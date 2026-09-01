# Gameplay v1

> updated 2026-09-01 · 28cecf5

## Player

- States: Idle, Move, Jump, Attack, Hurt, Death.
- Basic attack: two-hit combo with a 0.34 second continuation window.
- Skills: one stronger melee hit and one pooled ranged projectile; both consume MP.
- Input: keyboard fallback plus touch-index-isolated joystick, attack, and two skill controls.

## World and combat

- One procedural multi-layer TileMapLayer zone, one spike hazard, and two one-way platforms.
- Warden and Wraith enemies patrol, acquire, attack, receive knockback, and die.
- One single-phase Rift Warden boss chases, winds up, strikes, receives knockback, and dies.
- Protected mobile combat is evaluated by the Worker/Durable Object server; the client renders snapshots and server-confirmed damage events.
- Editor debug mode keeps the same local combat loop for rapid iteration and behavior tests.

## Progression

- Level, EXP, HP, MP, ATK, DEF, and gold.
- Weapon and armor slots only; tapping their HUD slots cycles owned v1 items.
- Protected progress is a resumable server session; the device stores only opaque session credentials.
- Local debug JSON contains progression and equipment IDs, never derived ATK or DEF.
