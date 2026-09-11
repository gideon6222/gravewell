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

## M3: the ship (2026-09-10, 0.4.0)

Modelled by hand from prisms, because the asset scout found no photoreal CC0
ship or drone anywhere. No spheres: "a sphere reads as a bubble at any size",
and Coreward's sphere cockpit is what got the ship called "bubbly and
cartoonish". The four upgrade mount points exist from this milestone even though
nothing hangs on them until M7, so a part lands where the hull expects it.

### Two more things found rather than reasoned

9. **The white blob was not the ship.** Two rounds went into the hull's metallic
   and albedo before the blob turned out to be the additive haze quad, drawn in
   FRONT of the ship and brightest at exactly zero distance from the lamp. The
   haze now sits behind the ship inside the tunnel volume, and it has a
   near-field ramp - which is also the physically right shape, because there is
   no path length to scatter along at a beam's own source.
10. **Metallic 0.55 on the hull was wrong for this scene.** A metal with nothing
    to reflect is black plus hotspots, and this scene is a hole in the ground
    with a background colour and no sky. Dropped to 0.12 and the shape came back.

### Framing

`CAM_DIST` is 15.5, about six cells across, which puts the ship at roughly 60 px
on the phone. Under about sixty pixels a machine reads as a shape rather than as
a machine. **Framing is an upgrade**: the lamp ladder pulls this back at M7, and
the darkness is what justifies the tight frame at the start.

## M4, M5 and M6 (2026-09-10, 0.5.0)

### The HUD

Instruments rather than themed widgets, because where a readout sits matters
more than how it looks. Power and hull are slim drawn columns up the LEFT edge,
which is where the thumb never goes; depth is large at the top in a monospace
face so the number does not jitter sideways as it climbs; load is top right and
opens the manifest; and a rate readout appears beside whichever gauge is
draining, because a number beats a bar when the player needs causation.

The manifest scrolls by hand, because a `ScrollContainer` does not scroll from a
finger at all, and its CLOSE is pinned to the bottom. Both are answers to
recorded blockers.

### The Line

Four things land on 80 m and a test keeps them there: the rock tint, the air
colour, the rock hardness and the hull drain. `BAND_TINT` makes the Line the
biggest colour step in the table on purpose, because it is the boundary the
player has to notice from a moving ship without being told.

**A cache shows through one layer of rock** as a discolouration in the wall. That
is the whole design of the secret layer in one rule: you find it by reading the
world, not by a marker on a map.

### The extraction

Cutting the core free starts the world dying from the bottom up. The clock is
**derived from the route actually dug** (the shortest open path, at the speed a
laden ship makes, times a margin), so a winding descent gets a long climb and a
straight shaft a short one, and neither is a guess. A flat timer would be a
stroll on one and impossible on the other, with no way to know which.

`World.collapse()` refuses any fill that would seal the only way out, and
`test_sim.gd` falsifies that guard by also asserting a collapse beside a second
route succeeds. Otherwise the test would pass by collapse never doing anything.

### Two more things found rather than reasoned

11. **The safe area is mobile-only.** Off a phone `get_display_safe_area()`
    returns the usable desktop, and the conversion divided by the monitor size
    rather than the window's, so every control sat 104 px above where its offsets
    said. Every check passed: the smoke test asserts the controls are anchored
    and they were, a headless viewport is 100x100 where wrong and right are
    identical, and a screenshot looked fine because the drawing moved with the
    hit box. **A filmed replay found it**: the taps landed in empty space, the run
    filmed perfectly for sixty seconds and the ship never left the surface.
    `scripts/rects.gd` now prints every control's real global rect from a real
    window, which is the only honest way to write replay coordinates.
12. **The APK came out at 1.42 GB.** Filming leaves 3,720 PNGs in `build/`, which
    is inside the project, and the exporter packs anything inside the project
    directory. `.gitignore` has no say in it. The size guard is the only check in
    the whole gate that had an opinion, which is the argument for having one from
    the first commit.

### Measured

| Date | What | Number | How |
|---|---|---|---|
| 2026-09-10 | Control displacement from the safe-area bug | **104 px upward** | `scripts/rects.gd` |
| 2026-09-10 | APK with `build/` packed | **1,423,818,175 bytes** against a 28 MB budget | `check_size.gd` |
| 2026-09-10 | APK with `build/` excluded | 27.54 MB, +2.10% drift | `check_size.gd` |

## M7: the Hold, and the first filmed run (2026-09-10, 0.6.0)

### The shop is a room

The real `Ship` node is reparented into it, so a part bolted on in the shop is
bolted on in the world by construction rather than by two systems agreeing. The
world is hidden entirely behind it: leaving half of it visible is what makes a
screen read as a pop-up however it is styled, and that was the note Coreward got
*after* its panel had already been restyled twice.

The rack lays out from the COUNT rather than from a fixed table, the drive frame
with its seven slots is on the wall from the first hour, and LAUNCH is pinned to
the bottom where scrolling cannot take it.

**The first screenshot of it had "THE GRAVEWELL DR..." running off the frame**,
which is the exact "some of the words are cut off" complaint arriving in a new
room. Labels are sized from the pixels they will occupy: at this camera the
visible width is about 2.7 units, so the text has to fit inside that before
anything else about it matters.

### Two currencies

`Upgrades` splits the ladder in two and `test_economy.gd` asserts the split by
trying to break it: a billion credits cannot buy a pressure seal, and no rung of
the credit ladder has a filament price. Every counter also carries a `verb`,
because a tool that only unlocks a door makes backtracking a fetch quest.

Prices use Motherload's rising-step curve plus Rogue Legacy's per-purchase
surcharge across the whole tree. The first seal costs 4 filament against the
4.5 a planet yields above the Line, so it is affordable exactly once and not
comfortably.

### The first filmed run, against the six questions

Reviewed `build/movie/first-minute/sheet.png`, sixty seconds, one tile a second.

1. **Feedback on every action?** Visual yes: the shaft grows behind the ship, the
   lamp pool moves with it, the thrusters light. **Audio and haptics are absent**
   and belong to M9. Partial.
2. **Speed within a fifth of a second, and coasting?** Not answerable from tiles
   a second apart. Asserted in `test_fly.gd` instead, which is the right place.
3. **Anything popping in or drawn over something?** No. The terrain rebuild on a
   cell change is invisible, which is what it was built to be.
4. **Are the short states visible?** The Line warning and the manifest both
   appear. The extraction and the Hold are not in this scenario and need their
   own replays.
5. **Is the first minute a win, and is the next goal visible?** The first ore is
   cut within a few seconds and the load readout moves. The uplink at 25 s is
   hard to confirm from the sheet, which is itself a finding: **banking a haul
   needs a visible event**, not just a number changing.
6. **A frame where the player would not know what to do?** Not exactly, but
   **the middle of the descent is monotonous.** From about 30 s to 50 s the sheet
   is a long thin shaft with the ship at the bottom and very little else. The
   lamp is doing its job and the rock is handsome, and there is nothing to
   decide. That is the honest weakness of the current build and the thing
   ambience, caches and per-class events exist to fix.

**What the film proves that no screenshot could:** the flood fill reads in
motion. The shaft bends where the player turned and the light bends with it,
which is the whole of what he asked for, and it is only legible as a sequence.

## M8: Rime, and one threshold too many (2026-09-10, 0.7.0)

### A class is a rule

`Classes` holds what a world IS, and `test_classes.gd` asserts that any two
classes differ on at least **three of five** channels a player can perceive, with
the palette counting for exactly one of them. That assertion is the whole file's
reason to exist: Coreward had twelve planets and they were twelve tints on one
cave.

Rime changes three things and the art follows from them:

| | |
|---|---|
| Hardness x0.5 | ice cuts in half the time, so a descent is quick |
| Brittle ceilings | cut a span of three or more and the rock above starts to go |
| Detour attenuation 0.24 against Cinder's 0.55 | ice carries light much further, so a Rime tunnel is legible far past where a Cinder one goes black |

Measured side by side over the same forty seconds from the same seed: Cinder
57 m and 84 credits, **Rime 89 m and 268 credits.** The world is faster and
richer, and the ceilings are what it charges for that.

### The bug that took three wrong theories

**Two thresholds for "gone" that did not agree.** `is_open` called a cell
passable at `OPEN_FILL` (1e-4) while `cut` only broke it at exactly 0.0. A cell
landing in that gap is flyable and has never broken: it never yields, and its
material stays whatever it was forever.

Whether a cut lands in the gap depends on `hp / hardness` against the remaining
fill, so it never happened on Cinder and happened constantly on Rime, whose
hardness multiplier is 0.5.

The symptom looked nothing like the cause. A scripted miner reached 15 m in forty
seconds and mined nothing, ping-ponging between two cells it had already dug
because they still reported themselves as iron. Three plausible causes were
reasoned about first - falling ceilings trapping it, the ship inside rock, the
bot oscillating on a rounding boundary - and all three were wrong. One print of
the cells around the stuck ship ended it.

**This is the second time this file has had two thresholds for gone.** The first
was the OPEN_FILL/0.5 mismatch at M1. Filed to `inbox/`. The test that catches it
sweeps eight bite sizes across two classes and five depths and asserts the
property directly: a passable cell has always broken, and reports no material.

### Open

Brittle ceilings did not fire once in a forty-second scripted descent, because
the bot digs cardinally and one cell wide, which is exactly the safe way. That is
the intended shape - narrow is safe, wide is the gamble - but it means the rule
is opt-in, and whether a real player triggers it is a question for the phone
rather than for the probe.

## M9: sound, and the dark it happens in (2026-09-10, 0.8.0)

### Sampled and generated, and which is which

`ASSETS.md`: sample where a sample is better, synthesise where the sound must
answer the game.

**Sampled**, from Kenney (CC0): the drill bite (`impactMining`), rock breaking,
ore, hull impacts, ice, and the UI. The packs came to 2.5 MB and were trimmed to
the six families actually used, which is 800 KB.

**Generated at build time** into committed WAVs by `scripts/gen_audio.gd`: two
ambient beds and the theme, 32 s each. They are generated because they crossfade
on depth and a recording cannot, and generated at BUILD time because GDScript
synthesis at runtime costs seconds of black screen on a phone.

### His one recorded outright dislike, answered by construction

"The music has random higher pitch beeps that I dont like."

Nothing in `gen_audio.gd` is chosen at random. The theme is a written 32-step
phrase over a fixed i-VI-III-VII in A minor, two bars answered by two that
resolve, with a bass on every bar for the pulse. Every note has a 0.28 s attack
and a long release, and the root is A1, well below where a sine gets shrill. All
three of those are readable in the source rather than only audible.

### Two things driven from numbers the game already had

- **The reverb reads the light solver's openness.** The flood already computes
  how open the space around the ship is in order to decide what the lamp reaches;
  the reverb reads the same number. A tight shaft is dry and close, a cavern is
  enormous. One quantity, two uses, and no second notion of room size that could
  disagree with the first.
- **The muffle reads the air.** `density_at` drives the fog, the lamp, the drag
  and the hull load, and now a lowpass. The deep sounds muffled because it is
  denser, from the same number that makes it look it.

The theme goes QUIETER as the pressure rises, and is silent for the whole
extraction. The quietest the game ever gets is the moment it is most dangerous.

### The polish pass

A vignette in three stops rather than one falloff, animated grain on the
mid-tones only, a touch of aberration that grows from the centre, and blacks
lifted toward the scene colour. The last is the one people leave out: a game this
dark spends most of its frame at zero, and true black reads as a hole in the
screen rather than as unlit rock.

**It is under the HUD, and the first version was not.** Added as a sibling in one
CanvasLayer the post drew LAST and therefore on top, which put chromatic
aberration on the edges of every button. Two layers, numbered.

### Measured

| Date | What | Number | How |
|---|---|---|---|
| 2026-09-10 | Kenney packs as downloaded, and trimmed | 2.5 MB to 800 KB | six families kept of twenty |
| 2026-09-10 | Generated beds and theme | three 32 s mono WAVs, 1.4 MB each | `gen_audio.gd` |
| 2026-09-10 | APK with all audio | 28.78 MB, +6.7% before the budget was re-recorded | `check_size.gd` |

## M10: the shell, and the desk playtest (2026-09-10, 0.9.0)

### What is in

A title over the live world with CONTINUE greyed rather than hidden. Save and
settings in two separate files with a one-way erase latch. The pause sheet with
the version, the build stamp and every patch note. The back button unwinding one
layer per press, with its handler and `quit_on_go_back` in the same commit. A
generated adaptive icon, a monochrome layer, a splash in the game's own dark, and
`keep_screen_on`.

### Screens looked at as pictures, and what each one cost

Every screen in this game has now been looked at once at the phone's aspect
before shipping, and **three of them had text running off the frame**, which is
the same recorded complaint arriving three separate times:

| Screen | What the picture showed | Fix |
|---|---|---|
| The Hold | "THE GRAVEWELL DR..." off the right edge | centred, and sized from the pixels it occupies |
| The pause sheet | every patch note cut off mid-word | `draw_string` CLIPS at its width; `draw_multiline_string` wraps |
| The title | the version line under the SETTINGS button | moved above the buttons |

That is worth stating plainly: **the rule "take a picture of every screen" caught
three real faults that no test did, in one milestone.**

### The desk playtest, against the six questions

Reviewed the filmed first minute and the stills of the Hold, the extraction and
both world classes.

1. **Feedback on every action?** Now yes on all three channels: a sound pitched
   by rock hardness on every bite, a haptic on every impact, and the visual that
   was already there. Camera shake is still absent and belongs in a polish pass.
2. **Speed inside a fifth of a second, and coasting?** Asserted in `test_fly.gd`
   rather than read off a contact sheet, which is the right place for it.
3. **Popping, sweeping, drawn over something?** One real instance, found and
   fixed: the post-processing was drawn OVER the HUD and put chromatic
   aberration on the edges of every button.
4. **Are the short states visible?** The Line warning, the manifest, the Hold and
   the extraction all have their own stills. The crack warning on Rime does not
   yet, because a scripted miner digs narrow and never triggers it.
5. **Is the first minute a win, and is the next goal visible?** The first ore
   comes within seconds. **Banking a haul still needs a visible event** rather
   than a number changing, and that is the clearest single thing to do next.
6. **A frame where the player would not know what to do?** No, but **the middle
   of the descent is still monotonous**: a long thin shaft with nothing to
   decide. Unchanged from the first film and still the honest weakness.

### What is NOT done, and why

**The phone run.** `adb devices` reports nothing attached, so none of the
phone-only paths have been exercised: touch on a real digitiser, the safe area on
a real notch, frame time, thermal after ten minutes, the back button as a system
gesture, home and resume, and haptics actually firing. Every one of those is a
structural assertion in the smoke test and a guess until the device says
otherwise. **This is the one part of phase one that cannot be finished without
the phone plugged in.**

### The second film, with the title crossed like a player

`build/movie/first-minute/sheet.png`, 64 seconds, one tile a second, starting at
the title and tapping NEW GAME the way a thumb would.

What it shows that the stills cannot:

- **The tunnel bends and the light bends with it.** Two direction changes at 10 s
  and 15 s, and the lit shaft follows the zigzag exactly. This is the whole of
  what he asked for in Coreward and it is only legible as a sequence.
- **The lamp pool shrinks as the air thickens.** Not scripted anywhere: it falls
  out of `density_at` feeding the reach, and it reads.
- **The Line announces itself.** "HEAT BELOW" appears in the state line a band
  early, then the manifest opens over it.

The middle stretch, tiles 30 to 55, is very dark: the ship is a small lit point
in a black field. **That is his brief rather than a fault** - "make shadows and
darkness denser. I want it hard to see blocks that are far away and almost black
toward the edge of the screen, so it feels like we are only zoomed in because we
cant see any further out" - and the picture matches it closely.

**So the problem in that stretch is not the darkness, it is that there is nothing
to decide in it.** Recording it precisely matters, because the obvious reaction
to a dark boring stretch is to brighten it, and brightening it would throw away
the thing he liked to fix a thing he did not complain about.

### A third script with the same fault

`movie.ps1` rendered all 3,840 frames and then died before tiling a single one,
because Godot's Movie Maker prints a shutdown warning to stderr and
`$ErrorActionPreference = 'Stop'` turns that into a terminating error. The
expensive half succeeded and the useful half never ran.

That is the third script in this repo with the same bug, after `new-game.ps1` and
`check.ps1`. All three now route native calls through one `Native` helper. Fixed
in the template too.

## 0.9.1: the lamp points where you are going (2026-09-10)

His note, verbatim: *"the light seems to be coming from the back of the ship in a
small beam. I would like you to do something similar to coreward, where forward
light creates a dispersed beam, but also fills the rest of the tunnel behind. as
you pass corners, it should create shadows. the air should start looking thick in
the tunnels. there should he a secondary light source that shows on the face of
the rocks when the ship is near them."*

Five mechanisms named in one sentence, restated from scratch rather than as a
tuning note, so the model was rebuilt rather than adjusted.

### The model now: three named terms per surface, combined with `max()`

Rock (`rock.gdshader`) and air (`haze.gdshader`) share `lamp_dir`, `cone_lo`,
`cone_hi`, `lamp_reach` and `density`, so the beam you see in the tunnel and the
pool it lands in are one lamp. The smoke run asserts that.

| Term | Reach | Direction | What it is for |
|---|---|---|---|
| BEAM | `lamp_reach / (1 + density * 0.35)` | the drill, squared cone | the dispersed forward beam |
| PROX (rock only) | 0.34x | none at all | *his* second light: the face you are beside |
| WASH (rock only) | 1.6x, weak, rides the spill | none | the tunnel behind stays readable |
| FILL (air only) | 1.05x, weak | none | the lit shaft that is the way home |
| SHADOW (air only) | the fan | per bearing | the wedge a corner throws |
| THICK (air only) | — | — | scatter and drifting grit, both scaling with density |

**`max()` of the terms, never a product.** Multiplying two floors lands anything
that is dim for two reasons on the product, which is black, and the thing it
blacks out is the shaft the player came down.

**Each term gets its OWN falloff.** Sharing the beam's pool makes the glow behind
the player stop exactly where the beam does, with the same hard edge, which is
the one thing the soft half must not do.

### Corrections, all measured on a screenshot rather than argued

9. **A lighting complaint is about a RATIO.** The beam was fine. The air *behind*
   the ship measured 150 of 255 against 103 for the rock the beam was pointing
   at, so the brightest thing on screen was behind him. Sampling the PNG at fixed
   points ahead and behind turned "better" into a number that survives a round.
   It now sits at roughly 100 ahead / 25 behind / 50 in the shaft: a 3-4:1
   forward ratio reads as directional while leaving the way home visible. At 6:1
   the tunnel behind went black, at 1.65:1 there was no direction at all.
10. **Isolate a shader term by REPLACING it, not by reading it.** Two frames with
    `flood -> 1.0` and `shadow -> 1.0` said in one pass that a black stretch of
    shaft was the shadow term. A headless probe then said the shadow was correct:
    the column above the ship was open for four cells and then ceiling. The fault
    was in the mental model of the geometry. `debug_term` is now a permanent
    uniform because this file was hand-patched twice in one session for want of
    it.
11. **The fan is cast and decoded with ONE number.** It was cast to `reach * 1.8`
    and decoded in the shader against `reach`, so every shadow began at 55% of
    its true distance. `Tuning.FAN_REACH_MULT`, and the smoke run asserts the
    uniform equals what the cast used. Third instance in this repo of one
    quantity written down twice.
12. **A title screen blinds every screenshot script written before it.** `_tick`
    returns while the shell is not playing, on purpose, so `freeze()` +
    `advance()` advanced nothing and captured the menu — exit 0, no error, a
    photograph of the title filed as evidence about tunnel lighting.
    `main.start_run()` -> `shell.begin_new()` is now the one way in, and it is
    the method the NEW GAME button calls.
13. **Straight down a shaft is the one scene where none of this can be judged**,
    because the only open air is behind the ship and no corner is in frame.
    `scripts/shot_light.gd` cuts a real junction and flies past it, and stage 4
    climbs clear and turns back down so there is open shaft in both directions at
    once. `build/junction.png`, `build/beam.png`, `build/deep.png`.

## 0.9.2: headlights in thick air (2026-09-10)

His note on 0.9.1, verbatim: *"Instead of thick air, this looks more similar to a
beam coming from the ship. Can you make it so that the there is a soft dispersed
light throughout the whole tunnel and the beam coming from the ship looks like
it's headlights cutting through the thick air? In front of the ship should be
brighter than behind and branching paths should cast shadows as you pass them."*

The forward/behind ratio and the corner shadows he restated unchanged, so those
were right. What was wrong was named twice in one sentence: light present in the
WHOLE tunnel, and a beam that reads as scattering.

### 14. A lamp-centred radius always reads as light belonging to the ship

0.9.1 already had a weak, long, direction-free term for the tunnel behind. It
still read as a pool that follows you, because its falloff was a radius measured
from the lamp. **A disc centred on the light source is a disc however gently it
falls and however far it reaches.**

The flood is the right quantity and it was already solved: `exp(-att * (path -
octile))` is exactly 1 down an open passage however long, and falls only where
the route bends. The AMBIENT term is that value raw, with no distance term of
its own, so the tunnel lights to the edge of the solved window and a side branch
is dim because it bends away rather than because it is far off. Same move on the
rock: `wash_reach_mult` is 4.0, longer than the solved window, so across a frame
it is flat and the only falloff is the spill's own.

### 15. A beam in a one-cell shaft has no shape unless it has a profile ACROSS itself

An angular cone is constant across something that narrow, so the beam came out a
flat slab with a razor edge at each wall: an object in the tunnel. A Gaussian on
the perpendicular distance from the axis, whose width grows with how far down the
beam a pixel is, is what "dispersed" actually means.

| Change | Why, measured |
|---|---|
| off-axis Gaussian, `w = 0.35 + 0.30 * along` | the cone cannot give a narrow shaft a core |
| beam scales with `density` | in clear air you see only what the lamp lands on: a visible shaft is entirely a fog effect |
| falloff CUBED, not squared | squared, the beam was still 148 of 255 where it left the frame, so it had an end |
| shadow edge `0.25 + dist * 0.12` | a fixed 0.30 m band is drawn crisper than the fan's own angular resolution and aliases |
| ambient + beam, not `max()` | fog scatters both at the same point and you see the sum; `max()` leaves a seam along the cone edge |

`max()` is still the rule on the rock, where the three terms are the same light
counted three ways.

### 16. Lighting the tunnel published a texture bug that had shipped for nine versions

The normal map is projected in world XY, which is exactly parallel to every wall
of a Z-extruded mesh, so a wall's whole 3 m of depth collapsed onto one line of
texels and came out as vertical streaks. Invisible while those faces were black.

**Selecting the projection by `abs(normal.z)` does not work.** `generate_normals()`
smooths across the crease where the front face meets the wall, so a tunnel ceiling
measures 0.87 there and every wall in the game takes the face projection anyway.
Measured by rendering `abs(n.z)` straight to ALBEDO. The selector is the geometry
instead: the front face is a plane at `Terrain.HALF`, passed in as `face_z` and
asserted in the smoke run.

Expect this generally: **any change that lifts the black floor also publishes
every defect the darkness was covering.**

### 17. The gate had been blind to every Godot error since the template was written

`check.ps1` ran `& $godot @a *> $log` and counted `'^(SCRIPT )?ERROR'`. PowerShell
sends a native command's stderr through its error channel, so every line arrives
as an ErrorRecord rendered `Godot...exe : SCRIPT ERROR: ...` in UTF-16. The anchor
could never match. `errs` was structurally always 0.

It surfaced because a `int(null)` on an unset shader uniform threw inside the
smoke check, skipped every assertion after the throw, and the gate printed
`smoke ok ... errors 0`. Two regression tests written minutes earlier were among
the skipped. The assertion count is the tell: 140 before, 142 after.

Fixed by unwrapping the ErrorRecords with `ToString()` and writing the log UTF-8,
in this repo and in `C:\dev\godot-template`. Filed to `inbox/`.

### Still open, not changed

At 90 m the frame carries large soft brown washes over big regions of rock. Probed
them rather than guessing: they are ORE GLOW, which is exempt from the light model
on purpose so a rich seam reads through the dark, and the deep bands are dense with
high-glow material (`COLOR.a` measured 0.67 in one of them). It is doing what it
was written to do; whether seams should read tighter than that is his call, not a
lighting fix to make under a lighting request.

## 0.10.0: the drill is a plow (2026-09-11)

His first phone session on 0.9.2, verbatim in `playtests/gravewell.md`. Five asks;
the research brief behind them covered continuous digging and two rendering
artefacts. **The ordering mattered more than any of the individual fixes: M11 is
also the fix for M12 and half of M13.**

### 18. Anything that gates motion on finishing a unit of work reads as chunky

"digging feels very rigid and chunky ... it takes large chunks out, slows me
down, then speeds up." The old drill aimed at ONE cell, spent
`fill * hardness / rate` seconds taking it to zero, and refused to let the hull
move until it was gone. **He feels the cadence, not the interpolation**: every
individual step was already smooth and it did not help.

Of the reference games only Motherload does what he described - the pod drills
the instant it moves into terrain and its speed is a number that falls with
depth. SteamWorld Dig, Dome Keeper and Terraria are all discrete per-tile
underneath, hidden behind a fast fixed swing cadence, which is the thing being
complained about.

### 19. Derive the speed from the bill, so the picture and the cost cannot disagree

Advancing one metre removes one cell of fill, which costs `hardness` hit points,
so `plow speed = drill power / (hardness * HP_PER_METRE)`. That single identity
carries three things at once: the deep is slower, the power bill per metre is
unchanged, and **the drill can never advance faster than it clears**.

| | old | new |
|---|---|---|
| dig rate, mean of six planets | 1.26 m/s | 1.55 m/s (M) |
| 200 m of pure digging | 159 s | 129 s |
| power split (drill / thrust / lamp) | 34 / 29 / 19 | 36 / 33 / 22 |
| surface to deepest speed ratio | n/a | 4.6:1 |

Research puts the readable band at 4:1 to 6:1. `BAND_HP` already spanned 4.6:1,
so the table needed no change at all.

### 20. A floor under the plow speed is a licence to pass through unbroken rock

`PLOW_MIN` was a `max()` inside `plow_speed` for one round, on the research's
advice that a drill reaching zero reads as a dead input. It broke the identity
above, and a scripted miner **drove straight through a planet's core without
cutting it**, ending forty metres below with the core sitting at fill 0.39.

The floor is now a property the band table KEEPS (`PLOW_MIN_ROCK`, asserted)
rather than a clamp that is applied. The core multiplies hardness by six and is
deliberately far under it: 0.11 m/s, nine seconds for one cell, which is the tell
that the extraction is about to start.

### 21. Sample the hardness at the hull's leading face, not at the drill head

The first version read the cell a metre ahead. The reading fell back to ordinary
rock the moment the ship was ALONGSIDE the hard thing rather than approaching it,
and the conservation broke. At the leading face, time-in-cell times power equals
exactly the cell's cost, by construction.

### 22. Plowing means the hull is inside rock, and that needs depenetration

The ship ends its tick inside material it is still cutting: that is the mechanic.
But the ordinary resolve has nothing to push against when the START position is
illegal, so it refused every direction and the ship was wedged in its own shaft
the moment the player let go.

Two bounds, and the first version had neither:

- **Only while the drill is off.** Letting velocity through as well let a miner
  cover 37 m in ten seconds and leave the whole shaft standing behind it.
- **Strictly out, on a CONTINUOUS measure.** An overlap count is flat across most
  of a cell, so "no deeper" read as "sideways is free"; an overlap AREA is flat
  too, because the hull is 0.76 m and a cell is 1.0 m, so a hull inside one cell
  covers the same area wherever it sits. Measured: it escaped 0.2 m and then sat
  with its velocity zeroed. The measure is now the fill sampled bilinearly at the
  hull's corners and centre, on the same lattice the contour uses.

### 23. The starburst and the jagged edges were one artefact seen twice

"multiple separate beams ... rather than a glow" and "the light also appears to
get caught on the edges of tunnels that I have made because they have random
edges that stick out". The feathered brush removed the protrusions, and the
bearing filter removed the rest.

**Filter the OUTCOME across bearings, never the stored distance.** Two adjacent
rays that hit different occluders store wildly different distances; blending
those lands at a distance neither measured, and the boundary draws as a hard
wedge. 0.9.2 made it worse by giving the ambient a shadow, which put the wedges
in every direction at once instead of only inside the beam.

Measured on a field of single-cell pillars at nine metres (M):

| taps | worst neighbouring jump | hard edges | first wall lit |
|---|---|---|---|
| 1 (none) | 1.000 | 22 | 0.98 mean, **0.00 darkest** |
| 5 (PCF5) | 0.200 | 0 | 0.75 mean, 0.40 darkest |

Raising the ray count is explicitly not the fix - the reference writeup reports
360 rays still looking jittery - and it is the most expensive option on Adreno.

Two things fell out of measuring it. **The first attempt measured nothing**,
because it was pointed at a carved shaft and the feathered brush had already made
that smooth: there was no artefact left to test the filter against, and the frame
proved nothing either way. And the old `first wall is lit` test had been passing
with parts of the wall at **0.00** - fully black - because a threshold count let
4.9% through; it now asserts the darkest sample, which is the claim it was always
making.

### 24. One number for the work, four channels reading it

`Sim.dig_load`, 0 to 1, zero when not drilling. The drill loop's volume, pitch
and grit rate, the haptic pulse length and cadence, and the camera tremor all
come off it, so they cannot disagree about whether this is fluffy dirt or real
effort. The drill is a generated seamless loop rather than the Kenney impact
one-shots, because the pitch has to answer the game and a recorded drill has its
own pitch baked in.

The per-cell haptic is gone for plain rock: under the plow a cell breaks about
once a second, and a kick on each one competes with the rumble that is now
carrying the information.

### 25. The plow buried the ship behind the rock it was cutting

The terrain's front face is at `Terrain.HALF` and the ship was at z = 0, so a
hull inside partly-cut material was drawn BEHIND it and simply disappeared. The
ship now rides just in front of the face. Found on the first frame after the plow
landed, not by reasoning about it.

### 26. And the first pause button sat exactly on the credits line

The top row already carries three readouts. The smoke run now asserts the button
does not intersect the d-pad, the bank, the depth, the hold or either gauge, at
the phone's aspect - because a control that overlaps another is invisible to any
test that only presses it.
