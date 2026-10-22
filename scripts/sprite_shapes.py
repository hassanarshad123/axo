"""Find the separate sprites on a sheet by their shapes. Used by split-sprite-sheet.py.

Every separate shape on the black gets a label. Then:
- grid_shape_cells (pose sheets): each whole shape goes to the grid cell that holds most of it.
- shape_cells (the evolution line): five forms grow from left to right. They do not sit in equal
  cells, and whiskers or tails of one form can reach over the next one, so neither a grid nor a
  column cut works. The biggest shapes are the sprites. Each small loose shape (a sparkle) joins
  the sprite that is nearest to it.
"""

import math

import numpy as np
from PIL import Image

SCALE = 4  # label a 4x smaller mask: fast, and one pixel-art pixel is about 8 sheet pixels wide
MIN_AREA = 4  # shapes smaller than this (in small-mask pixels) are noise, not sparkles
SPARKLE_RATIO = 5  # the smallest sprite must be this many times bigger than the biggest sparkle
TOUCH_SHARE = 0.25  # a grid shape with this part of its area in a second cell is two sprites that touch

Box = tuple[int, int, int, int]  # top, left, bottom, right


class TouchingSprites(Exception):
    """The sheet does not have the expected number of clear sprites: some of them touch."""


def label_shapes(mask: np.ndarray) -> np.ndarray:
    """Give each 8-connected shape of True pixels its own number, starting at 1."""
    height, width = mask.shape
    filled = mask.tolist()
    labels = [[0] * width for _ in range(height)]
    count = 0
    for start_y, start_x in zip(*np.nonzero(mask)):
        if labels[start_y][start_x]:
            continue
        count += 1
        labels[start_y][start_x] = count
        stack = [(int(start_y), int(start_x))]
        while stack:
            y, x = stack.pop()
            for ny in range(max(y - 1, 0), min(y + 2, height)):
                for nx in range(max(x - 1, 0), min(x + 2, width)):
                    if filled[ny][nx] and not labels[ny][nx]:
                        labels[ny][nx] = count
                        stack.append((ny, nx))
    return np.array(labels, dtype=np.int32)


def bounds(region: np.ndarray) -> Box:
    ys, xs = np.nonzero(region)
    return int(ys.min()), int(xs.min()), int(ys.max()), int(xs.max())


def box_distance(a: Box, b: Box) -> float:
    dy = max(0, b[0] - a[2], a[0] - b[2])
    dx = max(0, b[1] - a[3], a[1] - b[3])
    return math.hypot(dx, dy)


def owners(labels: np.ndarray, count: int, sheet_name: str) -> tuple[list[int], dict[int, int]]:
    """Return the sprite labels, left to right, and the sprite that each kept shape belongs to."""
    areas = np.bincount(labels.ravel())
    shapes = [int(label) for label in np.argsort(areas[1:])[::-1] + 1 if areas[label] >= MIN_AREA]
    sprites, sparkles = shapes[:count], shapes[count:]
    if len(sprites) < count or (sparkles and areas[sprites[-1]] < SPARKLE_RATIO * areas[sparkles[0]]):
        raise TouchingSprites(f"{sheet_name}: did not find {count} clear sprites. Some of them touch.")
    boxes = {label: bounds(labels == label) for label in shapes}
    owner = {label: label for label in sprites}
    for label in sparkles:
        owner[label] = min(sprites, key=lambda sprite: box_distance(boxes[label], boxes[sprite]))
    return sorted(sprites, key=lambda sprite: boxes[sprite][1]), owner


def grid_shape_cells(sheet: Image.Image, foreground: Image.Image, columns: int, rows: int) -> list[Image.Image]:
    """Return one full-size copy of the sheet per grid cell, row by row, with all else black.

    Each whole shape goes to the cell that holds most of it, so a tail, an arm or a sparkle that
    reaches over a cell line stays with its own sprite. A shape with a big part (TOUCH_SHARE or
    more) in a second cell is two sprites that touch: that one shape is cut on the cell line.
    """
    labels = label_shapes(np.asarray(foreground.reduce(SCALE)) > 0)
    labels = labels.repeat(SCALE, axis=0).repeat(SCALE, axis=1)[: sheet.height, : sheet.width]
    ys, xs = np.indices(labels.shape)
    cell_w, cell_h = sheet.width // columns, sheet.height // rows
    cell = np.minimum(ys // cell_h, rows - 1) * columns + np.minimum(xs // cell_w, columns - 1)
    shares = np.zeros((labels.max() + 1, columns * rows), dtype=np.int64)
    np.add.at(shares, (labels.ravel(), cell.ravel()), 1)
    ranked = np.sort(shares, axis=1)
    whole = ranked[:, -2] < TOUCH_SHARE * shares.sum(axis=1)
    owner = np.where(whole[labels], shares.argmax(axis=1)[labels], cell)
    owner[labels == 0] = -1
    pixels = np.asarray(sheet.convert("RGB"))
    return [
        Image.fromarray(np.where((owner == index)[..., None], pixels, 0).astype(np.uint8))
        for index in range(columns * rows)
    ]


def shape_cells(sheet: Image.Image, foreground: Image.Image, count: int, sheet_name: str) -> list[Image.Image]:
    """Return one full-size copy of the sheet per sprite, left to right, with all else black.

    foreground is the sheet's mask: 255 where the character is, 0 where the black background is.
    """
    small_labels = label_shapes(np.asarray(foreground.reduce(SCALE)) > 0)
    sprites, owner = owners(small_labels, count, sheet_name)
    labels = small_labels.repeat(SCALE, axis=0).repeat(SCALE, axis=1)[: sheet.height, : sheet.width]
    pixels = np.asarray(sheet.convert("RGB"))
    cells = []
    for sprite in sprites:
        region = np.isin(labels, [label for label, its_sprite in owner.items() if its_sprite == sprite])
        cells.append(Image.fromarray(np.where(region[..., None], pixels, 0).astype(np.uint8)))
    return cells
