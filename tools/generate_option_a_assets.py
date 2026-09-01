"""Shadow Rift - OPTION A production asset generator (entry point).

Characters compile from committed Option A high-detail masters under
art_source/option_a_masters (Godot-ignored). Environment/UI/VFX remain
the deterministic local generators. Output paths and Godot animation
contracts stay stable.

Run: python tools/generate_option_a_assets.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from build_high_detail_characters import build_all_sheets  # noqa: E402
from oa_world_ui import build_all as build_world_ui  # noqa: E402
from oa_resources import build_all as build_resources  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "build" / "reports"

GAP_REPORT = """Option A asset gap report

High-detail source masters are character poses only:
  hero idle/run/jump/slash/magic, warden, wraith, rift warden boss.

Kept from the deterministic local generators (no truthful better source):
  environment tiles, parallax sky/ruins/mist, rune platform, spike hazard
  HUD frame/bars/icons, joystick and action buttons
  slash, skill, projectile, hit-spark, and dust VFX

Do not flatten screenshots into fake sprites or tiles.
"""


def write_gap_report() -> None:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    path = REPORT_DIR / "option-a-asset-gap.txt"
    path.write_text(GAP_REPORT, encoding="utf-8")
    print(f"wrote {path.relative_to(ROOT)}")


def main() -> int:
    print("Generating OPTION A production assets (high-detail character masters)...")
    build_all_sheets()
    build_world_ui()
    build_resources()
    write_gap_report()
    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
