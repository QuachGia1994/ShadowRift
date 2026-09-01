# Shadow Rift

Godot 4.7.2 landscape mobile action-RPG vertical slice for Android and iOS. v1 contains a three-stage run (Rift Approach → Broken Keep → Rift Throne), a two-hit player combo, buffered/coyote-time jump, two skills, Warden/Wraith encounters, a final Rift Warden boss, death/respawn checkpoints, equipment, pooled effects, and a stylized 2D hand-drawn/vector dark-fantasy production art set (OPTION A) rendered through native Godot sprites, TileSet, parallax, and texture controls.

The pre-release mobile builds use the same local Godot gameplay runtime as the editor build. There is no gameplay server, bearer token, reconnect state machine, or network dependency in v1; movement/combat response is therefore limited by local frame/physics timing instead of HTTP round trips.

## Run

1. Install Godot 4.7.2 with export templates. On the Windows machine, keep tools off `C:`: use `D:\DevTools\Godot\` for Godot, `D:\Android\Sdk\` for the Android SDK, and `D:\DevTools\Java\` for the JDK.
2. Open `project.godot` in Godot and run the main scene.
3. Desktop fallback controls: `A/D` or arrows move, `Space` jumps, `J` attacks, `K/L` use skills.
4. Mobile controls: left joystick + independent `A` attack, `J` jump, skill `1`, skill `2`, and pause. Active touches are cleared on pause/focus loss so resumed play cannot inherit stale input.
5. Tap the Weapon or Armor slots in the HUD to cycle the two v1 equipment choices.

## Verify

Run the static contract and Godot behavior suite:

```bash
python tools/verify_project.py
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

GitHub `Verify` pins Godot 4.7.2, imports/parses the project, runs the source contract, and runs 16 deterministic GDScript behavior tests covering player/input, jump reachability, death/respawn, three-stage progression, safe-area mapping, lifecycle input reset, world structure, enemy/boss FSM/range/death timing, inventory, save validation, local canonical combat/hazard damage, pooling, performance contracts, production art resources, and pause/resume.

Regenerate production art (Pillow + NumPy) from the Godot-ignored masters in `art_source/option_a_masters` plus the local environment/UI/VFX generators:

```bash
python tools/generate_option_a_assets.py
python tools/report_mobile_memory.py
```

## Mobile pre-release export

- Package version: `0.1.0`; bundle/package identifier: `uk.oakgatekeeper.shadowrift`.
- Android CI exports an installable debug-signed pre-release APK named `ShadowRift-prerelease.apk` and verifies package/version metadata with Android build tools.
- iOS CI exports the Godot Xcode project, builds an unsigned device `.app`, validates bundle/version metadata, and packages `ShadowRift-unsigned.ipa`. `CIUNSIGNED` is only a Godot project-export sentinel; Xcode code signing is disabled in CI.
- Production Play/App Store signing credentials are intentionally not stored in the public repository. A production release must replace the CI-only signing path with the owner's Android keystore and Apple Team/certificate/provisioning profile.

## Persistence and integrity

v1 is offline single-player. `SaveRepository` validates schema/ranges/equipment and stores a SHA-256 checksum to detect accidental corruption or unsophisticated edits. The checksum salt ships with the client, so it is not an anti-cheat or cryptographic trust boundary; a modified client can alter its own local progress. No competitive ranking, paid currency, trading, or shared economy exists in v1, so no device-attestation/token system is required for this pre-release scope.
