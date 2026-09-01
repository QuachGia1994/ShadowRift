"""Shadow Rift - OPTION A production asset generator (entry point).

Stylized 2D hand-drawn / vector dark fantasy. Deterministic output (fixed seed).
Renders every canonical production texture at 4x supersampling, downscales with
Lanczos for clean anti-aliased vector edges, then emits the Godot SpriteFrames /
TileSet text resources that reference those textures.

Run:  python tools/generate_option_a_assets.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from oa_characters import build_all_sheets  # noqa: E402
from oa_world_ui import build_all  # noqa: E402
from oa_resources import build_all as build_resources  # noqa: E402


def main() -> int:
    print("Generating OPTION A production assets (deterministic seed 20260901)...")
    build_all_sheets()
    build_all()
    build_resources()
    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
