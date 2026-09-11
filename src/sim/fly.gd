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

## **How fast the drill is allowed to push the hull INTO rock this tick.**
##
## Set by `Sim` from the material under the head, zero when the player is not
## drilling. This is the whole of the plow: while it is positive the rock does
## not stop the ship, it only decides how fast the ship gets through it.
##
## Free flight is untouched. A ship coasting into a wall it is not cutting still
## hits it, still loses the axis, and still takes the hull damage - which is what
## keeps a mistake a mistake.
var plow_speed := 0.0

## Where the hull was at the start of the tick, so `Sim` can sweep the brush
## along the path actually travelled rather than stamping it at a point.
var last_pos := Vector2.ZERO


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
	last_pos = pos
	var before := vel
	_axis(0, vel.x * dt)
	_axis(1, vel.y * dt)
	if touching:
		impact_speed = (before - vel).length()

	# **The plow, and it runs AFTER the ordinary resolve.**
	#
	# Free motion through open space happens first and is unchanged, so flying
	# down a shaft you already cut feels exactly as it did. Only what the rock
	# refused is then pushed through, at the speed the material allows. Doing it
	# the other way round - a special case inside `_axis` - would have put a
	# branch on the hot path of every collision in the game for a case that is
	# only ever the drill.
	if plow_speed > 0.0 and heading.length_squared() > 0.001:
		var want := pos + heading.normalized() * plow_speed * dt
		if _blocked(want):
			# Into rock. The carve that follows in `Sim` clears the hull's own
			# footprint, so ending the tick inside partly-dug material is the
			# point rather than a fault.
			pos = want
			touching = true
			# NOT an impact. The drill is doing its job; being charged hull for
			# cutting was the first bug this game ever shipped.
			impact_speed = 0.0


func _axis(axis: int, delta: float) -> void:
	if absf(delta) < 1e-9:
		return
	var want := pos
	want[axis] += delta
	if not _blocked(want):
		pos = want
		return

	# **Already embedded? Then a move that gets you OUT is allowed.**
	#
	# Plowing means the hull ends its tick inside material the drill is still
	# chewing: that is the mechanic, not a fault. But the ordinary resolve has
	# nothing to push back against when the START position is illegal too, so it
	# refuses every direction and the ship is wedged in its own tunnel the moment
	# the player lets go of the drill. Measured: it could not climb a shaft it had
	# just cut.
	#
	# Two things keep this from being a way through rock, and the first version
	# of it was neither:
	#
	# **Only while the drill is off.** While plowing, the plow is the only thing
	# that moves the hull into rock, at the speed the material allows. Letting
	# velocity through as well let a scripted miner cover 37 m in ten seconds and
	# leave the whole shaft standing behind it, unpaid for.
	#
	# **Strictly out, on a CONTINUOUS measure.** An overlap count is flat across
	# most of a cell, so "no deeper" reads as "sideways is free". Summing the
	# remaining fill under the hull moves on every millimetre, so `<` is a real
	# constraint and it still cannot stall.
	if plow_speed <= 0.0:
		var here := _penetration(pos)
		if here > 0.0 and _penetration(want) < here:
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
	return _overlap(p) > 0


## Does the hull box at `p` overlap any cell the world calls solid?
func _overlap(p: Vector2) -> int:
	var h := Tuning.SHIP_HALF
	var x0 := int(floor(p.x - h + 0.5))
	var x1 := int(floor(p.x + h + 0.5))
	var d0 := int(floor(p.y - h + 0.5))
	var d1 := int(floor(p.y + h + 0.5))
	var n := 0
	for d in range(d0, d1 + 1):
		for x in range(x0, x1 + 1):
			if not world.is_open(x, d):
				n += 1
	return n


## **How much unbroken rock is under the hull box at `p`, as a continuous
## quantity.** Remaining fill weighted by how much of each cell the box covers.
##
## `_blocked` is the same question asked as a yes or no, and that is the right
## question for "can I move here". This one answers "am I getting OUT", which is
## a different question and needs an answer that changes on every millimetre: a
## count of overlapped cells is flat across most of a cell, so a ship escaping on
## it reads sideways motion as free.
func _penetration(p: Vector2) -> float:
	# Sampled BETWEEN cells, at the hull's corners and its middle. An overlap
	# area was the first version and it has a flat spot exactly where it matters:
	# the hull is 0.76 m and a cell is 1.0 m, so a hull entirely inside one cell
	# covers the same area wherever it sits in it, the measure does not move, and
	# the ship stops dead half a cell from open air. Measured: it escaped 0.2 m
	# and then sat there with its velocity zeroed for two seconds.
	var h := Tuning.SHIP_HALF
	return world.fill_between(p) \
		+ world.fill_between(p + Vector2(-h, -h)) \
		+ world.fill_between(p + Vector2(h, -h)) \
		+ world.fill_between(p + Vector2(-h, h)) \
		+ world.fill_between(p + Vector2(h, h))


## Where the drill tip is, for drawing the beam and pointing the hull.
func nose_point() -> Vector2:
	return pos + heading * (Tuning.SHIP_HALF + Tuning.DRILL_REACH)


func depth() -> float:
	return pos.y
