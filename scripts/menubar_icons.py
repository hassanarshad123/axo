"""Turn the two Codex menu bar images of a buddy into clean icons. Used by export-buddy-assets.py.

color_icon:   the head on black      -> full color on a transparent background
outline_icon: black shape on white   -> black shape on transparent (the app marks it as a template,
                                        so macOS colors it to match the menu bar)
Both come back square and cropped to the head. The menu bar is 18 pt tall, so save them at 36 px.
"""

from pathlib import Path

from PIL import Image, ImageDraw

PIXELS = 36  # 18 pt at 2x
BLACK_THRESHOLD = 28
OUTLINE_INK_THRESHOLD = 128  # darker than this on the white image counts as the shape


def square_crop(image: Image.Image) -> Image.Image:
    """Crop to the visible pixels, then pad to a square with transparent space."""
    box = image.getchannel("A").getbbox()
    if box is None:
        raise SystemExit("The icon image is empty")
    content = image.crop(box)
    side = max(content.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(content, ((side - content.width) // 2, (side - content.height) // 2))
    return square


def color_icon(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGB")
    mask = image.convert("L").point(lambda value: 255 if value > BLACK_THRESHOLD else 0)
    padded = Image.new("L", (mask.width + 2, mask.height + 2), 0)
    padded.paste(mask, (1, 1))
    ImageDraw.floodfill(padded, (0, 0), 128, thresh=0)  # remove only the black around the head
    alpha = padded.crop((1, 1, mask.width + 1, mask.height + 1)).point(lambda value: 0 if value == 128 else 255)
    result = image.convert("RGBA")
    result.putalpha(alpha)
    return square_crop(result)


def outline_icon(path: Path) -> Image.Image:
    luminance = Image.open(path).convert("L")
    alpha = luminance.point(lambda value: 255 if value < OUTLINE_INK_THRESHOLD else 0)
    result = Image.new("RGBA", luminance.size, (0, 0, 0, 255))
    result.putalpha(alpha)
    return square_crop(result)


def save_icon(icon: Image.Image, target: Path) -> None:
    icon.resize((PIXELS, PIXELS), Image.Resampling.LANCZOS).save(target, optimize=True)
