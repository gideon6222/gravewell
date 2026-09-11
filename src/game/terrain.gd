class_name Terrain
extends Node3D

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

## **The mesh is built in chunks, and only the dirty ones are rebuilt.**
##
## One mesh over the whole visible window cost 31 ms to rebuild and was rebuilt
## every time the ship crossed a metre. At `Tuning.SUB` = 4 the contour has
## sixteen times the cells and would be rebuilt four times as often, which priced
## the same whole-window rebuild at about 500 ms. Chunks turn that into "rebuild
## the six metres the drill actually touched", which is what makes a finer
## lattice affordable at all.
##
## Three metres is a size, not a guess: the brush reaches under a metre, so a
## tick dirties one chunk and occasionally two, and nine square metres of fine
## contour is a few milliseconds. At six it measured 13 ms a tick while drilling,
## which is most of a frame for rock that had barely changed.
##
## `BUDGET` is the second half of that: no more than this many chunks are rebuilt
## in one frame, and the rest wait. A chunk a frame behind is invisible, and a
## frame that stalls is not.
const CHUNK := 3

## Chunks rebuilt in one frame. A missing chunk is always built - a hole in the
## world is not something to amortise - but a merely STALE one can wait a frame.
const BUDGET := 1

## And how many MISSING chunks, which is a different and more urgent thing.
const HOLE_BUDGET := 4

var _world: World
var _material: Material
var _chunks: Dictionary = {}          ## Vector2i(chunk) -> MeshInstance3D
var _dirty: Dictionary = {}           ## Vector2i(chunk) -> true
var _colours: PackedColorArray = PackedColorArray()
var _colour_valid: PackedByteArray = PackedByteArray()

var vertex_count: int = 0     ## what the smoke test reads instead of a flush flag


func setup(w: World, material: Material) -> void:
	_world = w
	_material = material
	_colours.resize(w.mat.size())
	_colour_valid.resize(w.mat.size())
	_colour_valid.fill(0)
	for c in _chunks.values():
		(c as Node).queue_free()
	_chunks.clear()
	_dirty.clear()


## Mark EVERYTHING stale. A change of planet, or anything that can move rock
## outside the drill's own reach.
func touch() -> void:
	for k in _chunks.keys():
		_dirty[k] = true
	_colour_valid.fill(0)


## Mark the chunk a change at (x, d) lands in, and a NEIGHBOUR only when the
## change is against a shared edge.
##
## A chunk's contour reads one cell past its own edge, so a carve on a boundary
## does change the chunk next door - but marking the whole three-by-three
## neighbourhood every time, which is what this did first, rebuilds nine chunks
## for a change that touched one. At 36 ms a chunk that was 324 ms a tick, and a
## sixteen-second screenshot took five minutes to render.
func touch_at(x: int, d: int) -> void:
	# The metre's material can have changed with its shape, so its colour is
	# recomputed next time it is asked for.
	if _world.in_bounds(x, d):
		_colour_valid[_world.idx(x, d)] = 0
	var k := _key(x, d)
	_dirty[k] = true
	var lx := x - k.x * CHUNK
	var ld := d - k.y * CHUNK
	if lx == 0:
		_dirty[Vector2i(k.x - 1, k.y)] = true
	elif lx == CHUNK - 1:
		_dirty[Vector2i(k.x + 1, k.y)] = true
	if ld == 0:
		_dirty[Vector2i(k.x, k.y - 1)] = true
	elif ld == CHUNK - 1:
		_dirty[Vector2i(k.x, k.y + 1)] = true


## The unit square, for a metre that is drawn whole. A `static var` and not a
## `const`, because a PackedVector2Array literal is not a constant expression in
## GDScript and the parse error it raises takes the whole script down.
static var SQUARE := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])


## Is this metre deep enough inside solid rock that its surface is a flat square?
## Its own fine cells full, and the fine cells facing it across each edge full
## too, or the contour would have had a crossing to draw on that edge.
func _is_buried(x: int, d: int) -> bool:
	return _world.is_solid(x, d) and _world.is_solid(x - 1, d) and _world.is_solid(x + 1, d) 		and _world.is_solid(x, d - 1) and _world.is_solid(x, d + 1)


## Is this metre, and everything it touches, completely gone?
func _is_void(x: int, d: int) -> bool:
	return _empty(x, d) and _empty(x - 1, d) and _empty(x + 1, d) 		and _empty(x, d - 1) and _empty(x, d + 1)


func _empty(x: int, d: int) -> bool:
	if d < -Tuning.SURFACE_ROWS:
		return true
	if not _world.in_bounds(x, d):
		return false
	return _world.mean_cache[_world.idx(x, d)] <= Tuning.OPEN_FILL


func _key(x: int, d: int) -> Vector2i:
	return Vector2i(int(floor(float(x) / float(CHUNK))), int(floor(float(d) / float(CHUNK))))


## Build whatever is missing or stale inside the window, and drop what has left
## it. Returns true if anything was built, so the caller can keep the light field
## in step without a second notion of when things changed.
func refresh(centre: Vector2i, half_w: int, half_d: int) -> bool:
	var lo := _key(centre.x - half_w, centre.y - half_d)
	var hi := _key(centre.x + half_w, centre.y + half_d)

	# Anything outside the window is freed. The window follows the ship, so this
	# is what keeps a two-hundred-metre planet from accumulating in memory.
	for k in _chunks.keys():
		var key: Vector2i = k
		if key.x < lo.x or key.x > hi.x or key.y < lo.y or key.y > hi.y:
			(_chunks[key] as Node).queue_free()
			_chunks.erase(key)
			_dirty.erase(key)

	# **A HOLE beats a stale chunk, however far away it is.**
	#
	# Sorting purely by distance starves the missing ones: the chunk under the
	# drill is dirty every single tick and is always the nearest, so with a budget
	# of one it wins every frame and a chunk that has just entered the window
	# never gets built at all. The bottom half of the screen went black.
	#
	# So missing chunks come first, nearest first among themselves, and they get
	# their own larger budget - a hole is a hole, and it has to close now - while
	# a merely stale chunk is at most a frame or two out of date and nobody can
	# see that.
	var missing: Array[Vector2i] = []
	var stale: Array[Vector2i] = []
	for cd in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var key := Vector2i(cx, cd)
			if not _chunks.has(key):
				missing.append(key)
			elif _dirty.get(key, false):
				stale.append(key)
	var here := _key(centre.x, centre.y)
	var nearer := func(a: Vector2i, b: Vector2i) -> bool:
		return (a - here).length_squared() < (b - here).length_squared()
	missing.sort_custom(nearer)
	stale.sort_custom(nearer)

	var built := false
	var done := 0
	for key in missing:
		if done >= HOLE_BUDGET:
			break
		_build_chunk(key)
		_dirty.erase(key)
		built = true
		done += 1
	done = 0
	for key in stale:
		if done >= BUDGET:
			break
		_build_chunk(key)
		_dirty.erase(key)
		built = true
		done += 1

	if built:
		var total := 0
		for c in _chunks.values():
			var mi: MeshInstance3D = c
			var m: ArrayMesh = mi.mesh
			if m != null and m.get_surface_count() > 0:
				total += m.surface_get_array_len(0)
		vertex_count = total
	return built


## One chunk, contoured on the FINE lattice.
##
## The lattice is `Tuning.SUB` cells to the metre, so everything the contour
## returns is in fine-cell units and gets divided down before it becomes a
## vertex. Material, colour and seams are still read per METRE inside
## `_colour_at`, because an ore vein is a metre-scale fact and only the SHAPE
## needed to get finer.
func _build_chunk(key: Vector2i) -> void:
	var sub := Tuning.SUB
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# **Flat normals, per face, not smoothed.**
	#
	# `generate_normals()` averages across vertices that share a position, which
	# only ever sees the vertices in THIS chunk: two chunks meeting along a seam
	# average different sets and light differently, and the seams showed on screen
	# as a grid of three-metre rectangles laid over the rock. A per-face normal is
	# the same number whichever chunk computes it, so the seam disappears by
	# construction rather than by matching two caches.
	#
	# It also costs nothing at this lattice: a facet is a quarter of a metre and
	# the rock's detail comes from the normal map, not from the silhouette of a
	# triangle.
	st.set_smooth_group(-1)

	var any := false
	var scale := 1.0 / float(sub)

	# **Solid rock is drawn at the METRE, and only the surface at the quarter.**
	#
	# The contour has sixteen times the cells now, and almost all of them are deep
	# inside untouched rock where the answer is a flat square either way: emitting
	# those at the fine lattice put 61,350 vertices in a window that used to hold
	# 2,976, for a wall that looks identical. A metre whose own fine cells and
	# whose neighbours' facing cells are all full is covered by one quad, and the
	# fine lattice is spent where it is the whole point - the cut face.
	for d in range(key.y * CHUNK, key.y * CHUNK + CHUNK):
		for x in range(key.x * CHUNK, key.x * CHUNK + CHUNK):
			if _is_buried(x, d):
				# **Its own colour, at all four corners.** A buried metre is one
				# metre of one material, so that IS the truth - and sampling the
				# corners instead asks `_colour_at` to pick the most solid of the
				# four metres meeting there, which for untouched rock is a tie
				# resolved by scan order. Every quad then took a different
				# neighbour's ore colour and the wall came out as a patchwork of
				# metre-wide blocks in colours nothing nearby was made of.
				_add_face(st, Vector2(float(x) - 0.5, float(d) - 0.5), SQUARE, 1.0)
				any = true
				continue
			# And the mirror of it: a metre with nothing left in it, whose
			# neighbours are empty too, has no crossing anywhere inside it and
			# contours to nothing. Skipping it is worth more than skipping buried
			# rock, because while the player is drilling most of the chunk under
			# the ship is exactly this - the tunnel they just cut.
			if _is_void(x, d):
				continue
			# **One fine cell of overlap on the low side, or the metre has a gap
			# along its own edge.**
			#
			# A contour cell spans from one lattice point to the next, so the cells
			# whose ORIGIN lies inside this metre cover `x - 0.375` to `x + 0.625`
			# and not `x - 0.5` to `x + 0.5`. The strip left undrawn is an eighth
			# of a metre wide and it runs the length of every boundary: on screen
			# it is a grid of black bars across the rock. Starting one cell early
			# draws the seam twice, which costs a few triangles and is invisible.
			var fx0 := x * sub - 1
			var fd0 := d * sub - 1
			for fd in range(fd0, fd0 + sub + 1):
				for fx in range(fx0, fx0 + sub + 1):
					var c0 := _world.fine_at(fx, fd)
					var c1 := _world.fine_at(fx + 1, fd)
					var c2 := _world.fine_at(fx + 1, fd + 1)
					var c3 := _world.fine_at(fx, fd + 1)
					var m := Contour.case_of(c0, c1, c2, c3)
					if m == 0:
						continue
					any = true
					# The lattice is fine cell CENTRES, exactly as it used to be
					# metre centres, so the origin is this cell's centre in metres.
					var origin := Vector2(World.fine_centre(fx), World.fine_centre(fd))
					for poly in Contour.fill_polygon(c0, c1, c2, c3):
						_add_face(st, origin, poly, scale)
					var segs := Contour.segments(c0, c1, c2, c3)
					for i in range(0, segs.size(), 2):
						_add_wall(st, origin + segs[i] * scale, origin + segs[i + 1] * scale)

	var mi: MeshInstance3D = _chunks.get(key, null)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.material_override = _material
		# The rock owns its whole light model in the shader and is excluded from
		# every real light. A chunk that casts or receives one puts a hard-edged
		# rectangle of its own bounds over the rock beside it.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(mi)
		_chunks[key] = mi

	# **An empty chunk is a real and common case**: most of a window is either
	# solid rock away from any tunnel or open air, and both contour to nothing.
	# `generate_tangents` on an empty SurfaceTool logs "UVs are required to
	# generate tangents" once per chunk per rebuild, which is thousands of error
	# lines a minute and a gate that fails on the error count rather than on
	# anything being wrong.
	if not any:
		mi.mesh = null
		return
	st.generate_normals()
	st.generate_tangents()
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mi.mesh = mesh


## The colour of the rock AT A POINT, sampled per vertex rather than per cell.
##
## Per-cell colour was the first version and it undid the whole technique: the
## geometry was a smooth continuous surface and the colour was a hard grid of
## squares laid over it, so an ore vein read as a row of tiles rather than as
## mineral in rock. Sampling per vertex lets the colour interpolate across every
## triangle, which is what makes a seam look like it runs through the stone.
##
## **The sample is the weighted AVERAGE of the metres touching the point**, by how
## much rock each still has. It was the single most solid of them, and a tie - four
## untouched metres, which is most of a planet - was broken by scan order. With
## every cell contoured that was invisible, because the vertices were dense enough
## to blend anyway. Once buried rock became one quad per metre, the four corners
## each picked a different neighbour's ore and the wall came out as a patchwork of
## metre-wide blocks in colours nothing nearby was made of.
##
## Averaging also makes two neighbouring quads agree about the corner they share,
## which is what makes a flat-shaded wall read as continuous stone at all.
func _colour_at(p: Vector2) -> Color:
	var bx := int(floor(p.x))
	var bd := int(floor(p.y))
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var a := 0.0
	var total := 0.0
	var cache := Vector2i(-99999, 0)
	for od in range(0, 2):
		for ox in range(0, 2):
			var x := bx + ox
			var d := bd + od
			# **Weighted by how much rock is there**, which is what keeps a vein
			# its colour right up to the tunnel edge instead of being washed out
			# by the air beside it. Air weighs nothing and contributes nothing.
			var f := _world.fill_at(x, d)
			if f <= 0.0:
				continue
			if _world.material_at(x, d) == Ore.CACHE:
				cache = Vector2i(x, d)
			var c := _metre_colour(x, d)
			r += c.r * f
			g += c.g * f
			b += c.b * f
			a += c.a * f
			total += f
	# **A cache shows through one layer of rock**, as a discolouration in the wall
	# rather than as a marker on a map. That is the whole design of the secret
	# layer: you find it by reading the world. So it wins outright rather than
	# being averaged into the stone in front of it.
	if cache.x != -99999:
		return _metre_colour(cache.x, cache.y)
	if total <= 0.0:
		return _metre_colour(bx, bd)
	return Color(r / total, g / total, b / total, a / total)


## **What one METRE is coloured, memoised.**
##
## The colour of a metre depends on its material, its seam flag and its depth
## band, none of which change unless the metre itself does - but working it out
## costs a dictionary lookup, a `lightened()`, a tint multiply and three
## `Color` constructions, and the mesh builder asks for it once per vertex.
##
## **This is not the per-cell colour cache that flattened the rock.** That one
## keyed on the VERTEX position, so every vertex in a metre got one answer and
## the triangles had nothing to interpolate. This keys on the metre that
## `_colour_at` already chose after comparing its neighbours: two vertices a
## centimetre apart still pick different metres and still blend across the
## triangle between them. The sampling is unchanged; only the arithmetic behind
## the chosen metre is remembered.
func _metre_colour(x: int, d: int) -> Color:
	if not _world.in_bounds(x, d):
		return _compute_colour(x, d)
	var i := _world.idx(x, d)
	if _colour_valid[i] == 1:
		return _colours[i]
	var c := _compute_colour(x, d)
	_colours[i] = c
	_colour_valid[i] = 1
	return c


func _compute_colour(x: int, d: int) -> Color:
	var m := _world.material_at(x, d)
	var col: Color = MAT_COLOUR.get(m, MAT_COLOUR[Ore.ROCK])
	if _world.is_seam(x, d):
		col = col.lightened(SEAM_LIGHTEN)
	# The band tint, from the WORLD'S CLASS rather than from the depth alone.
	# Half of the four things that land on the Line, and the reason a Rime shaft
	# is blue-white where a Cinder one smoulders.
	var t := Classes.tint_at(_world.class_id, float(d))
	col = Color(col.r * t.r, col.g * t.g, col.b * t.b, col.a)
	# Alpha is how much the material glows on its own, which the shader runs on
	# its own gentler curve so a rich seam still reads through the dark.
	col.a = Ore.glow_of(m)
	if m == Ore.CACHE:
		col.a = 0.55
	elif m == Ore.CORE:
		col.a = 1.0
	return col


func _add_face(st: SurfaceTool, origin: Vector2, poly: PackedVector2Array, scale: float) -> void:
	if poly.size() < 3:
		return
	# A fan from the first vertex. Every polygon marching squares produces is
	# convex, so a fan is a correct triangulation and needs no ear clipping.
	for i in range(1, poly.size() - 1):
		_tri(_v(origin + poly[0] * scale, HALF), _v(origin + poly[i] * scale, HALF),
			_v(origin + poly[i + 1] * scale, HALF), st)


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
	# **Sampled per VERTEX. Never cached per cell, at any resolution.**
	#
	# This was cached per metre for one round, to save the two-by-two scan inside
	# `_colour_at` at the fine lattice. It is the exact bug the comment on
	# `_colour_at` was written about: every vertex in a metre gets one answer, the
	# interpolation across the triangles has nothing left to interpolate, and the
	# rock comes out as a grid of flat tiles. Rendering the vertex colour straight
	# to ALBEDO showed it immediately - the picture was a chequerboard.
	#
	# The whole technique is that adjacent vertices can pick DIFFERENT cells and
	# the triangle blends them. Caching by position destroys exactly that.
	st.set_color(_colour_at(Vector2(v.x, -v.y)))
	st.set_uv(Vector2(v.x, v.y) * UV_SCALE)
	st.add_vertex(v)
