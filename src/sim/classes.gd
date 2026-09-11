class_name Classes
extends RefCounted

## What a world IS, which is a rule before it is a palette.
##
## Coreward had twelve planets and they were twelve tints on one cave. His ask
## for this game was that they "feel completely different from each other", and
## the answer is that **each class changes something about digging, flying or
## seeing, and the art follows from that rule rather than sitting beside it.**
##
## A palette is a still image: two worlds painted differently still behave
## identically, and a player learns that in one descent.
##
## Seven classes in the plan. Three are built: Cinder is the control, Rime is the
## one that proves the point, and Drown is the one whose pressure the player
## causes rather than meets.

const CINDER := 0
const RIME := 1
const DROWN := 2

## Every field here is read by something. A class that only sets colours is a
## palette wearing a rule's clothes, and `test_classes.gd` asserts that any two
## classes differ on at least three of the five channels.
const ALL: Array[Dictionary] = [
	{
		"id": CINDER,
		"name": "Cinder",
		"blurb": "burnt out. honest rock, and it gets hot",
		# The control. Everything else reads against this.
		"hardness": 1.0,
		"cut_noise": 0.0,
		# How fast light loses its way going round a corner. Higher is murkier.
		"detour_att": 0.55,
		"line": "HEAT",
		"line_note": "the rock smoulders",
		"cavern_chance": 0.16,
		"brittle": false,
		"tint": [
			Color(1.00, 0.96, 0.90), Color(0.86, 0.88, 0.94), Color(1.15, 0.80, 0.62),
			Color(1.05, 0.62, 0.44), Color(0.90, 0.44, 0.34),
		],
		"air": [
			Color(0.050, 0.052, 0.060), Color(0.044, 0.048, 0.058),
			Color(0.090, 0.052, 0.038), Color(0.120, 0.058, 0.036),
			Color(0.150, 0.062, 0.034),
		],
	},
	{
		"id": RIME,
		"name": "Rime",
		"blurb": "frozen through. cuts fast, and the ceilings do not hold",
		# **The rule.** Ice cuts in half the time, which makes a descent quick and
		# makes every wide cut a decision: an unsupported ceiling comes down.
		"hardness": 0.5,
		"cut_noise": 0.0,
		# Ice carries light much further than rock, so the flood barely attenuates
		# round a corner and a Rime tunnel is legible far past where a Cinder one
		# goes black. The world is brighter AND more dangerous, which is the trade.
		"detour_att": 0.24,
		"line": "COLD",
		"line_note": "the hull stiffens",
		"cavern_chance": 0.26,
		"brittle": true,
		"tint": [
			Color(0.88, 0.95, 1.05), Color(0.78, 0.88, 1.02), Color(0.62, 0.82, 1.15),
			Color(0.50, 0.72, 1.10), Color(0.40, 0.58, 1.00),
		],
		"air": [
			Color(0.045, 0.055, 0.070), Color(0.040, 0.052, 0.072),
			Color(0.038, 0.060, 0.095), Color(0.034, 0.062, 0.110),
			Color(0.030, 0.058, 0.125),
		],
	},
	{
		"id": DROWN,
		"name": "Drown",
		"blurb": "drowned. the shaft you cut becomes a well",
		# Saturated rock: heavy and slow to cut, the opposite trade to Rime.
		"hardness": 1.3,
		"cut_noise": 0.0,
		# Murky. Light in water is scattered rather than carried, so a Drown
		# tunnel goes black around a corner sooner than a Cinder one does.
		"detour_att": 0.78,
		"line": "PRESSURE",
		"line_note": "the seals are working",
		# Fewer natural voids, because the interesting space is the space you cut
		# and then have to swim back up.
		"cavern_chance": 0.10,
		"brittle": false,
		# **The rule.** Everything below `water_table` that is open holds water,
		# and the surface climbs as the player opens volume under it.
		"floods": true,
		"water_table": 46.0,
		"tint": [
			Color(0.82, 0.92, 0.90), Color(0.66, 0.84, 0.86), Color(0.48, 0.74, 0.82),
			Color(0.34, 0.62, 0.76), Color(0.22, 0.46, 0.66),
		],
		"air": [
			Color(0.040, 0.058, 0.062), Color(0.034, 0.058, 0.066),
			Color(0.026, 0.062, 0.082), Color(0.020, 0.058, 0.092),
			Color(0.014, 0.048, 0.098),
		],
	},
]

## How wide an unsupported span has to be before a Rime ceiling gives. Three
## cells: a one-cell shaft is safe forever, which keeps the safe way to dig
## available and makes the wide cut the gamble.
const BRITTLE_SPAN := 3

## How long between the crack and the fall. Longer than human reaction time by a
## wide margin, because a tell shorter than about a third of a second is a
## reaction test rather than a decision, and this one is meant to be a decision:
## you hear it, and you choose whether to finish the seam or leave.
const BRITTLE_DELAY := 2.4

## What a falling ceiling costs. It is meant to hurt and never to end a descent
## on its own: a hazard may take the takings, never the run.
const BRITTLE_DAMAGE := 22.0


static func of(id: int) -> Dictionary:
	return ALL[clampi(id, 0, ALL.size() - 1)]


static func hardness_mult(id: int) -> float:
	return float(of(id)["hardness"])


static func detour_att(id: int) -> float:
	return float(of(id)["detour_att"])


## Does this world's water fill the tunnels the player cuts? Only Drown, and a
## rule that fires everywhere is a rule the player cannot attribute to a world.
static func floods(id: int) -> bool:
	return bool(of(id).get("floods", false))


## The depth its water starts at, before the player has opened anything.
static func water_table(id: int) -> float:
	return float(of(id).get("water_table", 1.0e9))


static func is_brittle(id: int) -> bool:
	return bool(of(id)["brittle"])


static func cavern_chance(id: int) -> float:
	return float(of(id)["cavern_chance"])


static func tint_at(id: int, depth: float) -> Color:
	return of(id)["tint"][Tuning.band_at(depth)]


static func air_at(id: int, depth: float) -> Color:
	return of(id)["air"][Tuning.band_at(depth)]


static func line_name(id: int) -> String:
	return String(of(id)["line"])


## How different two classes are, counted over the five channels a player can
## actually perceive. `test_classes.gd` requires at least three.
static func differences(a: int, b: int) -> int:
	var ca := of(a)
	var cb := of(b)
	var n := 0
	if not is_equal_approx(float(ca["hardness"]), float(cb["hardness"])):
		n += 1
	if not is_equal_approx(float(ca["detour_att"]), float(cb["detour_att"])):
		n += 1
	if ca["brittle"] != cb["brittle"]:
		n += 1
	# Whether the tunnels fill with water is the most perceivable thing any class
	# does, so it counts as a channel of its own.
	if bool(ca.get("floods", false)) != bool(cb.get("floods", false)):
		n += 1
	if String(ca["line"]) != String(cb["line"]):
		n += 1
	# The palette counts once, and only once: twelve tints on one cave is what
	# this whole file exists to stop being mistaken for variety.
	var palette_differs := false
	for i in range(ca["tint"].size()):
		var x: Color = ca["tint"][i]
		var y: Color = cb["tint"][i]
		if absf(x.r - y.r) + absf(x.g - y.g) + absf(x.b - y.b) > 0.25:
			palette_differs = true
	if palette_differs:
		n += 1
	return n
