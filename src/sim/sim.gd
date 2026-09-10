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

enum Phase { DESCENT, EXTRACTION, OVER }

## Persistent across descents and planets. Credits are mined; filament is only
## ever FOUND, and it is the only thing that buys a counter to a threat.
var credits: float = 0.0
var filament: int = 0
var cores: int = 0

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

var _warned_line := false


func _init(seed_value: int = 1, world_class: int = 0) -> void:
	world = World.new(seed_value, world_class)
	flight = Flight.new(world)


## Start another descent on the SAME planet. The world, and therefore every
## tunnel already cut, is kept.
func redescend() -> void:
	flight = Flight.new(world)
	phase = Phase.DESCENT
	outcome = ""
	power = Tuning.POWER_MAX
	hull = Tuning.HULL_MAX
	hold = {}
	load_kg = 0.0
	_warned_line = false
	descents += 1


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

	# Is the drill engaged on the face the hull is against? If it is, the
	# collision is the drill doing its job and it costs nothing. If it is not,
	# the ship hit rock it was not cutting and that is what hurts.
	var held := dir.length_squared() > 0.001
	var target := flight.drill_target(dir)
	var drill_engaged := drilling and held and not Flight.no_target(target)

	flight.step(dir, load_kg, density, dt)

	if flight.impact_speed > Tuning.IMPACT_FREE_SPEED and not drill_engaged:
		hull -= (flight.impact_speed - Tuning.IMPACT_FREE_SPEED) * Tuning.IMPACT_DAMAGE
		hull_hit.emit(flight.impact_speed)

	_drain(dir, dt)
	if drilling and held:
		_drill(target, dt)
	_pressure(d, density, dt)
	_collect()

	deepest = maxf(deepest, flight.depth())
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
	power = minf(power, Tuning.POWER_MAX)


## Cut whatever the nose is pointed at. Power is charged for the hit points
## actually spent, so hard rock costs more by construction rather than through a
## second curve that could drift out of step with the hardness table.
func _drill(c: Vector2i, dt: float) -> void:
	if Flight.no_target(c) or world.is_open(c.x, c.y):
		return
	var res := world.cut(c.x, c.y, Tuning.DRILL_RATE * dt)
	if res["cut"] <= 0.0:
		return
	power -= float(res["cut"]) * Tuning.POWER_PER_HP
	if not res["broke"]:
		return

	if bool(res["core"]):
		phase = Phase.EXTRACTION
		return
	if int(res["filament"]) > 0:
		filament += int(res["filament"])
		found_cache.emit(int(res["filament"]))
		return

	var kg := float(res["kg"])
	var value := float(res["value"])
	broke_cell.emit(c.x, c.y, int(res["mat"]), value)
	if kg <= 0.0:
		return
	# The drill NEVER refuses. A full hold leaves the ore on the ground.
	if load_kg + kg > Tuning.HOLD_KG:
		drops.append({"x": c.x, "d": c.y, "mat": int(res["mat"]), "kg": kg, "value": value})
	else:
		_stow(int(res["mat"]), kg, value)


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
		if away.length() < 1.1 and load_kg + float(dr["kg"]) <= Tuning.HOLD_KG:
			_stow(int(dr["mat"]), float(dr["kg"]), float(dr["value"]))
			drops.remove_at(i)
		i -= 1


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
		hull -= Tuning.PRESSURE_RATE * excess * dt


## Hull loss a second at this depth, right now. A number beats a bar when the
## player needs causation, so the HUD shows this beside the gauge whenever it
## is non-zero.
func pressure_rate() -> float:
	var d := flight.depth()
	if d < float(Tuning.LINE_DEPTH):
		return 0.0
	var excess: float = Tuning.density_at(d) - Tuning.density_at(float(Tuning.LINE_DEPTH))
	return maxf(Tuning.PRESSURE_RATE * excess, 0.0)


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
	power = 0.0 if why == "out of power" else power
	descent_over.emit(why)


# ── what the shell reads ──────────────────────────────────────────────────

func power_frac() -> float:
	return clampf(power / Tuning.POWER_MAX, 0.0, 1.0)


func hull_frac() -> float:
	return clampf(hull / Tuning.HULL_MAX, 0.0, 1.0)


func load_frac() -> float:
	return clampf(load_kg / Tuning.HOLD_KG, 0.0, 1.0)


## How far the lamp reaches right now, which is the reach for its mode faded
## down by how little power is left. Being in trouble looks like the world
## closing in rather than like a number turning red.
func lamp_reach() -> float:
	return Tuning.lamp_reach(lamp_mode, power_frac())


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
	}
