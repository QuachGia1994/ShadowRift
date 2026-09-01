# Client integrity boundary

> updated 2026-09-01 · c609b9e

## Threat dimensions

- Reach, estimated: any player controlling a local Android or jailbroken iOS device can inspect the client.
- Capability, estimated: save editing is easy; memory editing and modded packages require progressively more tooling.
- Motive, estimated: low in offline v1 because there is no rank, scarce currency, IAP, or shared economy.
- Blast radius, measured from architecture: modifications affect only the actor's local, recoverable progress; there is no server or other-user data.

## Implemented controls

- Save payload uses a deterministic SHA-256 checksum plus schema, range, equipment whitelist, resource ceiling, and canonical-stat validation.
- ATK and DEF are never loaded from save. `PlayerProfile` recomputes them from level and catalog IDs.
- Player damage uses `CombatAuthority._canonical_attack`; changing the HUD stat cache does not change resolved damage.
- Melee and projectile requests are bounded by source, target, attack ID, range, damage cap, and knockback cap.
- Runtime profile checks repair modified derived-stat caches and count violations.
- Release runtime contains no god mode, cheat menu, set-damage hook, or debug stat override.

## Limits and reopen trigger

Checksum salt and GDScript bytecode live in the client, so a determined attacker can patch the verifier, alter process memory, or redistribute a modified package. These controls are tamper deterrence and detection, not server-grade enforcement. Reopen the threat model before adding leaderboards, trading, competitive rank, paid currency, or any reward shared across users; those features require server-authoritative state and combat validation.

