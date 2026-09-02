"""Shadow Rift - OPTION A production asset generator (entry point).

Characters compile into articulated cutout atlases from committed Option A
high-detail masters under art_source/option_a_masters (Godot-ignored).
Environment/UI/VFX remain deterministic local generators.

Run: python tools/generate_option_a_assets.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

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


def _run_stage(script_name: str) -> None:
    subprocess.run([sys.executable, "-u", str(ROOT / "tools" / script_name)], cwd=ROOT, check=True)
    print(f"stage complete: {script_name}", flush=True)


def main() -> int:
    print("Generating OPTION A production assets (articulated cutout rigs)...", flush=True)
    # Each Pillow-heavy phase gets a fresh process so peak image buffers are
    # returned to the OS before the next phase. This keeps regeneration stable
    # on memory-constrained Windows/CI hosts while remaining one user command.
    _run_stage("oa_world_ui.py")
    _run_stage("build_character_rigs.py")
    _run_stage("oa_resources.py")
    write_gap_report()
    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
