class_name Ore
extends RefCounted

## What is in the rock, what it weighs and what it is worth.
##
## Cargo is WEIGHT, never units. Coreward counted units, so dirt and rubies
## took the same slot, and the report was "It is difficult to judge the price
## of the different blocks you are mining". Two things the player cannot
## compare on screen are not a choice.

## Material ids. These are stored in the world's byte array and in the frozen
## baseline, so **a value here is permanent**: append, never renumber.
const AIR := 0
const ROCK := 1
const IRON := 2
const COBALT := 3
const ARGENT := 4
const PYRE := 5
const VOIDGLASS := 6
const CACHE := 7
const CORE := 8

## The ore table, **ordered deepest-first with each entry's chance strictly
## lower than the next**. That ordering is what makes adding a new deepest ore
## convert only the band directly above it instead of reshuffling every band in
## the game, and `test_tuning.gd` asserts it.
##
## `glow` is what the material emits on its own, which is the whole
## find-the-ore mechanic in a game this dark: emissive is exempted from the
## light field's surface term and run through a gentler curve, so a rich seam
## reads through the gloom while plain rock does not.
const ORES: Array[Dictionary] = [
	{"id": VOIDGLASS, "name": "Voidglass", "min_depth": 168, "chance": 0.010, "kg": 2.6, "value": 41.0, "glow": 0.95},
	{"id": PYRE,      "name": "Pyre",      "min_depth": 126, "chance": 0.020, "kg": 2.1, "value": 22.0, "glow": 0.80},
	{"id": ARGENT,    "name": "Argent",    "min_depth":  74, "chance": 0.045, "kg": 1.8, "value": 11.5, "glow": 0.45},
	{"id": COBALT,    "name": "Cobalt",    "min_depth":  34, "chance": 0.090, "kg": 1.5, "value":  5.4, "glow": 0.18},
	{"id": IRON,      "name": "Iron",      "min_depth":   6, "chance": 0.170, "kg": 1.2, "value":  2.2, "glow": 0.00},
]


## Everything a material is worth carrying, including plain rock.
##
## Plain rock pays a very small amount and a seam pays much more. His words:
## "can you make it so most regular dirt and rock give you a very small amount
## of resource, and those textured areas give you more?" The seam roll and the
## payout come from the same roll, so what is drawn on the wall and what it
## pays are true by construction rather than by two systems agreeing.
static func yield_of(mat: int, seam: bool) -> Dictionary:
	if mat == AIR or mat == CACHE or mat == CORE:
		return {"kg": 0.0, "value": 0.0, "name": ""}
	var kg := Tuning.SLAG_KG
	var per_kg := Tuning.SLAG_VALUE
	var display := "Slag"
	for o in ORES:
		if o["id"] == mat:
			kg = o["kg"]
			per_kg = o["value"]
			display = o["name"]
			break
	var mult := Tuning.SEAM_MULT if seam else 1.0
	return {"kg": kg, "value": kg * per_kg * mult, "name": display}


## **How much harder this material is to cut than plain rock.**
##
## Derived from its WEIGHT, not typed in. `kg` is already in the table as what a
## cell of the stuff weighs, and "dense things take longer to get through" is the
## same statement as "dense things are heavy to carry" - so the number the player
## reads in the hold is the number that slowed them down getting it, and the two
## can never drift apart.
##
## His ask: "I would rather ... get slowed down on denser materials, and the
## particles or effects will sell that something is taking a lot more work, or
## easy fluffy dirt." Measured before this existed: every material in the first
## forty metres cut at exactly hardness 1.00, so there was nothing to be slowed
## BY and the whole stretch he played ran at a flat 3.10 m/s.
##
## The exponent keeps the range readable. Raw density would make Voidglass 3.25
## times the work of rock and, on top of the deepest band, fifteen times, which
## is a wall rather than a slow patch.
const DENSITY_POWER := 0.6

## A seam is a richer pocket of the same ore, so it is denser again. This is what
## makes finding one something you FEEL in the drill a moment before the payout
## confirms it.
const SEAM_HARDNESS := 1.25


static func hardness_of(mat: int, seam: bool = false) -> float:
	if mat == AIR:
		return 0.0
	# The cache and the core are not ore and do not follow the density rule: the
	# core has its own multiplier at the call site, and a cache is a container.
	if mat == CACHE or mat == CORE:
		return 1.0
	var kg := Tuning.SLAG_KG
	for o in ORES:
		if o["id"] == mat:
			kg = o["kg"]
			break
	var h: float = pow(maxf(kg, 0.001) / Tuning.SLAG_KG, DENSITY_POWER)
	return h * (SEAM_HARDNESS if seam else 1.0)


## How much a material glows on its own, before any lighting is applied.
static func glow_of(mat: int) -> float:
	for o in ORES:
		if o["id"] == mat:
			return o["glow"]
	return 0.0


static func name_of(mat: int) -> String:
	match mat:
		AIR: return "Air"
		ROCK: return "Slag"
		CACHE: return "Cache"
		CORE: return "Core"
	for o in ORES:
		if o["id"] == mat:
			return o["name"]
	return "?"


## Which ore, if any, a cell at this depth rolls into. The roll is handed in
## rather than taken, so this stays pure and the world owns the seed discipline.
##
## Deepest first and stop at the first hit: an ore that is legal here and rarer
## wins over a commoner one, which is what makes the bands ladder instead of
## averaging out.
static func roll(depth: float, r: float) -> int:
	for o in ORES:
		if depth >= float(o["min_depth"]) and r < float(o["chance"]):
			return int(o["id"])
	return ROCK
