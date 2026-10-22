#!/usr/bin/env python3
"""Cut a pose sheet on black into sprites, all at the same scale and on the same baseline.

Usage: scripts/split-sprite-sheet.py <sheet.png> <out-dir> [--grid 4x2] [--poses a,b,c,...] [--by-shapes]
                                     [--black-threshold 4]
Needs Pillow and numpy. Writes <out-dir>/<pose>.png for each pose name, row by row, left to right.
Without --grid and --poses it cuts the standard 4 x 2 sheet with the 8 poses in POSES.
Each whole shape goes to the grid cell that holds most of it, so a tail or a sparkle that reaches
over a cell line is not sliced (see sprite_shapes.py).
--by-shapes cuts out the separate shapes, left to right (see sprite_shapes.py). Use it for the
evolution line: its sprites grow from left to right and do not sit in equal cells.
The black background around the character becomes transparent. Dark pixels inside the
character (outlines, eyes) stay, because only black that touches the frame edge is removed.
--black-threshold sets the brightness (0 to 255) that still counts as background. Codex draws the
background at 0 to 2. Keep the value low: at 28 the cut ate dark hair and dark outlines.
On some evolution sheets a faint glow (brightness 5 to 12) joins two forms. Then --by-shapes finds
the shapes again with the brighter cut-offs in SPLIT_THRESHOLDS, and that faint glow is left out.
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw
from sprite_shapes import TouchingSprites, grid_shape_cells, shape_cells

POSES = ["happy", "worried", "sleeping", "stretching", "neck", "water", "eyes", "celebrate"]
BLACK_THRESHOLD = 4  # brightness at or below this counts as background
SPLIT_THRESHOLDS = (8, 12, 16, 28)  # tried in turn when a faint glow joins two evolution forms
PADDING = 10


def foreground_mask(image: Image.Image, threshold: int = BLACK_THRESHOLD) -> Image.Image:
    return image.convert("L").point(lambda value: 255 if value > threshold else 0)


def content_box(cell: Image.Image, threshold: int) -> tuple[int, int, int, int] | None:
    return foreground_mask(cell, threshold).getbbox()


def with_transparent_background(frame: Image.Image, threshold: int) -> Image.Image:
    """Return an RGBA copy where the black that touches the frame edge is transparent."""
    background = foreground_mask(frame, threshold)
    ImageDraw.floodfill(background, (0, 0), 128, thresh=0)  # the frame always has a black border
    alpha = background.point(lambda value: 0 if value == 128 else 255)
    result = frame.convert("RGBA")
    result.putalpha(alpha)
    return result


def separate_shapes(sheet: Image.Image, count: int, sheet_name: str, threshold: int) -> list[Image.Image]:
    """Cut out `count` separate shapes. Try brighter cut-offs if a faint glow joins two of them."""
    error = TouchingSprites(sheet_name)
    for split_threshold in (threshold, *(value for value in SPLIT_THRESHOLDS if value > threshold)):
        try:
            return shape_cells(sheet, foreground_mask(sheet, split_threshold), count, sheet_name)
        except TouchingSprites as touching:
            error = touching
    raise SystemExit(str(error))


def split(
    sheet_path: Path, out_dir: Path, columns: int, rows: int, poses: list[str], by_shapes: bool, threshold: int
) -> None:
    if len(poses) != columns * rows:
        raise SystemExit(f"{len(poses)} pose names for a {columns} x {rows} grid")
    sheet = Image.open(sheet_path).convert("RGB")
    if by_shapes:
        cells = separate_shapes(sheet, len(poses), sheet_path.name, threshold)
    else:
        cells = grid_shape_cells(sheet, foreground_mask(sheet, threshold), columns, rows)
    boxes = [content_box(cell, threshold) for cell in cells]
    found = [box for box in boxes if box]
    if not found:
        raise SystemExit(f"No sprites found in {sheet_path}")

    # One frame size for every pose, so the character does not change size between poses.
    frame_w = max(box[2] - box[0] for box in found) + PADDING * 2
    frame_h = max(box[3] - box[1] for box in found) + PADDING * 2

    out_dir.mkdir(parents=True, exist_ok=True)
    for pose, cell, box in zip(poses, cells, boxes):
        frame = Image.new("RGB", (frame_w, frame_h), "black")
        if box:
            sprite = cell.crop(box)
            x = (frame_w - sprite.width) // 2
            y = frame_h - PADDING - sprite.height  # same baseline for every pose
            frame.paste(sprite, (x, max(0, y)))
        with_transparent_background(frame, threshold).save(out_dir / f"{pose}.png")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("sheet", type=Path)
    parser.add_argument("out_dir", type=Path)
    parser.add_argument("--grid", default="4x2", help="columns x rows, for example 5x1")
    parser.add_argument("--poses", default=",".join(POSES), help="pose names, comma separated")
    parser.add_argument(
        "--by-shapes", action="store_true", help="cut out the separate shapes, left to right, not equal cells"
    )
    parser.add_argument(
        "--black-threshold", type=int, default=BLACK_THRESHOLD, help="brightness that still counts as background"
    )
    args = parser.parse_args()
    grid_columns, grid_rows = (int(part) for part in args.grid.lower().split("x"))
    split(
        args.sheet, args.out_dir, grid_columns, grid_rows, args.poses.split(","), args.by_shapes, args.black_threshold
    )
