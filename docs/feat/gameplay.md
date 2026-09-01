# Gameplay v1

> updated 2026-09-01 · 0.1.0

## Player

- States: Idle, Move, Jump, Attack, Hurt, Death.
- Basic attack: two-hit combo with a 0.34 second continuation window.
- Skills: one stronger melee hit and one pooled ranged projectile; both consume MP.
- Input: keyboard fallback plus touch-index-isolated joystick, attack, jump, and two skill controls.
- Mobile controls are safe-area-aware and clear ownership on pause/focus loss so resumed play never inherits stale movement or actions.

## World and combat

- One procedural multi-layer TileMapLayer zone, one spike hazard, and two one-way platforms.
- Warden and Wraith enemies patrol, acquire, attack, receive knockback, and die on Android, iOS, and editor builds using the same local FSM.
- One single-phase Rift Warden boss chases, winds up, strikes, receives knockback, and dies using the same local FSM on every platform.
- `CombatAuthority` evaluates canonical melee/projectile/enemy/hazard damage locally; there is no network round trip in the frame-critical combat loop.
- Pause freezes the scene tree while the pause control/HUD remain responsive, and active touch state is cleared before resume.

## Progression

- Level, EXP, HP, MP, ATK, DEF, and gold.
- Weapon and armor slots only; tapping their HUD slots cycles owned v1 items.
- Local save data contains progression, resources, and equipment IDs; derived ATK/DEF/max resources are recomputed from canonical definitions before use.
- The save checksum detects corruption/naive edits but is not an anti-cheat boundary; v1 has no competitive or paid shared state.
