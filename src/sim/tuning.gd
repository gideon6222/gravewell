class_name Tuning
extends RefCounted

## Every number that shapes how Gravewell feels, in one place, with the reason
## for each beside it, plus the arithmetic derived from them.
##
## Pure: nothing here reads live state. That is what lets `test/` check the
## shape of the curves - which is what a balance change accidentally breaks -
## without booting a game.
##
## Numbers marked (M) were measured, (T) survived play, (P) came out of the
## probe, and anything unmarked is a first guess waiting for `run_probe.gd`.
## PLAN.md is explicit that the core depth and the descent time are provisional
## until the probe measures them, so do not defend an unmarked number.

# ── the grid ──────────────────────────────────────────────────────────────
# A cell is one metre. Depth is measured in metres downward from the pad, so
# depth and cell row are the same number and nothing has to convert.
const CELL := 1.0
const HALF_WIDTH := 20            ## cells either side of the shaft centre: a 41-wide world
const SURFACE_ROWS := 3           ## open air above depth 0, where the pad sits

## A cell is passable only once it is FULLY cut. Shared by collision, the light
## flood and the drill, so a cell can never be flyable to one system and solid
## to another.
##
## This was 0.5 for one afternoon, on the idea that one number could serve
## passability and the contour's isovalue at the same time. It cannot, and the
## failure was silent and total: a half-cut cell counted as open, so the ship
## flew into cells it had not finished, the drill moved on to the next one, and
## **nothing in the game ever broke or yielded anything**. A scripted miner dug
## to 86 m in twenty-five seconds and mined precisely zero kilograms.
##
## Passability is a rule and the isovalue is a picture. They are two numbers.
## **Fine cells per metre, for the fill field only.**
##
## A cell was one metre and the ship is 0.76 m, so the drawn wall could only
## recede in steps close to the ship's own width - and marching squares on a
## metre lattice cannot represent anything smaller whatever the brush does
## underneath. Measured: the face moved 2.43 ship-widths a second in steps
## averaging 0.18 m with facets a metre across snapping between frames.
##
## The research settles it. Games whose destruction reads as continuous erosion
## run one to two orders of magnitude finer than their character - Worms about
## 18:1, Noita about 32:1 - and games that read as blocky run near 1:1 ON
## PURPOSE, with a square visual grammar to match: Terraria about 0.5:1,
## SteamWorld Dig about 1:1 by its designer's own account. Gravewell was at
## 0.76:1 while drawing smooth interpolated curves, which promises Worms and
## delivers Dig Dug. **That mismatch is the complaint, not the metres a second.**
##
## It also settles which of the two mechanisms he offered is the right one: the
## brush already accumulates continuously between rebuilds, so a finer TICK
## changes nothing. The limit is spatial.
##
## At 3 this is a third-metre cell and a ratio of about 2.3:1, against 0.76:1
## before: the visible step drops from a metre to a third of one. Nine times the
## fill data, which is 300 KB and nothing, and nine times the contour, which is
## why the terrain mesh had to become chunked in the same commit.
##
## **4 was measured and rejected on cost, not on looks.** The mesh rebuild while
## drilling came to 18.1 ms a tick against a 16.7 ms frame, and 3 is 6.7. The
## research puts genuinely continuous destruction at 18:1 and higher, which is a
## per-pixel simulation and not something a marching-squares contour in GDScript
## reaches at any setting; what is on offer here is a third the step size, and
## that is what 3 buys inside the budget.
const SUB := 3

const OPEN_FILL := 1.0e-4

## **And the metre-scale question, which is a different one.**
##
## `OPEN_FILL` answers "is this quarter-metre gone", which is what collision and
## the drawn surface need, and it is exact. This answers "has this METRE been
## worked out" - whether light travels through it, whether its ore has been paid,
## whether the route home runs through it. A round tunnel cannot clear the
## corners of a square metre, so demanding every fine cell be gone means no metre
## is EVER worked out: measured, a scripted miner sat frozen against a metre it
## had taken to 94% while the policy flip-flopped over which way was open.
##
## These are not two thresholds for one fact, which is the trap this file has
## fallen into twice. They are one threshold each for two facts at two scales,
## and the metre one is derived from the fine field and never stored beside it.
## **Derived from the lattice, not typed in.** It means "at most one and a half
## fine cells of this metre are left", which is a statement that survives a
## change to `SUB`; the literal 0.10 did not. At `SUB` 3 a single leftover corner
## cell is 1/9 = 0.111 of the metre, which is over 0.10, so no metre with one
## sliver in it ever counted as worked out - the core was never cut and no route
## home was ever found. The same literal had been fine at `SUB` 4, where a cell
## is 1/16.
const METRE_OPEN := 1.5 / float(SUB * SUB)

## The isovalue the marching-squares contour crosses. Its value is decided at M2
## against the corner-averaging scheme and it has nothing to do with whether the
## ship can fly there.
const CONTOUR_ISO := 0.5

# ── the depth bands ───────────────────────────────────────────────────────
# Five bands. The Line is the top of band 3 and four things land on that metre:
# the rock changes, the air changes, the hull starts draining and a sound
# arrives. `test_tuning.gd` asserts BAND_DEPTHS[2] == LINE_DEPTH, because in
# Coreward the rock band moved and the heat threshold did not, and his note was
# that he could feel the line was there and could not find it.
const BAND_DEPTHS: Array[int] = [0, 40, 80, 130, 175]
## Measured (P), not guessed. `run_probe.gd` puts a working dig at **1.26 m/s**
## over six planets, so 200 m is about 159 s of pure digging and a real descent
## with ore detours and uplinks lands between four and eight minutes. That is
## inside PLAN.md's five-to-ten-minute target, so the provisional number stands.
const CORE_DEPTH := 200
const LINE_DEPTH := 80

## Rock hardness per band, in hit points a cell. Rising hardness is what makes
## depth cost time as well as power, and it is why a straight dive to the core
## is slow even with nothing in the way.
const BAND_HP: Array[float] = [1.0, 1.6, 2.4, 3.4, 4.6]

## What the rock of each band LOOKS like, as a multiplier on the material colour.
##
## This is half of "four things land on the same metre". In Coreward the rock
## band changed at 60 m and the heat threshold sat at 70, so the only marker of
## the boundary was a number that never appears on screen, and his note was that
## he could feel the line was there and could not find it.
##
## Band 2 is the Line, and it is deliberately the largest step in the table: the
## rock goes from cold grey to smouldering in one metre, at exactly the metre the
## hull starts draining.
const BAND_TINT: Array[Color] = [
	Color(1.00, 0.96, 0.90),   ## regolith: pale, dusty, warm
	Color(0.86, 0.88, 0.94),   ## bedrock: cold grey, the control
	Color(1.15, 0.80, 0.62),   ## THE LINE: smouldering, and it reads instantly
	Color(1.05, 0.62, 0.44),   ## deep: ember
	Color(0.90, 0.44, 0.34),   ## core shell: nearly black, veined hot
]

## What the AIR of each band looks like, which is the other half of the same
## metre. The fog warms as the rock does, from one table, so they cannot drift.
const BAND_AIR: Array[Color] = [
	Color(0.050, 0.052, 0.060),
	Color(0.044, 0.048, 0.058),
	Color(0.090, 0.052, 0.038),
	Color(0.120, 0.058, 0.036),
	Color(0.150, 0.062, 0.034),
]

# ── flight ────────────────────────────────────────────────────────────────
# CRAFT.md: reach top speed in about a fifth of a second and coast under a
# cell. On a thumb, momentum reads as latency.
const TOP_SPEED := 7.0            ## m/s unladen
const THRUST_RATE := 17.0         ## exponential rate; 3/rate ~= 0.18 s to 95% of top speed
const COAST_RATE := 8.0           ## v/rate = 0.88 m of coast from top speed, under one cell
const SHIP_MASS := 90.0           ## kg. Acceleration is thrust / (SHIP_MASS + load_kg)

## The lane pull that keeps the ship square to the grid while it is cutting.
## Coreward's version was `+=` onto an existing velocity and ran while coasting,
## which is exactly the undamped spring that got reported as "very bouncy". It
## is ASSIGNED, and it runs only while a direction is held.
const LANE_RATE := 12.0
const LANE_DEADZONE := 0.04       ## m; inside this the pull is off, so it cannot hunt

const SHIP_HALF := 0.38           ## collision half-extent in cells. Under half so a
                                  ## one-cell tunnel is comfortably flyable

## Hitting rock hurts, but **the drill absorbs the face it is cutting**. Without
## that exception every single block you cut is a crash: the ship accelerates
## freely across the cell it just opened and arrives at the next face at nearly
## top speed, which measured 6.75 m/s and 17 hull a block, so the hull was gone
## after four cells of ordinary digging. Drilling is the core verb of the game
## and it cannot be the thing that kills you.
##
## What still hurts is hitting rock you were NOT cutting: coasting into a wall,
## being carried into one, or a ceiling coming down on you.
const IMPACT_FREE_SPEED := 4.0    ## m/s of closing speed that costs nothing
const IMPACT_DAMAGE := 6.0        ## hull per m/s above that

# ── the drill, which is a PLOW ────────────────────────────────────────────
#
# **Nothing gates the ship's motion on a unit of work being finished.** His
# words after the first phone session: "digging feels very rigid and chunky.
# while I am digging, it takes large chunks out, slows me down, then speeds up.
# I would rather dig at a more consistent speed ... instead of taking longer to
# destroy a chunk I would like it to continously plow through but get slowed
# down on denser materials."
#
# The old model aimed at ONE cell, spent `fill * hardness / DRILL_RATE` seconds
# taking it to zero, and refused to let the hull move until it was gone. That is
# a stop-start at a one-metre cadence, and **the cadence is what he feels**: the
# interpolation inside each step was already smooth and it did not help.
#
# Of the reference games, only Motherload does what he is describing - the pod
# drills the instant it moves into terrain and its speed is a number that falls
# with depth. SteamWorld Dig, Dome Keeper and Terraria are all discrete per-tile
# underneath and hide it behind a fast fixed swing cadence, which is the thing
# being complained about here.
#
# Speed comes out of the same arithmetic that pays for the hole, so the picture
# and the bill cannot disagree. Advancing one metre removes one cell's worth of
# fill, which costs `hardness` hit points, so
#
#     plow speed = drill power / (hardness * HP_PER_METRE)
#
const DRILL_RATE := 2.2           ## hit points a second at tier 0
const DRILL_REACH := 0.62         ## m from the ship's centre the nose bites at

## Hit points to advance one metre through hardness-1.0 rock. One cell of fill,
## which is what one metre of tunnel is. It exists as a constant rather than as a
## literal 1.0 so the speed and the power bill read the same number.
## A metre of tunnel is about 1.6 square metres of material now: one full column
## plus the partial cutting either side of it that makes the wall smooth. The
## drill is charged for what it actually removes, which is also why the plow runs
## slower than it did - 1.38 m/s in surface rock against 2.20.
const HP_PER_METRE := 1.45

## The slowest ROCK is still visibly moving. Asserted, never applied.
##
## It was a `max()` inside `plow_speed` for one round and that was wrong: a floor
## there lets the hull advance faster than the drill can clear the cell in front
## of it, and **a ship that outruns its own carve passes through unbroken
## material**. Measured, it went straight through a planet's core without cutting
## it and ended forty metres past, with the core sitting at fill 0.62.
##
## So the speed is exactly what the material allows, with nothing under it, and
## this is the property the band table has to keep: `BAND_HP` spans 1.0 to 4.6,
## so the deepest rock still plows at 0.67 m/s. The core multiplies hardness by
## six and is deliberately far below this - it is meant to be the slowest thing
## in the game, and it is one cell.
## The floor is stated at the drill tier the player will HAVE by then, not at
## tier 0. Band 4 is 175 m down, six upgrade rungs into a run, and the drill
## ladder multiplies by up to 3.2: the deepest rock is meant to want a better
## drill, which is what makes buying one mean something. At tier 0 it is 0.30 m/s
## and that is the tell, not a wall.
const PLOW_MIN_ROCK := 0.42
## Which rung of the drill ladder the floor above is measured at.
const PLOW_MIN_TIER := 2

## The drill head is a DISC, feathered at its rim, swept along the path actually
## travelled this tick.
##
## Feathered because a hard-edged disc bites in circular arcs that do not line up
## with the grid and leaves the contour scalloped, and **those scallops are what
## his second complaint is about**: "the light also appears to get caught on the
## edges of tunnels that I have made because they have random edges that stick
## out." A smooth wall has no protrusions and a protrusion is what throws a hard
## wedge of shadow.
##
## Swept, because a tick at a low frame rate would otherwise skip past a thin
## wall and leave it standing behind the ship.
## **Wide enough to finish a whole metre as it passes.**
##
## A round brush does not cover a square metre: the corners of the column sit
## further from the axis than its middle, so they spend less of the pass inside
## the full-strength core and fall behind. Measured at radius 0.52, ten seconds
## of drilling left **no metre in the game fully cleared** - every one stopped at
## a mean of 0.22 with its outer columns standing - so nothing ever paid out and
## the light never opened a single cell. At 0.72 it was seven metres in nine. At
## 0.78 it is all of them.
const BRUSH_RADIUS := 0.72        ## m of full-strength cut around the head
const BRUSH_FEATHER := 0.30       ## m of falloff beyond it

## Damage already done to a cell is KEPT when you stop. His words: "Blocks
## should stop being dug if you stop drilling but remember how much damage is
## already done to them so they can be partially damaged, then easily finished
## off." A commitment you cannot back out of is a wall wearing a decision's
## clothes, and the stored damage IS the corner fill, so there is no second
## number that can disagree with the picture.
const DAMAGE_IS_FILL := true      ## documentation, asserted in test_world.gd

# ── power, hull, load ─────────────────────────────────────────────────────
# Three clocks that are not interchangeable, so "can I keep going" is never one
# number. Power is the master: it drives the drill, the thrusters and the lamp.
## Measured (P): a cautious descent spends its power 34% on the drill, 29% on
## thrust, 19% on the lamp, 15% on uplinks and 3% on carrying. No single sink
## dominates, which is what keeps the lamp mode and the uplink timing real
## decisions rather than rounding errors.
const POWER_MAX := 240.0
const HULL_MAX := 100.0
const HOLD_KG := 60.0

## Drilling costs power PER HIT POINT, not per second, so hard rock is
## expensive by construction and the deep bands cost more without a second
## curve that could drift out of step with BAND_HP.
## Rebalanced with `HP_PER_METRE`: the two multiply into the power a metre costs,
## and that number is the one the descent was tuned around. When the brush grew
## wide enough to finish a whole metre, hit points per metre went 1.0 -> 1.6 and
## this came down by the same factor, so the budget is exactly where it was.
## Measured before the correction: every scripted policy died at six metres.
const POWER_PER_HP := 0.34
const POWER_PER_THRUST_S := 0.30
const POWER_PER_KG_S := 0.0016    ## carrying is a slow drain, so a full hold is a clock

## The lamp is a choice, not a meter. Darkwood's lesson: several light tools
## trading brightness against burn rate beat one depleting bar. Dark RECOVERS,
## which is what makes "go dark and wait" a verb rather than a wait.
enum Lamp { FLOOD, LANCE, DARK }
const LAMP_DRAIN: Array[float] = [0.20, 0.55, -0.10]
const LAMP_REACH: Array[float] = [7.0, 15.0, 1.2]     ## m
const LAMP_CONE: Array[float] = [2.4, 0.55, 3.0]      ## radians of full beam width

## How far past the lamp's own reach the shadow fan is cast, as a multiple of it.
##
## Longer than the light on purpose: a corner five metres beyond the last lit
## pixel still has to be in the fan, or the wedge it throws pops into existence
## as the ship drifts toward it.
##
## **It is here, once, because it is used at both ends.** The fan was cast to
## 1.8x and decoded in the shader with 1x, so every shadow began at 55% of its
## true distance. Two numbers for one quantity, which is the same fault as two
## thresholds for "gone", twice before in this repo.
const FAN_REACH_MULT := 1.8

## Power low dims the lamp, so being in trouble looks like the world closing in
## rather than like a number turning red. PLAN.md addition 2.
const LAMP_FADE_START := 0.30     ## fraction of POWER_MAX below which reach falls
const LAMP_MIN_REACH := 1.0       ## m at zero power. Never zero: a black screen is a bug

# ── the uplink ────────────────────────────────────────────────────────────
# Selling is an action taken in place, not a journey. The cost rises with depth
# and weight, so "bank it now or carry it further" stays live all the way down.
# This exists because the return trip is the genre's most-hated element.
const UPLINK_BASE := 6.0
const UPLINK_PER_M := 0.05
const UPLINK_PER_KG := 0.20

# ── recovery ──────────────────────────────────────────────────────────────
# Running out never takes the run. You keep everything already uplinked, you
# lose what is in the hold, and the tunnels stay open. His own Coreward design.
const RECOVERY_CUT := 1.0         ## fraction of the hold lost. Insurance reduces it

# ── the extraction ────────────────────────────────────────────────────────
# Reaching the core is HALF of it. Cutting it free starts the world dying and
# the only way out is the tunnel you dug, with the core aboard making you heavy
# and lit up. It reuses the level that was just built, and it turns Coreward's
# weakest beat - a modal dialog announcing that the planet exploded - into the
# best thing in the game.

## The core is a physical object in the hold, and it is heavy. Two thirds of the
## whole capacity, so the climb out is genuinely laboured and the choice of what
## to drop to make room for it is a real one.
const CORE_KG := 40.0

## What comes up behind you, in metres a second. Derived from the route rather
## than set flat: `extraction_seconds()` turns the actual shortest open path into
## a clock with a margin on it, so a long clever route and a straight shaft get
## the tension they each deserve.
const EXTRACT_MARGIN := 1.55       ## how much longer than the fastest climb
const EXTRACT_MIN_S := 26.0        ## never a panic on a short route
const EXTRACT_MAX_S := 150.0       ## never a stroll on a long one

# ── the Line ──────────────────────────────────────────────────────────────
## Hull a second at one full unit of excess density. Calibrated so the drain is
## a clock you can read and act on rather than a cliff: at 130 m it is about
## 1.6 hull a second, so a full hull lasts a minute, and at the core it is about
## 4.2, so half a minute. Both are survivable with the counter and neither is
## survivable without it. The probe checks the survivable depth per fit.
const PRESSURE_RATE := 1.2
const LINE_WARN_M := 12.0         ## how far above the Line the warning starts.
                                  ## Announce a zone before charging for it

# ── air density ───────────────────────────────────────────────────────────
# One number driving fog, lamp reach, bloom, muffling, reverb, drag and hull
# load. He described a feeling; this makes it a quantity so the picture and the
# rules cannot disagree.
const AIR_SURFACE := 0.05         ## density at depth 0
const AIR_PER_M := 0.0042         ## linear term
const AIR_CURVE := 1.35           ## depth exponent, so it thickens rather than ramps
const AIR_DRAG := 0.55            ## velocity lost a second at density 1.0

# ── water, which is Drown's whole rule ────────────────────────────────────
#
# **The only pressure in this game the player CAUSES rather than meets.** The
# air thickens with depth, the hull drains past the Line and the collapse rises
# on a clock; all three arrive whatever you do. The water rises because you cut
# the rock, and sitting still costs nothing.
#
# The physical story, which is also the arithmetic: the rock down there is
# saturated, so every cell you open releases the water it was holding, and that
# water runs into the void network you have been cutting. The network is a shaft
# about a metre across, so a cell's worth of released water raises the level by
# roughly the fraction of the cell that was water.

## How far the surface climbs per cell opened below it. 0.15 is a rock about
## fifteen per cent water by volume draining into a shaft one metre wide, and it
## puts a full hundred-and-fifty-cell descent at about twenty metres of rise:
## enough that the way home is visibly worse than the way down, and not so much
## that the shaft is gone.
const WATER_RISE_PER_CELL := 0.15

## Hull a second at the surface of the water, and how many metres under it takes
## to double that. Drowning is the Line for this class: it has a way out, and the
## way out is always up.
const DROWN_HULL_RATE := 0.35
const DROWN_HULL_SCALE := 25.0

## What water does to flight. Buoyancy in m/s of upward pull and a drag far
## heavier than any air: **down becomes the expensive direction**, which inverts
## the motion of the whole game for one world.
const WATER_BUOYANCY := 2.2
const WATER_DRAG := 1.8

## And what it does to the lamp. Water scatters rather than carries, so the pool
## closes in and a flooded tunnel reads as flooded before anything says so.
const WATER_LAMP := 0.55

# ── ore ───────────────────────────────────────────────────────────────────
# Cargo is WEIGHT, never units. Two things the player cannot compare on screen
# are not a choice, and counting units made dirt and rubies take the same slot.
#
# Most rock pays a very small amount and textured seams pay much more, which is
# his suggestion and the only unprompted design compliment in six games. The
# seam roll and the payout come from the SAME roll, so what is drawn on the
# wall and what it pays are true by construction.
const SLAG_KG := 0.8              ## a plain rock cell
const SLAG_VALUE := 0.6           ## credits a kilogram
const SEAM_MULT := 3.4            ## a seam cell pays this multiple of its ore
const SEAM_CHANCE := 0.16         ## fraction of cells carrying visible seam texture

# ── secrets ───────────────────────────────────────────────────────────────
# Filament is FOUND, never mined, and it is the only thing that buys a counter
# to a threat. This is the structural fix for "I can afford upgrades pretty
# early on for fuel and cooling so neither is a risk": grinding the shallow
# band forever buys a bigger hold and never once buys safety.
## Caches are placed one per block rather than by a per-cell roll, so the
## spacing is guaranteed by construction instead of by a rejection pass that
## would depend on the order cells were visited. Two caches touching reads as a
## vein rather than as a find.
const CACHE_BLOCK := 9            ## cells a side
## Measured (P): 7 to 13 caches a planet, **17.5 filament in total, of which
## only about 4.5 sits above the Line**. So the first Line counter has to be
## affordable inside that 4.5 or it can never be bought before the threat it
## counters, which is the exact failure this whole two-currency split exists to
## prevent. M7 prices against these numbers.
const CACHE_BLOCK_CHANCE := 0.13
const CACHE_MIN_DEPTH := 18       ## none in the teaching band
const CACHE_FILAMENT: Array[int] = [1, 1, 2, 2, 3]   ## by band

## Caverns: open space the player did not cut. Cinder is the control class and
## has almost none, which is what lets Hollow read as enormous later.
const CAVERN_BLOCK := 17
const CAVERN_CHANCE := 0.16
const CAVERN_MIN_DEPTH := 26
const CAVERN_RADIUS: Array[float] = [2.2, 4.6]   ## min, max in cells

# ── seed offsets ──────────────────────────────────────────────────────────
# Every generator rolls on its OWN offset. Consuming an existing roll shifts
# every ore at every depth on every planet and the diff looks like three lines.
# `test_world.gd` asserts there are no duplicates here.
const SEED_ORE := 0
const SEED_SEAM := 17
const SEED_CACHE := 41
const SEED_CAVERN := 77
const SEED_VAULT := 113
const SEED_GROWTH := 131
const SEED_AMBIENCE := 149
const SEED_OFFSETS: Array[int] = [0, 17, 41, 77, 113, 131, 149]


## The rock tint at a depth, blended across the last two metres of the band above
## so the boundary is a hard line rather than a dissolve. A hard line is the
## point: he has to be able to SEE where the Line is.
## Kept as the Cinder defaults. The per-class tables live in `Classes`, which is
## what a world actually reads, and these two remain so nothing that only knows
## about depth has to know about classes as well.
static func tint_at(depth: float) -> Color:
	return BAND_TINT[band_at(depth)]


static func air_at(depth: float) -> Color:
	return BAND_AIR[band_at(depth)]


## Which band a depth falls in. Clamped at both ends so a caller never has to.
static func band_at(depth: float) -> int:
	var b := 0
	for i in range(BAND_DEPTHS.size()):
		if depth >= float(BAND_DEPTHS[i]):
			b = i
	return b


## **How fast the ship plows through material of this hardness.**
##
## The one place the dig's speed comes from. Derived rather than tuned: the cost
## of a metre is a cell of fill at that hardness, and the power bill charges the
## same hit points, so a change to one is a change to both.
##
## `BAND_HP` spans 1.0 to 4.6, which puts the deepest rock at 4.6 times slower
## than the surface. That sits inside the 4:1 to 6:1 range the genre research
## puts on "slow" before it starts reading as "stuck", and it is a spread across
## the WHOLE descent rather than a step, so any one stretch feels steady.
## **Nothing is clamped under this.** The speed IS the rate the drill can clear
## the cell in front of the hull, so a floor is a licence to move through rock
## that has not been cut. `PLOW_MIN_ROCK` says what the band table must keep.
static func plow_speed(power: float, hardness: float) -> float:
	return power / maxf(hardness * HP_PER_METRE, 0.001)


## The hardness at which every effect channel is at full: heaviest rumble, lowest
## drill note, most debris. Above the deepest band's plain rock, so the top of
## the range belongs to dense ore in deep rock rather than to depth alone.
const LOAD_FULL := 6.4
## And the least it can ever read while the drill is actually turning.
const LOAD_FLOOR := 0.15


## **How hard the work looks, in 0..1.** One number, and every channel that sells
## the effort reads it: the particle rate and their colour, the drill loop's
## pitch and filter, the haptic cadence, the camera tremor.
##
## His ask: "the particles or effects will sell that something is taking a lot
## more work, or easy fluffy dirt." Four channels agreeing is what makes that
## read; four channels each with their own curve is what makes it mush.
##
## **It is measured from zero, not from the softest band, and it has a floor.**
## The first version mapped `BAND_HP[0]` to exactly 0, so plain surface rock
## reported no load at all - and since the first forty metres of every planet are
## band 0, that meant the whole opening of the game had no drill sound, no
## rumble and no tremor. Measured on the stretch he actually played: `dig_load`
## read 0.00 for ten seconds straight. He described the result as the ship
## driving through without slowing down, and he was describing silence as much as
## speed.
static func dig_load(hardness: float) -> float:
	var t: float = clampf(hardness / LOAD_FULL, 0.0, 1.0)
	return clampf(LOAD_FLOOR + t * (1.0 - LOAD_FLOOR), LOAD_FLOOR, 1.0)


## Hit points a cell at this depth. The only place hardness comes from.
static func hardness_at(depth: float) -> float:
	return BAND_HP[band_at(depth)]


## Air density at a depth. Strictly increasing, and the exponent is what makes
## it thicken rather than ramp, so the deep feels different in kind rather than
## in degree.
static func density_at(depth: float) -> float:
	var d: float = maxf(depth, 0.0)
	return AIR_SURFACE + AIR_PER_M * pow(d, AIR_CURVE)


## What one uplink costs in power, from where you are standing with what you
## are carrying.
static func uplink_cost(depth: float, load_kg: float) -> float:
	return UPLINK_BASE + UPLINK_PER_M * maxf(depth, 0.0) + UPLINK_PER_KG * maxf(load_kg, 0.0)


## How far the lamp reaches, given its mode and how much power is left. Below
## LAMP_FADE_START the reach falls linearly to LAMP_MIN_REACH, so the world
## closes in as the power goes.
static func lamp_reach(mode: int, power_frac: float) -> float:
	var base: float = LAMP_REACH[mode]
	if power_frac >= LAMP_FADE_START:
		return base
	var t: float = clampf(power_frac / LAMP_FADE_START, 0.0, 1.0)
	return LAMP_MIN_REACH + (base - LAMP_MIN_REACH) * t


## How long the player gets to climb out after cutting the core free.
##
## **Derived from the content, never set as a rate over it.** The route is the
## shortest open path the simulation can actually find, the climb is that path at
## the speed a fully laden ship makes, and the margin is what turns a measurement
## into a chase. A flat timer would be a stroll on a straight shaft and
## impossible after a clever winding descent, and there would be no way to know
## which without playing it.
static func extraction_seconds(route_cells: int, load_kg: float) -> float:
	var speed: float = maxf(speed_for(load_kg + CORE_KG) * 0.72, 0.5)
	var climb: float = float(maxi(route_cells, 1)) / speed
	return clampf(climb * EXTRACT_MARGIN, EXTRACT_MIN_S, EXTRACT_MAX_S)


## Top speed with a load aboard. The risk dial the player holds: the last ore
## you pick up is the one that strands you.
static func speed_for(load_kg: float) -> float:
	return TOP_SPEED * SHIP_MASS / (SHIP_MASS + maxf(load_kg, 0.0))
