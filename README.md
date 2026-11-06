# Night Ride (repo: horror-bmx)

A third-person **horror BMX endless rider** for Android, made in **Godot 4.6** (Compatibility renderer).
A faceless kid in a mustard raincoat rides a red BMX through a dead 1984 town under a blood-red sky —
dodge potholes, hop rubble, launch off heaved road slabs, and don't look too long at the thing standing at the roadside.

> Status: **vertical slice v0.1** — riding, controls, 3 zones, obstacles, crash/retry, atmosphere. No upgrades yet (by design — see `docs/ROADMAP.md`).

## Get the APK (phone)

Every push to `main` builds a debug APK in GitHub Actions:

- **Easiest:** open the repo's **Releases → "Latest build"** on your phone and download `night-ride.apk`.
- Or: **Actions → Build Android APK → latest run → Artifacts → `night-ride-apk`** (zip, needs login).

Install: allow "install unknown apps" for your browser/file manager, open the APK.
Builds are signed with the repo's debug keystore, so each new APK installs over the previous one.

## Controls

| Touch | Keyboard (desktop) | Action |
|---|---|---|
| Drag left/right on the left half | A / D, ← / → | Steer |
| Tap **HOP** (or anywhere on the right half) | Space / W | Bunny-hop (clears potholes, rubble, logs) |
| Hold **BRAKE** | S / ↓ | Brake |
| **II** top-right | Esc / P | Pause |

Ride over the raised road slabs to jump. Broken patches shake you and slow you down. Barricades must be avoided.

## Run on desktop

Open the folder in Godot **4.6.x** and press Play (F5). Main scene: `res://scenes/main.tscn`.

## Repo map

```
scenes/main.tscn        single root node (Main + game.gd); everything else is built in code
scripts/                game logic (see docs/ARCHITECTURE.md)
shaders/                sky, road, terrain, VHS post, barricade stripes
assets/models/          KayKit CC0 models (city + halloween packs)
assets/audio/           procedurally generated sounds (tools/gen_audio.py)
assets/fonts/           Playfair Display + VT323 (OFL)
tools/                  dev tools: screenshot harness, asset previews, audio generator, APK build script
docs/                   design, architecture, build, assets/licenses, roadmap
.github/workflows/      Android APK CI
CLAUDE.md               handoff notes for AI/dev sessions — read first
```

## Docs

- `CLAUDE.md` — start here if you're picking the project up
- `docs/DESIGN.md` — vision, pillars, what the slice is
- `docs/ARCHITECTURE.md` — how the code works
- `docs/BUILD.md` — CI, local APK builds, signing
- `docs/ASSETS.md` — every asset's source and license
- `docs/ROADMAP.md` — status and next steps
