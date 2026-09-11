class_name Upgrades
extends RefCounted

## The ladder, and the two currencies that climb it.
##
## Pure. The Hold draws this; it decides nothing.
##
## ## The structural fix for the one complaint that mattered most
##
## His words about Coreward: *"I can afford upgrades pretty early on for fuel and
## cooling so neither is a risk."* The documented cause of that failure mode is a
## **currency fungible across every threat**: if mining buys both cargo and
## survival, and mining is the fastest grind, the player buys immunity to every
## threat before any threat bites.
##
## So there are two currencies and they do different jobs:
##
## - **Credits** are mined, and they buy the routine ladder: drill, hold, power,
##   thrust, lamp. Grindable on purpose.
## - **Filament** is FOUND, never mined, in caches and vaults only, and it buys
##   **every counter to a threat and nothing else**.
##
## A pressure seal therefore cannot be bought with ore at any price. Grinding the
## shallow band forever buys a bigger hold and a faster drill and never once buys
## safety, which is precisely the failure he reported.
##
## ## The curve
##
## Motherload's published ladder is the baseline and its multiplier RISES with
## depth: $750, $2,000, $5,000, $20,000, $100,000, $500,000, which is 2.67x,
## 2.5x, 4x, 5x, 5x. Late rungs demand more trips than early ones, not fewer.
## `run_probe.gd` measures the descents-per-rung this actually produces and
## `test_economy.gd` asserts it lands in 2 to 4 early and 4 to 6 late.

## Rising multipliers, applied in order. The last one repeats if a ladder ever
## grows past five rungs.
##
## **Monotonic on purpose.** Motherload's published ladder is 2.67x, 2.5x, 4x,
## 5x, 5x, which dips at the second rung; the test here asserts the property the
## curve is FOR ("late rungs demand more trips than early ones") rather than
## copying the reference's wobble, and a curve that dips means one rung in the
## middle is the cheapest in real terms for no reason anybody chose.
const STEP: Array[float] = [2.5, 2.9, 3.6, 4.4]

## What credits buy. `mult` is applied to the tuning constant it names; `base` is
## the first rung's price.
##
## Five rungs each, because that is enough for a ladder to be felt and few enough
## that the shop stays a room rather than a spreadsheet.
const LADDER: Array[Dictionary] = [
	{"id": "drill", "name": "DRILL", "base": 420.0, "mount": "instrument",
		"blurb": "cuts faster", "mult": [1.0, 1.35, 1.8, 2.4, 3.2]},
	{"id": "hold", "name": "HOLD", "base": 380.0, "mount": "tank",
		"blurb": "carries more", "mult": [1.0, 1.35, 1.75, 2.25, 2.9]},
	{"id": "power", "name": "CELL", "base": 460.0, "mount": "tank",
		"blurb": "longer descents", "mult": [1.0, 1.25, 1.58, 2.0, 2.5]},
	{"id": "thrust", "name": "THRUST", "base": 340.0, "mount": "plating",
		"blurb": "faster, stops harder", "mult": [1.0, 1.12, 1.25, 1.40, 1.55]},
	{"id": "lamp", "name": "LAMP", "base": 500.0, "mount": "instrument",
		"blurb": "sees further, frames wider", "mult": [1.0, 1.15, 1.32, 1.50, 1.70]},
]

## What filament buys. **Every counter to a threat is here and nothing else.**
##
## `verb` is not decoration. Metroid Dread's weakest abilities are the ones that
## only unlock a door, and that is the standard critique of the pattern: a tool
## that reopens a sealed place must also give a new verb usable everywhere, or
## backtracking is a fetch and return.
const COUNTERS: Array[Dictionary] = [
	{"id": "seal", "name": "SEAL", "cost": [4, 7, 11], "mount": "plating",
		"blurb": "the Line bites less",
		"verb": "and the hull creaks before it cracks, so you can hear the depth"},
	{"id": "bore", "name": "BORE", "cost": [9], "mount": "instrument",
		"blurb": "cuts heat-sealed rock",
		"verb": "and reads warm rock anywhere, so a magma vein shows before you hit it"},
	{"id": "survey", "name": "SURVEY", "cost": [6, 10], "mount": "ordnance",
		"blurb": "a bearing to the nearest anomaly",
		"verb": "never a marker: it narrows the search rather than ending it"},
]

## How much a seal takes off the pressure drain per rung. Never to zero: an
## upgrade that removes a threat entirely removes the mechanic with it.
const SEAL_RELIEF: Array[float] = [1.0, 0.72, 0.50, 0.34]


static func ladder_of(id: String) -> Dictionary:
	for u in LADDER:
		if u["id"] == id:
			return u
	for u in COUNTERS:
		if u["id"] == id:
			return u
	return {}


## The credit price of taking `id` from `level` to `level + 1`.
##
## Two curves multiplied: the tier step, which rises with depth the way
## Motherload's does, and a flat surcharge per purchase ACROSS the whole tree,
## which is Rogue Legacy's fix for a single currency trivialising late upgrades
## once it has been farmed. The second is the lever to reach for if a playtest
## shows grinding defusing a threat.
static func price(id: String, level: int, total_bought: int) -> float:
	var u := ladder_of(id)
	if u.is_empty() or not u.has("base"):
		return -1.0
	var rungs: int = u["mult"].size()
	if level >= rungs - 1:
		return -1.0                                  ## maxed
	var p: float = float(u["base"])
	for i in range(level):
		p *= STEP[mini(i, STEP.size() - 1)]
	return p * (1.0 + 0.06 * float(total_bought))


## The filament price of the next rung of a counter, or -1 if maxed.
static func counter_cost(id: String, level: int) -> int:
	var u := ladder_of(id)
	if u.is_empty() or not u.has("cost"):
		return -1
	var costs: Array = u["cost"]
	if level >= costs.size():
		return -1
	return int(costs[level])


## The multiplier a ladder is at, clamped so a level past the end is the top.
## How many rungs a ladder has, so nothing has to know the shape of the table to
## ask whether a tier exists. The vault seals ask for a tier and the test asserts
## the tier is one the player can actually buy.
static func rungs(id: String) -> int:
	var u := ladder_of(id)
	return (u["mult"] as Array).size() if not u.is_empty() else 0


static func mult(id: String, level: int) -> float:
	var u := ladder_of(id)
	if u.is_empty() or not u.has("mult"):
		return 1.0
	var m: Array = u["mult"]
	return float(m[clampi(level, 0, m.size() - 1)])


static func max_level(id: String) -> int:
	var u := ladder_of(id)
	if u.has("mult"):
		return u["mult"].size() - 1
	if u.has("cost"):
		return u["cost"].size()
	return 0


## What the rack shows.
##
## **Everything unlocked, plus exactly one teaser**: the shallowest thing still
## out of reach. `CRAFT.md` used to say show every sealed row, and that rule was
## corrected on Coreward at fifteen upgrades: a case reading "sealed until 90 m"
## when your best is 78 m is a reason to go deeper, and the same case at 12 m is
## furniture. A rule about how much to show is a ratio and it expires silently
## when the content count doubles.
##
## `levels` maps id to level, `deepest` is the record that gates, and `bought` is
## how many rungs have been taken in total.
static func rack(levels: Dictionary, deepest: float, bought: int, credits: float,
		filament: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []

	# The teaser is the SHALLOWEST thing still out of reach, not the first one in
	# the table. Picking it by declaration order shows a gate at 130 m while a
	# gate at 40 m is hidden, which is the opposite of a reason to go deeper.
	var teaser_gate := 1.0e18
	for u in LADDER + COUNTERS:
		var g: float = _gate_of(String(u["id"]), int(levels.get(u["id"], 0)))
		if deepest < g:
			teaser_gate = minf(teaser_gate, g)

	for u in LADDER + COUNTERS:
		var id: String = u["id"]
		var level: int = int(levels.get(id, 0))
		var gate: float = _gate_of(id, level)
		var sealed: bool = deepest < gate

		if sealed and gate > teaser_gate:
			continue                                  ## furniture, not a goal

		var is_counter: bool = u.has("cost")
		var cost: float = float(counter_cost(id, level)) if is_counter \
			else price(id, level, bought)
		var maxed: bool = cost < 0.0
		var afford: bool = (float(filament) >= cost) if is_counter else (credits >= cost)

		rows.append({
			"id": id,
			"name": u["name"],
			"blurb": u["blurb"],
			"verb": String(u.get("verb", "")),
			"level": level,
			"max": max_level(id),
			"filament": is_counter,
			"cost": cost,
			"mount": u["mount"],
			"sealed": sealed,
			"gate": gate,
			"maxed": maxed,
			# Three separate booleans, because "unavailable", "not a control" and
			# "cannot afford" are three different things and only refusal is grey.
			"afford": afford and not maxed and not sealed,
		})
	return rows


## Depth gates. Depth is the cheapest structural gate there is because it cannot
## be farmed, and it is shown rather than hidden.
static func _gate_of(id: String, level: int) -> float:
	if id == "seal":
		return float(Tuning.LINE_DEPTH) - Tuning.LINE_WARN_M + float(level) * 30.0
	if id == "bore":
		return float(Tuning.BAND_DEPTHS[3])
	if id == "survey":
		return float(Tuning.BAND_DEPTHS[1]) + float(level) * 40.0
	# The routine ladder opens a rung at a time on the record, so there is always
	# somewhere to go and always something to want.
	return float(level) * 26.0


## How much of the Line's bite a seal takes off. Never all of it.
static func seal_relief(level: int) -> float:
	return SEAL_RELIEF[clampi(level, 0, SEAL_RELIEF.size() - 1)]
