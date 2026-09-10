class_name Contour
extends RefCounted

## Interpolated marching squares: the rock stops looking like blocks.
##
## Pure. Grid in, vertex arrays out. No Node, no mesh, no renderer.
##
## For each cell of the corner lattice, the four corner values are compared
## against `Tuning.CONTOUR_ISO` to pick one of sixteen cases, and the contour
## vertex on each crossed edge is placed by **linearly interpolating between the
## two corner values** rather than snapped to the edge's midpoint. That
## interpolation is the whole difference between an eroded rock face and a
## staircase of cubes, and it costs one division per crossed edge.
##
## Sources: the sixteen cases and the interpolation are the standard algorithm
## (Wikipedia, "Marching squares"); Sebastian Lague's cave series is the worked
## build; `richardhyy/Godot-4-Destructable-Terrain` is a Godot 4 implementation
## that already chunks and decomposes collision.
##
## ## What this is NOT
##
## **It is not collision.** Collision stays on the cell grid, exactly, because
## collision decides outcomes and must be testable headlessly. The contour is
## biased so it never encroaches more than `MAX_ENCROACH` of a cell into a cell
## the collision model calls open, and `test_contour.gd` asserts that band, so
## the player never hits rock they cannot see.
##
## ## The ambiguous cases
##
## Cases 5 and 10 are the checkerboard: two opposite corners inside the surface
## and two outside. There are two equally valid ways to join them and **the
## choice has to be fixed**, or the contour flips between them as neighbouring
## cells are dug and the wall shimmers. This resolves both by joining toward the
## cell's own average, which is the standard tie-break and is deterministic.

## How far the drawn surface may reach into a cell that collision calls open.
## A fifth of a cell is the same bias Coreward's displacement shader used and
## it was never reported; the point of the constant is that it is asserted.
const MAX_ENCROACH := 0.15

## The corner order used everywhere below: 0 top-left, 1 top-right, 2
## bottom-right, 3 bottom-left, matching the standard case table.
const CORNER_OFFSETS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
]


## Where the surface crosses the edge between two corners, as a fraction from
## `a` toward `b`. This is the interpolation, and it is the algorithm.
##
## Clamped away from the exact ends: a vertex sitting exactly on a lattice point
## produces zero-area triangles, which some drivers keep and some drop, and a
## mesh that differs by driver is a bug that only appears on one phone.
static func crossing(a: float, b: float) -> float:
	var span := b - a
	if absf(span) < 1.0e-6:
		return 0.5
	return clampf((Tuning.CONTOUR_ISO - a) / span, 0.02, 0.98)


## The four-bit case index for a cell, from its corner values.
static func case_of(c0: float, c1: float, c2: float, c3: float) -> int:
	var m := 0
	if c0 >= Tuning.CONTOUR_ISO:
		m |= 1
	if c1 >= Tuning.CONTOUR_ISO:
		m |= 2
	if c2 >= Tuning.CONTOUR_ISO:
		m |= 4
	if c3 >= Tuning.CONTOUR_ISO:
		m |= 8
	return m


## The segments of the surface inside one lattice cell, in cell-local
## coordinates where (0,0) is corner 0 and (1,1) is corner 2.
##
## Returns a flat array of point pairs: [a0, b0, a1, b1, ...]. Zero, one or two
## segments, never more.
static func segments(c0: float, c1: float, c2: float, c3: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var m := case_of(c0, c1, c2, c3)
	if m == 0 or m == 15:
		return out                       ## entirely outside or entirely inside

	# The crossing point on each of the four edges, named by the corners it
	# joins. Only the ones the case actually uses are read.
	var top := Vector2(crossing(c0, c1), 0.0)
	var right := Vector2(1.0, crossing(c1, c2))
	var bottom := Vector2(1.0 - crossing(c3, c2), 1.0)
	var left := Vector2(0.0, 1.0 - crossing(c3, c0))

	match m:
		1, 14: out.append_array([left, top])
		2, 13: out.append_array([top, right])
		3, 12: out.append_array([left, right])
		4, 11: out.append_array([right, bottom])
		6, 9: out.append_array([top, bottom])
		7, 8: out.append_array([left, bottom])
		5:
			# Ambiguous. Two opposite corners in, two out. Joining toward the
			# cell's average is the fixed tie-break: without one, the contour
			# flips as neighbours are dug and the wall shimmers.
			if _centre(c0, c1, c2, c3) >= Tuning.CONTOUR_ISO:
				out.append_array([left, top, right, bottom])
			else:
				out.append_array([left, bottom, top, right])
		10:
			if _centre(c0, c1, c2, c3) >= Tuning.CONTOUR_ISO:
				out.append_array([top, right, left, bottom])
			else:
				out.append_array([top, left, right, bottom])
	return out


static func _centre(c0: float, c1: float, c2: float, c3: float) -> float:
	return (c0 + c1 + c2 + c3) * 0.25


## Build the whole visible surface for a window of the world, as a flat list of
## world-space segment endpoints in (x, depth) metres.
##
## **The lattice is the cell CENTRES, and the scalar sampled at each vertex is
## that cell's own fill.** The obvious alternative, averaging four cells into a
## shared corner, cannot represent a single dug cell at all: one cell at 0
## surrounded by solid gives every corner (0+1+1+1)/4 = 0.75, which is above any
## isovalue that also calls untouched rock solid, so cutting one cell changed the
## picture not at all. Measured: `build()` returned zero segments after a cell was
## fully removed.
##
## Sampling cell centres is exact instead. A fully cut cell interpolates the
## surface to precisely its own boundary, so the drawn opening and the passable
## opening are the same shape, and a part-cut cell pulls the surface a fraction of
## the way in, which is what makes damage visible before the cell breaks.
##
## The caller extrudes these into a wall mesh. Keeping the extrusion out of here
## is what lets this be tested with no renderer at all.
static func build(world: World, x0: int, x1: int, d0: int, d1: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for d in range(d0, d1 + 1):
		for x in range(x0, x1 + 1):
			var segs := segments(
				world.fill_at(x, d), world.fill_at(x + 1, d),
				world.fill_at(x + 1, d + 1), world.fill_at(x, d + 1))
			if segs.is_empty():
				continue
			# Lattice cell (x, d) spans from cell centre (x, d) to centre
			# (x+1, d+1), and cell centres sit on integer coordinates.
			var origin := Vector2(float(x), float(d))
			for p in segs:
				out.append(origin + p)
	return out


## How far the drawn surface reaches into a cell the collision model calls open,
## as a fraction of a cell. The number `test_contour.gd` asserts against
## `MAX_ENCROACH`, and the reason the player never hits rock they cannot see.
static func encroachment(world: World, x: int, d: int) -> float:
	if not world.is_open(x, d):
		return 0.0
	var worst := 0.0
	# Annotated, not inferred: a value read out of an untyped Array literal is a
	# Variant and `:=` cannot infer from one. The failure is a parse error at
	# load, which in a harness reads as a run that never terminates.
	var neighbours: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]
	for off in neighbours:
		var lx: int = x + off.x
		var ld: int = d + off.y
		var segs := segments(
			world.fill_at(lx, ld), world.fill_at(lx + 1, ld),
			world.fill_at(lx + 1, ld + 1), world.fill_at(lx, ld + 1))
		var origin := Vector2(float(lx), float(ld))
		for p in segs:
			var w := origin + p
			# How far inside this cell's own box the point sits. Zero means the
			# surface lands exactly on the boundary, which is what a fully cut
			# cell produces and is the whole point of the cell-centre lattice.
			var inside := minf(0.5 - absf(w.x - float(x)), 0.5 - absf(w.y - float(d)))
			worst = maxf(worst, inside)
	return worst


## The polygon of the SOLID region inside one lattice cell, in the same local
## coordinates as `segments()`.
##
## `segments()` gives the line where rock meets air, which is what the tunnel
## walls are extruded along. This gives the face the player is looking AT, and
## the two have to come from the same case table or the wall and the face
## disagree along every edge.
##
## The algorithm is the standard walk: step round the four corners in order, emit
## a corner if it is inside, and emit the crossing point whenever an edge changes
## side. That is correct for every case except the two checkerboards, where a
## single walk produces a bowtie, so those are split by the same tie-break
## `segments()` uses.
static func fill_polygon(c0: float, c1: float, c2: float, c3: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var m := case_of(c0, c1, c2, c3)
	if m == 0:
		return out
	if m == 15:
		out.append(PackedVector2Array([
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
		return out

	var v: Array[float] = [c0, c1, c2, c3]
	var corner: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]

	# The two checkerboards. Disconnected means two corner triangles; connected
	# means the walk below already gives the right hexagon.
	if (m == 5 or m == 10) and _centre(c0, c1, c2, c3) < Tuning.CONTOUR_ISO:
		for i in range(4):
			if v[i] < Tuning.CONTOUR_ISO:
				continue
			var prev := (i + 3) % 4
			var next := (i + 1) % 4
			out.append(PackedVector2Array([
				corner[i],
				corner[i].lerp(corner[next], crossing(v[i], v[next])),
				corner[i].lerp(corner[prev], crossing(v[i], v[prev])),
			]))
		return out

	var poly := PackedVector2Array()
	for i in range(4):
		var j := (i + 1) % 4
		var inside_i: bool = v[i] >= Tuning.CONTOUR_ISO
		var inside_j: bool = v[j] >= Tuning.CONTOUR_ISO
		if inside_i:
			poly.append(corner[i])
		if inside_i != inside_j:
			var t: float = crossing(v[i], v[j]) if inside_i else 1.0 - crossing(v[j], v[i])
			poly.append(corner[i].lerp(corner[j], t))
	if poly.size() >= 3:
		out.append(poly)
	return out


## The area of the solid region in a cell, as a fraction. Used by the tests to
## check the face and the fill agree with the number the simulation holds, which
## is the only way to know the picture is drawing the rules.
static func fill_area(c0: float, c1: float, c2: float, c3: float) -> float:
	var total := 0.0
	for poly in fill_polygon(c0, c1, c2, c3):
		var a := 0.0
		for i in range(poly.size()):
			var p := poly[i]
			var q := poly[(i + 1) % poly.size()]
			a += p.x * q.y - q.x * p.y
		total += absf(a) * 0.5
	return total
