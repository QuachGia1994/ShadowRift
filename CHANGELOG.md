# Changelog

All notable changes are documented in this file.

## [Unreleased]

### Added

- Playable Godot mobile action-RPG vertical slice with player FSM, isolated multi-touch controls, two-hit combat, two skills, layered TileMapLayer zone, hazard, one-way platforms, two enemies, and a single-phase boss.
- HP, MP, EXP, level, gold, equipment, boss, and FPS HUD.
- Weapon and armor equipment with canonical stat recomputation.
- Checksummed JSON save data with tamper and invariant rejection.
- Pooled projectiles and damage numbers with a 50 draw-call runtime budget monitor.
- Android and iOS debug export presets plus automated source and behavior checks.
- Cloudflare Worker and SQLite Durable Object authority for authenticated, replay-resistant, server-owned combat and progression.
- Intent-only Godot network client with resumable sessions and fail-closed protected mobile exports.
- Public GitHub Actions for verification, Android debug APK, unsigned iOS build, and manual Cloudflare deployment.

### Added in M16

- Worker integration suite: 12 end-to-end tests against the real Worker and SQLite Durable Object in workerd via the official `@cloudflare/vitest-plugin`, covering health, session creation, bearer enforcement, authenticated resume, unknown-field rejection, malformed/oversized bodies, exact sequence enforcement, and server-owned cooldown, mana, equipment, movement bounds, canonical damage, death, and reward-once behavior.
- Bounded fail-closed reconnect: any transport, protocol, or auth failure locks protected gameplay, clears queued and in-flight intents, invalidates the stale sequence, and retries only authenticated resume with exponential backoff and jitter capped at 30 seconds; `lastSeq` refreshes only from an authenticated snapshot; invalid or expired tokens stay locked with no silent session recreation; the HUD shows CONNECTING, RECONNECTING, OFFLINE, and ONLINE states; bearer tokens are never logged.
- Deterministic GDScript tests for backoff bounds, fail-closed intent clearing, and resume state transitions, plus static contract checks in `tools/verify_project.py`.

### Changed in M16

- Server TypeScript checks now cover the integration tests and use generated runtime types (`wrangler types`) instead of the deprecated `@cloudflare/workers-types`.
- Verify workflow runs unit, integration, and TypeScript checks as explicit steps.
