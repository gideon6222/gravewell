# Notes - Gravewell

Decisions specific to this game, what has been measured, and what to do next. General
lessons go to `C:\dev\gamedev-notes\inbox\` via `/record-lesson`, never here.

## Decisions made without asking

From `PLAN.md` "Open decisions I made for him", verbatim, plus anything decided during the
build. One line each with the alternative, so he can reverse any of them.

1. **Name and slug: Gravewell / `gravewell`.** A gravity well is what you dig down through and
   a grave is what these worlds are. *Alternative:* anything he prefers. Renaming is cheap now.
2. **No mid-descent return trip.** *Alternative:* Coreward's climb back to the pad. Rejected on
   the research: it is the genre's most-cited complaint and it is the mechanism behind him never
   playing past 60 m of Coreward in seven sessions.
3. **The d-pad stays; no virtual joystick.** *Alternative:* Godot 4.7's built-in
   `VirtualJoystick`, if the first playtest asks for finer control.
4. **Collision stays on the cell grid while the visible rock is a marching-squares contour.**
   *Alternative:* collision on the contour, which is more correct, needs concave decomposition
   and cannot be tested nearly as cleanly.
5. **Seven world classes, two in phase one.** *Alternative:* more classes shallower, which is
   the Coreward mistake of twelve palettes over one cave.
6. **One room, not two shops.** The Hold is both the upgrade room and the hub.
   *Alternative:* a pad shop for refits and a separate hub, which is two chances to get wrong
   the screen he opens first.
7. **The core at about 200 m and five bands.** Provisional until the probe measures the real
   descent time. *Alternative:* whatever the probe says makes a descent five to ten minutes.
8. **Audio generated at build time into committed WAVs**, with sampled impacts where a sample
   is better. *Alternative:* fully sampled, if a pack fits the brief.

Decided during the build:

9. **Maaack's Menus Template is fetched at M10, not at scaffold.** It was fetched once at
   scaffold and taken straight back out: the tag ships **8.4 MB across 524 files**, most of it
   examples, media and docs, and carrying that through nine milestones of diffs and imports
   buys nothing while the shell is not wired in. It is one command at M10:
   `python C:\dev\gamedev-notes\scripts\assets.py get addon Maaack/Godot-Menus-Template v1.7.0 --into addons`,
   and `.gdignore` goes into `examples/`, `media/` and `docs/` the moment it lands.
   *Alternative:* fetch at scaffold, which the scaffold skill suggests, at the cost of 8.4 MB in
   history and a menu in front of every harness before there is a game behind it.
   **Its credits line is not in `assets/CREDITS.md` yet, on purpose:** the credits screen must
   never name something the build does not contain.
10. **`permissions/vibrate=true` set in both export presets at scaffold.** The plan uses
    haptics and `Input.vibrate_handheld` silently does nothing without it.

## Measured

| Date | What | Number | How |
|---|---|---|---|
| 2026-09-10 | Fresh copy of the template | tests and smoke green | `scripts\check.ps1` |
| 2026-09-10 | Dig rate, a working descent | **1.26 m/s**, mean of six planets | `run_probe.gd` |
| 2026-09-10 | A full 200 m descent, pure digging | **159 s**, so four to eight minutes with detours and uplinks | derived from the above |
| 2026-09-10 | Power budget, cautious descent | drill 34%, thrust 29%, lamp 19%, uplinks 15%, carrying 3% | `run_probe.gd` |
| 2026-09-10 | Filament in the ground, per planet | **17.5 total, only 4.5 of it above the Line**, from 7 to 13 caches | `run_probe.gd` |
| 2026-09-10 | Impact into a face while drilling, before the fix | 6.75 m/s and 17 hull a block | instrumented run |
| 2026-09-10 | Policy spread, 240 s, six planets | passive 0 cr / 0 m; diver 0 cr / 151 m (hull); cautious 230 cr / 62 m; greedy 426 cr / 101 m (always out of power); human 256 cr / 62 m | `run_probe.gd` |

**What the policy spread says.** Every policy fails for a different reason, which is the
signal the probe exists to give. Doing nothing banks nothing. Diving banks nothing and dies
to the Line at about 151 m, so depth on its own is worth precisely zero. Greed earns 1.9x
what caution earns and ends its descent every single time. That is the risk dial working at
M1 with no upgrades in the game yet; whether the reckless option *never actually works* is a
claim that can only be tested once the ladder exists, and it belongs to M7.

**CORE_DEPTH = 200 is now measured rather than provisional** (PLAN.md open decision 7 is
closed): 159 s of pure digging lands a real descent inside the plan's five-to-ten-minute
target.

## Corrections to PLAN.md made during the build

1. **`fill` is stored per CELL, not per corner.** The plan says corners. Collision is on the
   cell grid, and a per-corner store lets one dig bleed into three neighbouring cells that
   collision still calls solid. The first version averaged cells into shared corners at contour
   time; **see correction 6 below, which replaced that too** - the contour runs on the lattice
   of cell centres and samples the fill directly.
2. **Passability and the contour isovalue are two constants, not one.** `OPEN_FILL` (fully
   cut) decides what the ship can fly through; `CONTOUR_ISO` decides what the surface looks
   like. Sharing one number at 0.5 meant a half-cut cell was flyable, so the ship passed
   through cells it never finished and **nothing in the game ever broke or paid**: a scripted
   miner reached 86 m and mined zero kilograms. The failure was completely silent.
3. **The drill bites what is blocking the ship, not the cell under its nose.** On a diagonal
   those differ, and the nose version points at the corner cell, which the hull can never fit
   through. Measured before the fix: a miner held down-right and sat at 1.12 m for six hundred
   frames, cutting and never moving.
4. **Drilling never damages the hull.** Every cut block was arriving as a 6.75 m/s crash worth
   17 hull, so four blocks of ordinary digging ended a descent. The drill absorbs the face it
   is cutting; hitting rock you were *not* cutting still hurts.
5. **A diagonal hold does not dig in open ground, and that is correct.** With a free lateral
   run the ship slides and the drill nibbles a different cell every few frames, finishing
   none. You cannot dig while sprinting. The scripted miners are cardinal-only for the same
   reason a thumb on a d-pad is.

## Playtests (desk and phone)

(One dated section per `/playtest`: the six answers with frame numbers, the phone
percentiles and thermal, what changed because of it.)

## Ship log

(One dated section per `/ship`: POLISH.md lines that were no and what fixed them, deferred
lines with their phase, the release tag.)

## Next

See the first unticked milestone in `PLAN.md`.

## M2: the contour and the propagated lamp (2026-09-10, 0.3.0)

### What the light does now

The stack from `techniques/coreward-propagated-lighting.md`, ported and split
across the sim/render wall:

- **The flood** is a Dijkstra over OPEN cells storing `exp(-att * (path - octile))`,
  so open ground solves to exactly 1 and only geometry darkens anything. Runs on
  a cell change, not per frame.
- **The spill** carries that light one cell onto the rock faces beside it. Without
  it the game is a lit tunnel in a black screen, because the flood only ever
  reaches open cells and a wall is not one.
- **The fan** is 256 rays by grid DDA, every frame, recording the FAR corner of
  the first solid cell. The near corner puts every wall face in its own shadow,
  which is the artefact that cost five playtest rounds in Coreward.
- **Two lights.** `SURFACE = spill * falloff * beam` on the rock, and
  `AIR = flood * falloff * beam * shadow` on an additive quad behind the rock's
  front face. The shadow belongs to the air term only.

### Corrections to the plan, again found by tests and pictures

6. **The contour runs on the lattice of CELL CENTRES, not shared corners.**
   Averaging four cells into a corner cannot represent a single dug cell at all:
   one cell at 0 among solid gives every corner 0.75, above any isovalue that
   also calls untouched rock solid. Measured: `build()` returned zero segments
   after a cell was fully removed. Sampling cell centres is exact instead, and a
   fully cut cell puts the surface precisely on its own boundary, so the drawn
   opening and the passable opening are the same shape.
7. **`ALBEDO` is what Godot's lights multiply, not the final colour.** The rock is
   excluded from every light in the scene on purpose, so writing the solved field
   to `ALBEDO` produced a black screen at every setting. The shader is
   `unshaded` and owns its whole light model. Two rounds went into the falloff
   curve before one diagnostic frame rendering the field straight to EMISSION
   showed it was correct all along. Filed to `inbox/`.
8. **Vertex colour is sampled per VERTEX, not per cell.** Per-cell colour laid a
   hard grid of squares over a smooth continuous surface, so an ore vein read as
   a row of tiles. Per vertex it interpolates across every triangle and reads as
   mineral running through stone.

### Measured

| Date | What | Number | How |
|---|---|---|---|
| 2026-09-10 | Flood over the worst-case open window | under 60 ms for ten solves, so well under 6 ms each | `test_light.gd` bound |
| 2026-09-10 | Rock normal map, ambientCG Rock035 | 1K download, `size_limit` set to 512: a cell is about 66 px on the phone and the tile repeats every 2.2 cells, so 1024 was thrown away | ASSETS.md rule applied as a measurement |
| 2026-09-10 | APK with the contour, shaders and normal map | inside the size budget | `check_size.gd` |

### Still open at the end of M2

- **Volumetric fog is still assumed unavailable on Forward Mobile** and the air
  density drives the built-in depth fog instead. The measurement PLAN.md asks
  for has not been run yet, because nothing currently needs it: the four
  Mobile-safe layers are doing the job. Run it before anyone spends time on a
  `FogVolume`.
- No dust motes yet. They belong with the ambience pass at M9.
- The lamp pool still reads as a soft circle in a straight shaft, which is
  correct (a straight shaft has no detour to attenuate) but means the flood's
  character only shows once a descent has branches in it. Worth checking on a
  filmed run rather than a single frame.
