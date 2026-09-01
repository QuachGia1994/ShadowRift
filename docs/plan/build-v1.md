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
| 10. Authority server | PASS | 8 Node tests and live Cloudflare Durable Object Worker | Device/network soak test |
| 11. Protected client | PARTIAL | Intent-only protocol, resumable token, fail-closed mobile feature | Godot 4.7.2 parse/runtime CI |
| 12. Public mobile CI | PARTIAL | Verify, Android, unsigned iOS, and manual deploy workflows | First public GitHub run |

## Next action

Push the complete repository to the public GitHub remote and let the first workflows start. The protected client is configured for the deployed Worker. Android can then be tested directly; iOS still requires a real Apple Team ID, certificate, provisioning profile, and device. Do not mark a platform PASS until launch, input, combat, server resume, pause/resume, disconnect lock, and 60 FPS are observed on that device.
