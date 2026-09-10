class_name Terrain
extends MeshInstance3D

## The rock, drawn from the contour the simulation solves.
##
## Two pieces of geometry from one case table, which is what keeps them in
## agreement along every edge:
##
##   the FACE  - the solid region of each lattice cell, at z = +HALF, the surface
##               the player is looking at
##   the WALLS - each contour segment extruded back from z = +HALF to z = -DEPTH,
##               which is what a tunnel's sides are and what catches the lamp
##
## Rebuilt only when the window moves or the rock changes shape, on the same
## event that re-runs the light flood. A dig is one rebuild of one window, which
## is a few thousand vertices; it does not happen per frame.

## Front face at +0.5 so a cell occupies exactly its own metre, and the tunnel
## goes back far enough that a wall reads as a wall rather than as a ribbon.
const HALF := 0.5
const DEPTH := 2.6

## Vertex colour carries the material's colour in RGB and how much it glows on
## its own in A, so the shader gets both without a second stream and the whole
## terrain stays one draw call.
const MAT_COLOUR := {
	Ore.ROCK: Color(0.215, 0.200, 0.190),
	Ore.IRON: Color(0.380, 0.290, 0.235),
	Ore.COBALT: Color(0.200, 0.290, 0.400),
	Ore.ARGENT: Color(0.560, 0.590, 0.620),
	Ore.PYRE: Color(0.700, 0.330, 0.150),
	Ore.VOIDGLASS: Color(0.420, 0.250, 0.600),
	Ore.CACHE: Color(0.880, 0.760, 0.330),
	Ore.CORE: Color(1.000, 0.560, 0.220),
}

## A seam is the texture he asked to be worth more, so it has to read as
## different rock from a distance, not as a tint you only see up close.
const SEAM_LIGHTEN := 0.30

var _world: World
var _mesh := ArrayMesh.new()
var _built_at := Vector2i(9999, 9999)
var _dirty := true

var vertex_count: int = 0     ## what the smoke test reads instead of a flush flag


func setup(w: World, material: Material) -> void:
	_world = w
	mesh = _mesh
	material_override = material


## Mark the mesh stale. Called on every dig, and on a change of planet.
func touch() -> void:
	_dirty = true


## Rebuild if the ship has moved to a new cell or the rock has changed. Returns
## true if it actually rebuilt, so the caller can keep the light field in step
## without a second notion of when things changed.
func refresh(centre: Vector2i, half_w: int, half_d: int) -> bool:
	if not _dirty and centre == _built_at:
		return false
	_built_at = centre
	_dirty = false
	_build(centre, half_w, half_d)
	return true


func _build(centre: Vector2i, half_w: int, half_d: int) -> void:
	_mesh.clear_surfaces()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var x0 := centre.x - half_w
	var x1 := centre.x + half_w
	var d0 := centre.y - half_d
	var d1 := centre.y + half_d

	for d in range(d0, d1 + 1):
		for x in range(x0, x1 + 1):
			var c0 := _world.fill_at(x, d)
			var c1 := _world.fill_at(x + 1, d)
			var c2 := _world.fill_at(x + 1, d + 1)
			var c3 := _world.fill_at(x, d + 1)
			var m := Contour.case_of(c0, c1, c2, c3)
			if m == 0:
				continue
			var origin := Vector2(float(x), float(d))

			for poly in Contour.fill_polygon(c0, c1, c2, c3):
				_add_face(st, origin, poly)
			var segs := Contour.segments(c0, c1, c2, c3)
			for i in range(0, segs.size(), 2):
				_add_wall(st, origin + segs[i], origin + segs[i + 1])

	st.generate_normals()
	st.generate_tangents()
	st.commit(_mesh)
	# GDScript has no C ternary; the conditional expression is `x if c else y`.
	vertex_count = _mesh.surface_get_array_len(0) if _mesh.get_surface_count() > 0 else 0


## The colour of the rock AT A POINT, sampled per vertex rather than per cell.
##
## Per-cell colour was the first version and it undid the whole technique: the
## geometry was a smooth continuous surface and the colour was a hard grid of
## squares laid over it, so an ore vein read as a row of tiles rather than as
## mineral in rock. Sampling per vertex lets the colour interpolate across every
## triangle, which is what makes a seam look like it runs through the stone.
##
## The sample is the MOST SOLID of the cells touching the point, so a vein keeps
## its colour right up to the tunnel edge instead of being washed out by the air
## beside it.
func _colour_at(p: Vector2) -> Color:
	var bx := int(floor(p.x))
	var bd := int(floor(p.y))
	var best_fill := -1.0
	var best := Vector2i(bx, bd)
	for od in range(0, 2):
		for ox in range(0, 2):
			var f := _world.fill_at(bx + ox, bd + od)
			if f > best_fill:
				best_fill = f
				best = Vector2i(bx + ox, bd + od)
	# **A cache shows through one layer of rock**, as a discolouration in the
	# wall rather than as a marker on a map. That is the whole design of the
	# secret layer: you find it by reading the world. A cache therefore wins the
	# colour vote over the rock in front of it, which it would otherwise lose on
	# a tie of fills.
	for od in range(0, 2):
		for ox in range(0, 2):
			if _world.material_at(bx + ox, bd + od) == Ore.CACHE:
				best = Vector2i(bx + ox, bd + od)

	var m := _world.material_at(best.x, best.y)
	var col: Color = MAT_COLOUR.get(m, MAT_COLOUR[Ore.ROCK])
	if _world.is_seam(best.x, best.y):
		col = col.lightened(SEAM_LIGHTEN)
	# The band tint. Half of the four things that land on the Line: the rock
	# changes colour at exactly the metre the hull starts draining.
	var t := Tuning.tint_at(float(best.y))
	col = Color(col.r * t.r, col.g * t.g, col.b * t.b, col.a)
	# Alpha is how much the material glows on its own, which the shader runs on
	# its own gentler curve so a rich seam still reads through the dark.
	col.a = Ore.glow_of(m)
	if m == Ore.CACHE:
		col.a = 0.55
	elif m == Ore.CORE:
		col.a = 1.0
	return col


func _add_face(st: SurfaceTool, origin: Vector2, poly: PackedVector2Array) -> void:
	if poly.size() < 3:
		return
	# A fan from the first vertex. Every polygon marching squares produces is
	# convex, so a fan is a correct triangulation and needs no ear clipping.
	for i in range(1, poly.size() - 1):
		_tri(_v(origin + poly[0], HALF), _v(origin + poly[i], HALF), _v(origin + poly[i + 1], HALF), st)


func _add_wall(st: SurfaceTool, a: Vector2, b: Vector2) -> void:
	var a_front := _v(a, HALF)
	var b_front := _v(b, HALF)
	var a_back := _v(a, -DEPTH)
	var b_back := _v(b, -DEPTH)
	_tri(a_front, b_front, b_back, st)
	_tri(a_front, b_back, a_back, st)


## Sim (x, depth) to scene (x, -depth, z). The one conversion, so nothing else
## has to remember which way depth runs.
func _v(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, -p.y, z)


## UVs are the WORLD position, not a per-triangle unwrap.
##
## Two reasons, and the second is the one that bites. Tangents cannot be
## generated without UVs at all, and a normal map needs tangents. And a
## world-projected UV means the rock pattern belongs to the rock rather than to
## the mesh, so a chunk rebuilt after a dig cannot make the texture swim - which
## it would do on every single cut with any per-mesh unwrap.
const UV_SCALE := 0.25


func _tri(a: Vector3, b: Vector3, c: Vector3, st: SurfaceTool) -> void:
	_vert(a, st)
	_vert(b, st)
	_vert(c, st)


func _vert(v: Vector3, st: SurfaceTool) -> void:
	st.set_color(_colour_at(Vector2(v.x, -v.y)))
	st.set_uv(Vector2(v.x, v.y) * UV_SCALE)
	st.add_vertex(v)
