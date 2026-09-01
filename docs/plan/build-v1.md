# ARPG mobile v1 build

## Current state

M1–M18 source scope is closed. The final PRO pre-release remediation removes the experimental gameplay authority server from the shipped v1 path because real-device testing showed unacceptable network latency and availability friction for a single-player action game.

| Gate | Status | Evidence / acceptance |
| --- | --- | --- |
| Player FSM + two-hit combo | SOURCE COMPLETE | Godot behavior tests cover state transitions, combo cap, jump one-shot, hurt, death. |
| Multi-touch mobile input | SOURCE COMPLETE | Isolated joystick/action ownership, safe-area mapping, lifecycle reset behavior tests. |
| Combat + hazard | SOURCE COMPLETE | Canonical local melee/environment damage tests; enemy/boss FSM smoke tests. |
| Zone | SOURCE COMPLETE | Three TileMapLayer nodes, hazard, and two one-way platforms verified at runtime. |
| Inventory + progression | SOURCE COMPLETE | Canonical equipment/stat behavior test. |
| Save | SOURCE COMPLETE | Real `user://` round-trip, schema/range checks, checksum tamper rejection. |
| Pause/lifecycle | SOURCE COMPLETE | Scene-tree pause/resume plus touch reset contract. |
| Performance | SOURCE COMPLETE | 60 FPS cap, pooled effects, 50 draw-call budget; sustained thermals remain device acceptance. |
| Android/iOS layout | SOURCE COMPLETE | Landscape + `expand` stretch + safe-area-aware HUD/controls. |
| Android pre-release artifact | CI GATE | Installable debug-signed `0.1.0` APK with package/version metadata verification. |
| iOS pre-release artifact | CI GATE | Unsigned `0.1.0` device app/IPA with bundle/version metadata verification. |
| Production store signing | OUTSIDE PRE-RELEASE | Requires owner Android keystore and Apple signing identity/profile; no secrets belong in the public repo. |

## Architecture decision

v1 uses one local native Godot flow on editor, Android, and iOS. There is no `server_authoritative` export feature, network authority client, Cloudflare gameplay service, bearer session, reconnect state machine, or server deployment workflow in the shipped pre-release source. This keeps movement/combat responsive and removes the pause/network race class identified during device testing.

The local save checksum is a corruption/tamper signal, not a security boundary. Reopen server/account/device-attestation architecture only if later product scope adds valuable shared state such as leaderboards, trading, paid currency, or cloud progression.

## Final external acceptance

Only real-device observations remain: full-screen landscape/safe-area visual fit on representative Android/iPhone devices, physical multi-touch feel, combat tuning, sustained FPS/thermals, Android install/launch, and final iOS signing/install once owner credentials are supplied. These are device acceptance checks, not additional source milestones.
