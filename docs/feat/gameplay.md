# Gameplay v1

> updated 2026-09-01 · 0.1.0

## Player

- States: Idle, Move, Jump, Attack, Hurt, Death.
- Basic attack: two-hit combo with a 0.34 second continuation window.
- Skills: one stronger melee hit and one pooled ranged projectile; both consume MP.
- Input: keyboard fallback plus touch-index-isolated joystick, attack, jump, and two skill controls; jump includes coyote time and input buffering for reliable mobile traversal.
- Mobile controls are safe-area-aware and clear ownership on pause/focus loss so resumed play never inherits stale movement or actions.

## World and combat

- Three authored 2400px stages: Rift Approach, Broken Keep, and Rift Throne. Each stage builds its own reachable one-way platform/hazard layout from the imported rift TileSet and unlocks a visible exit gate only after its encounter is cleared.
- Warden and Wraith enemies patrol, acquire, attack with visual-range-matched hitboxes, receive knockback, play their complete death animation, and die on Android, iOS, and editor builds using the same local FSM.
- The final Rift Warden boss chases, visibly winds up/leans into strikes, uses a widened sweep hitbox matching its painted silhouette, receives knockback, and completes its full death animation before cleanup.
- `CombatAuthority` evaluates canonical melee/projectile/enemy/hazard damage locally; there is no network round trip in the frame-critical combat loop.
- Pause freezes the scene tree while the pause control/HUD remain responsive, and active touch state is cleared before resume.
- Hero death plays the death state, then rebuilds the current stage and respawns at its checkpoint with full HP/MP instead of leaving a dead actor standing indefinitely.

## Progression

- Level, EXP, HP, MP, ATK, DEF, and gold.
- Weapon and armor slots only; tapping their HUD slots cycles owned v1 items.
- Local save data contains progression, resources, and equipment IDs; derived ATK/DEF/max resources are recomputed from canonical definitions before use.
- The save checksum detects corruption/naive edits but is not an anti-cheat boundary; v1 has no competitive or paid shared state.
