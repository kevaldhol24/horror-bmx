# CLAUDE.md — handoff notes

Read this first. It's the fastest way to continue the project in a new session or account.

## What this is

**Night Ride** — Godot 4.6 horror BMX endless rider for Android (Play Store target). Owner tests on his phone
via APKs built by GitHub Actions; he does not run the editor. Owner wants a *professional-looking first
impression* and only expands the game if the riding itself feels good.

Current state: **v0.2 look pass** (portrait, matched to a reference reel — see `docs/DESIGN.md` › Look target). See `docs/ROADMAP.md` for what's done / next.

## Golden rules

1. **Godot 4.6.2, Compatibility renderer (GLES3).** Chosen for widest Android support. No Forward+ features
   (no volumetric fog, no SSR/SSAO/SDFGI). Don't switch renderers without asking.
2. **Everything is built in code.** `scenes/main.tscn` is one node with `scripts/game.gd`. Hand-written `.tscn`
   files are fragile; prefer code.
3. **The road is a pure function of distance** (`scripts/road_path.gd`). Never store road geometry; sample it.
4. **Assets must be CC0/OFL or generated.** Log every new asset in `docs/ASSETS.md`.
5. **Verify visually before pushing.** Use the screenshot harness (below). The owner judges by looking.
6. Keep `docs/ROADMAP.md` status current when you finish something.

## Gotchas already learned (don't re-learn them)

- **Triangle winding:** Godot front faces are **clockwise**. Procedural meshes in `world.gd` use (a, c, b) order.
  CCW makes the road invisible (you'll see the sky's below-horizon colour instead — looks like "red ground").
- **Portrait 720×1280.** Camera uses `KEEP_WIDTH`, so FOV is *horizontal* (66–76° chase). Capture with
  `xvfb-run -s "-screen 0 720x1280x24" ... --resolution 720x1280`.
- **Wet road is faked** in `road.gdshader`: it reflects the view vector and evaluates a copy of the rift sky analytically,
  plus anisotropic streaks for the 5 pooled lamps (`world.gd` pushes `lamp_pos/lamp_col` every frame). If you change
  `sky.gdshader`'s rift maths, mirror it in `sky_reflect()`.
- **Lightning flashes are random** — two screenshots can differ wildly in brightness. `capture.gd` disables lightning
  during rides so comparisons are fair.
- **Rift light** (`moon` in game.gd) is the only shadow caster (rider shadow toward camera). Its specular is ~0 on
  purpose: a real highlight on the wet road made a blob at the bottom of the screen.
- **Sky reflections are disabled** (`REFLECTION_SOURCE_DISABLED`): the red sky over-tinted every surface.
- **Fog** is exponential, density ~0.01. Above ~0.016 the near field washes out to flat red.
- **KayKit characters are chibi** (huge heads, tiny legs). They looked cartoony and mis-scaled on the bike, so the rider
  is a procedural kid (`bike_model.gd`): navy jacket, rust backpack, olive pants, white high-tops (matches the reference). Don't swap back without a properly proportioned rigged human.
- **Obstacles spawn in global 4 m slots** (`world.gd: _slot_has_obstacle`), not per chunk — the average gap is
  larger than a chunk, so a per-chunk loop placed nothing.
- `TextServer.name_to_tag` is not static → use `TextServerManager.get_primary_interface().name_to_tag(...)`.
- In a `SceneTree` tool script, use `look_at_from_position` (nodes aren't fully in-tree during `_init`).
- WAV loops are configured at runtime in `audio_director.gd` (`loop_mode` + `loop_end`), not in `.import` files.

## How to test without a phone

Godot binary must be on PATH as `godot` (download `Godot_v4.6.2-stable_linux.x86_64.zip` from GitHub releases).

```bash
godot --headless --import                       # import assets (first run / after adding assets)
godot --headless --quit-after 300               # smoke test: no script errors
# Screenshots (software GL via xvfb). Args: out_prefix start_distance shots [noauto]
xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-driver opengl3 --resolution 720x1280 -s tools/capture.gd -- /tmp/cap 0 4
xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-driver opengl3 --resolution 720x1280 -s tools/capture.gd -- /tmp/cap 440 2   # woods
xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-driver opengl3 --resolution 720x1280 -s tools/capture.gd -- /tmp/cap 880 2   # cemetery
xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-driver opengl3 --resolution 720x1280 -s tools/capture.gd -- /tmp/cap 200 12 noauto  # crash + game over
```
`capture.gd` writes `_title.png`, numbered ride shots, and `_crash/_over.png`. It has a tiny autopilot that dodges obstacles.
FPS printed under xvfb is meaningless (software rendering).

Other tools: `tools/preview_sky.gd` (sky shader only), `tools/preview_bike.gd` (bike/rider turntable), `tools/preview_assets.gd` (model grid),
`tools/model_bounds.gd` (model sizes), `tools/gen_audio.py` (regenerates all audio).

APK locally: see `docs/BUILD.md` (`tools/build_android.sh`, same script CI uses).

## Code map (short — details in docs/ARCHITECTURE.md)

| File | Role |
|---|---|
| `scripts/game.gd` | root: env/sky/fog, state machine (title/play/pause/crashed/over), collisions, lightning, FX, save |
| `scripts/road_path.gd` | road centre/height/heading as functions of distance `s`; terrain height |
| `scripts/world.gd` | chunk streaming (24 m), zone decoration (Suburb/Woods/Cemetery), obstacles, street-light pool, Watcher, Gate |
| `scripts/suburb.gd` | procedural houses (lit windows), power lines + cobra lamps, Gate building — each merged into one mesh |
| `scripts/player.gd` | arcade bike physics in road coords (s, lat, air), hop/launch/crash tumble, headlight |
| `scripts/bike_model.gd` | procedural BMX + procedural rider with 2-bone IK (pedals, grips) |
| `scripts/chase_camera.gd` | orbit (title) / chase / crash camera, FOV, roll, trauma shake |
| `scripts/ui.gd` | HUD (VHS camcorder style), title/pause/game-over, touch + keyboard input |
| `scripts/audio_director.gd` | music/ambience/tyre/freewheel loops + one-shots |

## Owner preferences (for tone of work)

- Concise, direct communication. Honest expectations over hype.
- He pivots fast if something doesn't "kick" — keep iterations small and visible (push → APK → phone).
- Target market: Google Play, Indian + global audience; mid/low-end Android phones matter.
