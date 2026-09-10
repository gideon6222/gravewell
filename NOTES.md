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
