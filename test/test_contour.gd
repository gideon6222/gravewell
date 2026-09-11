extends RefCounted

## Marching squares: the interpolation, the ambiguous cases, and the promise
## that the drawn surface never reaches into space the ship can fly through.


func _open_pocket(seed_value: int, cells: Array) -> World:
	var w := World.new(seed_value)
	for c in cells:
		var v: Vector2i = c
		if w.in_bounds(v.x, v.y):
			w.set_fill(v.x, v.y, 0.0)
			w.mat[w.idx(v.x, v.y)] = Ore.AIR
	return w


## Entirely solid and entirely open produce no surface at all. If they did, the
## mesh would carry a sheet through the middle of untouched rock.
func test_a_uniform_cell_has_no_surface(t: TestHarness) -> void:
	t.eq(Contour.segments(1.0, 1.0, 1.0, 1.0).size(), 0, "solid rock has no surface in it")
	t.eq(Contour.segments(0.0, 0.0, 0.0, 0.0).size(), 0, "open air has no surface in it")
	t.eq(Contour.case_of(1.0, 1.0, 1.0, 1.0), 15, "all-in is case 15")
	t.eq(Contour.case_of(0.0, 0.0, 0.0, 0.0), 0, "all-out is case 0")


## The interpolation IS the algorithm. Snapping to the midpoint is what makes a
## staircase of cubes; moving the vertex with the corner values is what makes an
## eroded face.
func test_the_crossing_moves_with_the_corner_values(t: TestHarness) -> void:
	t.approx(Contour.crossing(0.0, 1.0), 0.5, 1e-5, "an even pair crosses in the middle")
	var early := Contour.crossing(0.4, 1.0)
	var late := Contour.crossing(0.0, 0.6)
	t.lt(early, 0.5, "a corner already close to the surface crosses sooner")
	t.gt(late, 0.5, "a corner far from it crosses later")
	t.ok(early != late, "the crossing is not snapped to the midpoint")
	# Degenerate pairs must not divide by zero or leave a vertex on a lattice
	# point, which produces zero-area triangles that some drivers keep.
	var flat := Contour.crossing(0.5, 0.5)
	t.ok(flat > 0.0 and flat < 1.0, "an identical pair still returns a usable crossing")
	for a in [0.0, 0.25, 0.5, 0.75, 1.0]:
		for b in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var c := Contour.crossing(a, b)
			t.ok(c >= 0.02 and c <= 0.98, "crossing(%.2f,%.2f) stays off the lattice point" % [a, b])


## Every case that is not uniform produces a surface, and the checkerboards
## produce two segments rather than one.
func test_every_case_produces_the_right_number_of_segments(t: TestHarness) -> void:
	var lo := 0.0
	var hi := 1.0
	for m in range(16):
		var c0: float = hi if (m & 1) else lo
		var c1: float = hi if (m & 2) else lo
		var c2: float = hi if (m & 4) else lo
		var c3: float = hi if (m & 8) else lo
		var segs := Contour.segments(c0, c1, c2, c3)
		t.eq(Contour.case_of(c0, c1, c2, c3), m, "case %d round-trips" % m)
		if m == 0 or m == 15:
			t.eq(segs.size(), 0, "case %d is uniform" % m)
		elif m == 5 or m == 10:
			t.eq(segs.size(), 4, "case %d is a checkerboard and needs two segments" % m)
		else:
			t.eq(segs.size(), 2, "case %d is one segment" % m)


## The ambiguous cases have two equally valid readings and **the choice has to
## be fixed**, or the contour flips between them as neighbouring cells are dug
## and the wall shimmers. Called repeatedly with the same input it must give the
## same answer, and the two readings must actually differ.
func test_the_ambiguous_cases_resolve_the_same_way_every_time(t: TestHarness) -> void:
	for m in [5, 10]:
		var c0: float = 1.0 if (m & 1) else 0.0
		var c1: float = 1.0 if (m & 2) else 0.0
		var c2: float = 1.0 if (m & 4) else 0.0
		var c3: float = 1.0 if (m & 8) else 0.0
		var first := Contour.segments(c0, c1, c2, c3)
		for _i in range(8):
			t.eq(Contour.segments(c0, c1, c2, c3), first, "case %d is deterministic" % m)
	# And the tie-break is actually reading the average, not returning a
	# constant: a cell whose average sits the other side of the isovalue joins
	# the other way.
	var mostly_in := Contour.segments(1.0, 0.45, 1.0, 0.45)
	var mostly_out := Contour.segments(0.55, 0.0, 0.55, 0.0)
	t.ok(mostly_in != mostly_out, "the checkerboard tie-break reads the cell average")


## **The promise that keeps the player honest with the game.** Collision is on
## the cell grid; the contour is a picture. If the picture reaches into a cell
## the ship can fly through, the player sees rock where there is none, and if it
## pulls back out of a solid cell they hit rock that is not drawn.
func test_the_surface_never_reaches_into_space_you_can_fly_through(t: TestHarness) -> void:
	# A carved shaft with a side branch: plenty of surface, and every kind of
	# corner the algorithm has a case for.
	var cells: Array = []
	for d in range(10, 40):
		cells.append(Vector2i(0, d))
	for x in range(1, 6):
		cells.append(Vector2i(x, 24))
	cells.append(Vector2i(1, 25))
	cells.append(Vector2i(-1, 30))
	var w := _open_pocket(3, cells)

	var worst := 0.0
	var checked := 0
	for c in cells:
		var v: Vector2i = c
		t.ok(w.is_open(v.x, v.y), "the fixture cell (%d,%d) really is open" % [v.x, v.y])
		worst = maxf(worst, Contour.encroachment(w, v.x, v.y))
		checked += 1
	t.gt(float(checked), 30.0, "the fixture is big enough to be a test")
	t.lt(worst, Contour.MAX_ENCROACH,
		"the drawn surface reaches %.3f of a cell into open space, over the %.2f allowed"
		% [worst, Contour.MAX_ENCROACH])


## A dug cell must actually change the picture. If it does not, the contour is
## reading something other than the fill and the whole technique is inert.
func test_digging_a_cell_changes_the_surface(t: TestHarness) -> void:
	var solid := World.new(3)
	var before := Contour.build(solid, -2, 2, 28, 32)
	var dug := _open_pocket(3, [Vector2i(0, 30)])
	var after := Contour.build(dug, -2, 2, 28, 32)
	t.eq(before.size(), 0, "untouched rock draws no surface at all")
	t.gt(float(after.size()), 0.0, "cutting one cell puts a surface around it")


## A part-cut cell moves the surface before it breaks, which is what makes
## damage visible rather than a number.
func test_partial_damage_is_visible_in_the_surface(t: TestHarness) -> void:
	var w := World.new(3)
	var d := 30
	while w.is_open(0, d):
		d += 1
	var hardness := Tuning.hardness_at(float(d))
	var untouched := Contour.build(w, -2, 2, d - 2, d + 2)
	w.cut(0, d, hardness * 0.6)
	var damaged := Contour.build(w, -2, 2, d - 2, d + 2)
	t.eq(untouched.size(), 0, "before the cut there is nothing to draw")
	t.gt(float(damaged.size()), 0.0, "a cell part-way cut already shows a surface")
	t.ok(not w.is_open(0, d), "and it is still solid, so the picture leads the rule")


## The mesh has to stay inside a budget, because it is rebuilt on every dig.
func test_the_surface_stays_inside_its_budget(t: TestHarness) -> void:
	var cells: Array = []
	for d in range(4, 60):
		for x in range(-8, 9):
			if (x + d) % 3 != 0:
				cells.append(Vector2i(x, d))
	var w := _open_pocket(9, cells)
	var segs := Contour.build(w, -12, 12, 0, 64)
	t.gt(float(segs.size()), 100.0, "the worst-case fixture produces a real amount of surface")
	t.lt(float(segs.size()), 12000.0,
		"a deliberately shredded 25x65 window stays under the vertex budget")
	t.eq(segs.size() % 2, 0, "segments come in pairs of endpoints")


## The face the player looks at and the line the walls are extruded along have
## to come from the same case table, or they disagree along every edge.
func test_the_solid_face_matches_the_case(t: TestHarness) -> void:
	t.eq(Contour.fill_polygon(1.0, 1.0, 1.0, 1.0).size(), 1, "solid rock has one full face")
	t.approx(Contour.fill_area(1.0, 1.0, 1.0, 1.0), 1.0, 1e-5, "and it fills the cell")
	t.eq(Contour.fill_polygon(0.0, 0.0, 0.0, 0.0).size(), 0, "open air has no face")
	t.approx(Contour.fill_area(0.0, 0.0, 0.0, 0.0), 0.0, 1e-6, "and no area")

	for m in range(1, 15):
		var c0: float = 1.0 if (m & 1) else 0.0
		var c1: float = 1.0 if (m & 2) else 0.0
		var c2: float = 1.0 if (m & 4) else 0.0
		var c3: float = 1.0 if (m & 8) else 0.0
		var area := Contour.fill_area(c0, c1, c2, c3)
		t.gt(area, 0.0, "case %d covers some of the cell" % m)
		t.lt(area, 1.0, "case %d does not cover all of it" % m)
		for poly in Contour.fill_polygon(c0, c1, c2, c3):
			t.gt(float(poly.size()), 2.0, "case %d yields a real polygon, not a line" % m)


## **The picture draws the rules.** Half the rock gone has to look like half the
## rock gone: the drawn area tracks the number the simulation holds, so damage
## is visible rather than announced.
func test_the_drawn_area_tracks_the_fill(t: TestHarness) -> void:
	var last := 2.0
	for step in range(11):
		var f := 1.0 - 0.1 * float(step)
		# One cell of a four-cell lattice being cut away.
		var area := Contour.fill_area(f, 1.0, 1.0, 1.0)
		t.ok(area <= last + 1e-6, "cutting further never draws MORE rock (fill %.1f)" % f)
		last = area
	t.approx(Contour.fill_area(1.0, 1.0, 1.0, 1.0), 1.0, 1e-5, "untouched draws the whole cell")
	t.lt(Contour.fill_area(0.0, 1.0, 1.0, 1.0), 1.0, "a cut corner draws less than the whole cell")
	t.gt(Contour.fill_area(0.0, 1.0, 1.0, 1.0), 0.5, "and still draws most of it")


## The checkerboard has to split into two pieces when the tie-break says
## disconnected, or the walk produces a bowtie and the mesh folds through itself.
func test_a_disconnected_checkerboard_is_two_pieces(t: TestHarness) -> void:
	# 0.6 and 0.0, not 1.0 and 0.0: the latter averages to exactly the isovalue,
	# which is the tie itself rather than either side of it. A fixture sitting
	# precisely on the boundary tests the comparison operator, not the design.
	t.approx(Contour._centre(1.0, 0.0, 1.0, 0.0), Tuning.CONTOUR_ISO, 1e-9,
		"the obvious fixture really does sit exactly on the tie")
	var split := Contour.fill_polygon(0.6, 0.0, 0.6, 0.0)
	t.eq(split.size(), 2, "an isolated checkerboard is two separate triangles")
	for poly in split:
		t.eq(poly.size(), 3, "and each piece is a triangle")
	var joined := Contour.fill_polygon(1.0, 0.45, 1.0, 0.45)
	t.eq(joined.size(), 1, "a checkerboard whose average is inside stays one piece")
