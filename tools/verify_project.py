from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "project.godot",
    "export_presets.cfg",
    "scenes/game.tscn",
    "scripts/player/player.gd",
    "scripts/input/mobile_controls.gd",
    "scripts/combat/combat_authority.gd",
    "scripts/world/zone_builder.gd",
    "scripts/enemies/enemy_controller.gd",
    "scripts/enemies/boss_controller.gd",
    "scripts/progression/player_profile.gd",
    "scripts/persistence/save_repository.gd",
    "scripts/performance/reusable_pool.gd",
    "scripts/network/server_authority_client.gd",
    "server/src/domain.ts",
    "server/src/worker.ts",
    "server/src/domain.test.ts",
    "tests/test_runner.gd",
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def check_balanced_delimiters(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    stack: list[str] = []
    pairs = {")": "(", "]": "[", "}": "{"}
    quote = ""
    escaped = False
    for raw_line in text.splitlines():
        line = raw_line.split("#", 1)[0] if not quote else raw_line
        for char in line:
            if quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = ""
                continue
            if char in {'"', "'"}:
                quote = char
            elif char in "([{":
                stack.append(char)
            elif char in ")]}":
                require(bool(stack) and stack.pop() == pairs[char], f"unbalanced delimiter in {path}")
    require(not quote and not stack, f"unclosed string or delimiter in {path}")


def main() -> int:
    for relative in REQUIRED:
        require((ROOT / relative).is_file(), f"missing {relative}")
    for path in ROOT.glob("scripts/**/*.gd"):
        check_balanced_delimiters(path)
    runtime_text = "\n".join(path.read_text(encoding="utf-8") for path in ROOT.glob("scripts/**/*.gd"))
    require(not re.search(r"\b(gacha|diamond|iap|quest|critical_hit|cooldown_reduction|god_mode|cheat_menu)\b", runtime_text, re.I), "v2 or cheat behavior leaked into v1 runtime")
    require("run/max_fps=60" in (ROOT / "project.godot").read_text(encoding="utf-8"), "60 fps lock missing")
    require("TileMapLayer" in runtime_text, "TileMapLayer zone missing")
    require("checksum_for" in runtime_text and "save_checksum_mismatch" in runtime_text, "save integrity checks missing")
    require("get_canonical_attack_power" in runtime_text and "_canonical_attack" in runtime_text, "canonical combat boundary missing")
    require("DRAW_CALL_BUDGET := 50" in runtime_text, "draw-call budget missing")
    presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    require('platform="Android"' in presets and 'platform="iOS"' in presets, "mobile export presets missing")
    require(presets.count('custom_features="mobile,server_authoritative"') == 2, "mobile exports must require server authority")
    client = (ROOT / "scripts/network/server_authority_client.gd").read_text(encoding="utf-8")
    require("SERVER REQUIRED — GAMEPLAY LOCKED" in runtime_text, "mobile disconnect must fail closed")
    require("SESSION_PATH" in client and "lastSeq" in client, "resumable server session protocol missing")
    authority = (ROOT / "scripts/combat/combat_authority.gd").read_text(encoding="utf-8")
    require(authority.count('OS.has_feature("server_authoritative")') == 3, "local damage paths remain enabled in protected builds")
    domain = (ROOT / "server/src/domain.ts").read_text(encoding="utf-8")
    require("exactKeys" in domain and "sequence_rejected" in domain and "nearestEnemy" in domain, "server command validation missing")
    worker = (ROOT / "server/src/worker.ts").read_text(encoding="utf-8")
    require("DurableObject" in worker and "tokenHash" in worker and "MAX_BODY_BYTES" in worker, "durable authenticated server boundary missing")
    attributes = (ROOT / ".gitattributes").read_text(encoding="utf-8")
    require("filter=lfs" in attributes, "Git LFS patterns missing")
    print(f"PASS: {len(REQUIRED)} required files, delimiter scan, scope, integrity, performance, exports, LFS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
