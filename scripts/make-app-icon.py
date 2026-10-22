#!/usr/bin/env python3
"""Turn square artwork into a macOS app icon set.

Usage: scripts/make-app-icon.py <artwork.png> <AppIcon.appiconset> [--master <icon-1024.png>]
Needs Pillow. The artwork fills its square edge to edge. This script puts it on the macOS
icon grid (an 824 px rounded square in a 1024 px canvas, with a soft shadow), then writes
all 10 sizes and Contents.json. --master also saves the 1024 px icon (for the website).
"""

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

CANVAS = 1024
BODY = 824  # Apple macOS icon grid: the rounded square is 824 px in a 1024 px canvas
CORNER_RADIUS = 185
SHADOW_OFFSET, SHADOW_BLUR, SHADOW_ALPHA = 10, 14, 90
SUPERSAMPLE = 4  # draw the mask 4x bigger, then shrink, for smooth corners
SIZES = [16, 32, 128, 256, 512]


def rounded_mask(size: int, radius: int) -> Image.Image:
    big = Image.new("L", (size * SUPERSAMPLE, size * SUPERSAMPLE), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, big.width - 1, big.height - 1), radius=radius * SUPERSAMPLE, fill=255)
    return big.resize((size, size), Image.Resampling.LANCZOS)


def master_icon(artwork: Image.Image) -> Image.Image:
    side = min(artwork.size)
    square = artwork.crop(
        (
            (artwork.width - side) // 2,
            (artwork.height - side) // 2,
            (artwork.width + side) // 2,
            (artwork.height + side) // 2,
        )
    )
    body = square.convert("RGBA").resize((BODY, BODY), Image.Resampling.LANCZOS)
    mask = rounded_mask(BODY, CORNER_RADIUS)
    body.putalpha(ImageChops.multiply(body.getchannel("A"), mask))

    origin = (CANVAS - BODY) // 2
    shadow_alpha = Image.new("L", (CANVAS, CANVAS), 0)
    shadow_alpha.paste(mask.point(lambda value: value * SHADOW_ALPHA // 255), (origin, origin + SHADOW_OFFSET))
    shadow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shadow.putalpha(shadow_alpha.filter(ImageFilter.GaussianBlur(SHADOW_BLUR)))

    icon = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    icon.alpha_composite(shadow)
    icon.alpha_composite(body, (origin, origin))
    return icon


def write_icon_set(icon: Image.Image, out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    images = []
    for size in SIZES:
        for scale in (1, 2):
            name = f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
            icon.resize((size * scale, size * scale), Image.Resampling.LANCZOS).save(out_dir / name)
            images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{size}x{size}"})
    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    (out_dir / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("artwork", type=Path)
    parser.add_argument("icon_set", type=Path)
    parser.add_argument("--master", type=Path)
    args = parser.parse_args()
    result = master_icon(Image.open(args.artwork))
    write_icon_set(result, args.icon_set)
    if args.master:
        result.save(args.master)
