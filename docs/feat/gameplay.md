# Gameplay v1

> updated 2026-09-01 · c609b9e

## Player

- States: Idle, Move, Jump, Attack, Hurt, Death.
- Basic attack: two-hit combo with a 0.34 second continuation window.
- Skills: one stronger melee hit and one pooled ranged projectile; both consume MP.
- Input: keyboard fallback plus touch-index-isolated joystick, attack, and two skill controls.

## World and combat

- One procedural multi-layer TileMapLayer zone, one spike hazard, and two one-way platforms.
- Warden and Wraith enemies patrol, acquire, attack, receive knockback, and die.
- One single-phase Rift Warden boss chases, winds up, strikes, receives knockback, and dies.
- Central combat authority validates combatants, attack kind, range, canonical attack, defense, damage bounds, and knockback bounds.

## Progression

- Level, EXP, HP, MP, ATK, DEF, and gold.
- Weapon and armor slots only; tapping their HUD slots cycles owned v1 items.
- JSON save contains progression and equipment IDs, never derived ATK or DEF.

