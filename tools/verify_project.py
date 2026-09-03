from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "project.godot",
    "export_presets.cfg",
    "scenes/game.tscn",
    "scripts/player/player.gd",
    "scripts/animation/character_motion_rig.gd",
    "scripts/input/mobile_controls.gd",
    "scripts/combat/combat_authority.gd",
    "scripts/world/game_world.gd",
    "scripts/world/stage_catalog.gd",
    "scripts/world/zone_builder.gd",
    "scripts/world/hazard.gd",
    "scripts/level/level_config.gd",
    "scripts/level/level_manager.gd",
    "scripts/world/level_root.gd",
    "scripts/platform/moving_platform.gd",
    "scripts/world/checkpoint.gd",
    "scripts/world/killzone.gd",
    "scripts/world/level_exit.gd",
    "scripts/platform/squash_stretch.gd",
    "scripts/platform/camera_effects.gd",
    "scripts/enemies/enemy_controller.gd",
    "scripts/enemies/boss_controller.gd",
    "scripts/progression/player_profile.gd",
    "scripts/persistence/save_repository.gd",
    "scripts/performance/reusable_pool.gd",
    "scripts/ui/game_hud.gd",
    "tests/test_runner.gd",
    "tools/build_unsigned_ios.sh",
    "tools/build_character_rigs.py",
    "THIRD_PARTY_NOTICES.md",
    "docs/arch/engine-donors.md",
]

PRODUCTION_ASSETS = [
    "assets/rig/hero/idle_parts.png",
    "assets/rig/hero/run_parts.png",
    "assets/rig/hero/jump_parts.png",
    "assets/rig/hero/slash_parts.png",
    "assets/rig/hero/magic_parts.png",
    "assets/rig/enemies/warden_parts.png",
    "assets/rig/enemies/wraith_parts.png",
    "assets/rig/enemies/rift_warden_parts.png",
    "assets/rig/rig_manifest.json",
    "assets/environment/rift_zone_tiles.png",
    "assets/environment/rift_zone_tileset.tres",
    "assets/environment/bg_sky.png",
    "assets/environment/bg_ruins.png",
    "assets/environment/bg_foreground_mist.png",
    "assets/environment/platform_rune.png",
    "assets/environment/hazard_spikes.png",
    "assets/ui/hud_frame.png",
    "assets/ui/bar_under.png",
    "assets/ui/hp_fill.png",
    "assets/ui/mp_fill.png",
    "assets/ui/exp_fill.png",
    "assets/ui/boss_fill.png",
    "assets/ui/icon_rust_blade.png",
    "assets/ui/icon_rift_saber.png",
    "assets/ui/icon_ash_vest.png",
    "assets/ui/icon_warden_mail.png",
    "assets/ui/joystick_base.png",
    "assets/ui/joystick_knob.png",
    "assets/ui/button_attack.png",
    "assets/ui/button_jump.png",
    "assets/ui/button_skill_1.png",
    "assets/ui/button_skill_2.png",
    "assets/ui/button_pause.png",
    "assets/vfx/slash_1.png",
    "assets/vfx/slash_2.png",
    "assets/vfx/skill_one_slash.png",
    "assets/vfx/skill_two_projectile.png",
    "assets/vfx/wraith_bolt.png",
    "assets/vfx/hit_spark.png",
    "assets/vfx/dust.png",
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
    for relative in PRODUCTION_ASSETS:
        require((ROOT / relative).is_file(), f"missing production asset {relative}")
    require((ROOT / "tools/report_mobile_memory.py").is_file(), "mobile memory report tool missing")
    require((ROOT / "tools/check_elf_alignment.py").is_file(), "16 KB ELF alignment check tool missing")
    require((ROOT / "art_source/.gdignore").is_file(), "art source must stay Godot-ignored")
    masters = ROOT / "art_source/option_a_masters"
    require((masters / ".gdignore").is_file(), "Option A high-detail masters must stay Godot-ignored")
    for source_name in ("knight-combat.jpg", "dragon.jpg", "keep-gate.jpg", "courtyard-far.jpg", "hud-ref.jpg", "courtyard.jpg", "knight.jpg", "title.jpg"):
        require((masters / source_name).is_file(), f"missing Option A high-detail master {source_name}")
    generator = (ROOT / "tools/generate_option_a_assets.py").read_text(encoding="utf-8")
    require("build_character_rigs" in generator and "build_all_sheets" not in generator and "oa_characters" not in generator, "fake whole-sprite animation generator is still active")
    require(not (ROOT / "tools/oa_characters.py").exists(), "obsolete procedural character generator remained")
    for obsolete in ("assets/sprites/hero/hero_sheet.png", "assets/sprites/hero/hero_frames.tres", "assets/sprites/enemies/warden_sheet.png", "assets/sprites/enemies/warden_frames.tres", "assets/sprites/enemies/wraith_sheet.png", "assets/sprites/enemies/wraith_frames.tres", "assets/sprites/enemies/rift_warden_sheet.png", "assets/sprites/enemies/rift_warden_frames.tres"):
        require(not (ROOT / obsolete).exists(), f"obsolete whole-sprite animation asset remained: {obsolete}")
    rig_manifest = (ROOT / "assets/rig/rig_manifest.json").read_text(encoding="utf-8")
    require('"parts"' in rig_manifest and '"articulated_parts"' in rig_manifest, "cutout rig manifest missing")
    require((ROOT / "THIRD_PARTY_NOTICES.md").is_file(), "donor provenance missing")
    require((ROOT / "docs/arch/engine-donors.md").is_file(), "donor research matrix missing")
    require(not (ROOT / "_vendor").exists() and not (ROOT / "shadowrift-engine-donors").exists(), "donor repo vendored into game")
    notices = (ROOT / "THIRD_PARTY_NOTICES.md").read_text(encoding="utf-8")
    donor_doc = (ROOT / "docs/arch/engine-donors.md").read_text(encoding="utf-8")
    require("template-2d-platformer" in notices and "godot-platformer-toolkit" in notices, "donor attribution incomplete")
    require("godot-demo-projects" in notices and "Windy-Codes/2d-platformer-template" in notices, "animation/retry donor attribution incomplete")
    require("crystal-trails" in donor_doc and "0db80ca5fd22" in donor_doc and "7d7aa62dbd76" in donor_doc, "animation donor decision matrix incomplete")
    for png in sorted((ROOT / "assets").rglob("*.png")):
        import_file = png.with_suffix(".png.import")
        require(import_file.is_file(), f"missing pinned import settings for {png.relative_to(ROOT).as_posix()}")
        import_text = import_file.read_text(encoding="utf-8")
        require("mipmaps/generate=false" in import_text, f"unexpected mipmaps enabled for {png.name}")
        require("compress/mode=0" in import_text, f"unexpected non-lossless compression for {png.name}")
    referenced_paths = set()
    for pattern in ("scripts/**/*.gd", "tests/**/*.gd", "scenes/*.tscn", "assets/**/*.tres", "*.godot"):
        for path in ROOT.glob(pattern):
            if not path.is_file():
                continue
            for match in re.finditer(r"res://(assets/[A-Za-z0-9_./-]+)", path.read_text(encoding="utf-8", errors="ignore")):
                referenced_paths.add(match.group(1))
    for referenced in sorted(referenced_paths):
        require((ROOT / referenced).is_file(), f"referenced asset does not exist: {referenced}")
    require(not (ROOT / "server").exists(), "v1 server directory must be removed")
    require(not (ROOT / "scripts/network/server_authority_client.gd").exists(), "network authority client must be removed")
    require(not (ROOT / ".github/workflows/deploy-server.yml").exists(), "server deploy workflow must be removed")
    require(not (ROOT / "tools/configure_android_ci.gd").exists(), "dead Android editor configuration script must be removed")
    require(not (ROOT / "web").exists(), "rejected web workspace must not exist")

    for path in ROOT.glob("scripts/**/*.gd"):
        check_balanced_delimiters(path)
    runtime_text = "\n".join(path.read_text(encoding="utf-8") for path in ROOT.glob("scripts/**/*.gd"))
    require("server_authoritative" not in runtime_text, "server-authoritative runtime path leaked into v1")
    require(not re.search(r"\b(gacha|diamond|iap|quest|critical_hit|cooldown_reduction|god_mode|cheat_menu)\b", runtime_text, re.I), "v2 or cheat behavior leaked into v1 runtime")

    project_settings = (ROOT / "project.godot").read_text(encoding="utf-8")
    require("run/max_fps=60" in project_settings, "60 fps lock missing")
    require("window/handheld/orientation=0" in project_settings, "mobile landscape lock missing")
    require('window/stretch/aspect="expand"' in project_settings, "wide-screen expand stretch missing")
    require("pointing/emulate_touch_from_mouse=true" in project_settings, "desktop/editor touch emulation missing")
    require("server/base_url" not in project_settings and "workers.dev" not in project_settings, "server endpoint remained in project settings")
    require("textures/canvas_textures/default_texture_filter=1" in project_settings, "linear texture filtering missing for vector art")
    require("TileMapLayer" in runtime_text, "TileMapLayer zone missing")
    require("checksum_for" in runtime_text and "save_checksum_mismatch" in runtime_text, "save integrity checks missing")
    save_repo = (ROOT / "scripts/persistence/save_repository.gd").read_text(encoding="utf-8")
    level_manager = (ROOT / "scripts/level/level_manager.gd").read_text(encoding="utf-8")
    require("SCHEMA_VERSION := 2" in save_repo, "save schema v2 migration missing")
    require("_migrate_v1_to_v2" in save_repo, "save migration missing")
    require("_checkpoint_to_vector" in save_repo and "str_to_var" in save_repo, "checkpoint save compatibility normalization missing")
    require('"checkpoint": {"x": last_checkpoint_position.x, "y": last_checkpoint_position.y}' in level_manager, "checkpoint must persist as JSON-safe coordinates")
    require("get_canonical_attack_power" in runtime_text and "_canonical_attack" in runtime_text, "canonical local combat boundary missing")
    require("DRAW_CALL_BUDGET := 50" in runtime_text, "draw-call budget missing")

    player = (ROOT / "scripts/player/player.gd").read_text(encoding="utf-8")
    rig = (ROOT / "scripts/animation/character_motion_rig.gd").read_text(encoding="utf-8")
    require("CharacterMotionRig2D" in player and "AnimatedSprite2D" not in player and "hero_frames.tres" not in player, "hero must render through the articulated motion rig")
    require("Skeleton2D" in rig and "Bone2D" in rig and "AnimationPlayer" in rig and "leg_back" in rig and "leg_front" in rig, "native articulated rig contract missing")
    require("attack1" in rig and "attack2" in rig and "jump_rise" in rig and "fall" in rig and "land" in rig, "hero articulated animation states missing")
    require('&"leg_back": [-3.0, -1.0, 3.0, 1.0, -3.0]' in rig and '&"leg_front": [3.0, 1.0, -3.0, -1.0, 3.0]' in rig, "hero locomotion leg rotation must stay low-angle to avoid cutout smear")
    require('&"leg_back": [Vector2(3, 0)' in rig and '&"leg_front": [Vector2(-3, 0)' in rig, "hero locomotion opposite-phase leg translation missing")
    require("COYOTE_TIME" in player and "JUMP_BUFFER_TIME" in player, "mobile traversal jump tuning missing")
    require("GRAVITY_RISE" in player and "GRAVITY_FALL" in player and "JUMP_CUT_FACTOR" in player and "TURN_BOOST" in player, "donor player game-feel constants missing")
    require("MovingPlatform" in (ROOT / "scripts/world/game_world.gd").read_text(encoding="utf-8") or "LevelManager" in (ROOT / "scripts/world/game_world.gd").read_text(encoding="utf-8"), "data-driven level manager missing from game world")
    require("LevelConfig" in (ROOT / "scripts/level/level_config.gd").read_text(encoding="utf-8") and "LevelManager" in (ROOT / "scripts/level/level_manager.gd").read_text(encoding="utf-8"), "level config/manager missing")
    require("slash_1.png" in player and "slash_2.png" in player and "skill_one_slash.png" in player, "hero slash VFX assets missing")
    require("dust.png" in player, "hero run dust asset missing")
    enemies = (ROOT / "scripts/enemies/enemy_controller.gd").read_text(encoding="utf-8")
    boss = (ROOT / "scripts/enemies/boss_controller.gd").read_text(encoding="utf-8")
    require("CharacterMotionRig2D" in enemies and "AnimatedSprite2D" not in enemies, "enemy articulated rig integration missing")
    require("CharacterMotionRig2D" in boss and "AnimatedSprite2D" not in boss, "boss articulated rig integration missing")
    require("windup" in rig and "strike" in rig, "boss telegraph/strike articulated animations missing")
    for actor_script in (player, enemies, boss):
        require("draw_colored_polygon" not in actor_script, "procedural character drawing remained")
        require("func _draw()" not in actor_script, "procedural character _draw remained")

    zone = (ROOT / "scripts/world/zone_builder.gd").read_text(encoding="utf-8")
    require("Image.create" not in zone, "runtime procedural tile generation remained")
    require("rift_zone_tileset.tres" in zone, "zone must load the imported TileSet resource")
    require("platform_rune.png" in zone, "rune platform texture missing")
    hazard = (ROOT / "scripts/world/hazard.gd").read_text(encoding="utf-8")
    require("hazard_spikes.png" in hazard and "func _draw()" not in hazard, "hazard must render through the spikes texture")
    world = (ROOT / "scripts/world/game_world.gd").read_text(encoding="utf-8")
    require("Parallax2D" in world and "bg_sky.png" in world and "bg_ruins.png" in world and "bg_foreground_mist.png" in world, "parallax background layers missing")
    require("draw_circle" not in world and "draw_colored_polygon" not in world, "procedural world background drawing remained")
    require("hit_spark.png" in world, "hit spark VFX missing")

    presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    require('name="Android PreRelease"' in presets and 'name="iOS PreRelease"' in presets, "pre-release mobile presets missing")
    require(presets.count('custom_features="mobile"') == 2, "mobile presets must use the same local runtime")
    require("server_authoritative" not in presets, "server-authoritative export feature remained")
    android_version = re.search(r'^version/name="([^"]+)"$', presets, re.M)
    ios_version = re.search(r'^application/short_version="([^"]+)"$', presets, re.M)
    require(android_version is not None and ios_version is not None, "mobile pre-release version metadata missing")
    require(android_version.group(1) == ios_version.group(1) and android_version.group(1) != "0.0.0", "Android/iOS pre-release versions must match")
    require('application/app_store_team_id="CIUNSIGNED"' in presets, "unsigned iOS CI sentinel missing")

    controls = (ROOT / "scripts/input/mobile_controls.gd").read_text(encoding="utf-8")
    require("signal pause_requested" in controls and "PROCESS_MODE_ALWAYS" in controls, "pause control must remain responsive while paused")
    require('"jump": -1' in controls and '"jump": false' in controls, "mobile jump action missing")
    require("_held_actions" in controls and "_released_actions" in controls and "consume_action_released" in controls, "mobile press/hold/release semantics missing")
    require("get_display_safe_area" in controls and "scale_safe_area" in controls, "mobile safe-area mapping missing")
    require("reset_inputs" in controls and "NOTIFICATION_APPLICATION_PAUSED" in controls, "mobile lifecycle input reset missing")
    require("joystick_base.png" in controls and "joystick_knob.png" in controls, "joystick textures missing")
    require("button_attack.png" in controls and "button_jump.png" in controls and "button_skill_1.png" in controls and "button_skill_2.png" in controls, "action button textures missing")
    require("button_pause.png" in controls, "pause button texture missing")
    require("TextureRect" in controls and "func _draw()" not in controls, "mobile controls must render through texture visuals")

    hud = (ROOT / "scripts/ui/game_hud.gd").read_text(encoding="utf-8")
    require("get_display_safe_area" in hud, "HUD safe-area handling missing")
    require("SERVER REQUIRED" not in hud and "set_network_status" not in hud, "obsolete server HUD remained")
    require("set_pause_state" in hud and "PAUSED" in hud, "HUD pause overlay missing")
    require("signal retry_requested" in hud and "DEFEATED" in hud and "show_defeat" in hud and "RETRY" in hud, "HUD defeat/retry flow missing")
    require("TextureProgressBar" in hud and "hud_frame.png" in hud, "HUD must use native texture controls")
    require("icon_rust_blade.png" in hud and "icon_rift_saber.png" in hud and "icon_ash_vest.png" in hud and "icon_warden_mail.png" in hud, "equipment catalog icons missing")

    world = (ROOT / "scripts/world/game_world.gd").read_text(encoding="utf-8")
    require("_toggle_user_pause" in world and "get_tree().paused = _paused_by_user" in world, "world pause/resume contract missing")
    require("StageCatalog.count()" in world and "_load_stage" in world, "three-stage progression flow missing")
    require("_stage_advance_token" in world and "_advancing_stage" in world and "_schedule_stage_advance" in world, "stage-advance idempotency guard missing")
    require("create_timer(0.66, false)" in world and "create_timer(delay, false)" in world and "create_timer(0.28, false)" in world, "gameplay timers must pause with SceneTree")
    require("_on_hero_died" in world and "_enter_defeat_state" in world and "_retry_from_defeat" in world and "respawn_at" in world, "explicit death/retry flow missing")
    require("_run_defeated" in world and "set_gameplay_enabled(false)" in world, "defeat input lock missing")
    require("visible = true" in player and "_rig.visible = true" in player and "modulate = Color.WHITE" in player, "death/retry visibility recovery missing")
    require('payload["health"] = int(snapshot.max_health)' in world, "dead-safe persistence recovery missing")
    require("_load_progress()" in world and "_save_progress()" in world, "local mobile persistence flow missing")
    require("reset_inputs()" in world and "NOTIFICATION_APPLICATION_FOCUS_OUT" in world, "world lifecycle reset missing")
    require("ServerAuthorityClient" not in world, "network authority remained in game world")

    authority = (ROOT / "scripts/combat/combat_authority.gd").read_text(encoding="utf-8")
    require("server_authoritative" not in authority, "local combat is still disabled on mobile")
    require("resolve_environment_hit" in authority, "hazard damage path missing")
    killzone = (ROOT / "scripts/world/killzone.gd").read_text(encoding="utf-8")
    level_exit = (ROOT / "scripts/world/level_exit.gd").read_text(encoding="utf-8")
    require("hero.die()" in killzone and "resolve_environment_hit" not in killzone, "death-plane Killzone must be terminal")
    require("body_exited.connect" in level_exit and "_triggered = false" in level_exit, "LevelExit re-arm handling missing")
    require("server_authoritative" not in enemies and "server_authoritative" not in boss, "enemy AI is still disabled on mobile")

    projectile = (ROOT / "scripts/performance/projectile.gd").read_text(encoding="utf-8")
    require("skill_two_projectile.png" in projectile and "wraith_bolt.png" in projectile and "activate_homing" in projectile and "func _draw()" not in projectile, "projectile must support player rift bolt plus Wraith homing bolt textures")
    require("WRAITH_HOMING_TIME := 0.38" in projectile and "WRAITH_SPEED := 285.0" in projectile and "WRAITH_MAX_TURN_RATE" in projectile, "Wraith projectile dodgeability limits missing")
    require("_homing_remaining" in projectile and "_target = null" in projectile, "Wraith homing must expire into committed ballistic travel")
    require('set_deferred("monitoring", false)' in projectile and 'call_deferred("deactivate")' in projectile, "projectile monitoring shutdown must be deferred from physics callbacks")
    require("_attack_time = 0.72" in enemies and "_attack_cooldown = 1.55" in enemies, "Wraith readable cast telegraph/cooldown missing")

    tests = (ROOT / "tests/test_runner.gd").read_text(encoding="utf-8")
    require("PASS: 29 behavior tests" in tests and "_test_full_scene_boot_and_pause" in tests, "Godot runtime coverage missing")
    require("_test_true_articulated_rig" in tests and "_test_touch_jump_release" in tests and "_test_defeat_retry_flow" in tests, "articulated animation/retry regression coverage missing")
    require("_test_rig_alpha_exclusive_manifest" in tests and "_test_combat_escape_window" in tests and "_test_wraith_ranged_homing" in tests, "ghosting/combat-escape/Wraith ranged regression coverage missing")
    require("_test_donor_jump_feel" in tests and "_test_moving_platform_carry" in tests, "donor game-feel coverage missing")
    require("_test_checkpoint_activation" in tests and "_test_killzone_recovery" in tests, "checkpoint/killzone coverage missing")
    require("_test_stage_transition_no_duplicates" in tests and "timer plus exit advances exactly one stage" in tests, "stage transition race coverage missing")
    require("_test_save_migration" in tests and "checkpoint survives JSON stringify/parse" in tests and "legacy schema-v2 string checkpoint" in tests, "save checkpoint round-trip coverage missing")
    require("death-plane Killzone is terminal" in tests and "level exit re-arms" in tests, "killzone/exit regression coverage missing")
    require("_test_level_config_data_driven" in tests, "data-driven level coverage missing")
    require("_test_jump_traversal_contract" in tests and "_test_death_respawn_contract" in tests and "_test_stage_catalog_and_progression" in tests, "gameplay completion regression coverage missing")
    require("_test_multitouch_and_safe_area" in tests and "_test_input_reset_on_lifecycle_boundary" in tests, "mobile edge-case coverage missing")
    require("hazard damage resolves through local authority" in tests, "mobile hazard regression coverage missing")
    require("_test_production_resources_load" in tests, "production asset coverage missing")

    require((ROOT / ".godot-version").read_text(encoding="utf-8").strip() == "4.7.2", "Godot version pin missing")
    mobile_workflow = (ROOT / ".github/workflows/mobile-build.yml").read_text(encoding="utf-8")
    require("Android PreRelease" in mobile_workflow and "ShadowRift-prerelease.apk" in mobile_workflow, "Android pre-release workflow incomplete")
    require("build_unsigned_ios.sh" in mobile_workflow and "ShadowRift-ios-prerelease-unsigned" in mobile_workflow, "iOS pre-release workflow incomplete")
    verify_workflow = (ROOT / ".github/workflows/verify.yml").read_text(encoding="utf-8")
    require("4.7.2" in verify_workflow and "test_runner.gd" in verify_workflow, "Godot verification workflow incomplete")
    require("working-directory: server" not in verify_workflow and "test:integration" not in verify_workflow, "removed server verification still runs")

    changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    require("local Godot runtime" in changelog and "safe-area" in changelog, "pre-release remediation missing from changelog")
    attributes = (ROOT / ".gitattributes").read_text(encoding="utf-8")
    require("filter=lfs" in attributes, "Git LFS patterns missing")
    print(f"PASS: {len(REQUIRED)} required files, {len(PRODUCTION_ASSETS)} production assets, local runtime, mobile edge cases, exports, docs, LFS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
