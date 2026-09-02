# Changelog

All notable changes are documented in this file.

## [Unreleased]

### Added

- OPTION A stylized 2D hand-drawn/vector dark-fantasy production art set: articulated Hero/Warden/Wraith/Rift Warden cutout atlases, an imported 32x32 rift TileSet, three parallax background layers (sky/broken moon, ruins, near mist), rune platform and spike hazard textures, dark-fantasy HUD frame/bar/icon textures, texture-based joystick/buttons, and slash/projectile/hit-spark/dust VFX.
- Deterministic asset generator (`tools/generate_option_a_assets.py`) that keys the committed high-detail masters into six-part cutout atlases and regenerates environment/UI/VFX resources without cloud image generation.
- Mobile texture-memory audit (`tools/report_mobile_memory.py`) reporting per-texture dimensions, source bytes, estimated decoded RGBA bytes, category totals, and review flags (oversize, duplicates, unreferenced assets); CI generates `build/reports/mobile-memory-report.txt` as an artifact.
- Android pre-release CI reporting for APK bytes, asset source bytes, and decoded texture estimates, plus a 16 KB native page-size ELF alignment check (`tools/check_elf_alignment.py`) over the exported APK.
- Pinned Godot texture import settings for every production texture (lossless compression, mipmaps disabled) matching the 1:1 mobile rendering of the Option A art.
- Static verifier coverage for articulated cutout-rig assets, native Skeleton2D/AnimationPlayer integration, TileSet resources, native HUD/mobile texture controls, and removal of obsolete whole-sprite/procedural character drawing paths.
- Playable Godot 4.7.2 landscape mobile action-RPG vertical slice with Idle/Move/Jump/Attack/Hurt/Death states, a two-hit combo, buffered/coyote-time jump, two skills, Warden and Wraith enemies, a three-stage run (Rift Approach, Broken Keep, Rift Throne), final Rift Warden boss, stage gates, hazards, and reachable one-way platform routes.
- Isolated multi-touch controls with a fixed joystick, independent attack/jump/skill touch ownership, landscape safe-area positioning, and lifecycle reset on app pause or focus loss.
- HP, MP, EXP, level, gold, equipment, boss, pause, and FPS HUD with safe-area-aware positioning.
- Weapon and armor progression with canonical stat recomputation, checksummed local save data, pooled projectiles/damage numbers, and a 50 draw-call runtime budget monitor.
- Android and unsigned iOS pre-release artifacts for version `0.1.0`, plus deterministic source and Godot behavior verification in GitHub Actions.

- GitHub donor engine integration: data-driven `LevelConfig`/`LevelManager`/`LevelRoot` (three curated stages remain Rift Approach/Broken Keep/Rift Throne, 4th stage now needs only a new resource), `MovingPlatform` (AnimatableBody2D tween, jitter-free carry), `Checkpoint`/`Killzone`/`LevelExit`/`DeathPlane`, `SquashStretch` and `CameraEffects` (hitstop/shake) adapted from MIT donors (`SummerEngine/template-2d-platformer` 66fc71b, `enea-codes/godot-platformer-toolkit` e755d6e, `PhumPea/GameLab4` ebe3fad), with `crystal-trails` 67404a6 as reference-only architecture. Donor SHAs, licenses and migration map recorded in `docs/arch/engine-donors.md` and `THIRD_PARTY_NOTICES.md`; donors cloned outside the game at `D:\LacViet\_vendor\shadowrift-engine-donors\`.
- Player controller now uses donor-proven asymmetric gravity (rise 1800 / fall 2650, max fall 900), variable jump cut (0.42), coyote 0.11 / buffer 0.13 with `_coyote_left`/`_buffer_left` pattern, turn boost 1.55 and air-control damping for measurable jump apex and reachable authored platforms.
- Checkpoint/death/respawn now deterministic: death animation completes, checkpoint persists via `LevelManager`, fall/hazard killzone recovers to last checkpoint, no duplicate Hero/HUD/MobileControls after stage transition or respawn, pools/tweens do not leak.
- Save schema migrated v1->v2 (`stage_index`, `checkpoint`, `has_checkpoint`) with SHA-256 re-checksum; old v1 saves migrate safely without crash.
- Behavior suite expanded to 29 tests, adding real touch jump release, articulated limb-motion checks, DEFEATED→RETRY checkpoint recovery, dead-save recovery, rig-alpha exclusivity, combat escape windows, and Wraith ranged-homing coverage on top of donor jump feel, moving platform, checkpoint, killzone, stage-transition no-duplicate, save migration and LevelConfig data-driven coverage.

### Changed

- Hero, Warden, Wraith, and Rift Warden now compile from Option A high-detail painted masters into six-part body/head/arm/leg cutout atlases with backdrop keying, spill cleanup, stable feet anchors and the original visual footprint/pivot.
- Character rendering moved from whole-image pseudo-animation to native `Skeleton2D`/`Bone2D` + `AnimationPlayer` articulation: run cycles move opposite legs/arms, jump separates rise/fall/land, combat has anticipation/impact/recovery, and the boss has visible windup/strike limb motion. Gameplay-owned movement, combo timing, hitboxes, FSM transitions, cooldowns and damage remain unchanged.
- The zone renders from an imported TileSet atlas with textured one-way platforms and spike hazard, and the world background uses three `Parallax2D` layers instead of runtime-drawn sky/ridges.
- HUD bars moved to native `TextureProgressBar` controls with catalog equipment icons, and mobile joystick/action buttons render through texture visuals while keeping the original multi-touch ownership, dead-zone, one-shot, and safe-area behavior.
- HUD and mobile-control per-frame updates now cache safe-area layout and label text so unchanged values no longer re-run text shaping or layout every frame.
- Default texture filtering switched to linear so the vector art stays crisp without nearest-neighbor artifacts.
- Mobile gameplay now uses the same local Godot runtime as editor gameplay instead of the former network authority path, removing command round-trip latency and reconnect/pause races from the v1 combat loop.
- Enemy patrol/aggro/attack logic, boss chase/windup/strike logic, hazard damage, movement, jump physics, rewards, equipment, and persistence now execute locally on Android and iOS exactly as they do in editor runs.
- Hero death now completes its authored animation, locks gameplay input, presents a `DEFEATED` overlay, and resumes only through `RETRY` at the last checkpoint with restored HP/MP and short invulnerability. Dead saves are normalized to a playable recovery state; enemy/boss cleanup still waits for complete death animations.
- Enemy and boss attack windows now use horizontal/vertical reach checks plus hitbox sizes/offsets matched to the high-detail painted silhouettes; the boss gains visible windup/strike body motion.
- Articulated cutout generation now partitions source alpha exclusively between body parts, eliminating the duplicated semi-transparent pixels that produced blurred/ghost afterimages during limb rotation.
- Hero and enemy/boss physics bodies no longer body-block one another; combat still resolves through Hurtbox/Hitbox areas. Hero post-hit invulnerability is 0.78s, hurt input lock is 0.18s, and melee knockback creates a reliable touch-control escape window instead of repeated overlap damage.
- Wraith is now a ranged caster: it retreats when crowded, maintains a mid-range casting band, telegraphs a 0.52s cast, and fires a pooled cyan/violet homing bolt using damped desired-velocity steering. Combat faction checks reject enemy friendly fire.
- Pause and application lifecycle transitions clear active touch ownership before gameplay resumes, preventing held/stale mobile input after interruption. Mobile Jump now tracks real press/hold/release edges instead of inferring release from keyboard state, so variable jump height behaves correctly on touch.
- Export presets are explicitly pre-release presets with `0.1.0` package metadata; iOS CI remains intentionally unsigned and validates bundle/version metadata before packaging.

### Removed

- Obsolete whole-sprite Hero/Warden/Wraith/Rift Warden sheets and SpriteFrames resources that simulated motion by rotating/translating static images.
- Cloudflare Worker/Durable Object authority, bearer-session persistence, server reconnect/fallback logic, server deployment workflow, and unused Android editor configuration script from the v1 shipped code path.
