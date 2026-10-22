#!/usr/bin/env python3
"""Copy every buddy image the app uses into the NotchUI package, small, with a catalog.

Usage: scripts/export-buddy-assets.py
Needs Pillow. Reads:
  design/pixel-options/prompts.tsv           the buddy list (number-slug, reference, character text)
  design/buddies/buddy-settings.json         name, color settings and the cut threshold, per buddy
  design/pixel-options/<slug>.png            the 8 core poses (cut here into design/pixel-options/sprites/<slug>/)
  design/buddies/source/<slug>--<sheet>.png  the extra sheets (cut here), when they exist
Writes Packages/BuddyKit/Sources/NotchUI/Resources/Buddies/<slug>/<asset>.png and catalog.json.
A buddy with a "pack" setting is locked (DECISIONS T54): it goes to private/packs/<pack>/ instead,
with its own catalog.json. Run `make packs` after this to lock those folders into the app.
Run it again after new images arrive. It replaces the whole Buddies folder and private/packs/.
"""

import colorsys
import json
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from menubar_icons import color_icon, outline_icon, save_icon

REPO = Path(__file__).resolve().parent.parent
PROMPTS = REPO / "design/pixel-options/prompts.tsv"
CORE_SHEETS = REPO / "design/pixel-options"
CORE = REPO / "design/pixel-options/sprites"
SOURCE = REPO / "design/buddies/source"
CUTS = REPO / "design/buddies/cuts"
OUT = REPO / "Packages/BuddyKit/Sources/NotchUI/Resources/Buddies"
PACKS = REPO / "private/packs"  # locked buddies: never in the open app or the public repo
SPLITTER = REPO / "scripts/split-sprite-sheet.py"
SETTINGS = REPO / "design/buddies/buddy-settings.json"

MAX_HEIGHT = 192  # the open island shows a buddy 92 pt tall, which is 184 px on a Retina screen
PALETTE_COLORS = 128

CORE_POSES = ["happy", "worried", "sleeping", "stretching", "neck", "water", "eyes", "celebrate"]
SHEETS = {
    "moods-2": ("4x2", ["calm", "blink", "talking", "curious", "wave", "thumbs-up", "sad", "yawn"]),
    "stretches-1": (
        "4x2",
        ["neck-left", "neck-right", "chin-tuck", "shrug", "chest-open", "twist-left", "twist-right", "wrist"],
    ),
    "stretches-2": ("4x2", ["reach", "side-bend", "march", "walk", "breathe", "palming", "sit-tall", "slouch"]),
    "moments": ("4x2", ["wave", "walk", "laptop", "chai", "thumbs-up", "fist-bump", "breathe", "trophy"]),
    "evolution": ("5x1", ["form1", "form2", "form3", "form4", "form5"]),
    **{f"form{n}-poses": ("4x2", [f"form{n}-{pose}" for pose in CORE_POSES]) for n in (1, 3, 4, 5)},
}
CUT_BY_SHAPES = {"evolution"}  # the forms grow from left to right, so they do not sit in equal cells

# Fields of buddy-settings.json that go into catalog.json for the app's color option (HueSwap).
COLOR_FIELDS = ("hueCenter", "hueTolerance", "minSaturation", "minValue")
OPAQUE_FROM = 128  # alpha at or above this becomes solid, below it see-through


def buddies() -> list[dict]:
    result = []
    for line in PROMPTS.read_text().splitlines():
        if not line.strip():
            continue
        slug = line.split("\t")[0]
        number, _, words = slug.partition("-")
        result.append({"id": slug, "number": int(number), "name": words.split("-")[0].capitalize()})
    return result


def main_hue(image: Image.Image) -> int:
    """The most common hue (in degrees) among the clearly colored, visible pixels."""
    counts = [0] * 36
    small = image.convert("RGBA").resize((64, 64))
    for red, green, blue, alpha in small.get_flattened_data():
        if alpha < 128:
            continue
        hue, lightness, saturation = colorsys.rgb_to_hls(red / 255, green / 255, blue / 255)
        if saturation > 0.35 and 0.25 < lightness < 0.85:
            counts[int(hue * 36) % 36] += 1
    return counts.index(max(counts)) * 10 + 5


def save_small(source: Path, target: Path) -> None:
    """Shrink to MAX_HEIGHT and save with a palette and one see-through index.

    The alpha becomes solid or see-through, like the pixel art it comes from. A palette made from
    RGBA blends the alpha of similar colors, and the buddy's body came out slightly see-through.
    """
    image = Image.open(source).convert("RGBA")
    if image.height > MAX_HEIGHT:
        width = round(image.width * MAX_HEIGHT / image.height)
        image = image.resize((width, MAX_HEIGHT), Image.Resampling.LANCZOS)
    solid = image.getchannel("A").point(lambda alpha: 255 if alpha >= OPAQUE_FROM else 0)
    rgb = Image.composite(image.convert("RGB"), Image.new("RGB", image.size), solid)  # see-through becomes black
    clear = PALETTE_COLORS - 1  # the last palette index is the see-through one
    paletted = rgb.quantize(colors=clear, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    colors = paletted.getpalette()[: clear * 3]
    paletted.putpalette(colors + [0] * (clear * 3 - len(colors)) + [0, 0, 0])
    paletted.paste(clear, mask=solid.point(lambda alpha: 255 - alpha))
    paletted.save(target, optimize=True, transparency=clear)


def cut(source: Path, out_dir: Path, grid: str, poses: list[str], settings: dict, by_shapes: bool) -> bool:
    threshold = ["--black-threshold", str(settings["blackThreshold"])] if "blackThreshold" in settings else []
    command = [sys.executable, str(SPLITTER), str(source), str(out_dir), "--grid", grid, "--poses", ",".join(poses)]
    result = subprocess.run([*command, *(["--by-shapes"] if by_shapes else []), *threshold], check=False)
    if result.returncode != 0:
        print(f"WARNING: could not cut {source.name}. Its images are left out. Make it again.", file=sys.stderr)
    return result.returncode == 0


def cut_sheets(slug: str, settings: dict) -> dict[str, Path]:
    found = {}
    for sheet, (grid, poses) in SHEETS.items():
        source = SOURCE / f"{slug}--{sheet}.png"
        out_dir = CUTS / slug / sheet
        if source.exists() and cut(source, out_dir, grid, poses, settings, sheet in CUT_BY_SHAPES):
            found.update({pose: out_dir / f"{pose}.png" for pose in poses})
    return found


def export_buddy(buddy: dict, settings: dict) -> dict:
    slug = buddy["id"]
    sheet = CORE_SHEETS / f"{slug}.png"
    if not sheet.exists() or not cut(sheet, CORE / slug, "4x2", CORE_POSES, settings, by_shapes=False):
        print(f"WARNING: {slug} is left out: its pose sheet {sheet.name} is missing or did not cut.", file=sys.stderr)
        return {}
    assets = {pose: CORE / slug / f"{pose}.png" for pose in CORE_POSES}
    assets.update(cut_sheets(slug, settings))
    out_dir = (PACKS / settings["pack"] if "pack" in settings else OUT) / slug
    out_dir.mkdir(parents=True)
    for name, path in assets.items():
        save_small(path, out_dir / f"{name}.png")
    for name, make_icon in (("menubar-color", color_icon), ("menubar-outline", outline_icon)):
        source = SOURCE / f"{slug}--{name}.png"
        if source.exists():
            save_icon(make_icon(source), out_dir / f"{name}.png")
            assets[name] = source
    hue = settings.get("mainHue", main_hue(Image.open(assets["happy"])))
    color = {field: settings[field] for field in COLOR_FIELDS if field in settings}
    name = settings.get("name", buddy["name"])
    pack = {"pack": settings["pack"]} if "pack" in settings else {}
    return {**buddy, "name": name, "mainHue": hue, **color, **pack, "images": len(assets)}


def write_catalog(folder: Path, entries: list[dict]) -> None:
    catalog = [{key: value for key, value in entry.items() if key not in ("images", "pack")} for entry in entries]
    (folder / "catalog.json").write_text(json.dumps({"buddies": catalog}, indent=2) + "\n")


if __name__ == "__main__":
    for folder in (OUT, PACKS):
        if folder.exists():
            shutil.rmtree(folder)
    OUT.mkdir(parents=True)
    settings = json.loads(SETTINGS.read_text())
    exported = [entry for entry in (export_buddy(b, settings.get(b["id"], {})) for b in buddies()) if entry]
    write_catalog(OUT, [entry for entry in exported if "pack" not in entry])
    for pack in sorted({entry["pack"] for entry in exported if "pack" in entry}):
        write_catalog(PACKS / pack, [entry for entry in exported if entry.get("pack") == pack])
    for entry in exported:
        where = f"locked in {entry['pack']}" if "pack" in entry else "open"
        print(f"{entry['id']:20} hue {entry['mainHue']:3}  {entry['images']} images  {where}")
