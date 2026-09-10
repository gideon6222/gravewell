class_name Flight
extends RefCounted

## How the ship moves, and what stops it.
##
## Pure: no Node, no Viewport, no input event, no real frame. `step()` takes a
## direction and a delta and nothing else, which is what lets a whole descent
## replay identically in a headless test.
##
## Coordinates are metres. `pos.x` is across the shaft, `pos.y` is DEPTH,
## positive downward, and an integer coordinate is the centre of a cell. Depth
## and cell row are therefore the same number everywhere in the game.
##
## ## What Coreward got wrong here, and what this does instead
##
## "The ship looks very bouncy when you change direction or stop" was three
## faults stacked. The lane pull was `+=` onto an existing velocity, which is an
## undamped spring. It ran while COASTING, where the nearest lane is as often
## behind the ship as ahead, so releasing near a boundary dragged the ship
## backwards against its own momentum. And the drill alignment wrote position
## directly, which is invisible to collision, so it drove the ship into the rock
## it was cutting and the coast pull ejected it back out after every block.
##
## So, here: the pull is **assigned**, it runs **only while a cardinal direction
## is held**, and every correction goes through the normal collision path as a
## velocity. `test_fly.gd` asserts all three by construction.

var world: World
var pos := Vector2.ZERO
var vel := Vector2.ZERO

## The direction the drill points, kept from the last held input so the ship
## faces what it is cutting. His ask, verbatim: "The ship should turn to face
## the direction it is digging in."
var heading := Vector2(0, 1)

## Set by `Sim` from the thrust ladder, so an upgrade the player bought is felt
## in the hand rather than being a number in a shop.
var speed_mult := 1.0

var touching := false            ## the box is against rock this frame
var impact_speed := 0.0          ## speed lost to a collision this frame, for damage


func _init(w: World) -> void:
	world = w
	pos = Vector2(0.0, -1.5)


## One step. `dir` is the d-pad, each component in [-1, 1]; `load_kg` sets the
## top speed and the inertia; `density` is the air, which drags.
func step(dir: Vector2, load_kg: float, density: float, dt: float) -> void:
	impact_speed = 0.0
	var held := dir.length_squared() > 0.001

	var top := Tuning.speed_for(load_kg) * speed_mult
	if held:
		var target := dir.normalized() * top
		var k := SimUtil.smooth(Tuning.THRUST_RATE, dt)
		vel = vel.lerp(target, k)
		heading = dir.normalized()
	else:
		# Coasting. Nothing is corrected here, ever. CRAFT.md: never correct
		# anything while the player is coasting; snap on the next input.
		var k := SimUtil.smooth(Tuning.COAST_RATE, dt)
		vel = vel.lerp(Vector2.ZERO, k)

	# Air drag. The same density that thickens the fog makes the deep heavy to
	# fly in, from one number, so the picture and the handling agree.
	var drag: float = clampf(Tuning.AIR_DRAG * density * dt, 0.0, 0.9)
	vel *= (1.0 - drag)

	if held:
		_lane_pull(dir)

	_move(dt)


## Pull onto the centre line of the axis the ship is NOT travelling along, so a
## held cardinal direction squares the ship up to the grid without ever
## fighting the direction the player asked for. A diagonal is deliberate and is
## left alone.
##
## Assigned, never added. Adding is the undamped spring that rings.
func _lane_pull(dir: Vector2) -> void:
	if absf(dir.x) > 0.01 and absf(dir.y) > 0.01:
		return                                     ## a diagonal is deliberate
	if absf(dir.x) < 0.01:
		var off := roundf(pos.x) - pos.x
		vel.x = 0.0 if absf(off) < Tuning.LANE_DEADZONE else off * Tuning.LANE_RATE
	else:
		var offd := roundf(pos.y) - pos.y
		vel.y = 0.0 if absf(offd) < Tuning.LANE_DEADZONE else offd * Tuning.LANE_RATE


## Move one axis at a time and resolve against the grid. Axis at a time is what
## lets the ship slide along a wall instead of stopping dead on it, and it is
## why a diagonal into a corner does not wedge.
func _move(dt: float) -> void:
	touching = false
	var before := vel
	_axis(0, vel.x * dt)
	_axis(1, vel.y * dt)
	if touching:
		impact_speed = (before - vel).length()


func _axis(axis: int, delta: float) -> void:
	if absf(delta) < 1e-9:
		return
	var want := pos
	want[axis] += delta
	if not _blocked(want):
		pos = want
		return

	# Blocked. Walk back to the closest legal position on this axis so the hull
	# rests against the face rather than stopping a fraction short of it, then
	# kill the velocity on this axis only.
	var lo := 0.0
	var hi := delta
	for _i in range(12):
		var mid := (lo + hi) * 0.5
		var probe := pos
		probe[axis] += mid
		if _blocked(probe):
			hi = mid
		else:
			lo = mid
	pos[axis] += lo
	vel[axis] = 0.0
	touching = true


## Does the hull box at `p` overlap any cell the world calls solid?
func _blocked(p: Vector2) -> bool:
	var h := Tuning.SHIP_HALF
	var x0 := int(floor(p.x - h + 0.5))
	var x1 := int(floor(p.x + h + 0.5))
	var d0 := int(floor(p.y - h + 0.5))
	var d1 := int(floor(p.y + h + 0.5))
	for d in range(d0, d1 + 1):
		for x in range(x0, x1 + 1):
			if not world.is_open(x, d):
				return true
	return false


## Where the drill tip is, for drawing the beam and pointing the hull.
func nose_point() -> Vector2:
	return pos + heading * (Tuning.SHIP_HALF + Tuning.DRILL_REACH)


## **The cell the drill bites is the one that is stopping the ship**, not the
## one geometrically under the nose.
##
## Those are the same cell for a cardinal hold and very different for a
## diagonal. A diagonal nose points at the corner cell, which the hull can
## never fit through even when it is gone, because the two orthogonal
## neighbours either side of it are still there. The ship then saws at a gap of
## zero width forever: measured, a scripted miner held down-right and stayed at
## 1.12 m for six hundred frames, cutting and never moving.
##
## Biting the nearest solid cell that the hull is actually moving into carves a
## passable staircase on a diagonal and behaves exactly as before on a
## cardinal, which is the whole of the fix.
func drill_target(dir: Vector2) -> Vector2i:
	if dir.length_squared() < 0.001:
		return Vector2i(-99999, -99999)
	var d := dir.normalized()
	var want := pos + d * (Tuning.SHIP_HALF + Tuning.DRILL_REACH)
	var h := Tuning.SHIP_HALF
	var best := Vector2i(-99999, -99999)
	var best_dist := 1.0e9
	for dd in range(int(floor(want.y - h + 0.5)), int(floor(want.y + h + 0.5)) + 1):
		for xx in range(int(floor(want.x - h + 0.5)), int(floor(want.x + h + 0.5)) + 1):
			if world.is_open(xx, dd):
				continue
			var away := Vector2(float(xx), float(dd)) - pos
			if away.dot(d) <= 0.0:
				continue                      ## never cut backwards
			var dist := away.length()
			if dist < best_dist:
				best_dist = dist
				best = Vector2i(xx, dd)
	return best


## True when there is nothing left to cut in the held direction.
static func no_target(c: Vector2i) -> bool:
	return c.x == -99999


func depth() -> float:
	return pos.y
