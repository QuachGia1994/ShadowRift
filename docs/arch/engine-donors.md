# Engine Donors — Research Matrix & Migration Decisions

Date: 2026-09-02
Branch: refactor/donor-engine-integration
Engine: Godot 4.7.2 (ShadowRift)
Vendor isolation: D:\\LacViet\\_vendor\\shadowrift-engine-donors\\ (outside ShadowRift, no .git vendoring)

## Research Rule
GitHub research completed BEFORE custom implementation. Every candidate pinned to exact commit SHA, LICENSE verified, Godot version checked, subsystem mapped, decision recorded. No copy from non-permissive sources.

## Candidate Matrix

| # | Repository | SHA | Godot | LICENSE | Subsystem / Files | Maintenance | Decision | Reason |
|---|------------|-----|-------|---------|-------------------|-------------|----------|--------|
| 1 | https://github.com/SummerEngine/template-2d-platformer | 66fc71b8edcd1c7023b890c7c0ef7cc55d80748e | 4.6 (config_features 4.6, config_version 5) | MIT (Copyright (c) 2026 Summer Engine) | player_controller.gd (coyote 0.08, buffer 0.1, gravity_up 1100 gravity_down 1400, turn_boost 1.6, jump_cut 0.4, dash/wall), moving_platform.gd (AnimatableBody2D tween), checkpoint.gd, killzone.gd, bench.gd, level_end.gd, scene_transition.gd, game_manager.gd, room_manager.gd, camera_controller.gd (shake/hitstop) | Active 2026-06-11, 3 commits 2026-06-11, comprehensive template, Hollow Knight-inspired | **ADAPT** | MIT, permissive, directly matches PHASE 3/4/6/10 needs: proven coyote/buffer/variable jump + moving platform + checkpoint/killzone + transition. 4.6→4.7 trivial (API compatible). Will adapt values to ShadowRift scale (250 speed vs 280) and keep Option A anim mapping. |
| 2 | https://github.com/enea-codes/godot-platformer-toolkit | e755d6ee27501acad7a5c3976bb6eb5a4ef57dc0 | 4.7 (config_features 4.7) | MIT (Copyright (c) 2026 Enea) | player_controller.gd (jump_height 140, time_to_peak 0.35, time_to_fall 0.28, derived gravity, coyote 0.10, buffer 0.12, cut 0.4), components/health_component.gd, hitbox.gd, hurtbox.gd, blink_effect.gd, camera_shake.gd, squash_stretch.gd, landing_dust.gd, signal_bus.gd | Active 2026-07-28, 2026-07-09 x3, typed GDScript (untyped_declaration=2), clean component architecture | **ADAPT / COPY** | MIT, Godot 4.7 native, best-in-class for designer-friendly gravity derivation (measurable apex) and modular health/HUD/juice. Reuse HealthComponent pattern, Hitbox/Hurtbox signals, SquashStretch, CameraShake, LandingDust via adaptation (preserve CombatAuthority identity, no coin logic). |
| 3 | https://github.com/sayuolab/2d-platformer-controller | 54b2160c61627556fff2e568021e784916181067 | 4.6 (config_features 4.6) | MIT (Copyright (c) 2026 sayuo) | 2D Platformer Controller addon: coyote, buffer, wall slide/jump, dash, corner correction, one-way assist | Active 2026-07-13, Asset Library 4696, community 4.5 | **REFERENCE ONLY** | MIT but redundant with #1+#2 which already cover coyote/buffer/wall/dash with better maintenance and ShadowRift-specific needs (no wall needed). Studied for corner correction concept, not copied. |
| 4 | https://github.com/PhumPea/GameLab4 | ebe3fada07ad9e48fb35602e001e4e6d78e5ad6a | 4.7 (config_features 4.7 Forward Plus) | MIT (Copyright (c) 2022 Leon Oscar Kidando + 2026 Khon Kaen Univ, derivative of AdilDevStuff MIT) | Scenes/Levels/base_level.gd, Scenes/Managers/game_manager.gd, scene_transition.gd, level_finish_door.gd, enemy_spawn.gd, bullet.gd, player.gd (simple 300/650), game_ui.gd, menu.gd | Active 2026-08-05, starter kit for coursework, less typed, simple physics (gravity 30) | **ADAPT (partial) / REFERENCE** | MIT, useful for level manager + scene transition + finish door pattern (BaseLevel + GameManager.load_next_level + dissolve_rect). Adapt transition API, door logic; reject player/enemy code (too simple, not polished). License verified permissive before adapt. |
| 5 | https://github.com/dvgamelab/crystal-trails | 67404a60822fda88019352456d10e1e6a42b704b | 4.7 (config_features 4.7 GL Compatibility) | All Rights Reserved (DVGameLab, no copy/modify/redistribute) | data-driven multi-world progression, stage configs, checkpoint persistence, save_system.gd, audience_profile, test organization, mobile export path | Active 2026-08-17, v42, mature mobile arcade, strong architecture | **REFERENCE ONLY — COPY ZERO** | Non-permissive (all-rights-reserved). Studied for LevelConfig/Stage progression architecture, checkpoint/tests/mobile organization. Reimplemented independently. No code/assets/text copied. Third-party admob MIT sub-component ignored. |
| 6 | GitHub search 2026: Godot 4.7 platformer controller MIT (websearch 2026-09-02) | — | — | — | sayuolab/toolkit/ultimate controller etc | Search returned #2, #3, Ultimate Platformer 4.0 (2025-01-03, MIT but 4.0 outdated), Ev01/PlatformerController2D 4.0 (69 stars, older) | **REJECT** | No stronger current 4.7 MIT donor than #1+#2; search confirmed #2 is top for 4.7 typed components. Documented. |

## License Verification Detail
- template-2d-platformer: LICENSE file MIT at root, verified commit 66fc71b contains same MIT text.
- godot-platformer-toolkit: LICENSE MIT at root, commit e755d6e MIT.
- 2d-platformer-controller: LICENSE MIT at root, commit 54b2160 MIT.
- GameLab4: LICENSE MIT at root with dual copyright (AdilDevStuff + Khon Kaen Univ), verified commit ebe3fad MIT; required checking before copy — confirmed permissive.
- crystal-trails: LICENSE file states All Rights Reserved, Copyright DVGameLab 2026, explicitly forbids copy; docs/ASSET_LICENSES.md confirms third-party excluded. Treated as reference only.

## Godot Compatibility
- ShadowRift 4.7.2 gl_compatibility mobile renderer. All selected donors use 4.6 or 4.7 with config_version 5, CharacterBody2D, move_and_slide(), AnimatableBody2D tween — fully compatible. No C# (codewhizzz rejected), no deprecated APIs.

## Migration Map (Old -> Donor Concept -> New)

| ShadowRift Old | Donor Concept / File | New ShadowRift |
|----------------|----------------------|----------------|
| scripts/player/player.gd (fixed -640, single gravity 1400, coyote 0.11, buffer 0.13, no cut) | toolkit player_controller.gd derived gravity (height/time) + template gravity_up/down + template turn_boost + toolkit coyote/buffer | scripts/player/player.gd upgraded: asymmetric gravity (rise 1800 / fall 2600), jump_cut 0.45, turn_boost 1.5, derived jump apex 185px, coyote 0.11 buffer 0.13 kept but refactored to _coyote_left/_buffer_left pattern |
| no checkpoint, death = die+respawn_at spawn, no death plane | template checkpoint.gd + killzone.gd + bench.gd + godot-platformer-toolkit demo respawn | scripts/world/checkpoint.gd (Area2D, signal activated), scripts/world/killzone.gd (Area2D, resolve_environment_hit), scripts/world/death_plane.gd, checkpoint state in LevelManager |
| StageCatalog dictionary + ZoneBuilder hard-coded + game_world._load_stage | GameLab4 base_level.gd + game_manager.gd + template room_manager.gd + crystal-trails LevelConfig architecture (reference) | scripts/level/level_config.gd (Resource), scripts/level/level_manager.gd (RunManager), scripts/world/level_root.gd (BaseLevel), scripts/world/stage_catalog.gd now emits LevelConfig resources (backward compat) |
| ZoneBuilder one-way StaticBody2D only | template moving_platform.gd (AnimatableBody2D tween) + zone_builder one-way | scripts/platform/moving_platform.gd (ADAPT template), ZoneBuilder extended to spawn moving platforms from LevelConfig |
| Hazard Area2D damage 18 | template killzone.gd + toolkit hitbox | scripts/world/hazard.gd improved to use CombatAuthority.resolve_environment_hit via Killzone base, hazard still 18 dmg |
| CombatAuthority MAX_MELEE_DISTANCE 144, boss strike logic | toolkit hitbox/hurtbox signals + enemy range tuning | CombatAuthority presidio, enemy _attack_range widened check, boss windup/strike motion enhanced via existing _motion_clock but now driven by SquashStretch concept |
| No hitstop/shake/landing dust | template camera_controller.gd hitstop/shake + toolkit squash_stretch.gd + landing_dust.gd + GameLab4 audio stub | scripts/platform/camera_effects.gd (ADAPT camera_shake+hitstop), scripts/platform/squash_stretch.gd (ADAPT toolkit), dust already in Hero but now driven by landed signal |
| game_world monolithic (stage_root, stage_gate, transition, pools) | template GameManager + SceneTransition + crystal-trails data-driven | scripts/world/game_world.gd refactored to delegate to LevelManager + LevelRoot, keeps pools/HUD/controls, no duplicate nodes on transition (queue_free previous stage_root) |
| SaveRepository schema 1 (level, exp, gold, mana, health, equipment) | template SaveManager + toolkit signal bus | SaveRepository extended to schema 1→2 migration (added stage_index/checkpoint_id), old saves migrate safely |
| MobileControls full but jump one-shot outside donor | template input handling + GameLab4 touch | MobileControls preserved, jump one-shot kept, donor touch isolation concept referenced but not replacing |

## Donor Isolation
All donors cloned under D:\\LacViet\\_vendor\\shadowrift-engine-donors\\, pinned SHAs above. No donor .git vendored into ShadowRift. Ported files are minimal adapt, not whole projects.

## Provenance
When code copied/adapted, THIRD_PARTY_NOTICES.md records URL, SHA, license, files, destination, copy vs adapt. Architectures learned from crystal-trails labelled REFERENCE ONLY.

