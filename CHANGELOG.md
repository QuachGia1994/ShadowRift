# Changelog

All notable changes are documented in this file.

## [Unreleased]

### Added

- OPTION A stylized 2D hand-drawn/vector dark-fantasy production art set: hero/warden/wraith/boss sprite sheets with SpriteFrames resources, an imported 32x32 rift TileSet, three parallax background layers (sky/broken moon, ruins, near mist), rune platform and spike hazard textures, dark-fantasy HUD frame/bar/icon textures, texture-based joystick/buttons, and slash/projectile/hit-spark/dust VFX.
- Deterministic asset generator (`tools/generate_option_a_assets.py`) that renders every production texture at 4x supersampling and emits the Godot `.tres` resources.
- Mobile texture-memory audit (`tools/report_mobile_memory.py`) reporting per-texture dimensions, source bytes, estimated decoded RGBA bytes, category totals, and review flags (oversize, duplicates, unreferenced assets); CI generates `build/reports/mobile-memory-report.txt` as an artifact.
- Android pre-release CI reporting for APK bytes, asset source bytes, and decoded texture estimates, plus a 16 KB native page-size ELF alignment check (`tools/check_elf_alignment.py`) over the exported APK.
- Pinned Godot texture import settings for every production texture (lossless compression, mipmaps disabled) matching the 1:1 mobile rendering of the Option A art.
- Static verifier coverage for the production asset tree, SpriteFrames/TileSet resources, native HUD/mobile texture controls, and removal of all procedural character/world drawing.
- Playable Godot 4.7.2 landscape mobile action-RPG vertical slice with Idle/Move/Jump/Attack/Hurt/Death states, a two-hit combo, buffered/coyote-time jump, two skills, Warden and Wraith enemies, a three-stage run (Rift Approach, Broken Keep, Rift Throne), final Rift Warden boss, stage gates, hazards, and reachable one-way platform routes.
- Isolated multi-touch controls with a fixed joystick, independent attack/jump/skill touch ownership, landscape safe-area positioning, and lifecycle reset on app pause or focus loss.
- HP, MP, EXP, level, gold, equipment, boss, pause, and FPS HUD with safe-area-aware positioning.
- Weapon and armor progression with canonical stat recomputation, checksummed local save data, pooled projectiles/damage numbers, and a 50 draw-call runtime budget monitor.
- Android and unsigned iOS pre-release artifacts for version `0.1.0`, plus deterministic source and Godot behavior verification in GitHub Actions.

### Changed

- Hero, Warden, Wraith, and Rift Warden character sheets now compile from Option A high-detail painted masters (backdrop keyed, spill cleaned, feet-anchored) while keeping the existing animation names, frame counts, SpriteFrames paths, and original visual footprint/pivot.
- Hero, Warden, Wraith, and Rift Warden now render through native `AnimatedSprite2D` SpriteFrames with state-mapped animations and independent slash VFX; all procedural `_draw()` character art was removed while preserving movement, combo timing, hitboxes, FSM transitions, cooldowns, and damage exactly.
- The zone renders from an imported TileSet atlas with textured one-way platforms and spike hazard, and the world background uses three `Parallax2D` layers instead of runtime-drawn sky/ridges.
- HUD bars moved to native `TextureProgressBar` controls with catalog equipment icons, and mobile joystick/action buttons render through texture visuals while keeping the original multi-touch ownership, dead-zone, one-shot, and safe-area behavior.
- HUD and mobile-control per-frame updates now cache safe-area layout and label text so unchanged values no longer re-run text shaping or layout every frame.
- Default texture filtering switched to linear so the vector art stays crisp without nearest-neighbor artifacts.
- Mobile gameplay now uses the same local Godot runtime as editor gameplay instead of the former network authority path, removing command round-trip latency and reconnect/pause races from the v1 combat loop.
- Enemy patrol/aggro/attack logic, boss chase/windup/strike logic, hazard damage, movement, jump physics, rewards, equipment, and persistence now execute locally on Android and iOS exactly as they do in editor runs.
- Death now rebuilds the current stage and respawns the hero at its checkpoint instead of leaving a dead actor in place; enemy/boss cleanup waits for complete death animations.
- Enemy and boss attack windows now use horizontal/vertical reach checks plus hitbox sizes/offsets matched to the high-detail painted silhouettes; the boss gains visible windup/strike body motion.
- Pause and application lifecycle transitions clear active touch ownership before gameplay resumes, preventing held/stale mobile input after interruption.
- Export presets are explicitly pre-release presets with `0.1.0` package metadata; iOS CI remains intentionally unsigned and validates bundle/version metadata before packaging.

### Removed

- Cloudflare Worker/Durable Object authority, bearer-session persistence, server reconnect/fallback logic, server deployment workflow, and unused Android editor configuration script from the v1 shipped code path.
