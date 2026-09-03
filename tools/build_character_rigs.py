"""Build deterministic cutout atlases for native Godot 2D character rigs.

The source remains the committed Option A high-detail master art. This tool
creates six transparent layers per pose (body, head, back/front arms and
back/front legs) so Godot can articulate actual limbs with AnimationPlayer
instead of rotating an entire static character image.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

from build_high_detail_characters import (
    BOSS_CELL,
    ENEMY_CELL,
    HERO_CELL,
    frame,
    load_master,
    release_master,
    validate_sources,
)

ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "build" / "reports"
PART_NAMES = ("body", "head", "arm_back", "arm_front", "leg_back", "leg_front")

POSES = {
    "hero/idle_parts.png": ("hero_idle", HERO_CELL, (-96.0, -129.0), 64.0 / 192.0),
    "hero/run_parts.png": ("hero_run", HERO_CELL, (-96.0, -129.0), 64.0 / 192.0),
    "hero/jump_parts.png": ("hero_jump", HERO_CELL, (-96.0, -129.0), 64.0 / 192.0),
    "hero/slash_parts.png": ("hero_slash", HERO_CELL, (-96.0, -129.0), 64.0 / 192.0),
    "hero/magic_parts.png": ("hero_magic", HERO_CELL, (-96.0, -129.0), 64.0 / 192.0),
    "enemies/warden_parts.png": ("warden", ENEMY_CELL, (-96.0, -126.0), 64.0 / 192.0),
    "enemies/wraith_parts.png": ("wraith", ENEMY_CELL, (-96.0, -126.0), 64.0 / 192.0),
    "enemies/rift_warden_parts.png": ("boss", BOSS_CELL, (-128.0, -206.0), 128.0 / 256.0),
}

IMPORT_TEXT = """[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[deps]\n\nsource_file=\"res://{path}\"\n\n[params]\n\ncompress/mode=0\ncompress/high_quality=false\ncompress/lossy_quality=0.7\ncompress/hdr_compression=1\ncompress/normal_map=0\ncompress/channel_pack=0\nmipmaps/generate=false\nmipmaps/limit=-1\nroughness/mode=0\nroughness/src_normal=\"\"\nprocess/fix_alpha_border=true\nprocess/premult_alpha=false\nprocess/normal_map_invert_y=false\nprocess/hdr_as_srgb=false\nprocess/hdr_clamp_exposure=false\nprocess/size_limit=0\ndetect_3d/compress_to=1\n"""


def _polygon_mask(size: tuple[int, int], points: list[tuple[float, float]]) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon([(int(x), int(y)) for x, y in points], fill=255)
    return mask.filter(ImageFilter.GaussianBlur(1.0))


def _ellipse_mask(size: tuple[int, int], box: tuple[float, float, float, float]) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).ellipse(tuple(int(v) for v in box), fill=255)
    return mask.filter(ImageFilter.GaussianBlur(1.0))


def _clip_mask(mask: Image.Image, alpha: Image.Image) -> Image.Image:
    return ImageChops.multiply(mask, alpha)


def _subject_geometry(image: Image.Image) -> tuple[float, float, float, float, float, float]:
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value >= 28 else 0).getbbox()
    if bbox is None:
        raise RuntimeError("rig source has no visible subject")
    left, top, right, bottom = map(float, bbox)
    width = max(1.0, right - left)
    height = max(1.0, bottom - top)
    return left, top, right, bottom, width, height


def split_parts(image: Image.Image) -> list[Image.Image]:
    """Split a keyed full-body pose into alpha-exclusive cutout layers.

    Regions are normalized to the detected subject bounds. Lower-leg masks
    intentionally start below the hip/cape region so locomotion never drags a
    large painted cloth/thigh silhouette through rotational resampling.
    """
    image = image.convert("RGBA")
    alpha = image.getchannel("A")
    left, top, right, bottom, width, height = _subject_geometry(image)
    cx = (left + right) * 0.5

    head = _ellipse_mask(
        image.size,
        (cx - width * 0.27, top - height * 0.01, cx + width * 0.27, top + height * 0.34),
    )
    arm_back = _polygon_mask(
        image.size,
        [
            (cx - width * 0.04, top + height * 0.25),
            (left - width * 0.03, top + height * 0.22),
            (left - width * 0.03, top + height * 0.72),
            (cx - width * 0.08, top + height * 0.66),
        ],
    )
    arm_front = _polygon_mask(
        image.size,
        [
            (cx + width * 0.04, top + height * 0.25),
            (right + width * 0.03, top + height * 0.22),
            (right + width * 0.03, top + height * 0.72),
            (cx + width * 0.08, top + height * 0.66),
        ],
    )
    leg_back = _polygon_mask(
        image.size,
        [
            (cx - width * 0.015, top + height * 0.67),
            (left + width * 0.22, top + height * 0.64),
            (left + width * 0.11, bottom + height * 0.01),
            (cx - width * 0.04, bottom + height * 0.01),
        ],
    )
    leg_front = _polygon_mask(
        image.size,
        [
            (cx + width * 0.015, top + height * 0.67),
            (right - width * 0.22, top + height * 0.64),
            (right - width * 0.11, bottom + height * 0.01),
            (cx + width * 0.04, bottom + height * 0.01),
        ],
    )

    raw_masks = [head, arm_back, arm_front, leg_back, leg_front]
    # Production cutouts must be alpha-exclusive. The previous implementation
    # kept overlapping source pixels in multiple moving layers to hide seams;
    # once those layers rotated, the duplicated semi-transparent pixels read as
    # a blurred afterimage/ghost. Partition the original alpha exactly once.
    remaining = alpha.copy()
    clipped: list[Image.Image] = []
    for mask in raw_masks:
        part_alpha = _clip_mask(mask, remaining)
        clipped.append(part_alpha)
        remaining = ImageChops.subtract(remaining, part_alpha)
    body_alpha = remaining

    parts: list[Image.Image] = []
    for part_alpha in [body_alpha, *clipped]:
        part = image.copy()
        part.putalpha(part_alpha)
        parts.append(part)
    if len(parts) != len(PART_NAMES):
        raise RuntimeError("cutout part contract mismatch")
    return parts


def _write_atlas(parts: list[Image.Image], cell: int, output: Path) -> None:
    atlas = Image.new("RGBA", (cell * len(parts), cell), (0, 0, 0, 0))
    for index, part in enumerate(parts):
        atlas.alpha_composite(part, (index * cell, 0))
    output.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output)
    rel = output.relative_to(ROOT).as_posix()
    output.with_suffix(output.suffix + ".import").write_text(IMPORT_TEXT.format(path=rel), encoding="utf-8")
    print(f"wrote {rel} {atlas.width}x{atlas.height}")


def _opaque_fraction(image: Image.Image) -> float:
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8)
    return float(np.count_nonzero(alpha > 28) / alpha.size)


def _alpha_overlap_max(source: Image.Image, parts: list[Image.Image]) -> int:
    source_alpha = np.asarray(source.getchannel("A"), dtype=np.int16)
    combined = np.zeros_like(source_alpha, dtype=np.int16)
    for part in parts:
        combined += np.asarray(part.getchannel("A"), dtype=np.int16)
    return int(np.maximum(combined - source_alpha, 0).max(initial=0))


def build_all_rigs() -> None:
    validate_sources()
    manifest: dict[str, object] = {"parts": list(PART_NAMES), "poses": {}}
    qa_tiles: list[Image.Image] = []

    for relative, (master_name, cell, base_offset, base_scale) in POSES.items():
        canonical = frame(load_master(master_name), cell)
        parts = split_parts(canonical)
        overlap_max = _alpha_overlap_max(canonical, parts)
        if overlap_max > 1:
            raise RuntimeError(f"rig alpha overlap for {relative}: {overlap_max}")
        output = ROOT / "assets" / "rig" / relative
        _write_atlas(parts, cell, output)
        visible_parts = sum(1 for part in parts[1:] if _opaque_fraction(part) > 0.002)
        if visible_parts < 3:
            raise RuntimeError(f"rig split too sparse for {relative}: {visible_parts} articulated parts")
        manifest["poses"][relative] = {
            "source": master_name,
            "cell": cell,
            "atlas_width": cell * len(parts),
            "base_offset": list(base_offset),
            "base_scale": base_scale,
            "articulated_parts": visible_parts,
            "alpha_overlap_max": overlap_max,
        }
        qa_tiles.append(Image.open(output).convert("RGBA"))
        release_master(master_name)

    manifest_path = ROOT / "assets" / "rig" / "rig_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    thumb_h = 128
    thumbs: list[Image.Image] = []
    for tile in qa_tiles:
        ratio = thumb_h / tile.height
        thumbs.append(tile.resize((int(tile.width * ratio), thumb_h), Image.Resampling.LANCZOS))
    width = max(tile.width for tile in thumbs)
    sheet = Image.new("RGBA", (width, thumb_h * len(thumbs)), (20, 22, 30, 255))
    for row, tile in enumerate(thumbs):
        sheet.alpha_composite(tile, (0, row * thumb_h))
    qa_path = REPORT_DIR / "qa_cutout_rigs.png"
    sheet.save(qa_path)
    print(f"wrote {qa_path.relative_to(ROOT)}")


def main() -> int:
    build_all_rigs()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
