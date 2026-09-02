# Third-Party Notices

This project incorporates adapted code from permissively licensed donor repositories.
All donors were verified for license compatibility before copying/adapting.
Crystal Trails was studied as architecture reference only — no code copied.

## SummerEngine/template-2d-platformer
- URL: https://github.com/SummerEngine/template-2d-platformer
- Commit: 66fc71b8edcd1c7023b890c7c0ef7cc55d80748e
- License: MIT — Copyright (c) 2026 Summer Engine (LICENSE file)
- Subsystems reused/adapted:
  - scripts/player/player_controller.gd (coyote_time 0.08, jump_buffer_time 0.1, gravity_up 1100 gravity_down 1400, turn_boost 1.6, jump_cut 0.4) -> adapted into scripts/player/player.gd (asymmetric gravity, variable jump, turn boost, coyote/buffer refactor)
  - scripts/systems/moving_platform.gd (AnimatableBody2D tween) -> adapted into scripts/platform/moving_platform.gd
  - scripts/systems/checkpoint.gd (Area2D flag) -> adapted into scripts/world/checkpoint.gd
  - scripts/systems/killzone.gd (Area2D die) -> adapted into scripts/world/killzone.gd
  - scripts/systems/level_end.gd + scripts/autoloads/scene_transition.gd -> adapted into scripts/world/level_exit.gd + scripts/level/level_manager.gd transition handling
  - scripts/player/camera_controller.gd (shake/hitstop) -> adapted into scripts/platform/camera_effects.gd
- Type: ADAPT (values retuned for ShadowRift 250 speed / 192-256 art scale, Option A anim mapping kept, no dash/wall copied)
- Local destination: scripts/player/player.gd, scripts/platform/moving_platform.gd, scripts/world/checkpoint.gd, scripts/world/killzone.gd, scripts/world/level_exit.gd, scripts/platform/camera_effects.gd, scripts/level/level_manager.gd

## enea-codes/godot-platformer-toolkit
- URL: https://github.com/enea-codes/godot-platformer-toolkit
- Commit: e755d6ee27501acad7a5c3976bb6eb5a4ef57dc0
- License: MIT — Copyright (c) 2026 Enea (LICENSE file)
- Subsystems reused/adapted:
  - player/player_controller.gd (jump_height 140, time_to_peak 0.35, time_to_fall 0.28, derived gravity, coyote 0.10 buffer 0.12) -> adapted jump apex derivation concept into scripts/player/player.gd
  - components/health_component.gd, hitbox.gd, hurtbox.gd (typed signals) -> referenced for HealthComponent polish (signals) but kept ShadowRift canonical CombatAuthority
  - components/squash_stretch.gd -> adapted into scripts/platform/squash_stretch.gd
  - components/camera_shake.gd -> merged into scripts/platform/camera_effects.gd
  - player/landing_dust.gd -> adapted dust signal pattern into Hero landed handling
- Type: ADAPT / COPY (MIT required notice included here; code adapted not verbatim vendored, typed GDScript style followed)
- Local destination: scripts/player/player.gd, scripts/platform/squash_stretch.gd, scripts/platform/camera_effects.gd

## PhumPea/GameLab4
- URL: https://github.com/PhumPea/GameLab4
- Commit: ebe3fada07ad9e48fb35602e001e4e6d78e5ad6a
- License: MIT — Copyright (c) 2022 Leon Oscar Kidando (AdilDevStuff) + 2026 Khon Kaen University, derivative MIT (LICENSE file)
- Subsystems reused/adapted:
  - Scenes/Managers/scene_transition.gd (CanvasLayer dissolve_rect) -> adapted into scripts/level/level_manager.gd transition
  - Scenes/Prefabs/level_finish_door.gd -> adapted into scripts/world/level_exit.gd (door logic)
  - Scenes/Levels/base_level.gd + Scenes/Managers/game_manager.gd (current_level, load_next_level pattern) -> adapted into scripts/world/level_root.gd + scripts/level/level_manager.gd
- Type: ADAPT (partial, transition/door/base-level concepts)
- Local destination: scripts/level/level_manager.gd, scripts/world/level_root.gd, scripts/world/level_exit.gd
- Not copied: player.gd (too simple), enemy.gd simple patrol, bullet etc.

## crystal-trails (Reference Only)
- URL: https://github.com/dvgamelab/crystal-trails
- Commit: 67404a60822fda88019352456d10e1e6a42b704b
- License: All Rights Reserved — DVGameLab 2026, no permission to copy/modify/redistribute
- Subsystems: multi-world data-driven level configs, Stage progression, save_system architecture, checkpoint persistence, test organization
- Type: REFERENCE ONLY — zero code/assets/text copied; reimplemented independently as scripts/level/level_config.gd Resource pattern
- Reason: license prohibits copying; used for architectural learning only.

## sayuolab/2d-platformer-controller (Searched, Reference Only)
- URL: https://github.com/sayuolab/2d-platformer-controller
- Commit: 54b2160c61627556fff2e568021e784916181067
- License: MIT — Copyright (c) 2026 sayuo
- Type: REFERENCE ONLY (studied corner correction, redundant with donors #1/#2)

## godotengine/godot-demo-projects — 2d/skeleton
- URL: https://github.com/godotengine/godot-demo-projects
- Commit: 0db80ca5fd22b9a40e05b9bc1e00af867fb7c712
- License: MIT (repository license)
- Type: ADAPT pattern only; no demo art copied.
- Reused concepts: native Skeleton2D/Bone2D cutout hierarchy, AnimationPlayer-driven limb tracks, separate run/rise/fall/land visual states, locomotion animation speed coupled to movement.
- Local destination: scripts/animation/character_motion_rig.gd and actor visual-state integration.

## Windy-Codes/2d-platformer-template
- URL: https://github.com/Windy-Codes/2d-platformer-template
- Commit: 7d7aa62dbd768054a0b6a06c8e479f1cf2872bcf
- License: MIT for project code; bundled demo assets were not copied.
- Type: ADAPT pattern only.
- Reused concepts: explicit death recovery/checkpoint flow and animation-state selection; ShadowRift implements its own DEFEATED/RETRY UX and preserves its existing LevelManager/checkpoint architecture.
- Local destination: scripts/world/game_world.gd, scripts/ui/game_hud.gd, tests/test_runner.gd.

---
All adapted code retains original MIT license terms; this file satisfies attribution requirements.
