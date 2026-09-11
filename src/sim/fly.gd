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

## **Is the ship in Drown's water?** Set by `Sim` before the step, like
## `plow_speed`. Water drags far harder than any air and pushes the hull upward,
## so down becomes the expensive direction and the motion of the whole game is
## inverted for one world.
var in_water := false

## Where the escape samples the material, as offsets from the hull's centre.
##
## **Inset in X, out to the edge in Y**, and the asymmetry is the whole point. A
## tunnel is a metre wide and the hull is 0.76, so a sample at the box's left or
## right edge reads the wall beside the ship and swamps everything else: climbing
## out of the core chamber measured as burrowing in, and a ship carrying the core
## sat still while the collapse took it. There is no such wall above or below, and
## Y has to reach the box's edge or the measure cannot see the FLOOR the plow has
## pushed the hull into - which is the other way this got stuck.
const ESCAPE_X := 0.30
const ESCAPE_Y := 0.36

## How much material can be under the hull before the ship counts as BURIED and
## the escape is refused outright. Plowing sits around 0.36 of a full cell and
## solid rock is 1.0, so this is the line between "backing out of my own tunnel"
## and "swimming through the planet".
const ESCAPE_BURIED := 0.55

## How much material under the hull counts as "in the cut" rather than in open
## air, for the speed limit above.
const IN_MATERIAL := 0.05


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
	if in_water:
		# Water instead of air, not on top of it: a submerged ship is not flying
		# through thick fog, it is swimming.
		drag = clampf(Tuning.WATER_DRAG * dt, 0.0, 0.9)
	vel *= (1.0 - drag)
	if in_water:
		# Buoyancy, applied as an acceleration so the drag above decides the
		# terminal rise rather than a speed being assigned here.
		vel.y -= Tuning.WATER_BUOYANCY * dt

	if held:
		_lane_pull(dir)

	# **You cannot fly faster than you can cut, while you are in the cut.**
	#
	# Collision is against the DRAWN surface, so a cell is passable once it is
	# half gone - which is right, because that is where the wall is. But it also
	# means the rock stops blocking the hull long before the metre is finished,
	# and the ordinary velocity then carries the ship through at flying speed:
	# measured, it drove straight through a planet's core at seven metres a second
	# and the extraction never started.
	#
	# So while the drill is engaged and the hull is in material, the plow's rate
	# is the speed limit whatever the collision says. Out in open air the load is
	# zero and nothing here fires.
	if plow_speed > 0.0 and _load_under(pos) > IN_MATERIAL:
		var speed := vel.length()
		if speed > plow_speed:
			vel = vel * (plow_speed / speed)

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

	# **Brushing slivers? Then push through them.**
	#
	# Plowing leaves the hull inside material it is still cutting, and the round
	# brush cannot finish the corners of a square metre, so a ship that stops
	# drilling is routinely touching a few quarter-metre slivers it never
	# completed. The ordinary resolve has nothing to push against when the START
	# position is illegal, so it refuses every direction and wedges the ship in
	# its own tunnel.
	#
	# Two bounds, and three earlier versions of this each failed on one of them:
	#
	# **Only while the drill is off.** Letting velocity through as well let a
	# miner cover 37 m in ten seconds with the shaft still standing behind it.
	#
	# **Only while LIGHTLY embedded.** A hull mostly inside rock is buried, not
	# brushing something, and letting that move is a way through the planet. The
	# box covers about sixteen fine cells, so a third of them is the line.
	#
	# The measure is the fine overlap COUNT and not the interpolated fill it was
	# for one round: sampling the field at the hull's corners in a one-metre shaft
	# reads the walls either side, so climbing OUT measured as going deeper in and
	# a ship carrying the core sat still while the collapse took it.
	if plow_speed <= 0.0:
		var here := _overlap(pos)
		var load := _load_under(pos)
		# **Not strictly less, because the thing blocking can be smaller than the
		# measure can see.** Two quarter-metre slivers left in the corners of the
		# hull box move the overlap without moving a nine-point average at all,
		# and a strict test then refuses every direction: a ship carrying the core
		# sat still at 197 m while the collapse took it, with a load of 0.0123
		# either way. The buried check is what keeps "no worse" from becoming a
		# way through solid rock, where the load is 1.0 and this never fires.
		if here > 0 and load < ESCAPE_BURIED 				and _overlap(want) <= here and _load_under(want) <= load + 1.0e-6:
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


## **How many QUARTER-metre cells the hull box overlaps that still hold rock.**
##
## Collision reads the fine field directly, because "can the ship fit" is a
## question at the scale of the ship and the ship is three quarters of a metre.
## Asking it per metre was what made the hull stop dead against a metre it had
## already taken to 94%, with a clear path through the middle of it.
##
## The metre-scale `World.is_open` answers a different question - has this metre
## been worked out, for the light and the yields - and the two are allowed to
## disagree about a metre with slivers left in it. The ship squeezes past them
## and they are still drawn, because both come from the same fine field.
func _overlap(p: Vector2) -> int:
	var h := Tuning.SHIP_HALF
	var x0 := int(floor(World.fine_index(p.x - h) + 0.5))
	var x1 := int(floor(World.fine_index(p.x + h) + 0.5))
	var d0 := int(floor(World.fine_index(p.y - h) + 0.5))
	var d1 := int(floor(World.fine_index(p.y + h) + 0.5))
	var n := 0
	for d in range(d0, d1 + 1):
		for x in range(x0, x1 + 1):
			if not world.is_clear(x, d):
				n += 1
	return n


## **How much material is under the hull**, as a continuous number.
##
## A nine-point average of the fine field across the box, sampled bilinearly, so
## it moves on every millimetre the ship does. That is the whole requirement:
## three earlier versions of this measure each had a flat spot, and a measure
## that does not move is a ship that does not move.
##
##   - an overlap COUNT of whole metres was flat across most of a metre
##   - an overlap AREA was flat too, because the hull is smaller than a metre
##   - a count of FINE cells is flat between quarter-metre steps
##   - five points including the hull's CORNERS read the walls of a one-metre
##     shaft, so climbing out of the core chamber measured as burrowing in
##
## Deep inside solid rock every sample reads 1.0 whichever way the ship goes, so
## this never becomes a way through the planet: strictly less, or no move.
func _load_under(p: Vector2) -> float:
	var total := 0.0
	for j in [-ESCAPE_Y, 0.0, ESCAPE_Y]:
		for i in [-ESCAPE_X, 0.0, ESCAPE_X]:
			total += world.fill_between(p + Vector2(i, j))
	return total / 9.0


## Where the drill tip is, for drawing the beam and pointing the hull.
func nose_point() -> Vector2:
	return pos + heading * (Tuning.SHIP_HALF + Tuning.DRILL_REACH)


func depth() -> float:
	return pos.y
