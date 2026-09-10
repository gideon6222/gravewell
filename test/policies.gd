class_name Policies
extends RefCounted

## Scripted players.
##
## These are not test fixtures. They are **the definition of "playing well"** -
## the thing every balance number in the game is measured against - and that is
## why they live in the repo rather than in a session.
##
## **Write one policy per way of failing**, and every policy must fail for a
## DIFFERENT reason. When two of them score the same, one is not testing
## anything. If the one that reads the world ever loses to the one that ignores
## it, the bot is wrong before the game is: fix the bot before touching a single
## constant, or a whole balance pass gets built on a measurement of the wrong
## thing.
##
## **The pair that proves a decision exists must differ in exactly one thing.**
## `CAUTIOUS` and `GREEDY` share every line and one number, the depth each is
## willing to go to, so the gap between their scores is a claim about the GAME
## and not about how well the two of them drive.
##
## And drive them through the same seam a thumb uses: `Sim.step(dir, drilling,
## dt)`. A helper that computes its own outcome is a second, usually worse
## player.

## Touches nothing. Proves that doing nothing loses - the wear clock in
## `_drain` means even an idle ship is spending, so PASSIVE must end with
## nothing banked. If this ever scores, the game has no stakes.
const PASSIVE := "passive"

## Dives straight down as fast as it can and never turns aside for ore. Reaches
## depth, banks almost nothing. The control for "is depth on its own worth
## anything".
const DIVER := "diver"

## Cuts down, turns aside for ore it can see, and uplinks whenever the hold is
## more than three quarters full. Stops at CAUTIOUS_DEPTH.
const CAUTIOUS := "cautious"

## The same player with one number changed: it keeps going past the Line. It
## should earn more and it should end its descent badly far more often. The
## claim under test is "the reckless option never actually works", not "the safe
## option scores higher".
const GREEDY := "greedy"

## Reaction time, a misread about one time in six, and a hand that wobbles.
## Tune the game so this one struggles, never the bot so the game looks hard.
const HUMAN := "human"

const ALL: Array[String] = [PASSIVE, DIVER, CAUTIOUS, GREEDY, HUMAN]

const CAUTIOUS_DEPTH := 62.0
const GREEDY_DEPTH := 148.0

var _rng: SimRng
var _react := 0.0
var _held := Vector2.ZERO


func _init(seed_value: int = 7) -> void:
	_rng = SimRng.new(seed_value)


## What the policy would press this frame. Returns {dir, drilling, uplink}.
func act(name: String, sim: Sim, dt: float) -> Dictionary:
	match name:
		PASSIVE:
			return {"dir": Vector2.ZERO, "drilling": false, "uplink": false}
		DIVER:
			return {"dir": Vector2(0, 1), "drilling": true, "uplink": false}
		CAUTIOUS:
			return _mine(sim, CAUTIOUS_DEPTH, false, dt)
		GREEDY:
			return _mine(sim, GREEDY_DEPTH, false, dt)
		HUMAN:
			return _mine(sim, CAUTIOUS_DEPTH, true, dt)
	return {"dir": Vector2.ZERO, "drilling": false, "uplink": false}


## The one body CAUTIOUS, GREEDY and HUMAN all share. `limit` is the only thing
## that separates the first two, which is what makes the gap between them a
## measurement of the game.
func _mine(sim: Sim, limit: float, human: bool, dt: float) -> Dictionary:
	if sim.load_kg >= Tuning.HOLD_KG * 0.75 and sim.can_uplink():
		return {"dir": Vector2.ZERO, "drilling": false, "uplink": true}

	var here := sim.flight.pos
	var dir := Vector2(0, 1)

	if here.y >= limit:
		# At its limit it works sideways rather than deeper, which is what a
		# player who has decided not to push does.
		dir = Vector2(1, 0) if int(here.y) % 2 == 0 else Vector2(-1, 0)
	else:
		var best := _best_ore_dir(sim, int(roundf(here.x)), int(roundf(here.y)))
		if best != Vector2.ZERO:
			dir = best

	if human:
		# Reaction time: hold the last input for a beat before switching.
		_react -= dt
		if _react > 0.0:
			dir = _held
		else:
			_react = 0.3
			if _rng.next() < 0.167:
				dir = Vector2(1, 0) if _rng.next() < 0.5 else Vector2(-1, 0)
			_held = dir

	return {"dir": dir, "drilling": true, "uplink": false}


## Look one cell around for something worth more than plain rock. Deliberately
## short-sighted: a bot with perfect knowledge of the whole grid is not a claim
## about a player who can only see as far as the lamp.
##
## **Cardinal directions only.** A diagonal is free flight rather than a dig: it
## skips the lane pull on purpose, so the ship slides and the drill nibbles a
## different cell every few frames and finishes none of them. A bot that digs
## diagonally measures the wrong thing, and a thumb on a d-pad digs cardinally.
func _best_ore_dir(sim: Sim, x: int, d: int) -> Vector2:
	var best_v := 0.0
	var best := Vector2.ZERO
	for off in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var m := sim.world.material_at(x + off.x, d + off.y)
		if m == Ore.AIR:
			continue
		var y := Ore.yield_of(m, sim.world.is_seam(x + off.x, d + off.y))
		var v := float(y["value"])
		if m == Ore.CACHE:
			v = 99.0                      ## a cache is worth any detour
		if v > best_v:
			best_v = v
			best = Vector2(float(off.x), float(off.y))
	return best if best_v > Tuning.SLAG_KG * Tuning.SLAG_VALUE * 1.2 else Vector2.ZERO


## Play a whole descent and report what the player would have to show for it.
## Fixed timestep, because a policy is only a measurement if it replays.
static func run(name: String, seed_value: int, seconds: float, dt: float = 1.0 / 60.0) -> Dictionary:
	var sim := Sim.new(seed_value)
	var p := Policies.new(seed_value)
	var steps := int(seconds / dt)
	for _i in range(steps):
		if sim.phase == Sim.Phase.OVER:
			break
		var a := p.act(name, sim, dt)
		if bool(a["uplink"]):
			sim.uplink()
			continue
		sim.step(a["dir"], bool(a["drilling"]), dt)
	return {
		"policy": name,
		"credits": sim.credits,
		"filament": sim.filament,
		"deepest": sim.deepest,
		"outcome": sim.outcome,
		"phase": sim.phase,
		"time": sim.time,
	}
