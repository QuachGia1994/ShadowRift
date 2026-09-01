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
| 9. Mobile exports | PARTIAL | Android CI artifact produced and launched on a real phone; iOS export pipeline repaired through project-only Xcode packaging | Fresh landscape artifact/device verification; iOS artifact observation |
| 10. Authority server | PASS | 8 Node tests and live Cloudflare Durable Object Worker | Device/network soak test |
| 11. Protected client | PARTIAL | Intent-only protocol, resumable token, fail-closed mobile feature | Godot 4.7.2 parse/runtime CI |
| 12. Public mobile CI | PARTIAL | Verify workflow green in repair runs; Android mobile build produced artifact; unsigned iOS pipeline repaired iteratively | User-observed iOS artifact success |
| 13. Canonical workspace | PASS | Repository canonical at `D:\LacViet\ShadowRift` with history intact | — |
| 14. Public repository | PASS | `main` and milestone branches pushed to public origin | — |
| 15. Live authority | PASS | Deployed Worker: health 200, session creation 201 observed | Device/network soak test |
| 16. Release gate & server E2E | PARTIAL | 12 Worker/DO integration tests in workerd, bounded fail-closed reconnect, static contract checks, Verify runs unit + integration + TypeScript | Remaining real-device behavior gates |
| 17. Landscape device stabilization | PARTIAL | Android real-device launch reaches SERVER ONLINE at 60 FPS; source locks landscape and uses expand stretch; verifier guards both settings | Fresh artifact must confirm full-screen landscape plus touch/combat/resume/reconnect behavior |

## Next action

M17 is the active milestone. The first real-device Android launch proves the APK starts, renders the HUD/world, reaches the live authority (`SERVER ONLINE`), and reports 60 FPS, but it exposed a portrait/letterbox defect. The source now explicitly locks mobile orientation to landscape and uses Godot 4.7 `expand` stretch for wide screens. Build fresh Android/iOS artifacts and keep platform status PARTIAL until the user observes full-screen landscape launch, input, combat, server resume, pause/resume, disconnect lock, reconnect recovery, and sustained 60 FPS on-device.
