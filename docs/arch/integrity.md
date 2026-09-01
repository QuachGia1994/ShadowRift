# Integrity boundary

> updated 2026-09-01 · 0.1.0

## Scope

Shadow Rift v1 is offline single-player. It has no leaderboard, trading, paid currency, shared economy, account system, bearer session, gameplay server, or cross-device progression. The pre-release priority is responsive mobile combat and reliable local persistence.

## Implemented controls

- `CombatAuthority` is the single local damage calculation boundary for melee, projectiles, enemies, boss attacks, and hazards.
- `PlayerProfile` recomputes canonical ATK/DEF/max-resource values from level and allowlisted equipment; save data never supplies derived combat stats.
- `SaveRepository` validates schema version, required fields, numeric bounds, equipment IDs, and resource limits before restoring progress.
- Save files include a SHA-256 checksum over the canonical payload so accidental corruption and unsophisticated edits fail closed instead of loading silently.
- Mobile lifecycle boundaries clear active touch ownership before resume, preventing stale movement/action input after pause, focus loss, or app backgrounding.

## Security truth

The checksum salt is part of the shipped client. It is integrity detection, not a secret and not an anti-cheat guarantee. A user who modifies the application can modify their own local progression and pixels. That is acceptable for the v1 offline single-player scope and is stated explicitly rather than hidden behind a false client-side security claim.

## Reopen trigger

Before adding leaderboards, trading, paid currency, account-linked progression, cloud save, or any competitive/shared state, reopen the architecture and move valuable state behind an authenticated service. At that point add account identity, revocation, rate/anomaly controls, audit retention, key rotation, and Apple App Attest / Google Play Integrity as risk-appropriate layers. Do not reintroduce network authority into frame-critical movement/combat unless latency and prediction are designed as first-class gameplay requirements.
