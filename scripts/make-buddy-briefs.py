#!/usr/bin/env python3
"""Write the Codex image briefs for the full asset set of every buddy.

Usage:
  scripts/make-buddy-briefs.py 1   # briefs that need only the buddy's pose sheet
  scripts/make-buddy-briefs.py 2   # pose sheets for the evolved forms (run scripts/export-buddy-assets.py
                                   # first: it cuts the evolution sheets into design/buddies/cuts)

Reads design/pixel-options/prompts.tsv (slug, reference, character text).
Writes design/buddies/briefs/<slug>--<asset>.txt and a .ref file with the reference image.
Then run: scripts/codex-batch.sh design/buddies/briefs design/buddies/source
"""

import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
PROMPTS = REPO / "design/pixel-options/prompts.tsv"
BRIEFS = REPO / "design/buddies/briefs"
CUTS = REPO / "design/buddies/cuts"
FORMS = REPO / "design/buddies/forms"
REF_PADDING = 48

STYLE = (
    "Art style: true retro pixel art like a Tamagotchi pet or a cozy indie game, the same pixel scale as the "
    "attached image. Every pixel is a crisp hard square. No anti-aliasing, no gradients, no blur, no soft shadows. "
    "Limited palette. No text, no letters, no numbers, no labels, no watermark."
)
GRID = (
    "Layout (landscape 3:2): a grid of 4 columns and 2 rows, 8 equal cells, on pure solid black (#000000). "
    "The SAME character in every cell, same size, same pixel scale, on the same baseline, centered in its cell, "
    "with clear black space between cells. No grid lines, no borders."
)
SMALL = "Each pose must still read clearly when the sprite is shown only 32 pixels tall."

SHEETS = {
    "moods-2": (
        "Top row, left to right: (1) calm and relaxed, standing, soft closed-mouth smile; (2) exactly the same as "
        "pose 1 but with the eyes closed in a blink; (3) talking kindly, mouth open, one hand raised as if explaining "
        "something; (4) curious, head tilted to one side, one hand on the chin.\n"
        "Bottom row, left to right: (5) waving hello with one hand; (6) proud, giving a thumbs up; (7) a little sad "
        "and tired, shoulders down, gentle and not dramatic; (8) sleepy, yawning and rubbing one eye."
    ),
    "stretches-1": (
        "The character shows each office stretch clearly, so a person can copy it.\n"
        "Top row, left to right: (1) neck stretch, head tilted to its left, ear toward the shoulder, eyes closed; "
        "(2) the same neck stretch to the other side; (3) chin tucked down toward the chest; (4) both shoulders "
        "shrugged up high toward the ears.\n"
        "Bottom row, left to right: (5) chest opener, shoulders rolled back, both hands clasped behind the back; "
        "(6) sitting on a small stool, upper body twisted to the left; (7) sitting on the same stool, upper body "
        "twisted to the right; (8) wrist stretch, one arm straight forward, the other hand gently pulling the "
        "fingers back."
    ),
    "stretches-2": (
        "Top row, left to right: (1) reaching both arms high to the sky, standing on tiptoes; (2) side bend, one arm "
        "curved over the head, body leaning to one side; (3) marching in place, one knee lifted high; (4) walking, "
        "mid-stride, stepping forward.\n"
        "Bottom row, left to right: (5) taking a deep breath, chest lifted, eyes closed, calm; (6) palming the eyes, "
        "both hands cupped over the closed eyes; (7) sitting perfectly tall on a small chair in front of a tiny "
        "laptop, good posture, a small green pixel sparkle; (8) slumped badly in front of the same tiny laptop, head "
        "pushed forward like a turtle neck, rounded back, bad posture."
    ),
}

CORE_POSES = (
    "Top row, left to right: (1) happy and proud, with a perfectly straight back; (2) gently worried and slightly "
    "hunched forward, showing the bad posture of the user; (3) peacefully asleep with closed eyes; (4) stretching "
    "both arms high above the head.\n"
    "Bottom row, left to right: (5) neck stretch, head tilted to one side, eyes calmly closed; (6) drinking from a "
    "small glass of water; (7) resting the eyes, looking far into the distance with one hand shading the eyes; "
    "(8) celebrating a level up, jumping, with small pixel sparkles around it."
)

EVOLUTION = (
    "Pixel art evolution line, like the evolution chart of a creature-collecting game, but with our own original "
    "character.\n{char}\n{style}\n"
    "Layout (landscape 3:2): ONE row of 5 forms, left to right, on pure solid black (#000000), all standing on the "
    "same baseline, each form clearly bigger and more powerful than the one before. No arrows, no grid lines, no "
    "borders.\n"
    "(1) Baby form: smaller, rounder and younger, with huge eyes.\n"
    "(2) Exactly the character from the attached image.\n"
    "(3) Evolved form: a bit taller and stronger, a confident smile, one feature of its own design grows bigger "
    "(for example longer ears, bigger leaves, longer gills or longer hair) and its colors get a little brighter.\n"
    "(4) Champion form: much taller and athletic, standing very straight with fists on the hips, a glowing accent "
    "in its main color.\n"
    "(5) Legendary final form: the biggest, majestic, standing perfectly tall (a master of good posture), a glowing "
    "crown-like feature that grows from its own design, a faint ring of pixel sparkles around it, still a kind face.\n"
    "All five must clearly be the same character family as the attached image. Each form must read clearly when "
    "shown only 40 pixels tall."
)

MENUBAR_COLOR = (
    "Tiny pixel art icon, square 1:1.\n{char}\n{style}\n"
    "Only the head of the character (with its ears, gills, leaves or hair), seen from the front, happy face, on "
    "pure solid black (#000000). Very chunky pixels: draw it on a 16 x 16 pixel grid and scale it up, so each pixel "
    "is a big clear square. The head fills about 80% of the square. It must read at 18 pixels."
)

MENUBAR_OUTLINE = (
    "Tiny pixel icon, square 1:1, ONE color only. A silhouette of the head of the character in the attached image "
    "(with its ears, gills, leaves or hair), seen from the front: a solid pure black (#000000) shape on a pure white "
    "(#FFFFFF) background. The eyes and the smile are white holes cut out of the black shape. No other colors, no "
    "gray. Very chunky pixels: draw it on a 16 x 16 pixel grid and scale it up, so each pixel is a big clear square. "
    "The head fills about 80% of the square. It must read at 18 pixels. No text."
)

FORM_NAMES = {1: "baby", 3: "evolved", 4: "champion", 5: "legend"}


def buddies() -> list[tuple[str, str]]:
    rows = [line.split("\t") for line in PROMPTS.read_text().splitlines() if line.strip()]
    return [(row[0], row[2]) for row in rows]


def character_text(text: str) -> str:
    return (
        f"Character: {text}\nUse EXACTLY the character from the attached image: the same design, colors, eyes, "
        "proportions and pixel scale. It is the calm, kind buddy of a free macOS posture and break app."
    )


def write(slug: str, asset: str, brief: str, reference: Path) -> None:
    BRIEFS.mkdir(parents=True, exist_ok=True)
    (BRIEFS / f"{slug}--{asset}.txt").write_text(brief + "\n")
    (BRIEFS / f"{slug}--{asset}.ref").write_text(str(reference.relative_to(REPO)) + "\n")


def phase_one() -> None:
    for slug, text in buddies():
        char, sheet = character_text(text), REPO / f"design/pixel-options/{slug}.png"
        for asset, poses in SHEETS.items():
            write(slug, asset, f"Pixel art sprite sheet.\n{char}\n{STYLE}\n{GRID}\n{poses}\n{SMALL}", sheet)
        write(slug, "evolution", EVOLUTION.format(char=char, style=STYLE), sheet)
        write(slug, "menubar-color", MENUBAR_COLOR.format(char=char, style=STYLE), sheet)
        write(slug, "menubar-outline", MENUBAR_OUTLINE, sheet)


def form_reference(cut: Path, target: Path) -> None:
    """Put one cut form (transparent) on black, cropped tight, as the Codex reference."""
    sprite = Image.open(cut).convert("RGBA")
    sprite = sprite.crop(sprite.getchannel("A").getbbox())
    reference = Image.new("RGBA", (sprite.width + REF_PADDING * 2, sprite.height + REF_PADDING * 2), "black")
    reference.alpha_composite(sprite, (REF_PADDING, REF_PADDING))
    target.parent.mkdir(parents=True, exist_ok=True)
    reference.convert("RGB").save(target)


def phase_two() -> None:
    for slug, text in buddies():
        for number, name in FORM_NAMES.items():
            cut = CUTS / slug / "evolution" / f"form{number}.png"
            if not cut.exists():
                print(f"skip {slug} form {number}: run scripts/export-buddy-assets.py after the evolution sheet")
                continue
            form = FORMS / slug / f"form{number}.png"
            form_reference(cut, form)
            char = (
                f"Character: the {name} form of this buddy: {text}\nUse EXACTLY the character from the attached "
                "image: the same design, colors, size, proportions and pixel scale."
            )
            write(
                slug,
                f"form{number}-poses",
                f"Pixel art sprite sheet.\n{char}\n{STYLE}\n{GRID}\n{CORE_POSES}\n{SMALL}",
                form,
            )


if __name__ == "__main__":
    if sys.argv[1:] == ["1"]:
        phase_one()
    elif sys.argv[1:] == ["2"]:
        phase_two()
    else:
        raise SystemExit(__doc__)
