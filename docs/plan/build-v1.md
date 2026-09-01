# ARPG mobile v1 build

## Status

M18 is the single final milestone. It absorbs every remaining PARTIAL gate from M1–M17 so there is no M19+ roadmap for v1.

| Milestone | Status | Evidence / closure path |
| --- | --- | --- |
| 1. Player FSM and input | ABSORBED → M18 | FSM + two-hit combo runtime tests; isolated multi-touch runtime test; final touch feel remains device acceptance. |
| 2. Combat | ABSORBED → M18 | Canonical damage behavior test remains in the Godot suite. |
| 3. Zone | ABSORBED → M18 | Runtime structure test asserts three TileMapLayer nodes, hazard, and both one-way platforms. |
| 4. Enemies | ABSORBED → M18 | Warden and boss FSM smoke tests execute in Godot CI; tuning feel remains device acceptance. |
| 5. Boss and HUD | ABSORBED → M18 | Full-scene boot test + pause overlay contract + landscape device acceptance. |
| 6. Inventory | ABSORBED → M18 | Hero equipment cycling + canonical stat test. |
| 7. Save | ABSORBED → M18 | Real `user://` filesystem round-trip and checksum tamper rejection test. |
| 8. Performance | ABSORBED → M18 | Pool reuse + 60 FPS cap + 50 draw-call budget contracts; sustained FPS/thermals remain device acceptance. |
| 9. Mobile exports | ABSORBED → M18 | Android artifact previously launched; final landscape Android + unsigned iOS artifacts are triggered by M18. |
| 10. Authority server | PASS | Unit tests + Worker/Durable Object E2E + live authority health/session evidence. |
| 11. Protected client | ABSORBED → M18 | Runtime bounded reconnect, resume, fail-closed intent clearing, and pause zero-movement contracts. |
| 12. Public mobile CI | ABSORBED → M18 | Verify + Android + unsigned iOS workflows; M18 produces the final trigger. |
| 13. Canonical workspace | PASS | Canonical repo at `D:\LacViet\ShadowRift`. |
| 14. Public repository | PASS | Public origin with milestone branches and `main`. |
| 15. Live authority | PASS | Live Worker health/session creation previously observed. |
| 16. Release gate & server E2E | ABSORBED → M18 | 12 Worker/DO integration tests + expanded Godot runtime suite. |
| 17. Landscape device stabilization | ABSORBED → M18 | Landscape lock + `expand` stretch guarded statically; final visual fit is device acceptance. |
| 18. V1 Final Closeout | PASS (baseline) | M18 Verify + Mobile builds completed green. Post-M18 acceptance hotfix stays outside milestone numbering. |

## Post-M18 device acceptance hotfix

`hotfix/mobile-input-ui-polish` addresses real-device evidence without creating M19: dedicated one-shot jump touch, immediate protected movement dispatch on direction changes with 80 ms periodic sync, fixed-base joystick/dead-zone improvements, compact landscape HUD, and procedural visual polish for controls/world/hero/enemies/boss/hazard. The Godot suite expands from 14 to 15 behavior tests to lock the input fix.

## Automated gate

`Verify` must run the static source contract, Godot import/parse, 15 GDScript behavior tests, server unit tests, Worker/Durable Object integration tests, and TypeScript type-check. `Mobile builds` must produce the Android debug APK and unsigned iOS IPA artifact.

## Final external acceptance

These observations intrinsically require real hardware and remain outside automated truth claims: full-screen landscape/safe-area visual fit, physical multi-touch feel, combat/tuning feel, pause/resume feel, disconnect/reconnect during a real network transition, sustained FPS/device thermals, final Android install/launch, and unsigned iOS artifact/device-side validation where applicable. Once those are observed, v1 has no remaining milestone.