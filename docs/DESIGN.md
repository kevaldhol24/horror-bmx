# Design

## Pitch
An 80s-small-town horror BMX endless rider. You're a kid out after curfew, riding home through a town that's
gone *wrong*: blood-red sky, ash drifting upward, street lights failing, and something tall standing at the edge
of the road. Keep pedaling. Don't crash.

**Inspiration (vibe only, no IP):** 80s supernatural teen-adventure shows, VHS camcorder footage, synth scores.
Never use names, logos, characters or music from any existing show.

## Pillars
1. **Riding feels good** — responsive steering, satisfying hops/launches, readable obstacles. If this isn't fun, nothing else matters.
2. **Dread, not jump-scare spam** — atmosphere does the work: light, fog, sound, the Watcher. Scares are rare and earned.
3. **Looks professional on a cheap phone** — stylized low-poly + strong lighting/post, not detail. Darkness and fog hide budget.
4. **Short sessions** — 30 s to 3 min runs, instant retry.

## The slice (v0.1) — what exists
- Third-person chase camera; title screen orbits the rider (faceless hood stares at you).
- Arcade BMX: auto-pedal to a cruise speed that rises with distance (27 → 56 km/h), steer, brake, bunny-hop.
- Endless curving, rolling road; 3 zones cycling every 420 m: **Town → Woods → Cemetery**.
- Obstacles: potholes, rubble, heaved road slabs (ramps → air), broken rough patches (shake + slow), ROAD CLOSED barricades, fallen trees.
  Early road (<260 m) only spawns potholes/ramps to teach hopping.
- Horror layer: red storm sky with lightning + thunder, flickering/dying street lights, drifting spores, VHS overlay
  (grain, scanlines, chromatic fringe, glitches), **the Watcher** (tall shadow figure with red eyes ~every 150 m —
  lights cut out as you pass and it's gone), dissonant sting.
- Original synth loop + ambience + SFX, all generated (`tools/gen_audio.py`).
- HUD styled as a 1984 camcorder (REC, date/time), distance + speed, best distance saved.

## Planned systems (only after the riding is approved)
- **Meta progression / upgrades** (between runs, currency = distance + pickups):
  headlight (range/width/battery), bike (top speed, hop height, grip), walkie-talkie (warns of hazards ahead),
  flashlight-burst (scares the Watcher away), cosmetic bikes/raincoats.
- **The chase**: something that follows you when you slow down or crash — speed becomes survival, not just score.
- **Pickups**: batteries, cassette tapes (lore/collectibles), coins.
- **More hazards**: open manholes, fallen power lines (timed sparks), a car pulling out, crows, "the road ends" gaps
  that require a ramp, fog banks where the headlight is the only thing you can see.
- **Zones**: the lab fence road, the quarry, the "flipped" world (same town, inverted colours, floating debris).
- **Missions**: daily challenges (hop 20 potholes, ride 2 km without braking).
- Monetization (Play): rewarded ad to continue once, optional ad-removal IAP. No forced interstitials mid-run.

## Tuning knobs (where to change feel)
- Speeds/accel/hop: constants at top of `scripts/player.gd`.
- Steering responsiveness: `_physics_process` in `player.gd` (`resp`, `steer_rate`).
- Difficulty curve: `world.gd` → `_slot_has_obstacle` (gap 17 m → 10 m over 2.6 km) and `_spawn_obstacles` mix.
- Atmosphere: `game.gd` → `_build_environment` (fog density/colour, ambient, glow) and `shaders/sky.gdshader` uniforms.
