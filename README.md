# Shadow Rift

Godot 4.7.2 landscape mobile action-RPG vertical slice for Android and iOS. v1 contains one zone, a two-hit player combo, two skills, two enemy types, one single-phase boss, equipment, pooled effects, and procedural placeholder art. Protected mobile exports use a Cloudflare Worker and SQLite Durable Object as the sole authority for movement bounds, combat, HP/MP, equipment, EXP, gold, and persistence.

## Run

1. Install Godot 4.7.2 with export templates. On the Windows machine, keep tools off `C:`: use `D:\DevTools\Godot\` for Godot, `D:\Android\Sdk\` for the Android SDK, and `D:\DevTools\Java\` for the JDK.
2. Open `project.godot` in Godot and run the main scene.
3. Desktop fallback controls: `A/D` or arrows move, `Space` jumps, `J` attacks, `K/L` use skills. Mobile uses one isolated left joystick touch plus independent attack and skill touch indices.
4. Tap the Weapon or Armor slots in the HUD to cycle the two v1 equipment choices.

Editor runs intentionally use local debug authority. Both mobile presets include the `server_authoritative` feature and fail closed when the configured HTTPS server is unavailable.

## Verify

Run the source contract check and the deterministic server suites:

```bash
python tools/verify_project.py
cd server
npm test
```

`npm test` runs the deterministic domain unit tests plus the Worker integration suite: `@cloudflare/vitest-plugin` drives 12 end-to-end tests against the real Worker and SQLite Durable Object inside workerd, isolated from the production Worker. `npm run typecheck` type-checks the Worker and the tests using generated runtime types; rerun `npx wrangler types` after changing any binding.

With Godot installed, run behavior tests:

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

## Authority server

The server accepts only intent commands: move direction, jump, attack, skill slot, equipment ID, and sync. It rejects unknown fields, client damage/stats/rewards, invalid items, out-of-range targets, cooldown/mana violations, and replayed or out-of-order sequence numbers. A random bearer token is hashed before storage; game state is serialized and persisted inside one Durable Object per session.

Protected clients reconnect fail-closed: any transport, protocol, or authentication failure locks gameplay, clears every queued and in-flight intent, and invalidates the stale sequence. Only authenticated session resume is retried, with exponential backoff and jitter capped at 30 seconds, and `lastSeq` is refreshed only from an authenticated snapshot before new input is accepted. An invalid or expired token stays locked; the client never silently creates a replacement session, and the bearer token is never logged. The HUD surfaces ONLINE, CONNECTING, RECONNECTING, and OFFLINE states.

```bash
cd server
npm ci
npm test
npm run typecheck
npm run deploy
```

The protected client currently uses `https://shadowrift-authority.kim-phong619.workers.dev`; change `shadow_rift/server/base_url` only when deploying a replacement authority. The public repository contains no signing or Cloudflare credential. Manual server deployment reads `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` from GitHub environment secrets.

## Mobile debug export

- Public GitHub Actions verifies source/server behavior and builds the Android debug APK plus an unsigned iOS application/Xcode archive. The public workflow contains no signing material.
- Android local: set SDK/JDK paths to the `D:` locations above, install Android templates, connect a USB-debug device, and export `Android Debug`.
- iOS device: replace the placeholder Team ID, provide an Apple certificate/provisioning profile through protected GitHub environment secrets or Xcode, then sign and install. An unsigned `.ipa` cannot run on a real iPhone. Xcode cannot run on Windows.
- The bundle identifier is `uk.oakgatekeeper.shadowrift`; change it only if that identifier is not owned by the final signing account.

## Integrity boundary

The official server, not the mobile process, owns valuable state. Cheat Engine or a modded package can fake pixels on that device and automate valid input, but cannot submit damage, ATK/DEF, HP/MP, rewards, equipment definitions, or save payloads accepted by the official server. The local session token identifies an anonymous session; account recovery, device attestation, rate analytics, and ban operations remain post-MVP hardening work.
