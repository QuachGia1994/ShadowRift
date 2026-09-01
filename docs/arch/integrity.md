# Server authority boundary

> updated 2026-09-01 · M16 release gate

## Threat dimensions

- Reach, estimated: any player controlling a local Android or jailbroken iOS device can inspect the client.
- Capability, estimated: save editing is easy; memory editing and modded packages require progressively more tooling.
- Motive, estimated: low in v1 because there is no rank, paid currency, trading, or shared economy.
- Blast radius, measured from architecture: client modification can falsify local rendering and automate valid intent, but official progression remains isolated in its authenticated server session.

## Implemented controls

- Protected builds send only a strict intent union. Extra keys such as damage, stats, gold, HP, target results, device time, or save payload make the command invalid.
- A random 256-bit bearer token is hashed before Durable Object storage and never logged. A UUID session identifier alone grants no access.
- Exactly increasing sequence numbers reject replay and out-of-order requests; each session processes commands serially.
- Server time caps movement distance, enforces command rate/cooldowns, spends mana, selects the nearest range-valid target, and computes canonical ATK/DEF/damage.
- Equipment comes from a server allowlist. Rewards are granted only during the server's alive-to-dead transition, so a kill cannot pay twice.
- The server persists state only after an accepted command. Restart resumes from server `lastSeq`; no protected progress is loaded from local JSON.
- All three local damage entry points return false in `server_authoritative` builds. Disconnect or invalid protocol response locks gameplay visibly.
- Reconnect is fail-closed (M16): any transport, protocol, or authentication failure clears queued and in-flight intents, invalidates the stale sequence, and locks gameplay. Only authenticated session resume is retried, with exponential backoff and jitter capped at 30 seconds. `lastSeq` is refreshed only from an authenticated snapshot before new input is accepted, so stale combat or equipment commands are never replayed after a reconnect. An invalid or expired token remains locked; the client never silently creates a replacement session, and no bearer token is logged.
- The Worker and SQLite Durable Object adapter is proven end to end by an isolated integration suite (12 tests in workerd) covering bearer enforcement, resume, unknown-field rejection, malformed and oversized bodies, exact sequence enforcement, and server-owned cooldown, mana, equipment, movement bounds, canonical damage, death, and reward-once behavior.
- Editor/local debug still uses checksummed JSON, canonical stat recomputation, distance checks, and no cheat hooks.

## Limits and reopen trigger

No client-side design can stop an attacker from changing their own pixels, suppressing animations, stealing their own token from a rooted device, or scripting valid commands. The current anonymous token is not an account system and has no cross-device recovery. Before leaderboards, trading, rank, or paid currency, add authenticated accounts, Apple App Attest/Google Play Integrity verification, per-account anomaly limits, revocation/ban tooling, audit retention, and key rotation. Those layers raise abuse cost; “absolute” protection on an attacker-controlled device is not a truthful guarantee.
