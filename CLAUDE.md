# Gravewell

A phone game for Android, built in Godot 4.7 from `C:\dev\godot-template` on 2026-09-10.
Package `com.gideon.gravewell`, repo `github.com/gideon6222/gravewell`.

@../gamedev-notes/INDEX.md

The shared rules, the Godot traps, the toolchain paths and the process are in
`C:\dev\gamedev-notes` (loaded above). This file carries only what is specific to this
game. **Read `PLAN.md` for what to build and `NOTES.md` for what was decided and measured.**

## This game

Cut down through a dead world toward its core, with only your lamp for light, then run for the surface with the core aboard.

The design in the order it has to be understood: (fill from PLAN.md at scaffold time)

1.
2.
3.

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

(Add one line per rule the plan established. Shared invariants live in GODOT.md; do not
copy them here.)

-

## Ports and identifiers

Nothing on the web stack here. Package `com.gideon.gravewell`, APK `build/gravewell.apk`, AAB
`build/gravewell.aab`, launch component `com.gideon.gravewell/com.godot.game.GodotAppLauncher`.
