# ARPG mobile v1 build

## Status

| Milestone | Status | Evidence | Remaining gate |
| --- | --- | --- | --- |
| 1. Player FSM and input | PARTIAL | Source and static checks | Godot runtime and touch-device feel |
| 2. Combat | PARTIAL | Source and behavior tests authored | Run headless tests in Godot |
| 3. Zone | PARTIAL | Three TileMapLayer nodes, hazard, platforms | Render and collision check |
| 4. Enemies | PARTIAL | Two FSM archetypes implemented | Runtime tuning |
| 5. Boss and HUD | PARTIAL | Single-phase boss and HUD implemented | Layout/device-safe-area check |
| 6. Inventory | PARTIAL | Two slots and canonical recompute implemented | Touch equip check |
| 7. Save | PARTIAL | Checksum, tamper test, and invariants authored | Godot filesystem test |
| 8. Performance | PARTIAL | Pools, 60 FPS lock, 50 draw-call monitor | Profile on two real devices |
| 9. Mobile exports | BLOCKED | Android and iOS presets authored | Godot templates, Android SDK/device, macOS/Xcode/Team ID/device |

## Next action

Install Godot and Android tooling under `D:` on Windows, run the static and headless suites, export the Android debug APK, and test on a real device. Export iOS on a Mac after adding the Apple Team ID. Do not mark a platform PASS until launch, input, combat, save/load, pause/resume, and 60 FPS are observed on that device.

