#!/usr/bin/env python3
"""Make the V2 artwork atlases real RGBA without changing their grid geometry.

The source images are white-matted illustrations.  Each 384x512 cell is
processed independently so white details enclosed by a dark outline remain
foreground.  Only near-white pixels connected to a cell edge are treated as
background; a small edge ramp removes the remaining white matte.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


ATLAS_COUNT = 6
ATLAS_SIZE = (1536, 1024)
CELL_SIZE = (384, 512)
GRID = (4, 2)
LIGHT = (250, 247, 240)
DARK = (32, 35, 42)
COLOR = (235, 218, 174)

# These are deliberately small, hand-checked masks for two interior white
# regions that the source artwork leaves open to its white matte.
INTERNAL_RESTORE_POLYGONS: dict[tuple[int, int, int], tuple[tuple[tuple[int, int], ...], ...]] = {
    (1, 0, 0): (
        ((59, 163), (89, 160), (113, 164), (120, 169), (127, 162), (157, 153), (174, 150), (179, 154), (194, 221), (137, 234), (120, 231), (106, 236), (76, 240)),
    ),
    (2, 1, 3): (
        ((94, 265), (139, 272), (143, 285), (133, 322), (118, 362), (96, 397), (89, 404), (63, 400), (44, 390), (44, 384), (55, 364), (70, 330), (86, 287)),
        ((60, 437), (78, 439), (89, 445), (91, 451), (85, 455), (64, 453), (53, 448), (42, 441)),
    ),
}

BOUNDARY_SPILLS: dict[tuple[int, int, int], str] = {
    (3, 1, 3): "top",
    (3, 1, 2): "right",
    (5, 1, 2): "right",
}


def parse_args() -> argparse.Namespace:
    root = Path(__file__).resolve().parents[1]
    return argparse.Namespace(
        root=root,
        assets=root / "apps/ios/Resources/Assets.xcassets",
        review=root / "design-assets/Final_product/02-screens/icon-transparency-review",
    )


def border_pixels(rgb: np.ndarray) -> np.ndarray:
    return np.concatenate(
        (
            rgb[:12, :, :].reshape(-1, 3),
            rgb[-12:, :, :].reshape(-1, 3),
            rgb[:, :12, :].reshape(-1, 3),
            rgb[:, -12:, :].reshape(-1, 3),
        ),
        axis=0,
    )


def estimate_background(rgb: np.ndarray) -> np.ndarray:
    border = border_pixels(rgb).astype(np.float32)
    chroma = border.max(axis=1) - border.min(axis=1)
    bright = border.mean(axis=1) >= 210
    candidates = border[(chroma <= 26) & bright]
    if len(candidates) < 32:
        candidates = border[border.mean(axis=1) >= 190]
    return np.median(candidates, axis=0) if len(candidates) else np.array([255, 255, 255], dtype=np.float32)


def dilate(mask: np.ndarray) -> np.ndarray:
    padded = np.pad(mask, 1, mode="constant", constant_values=False)
    result = np.zeros_like(mask, dtype=bool)
    for dy in range(3):
        for dx in range(3):
            result |= padded[dy : dy + mask.shape[0], dx : dx + mask.shape[1]]
    return result


def dilate_n(mask: np.ndarray, iterations: int) -> np.ndarray:
    result = mask.copy()
    for _ in range(iterations):
        result = dilate(result)
    return result


def flood_from_seeds(mask: np.ndarray, seeds: np.ndarray, diagonal: bool = True) -> np.ndarray:
    """Return mask pixels connected to any true seed."""
    height, width = mask.shape
    visited = np.zeros_like(mask, dtype=bool)
    seed_y, seed_x = np.nonzero(mask & seeds)
    queue: deque[tuple[int, int]] = deque(zip(seed_y.tolist(), seed_x.tolist()))
    visited[seed_y, seed_x] = True
    directions = ((-1, 0), (1, 0), (0, -1), (0, 1))
    if diagonal:
        directions += ((-1, -1), (-1, 1), (1, -1), (1, 1))
    while queue:
        y, x = queue.popleft()
        for dy, dx in directions:
            ny, nx = y + dy, x + dx
            if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not visited[ny, nx]:
                visited[ny, nx] = True
                queue.append((ny, nx))
    return visited


def connected_background(rgb: np.ndarray, background: np.ndarray) -> np.ndarray:
    """Find only edge-connected matte, never all white pixels in the cell."""
    pixels = rgb.astype(np.float32)
    mean = pixels.mean(axis=2)
    chroma = pixels.max(axis=2) - pixels.min(axis=2)
    distance = np.abs(pixels - background).mean(axis=2)

    # V2 has no black outer outline, so keep this matte test deliberately tight.
    # Connectivity removes only near-white edge matte; pale hats, pants and
    # other artwork remain foreground even when they touch the white field.
    candidates = (mean >= 240) & (chroma <= 14) & (distance <= 18)
    seeds = np.zeros_like(candidates, dtype=bool)
    seeds[0, :] = True
    seeds[-1, :] = True
    seeds[:, 0] = True
    seeds[:, -1] = True
    # Four-connectivity prevents a one-pixel diagonal gap from leaking into
    # outlined white pages or clothing while still removing the outer matte.
    return flood_from_seeds(candidates, seeds, diagonal=False)


def unmatte_cell(cell: np.ndarray) -> tuple[np.ndarray, dict[str, int | float]]:
    rgb = cell[:, :, :3].astype(np.float32)
    background = estimate_background(rgb)
    matte = connected_background(rgb, background)
    foreground = ~matte

    # Preserve solid foreground, then create a narrow anti-aliased transition
    # where a foreground edge meets the removed matte.
    alpha = np.where(foreground, 255.0, 0.0)
    near_edge = foreground & dilate(matte)
    difference = np.max(np.abs(rgb - background), axis=2)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    # Remove a light neutral fringe without making pale, chromatic artwork
    # translucent.  The latter is important for V2's unoutlined cream figures.
    soft_fringe = near_edge & (chroma <= 24)
    ramp = np.clip((difference - 18.0) / 100.0, 0.0, 1.0) * 255.0
    alpha[soft_fringe] = np.minimum(alpha[soft_fringe], ramp[soft_fringe])

    # Remove the white contribution from semi-transparent edge pixels.  Dark
    # outlines remain opaque and therefore act as the intended protection wall.
    partial = near_edge & (alpha > 0) & (alpha < 254)
    a = np.maximum(alpha[partial, None] / 255.0, 1 / 255.0)
    corrected = (rgb[partial] - background[None, :] * (1.0 - a)) / a
    rgb[partial] = np.clip(corrected, 0.0, 255.0)

    output = np.dstack((np.rint(rgb).astype(np.uint8), np.rint(alpha).astype(np.uint8)))
    stats = {
        "background_pixels": int(matte.sum()),
        "foreground_pixels": int(foreground.sum()),
        "partial_alpha_pixels": int(((output[:, :, 3] > 0) & (output[:, :, 3] < 255)).sum()),
        "nonzero_alpha": int((output[:, :, 3] > 0).sum()),
        "alpha_coverage": round(float((output[:, :, 3] > 0).mean()), 6),
        "background_rgb": [int(round(value)) for value in background],
    }
    return output, stats


def restore_internal_regions(output: np.ndarray, original: np.ndarray, polygons: tuple[tuple[tuple[int, int], ...], ...]) -> int:
    mask = Image.new("1", CELL_SIZE, 0)
    draw = ImageDraw.Draw(mask)
    for polygon in polygons:
        draw.polygon(polygon, fill=1)
    region = np.asarray(mask, dtype=bool) & (output[:, :, 3] == 0)
    output[region] = original[region]
    output[region, 3] = 255
    return int(region.sum())


def remove_isolated_boundary_spill(cell: np.ndarray, side: str, max_area: int = 2500) -> int:
    foreground = cell[:, :, 3] > 8
    seeds = np.zeros_like(foreground, dtype=bool)
    if side == "top":
        seeds[0, :] = True
    elif side == "right":
        seeds[:, -1] = True
    else:
        raise ValueError(f"Unsupported spill side: {side}")
    remaining = foreground & seeds
    removed = 0
    while remaining.any():
        seed = np.zeros_like(foreground, dtype=bool)
        y, x = np.argwhere(remaining)[0]
        seed[y, x] = True
        component = flood_from_seeds(foreground, seed, diagonal=True)
        remaining[component] = False
        if int(component.sum()) <= max_area:
            cell[component, 3] = 0
            removed += int(component.sum())
    return removed


def process_atlas(source: Path, destination: Path, atlas_number: int) -> dict[str, object]:
    image = Image.open(source).convert("RGBA")
    if image.size != ATLAS_SIZE:
        raise ValueError(f"{source} has {image.size}, expected {ATLAS_SIZE}")
    source_rgba = np.asarray(image)
    result = np.empty_like(source_rgba)
    cells: list[dict[str, object]] = []
    cell_w, cell_h = CELL_SIZE
    for row in range(GRID[1]):
        for column in range(GRID[0]):
            x0, y0 = column * cell_w, row * cell_h
            cell, stats = unmatte_cell(source_rgba[y0 : y0 + cell_h, x0 : x0 + cell_w])
            key = (atlas_number, row, column)
            if key in INTERNAL_RESTORE_POLYGONS:
                restored = restore_internal_regions(cell, source_rgba[y0 : y0 + cell_h, x0 : x0 + cell_w], INTERNAL_RESTORE_POLYGONS[key])
                stats["restored_internal_pixels"] = restored
            if key in BOUNDARY_SPILLS:
                stats["removed_isolated_boundary_pixels"] = remove_isolated_boundary_spill(cell, BOUNDARY_SPILLS[key])
            result[y0 : y0 + cell_h, x0 : x0 + cell_w] = cell
            cells.append({"row": row, "column": column, **stats})

    Image.fromarray(result, mode="RGBA").save(destination, format="PNG", optimize=True)
    alpha = result[:, :, 3]
    return {
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "output_sha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
        "size": list(image.size),
        "has_alpha": True,
        "alpha_nonzero": int((alpha > 0).sum()),
        "alpha_opaque": int((alpha == 255).sum()),
        "alpha_partial": int(((alpha > 0) & (alpha < 255)).sum()),
        "alpha_min": int(alpha.min()),
        "alpha_max": int(alpha.max()),
        "cells": cells,
    }


def process_legacy(source: Path, destination: Path) -> dict[str, object]:
    """Remove only external white sticker contours from an existing RGBA icon."""
    image = Image.open(source).convert("RGBA")
    pixels = np.asarray(image).copy()
    rgb = pixels[:, :, :3].astype(np.float32)
    alpha = pixels[:, :, 3]
    neutral_white = (rgb.min(axis=2) >= 214) & ((rgb.max(axis=2) - rgb.min(axis=2)) <= 38) & (alpha > 0)

    # Restrict removal to the five-pixel band immediately inside the original
    # alpha edge. Never flood arbitrary-depth white interior surfaces.
    transparent = alpha <= 8
    edge_band = dilate_n(transparent, 5)
    outer_candidates = neutral_white & edge_band
    outer = flood_from_seeds(outer_candidates, dilate(transparent), diagonal=True)
    pixels[outer, 3] = 0

    # Defringe the remaining partially transparent edge pixels next to the
    # removed contour, but leave saturated artwork and interior white alone.
    edge = dilate(outer) & (pixels[:, :, 3] > 0)
    partial = edge & (pixels[:, :, 3] < 255)
    if partial.any():
        a = np.maximum(pixels[partial, 3, None].astype(np.float32) / 255.0, 1 / 255.0)
        corrected = (pixels[partial, :3].astype(np.float32) - 255.0 * (1.0 - a)) / a
        pixels[partial, :3] = np.clip(np.rint(corrected), 0, 255).astype(np.uint8)

    Image.fromarray(pixels, mode="RGBA").save(destination, format="PNG", optimize=True)
    output_alpha = pixels[:, :, 3]
    return {
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "output_sha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
        "size": list(image.size),
        "has_alpha": True,
        "removed_outer_white_pixels": int(outer.sum()),
        "alpha_nonzero": int((output_alpha > 0).sum()),
        "alpha_partial": int(((output_alpha > 0) & (output_alpha < 255)).sum()),
    }


def font() -> ImageFont.ImageFont:
    for candidate in (
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        if Path(candidate).exists():
            try:
                return ImageFont.truetype(candidate, 20)
            except OSError:
                pass
    return ImageFont.load_default()


def contact_sheet(
    items: list[tuple[str, Image.Image]],
    background: tuple[int, int, int],
    destination: Path,
    columns: int,
    thumbnail_size: tuple[int, int],
    label_height: int,
) -> None:
    thumb_w, thumb_h = thumbnail_size
    margin, gap = 24, 16
    rows = (len(items) + columns - 1) // columns
    sheet = Image.new(
        "RGB",
        (
            margin * 2 + columns * thumb_w + (columns - 1) * gap,
            margin * 2 + rows * (thumb_h + label_height) + (rows - 1) * gap,
        ),
        background,
    )
    draw = ImageDraw.Draw(sheet)
    text_font = font()
    for index, (label, image) in enumerate(items):
        x = margin + (index % columns) * (thumb_w + gap)
        y = margin + (index // columns) * (thumb_h + label_height + gap)
        layer = Image.new("RGBA", (thumb_w, thumb_h), (*background, 255))
        preview = image.copy()
        preview.thumbnail((thumb_w - 4, thumb_h - 4), Image.Resampling.LANCZOS)
        layer.alpha_composite(preview, ((thumb_w - preview.width) // 2, (thumb_h - preview.height) // 2))
        sheet.paste(layer.convert("RGB"), (x, y))
        draw.text((x, y + thumb_h + 6), label, fill=(245, 245, 245) if sum(background) < 300 else (24, 28, 34), font=text_font)
    sheet.save(destination, format="PNG", optimize=True)


def main() -> None:
    args = parse_args()
    originals = args.review / "originals"
    previews = args.review / "contact-sheets"
    originals.mkdir(parents=True, exist_ok=True)
    previews.mkdir(parents=True, exist_ok=True)

    processed: list[tuple[str, Image.Image]] = []
    report: dict[str, object] = {"grid": {"atlas_size": list(ATLAS_SIZE), "cell_size": list(CELL_SIZE), "columns": 4, "rows": 2}, "atlases": {}}
    for index in range(1, ATLAS_COUNT + 1):
        asset_dir = args.assets / f"achv2_atlas_{index}.imageset"
        source = asset_dir / "atlas.png"
        original = originals / f"achv2_atlas_{index}.png"
        if not original.exists():
            shutil.copy2(source, original)
        input_source = original
        stats = process_atlas(input_source, source, index)
        report["atlases"][f"achv2_atlas_{index}"] = stats
        processed.append((f"atlas {index}", Image.open(source).convert("RGBA")))

    legacy_report: dict[str, object] = {}
    legacy_images: list[tuple[str, Image.Image]] = []
    for source_root, backup_name in (
        (args.assets / "Achievements", "legacy-achievements"),
        (args.assets, "legacy-chore-report"),
    ):
        backup_root = originals / backup_name
        for source in sorted(source_root.glob("*.imageset/*.png")):
            # The top-level asset pass is deliberately limited to chore/report
            # art; avatar_*.imageset and family_avatar_* are excluded below.
            if source_root == args.assets and not source.name.startswith(("chore_core_", "chore_catalog_", "chore_premium_", "monthly_")):
                continue
            original = backup_root / source.name
            backup_root.mkdir(parents=True, exist_ok=True)
            if not original.exists():
                shutil.copy2(source, original)
            stats = process_legacy(original, source)
            legacy_report[source.stem] = stats
            if source_root == args.assets:
                legacy_images.append((source.stem, Image.open(source).convert("RGBA")))
    report["legacy_alpha_icons"] = legacy_report

    cells: list[tuple[str, Image.Image]] = []
    for atlas_label, image in processed:
        for row in range(GRID[1]):
            for column in range(GRID[0]):
                x0, y0 = column * CELL_SIZE[0], row * CELL_SIZE[1]
                cells.append((f"{atlas_label} r{row + 1}c{column + 1}", image.crop((x0, y0, x0 + CELL_SIZE[0], y0 + CELL_SIZE[1]))))

    for name, color in (("light", LIGHT), ("dark", DARK), ("color", COLOR)):
        contact_sheet(cells, color, previews / f"achv2-cells-8x6-{name}.png", columns=8, thumbnail_size=(192, 256), label_height=24)
        contact_sheet(processed, color, previews / f"achv2-atlases-2x3-{name}.png", columns=3, thumbnail_size=(512, 341), label_height=28)
        if legacy_images:
            contact_sheet(legacy_images, color, previews / f"chore-report-27-{name}.png", columns=9, thumbnail_size=(160, 160), label_height=24)
    (args.review / "alpha-report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    print(f"review={args.review}")


if __name__ == "__main__":
    main()
