# Gravewell

A phone game for Android, built in Godot 4.7 from `C:\dev\godot-template` on 2026-09-10.
Package `com.gideon.gravewell`, repo `github.com/gideon6222/gravewell`.

@../gamedev-notes/INDEX.md

The shared rules, the Godot traps, the toolchain paths and the process are in
`C:\dev\gamedev-notes` (loaded above). This file carries only what is specific to this
game. **Read `PLAN.md` for what to build and `NOTES.md` for what was decided and measured.**

## This game

Cut down through a dead world toward its core, with only your lamp for light, then run for the surface with the core aboard.

Successor to **Coreward** (`C:\dev\coreward`, web/three.js, still live and still maintained).
Nothing was ported. What came across is the knowledge, in `REFERENCE.md`.

The design in the order it has to be understood:

1. **A planet is one sitting, and the descent is one-way.** You uplink ore from where you
   stand for a power cost that scales with depth and weight, rather than hauling it back. Your
   tunnels persist across descents, so running out of power costs the hold and never the
   planet, and re-descending is a fast dive down your own open shaft. The only ascent in the
   game is the extraction, and it is the climax. This exists because seven Coreward sessions
   never got past 60 m, and because the return trip is this genre's most-cited complaint.
2. **The lamp is the game.** Light floods through open cells only, so what you can see is the
   shape of what you have dug. Air density rises with depth and is **one simulated number**
   driving fog, lamp reach, bloom, audio muffling, reverb, drag and hull load together. Power
   running low dims the lamp, so being in trouble looks like the world closing in.
3. **A world class is a rule, not a palette.** Seven of them, each changing something about
   digging, flying or seeing, with the art following from the rule.
4. **Two currencies, so survival costs exploration and not time.** Credits are mined and buy
   the routine ladder. **Filament is only ever found**, in caches and vaults, and it is the only
   thing that buys a counter to a threat. Grinding the shallow band forever cannot buy safety.
5. **The goal is the Gravewell Drive**: seven slots, one core per class, assembled physically
   in the Hold, advancing once per planet and therefore once per sitting.

## Commands

```powershell
scripts\check.ps1                 # import, tests, smoke, visual guard, size guard
scripts\check.ps1 -Export         # plus the debug APK
scripts\movie.ps1 -Replay test\replays\first-minute.json -Seconds 60 -Every 30
scripts\device.ps1 install | launch | log | shot | record 30 | perf | back | home | resume
& $env:GODOT --path . --resolution 460x996 --script res://scripts/shot.gd -- 30 <state>
& $env:GODOT --path .              # the editor
```

## Files

| File | What it is |
|---|---|
| `src/sim/sim.gd` | **The whole game, with no renderer in it** |
| `src/sim/tuning.gd` | Every number that shapes how it feels, with the reason beside it |
| `src/sim/util.gd`, `rng.gd` | `hash2`, `smooth`, `fmt`; the seeded stream |
| `src/game/main.gd` | The shell: reads `Sim`, draws it, feeds it input. Decides nothing |
| `src/build_stamp.gd`, `changelog.gd` | Stamp (overwritten by CI) and version + patch notes |
| `test/policies.gd` | Scripted players. The definition of "playing well" |
| `test/run_tests.gd`, `run_smoke.gd`, `run_probe.gd` | Pure suite, real-scene smoke, balance probe |
| `test/harness.gd` | The assertions, with `FLOAT_EPS` |
| `test/replays/*.json` | Recorded touch scenarios for filmed runs |
| `scripts/replay_player.gd` | Autoload: `-- record=<file>`, `-- replay=<file>`, `-- touch` |
| `scripts/shot.gd`, `check_size.gd`, `stamp.ps1`, `export_release.bat` | Screenshot, size guard, stamp, Play AAB |
| `assets/CREDITS.md` | Every imported asset, appended by `assets.py` |
| `PLAN.md`, `NOTES.md`, `REFERENCE.md` | The plan and milestones; decisions and measurements; the reference game, observed |

## Invariants specific to this game

Shared invariants live in `GODOT.md`. These are the ones this game will silently break.

- **Every generator rolls on its own seed offset**, from the one table in `src/sim/world.gd`:
  ore `+0`, seams `+17`, caches `+41`, caverns `+77`, vaults `+113`, growth `+131`, ambience
  `+149`. Consuming an existing roll shifts every ore at every depth on every planet and the
  diff looks like three lines. A test asserts the table has no duplicate offsets.
- **`test/baseline/blocks-baseline.json` is frozen and is never re-recorded.** The test asserts
  the only legal difference: a cell kept its id, or a known overwriter replaced it.
- **Corner fill is one float doing three jobs**: partial dig damage, the marching-squares
  input, and what the light flood calls passable. Anything that writes it writes all three.
- **A class's Line depth equals its rock-band change depth**, and a test asserts they stay
  equal. Four things land on that metre: the rock, the air, the hull drain and a sound. They
  drifted apart silently in Coreward and the report was that the line could be felt and not
  found.
- **Collision is on the cell grid, never on the contour.** The contour may not encroach more
  than 0.15 of a cell into a cell collision calls open, and a test asserts that band, or the
  player hits rock they cannot see.
- **Surface light and air light are two lights**, combined with `max()` and never by
  multiplying two floors. The shadow fan belongs to the air term only. The fan records the far
  corner of the cell it hits, not where the ray leaves it.
- **Filament is never obtainable by mining.** If a Line counter can be bought from ore income
  alone, the central balance fix is gone. `test_economy.gd` asserts it.
- **The ascent is bounded**: the timer derives from the shortest open route from core to
  surface, is re-derived after every collapse, and a collapse that makes the surface
  unreachable is reverted. A hazard never takes the run.
- **`Changelog.VERSION` and `version/name` in both export presets are one fact**, and a test
  asserts they agree.

## Ports and identifiers

Nothing on the web stack here. Package `com.gideon.gravewell`, APK `build/gravewell.apk`, AAB
`build/gravewell.aab`, launch component `com.gideon.gravewell/com.godot.game.GodotAppLauncher`.
