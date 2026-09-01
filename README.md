# Shadow Rift

Godot 4.7.2 landscape mobile action-RPG vertical slice for Android and iOS. v1 contains one zone, a two-hit player combo, two skills, two enemy types, one single-phase boss, equipment, pooled effects, and procedural placeholder art. Protected mobile exports use a Cloudflare Worker and SQLite Durable Object as the sole authority for movement bounds, combat, HP/MP, equipment, EXP, gold, and persistence.

## Run

1. Install Godot 4.7.2 with export templates. On the Windows machine, keep tools off `C:`: use `D:\DevTools\Godot\` for Godot, `D:\Android\Sdk\` for the Android SDK, and `D:\DevTools\Java\` for the JDK.
2. Open `project.godot` in Godot and run the main scene.
3. Desktop fallback controls: `A/D` or arrows move, `Space` jumps, `J` attacks, `K/L` use skills. Mobile uses one isolated left joystick touch plus independent attack and skill touch indices.
4. Tap the Weapon or Armor slots in the HUD to cycle the two v1 equipment choices.

Editor runs intentionally use local debug authority. Both mobile presets include the `server_authoritative` feature and fail closed when the configured HTTPS server is unavailable.

## Verify

Run the source contract check:

```bash
python tools/verify_project.py
node --test server/src/domain.test.ts
```

With Godot installed, run behavior tests:

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

## Authority server

The server accepts only intent commands: move direction, jump, attack, skill slot, equipment ID, and sync. It rejects unknown fields, client damage/stats/rewards, invalid items, out-of-range targets, cooldown/mana violations, and replayed or out-of-order sequence numbers. A random bearer token is hashed before storage; game state is serialized and persisted inside one Durable Object per session.

```bash
cd server
npm ci
npm test
npm run typecheck
npm run deploy
```

Set `shadow_rift/server/base_url` in `project.godot` to the deployed HTTPS Worker URL before distributing a mobile build. The public repository contains no signing or Cloudflare credential. Manual server deployment reads `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` from GitHub environment secrets.

## Mobile debug export

- Public GitHub Actions verifies source/server behavior and builds the Android debug APK plus an unsigned iOS application/Xcode archive. The public workflow contains no signing material.
- Android local: set SDK/JDK paths to the `D:` locations above, install Android templates, connect a USB-debug device, and export `Android Debug`.
- iOS device: replace the placeholder Team ID, provide an Apple certificate/provisioning profile through protected GitHub environment secrets or Xcode, then sign and install. An unsigned `.ipa` cannot run on a real iPhone. Xcode cannot run on Windows.
- The bundle identifier is `uk.oakgatekeeper.shadowrift`; change it only if that identifier is not owned by the final signing account.

## Integrity boundary

The official server, not the mobile process, owns valuable state. Cheat Engine or a modded package can fake pixels on that device and automate valid input, but cannot submit damage, ATK/DEF, HP/MP, rewards, equipment definitions, or save payloads accepted by the official server. The local session token identifies an anonymous session; account recovery, device attestation, rate analytics, and ban operations remain post-MVP hardening work.
