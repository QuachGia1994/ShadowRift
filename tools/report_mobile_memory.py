"""Deterministic mobile texture-memory audit for Shadow Rift production assets.

Scans every production image under assets/, reports path, dimensions, source
bytes, estimated decoded RGBA bytes (width * height * 4), asset category,
category totals and a grand total. Flags (review-only, never destructive):
  - dimension > 2048 px on either axis
  - estimated decoded size > 8 MiB for a single texture
  - duplicate content (identical SHA-256)
  - production asset not referenced by any .gd/.tres/.tscn/project.godot
    and not named by the deterministic asset generator contract

Report is written to build/reports/mobile-memory-report.txt (gitignored;
CI uploads it as an artifact). Run:  python tools/report_mobile_memory.py
"""
from __future__ import annotations

import hashlib
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
REPORT_DIR = ROOT / "build" / "reports"
REPORT_PATH = REPORT_DIR / "mobile-memory-report.txt"

MIB = 1024.0 * 1024.0
DIMENSION_FLAG = 2048
DECODED_FLAG = 8.0 * MIB

CATEGORY_BY_PART = (
    ("sprites/hero", "hero"),
    ("sprites/enemies", "enemy"),
    ("environment", "environment"),
    ("ui", "ui"),
    ("vfx", "vfx"),
)


def category_for(relative: str) -> str:
    for needle, category in CATEGORY_BY_PART:
        if needle in relative:
            return category
    return "other"


def reference_corpus() -> str:
    chunks = []
    for pattern in ("scripts/**/*.gd", "tests/**/*.gd", "scenes/*.tscn", "*.godot", "*.tres", "assets/**/*.tres", "tools/generate_option_a_assets.py", "tools/oa_characters.py", "tools/oa_world_ui.py", "tools/oa_resources.py"):
        for path in ROOT.glob(pattern):
            try:
                chunks.append(path.read_text(encoding="utf-8", errors="ignore"))
            except OSError:
                continue
    return "\n".join(chunks)


def main() -> int:
    images = sorted(ASSETS.rglob("*.png"))
    corpus = reference_corpus()
    lines = ["Shadow Rift mobile texture memory report", ""]

    rows = []
    hashes: dict[str, list[str]] = {}
    for path in images:
        relative = path.relative_to(ROOT).as_posix()
        with Image.open(path) as image:
            width, height = image.size
        source_bytes = path.stat().st_size
        decoded = width * height * 4
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        hashes.setdefault(digest, []).append(relative)
        res_path = f"res://{relative}"
        stem_references = path.stem in corpus
        referenced = res_path in corpus or stem_references
        rows.append({
            "path": relative,
            "width": width,
            "height": height,
            "source_bytes": source_bytes,
            "decoded": decoded,
            "category": category_for(relative),
            "referenced": referenced,
        })

    category_totals: dict[str, dict[str, int]] = {}
    for row in rows:
        bucket = category_totals.setdefault(row["category"], {"count": 0, "source": 0, "decoded": 0})
        bucket["count"] += 1
        bucket["source"] += row["source_bytes"]
        bucket["decoded"] += row["decoded"]

    lines.append(f"{'path':58} {'size':>12} {'wxh':>11} {'source':>10} {'decoded':>10} {'cat':>11} refs")
    for row in rows:
        lines.append(
            f"{row['path']:58} {row['width']:>5}x{row['height']:<5} {row['source_bytes']:>10,} {row['decoded']:>10,} {row['category']:>11} {'yes' if row['referenced'] else 'NO'}"
        )

    lines.append("")
    lines.append("Category totals (decoded RGBA estimate):")
    grand_source = 0
    grand_decoded = 0
    for category in sorted(category_totals):
        bucket = category_totals[category]
        grand_source += bucket["source"]
        grand_decoded += bucket["decoded"]
        lines.append(
            f"  {category:12} n={bucket['count']:2}  source={bucket['source']:>10,} B  decoded={bucket['decoded']:>10,} B ({bucket['decoded'] / MIB:.2f} MiB)"
        )
    lines.append(
        f"  {'TOTAL':12} n={len(rows):2}  source={grand_source:>10,} B  decoded={grand_decoded:>10,} B ({grand_decoded / MIB:.2f} MiB)"
    )

    lines.append("")
    lines.append("Review flags:")
    flags = 0
    for row in rows:
        if max(row["width"], row["height"]) > DIMENSION_FLAG:
            flags += 1
            lines.append(f"  [DIM>2048] {row['path']} is {row['width']}x{row['height']}")
        if row["decoded"] > DECODED_FLAG:
            flags += 1
            lines.append(f"  [DECODED>8MiB] {row['path']} decodes to {row['decoded'] / MIB:.2f} MiB")
    for digest, paths in sorted(hashes.items()):
        if len(paths) > 1:
            flags += 1
            lines.append(f"  [DUPLICATE] {' + '.join(paths)}")
    for row in rows:
        if not row["referenced"]:
            flags += 1
            lines.append(f"  [UNREFERENCED] {row['path']}")
    if flags == 0:
        lines.append("  none")
    lines.append("")
    lines.append(f"Flags: {flags} (review-only; no destructive action taken by this tool)")

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {REPORT_PATH.relative_to(ROOT)} ({len(rows)} textures, {grand_decoded / MIB:.2f} MiB decoded, {flags} flags)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
