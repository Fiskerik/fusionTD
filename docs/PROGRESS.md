# Elemental TD MVP status

| Milestone | Status |
|---|---|
| M0 · Scaffold | Godot project, test runner, and Windows and Bash tools |
| M1 · Data and rules | Data tables, original map, deterministic waves, elemental matchups, and economy |
| M2 · Simulation | Build and combat phases, range and targeting, upgrades, undo, gate lives, and rewards |
| M3 · Playable UI | Responsive battlefield, live building and upgrades, tower inspector, and named wave forecasts |
| M4 · Spirits and elements | Standalone spirit bonus rounds, one attempt per trial, and six elemental upgrade paths |
| M5 · Infusion | Level 2–6 infusion bands, elemental damage, trait scaling, swap, and removal |
| M6 · Fusion | All 15 dual and 20 triple recipes, preview, matchups, upgrade gates, and ingredient search |
| M7 · Enemies and bosses | Seven enemy properties, elemental waves, three rotating bosses, and Rally |
| M8 · Persistence | Build and active-wave checkpoints, profile, replay, first-run hints, and mobile haptics hook |
| M9 · Visuals | Element-specific tower silhouettes, eight enemy families, three boss silhouettes, tiered spirits, status effects, and impact footprints |
| M10 · Balance | Opening trials and later rounds exercised under the solo bonus format. See [Historical balance report](BALANCE_REPORT.md) for earlier full samples. |
| M11 · Documentation | [Run and play](README.md), [design decisions](DECISIONS.md), and [iOS export checklist](IOS_EXPORT.md) |

## Verification

- Godot 4.4.1 on Windows. The tests cover the simulation, live tower edits, all 15 fusion recipes, determinism, active-wave checkpoints, and the tower inspector.
- Both orientations rendered on desktop. Pointer checks exercised building, upgrading and selling during combat, opening tower details, loading the exact active-wave checkpoint, and resolving a solo spirit before a regular boss wave.
- Opening runs beat the first spirit with five level-1 Arrows or six level-1 Cannons. A focused Fire opening beat the first available Tier II spirit on its single pass.

## Release checks

Physical iPhone verification remains open for rotation, safe areas, touch targets, renderer compatibility, audio and haptics, suspend and resume, and 60+ enemy performance. iOS signing and export are documented. Platform services are stubs.
