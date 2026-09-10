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
const OPEN_FILL := 1.0e-4

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

# ── the drill ─────────────────────────────────────────────────────────────
const DRILL_RATE := 2.5           ## hit points a second at tier 0
const DRILL_REACH := 0.62         ## m from the ship's centre the nose bites at

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
const POWER_PER_HP := 0.55
const POWER_PER_THRUST_S := 0.30
const POWER_PER_KG_S := 0.0016    ## carrying is a slow drain, so a full hold is a clock

## The lamp is a choice, not a meter. Darkwood's lesson: several light tools
## trading brightness against burn rate beat one depleting bar. Dark RECOVERS,
## which is what makes "go dark and wait" a verb rather than a wait.
enum Lamp { FLOOD, LANCE, DARK }
const LAMP_DRAIN: Array[float] = [0.20, 0.55, -0.10]
const LAMP_REACH: Array[float] = [7.0, 15.0, 1.2]     ## m
const LAMP_CONE: Array[float] = [2.4, 0.55, 3.0]      ## radians of full beam width

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


## Which band a depth falls in. Clamped at both ends so a caller never has to.
static func band_at(depth: float) -> int:
	var b := 0
	for i in range(BAND_DEPTHS.size()):
		if depth >= float(BAND_DEPTHS[i]):
			b = i
	return b


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


## Top speed with a load aboard. The risk dial the player holds: the last ore
## you pick up is the one that strands you.
static func speed_for(load_kg: float) -> float:
	return TOP_SPEED * SHIP_MASS / (SHIP_MASS + maxf(load_kg, 0.0))
