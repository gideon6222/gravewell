class_name Sim
extends RefCounted

## The whole game, with no renderer in it.
##
## `src/game/` reads these numbers and draws them, and never the other way
## round. Nothing in this file may reference a Node, a Viewport, an input event
## or a delta that came from a real frame. If it needs to know something about
## the world, it takes it as an argument.
##
## ## The shape of a descent
##
## One-way. You land, you cut down, you uplink ore from where you stand rather
## than hauling it back, and the descent ends one of three ways: you run out
## (recovery), you break (recovery), or you cut the core free and the
## extraction begins. **There is no mid-descent return trip**, because the
## return trip is this genre's most-cited complaint and because it is the
## mechanism behind seven Coreward sessions never getting past 60 m.
##
## The tunnels persist between descents on a planet, so running out costs the
## hold and never the planet, and the next descent is a fast dive down a shaft
## that is already open.

signal broke_cell(x: int, d: int, m: int, value: float)
signal picked_up(kg: float, value: float)
signal found_cache(filament: int)
signal hull_hit(speed: float)
signal uplinked(value: float, cost: float)
signal descent_over(outcome: String)
signal core_cut(seconds: float)
signal drill_bite(hardness: float)
signal collapsed(x: int, d: int)

enum Phase { DESCENT, EXTRACTION, OVER, HOLD }

## Persistent across descents and planets. Credits are mined; filament is only
## ever FOUND, and it is the only thing that buys a counter to a threat.
var credits: float = 0.0
var filament: int = 0
var cores: int = 0

## The ladder, by upgrade id. `bought` is the count across the whole tree, which
## is what makes every purchase raise the price of the next one.
var levels: Dictionary = {}
var bought: int = 0

## The record that gates the rack. Depth is the cheapest structural gate there
## is, because it cannot be farmed, and it is shown rather than hidden.
var record: float = 0.0

var planet: int = 1
var world: World
var flight: Flight

var phase: int = Phase.DESCENT
var outcome: String = ""
var time: float = 0.0

var power: float = Tuning.POWER_MAX
var hull: float = Tuning.HULL_MAX
var lamp_mode: int = Tuning.Lamp.FLOOD

## The hold, keyed by material id: {kg, value, count}. A manifest rather than a
## number, so two ores are comparable on screen and the choice between them is
## a real one.
var hold: Dictionary = {}
var load_kg: float = 0.0

## Ore left lying where it fell because the hold was full. His ask: "make it so
## I can always dig but if the hull is full, just leave the resources floating
## in place for me to pick up later". A full hold that stops the drill is a wall
## that asks nothing of the player.
var drops: Array[Dictionary] = []

var deepest: float = 0.0
var descents: int = 0

## **How hard the work looks right now, 0 to 1, and zero when not drilling.**
##
## One number, read by the particles, the drill loop, the haptics and the camera
## shake, so they cannot disagree about whether this is fluffy dirt or something
## that is taking real effort. His ask: "the particles or effects will sell that
## something is taking a lot more work, or easy fluffy dirt."
var dig_load: float = 0.0

## The extraction. `rising` is the depth the world has died up to: everything
## below it is gone, and when it reaches the ship the run is over.
var extract_left: float = 0.0
var extract_total: float = 0.0
var rising: float = 0.0
var carrying_core := false

var _warned_line := false


func _init(seed_value: int = 1, world_class: int = 0) -> void:
	planet = seed_value
	world = World.new(seed_value, world_class)
	flight = Flight.new(world)


## Into the Hold, which is the only shop and the only place between descents.
func enter_hold() -> void:
	phase = Phase.HOLD


## Whether the last descent finished the planet. Only carrying a core out does.
func planet_finished() -> bool:
	return outcome == "escaped with the core"


## Out of the Hold. Either back down the shaft you already cut, or on to a new
## world if you carried this one's core out.
func launch() -> void:
	if planet_finished():
		next_planet()
	else:
		redescend()


## A new world. Everything the player has KEPT comes with them - credits,
## filament, cores, the ladder, the record - and only the planet is new.
func next_planet() -> void:
	planet += 1
	# The class alternates for now. A later milestone replaces this with the
	# chart, where choosing WHERE to go is the decision the classes exist for.
	world = World.new(planet, planet % Classes.ALL.size())
	flight = Flight.new(world)
	drops.clear()
	deepest = 0.0
	descents = 0
	redescend()


## Start another descent on the SAME planet. The world, and therefore every
## tunnel already cut, is kept.
func redescend() -> void:
	flight = Flight.new(world)
	phase = Phase.DESCENT
	outcome = ""
	power = power_capacity()
	hull = Tuning.HULL_MAX
	hold = {}
	load_kg = 0.0
	_warned_line = false
	carrying_core = false
	extract_left = 0.0
	extract_total = 0.0
	rising = 0.0
	descents += 1


# ── what the ladder actually changes ──────────────────────────────────────
#
# Every constant the player can buy is read through here rather than from
# `Tuning` directly, so an upgrade cannot be a number in a shop that changes
# nothing in the world. `test_economy.gd` asserts each of these moves.

func level_of(id: String) -> int:
	return int(levels.get(id, 0))


func drill_rate() -> float:
	return Tuning.DRILL_RATE * Upgrades.mult("drill", level_of("drill"))


func hold_capacity() -> float:
	return Tuning.HOLD_KG * Upgrades.mult("hold", level_of("hold"))


func power_capacity() -> float:
	return Tuning.POWER_MAX * Upgrades.mult("power", level_of("power"))


func speed_mult() -> float:
	return Upgrades.mult("thrust", level_of("thrust"))


## The lamp reach, and therefore the FRAMING. His suggestion, and it was the
## right shape: a lamp that only grows a radius while the camera frames a fixed
## number of rows can never be felt, because the frame is always inside the lit
## circle. So the camera pulls back with it, and the darkness is what justifies
## the tight frame at the start.
func lamp_reach() -> float:
	return Tuning.lamp_reach(lamp_mode, power_frac()) * Upgrades.mult("lamp", level_of("lamp"))


## What one rung costs right now, or -1 if it is maxed or still sealed.
func cost_of(id: String) -> float:
	var u := Upgrades.ladder_of(id)
	if u.is_empty():
		return -1.0
	if record < Upgrades._gate_of(id, level_of(id)):
		return -1.0
	if u.has("cost"):
		return float(Upgrades.counter_cost(id, level_of(id)))
	return Upgrades.price(id, level_of(id), bought)


## Take a rung. Returns true if it was actually bought.
##
## Credits and filament are never interchangeable here: a counter checks
## filament and nothing else, which is the whole two-currency design in one
## branch.
func buy(id: String) -> bool:
	var u := Upgrades.ladder_of(id)
	if u.is_empty():
		return false
	var cost := cost_of(id)
	if cost < 0.0:
		return false
	if u.has("cost"):
		if filament < int(cost):
			return false
		filament -= int(cost)
	else:
		if credits < cost:
			return false
		credits -= cost
	levels[id] = level_of(id) + 1
	bought += 1
	# Capacity bought mid-game is capacity you have now, not next descent.
	power = minf(power, power_capacity())
	return true


func rack() -> Array[Dictionary]:
	return Upgrades.rack(levels, record, bought, credits, filament)


# ── the frame ─────────────────────────────────────────────────────────────

## One step of the simulation. `dir` is the d-pad; `drilling` is whether the
## player is asking to cut, which in practice is the same held direction, but
## they are separate arguments so a test can drive one without the other.
func step(dir: Vector2, drilling: bool, dt: float) -> void:
	if phase == Phase.OVER:
		return
	time += dt

	var d := flight.depth()
	var density := Tuning.density_at(d)

	# Is the drill engaged? If it is, the collision is the drill doing its job
	# and it costs nothing. If it is not, the ship hit rock it was not cutting
	# and that is what hurts.
	var held := dir.length_squared() > 0.001
	var drill_engaged := drilling and held

	# **The plow's speed is set BEFORE the move**, from the material the head is
	# about to be in, so the tick that carves and the tick that advances agree
	# about how hard the rock is. `dig_load` is the same number the effects read.
	var hardness := _hardness_under_head(dir)
	dig_load = Tuning.dig_load(hardness) if drill_engaged else 0.0
	flight.plow_speed = 0.0
	if drill_engaged:
		flight.plow_speed = minf(
			Tuning.plow_speed(drill_rate(), hardness),
			Tuning.speed_for(load_kg) * speed_mult())

	flight.speed_mult = speed_mult()
	flight.step(dir, load_kg, density, dt)

	if flight.impact_speed > Tuning.IMPACT_FREE_SPEED and not drill_engaged:
		hull -= (flight.impact_speed - Tuning.IMPACT_FREE_SPEED) * Tuning.IMPACT_DAMAGE
		hull_hit.emit(flight.impact_speed)

	_drain(dir, dt)
	if drill_engaged:
		_drill(dt)
	_pressure(d, density, dt)
	_settle(dt)
	_collect()
	if phase == Phase.EXTRACTION:
		_extract(dt)

	deepest = maxf(deepest, flight.depth())
	record = maxf(record, deepest)
	if power <= 0.0:
		_end("out of power")
	elif hull <= 0.0:
		_end("hull breached")


## Power: the drill, the thrusters, the lamp and the weight of what you carry.
## The lamp in DARK mode gives a little back, which is what makes going dark a
## verb rather than a wait.
func _drain(dir: Vector2, dt: float) -> void:
	if dir.length_squared() > 0.001:
		power -= Tuning.POWER_PER_THRUST_S * dt
	power -= Tuning.LAMP_DRAIN[lamp_mode] * dt
	power -= Tuning.POWER_PER_KG_S * load_kg * dt
	power = minf(power, power_capacity())


## Cut whatever the nose is pointed at. Power is charged for the hit points
## actually spent, so hard rock costs more by construction rather than through a
## second curve that could drift out of step with the hardness table.
## **The hardness of the material the hull is actually in or entering**, which is
## what decides how fast the plow may advance.
##
## Sampled at the hull's LEADING FACE and at its centre, hardest of the two, and
## only over cells that still have something in them. That is not a detail: it is
## what conserves the work.
##
## Time spent crossing a cell is one metre over the plow speed, and the plow
## speed is the drill's power over the hardness, so the hit points delivered
## while crossing are exactly the hit points the cell costs. Sample anywhere else
## and that identity breaks. The first version read a cell a whole metre ahead of
## the hull, so the reading fell back to ordinary rock as soon as the ship was
## alongside the hard thing rather than approaching it - and a scripted miner
## drove straight through a planet's CORE without cutting it, ending forty metres
## below with the core sitting at fill 0.39.
func _hardness_under_head(dir: Vector2) -> float:
	var band := Tuning.hardness_at(flight.depth()) * Classes.hardness_mult(world.class_id)
	var d := dir
	if d.length_squared() < 0.001:
		d = flight.heading
	var hardest := 0.0
	for p in [flight.pos, flight.pos + d.normalized() * (Tuning.SHIP_HALF + 0.12)]:
		var x := int(roundf(p.x))
		var dd := int(roundf(p.y))
		if not world.in_bounds(x, dd) or world.fill[world.idx(x, dd)] <= Tuning.OPEN_FILL:
			continue
		var mm: int = world.mat[world.idx(x, dd)]
		# **The same three terms `World.cut` charges**, so the speed the hull
		# advances at and the cost of the cell it is advancing through are one
		# statement. Any difference here is the ship outrunning its own carve.
		var h := Tuning.hardness_at(float(dd)) * Classes.hardness_mult(world.class_id) 			* Ore.hardness_of(mm, world.seam[world.idx(x, dd)] == 1)
		# The core takes six times as long as anything else and it is meant to:
		# the cut is the tell that the extraction is about to start.
		if mm == Ore.CORE:
			h *= 6.0
		hardest = maxf(hardest, h)
	# Nothing solid under the hull: the drill is held while flying down a shaft
	# already cut. The band's own hardness keeps `dig_load` meaningful, and the
	# speed cap is the ship's rather than the rock's.
	return hardest if hardest > 0.0 else band


## **One tick of the plow.** Carve the swept capsule the hull just moved through
## and bank whatever it freed.
##
## The old version took one cell and returned; this takes a path. Everything
## about what a cell is WORTH is still in `World.cut`, reached through
## `World.carve`, so the shape of the dig changed and the yield rules did not.
func _drill(dt: float) -> void:
	var res := world.carve(
		flight.last_pos, flight.pos,
		Tuning.BRUSH_RADIUS, Tuning.BRUSH_FEATHER,
		drill_rate() * dt)
	var spent := float(res["cut"])
	if spent <= 0.0:
		return
	power -= spent * Tuning.POWER_PER_HP
	# The sound answers the WORK, not the button: hit points actually removed,
	# so the deep sounds harder to cut because it is.
	drill_bite.emit(_hardness_under_head(flight.heading))

	if bool(res["core"]):
		_begin_extraction(res["core_cell"])
		return
	if int(res["filament"]) > 0:
		filament += int(res["filament"])
		found_cache.emit(int(res["filament"]))

	for e in (res["cells"] as Array):
		var cell: Dictionary = e
		var kg := float(cell["kg"])
		var value := float(cell["value"])
		broke_cell.emit(int(cell["x"]), int(cell["d"]), int(cell["mat"]), value)
		if kg <= 0.0:
			continue
		# The drill NEVER refuses. A full hold leaves the ore on the ground.
		if load_kg + kg > hold_capacity():
			drops.append({"x": int(cell["x"]), "d": int(cell["d"]),
				"mat": int(cell["mat"]), "kg": kg, "value": value})
		else:
			_stow(int(cell["mat"]), kg, value)


func _stow(m: int, kg: float, value: float) -> void:
	var e: Dictionary = hold.get(m, {"kg": 0.0, "value": 0.0, "count": 0})
	e["kg"] = float(e["kg"]) + kg
	e["value"] = float(e["value"]) + value
	e["count"] = int(e["count"]) + 1
	hold[m] = e
	load_kg += kg
	picked_up.emit(kg, value)


## Pick up anything lying within reach, if there is room for it.
func _collect() -> void:
	var i := drops.size() - 1
	while i >= 0:
		var dr := drops[i]
		var away := Vector2(float(dr["x"]), float(dr["d"])) - flight.pos
		if away.length() < 1.1 and load_kg + float(dr["kg"]) <= hold_capacity():
			_stow(int(dr["mat"]), float(dr["kg"]), float(dr["value"]))
			drops.remove_at(i)
		i -= 1


## Brittle ceilings, on the classes that have them.
##
## The world counts the cracks down and says which fell; deciding what a falling
## rock costs belongs to the ship, so the two stay apart and the world can be
## tested without one.
func _settle(dt: float) -> void:
	var fell := world.settle(dt)
	if fell.is_empty():
		return
	var cell := Vector2i(int(roundf(flight.pos.x)), int(roundf(flight.pos.y)))
	for c in fell:
		collapsed.emit(c.x, c.y)
		# It lands in the cell BELOW the one that cracked, which is where the
		# ship has to be standing to be hit.
		if cell.x == c.x and cell.y == c.y + 1:
			hull -= Classes.BRITTLE_DAMAGE
			hull_hit.emit(Classes.BRITTLE_DAMAGE)


## How long before the nearest cracking ceiling comes down, or a large number if
## nothing near is cracking. The HUD reads this: announce a zone before charging
## for it, and by more than human reaction time.
func crack_warning() -> float:
	return world.nearest_crack(flight.pos)


## The Line. Past it the air is thick enough to be a load on the hull, and the
## drain is a rate the player can read rather than a cliff. Announced a band
## early: a threshold the player cannot see is not a mechanic.
func _pressure(d: float, density: float, dt: float) -> void:
	if d < float(Tuning.LINE_DEPTH) - Tuning.LINE_WARN_M:
		return
	if not _warned_line:
		_warned_line = true
	if d < float(Tuning.LINE_DEPTH):
		return
	var excess: float = density - Tuning.density_at(float(Tuning.LINE_DEPTH))
	if excess > 0.0:
		hull -= Tuning.PRESSURE_RATE * excess * Upgrades.seal_relief(level_of("seal")) * dt


# ── the extraction ────────────────────────────────────────────────────────

## Cutting the core free is the halfway point, not the end.
##
## The clock is derived from the route the player actually has, so a long
## winding descent gets a long climb and a straight shaft gets a short one, and
## neither is a guess. **Never let a hazard take the run**: if there were no way
## out at all the extraction would be unwinnable by construction, so the bound is
## computed here and asserted in `test_sim.gd`.
func _begin_extraction(at: Vector2i) -> void:
	phase = Phase.EXTRACTION
	carrying_core = true
	# The core is a physical object and it is heavy. Room is made for it by
	# dumping what is in the hold, which is the last decision of the descent
	# whether the player makes it deliberately or not.
	while load_kg + Tuning.CORE_KG > Tuning.HOLD_KG and not hold.is_empty():
		var worst := -1
		var worst_value := 1.0e18
		for m in hold.keys():
			var per_kg: float = float(hold[m]["value"]) / maxf(float(hold[m]["kg"]), 0.001)
			if per_kg < worst_value:
				worst_value = per_kg
				worst = int(m)
		load_kg -= float(hold[worst]["kg"])
		hold.erase(worst)
	load_kg += Tuning.CORE_KG

	var cell := Vector2i(int(roundf(flight.pos.x)), int(roundf(flight.pos.y)))
	var route := world.route_out(cell.x, cell.y)
	extract_total = Tuning.extraction_seconds(route, load_kg)
	extract_left = extract_total
	rising = float(Tuning.CORE_DEPTH) + 4.0
	core_cut.emit(extract_total)


## The world dying, from the bottom up. Everything below `rising` is gone; when
## it reaches the ship the descent is over and the planet is spent.
func _extract(dt: float) -> void:
	extract_left -= dt
	var frac: float = 1.0 - clampf(extract_left / maxf(extract_total, 0.001), 0.0, 1.0)
	# It climbs the whole way in the time allowed, so the clock and the thing the
	# player can SEE are the same quantity rather than two that must agree.
	rising = lerpf(float(Tuning.CORE_DEPTH) + 4.0, -2.0, frac)

	if flight.depth() <= 0.0:
		_escape()
		return
	if flight.depth() >= rising:
		_end("taken by the collapse")


## Out, with the core. The only way a planet is finished.
func _escape() -> void:
	phase = Phase.OVER
	outcome = "escaped with the core"
	cores += 1
	carrying_core = false
	credits += hold_value()
	hold = {}
	load_kg = 0.0
	descent_over.emit(outcome)


## How far up the world has died, as a fraction, for the HUD and the renderer.
func extract_frac() -> float:
	if phase != Phase.EXTRACTION or extract_total <= 0.0:
		return 0.0
	return 1.0 - clampf(extract_left / extract_total, 0.0, 1.0)


## Hull loss a second at this depth, right now. A number beats a bar when the
## player needs causation, so the HUD shows this beside the gauge whenever it
## is non-zero.
func pressure_rate() -> float:
	var d := flight.depth()
	if d < float(Tuning.LINE_DEPTH):
		return 0.0
	var excess: float = Tuning.density_at(d) - Tuning.density_at(float(Tuning.LINE_DEPTH))
	return maxf(Tuning.PRESSURE_RATE * excess * Upgrades.seal_relief(level_of("seal")), 0.0)


# ── selling, without a journey ────────────────────────────────────────────

func uplink_cost() -> float:
	return Tuning.uplink_cost(flight.depth(), load_kg)


func can_uplink() -> bool:
	return phase == Phase.DESCENT and load_kg > 0.0 and power > uplink_cost()


## Fire the hold up the shaft. This is the whole of "selling", and it happens
## where you are standing.
func uplink() -> float:
	if not can_uplink():
		return 0.0
	var cost := uplink_cost()
	var value := hold_value()
	power -= cost
	credits += value
	hold = {}
	load_kg = 0.0
	uplinked.emit(value, cost)
	return value


func hold_value() -> float:
	var v := 0.0
	for m in hold.keys():
		v += float(hold[m]["value"])
	return v


# ── ending a descent ──────────────────────────────────────────────────────

## Running out never takes the run. You keep everything already uplinked, you
## lose what is in the hold, and every tunnel stays open for the next descent.
## His own Coreward design, and it was right.
func _end(why: String) -> void:
	phase = Phase.OVER
	outcome = why
	var lost := hold_value()
	credits += lost * (1.0 - Tuning.RECOVERY_CUT)
	hold = {}
	load_kg = 0.0
	# Failing the extraction costs the core and the planet, and never the save.
	# Another world of this class comes round on the chart, so a mistake is a
	# detour rather than a dead run: a permanently unwinnable save is the one
	# outcome this must not have.
	carrying_core = false
	power = 0.0 if why == "out of power" else power
	descent_over.emit(why)


# ── what the shell reads ──────────────────────────────────────────────────

func power_frac() -> float:
	return clampf(power / power_capacity(), 0.0, 1.0)


func hull_frac() -> float:
	return clampf(hull / Tuning.HULL_MAX, 0.0, 1.0)


func load_frac() -> float:
	return clampf(load_kg / hold_capacity(), 0.0, 1.0)


## How far the lamp reaches right now, which is the reach for its mode faded
## down by how little power is left. Being in trouble looks like the world
## closing in rather than like a number turning red.
func cycle_lamp() -> void:
	lamp_mode = (lamp_mode + 1) % 3


## The manifest: count, weight and value per mineral, sorted by what it is
## worth, so the player can compare two ores on screen.
func manifest() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for m in hold.keys():
		rows.append({
			"mat": m,
			"name": Ore.name_of(m),
			"count": int(hold[m]["count"]),
			"kg": float(hold[m]["kg"]),
			"value": float(hold[m]["value"]),
		})
	rows.sort_custom(func(a, b): return float(a["value"]) > float(b["value"]))
	return rows


## A compact snapshot for the golden test. Every field is something the player
## can see, so a change here is a change they would notice.
func snapshot() -> Dictionary:
	return {
		"t": snappedf(time, 0.001),
		"x": snappedf(flight.pos.x, 0.001),
		"depth": snappedf(flight.pos.y, 0.001),
		"vx": snappedf(flight.vel.x, 0.001),
		"vy": snappedf(flight.vel.y, 0.001),
		"power": snappedf(power, 0.001),
		"hull": snappedf(hull, 0.001),
		"load": snappedf(load_kg, 0.001),
		"credits": snappedf(credits, 0.001),
		"filament": filament,
		"drops": drops.size(),
		"deepest": snappedf(deepest, 0.001),
		"phase": phase,
		"rising": snappedf(rising, 0.001),
		"cores": cores,
	}
