# Changelog

All notable changes are documented in this file.

## [Unreleased]

### Added

- Playable Godot 4.7.2 landscape mobile action-RPG vertical slice with Idle/Move/Jump/Attack/Hurt/Death states, a two-hit combo, one-shot jump touch, two skills, Warden and Wraith enemies, a single-phase Rift Warden boss, one spike hazard, and two one-way platforms.
- Isolated multi-touch controls with a fixed joystick, independent attack/jump/skill touch ownership, landscape safe-area positioning, and lifecycle reset on app pause or focus loss.
- HP, MP, EXP, level, gold, equipment, boss, pause, and FPS HUD with safe-area-aware positioning.
- Weapon and armor progression with canonical stat recomputation, checksummed local save data, pooled projectiles/damage numbers, and a 50 draw-call runtime budget monitor.
- Android and unsigned iOS pre-release artifacts for version `0.1.0`, plus deterministic source and Godot behavior verification in GitHub Actions.

### Changed

- Mobile gameplay now uses the same local Godot runtime as editor gameplay instead of the former network authority path, removing command round-trip latency and reconnect/pause races from the v1 combat loop.
- Enemy patrol/aggro/attack logic, boss chase/windup/strike logic, hazard damage, movement, jump physics, rewards, equipment, and persistence now execute locally on Android and iOS exactly as they do in editor runs.
- Pause and application lifecycle transitions clear active touch ownership before gameplay resumes, preventing held/stale mobile input after interruption.
- Export presets are explicitly pre-release presets with `0.1.0` package metadata; iOS CI remains intentionally unsigned and validates bundle/version metadata before packaging.

### Removed

- Cloudflare Worker/Durable Object authority, bearer-session persistence, server reconnect/fallback logic, server deployment workflow, and unused Android editor configuration script from the v1 shipped code path.
