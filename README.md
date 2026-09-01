# Shadow Rift

Godot 4.x landscape mobile action-RPG vertical slice for Android and iOS. v1 contains one zone, a two-hit player combo, two skills, two enemy types, one single-phase boss, equipment, checksummed local progression, pooled effects, and procedural placeholder art.

## Run

1. Install Godot 4.3 or newer with export templates. On the Windows machine, keep tools off `C:`: use `D:\DevTools\Godot\` for Godot, `D:\Android\Sdk\` for the Android SDK, and `D:\DevTools\Java\` for the JDK.
2. Open `project.godot` in Godot and run the main scene.
3. Desktop fallback controls: `A/D` or arrows move, `Space` jumps, `J` attacks, `K/L` use skills. Mobile uses one isolated left joystick touch plus independent attack and skill touch indices.
4. Tap the Weapon or Armor slots in the HUD to cycle the two v1 equipment choices.

## Verify

Run the source contract check:

```bash
python tools/verify_project.py
```

With Godot installed, run behavior tests:

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

## Mobile debug export

- Android: set the SDK/JDK paths in Godot Editor Settings to the `D:` locations above, install Android export templates, connect a USB-debug device, then export the `Android Debug` preset.
- iOS: export requires macOS with Xcode. Set the Apple Team ID in `export_presets.cfg`, export the `iOS Debug` preset to Xcode, sign it, then run on the connected device. Xcode cannot be installed or executed on Windows.
- The bundle identifier is `uk.oakgatekeeper.shadowrift`; change it only if that identifier is not owned by the final signing account.

## Integrity boundary

This client deters casual save/stat/damage edits through a SHA-256 checksummed canonical payload, strict ranges and item whitelists, runtime stat recomputation, centralized damage resolution, distance checks, and no release cheat hooks. A local Godot client cannot prevent a determined attacker from patching a modded APK/IPA or changing process memory; competitive enforcement requires a future server-authoritative backend.

