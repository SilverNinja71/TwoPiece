#!/usr/bin/env python3
"""
Spherical World Map Extractor for Project "Blue Planet" (Godot 4.3+, precision=double).

Reads the canonical equirectangular reference map:
  /Users/lin/.gemini/antigravity/brain/b554bb1c-b553-4bef-a514-dd4a62f0a2c8/.user_uploaded/media_1794727730344_94c767f.jpg
Samples a 180 x 90 spherical (lon, lat) grid (2 deg x 2 deg = 16,200 sectors matching WorldRegistry),
combines image color classification (land/island vs ocean vs Red Line) with exact 64-bit Great-Circle
geodesy (R = 16,000,000.0 m), and outputs:
  /Users/lin/Downloads/OnePieceBluePlanet/assets/planetary_map_metadata.json
"""

from __future__ import annotations

import json
import math
import os
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, List, Tuple

SOURCE_MAP_PATH = Path(
    "/Users/lin/.gemini/antigravity/brain/b554bb1c-b553-4bef-a514-dd4a62f0a2c8/.user_uploaded/media_1794727730344_94c7567f.jpg"
)
OUTPUT_JSON_PATH = Path(
    "/Users/lin/Downloads/OnePieceBluePlanet/assets/planetary_map_metadata.json"
)

PLANET_RADIUS_M = 16_000_000.0
RED_LINE_TILT_RAD = math.radians(45.0)
GRAND_LINE_TILT_RAD = math.radians(-45.0)
RED_LINE_HALF_WIDTH_M = 125_000.0
GRAND_LINE_HALF_WIDTH_M = 300_000.0
CALM_BELT_OUTER_OFFSET_M = 450_000.0

GRID_LON_CELLS = 180  # 2 deg per cell (-180..+180)
GRID_LAT_CELLS = 90   # 2 deg per cell (+90..-90)


def _dot(a: Tuple[float, float, float], b: Tuple[float, float, float]) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _normalize(v: Tuple[float, float, float]) -> Tuple[float, float, float]:
    mag = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    if mag < 1e-12:
        return (0.0, 1.0, 0.0)
    return (v[0] / mag, v[1] / mag, v[2] / mag)


def _lat_lon_to_unit_sphere(lat_deg: float, lon_deg: float) -> Tuple[float, float, float]:
    lat_r = math.radians(lat_deg)
    lon_r = math.radians(lon_deg)
    cos_lat = math.cos(lat_r)
    return (
        cos_lat * math.cos(lon_r),
        math.sin(lat_r),
        cos_lat * math.sin(lon_r),
    )


RED_LINE_NORMAL = _normalize((0.0, math.cos(RED_LINE_TILT_RAD), -math.sin(RED_LINE_TILT_RAD)))
GRAND_LINE_NORMAL = _normalize((0.0, math.cos(GRAND_LINE_TILT_RAD), -math.sin(GRAND_LINE_TILT_RAD)))


def load_rgb_image(image_path: Path) -> Tuple[int, int, List[Tuple[int, int, int]], str]:
    """Loads RGB image pixels via Pillow if installed, else macOS `sips` -> BMP pure-Python decoder."""
    try:
        from PIL import Image  # type: ignore

        with Image.open(image_path) as img:
            rgb = img.convert("RGB")
            w, h = rgb.size
            pixels = list(rgb.getdata())
            return w, h, pixels, "Pillow"
    except ImportError:
        pass

    sips_bin = shutil.which("sips")
    if sips_bin and image_path.exists():
        with tempfile.TemporaryDirectory() as tmp_dir:
            bmp_path = Path(tmp_dir) / "converted_map.bmp"
            subprocess.run(
                [sips_bin, "-s", "format", "bmp", str(image_path), "--out", str(bmp_path)],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            w, h, pixels = _decode_bmp_rgb(bmp_path)
            return w, h, pixels, "macOS_sips_bmp"

    raise RuntimeError(
        "Neither Pillow (`PIL`) nor macOS `sips` is available to decode JPEG map image."
    )


def _decode_bmp_rgb(bmp_path: Path) -> Tuple[int, int, List[Tuple[int, int, int]]]:
    data = bmp_path.read_bytes()
    if data[:2] != b"BM":
        raise ValueError("Invalid BMP header")
    pixel_offset = struct.unpack_from("<I", data, 10)[0]
    width, height = struct.unpack_from("<ii", data, 18)
    bpp = struct.unpack_from("<H", data, 28)[0]
    if bpp not in (24, 32):
        raise ValueError(f"Unsupported BMP bpp={bpp}; expected 24 or 32")

    top_down = height < 0
    abs_h = abs(height)
    bytes_per_px = bpp // 8
    row_stride = ((width * bytes_per_px + 3) // 4) * 4

    pixels: List[Tuple[int, int, int]] = [(0, 0, 0)] * (width * abs_h)
    for row in range(abs_h):
        src_row = row if top_down else (abs_h - 1 - row)
        row_start = pixel_offset + src_row * row_stride
        out_base = row * width
        for col in range(width):
            px_off = row_start + col * bytes_per_px
            b = data[px_off]
            g = data[px_off + 1]
            r = data[px_off + 2]
            pixels[out_base + col] = (r, g, b)
    return width, abs_h, pixels


def classify_pixel_terrain(r: int, g: int, b: int) -> Tuple[str, float]:
    """Classifies RGB map color into land/red_line/ocean & normalized elevation weight [0..1]."""
    # Red Line is painted in warm crimson/terracotta browns (high R, lower B, moderate G)
    if r > 95 and (r - b) > 38 and r >= g:
        return "red_line_pixel", min(1.0, (r - b) / 140.0)
    # Islands are olive/forest green, tan desert, or snowy white
    if (g > b + 12 and g >= 70) or (r > 130 and g > 110 and b < 110):
        return "island_land", min(1.0, (max(r, g) - b) / 130.0)
    # Bright snow/white highlands
    if r > 175 and g > 175 and b > 175:
        return "island_land", 0.9
    return "ocean", 0.0


def extract_spherical_metadata() -> Dict[str, object]:
    if not SOURCE_MAP_PATH.exists():
        raise FileNotFoundError(f"Reference map image not found: {SOURCE_MAP_PATH}")

    img_w, img_h, pixels, decoder_used = load_rgb_image(SOURCE_MAP_PATH)

    counts = {
        "red_line": 0,
        "grand_line_paradise": 0,
        "grand_line_new_world": 0,
        "calm_belt": 0,
        "island_land": 0,
        "ocean": 0,
    }

    # Store compact 2-char biome code rows + notable elevated island samples
    # Biome codes: 'R' = Red Line (+10,000m), 'P' = Paradise, 'N' = New World,
    #              'C' = Calm Belt, 'L' = Island Land, 'O' = Open Blue Ocean
    grid_rows: List[str] = []
    island_samples: List[Dict[str, object]] = []

    for lat_idx in range(GRID_LAT_CELLS):
        # Center of 2-deg cell from +89 deg down to -89 deg
        lat_deg = 89.0 - lat_idx * 2.0
        # Map image v in [0, 1)
        py = min(img_h - 1, max(0, int(((90.0 - lat_deg) / 180.0) * img_h)))
        row_chars: List[str] = []

        for lon_idx in range(GRID_LON_CELLS):
            lon_deg = -179.0 + lon_idx * 2.0
            # Shift reference map projection so lon=0 (Reverse Mountain) sits near image center (u=0.5)
            u_norm = ((lon_deg + 180.0) % 360.0) / 360.0
            px = min(img_w - 1, max(0, int(u_norm * img_w)))
            r, g, b = pixels[py * img_w + px]

            unit_dir = _lat_lon_to_unit_sphere(lat_deg, lon_deg)
            dist_rl_m = abs(PLANET_RADIUS_M * math.asin(max(-1.0, min(1.0, _dot(unit_dir, RED_LINE_NORMAL)))))
            dist_gl_m = abs(PLANET_RADIUS_M * math.asin(max(-1.0, min(1.0, _dot(unit_dir, GRAND_LINE_NORMAL)))))

            pix_class, elev_weight = classify_pixel_terrain(r, g, b)

            # Combine analytical 64-bit Great-Circle geodesy with pixel land masks
            if dist_rl_m <= RED_LINE_HALF_WIDTH_M:
                counts["red_line"] += 1
                row_chars.append("R")
            elif dist_gl_m <= GRAND_LINE_HALF_WIDTH_M:
                if lon_deg >= 0.0:
                    counts["grand_line_paradise"] += 1
                    row_chars.append("P")
                else:
                    counts["grand_line_new_world"] += 1
                    row_chars.append("N")
                if pix_class == "island_land":
                    island_samples.append({
                        "lat_deg": lat_deg,
                        "lon_deg": lon_deg,
                        "zone": "grand_line",
                        "est_elevation_m": round(150.0 + elev_weight * 1_850.0, 1),
                    })
            elif dist_gl_m <= CALM_BELT_OUTER_OFFSET_M:
                counts["calm_belt"] += 1
                row_chars.append("C")
            elif pix_class in ("island_land", "red_line_pixel"):
                counts["island_land"] += 1
                row_chars.append("L")
                island_samples.append({
                    "lat_deg": lat_deg,
                    "lon_deg": lon_deg,
                    "zone": "four_blues",
                    "est_elevation_m": round(80.0 + elev_weight * 920.0, 1),
                })
            else:
                counts["ocean"] += 1
                row_chars.append("O")

        grid_rows.append("".join(row_chars))

    metadata = {
        "project": "Project Blue Planet",
        "source_image": str(SOURCE_MAP_PATH),
        "source_dimensions_px": {"width": img_w, "height": img_h},
        "decoder_used": decoder_used,
        "planet_geodesy": {
            "radius_m": PLANET_RADIUS_M,
            "circumference_m": round(2.0 * math.pi * PLANET_RADIUS_M, 2),
            "red_line_tilt_deg": 45.0,
            "red_line_width_m": 250_000.0,
            "red_line_elevation_m": 10_000.0,
            "grand_line_tilt_deg": -45.0,
            "grand_line_width_m": 600_000.0,
            "calm_belt_width_m": 150_000.0,
            "node_a_reverse_mountain": {"lat_deg": 0.0, "lon_deg": 0.0, "summit_m": 5_000.0},
            "node_b_mary_geoise_fishman": {
                "lat_deg": 0.0,
                "lon_deg": 180.0,
                "mary_geoise_m": 10_000.0,
                "sabaody_m": 0.0,
                "fish_man_island_m": -10_000.0,
            },
        },
        "grid_spec": {
            "lon_cells": GRID_LON_CELLS,
            "lat_cells": GRID_LAT_CELLS,
            "cell_size_deg": 2.0,
            "total_sectors": GRID_LON_CELLS * GRID_LAT_CELLS,
            "legend": {
                "R": "Red Line (+10,000m Great Circle)",
                "P": "Grand Line Paradise (lon 0..180 deg)",
                "N": "Grand Line New World (lon 180..360 deg)",
                "C": "Calm Belt (0 m/s wind, Sea King zone)",
                "L": "Outer Four Blues Island Landmass",
                "O": "Blue Sea Open Ocean",
            },
        },
        "sector_counts": counts,
        "elevated_island_sample_count": len(island_samples),
        "elevated_island_samples": island_samples[:250],
        "biome_grid_rows": grid_rows,
    }
    return metadata


def main() -> None:
    OUTPUT_JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    metadata = extract_spherical_metadata()
    OUTPUT_JSON_PATH.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(f"Generated {OUTPUT_JSON_PATH}")
    print(f"Source: {metadata['source_dimensions_px']} via {metadata['decoder_used']}")
    print(f"Sector counts (total 16,200): {metadata['sector_counts']}")
    print(f"Elevated island samples recorded: {metadata['elevated_island_sample_count']}")


if __name__ == "__main__":
    main()
