# Shadow Rift

Godot 4.7.2 landscape mobile action-RPG vertical slice for Android and iOS. v1 contains a three-stage run (Rift Approach → Broken Keep → Rift Throne), a two-hit player combo, buffered/coyote-time jump, two skills, Warden/Wraith encounters, a final Rift Warden boss, checkpoint retry flow, equipment, pooled effects, and a stylized 2D hand-drawn/vector dark-fantasy production art set (OPTION A) rendered through native Godot Skeleton2D/Bone2D cutout animation, TileSet, parallax, and texture controls.

The pre-release mobile builds use the same local Godot gameplay runtime as the editor build. There is no gameplay server, bearer token, reconnect state machine, or network dependency in v1; movement/combat response is therefore limited by local frame/physics timing instead of HTTP round trips.

## Run

1. Install Godot 4.7.2 with export templates. On the Windows machine, keep tools off `C:`: use `D:\DevTools\Godot\` for Godot, `D:\Android\Sdk\` for the Android SDK, and `D:\DevTools\Java\` for the JDK.
2. Open `project.godot` in Godot and run the main scene.
3. Desktop fallback controls: `A/D` or arrows move, `Space` jumps, `J` attacks, `K/L` use skills.
4. Mobile controls: left joystick + independent `A` attack, `J` jump, skill `1`, skill `2`, and pause. Jump tracks press/hold/release for variable height; active touches are cleared on pause/focus loss so resumed play cannot inherit stale input.
5. On defeat, finish the death animation and tap `RETRY` to return to the last checkpoint with restored HP/MP. Tap the Weapon or Armor slots in the HUD to cycle the two v1 equipment choices.

## Verify

Run the static contract and Godot behavior suite:

```bash
python tools/verify_project.py
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

GitHub `Verify` pins Godot 4.7.2, imports/parses the project, runs the source contract, and runs 26 deterministic GDScript behavior tests covering donor-derived platformer feel, real touch jump release, articulated Hero/Boss limb motion, moving platform carry, checkpoint/killzone/death-plane recovery, explicit DEFEATED→RETRY recovery, dead-save revival, data-driven LevelConfig/LevelManager, stage transition without duplicate Hero/HUD/MobileControls, Warden/Wraith/boss windup-strike-death, save migration v1->v2, safe-area/lifecycle, local canonical combat/hazard damage, pooling, performance, production art resources, and pause/resume.

Regenerate production art (Pillow + NumPy) from the Godot-ignored masters in `art_source/option_a_masters`. Character masters are deterministically split into articulated cutout atlases; environment/UI/VFX remain local generators:

```bash
python tools/generate_option_a_assets.py
python tools/report_mobile_memory.py
```

## Donor Engine Integration
Proven GitHub systems were researched before custom code (see `docs/arch/engine-donors.md` and `THIRD_PARTY_NOTICES.md`):
- **SummerEngine/template-2d-platformer** (MIT 66fc71b, Godot 4.6) — adapted player feel (coyote 0.08/buffer 0.1 + gravity 1100/1400 + turn boost), AnimatableBody2D moving platform, checkpoint/killzone, level-end and scene-transition.
- **enea-codes/godot-platformer-toolkit** (MIT e755d6e, Godot 4.7) — adapted designer-friendly jump gravity derivation, HealthComponent/Hitbox/Hurtbox signals, SquashStretch, CameraShake and landing dust.
- **PhumPea/GameLab4** (MIT ebe3fad, Godot 4.7) — adapted BaseLevel/GameManager transition and level-finish door pattern for LevelRoot/LevelManager.
- **crystal-trails** (All Rights Reserved 67404a6, Godot 4.7) — reference only for data-driven multi-world progression and checkpoint architecture; zero code copied.
- **sayuolab/2d-platformer-controller** (MIT 54b2160, Godot 4.6) — searched, reference only (corner correction, redundant with above).
- **godotengine/godot-demo-projects `2d/skeleton`** (MIT 0db80ca, Godot 4.7) — adapted the native Skeleton2D/Bone2D + AnimationPlayer cutout pattern; no demo art copied.
- **Windy-Codes/2d-platformer-template** (MIT 7d7aa62, Godot 4) — adapted explicit death→checkpoint recovery and state-driven animation concepts; no bundled third-party art/audio copied.

Donors are cloned outside the game under `D:\LacViet\_vendor\shadowrift-engine-donors\` and `D:\LacViet\_vendor\shadowrift-animation-donors\`, pinned SHAs above, and only permissively licensed patterns/code are adapted. Adding a 4th stage still requires only a new `LevelConfig` resource, no core run-management edit.

## Mobile pre-release export

- Package version: `0.1.0`; bundle/package identifier: `uk.oakgatekeeper.shadowrift`.
- Android CI exports an installable debug-signed pre-release APK named `ShadowRift-prerelease.apk` and verifies package/version metadata with Android build tools.
- iOS CI exports the Godot Xcode project, builds an unsigned device `.app`, validates bundle/version metadata, and packages `ShadowRift-unsigned.ipa`. `CIUNSIGNED` is only a Godot project-export sentinel; Xcode code signing is disabled in CI.
- Production Play/App Store signing credentials are intentionally not stored in the public repository. A production release must replace the CI-only signing path with the owner's Android keystore and Apple Team/certificate/provisioning profile.

## Persistence and integrity

v1 is offline single-player. `SaveRepository` validates schema/ranges/equipment and stores a SHA-256 checksum to detect accidental corruption or unsophisticated edits. The checksum salt ships with the client, so it is not an anti-cheat or cryptographic trust boundary; a modified client can alter its own local progress. No competitive ranking, paid currency, trading, or shared economy exists in v1, so no device-attestation/token system is required for this pre-release scope.
