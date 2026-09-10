class_name Light
extends RefCounted

## The lamp: light that travels through the tunnels you cut, and stops at rock.
##
## Pure. World in, two small fields out. No Node, no texture, no shader. The
## renderer uploads what this solves and evaluates the smooth half per pixel.
##
## `techniques/coreward-propagated-lighting.md` in the shared notes is the
## write-up, and every artefact it lists is a thing not to rediscover. His ask,
## in his own words: "I want the light look like it actually spreading from the
## ship. When a tunnel is dug down or to the side, light should fill those
## tunnels and spread to nearby rocks, but areas that are multiple rocks deep
## should be very dark. light should come from the actual ship so if it hits a
## corner or branch, it should cast a shadow down that tunnel."
##
## ## Two solvers, because they answer two different questions
##
## **The flood** answers "can light get here at all, and how far did it have to
## go round". That is a property of the geometry, so it is a Dijkstra over open
## cells and it runs only when the ship changes cell or the terrain changes
## shape.
##
## **The fan** answers "is this point in the shadow of a corner". That is a
## question about straight lines from a point, so it is a fan of rays by grid
## DDA, and it runs every frame, because the whole point is that the shadow
## moves as the ship does.
##
## ## Two lights, not one
##
##     SURFACE = flood * falloff * beam
##     AIR     = flood * falloff * beam * shadow
##
## A surface is lit by being NEAR a lit space, which is a property of the
## surface. The air in a corridor is lit by light travelling along it, which a
## corner can block. Coreward ran one number and handed it to both, so the ray
## fan carved hard-edged wedges across every rock face in the frame, and three
## rounds of playtest notes about it were all read as tuning requests. Combine
## the two with `max()`, never by multiplying two floors: multiplying "how much
## survives behind the player" by "how much survives in shadow" lands anywhere
## that is both on the product, which is black, and that erases the shaft the
## player came down - the way home.

## How much a cell's light is attenuated per extra metre the light had to
## travel compared with a clear run. This is the ONLY thing that darkens
## anything: open ground solves to exactly 1.
const DETOUR_ATT := 0.55

## Half the width of the solved window, in cells. Covers the visible frame at
## the widest lamp with room to spare, so a camera pull-back cannot walk off the
## edge of the field.
const R := 24
const SIDE := R * 2 + 1

## Rays in the shadow fan. A few hundred is what Coreward used; the cost is a
## few thousand grid steps and it did not show up in a measurement.
const RAYS := 256

## Octile geometry: eight-way steps, so a diagonal costs sqrt(2). Subtracting
## EUCLIDEAN distance instead of octile puts a permanent haze over open ground,
## because eight-way steps do not add up to a straight line.
const DIAG := 1.41421356


## The solved visibility field, `SIDE * SIDE` floats in [0, 1], row-major from
## (origin - R) to (origin + R).
##
## Per cell it holds `exp(-att * (pathLength - octileDistance))`: how much
## LONGER the light's real path was than a clear run would have been. Open space
## therefore comes out at exactly 1 and only geometry can darken anything.
##
## **Distance falloff is deliberately not in here.** The grid cannot move
## smoothly and the ship can, so the smooth half belongs in the shader,
## evaluated per pixel from the ship's exact position. Leave it in the grid and
## the pool of light steps a whole metre at a time as the ship flies.
static func flood(world: World, ox: int, od: int) -> PackedFloat32Array:
	# **The attenuation belongs to the WORLD, not to this file.** Ice carries
	# light much further than rock, so a Rime tunnel is legible far past where a
	# Cinder one goes black. That is the class changing what you can SEE, which
	# is one of the three things a class is allowed to change.
	var att := Classes.detour_att(world.class_id)
	var field := PackedFloat32Array()
	field.resize(SIDE * SIDE)
	field.fill(0.0)

	var dist := PackedFloat32Array()
	dist.resize(SIDE * SIDE)
	dist.fill(1.0e18)

	# A small bucket queue rather than a heap: the costs are 1 and sqrt(2), the
	# window is 49x49, and a heap here would be more code for no measurable win.
	var open: Array[int] = []
	var start := _local(0, 0)
	dist[start] = 0.0
	open.append(start)

	while not open.is_empty():
		# Cheapest first. The frontier never gets large on a window this size.
		var bi := 0
		for i in range(1, open.size()):
			if dist[open[i]] < dist[open[bi]]:
				bi = i
		var cur: int = open[bi]
		open.remove_at(bi)

		var cx := cur % SIDE - R
		var cd := cur / SIDE - R
		var here := dist[cur]

		for sy in range(-1, 2):
			for sx in range(-1, 2):
				if sx == 0 and sy == 0:
					continue
				var nx := cx + sx
				var nd := cd + sy
				if absi(nx) > R or absi(nd) > R:
					continue
				# Light travels through OPEN cells only. That is what makes an
				# unopened side tunnel black instead of as bright as the shaft
				# the player is flying down.
				if not world.is_open(ox + nx, od + nd):
					continue
				var step := DIAG if (sx != 0 and sy != 0) else 1.0
				var ni := _local(nx, nd)
				var cost := here + step
				if cost < dist[ni] - 1.0e-6:
					dist[ni] = cost
					open.append(ni)

	for d in range(-R, R + 1):
		for x in range(-R, R + 1):
			var i := _local(x, d)
			if dist[i] > 1.0e17:
				field[i] = 0.0
				continue
			var detour: float = maxf(dist[i] - _octile(x, d), 0.0)
			field[i] = exp(-att * detour)
	return field


## Surfaces are lit by being NEAR a lit space, so a solid cell takes the
## brightest of its open neighbours. Without this every rock face is black,
## because the flood only ever reaches open cells and a wall is not one.
static func spill(world: World, field: PackedFloat32Array, ox: int, od: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(SIDE * SIDE)
	for d in range(-R, R + 1):
		for x in range(-R, R + 1):
			var i := _local(x, d)
			if world.is_open(ox + x, od + d):
				out[i] = field[i]
				continue
			var best := 0.0
			for sy in range(-1, 2):
				for sx in range(-1, 2):
					if sx == 0 and sy == 0:
						continue
					if absi(x + sx) > R or absi(d + sy) > R:
						continue
					if not world.is_open(ox + x + sx, od + d + sy):
						continue
					best = maxf(best, field[_local(x + sx, d + sy)])
			out[i] = best
	return out


## The shadow fan: per bearing, how far light gets before something stops it.
##
## One-dimensional, so it uploads as a small texture and the shader asks "is
## this fragment further from the lamp than the occluder on its own bearing".
## Sharp by construction, exact for any geometry, and the wedge behind a corner
## widens with distance for free, because that is what a fan of rays does.
##
## **Record the FAR corner of the first solid cell hit, not where the ray leaves
## it.** A wall's face is the surface the light is falling ON and has to stay
## lit; shadow starts behind it. Recording the near side puts every rock face in
## the game into its own shadow, which reads as the lighting being broken rather
## than as an off-by-one, and in Coreward it was thirteen per cent of every wall.
static func fan(world: World, from: Vector2, reach: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(RAYS)
	for i in range(RAYS):
		var a := TAU * float(i) / float(RAYS)
		out[i] = _cast(world, from, Vector2(cos(a), sin(a)), reach)
	return out


## March one ray through the grid and return the distance at which shadow
## starts, or `reach` if nothing stopped it.
static func _cast(world: World, from: Vector2, dir: Vector2, reach: float) -> float:
	var x := int(roundf(from.x))
	var d := int(roundf(from.y))
	var step_x := 1 if dir.x > 0.0 else -1
	var step_d := 1 if dir.y > 0.0 else -1
	var inv_x: float = 1.0e18 if absf(dir.x) < 1.0e-9 else 1.0 / absf(dir.x)
	var inv_d: float = 1.0e18 if absf(dir.y) < 1.0e-9 else 1.0 / absf(dir.y)

	# Distance from the start to the first cell boundary on each axis.
	var next_x: float = ((float(x) + 0.5 * float(step_x)) - from.x) / dir.x if absf(dir.x) > 1.0e-9 else 1.0e18
	var next_d: float = ((float(d) + 0.5 * float(step_d)) - from.y) / dir.y if absf(dir.y) > 1.0e-9 else 1.0e18

	var travelled := 0.0
	while travelled < reach:
		if not world.is_open(x, d):
			# The far corner of this cell along the ray: the whole cell is a
			# wall and the whole wall is lit, so shadow begins behind it.
			var far := _far_corner(Vector2(float(x), float(d)), from, dir)
			return minf(far, reach)
		if next_x < next_d:
			travelled = next_x
			x += step_x
			next_x += inv_x
		else:
			travelled = next_d
			d += step_d
			next_d += inv_d
	return reach


## The distance from `from` to the furthest corner of the cell at `cell` along
## `dir`. A wall is a whole cell, and the rule the fan exists to express is
## "the first wall is lit".
static func _far_corner(cell: Vector2, from: Vector2, dir: Vector2) -> float:
	var best := 0.0
	var corners: Array[Vector2] = [
		Vector2(-0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5),
	]
	for c in corners:
		best = maxf(best, ((cell + c) - from).dot(dir))
	return best


## Is a point in shadow, given the fan? The shader does this per pixel; this is
## the same arithmetic so a test can assert on what the shader will show.
##
## **Blend the two nearest rays the way the shader does.** A nearest-ray lookup
## cannot see the interpolation artefact at all, because the artefact only
## exists once two rays are blended, and sampling cell centres cannot see it
## either, because a centre passes under both rules.
static func shadow_at(fan_field: PackedFloat32Array, from: Vector2, p: Vector2) -> float:
	var away := p - from
	var dist := away.length()
	if dist < 1.0e-5:
		return 1.0
	var a := fposmod(away.angle(), TAU) / TAU * float(RAYS)
	var i0 := int(floor(a)) % RAYS
	var i1 := (i0 + 1) % RAYS
	var frac: float = a - floor(a)
	var occ: float = lerpf(fan_field[i0], fan_field[i1], frac)
	return 1.0 if dist <= occ else 0.0


## Read the field at a cell offset from the origin it was solved around.
static func at(field: PackedFloat32Array, x: int, d: int) -> float:
	if absi(x) > R or absi(d) > R:
		return 0.0
	return field[_local(x, d)]


static func _local(x: int, d: int) -> int:
	return (d + R) * SIDE + (x + R)


static func _octile(x: int, d: int) -> float:
	var ax := absi(x)
	var ad := absi(d)
	return float(maxi(ax, ad)) + (DIAG - 1.0) * float(mini(ax, ad))
