#!/usr/bin/env python3
"""Draw every buddy in every color choice, to check the color settings before they ship.

Usage: scripts/color-sheet.py <out.png> [slug ...] [--pose happy]   (needs Pillow and numpy)
Reads the exported art and catalog.json in Packages/BuddyKit/Sources/NotchUI/Resources/Buddies, so run
scripts/export-buddy-assets.py first after a change to design/buddies/buddy-settings.json.
Uses the same math as HueSwap.swift (BuddyCore). Keep the two the same.
A cell with a gray frame is a color the app does not offer for that buddy: it is too close to the
buddy's own color (BuddyColor.sameColorDistance).
"""

import argparse
import colorsys
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
BUDDIES = REPO / "Packages/BuddyKit/Sources/NotchUI/Resources/Buddies"
COLORS = [("original", None), ("rose", 330), ("orange", 30), ("lime", 95), ("teal", 175), ("sky", 205), ("violet", 275)]
HUE_FEATHER, SATURATION_FEATHER, VALUE_FEATHER = 8.0, 0.06, 0.08
SAME_COLOR_DISTANCE = 25
CELL, LABEL = 200, 18
BACKGROUND, HIDDEN = (150, 150, 150, 255), (110, 110, 110, 255)


def distance(first: float, second: float) -> float:
    difference = abs(first - second) % 360
    return min(difference, 360 - difference)


def ramp(amount: float, band: float) -> float:
    return 0.0 if amount <= 0 else min(1.0, amount / band)


def weight(hue: float, saturation: float, value: float, buddy: dict) -> float:
    return (
        ramp(buddy["hueTolerance"] - distance(hue, buddy["hueCenter"]), HUE_FEATHER)
        * ramp(saturation - buddy["minSaturation"], SATURATION_FEATHER)
        * ramp(value - buddy["minValue"], VALUE_FEATHER)
    )


def turned_color(color: np.ndarray, buddy: dict, turn: float) -> list[int]:
    hue, saturation, value = colorsys.rgb_to_hsv(*(color / 255))
    new_hue = (hue * 360 + weight(hue * 360, saturation, value, buddy) * turn) % 360 / 360
    return [round(channel * 255) for channel in colorsys.hsv_to_rgb(new_hue, saturation, value)]


def recolored(image: Image.Image, buddy: dict, target: float) -> Image.Image:
    """Each distinct color is worked out once, like HueSwap.recolored. Alpha never changes."""
    turn = (target - buddy["mainHue"] + 180) % 360 - 180
    pixels = np.array(image)
    solid = pixels[..., 3] > 0
    colors, index = np.unique(pixels[solid][:, :3], axis=0, return_inverse=True)
    turned = np.array([turned_color(color, buddy, turn) for color in colors], dtype=np.uint8)
    pixels[solid, :3] = turned[index.ravel()]
    return Image.fromarray(pixels)


def with_defaults(entry: dict) -> dict:
    return {
        "hueCenter": entry["mainHue"],
        "hueTolerance": 30.0,
        "minSaturation": 0.12,
        "minValue": 0.0,
        **entry,
    }


def draw_sheet(buddies: list[dict], pose: str) -> Image.Image:
    sheet = Image.new("RGBA", (CELL * len(COLORS), LABEL + CELL * len(buddies)), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    for column, (name, _) in enumerate(COLORS):
        draw.text((column * CELL + 6, 3), name, fill="black")
    for row, buddy in enumerate(buddies):
        art = Image.open(BUDDIES / buddy["id"] / f"{pose}.png").convert("RGBA")
        art.thumbnail((CELL - 20, CELL - 20))
        top = LABEL + row * CELL
        for column, (_, target) in enumerate(COLORS):
            left = column * CELL
            if target is not None and distance(target, buddy["mainHue"]) <= SAME_COLOR_DISTANCE:
                draw.rectangle((left + 2, top + 2, left + CELL - 3, top + CELL - 3), outline=HIDDEN, width=4)
            cell = art if target is None else recolored(art, buddy, target)
            sheet.alpha_composite(cell, (left + (CELL - cell.width) // 2, top + (CELL - cell.height) // 2))
        draw.text((6, top + 4), buddy["id"], fill="black")
    return sheet


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    parser.add_argument("slugs", nargs="*", help="buddy ids; all buddies when left out")
    parser.add_argument("--pose", default="happy")
    args = parser.parse_args()
    catalog = json.loads((BUDDIES / "catalog.json").read_text())["buddies"]
    buddies = [with_defaults(entry) for entry in catalog if not args.slugs or entry["id"] in args.slugs]
    if not buddies:
        raise SystemExit(f"No buddy matches {args.slugs}")
    draw_sheet(buddies, args.pose).save(args.out)
    print(f"{args.out}: {len(buddies)} buddies x {len(COLORS)} colors")


if __name__ == "__main__":
    main()
