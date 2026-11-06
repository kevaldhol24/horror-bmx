# Roadmap & status

_Last updated: 2026-11-06_

## v0.1 — vertical slice ✅ (this build)
- [x] Godot 4.6 project, Compatibility renderer, landscape Android export, CI → APK + "latest" release
- [x] Procedural BMX + faceless hooded rider with pedal/grip IK, lean, stand-up effort
- [x] Arcade controls: drag-steer, hop, brake (+ keyboard)
- [x] Endless curving/rolling road, 3 zones (Town / Woods / Cemetery)
- [x] Obstacles: pothole, rubble, ramp slab, rough patch, barricade, fallen tree; difficulty ramps with distance
- [x] Crash tumble, WIPED OUT screen with cause, best distance saved
- [x] Atmosphere: red storm sky + lightning/thunder, fog, flickering light pool, spores, VHS post, the Watcher
- [x] Generated synth music, ambience, SFX
- [x] Docs + screenshot test harness

## Waiting on owner phone test — questions to answer
- Does steering feel right? (too twitchy / too slow?) → `player.gd` `steer_rate`, `resp`
- Is speed right? Start 27 km/h, max ~56 km/h.
- Can you see obstacles early enough at night? (headlight range 42 m, fog 0.0105)
- FPS on the test phone? If < 50: lower `LIGHT_POOL`, disable headlight shadow, reduce spores, drop VHS aberration.
- Title/HUD readable on the phone's screen size?

## v0.2 — "feel" pass (after feedback)
- [ ] Apply tuning from the phone test
- [ ] Haptics on hop/land, screen-shake polish
- [ ] Tilt-steer option + left-handed layout option
- [ ] Settings: music/SFX volume, VHS effect on/off, graphics quality (low/med/high)
- [ ] Performance overlay toggle (FPS) for testing builds

## v0.3 — progression
- [ ] Currency (distance + pickups: batteries/coins/cassettes)
- [ ] Garage screen: headlight / bike / walkie-talkie upgrades, cosmetics
- [ ] The chase: entity behind you when you slow down
- [ ] More hazards (manholes, power lines, car pull-outs, gaps), new zone ("flipped" town)

## v0.4 — Play Store prep
- [ ] Release keystore, AAB export, versioning
- [ ] Rewarded ad "continue" (AdMob plugin for Godot 4), privacy policy
- [ ] Store listing art (screenshots via `tools/capture.gd`), trailer
- [ ] Closed testing track (or organization account to skip the 14-day test)

## Known issues / limits
- Debug APK only (debug keystore committed in `tools/`; release keystore needed for Play).
- Buildings are city-style row houses (KayKit City Builder) — reads as "downtown", not suburbs. A suburban house pack would help.
- Collision is box-based in road space; fine for now, imprecise for diagonal objects.
- Lateral offsets ignore curvature (fine at current curve strength).
