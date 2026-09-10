# Gravewell - plan

Written 2026-09-09 by `/new-game` and `/game-plan`. The expanded idea is in `IDEA.md`, the
observed record of Coreward and the genre is in `REFERENCE.md`. This file is the plan a build
session follows without asking. The first unticked box in Milestones is where work resumes.

---

## Summary (shown to Gideon at the gate)

**Fantasy:** you are a salvager working a graveyard of dead worlds, cutting down through rock
and pressure toward a planet's core to pull out the last thing still burning inside it.

**Loop:** cut down through rock you light yourself, choosing what to carry against what weight
and depth cost you, uplink the haul or gamble on carrying it, reach the core, cut it free, and
run for the surface up your own tunnel while the world comes apart behind you.

**Engine:** Godot 4.7.2, native Android, Forward Mobile. The lighting he named as the thing he
likes is the heaviest system in the game and needs a real light-field texture, real emissive
and headroom the browser does not have. The phone measured 5 ms a frame on a placeholder
scene, so the ceiling is nowhere near. Coreward stays live and is not ported.

**Reference:** Coreward (ours, `REFERENCE.md`) for what he liked and did not, and **Holedown**
for structure. Holedown is the only well-reviewed mobile game in this genre that already does
one-way-per-planet with a between-planets-only shop, and it was well received for exactly the
thing this plan is betting on.

**The first minute:**

| Time | What happens |
|---|---|
| 0 s | Tap the icon. Title over a live scene, CONTINUE greyed on a fresh save. First run plays a 25 s flythrough, skippable, that states the objective and withholds the explanation |
| 8 s | You are already in the shaft, 20 m down, lamp on, rock all round, one glowing seam within reach |
| 20 s | You hold down. The drill bites, the rock cracks in stages, chips fly, the pad rumbles under the thumb |
| 40 s | **First win.** The seam breaks, ore floats free, the LOAD readout jumps and the value reads out beside it |
| 70 s | The ship is visibly heavier: slower to start, longer to stop, more power a metre |
| 90 s | **First uplink.** A capsule fires up the shaft you cut. Credits land. One rung of the ladder is now affordable and the shop says so |
| 2 min | The first threshold is announced from below before it charges you for anything |

Zero reading needed for any of it.

**What you keep:** the **cores**, physically. Each world's core sits in the drive frame in your
ship's hold, lit, taking up a slot you can see. Plus the log fragments on the wall beside them,
and one keepsake per world. Nothing that is a number that looks small next week.

**New technique:** **interpolated marching squares** for the rock surface. The grid stays a
grid for collision, lighting and tests, and the thing you see is a smooth interpolated contour
extruded into a wall, so the world reads as eroded rock rather than as stacked cubes. It needs
a continuous per-corner fill value instead of a boolean, **which is the same number that stores
partial dig damage**, so the technique he asked for in "blocks should remember how much damage
is already done" and the technique that removes the blockiness are one piece of data. Sources:
Wikipedia's marching squares page for the sixteen cases and the interpolation, Sebastian
Lague's two-part build for the worked version, and `richardhyy/Godot-4-Destructable-Terrain`
for a Godot 4 implementation that already chunks and decomposes collision.

**His asks, expanded:**

| # | His ask | What it grew into |
|---|---|---|
| 1 | Digging and space | Kept as the spine, and the tunnel becomes the level: it is the way out, the thing light travels down, the thing heat and water and everything else travels down, and the thing that is still there next descent |
| 2 | The lighting, air denser with depth, shadows past tunnels you made | The biggest single engineering budget. Coreward's flood-fill light field ported to Godot, plus **air density as one simulated number** driving fog, lamp reach, bloom, muffling, reverb, drag and hull load together |
| 3 | Multiple planets that feel completely different | Seven **world classes**, each of which changes a RULE of digging or flying, with the art following from the rule. Not twelve tints |
| 4 | Upgrades and secrets hidden in each area | Upgrades on two axes, priced against the depth of the threat they counter, physically bolted to the ship. Secrets in three tiers: seams you read off the wall, caches found by a diegetic cue, and **vaults sealed behind a drill tier you do not have yet** |
| 5 | Planets that feel alive | The world reacts to being cut (water finds the low point, gas fills a dead end, an undermined ceiling comes down), things move through the tunnels, and every class emits something of its own in the air |
| 6 | An overarching goal separate from digging | The **Gravewell Drive**: seven slots, one core from each world class, assembled physically in your hold. It advances once per planet, so it advances every time he plays, which is the fix for the Coreward version he never reached |
| 7 | Balanced, gradual, exciting | **Two currencies**, so survival costs exploration and not time: credits are mined, filament is only found, and every counter to a threat costs filament. Grinding the shallow band forever buys a bigger hold and never once buys safety, which is exactly the failure he reported. Backed by a probe that reports the minute and depth each upgrade is reached at, over six seeds, with a do-nothing bot that must lose. Gradual by one new pressure a class, announced before it charges. **Exciting by the extraction**: reaching the core is halfway |
| 8 | Realistic, gritty, eerie, glowing, neon | Real PBR rock under a moving lamp, a dark desaturated palette so the few glowing things are the brightest objects on screen, glow only from things that would glow, and dread built from sound, silence and empty space rather than from monsters |
| 9 | Research what makes similar games fun | Done, in `REFERENCE.md`. The finding that changed the design: **the return trip is this genre's most-hated element**, so Gravewell has no mid-descent return trip at all |

**My additions:**

1. **The tunnel is a liability as well as an asset.** Everything you cut is a path in both
   directions. A straight shaft is the fastest route down and the most exposed one, and a
   collapse charge closes a branch at the cost of closing your own way back.
2. **Power low means the lamp dims.** The pressure gauge is rendered as the thing he already
   likes looking at. Running low on power does not print a warning, it closes the world in
   around you. One state, one truth, and no invented symbol for something we can show.
3. **Extraction, not just descent.** Cutting the core free starts the world dying and the only
   way out is the tunnel you dug, with the core aboard making you heavy and lit up. It reuses
   the level that was just built and it turns Coreward's weakest beat, a modal dialog saying
   the planet exploded, into the best thing in the game.

**Assets:** rock, props, skies, UI, icons, fonts and sound are all CC0 or permissively licensed
and all fetchable unattended. ambientCG for eight rock and metal sets (normal and roughness
only, so the palette keeps deciding colour), twenty-three Poly Haven industrial props for the
pad, the Hold and the ship's bolt-on parts, six Poly Haven HDRI skies, Kenney for particles, the
UI kit and impacts, Lucide icons, Chakra Petch and Share Tech Mono, Freesound CC0 for drill,
rock, hull and drone, four MIT Godot addons. Full table with ids, licences and fetch commands
under Assets. **The one real miss is the drill ship**: no photoreal CC0 ship exists anywhere, so
the hull is modelled by hand as a real asset and the upgrade parts bolt on from the Poly Haven
industrial set.

**Phases:** 1 first playable, ten milestones, one world class complete end to end plus a second
to prove classes differ. 2 content and meta, the other five classes, the vaults, the drive and
the ending. 3 polish and store.

---

## The loop, and the one thing the research changed

Motherload and SteamWorld Dig put their content at the bottom of one shaft and make you climb
back up it, and that climb is the single most-cited complaint in their reviews. Coreward
inherited the shape. Holedown removed the return trip entirely and was praised for it.

**So Gravewell has no mid-descent return trip.** Three consequences, and each solves something:

1. **You uplink instead of hauling.** A capsule fires from wherever you are and takes the hold
   with it. It costs power, scaled by depth and weight, so a deep uplink is expensive and the
   decision "bank it now or carry it further" is live for the whole descent. Selling is an
   action you take in place, not a journey.
2. **The tunnels persist across descents on the same planet.** Running out of power is not
   losing the planet, it is losing what is in the hold. You are recovered, you refit, and you
   dive your own open shaft to get back to where you were in a fraction of the time. The
   repeated part of a planet is fast. The new part is the part that takes time.
3. **The one ascent that exists is the climax, not a haul.** It happens once per planet, with
   the world coming apart, and it is a chase.

A planet is two to four descents of five to ten minutes each, so a planet is one sitting or
two, and the drive gains a slot at the end of it. He has never once played past 60 m of
Coreward, and this is the structural answer to that, not a discipline problem to be nagged at.

---

## Player and controls

Portrait 1080x2340, one thumb, no menu to wade through.

| Verb | Gesture | Constants | What it looks like |
|---|---|---|---|
| **Fly** | 8-way d-pad, bottom centre-left, `PRESET_CENTER_BOTTOM` with a negative offset so it sits a fixed distance from the real bottom edge | Reach top speed in ~0.18 s, coast under one cell, smoothing `1 - exp(-rate * dt)` **assigned not added**, and the lane pull runs only while a direction is held, never while coasting | The hull banks into the direction, thrusters light on the side that is pushing, and the nose points where it is going |
| **Drill** | Automatic while a held direction puts the nose into rock. No separate button | Cut rate from drill tier / rock hardness / air drag. Damage per cell is stored and **kept when you stop** | The drill spins up, the rock cracks in stages, chips spray, the beam lights the face, the pad ticks under the thumb |
| **Uplink** | A button, bottom right, showing the cost in power and the value of the hold | Cost `UPLINK_BASE + depth * UPLINK_PER_M + load_kg * UPLINK_PER_KG` | A capsule rises up the shaft and out of frame, lighting the tunnel as it goes, which is the only time you see your whole route lit |
| **Lamp mode** | A button, bottom right, cycling Flood, Lance, Dark | See the lamp modes under Light | The beam physically changes shape. Dark is a real state you can sit in |
| **Ordnance** | A button, bottom right above the uplink, one shared meter | The meter trickles while underground and refills fully between descents. This is his own design and all three of his options turned out to be right together | Each ordnance has its own physical effect on the rock. Nothing is a screen flash |
| **Consumable** | A button, bottom right, small stacks | Priced above the first upgrade rung so they never dominate | |
| **Manifest** | Tap the LOAD readout | | A sheet: count, weight and value per mineral, so two ores are comparable on screen. This was ask number 3 in Coreward and it is in from the first build |
| **Pause** | Android back button, or a corner button | `quit_on_go_back = false` **and** `NOTIFICATION_WM_GO_BACK_REQUEST` handled in the same commit, or the back button is dead | Version, build stamp, patch notes, audio, haptics, graphics scale, erase progress behind a confirm |

**Decision recorded:** the d-pad stays, rather than moving to Godot 4.7's built-in
`VirtualJoystick`. He complained about where the d-pad was, never about what it was, and free
flight with a lane pull is the state he approved. The joystick is the alternative if the first
playtest asks for finer control.

Every control handles its own input through `_gui_input` with `accept_event()` and
`mouse_filter = STOP`, so the hit box and the drawing are one object. Layout is against the
real viewport, never the base size, with `DisplayServer.get_display_safe_area()` applied on
`_ready` and on `size_changed`.

---

## Systems

### 1. The grid, and what a cell is

**Owns:** `fill: PackedFloat32Array` over grid corners, `mat: PackedByteArray` over cells.
**Lives in:** `src/sim/world.gd`.

A cell is one metre. Generation is a **pure seeded hash** keyed on place, `SimUtil.hash2` on
(x, depth, planet_seed). Nothing in the simulation calls `randf()`.

**Every new generator rolls on its own seed offset.** Coreward's invariant, and the reason is
that consuming an existing roll shifts every ore at every depth on every planet and the diff
looks like three lines. Registered offsets live in one table in `world.gd`: ore `+0`, seams
`+17`, caches `+41`, caverns `+77`, vaults `+113`, growth `+131`, ambience `+149`.

**Corner fill is a float, not a boolean, and it is the whole trick.** `1.0` is solid rock,
`0.0` is open air, and the values in between are a cell part-way cut. That single array is:

- the partial dig damage he asked for, kept when you stop drilling
- the input to marching squares, which is what makes the rock read as eroded rather than
  stacked
- the input to the light flood, which treats anything under `OPEN_THRESHOLD` as passable

**Test:** `test_world.gd` asserts the seed table has no duplicate offsets, that
`blocks-baseline.json` (frozen, never re-recorded) only ever differs by a known overwriter,
and that a cell's id is unchanged by anything decorative.

### 2. Flight and collision

**Owns:** `pos`, `vel`, `heading`, `load_kg`. **Lives in:** `src/sim/fly.gd`. No Node, no
Viewport, no input event, no real frame.

Velocity and a collision box against the cell grid, not a cell timer. Collision stays on the
**grid**, not on the marching-squares contour, because collision decides outcomes and must be
exactly testable headlessly. The contour is biased so it never encroaches more than 0.15 of a
cell into an open cell, and a test asserts that band, so the player never hits rock they cannot
see.

Load changes three things and they are all felt: acceleration (`thrust / (mass + load)`), stop
distance, and power drawn per metre. This is the risk dial he holds himself, and it is the
reason the last ore you pick up is the one that strands you.

**Test:** `test_fly.gd` asserts momentum, acceleration to top speed inside 0.2 s, coast
distance under a cell, that a correction is applied as a velocity through the normal collision
path and never as a position write, and that nothing is corrected while coasting.

### 3. Power, hull and load: three clocks, and only one of them is a bar you watch

**Owns:** `power`, `hull`, `load_kg`. **Lives in:** `src/sim/ship.gd`.

| Clock | Drained by | Restored by | Shown as |
|---|---|---|---|
| **Power** | thrust, drilling, the lamp, and each uplink | between descents only | A slim vertical column up the **left edge**, opposite the thumb, because it is watched continuously. Plus **the lamp itself dimming** below 30% |
| **Hull** | impacts, collapses, and the planet's own pressure past its Line | between descents, and slowly by the Repair Drone underground | A horizontal bar under the power column, and a rate readout `HULL -3.4/s` whenever it is draining, because a number beats a bar when the player needs causation |
| **Load** | picking ore up | uplinking, or dumping | `kg / kg` top right, tap to open the manifest |

**Power low dims the lamp.** Below `LAMP_FADE_START = 0.30` the lamp's reach falls linearly to
`LAMP_MIN_REACH` at zero. The world closes in, the camera's justification for its tight frame
gets tighter, and the player can see they are in trouble without reading anything. This is my
addition 2 and it is the single cheapest piece of design in the plan.

**Running out does not take the run.** Recovery hauls you to the surface, you keep everything
already uplinked and lose what is in the hold, and the tunnels stay open. Tow Insurance reduces
the loss. This is his own Coreward design and it was right.

**Test:** `test_ship.gd` asserts a do-nothing ship loses (a wear clock, so caution has a cost),
that the lamp reach is a monotonic function of power below the threshold, and that recovery is
always reachable from any legal state, so a save can never strand.

### 4. Air density: one number that drives the picture and the rules

**Owns:** `density(depth, class)`. **Lives in:** `src/sim/air.gd`. Pure, one function, no state.

He described a feeling. This makes it a quantity, and then everything reads from the one
quantity so the picture and the rules cannot disagree.

| Reads it | Effect |
|---|---|
| Fog | `Environment.fog_density`, and `fog_sky_affect` around 0.2 because any effect applied by distance hits the background hardest |
| Lamp | Reach multiplied by `exp(-ABSORB * density)`. Denser air, shorter lamp |
| Glow | Emissive bloom widens and softens with density, on a gentler curve than surfaces |
| Audio | An `AudioEffectLowPassFilter` cutoff falling with density, so the deep sounds muffled |
| Flight | A drag term, so a dense world is heavy to fly in |
| Hull | Past the class's Line, `hull -= PRESSURE_RATE * (density - LINE_DENSITY)` |

**Volumetric fog is Forward+ only and is not available on the Mobile renderer**, per the Godot
docs. The asset scout asserted the opposite in passing, so **M2 settles this with a
measurement, not with a citation**: build a `FogVolume` in the real project on Forward Mobile,
screenshot it, and record the answer in `NOTES.md`. Rule 7 is that a caution gets replaced by a
number. Until then the plan assumes it is unavailable, because that is the assumption that
still ships if the claim is true. Density is
delivered by four Mobile-safe layers instead: the built-in `Environment` depth fog, the
additive tunnel-glow quads that put light in the air (Coreward's technique, and the half that
was missed there on the first pass), world-anchored dust motes whose count scales with density,
and a full-screen pass under the HUD. The full-screen pass must **not** read `DEPTH_TEXTURE`,
which is corrupt on Forward Mobile with MSAA and MSAA is not being turned off. It reads the
light field the simulation already uploaded, by world position, which is `GODOT.md`'s standing
answer: when a shader wants to know something about the world, the simulation already owns it.

**Test:** `test_air.gd` asserts density is strictly increasing with depth on every class, that
each class's curve is distinguishable from every other at the same depth by at least a set
margin, and that the Line depth for each class equals the depth at which its rock band changes.
Four things landing on the same metre is the fix for the one real bug in his heat feedback.

### 5. Light: the crown jewel

**Owns:** the light field. **Lives in:** `src/sim/light.gd` for the solvers, `src/game/lightmap.gd`
for the texture and the shader wiring. `techniques/coreward-propagated-lighting.md` is the
write-up and every artefact in it is a thing not to rediscover.

Four pieces, in this order, and none of them is optional:

1. **The flood.** Dijkstra over open cells from the ship, storing
   `exp(-att * (pathLength - octileDistance))`, which is how much longer the light's real path
   was than a clear run. Open space comes out at exactly 1 so only geometry can darken
   anything. Octile, never Euclidean, or open ground gets a permanent haze. Runs on cell change
   and on terrain change, not per frame.
2. **The field as a texture.** A small `ImageTexture` with linear filtering, several texels a
   cell, sampled by world position, so light fades across a rock face instead of stepping at
   cell edges. Brightness and shape in separate channels.
3. **The shadow fan.** A few hundred rays by grid DDA from the lamp, recording per bearing how
   far light gets. Runs every frame, because the whole point is that the shadow moves as you
   do. **Record the far corner of the cell the ray hits, not where the ray leaves it**, or
   thirteen per cent of every wall face is in its own shadow and it reads as the lighting being
   broken. That artefact cost five playtest rounds in Coreward.
4. **Two lights, not one.** `SURFACE = flood * falloff * beam` and
   `AIR = flood * falloff * beam * shadow`, with their own ambient floors and their own
   falloff curves, combined with `max()` and never by multiplying two floors. A shadow belongs
   to the air term only. This is the thing three rounds of his notes were about while three
   rounds of fixes went to the shadow itself.

#### The lamp is a choice, not a meter

The documented mistake is making a light source a single depleting bar, which is a chore.
Darkwood gives several light tools that trade brightness against burn rate so choosing which to
bring is a decision made before you descend. Alien: Isolation makes the light two-sided: it
shows you the room and it shows the room where you are.

So the lamp has **three modes on one button**, and the trade is real:

| Mode | Reach | Power | The other edge |
|---|---|---|---|
| **Flood** | Wide, short | Cheap | You see the walls beside you and nothing ahead |
| **Lance** | Narrow, long | Costly | You see far down one bearing and nothing to the sides |
| **Dark** | Almost nothing | Free, and it recovers a trickle | You are blind, and you are not noticed |

Dark mode is what makes the whole system a decision rather than a resource. It is also the
answer to "what do I do when power is nearly gone", which is a verb rather than a wait.

**And power low forces the lamp down.** Below `LAMP_FADE_START = 0.30` the reach falls linearly
to `LAMP_MIN_REACH` at zero, so being in trouble looks like the world closing in rather than
like a number turning red. This is my addition 2, and Iron Lung is the argument for it: taking
continuous vision away and giving back sound plus glimpses does more than anything shown.

Expanded past Coreward, and this is where his ask goes further than what exists:

- **Your history stays lit.** Shafts you cut on an earlier descent still carry light from the
  surface down them, so looking back up a completed dig shows the route as a faint lit branch
  structure. The map of the planet is the light, and there is no minimap.
- **More lights than yours.** Glowing ore, magma veins, bioluminescence and the dead neon of
  ruined machinery are all sources in the flood, not just emissive decoration. A **flare** is a
  consumable you stick in a wall and leave, which is navigation you place by hand.
- **Each class has its own optics.** One class's air scatters so hard the lamp dies in three
  metres. One is clear as vacuum and the dark past the lamp is absolute. One glows faintly by
  itself so you can always see a little and never see anything sharply.

**Test:** `test_light.gd` asserts open ground solves to exactly 1, that a cell three layers
into rock is under a few per cent, that the fan's lit-face-in-shadow fraction stays under a few
per cent **when sampled the way the shader interpolates** (a nearest-ray lookup cannot see the
artefact at all, which is how it survived), and that the surface and air terms differ in the
one place they are meant to.

### 6. Marching squares: the rock stops looking like blocks

**Lives in:** `src/sim/contour.gd` (pure, grid in, vertex arrays out) and
`src/game/terrain.gd` (the `ArrayMesh` and the chunking).

Sixteen cases over the corner fills, the contour vertex placed by linear interpolation between
the two corner values rather than snapped to the edge midpoint, extruded into a wall. Chunked,
so a dig rebuilds one or two chunks and not the world, on the same event that already re-runs
the light flood.

Three things that go wrong and are cheaper to know now:

- **The ambiguous cases (5 and 10, the checkerboard corners) need a fixed tie-break** or the
  contour flips inconsistently between adjacent digs and the wall shimmers.
- **Concave contour polygons must be decomposed for collision** if collision ever moves off the
  grid. It is not moving off the grid in phase one, which is most of why this is safe to build.
- **Non-axis-aligned faces need correct tangents** or the world-position-sampled normal map
  goes flat on exactly the curves this technique exists to create. Check it under a moving lamp
  before committing, because that is the only way a normal map can be judged.

**Test:** `test_contour.gd` asserts the contour is closed, that it never encroaches more than
0.15 of a cell into a cell the collision model calls open, that the ambiguous cases resolve the
same way every time, and that the triangle count per chunk stays under budget.

### 7. Ore, seams and the manifest

**Owns:** `ORES` table. **Lives in:** `src/sim/ore.gd`.

Cargo is **weight**, never units, because two things the player cannot compare on screen are
not a choice. The manifest shows count, weight and value per mineral.

**Seams are his mechanic and they are in from the first build.** Most rock pays a very small
amount. Textured patches pay much more, and **the texture and the payout come from the same
seeded roll**, so what he sees on the wall and what he gets are true by construction rather
than by two systems agreeing. This was the only unprompted design compliment in six games and
he turned it into a mechanic in the same sentence.

`ORES` is ordered deepest-first with each entry's chance strictly lower than the one below,
which is what makes adding a new deepest ore convert only the band above it instead of
reshuffling the game. There is a test.

**Quality is a multiplier on quantity, never an amount added**, so both axes stay alive at
every scale.

### 8. The world classes, which are rules and not palettes

**Owns:** `CLASSES`. **Lives in:** `src/sim/classes.gd`.

Each class changes something about digging, flying or seeing. The art follows from the rule.

| Class | The rule | The Line (its pressure) | Its light | Phase |
|---|---|---|---|---|
| **Cinder** | The control. Clean layered rock, honest ore, nothing strange. Everything else reads against it | Heat, from below | Embers rising, magma glow deep | 1 |
| **Rime** | Ice is brittle: cuts in half the time, but an unsupported ceiling comes down. Fast and dangerous | Cold, hull stiffens and cracks | The lamp refracts, ice carries light much further than rock | 1 |
| **Drown** | Water fills tunnels from the lowest point up. A shaft you cut becomes a well. Buoyancy changes flight | Depth pressure, and drowning | Bioluminescence, and light shafts through water | 2 |
| **Crush** | High density: thrust is weak, everything is heavy, hull load rises continuously rather than past a line | Continuous crush from the surface down | Almost nothing. This is the dark one | 2 |
| **Hollow** | Enormous caverns. You fly more than you dig, falls hurt, and the dark has scale | Cold, and the drop | Light carries far and shows how big the room is | 2 |
| **Verge** | It was inhabited. Dead machinery, sealed structure, powered doors, things that still have current | Radiation, and power surges that drain you | Neon, sodium, screens still running | 2 |
| **Quick** | The rock is tissue. Cuts heal, so a tunnel closes behind you. It reacts to light | Toxins | Bioluminescent pulses that answer your lamp | 2 |

**Test:** `test_classes.gd` asserts every class's rule actually fires in a scripted descent (a
condition that can never be true fails as absence), that every class is distinguishable from
every other on at least three of rock, air, light, hazard and ore, and that each class's
counter-mineral lives below its own Line.

### 9. The Line: one mechanism, seven costumes

Every class has one depth where **four things land on the same metre**: the rock band changes,
the air changes colour and density, the hull starts draining, and a sound arrives from below.
A test asserts the constants stay equal, because in Coreward they drifted apart silently and
his note was that he could feel the line existed and could not find it.

Each Line is announced before it charges: you hear it and see it a band early. A threshold the
player cannot see is not a mechanic.

The counter to each Line is gated behind a **material found inside the threat**, not behind a
price. Two gates on one thing means one of them is decoration.

### 10. Secrets, in three tiers

| Tier | How you find it | What it gives |
|---|---|---|
| **Seams** | Read the wall. The texture is the tell | Much more ore. Constant, low-stakes reward for looking |
| **Caches** | A diegetic cue: a draught of particles from a hairline crack, a vein that visibly runs somewhere, a wall the drill sounds different against | Goods, or a temporary effect aimed at whatever bottleneck you are actually in |
| **Vaults** | Sealed behind rock a drill tier you do not have yet cannot cut. Visible from the first hour, opened at hour six | A permanent upgrade, a log fragment, or the planet's keepsake |

The **Survey** instrument never prints a marker. It gives a bearing and a distance to the
nearest anomaly and gets more excited as you close, so it narrows the search rather than ending
it. An instrument that hands you a coordinate has removed the thing it was bought for.

Vaults are what make a hard tool gate worth having. The genre research is unambiguous that
hard tier gates are what make a place seen early worth returning to later, and that a ladder of
pure soft speedups makes repeat runs predictable.

### 11. Upgrades and the economy

Two axes, per `CRAFT.md`, and the pricing rule is the one Coreward got wrong.

**Permanent rungs**, bought in The Hold between planets. Each is physical: it bolts onto the
ship on the rack and it is visibly different in play. Groups: drill, thrust, hull, power, lamp,
instruments, ordnance, hold.

**Consumables**, small stacks, priced above the first upgrade rung so they never dominate.
Flare, patch, overcharge, collapse charge, bulwark.

#### Two currencies, which is the structural fix for his complaint

His exact words were "I can afford upgrades pretty early on for fuel and cooling so neither is
a risk". The documented cause of that failure mode in this genre is **a currency that is
fungible across every threat**: if mining buys both cargo and survival, and mining is the
fastest grind, the player buys immunity to every threat before any threat bites. SteamWorld Dig
2 solves it by splitting gold (mined, spent freely) from cogs (found by exploring, and required
regardless of how much gold you have).

Gravewell takes that split, and it is what connects the secrets to the balance:

| Resource | Where it comes from | What it buys | Job |
|---|---|---|---|
| **Credits** | Selling ore through the uplink | Drill, thrust, hold, power, lamp, consumables | The routine ladder. Grindable on purpose |
| **Filament** | **Found, never mined.** Caches, vaults and Verge structures only | **Every counter to a Line**, and nothing else | Makes survival cost exploration rather than time |
| **Cores** | One per planet, from the extraction | The drive. Seven slots | The goal. Not spendable |

Three resources, which is `CRAFT.md`'s ceiling for comprehension and its floor for a real
decision, and each has a job the other two cannot do. **A heat shield cannot be bought with
mined ore at any price.** Grinding the shallow band forever therefore buys a bigger hold and a
faster drill and never once buys safety, which is precisely the failure he reported.

Filament comes mostly from **caches**, which are common and part of the loop, so the game stays
completable by a player who never opens a vault. That is Animal Well's rule and it is the one
that keeps a secret layer optional: layer one is finishable with zero secrets found.

#### The curve, with numbers to calibrate against

Motherload's ladder is the published baseline and its multiplier *rises* with depth:
$750, $2,000, $5,000, $20,000, $100,000, $500,000, which is 2.67x, 2.5x, 4x, 5x, 5x. Late rungs
demand more trips than early ones, not fewer. Rogue Legacy adds the other half: **each purchase
raises the cost of the next**, so the currency inflates per purchase and not only per tier.
Gravewell uses both, and the second is the lever to reach for if a playtest shows grinding
trivialising a threat.

**Target: two to four successful descents at the current band to afford the next rung, rising
to four to six for the last rungs of a class.** Below two the upgrade is a formality. Above six
it reads as a grind wall, which is Deep Rock Galactic's documented failure in the other
direction, where a counter arriving too late made players stop engaging with the system at all.

**Hard gates versus soft speedups.** One hard gate per class (a depth you cannot pass without
that class's Line counter) plus one or two mid-planet, which lands the game at roughly eight
hard gates. Everything else, hold size, lamp reach, drill speed, is a soft speedup. A ladder of
pure soft speedups makes repeat runs predictable, which is the documented critique of Dome
Keeper's otherwise excellent design.

**Every tool that opens a sealed place must also give a new verb.** Metroid Dread's weakest
abilities are the ones that only unlock a door, and that is the standard critique of the
pattern. So the Thermal Bore both cuts heat-sealed vaults **and** lets you read warm rock
anywhere, which means backtracking is never a fetch and return.

#### Enforcement, which is a measurement and not a judgement

`test/run_probe.gd` simulates play, banking and buying across **six seeds** and prints the
minute and the depth at which each upgrade first becomes affordable, plus the descent count per
rung. `test_economy.gd` then asserts:

- every Line counter first becomes affordable inside a window around the depth of the threat it
  counters, and never before that threat's band
- descents per rung sits in 2 to 4 early and 4 to 6 late
- no single upgrade dominates: removing any one from the tree changes total score by less than
  a set fraction
- the game is completable buying only from credits and cache filament, with zero vaults opened

Dividing a late price by early income measures a player who never got better, so the probe
plays rather than dividing.

**Three policies in `test/policies.gd`**, each failing for a different reason:

- `do_nothing` must lose. If caution scores well the game has no stakes.
- `greedy` earns more than `cautious` and dies far more often. The claim under test is "the
  reckless option never actually works", not "the safe option scores higher".
- `human` has a reaction time of about 0.3 s, misreads a tell about one time in six, and has a
  hand that wobbles. Tune the game so the human bot struggles, never the bot so the game looks
  hard.

### 12. The core, and the extraction

The core chamber is the bottom of the planet. Cutting the core free takes a sustained cut with
a visible tell, and the moment it comes loose the world starts to die in that class's own way:
water rises, magma rises, ceilings come down, the machinery wakes, the tissue contracts.

Then you climb. The core is heavy and it is lit, so you are slower and you are visible. The
route is the tunnel you dug, which is why the tunnel was worth thinking about for the whole
descent. A straight shaft is the fast way out and the one the collapse follows first.

**Never let a hazard take the run.** The ascent timer is derived from the actual route length
of the shortest open path from the core to the surface, with a margin, re-derived after every
collapse, and if the route is ever unreachable the collapse is reverted. There is a test on the
bound. Failing the ascent costs the core and the haul and the planet, and never the save.

### 13. The Hold: one room, the whole game

`techniques/coreward-shop-room-and-hud.md` is the write-up. The lesson in one line: if the
player is meant to feel they are somewhere, the somewhere has to be geometry. A panel over the
game is a pop-up however it is styled, and a list is a list however it is styled.

**One room, not two shops.** The interior of your own ship, the same geometry the whole game,
seen between planets. In it:

| Fixture | What it is |
|---|---|
| **The rack** | The upgrade parts on plinths, with the real ship in the middle of the room so the part and the ship cannot disagree. Everything unlocked plus **exactly one teaser**, the shallowest thing still out of reach |
| **The drive frame** | Seven slots. The cores you have are in it, lit. This is the goal and it is furniture you walk past |
| **The chart table** | Two or three worlds offered, never one, and never a good option beside a bad one. Trait, depth to core, transit cost, and whether it holds a core class you still need |
| **The log wall** | The fragments, assembling |

The room is laid out **from the count**, not from a fixed table, because the count grows.
Labels are sized by the pixels they occupy: at a 46 degree vertical field on a 0.46 aspect the
horizontal cone is about 22 degrees, so a 0.66-unit plate is about 70 px, which is a
six-character word. DRILL, not "Drill Bit Upgrade". Words are measured and shrunk to fit rather
than truncated, because "SALVAGE MAGNET" not fitting was a real bug in Coreward.

Scrolling is translated by hand in `_gui_input` (`scroll.scroll_vertical -= int(event.relative.y)`,
then `accept_event()`), because a `ScrollContainer` does not scroll from a finger: measured at
wheel 50, pan 400, `InputEventScreenDrag` **zero**. Rows inside get `MOUSE_FILTER_IGNORE`. The
primary button is pinned to the bottom. "it won't scroll down so I can't see all of the upgrades
or close out of the menu" is a blocker that has shipped once and will not ship again.

### 14. The Gravewell Drive, and the story

Seven slots, one core per class. With all seven the chart opens a route to the place that
cannot otherwise be reached, and its core ends the game. Afterwards the chart keeps generating
worlds, so the endless game is still there with a finished thing behind it.

It is **missable and recoverable but costly**: fail an extraction and that planet is spent, and
another world of that class comes round on the chart. A permanently unwinnable save is the one
outcome this must not have, and there is a test that the chart always keeps offering every class
still needed.

The story is not told, it is assembled. Log fragments from vaults and from Verge structures
answer what killed these worlds. The objective is stated in the first two minutes because every
top game in the genre does; the explanation is withheld, because mystery is withholding the
explanation and never the goal.

---

## Content ladder

Depth bands per planet, monotonic, and every row reachable and proven by a test.

| Band | Depth | Rock | What is new |
|---|---|---|---|
| 1 | 0 - 40 m | Regolith, soft | Seams. The teaching band. Nothing punishes yet |
| 2 | 40 - 80 m | Bedrock | First real ore. Caches begin. Rubble from a bad cut |
| 3 | 80 - 130 m | **The Line** | The class's pressure begins. Rock band, air, hull drain and a sound all land on this metre |
| 4 | 130 - 175 m | Deep | Vaults. The counter-mineral for this class's Line lives here |
| 5 | 175 - 200 m | Core shell | Hardest rock, richest ore, the core chamber |

The core at about 200 m: at the plan's cut rates that is a five to ten minute descent on a
fitted ship and two to four descents to take a planet, which is the sitting length the whole
structure is built around. **The probe measures this before it is believed.**

Planet order is the chart's, not a fixed list, but the first planet is always Cinder and the
second is always Rime, because the second planet is where the player learns that classes differ
by rule and Rime makes that unmistakable in ten seconds.

---

## Presentation

**Camera.** 2.5D: a cell grid with real depth, camera looking down `-Z`, perspective at a 46
degree vertical field. At a 0.4615 aspect that is a 22 degree horizontal cone, so visible width
is about `0.39 * distance` and visible height about `0.85 * distance`. At 18 units back the
frame holds about 7 cells across and 15 down. **Framing is an upgrade**: the lamp ladder pulls
the camera from 18 to about 28 units, giving 11 across and 24 down, and the darkness is what
justifies the tight frame at the start. That is exactly his suggestion and it was the right
shape, because the Scanner in Coreward only changed a lamp radius while the camera framed a
fixed number of rows, so the frame was always inside the lit circle and no amount of tuning
could have helped.

**Light.** Covered above. The ship has **its own key light** on its own layer, excluded from
the world's light through `light_cull_mask` and `layers`, because the world's light is an
upgrade and the ship must not get brighter when the player buys a lamp. One flag in Godot, not
a second pass.

**Palette.** Dark and desaturated everywhere, so the brightest object on screen is always the
most valuable thing in it. Glow only from things that would glow. Every hazard in one colour
family; variety goes in silhouette and behaviour. Separate the play space from the background
by **lightness**, not hue.

**Materials.** Real PBR rock: normal and roughness maps sampled by world position, expecting a
much higher normal strength than usual and judged under a moving lamp. Data textures must not
be sRGB-decoded. Per class the palette moves roughness, relief and **growth**: moss, frost,
plants, oil, ash drifts, salt crusts, rust, scattered on a fraction of rock faces on their own
seed offset and in their own depth bands, as one instanced mesh for all of it so it is a single
extra draw call. A growth that ignores depth is wallpaper.

"Cartoony" from him means under-lit and under-textured, never the model style, so a normal map
on the largest surface, a real light with falloff and a considered sky do more here than any
model swap.

**Post, under the HUD.** A vignette in three stops, animated mid-tone grain, a touch of
aberration, blacks lifted toward the scene colour. `scaling_3d/scale` around 0.8 for the 3D
while the UI stays crisp. MSAA 2x at most and **not off**, which is why nothing reads
`DEPTH_TEXTURE`.

**HUD placement.** Depth in metres large at top centre, because depth is the record and the
thing he talks about. POWER as a slim column up the left edge and HULL under it, both opposite
the thumb because they are watched continuously. LOAD top right, tappable for the manifest.
D-pad bottom centre-left, ordnance and uplink bottom right, all at least 48 dp and clear of the
gesture bar. A rate readout appears beside any gauge that is draining. A gauge checked under
pressure must not move for unrelated reasons. Nothing is positioned against a literal screen
size.

**Shell.** Title over a live scene with CONTINUE, NEW GAME (confirms), SETTINGS and NOTES, and
CONTINUE greyed rather than hidden on a fresh save because a greyed button says "this is where
your game will be". Settings and Notes **reuse the pause sheet** rather than duplicating it.
The title screen is also where the audio gesture happens, so the first tap of the game is not
silent.

**Audio.** Buses `Master / Music / SFX / UI`.

- **Reverb driven by the flood fill.** The light solver already knows how open the space around
  the ship is, so the same number sets `AudioEffectReverb` room size and wet. A tight shaft is
  dry and close, a cavern is enormous. One state, two uses, no second source of truth.
- **A lowpass driven by air density**, so the deep is muffled.
- **A written theme**, minor, slow, with a real progression, a cadence and a pulse, layered by
  depth as a crossfade on a gameplay quantity and never as a playlist. The layer that leaves
  does more than any that arrives. His one recorded outright dislike is random high beeps, so
  no note in this score is chosen at random and nothing has a fast attack on a high sine.
- **Silence is used deliberately** at the Line and in the core chamber.
- Generated at build time into WAV and committed, never synthesised per frame in GDScript,
  which costs seconds of black screen on a phone. Sampled where a sample is better: impacts,
  clicks, rock.

---

## Assets

Everything below was verified live by the asset scout on 2026-09-09 and every one is fetchable
unattended. `FREESOUND_KEY`, `ITCH_KEY` and `POLYPIZZA_KEY` are all present in `C:\dev\.env`
and working. Every `get` appends to `assets/CREDITS.md`, which feeds the credits screen.

### Rock, which is the most important import in the game

The whole screen is rock at close range under a moving lamp. **Take NormalGL and Roughness
only, never the colour map**: the per-class palette decides colour, and that rule is what lets
a photographed texture into a stylised game at all.

| Class | Source | Id | Licence | Note |
|---|---|---|---|---|
| Base rock, Hollow | ambientCG | `Rock035` | CC0 | Tagged black/cave/cliff. Tight facets under a spot lamp |
| Crush | ambientCG | `Rock058` | CC0 | Compressed strata |
| Drown | ambientCG | `Ground037` | CC0 | Damp eroded floor. Wetness is roughness ~0.3 plus a sheen, not a texture |
| Rime | ambientCG | `Ice001` | CC0 | A real ice matrix, not a snow blanket |
| Cinder | ambientCG | `Rock029` + `Lava004` | CC0 | `Lava004` is **the one place a colour and emission map earns its place**, as the crack pattern driving the vein emissive |
| Verge | ambientCG | `Concrete044D`, `Metal041B`, `MetalPlates013` | CC0 | Metal keeps metallic 1.0 and roughness from the map |
| Quick | ambientCG | `Moss002` + `Rock064` | CC0 | Moss for the organic normal, rock underneath so it stays geological |
| Decal masks | ambientCG | `MetalPlates013`, `Fence007A`, `WoodSiding008` | CC0 | NormalGL only, as greyscale grunge patterns. The grate doubles as gantry decking |

```powershell
python C:\dev\gamedev-notes\scripts\assets.py get ambientcg Rock035 --res 1K --maps NormalGL,Roughness --into C:\dev\gravewell\assets\textures
```

Sized from the physical pixels a cell displays at, which is 384 to 512, not from what the
download offers. Coreward measured 1k as three quarters of a megabyte thrown away.

### Props: the pad, the Hold, and the ship's bolt-on parts

Poly Haven, CC0, `--res 1k`, into `assets/models`. On screen at full size for a long time, so
this is squarely import territory.

`plastic_crate_03`, `wooden_military_crate`, `Barrel_01`, `barrel_03`, `small_lpg_tank`,
`propane_tank`, `modular_industrial_pipes_01`, `modular_pipes`, `modular_electric_cables`,
`industrial_pipe_lamp`, `industrial_caged_sconce`, `utility_box_01`, `utility_box_02`,
`worn_metal_rack`, `tool_cart`, `industrial_storage_cart`, `portable_welding_cart`,
`ladder_sectioned_01`, `modular_airduct_rectangular_01`, `portable_generator`, `pipe_wrench`,
`adjustable_wrench`, `lubricant_spray`.

The lamp fixtures are used as the actual mesh with a real `SpotLight3D` parented to them, so
the light and the thing emitting it cannot disagree.

### Skies

Poly Haven HDRIs, `assets/hdri`. **Write the `.import` before the first import**:
`compress/mode=2` and `process/size_limit=512`. Six at the default settings cost +14 MB; at
these settings they are about 175 KB each and the difference is invisible on a sky.

`cave_wall` (Hollow), `winter_river` (Rime), `abandoned_slipway` (Verge), `dikhololo_night`
(Quick), `approaching_storm` (Drown), `industrial_sunset_puresky` (Cinder, graded hard, and
flagged as an approximation rather than a fit).

### Particles, UI, icons, font

| Need | Source | Id | Licence |
|---|---|---|---|
| Dust, embers, sparks | Kenney | `particle-pack` (80 sprites at 512 px) | CC0 |
| Smoke | Kenney | `smoke-particles` | CC0 |
| UI kit | Kenney | `ui-pack` | CC0 |
| Touch prompts | Kenney | `input-prompts` | CC0 |
| Icons | Lucide | `gauge, thermometer, flame, droplet, wind, alert-triangle, battery, zap, pickaxe, gem, package, radiation, skull, crosshair, compass, wrench, cpu, activity` | ISC |
| Headings and labels | Google Fonts | **Chakra Petch** 500 and 700 | OFL-1.1 |
| Numeric readouts | Google Fonts | **Share Tech Mono** 400 | OFL-1.1 |

Two font families on purpose: Chakra Petch is condensed and technical and legible small, and
Share Tech Mono is monospace, which is how depth, load and value line up digit for digit
without needing a tabular-figures feature. One icon family only, so stroke weights cannot
disagree; Lucide has `pickaxe` and `gem`, which is why game-icons is not needed.

The Kenney UI atlas is recoloured to the dark palette once rather than tinted per widget, and
one `Theme` is built from it with 9-slice `StyleBoxTexture`.

### Sound

Freesound CC0 (the HQ OGG preview, which the key alone downloads and which is fine for a
phone), plus Kenney packs for matched round-robin sets.

| Need | Source | Id |
|---|---|---|
| Drilling rock | Freesound | `639019` pneumatic drill in an underground mine |
| Rock collapse | Freesound | `500638`, `438684` |
| Hull creak | Freesound | `407326`, `700705` |
| Thruster loop | Freesound | `398675` |
| Alarm | Freesound | `584287` |
| Water drips | Freesound | `464251`, `476318` |
| Gas hiss | Freesound | `615667` |
| Deep rumble | Freesound | `473725` |
| Eerie drones | Freesound | `452999`, `479328` |
| Impacts | Kenney | `impact-sounds` |
| UI | Kenney | `interface-sounds`, `sci-fi-sounds`, `digital-audio` |

Anything that must **answer** a number is generated, not sampled: the drill pitch tracking rock
hardness, the hull creak tracking integrity, the score crossfading on depth.

### Music

The Tallbeard bundle is fetchable now, and it is a **tonal miss**: its own tags are ambient,
chiptune, upbeat. Wrong family. Instead, two or three CC0 drone and industrial tracks from
OpenGameArt (`Manaos Drones`, `Abandon Hope`, `Overshadow`, `Factory ambiance`) as the bed,
with the game's actual theme generated through the MIDI and FluidSynth pipeline in
`techniques/generated-audio.md`, because the theme has to crossfade on depth and danger and no
library loop can do that.

### Addons

| Need | Repo | Tag | Licence |
|---|---|---|---|
| Menus, options, pause, credits | `Maaack/Godot-Menus-Template` | `v1.7.0` | MIT |
| Camera follow and transitions | `ramokz/phantom-camera` | `v0.11.0.3` | MIT |
| Post: vignette, grain, aberration | `KorinDev/Godot-Post-Process-Plugin` | `v0.1.1` | MIT |
| Debug and perf overlay | `antzGames/Antz-Debug-Menu` | `v1.3.0` | MIT |

No joystick addon: Godot 4.7's built-in touch handling clears the bar and the d-pad is
hand-built anyway so its hit box is its drawing.

### The misses, which shape the plan

1. **The drill ship. No CC0 photoreal ship or drone exists anywhere searched.** Every hit is
   flat-shaded low-poly, which is the exact "cartoony" failure mode and the wrong style family
   beside photoreal rock. The hull is **modelled by hand** as a real asset, not code-modelled
   like a thirty-pixel sprite, and the **upgrade parts bolt on from the Poly Haven industrial
   set** (tanks, lamp housings, pipes, utility boxes) so the ship belongs to the same world as
   the pad and the Hold. This is a milestone of its own in phase one.
2. **No Crush sky.** Built from `ProceduralSkyMaterial` plus height fog, which is a better fit
   than forcing a mismatched photograph and is hand-tunable.
3. **No dead neon signage.** Hand-painted emissive quads with the flicker driven from a shader
   and game state, which is where it belongs anyway because a flickering light is a light source
   and its timing is gameplay.
4. **No salt, coal, basalt, frost or oil-stain material** under those names. Repurpose the
   closest normals recoloured, and hand-paint the oil mask so it matches the grime layout rather
   than a photograph.
5. **No lava sky, floodlight, pallet or workbench model.** Substitutes named above, and the
   substitution gets written into `NOTES.md` when built rather than left silent.
6. **Bioluminescence is not an import.** Its radius and pulse answer proximity and danger, which
   makes it game state being drawn, so it is a shader driven by the simulation.

### One unifying pass over everything imported

Two style families are in play and the split is safe because they never share a surface: Poly
Haven and ambientCG are photoreal and live in the 3D world, Kenney is flat and lives in the UI
and in additive particles. Every imported PBR material is forced to metallic 0 and roughness
about 0.8 unless it is genuinely metal, scale is normalised on import so a crate and the hull
agree on what a metre is, one `Environment` tonemap (ACES) is applied globally so a lava
emissive and an ice normal compress the same way, and one shared fresnel rim term is added in a
common shader so the hand-modelled hull, the Poly Haven props and the rock all pick up the same
lamp-facing glint.

### A tool bug to fix before the asset hunt runs

`assets.py search kenney` returns **zero results for every query**: the site now emits
single-quoted `href='...'` attributes and the slug regex in `search_kenney` still expects double
quotes. `get kenney <slug>` is unaffected, which is why every slug above could be confirmed by a
direct fetch. Fix the regex to accept either quote character. Filed to `inbox/` so the next
session does not lose its two minutes to a search that silently returns nothing.

---

## Tests and tools

**Golden.** `test/run_tests.gd`, headless, about a second. A golden over a whole descent under
each policy, over floats with `TestHarness.FLOAT_EPS` because `snappedf` does not round-trip
through a source literal and goldens are recorded on Windows and checked on Linux.
`blocks-baseline.json` is frozen and is never re-recorded.

**Design tests**, one line each, every one of which has caught a design mistake in a past game
or is aimed at one that shipped:

- A do-nothing descent loses.
- The greedy policy out-earns the cautious one and dies more often.
- Every ore band is reachable, and every row of every content table occurs in an actual run.
- Each class's counter-mineral lies below that class's Line.
- Each class's Line depth equals its rock band change depth.
- Air density is strictly increasing with depth, and any two classes differ by a margin.
- The ascent is survivable from the core with the worst legal load, and the route bound holds
  after every collapse.
- The chart always offers every class the drive still needs.
- At most one sealed row in the rack, and never zero while something is gated.
- The contour never encroaches into a cell collision calls open.
- `SimUtil.hash2` returns the full range with a flat distribution (a signed shift silently
  returns only the bottom half and disabled three shipped mechanics for a game's whole life).
- No file in `src/sim/` references a Node, a Viewport, an input event or `randf()`, asserted by
  reading the files. **And every one of those assertions is verified by reintroducing the bug**,
  because a Coreward guard written exactly like this was green and completely inert: its
  allow-list clause permitted the thing it existed to catch. The allow-list clause is where a
  vacuous guard hides.

**Smoke.** `test/run_smoke.gd` boots the real scene and drives through every terminal state:
land, dig, uplink, run out of power, get recovered, re-descend the open shaft, reach the core,
extract, ascend, fail an ascent, take the chart, buy in the rack. It drives the **input
handler's seam**, not the methods, because a way out the handler never calls is a missing
feature with full coverage. `visible_instance_count` is the flush and forgetting it fails
silently.

**Probe.** `test/run_probe.gd`, never fails, prints: minute and depth at which each upgrade
first becomes affordable across six seeds, power spent per metre by band, ore value per minute
by band, how often each ability is used and **"never used" out loud** when one is not, and the
ascent margin distribution. This is the file that answers "is the cost worth the benefit", which
he asked for by name with both acceptance criteria attached.

**Films.** `scripts/movie.ps1` with named replays: `first-minute`, `descent`, `line` (crossing
the threshold), `extraction`, `ascent`, `hold` (the room), `chart`, `recovery`. Replay
coordinates are the **project viewport at about 1080x2338**, not the `--resolution` value:
Movie Maker ignores `--resolution` and ffmpeg does the downscaling afterwards, which is exactly
why a contact sheet looks right and hides the problem. Console errors are collected and printed
with every sheet.

**Phone.** `scripts/device.ps1`: `perf` at the start of a session and again after ten minutes,
because thermal throttling is the real constraint and it degrades a session while it is being
played. Back button, home and resume, safe area, haptics, rotation lock, sleep prevention, all
exercised every time.

**Version is one fact in three places** (`src/changelog.gd` and `version/name` in both export
presets) and a test asserts they agree, because they have drifted before and the drift lands
exactly on the question the build stamp exists to answer.

---

## Polish budget

Every line of `POLISH.md` is a ship gate. The ones this game has to pay for specifically, and
where:

| POLISH line | Paid by |
|---|---|
| Playable in ten seconds, first thirty seconds need no reading, first minute is a win | M5 and M10 |
| Movement has velocity and coasting, smoothing assigned not added | M1 |
| Controls thumb-sized, anchored to the real viewport, each owning its input | M4 |
| A real light with falloff, a normal map on the largest surface, a considered sky | M2 |
| Post under the HUD: vignette, grain, lifted blacks | M9 |
| A self-hosted font, two weights, everywhere | M4 |
| Every interactable has visible geometry | M7 |
| Ambient motion in the idle state | M2 and M9 |
| The shop is a place, scrolls from a finger, primary button pinned | M7 |
| Sound for every action with pitch jitter and a round-robin pool | M9 |
| Music with a theme, a cadence and a pulse, crossfading on depth | M9 |
| Main menu, options, pause, credits, confirm before erasing | M10 |
| Version, build stamp and patch notes in the pause screen | **M1**, not M9. It stopped being enough for him after a few sessions in the last game and the lesson recorded was to do it much earlier |
| Back button, home and resume, portrait lock, safe area, haptics | M10 |
| Adaptive icon, splash, package name | M10 |
| `assets/CREDITS.md` complete and the credits screen renders it | M9 |

---

## Milestones

Each slice ships on its own: import, tests, smoke, build, size guard, CI. Nothing sits
half-finished on `main`.

### Phase 1: first playable

- [x] **M1. The simulation, headless.** (0.2.0) Grid with float corner fills, seeded generation with
      the offset table, flight with velocity and collision, drilling with kept partial damage,
      ore with weight, power/hull/load, the uplink, recovery. Version, build stamp and
      changelog in place from this commit. *Proves it:* `test_world`, `test_fly`, `test_ship`,
      the first golden over a scripted descent, and the `src/sim` boundary test with all five
      assertions falsified by reintroducing each bug.
- [x] **M2. The look: rock, contour and the lamp.** (0.3.0) Marching-squares terrain chunked into
      `ArrayMesh`, PBR rock under a moving lamp, the flood fill, the field texture, the shadow
      fan, surface and air as two lights, air density wired to fog and lamp reach, dust motes.
      *Proves it:* `test_contour`, `test_light`, `test_air`. *Film:* `descent`.
- [x] **M3. The ship, modelled by hand.** (0.4.0) The hull, the drill head, the lamp housing, thrusters
      and the mount points that upgrades bolt onto, in the same style family and the same metre
      scale as the Poly Haven industrial props. Its own key light on its own layer, excluded
      from the world's light through `light_cull_mask` and `layers`, so buying a lamp upgrade
      does not brighten the ship. This is a milestone because the asset scout found no photoreal
      CC0 ship anywhere and the one thing permanently on screen cannot be a placeholder.
      *Proves it:* a screenshot at 460x996 and the upgrade mount points exercised by the smoke
      test. *Film:* `descent` re-shot with the real hull.
- [x] **M4. Controls, HUD and the first sixty seconds.** (0.5.0) D-pad, lamp mode, uplink and ordnance
      buttons, the three readouts where the plan puts them, the manifest, the fonts.
      *Proves it:* smoke drives the input seam. *Film:* `first-minute`, reviewed against the six
      questions in `TESTING.md` with the answers written into `NOTES.md`.
- [x] **M5. Cinder complete.** (0.5.0) Five bands, the ore ladder, seams, the Line at 80 m with four
      things landing on the same metre, caches with diegetic cues, the recovery loop, tunnels
      persisting between descents. *Proves it:* `test_classes` for Cinder, the probe's first
      real numbers. *Film:* `line`.
- [x] **M6. The core and the extraction.** (0.5.0) The core chamber, cutting it free, the world dying,
      the ascent with the route bound and its test, failure that costs the planet and never the
      save. *Proves it:* the ascent bound test and smoke driving both outcomes. *Film:*
      `extraction`, `ascent`.
- [x] **M7. The Hold.** (0.6.0) The room, the rack with physical parts and the real ship in it, finger
      scrolling with the pinned button, the chart table, the drive frame with its seven empty
      slots visible from the first hour. *Proves it:* the sealed-row test, and the room tested
      at a size where it must scroll. *Film:* `hold`, `chart`.
- [x] **M8. Rime, the second class.** (0.7.0) Brittle rock that cuts in half the time, ceilings that
      come down, ice that carries light. The point of this milestone is that the second planet
      proves classes differ by rule. *Proves it:* `test_classes` asserts Rime differs from
      Cinder on at least three of five channels and that its rule fires in a scripted descent.
- [ ] **M9. Audio, atmosphere and the polish pass.** Flood-driven reverb, density-driven
      lowpass, the written theme layered by depth, sound on every action, post under the HUD,
      growth on the rock faces, credits. *Proves it:* the monotonic mood-arc test and a real
      span on the crossfade.
- [ ] **M10. Shell, phone and ship.** Title over a live scene, the intro, settings reusing the
      pause sheet, save on every meaningful change and on `APPLICATION_PAUSED`, back button
      with its handler in the same commit, icon, splash, package. Then `/playtest desk`,
      `/playtest phone`, `/ship`.

### Phase 2: content and meta

- [ ] The other five classes: Drown, Crush, Hollow, Verge, Quick, in that order. Drown first
      because water is the most dramatic and the most work
- [ ] Vaults, the drill tier gate, and the keepsake per world
- [ ] Log fragments and the log wall
- [ ] The drive completing, the final world, and the ending, with the endless game behind it
- [ ] The full consumable and ordnance set, including the collapse charge and the flare
- [ ] Second-tier upgrades and the Survey instrument that gives a bearing and never a marker
- [ ] **Attention, and the things that live in the tunnels.** Attention rises while you drill
      and while the lamp is bright, and falls while you are still and dark. It is the model
      Sunless Sea uses for Terror: a numeric consequence of a choice the player makes knowingly,
      warned continuously, rather than a wandering predator. It is heard before it is seen and
      it is avoided rather than fought, which needs no combat and almost no AI. It ships with
      the first dweller and not before, because a pressure with no teeth is scaffolding

### Phase 3: polish and store

- [ ] The full `POLISH.md` walk with nothing outstanding
- [ ] Play listing per `PLAY.md`: AAB on a `v*` tag, target SDK from Gradle, store icon,
      screenshots, data safety, privacy policy

---

## Second month

An eighth class that breaks a rule the other seven share. A layer beneath the core, reachable
only after the drive is built. A rival salvager working the same worlds, whose tunnels you find
already cut and whose route you can follow or avoid. Hulls with different shapes rather than
only better numbers, so the ship is a choice. An endless Drift past the ending, with the worlds
still generating and the record being how deep and how many.

---

## Open decisions I made for him

Reversible, one line each, with the alternative. These move into `NOTES.md` at scaffold.

1. **Name and slug: Gravewell / `gravewell`.** A gravity well is what you dig down through and
   a grave is what these worlds are. *Alternative:* anything he prefers, and renaming now costs
   nothing.
2. **No mid-descent return trip.** *Alternative:* Coreward's climb back to the pad. Rejected on
   the research: it is the genre's most-cited complaint and it is the mechanism behind him never
   playing past 60 m.
3. **The d-pad stays; no virtual joystick.** *Alternative:* Godot 4.7's built-in
   `VirtualJoystick`, if the first playtest asks for finer control.
4. **Collision stays on the cell grid while the visible rock is a marching-squares contour.**
   *Alternative:* collision on the contour, which is more correct, decomposes concave polygons
   and cannot be tested nearly as cleanly.
5. **Seven classes, two in phase one.** *Alternative:* more classes shallower, which is the
   Coreward mistake of twelve palettes over one cave.
6. **One room, not two shops.** The Hold is both the upgrade room and the hub. *Alternative:* a
   pad shop for refits and a separate hub, which is two chances to get wrong the screen he
   opens first.
7. **The core at about 200 m and five bands.** Provisional until the probe measures the real
   descent time. *Alternative:* whatever the probe says makes a descent five to ten minutes.
8. **Audio generated at build time into committed WAVs**, with sampled impacts where a sample
   is better. *Alternative:* fully sampled, if the scout finds a pack that fits the brief.
