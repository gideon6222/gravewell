extends RefCounted

## The lamp. Every case here is aimed at an artefact that cost real playtest
## rounds in Coreward, and the file to read before changing any of it is
## `techniques/coreward-propagated-lighting.md`.


## A world carved to order, so the claim being tested is about the solver and
## not about whatever the seed happened to generate.
func _carved(cells: Array) -> World:
	var w := World.new(5)
	for c in cells:
		var v: Vector2i = c
		if w.in_bounds(v.x, v.y):
			w.fill[w.idx(v.x, v.y)] = 0.0
			w.mat[w.idx(v.x, v.y)] = Ore.AIR
	return w


func _shaft(from_d: int, to_d: int) -> Array:
	var cells: Array = []
	for d in range(from_d, to_d + 1):
		cells.append(Vector2i(0, d))
	return cells


## **Open space comes out at exactly 1.** That is the whole design of the field:
## it stores how much LONGER the light's path had to be than a clear run, so
## only geometry can darken anything and a straight shaft is as bright at the
## bottom as at the top.
##
## Subtracting Euclidean distance instead of octile is the trap here: eight-way
## steps do not add up to a straight line, so it puts a permanent haze over open
## ground. A diagonal run is where that shows.
func test_open_ground_solves_to_exactly_one(t: TestHarness) -> void:
	var cells: Array = []
	for d in range(20, 41):
		for x in range(-10, 11):
			cells.append(Vector2i(x, d))
	var w := _carved(cells)
	var f := Light.flood(w, 0, 30)
	for d in range(-8, 9):
		for x in range(-8, 9):
			t.approx(Light.at(f, x, d), 1.0, 1e-4,
				"open cell (%d,%d) is fully lit, with no haze from the octile term" % [x, d])


func test_unopened_rock_is_black(t: TestHarness) -> void:
	var w := _carved(_shaft(20, 40))
	var f := Light.flood(w, 0, 30)
	t.approx(Light.at(f, 0, 0), 1.0, 1e-4, "the shaft the ship is in is lit")
	for x in [3, 4, 5, -3, -4, -5]:
		t.approx(Light.at(f, x, 0), 0.0, 1e-6,
			"rock %d cells into the wall gets no light at all" % absi(x))


## Light goes ROUND a corner, so a branch is dim rather than black, and it dims
## with how far round it had to go. This is the half he described as "light
## should fill those tunnels and spread to nearby rocks".
func test_light_turns_a_corner_and_dims_doing_it(t: TestHarness) -> void:
	var cells := _shaft(20, 40)
	# The branch is FOUR cells below the lamp, so the light has to travel down
	# the shaft and then along. A branch level with the lamp is a straight line
	# from it and is correctly lit to full: there is no detour to attenuate, and
	# what dims it there is distance falloff, which lives in the shader.
	for x in range(1, 9):
		cells.append(Vector2i(x, 34))
	var w := _carved(cells)
	var f := Light.flood(w, 0, 30)

	var last := 2.0
	for x in range(1, 9):
		var v := Light.at(f, x, 4)
		t.gt(v, 0.0, "the branch at x=%d gets some light" % x)
		t.lt(v, last + 1e-6, "and it is no brighter than the cell before it")
		last = v
	t.lt(Light.at(f, 8, 4), 0.9, "the far end of the branch is dimmer than open ground")
	t.gt(Light.at(f, 1, 4), Light.at(f, 8, 4), "and the near end is brighter than the far end")


## A side tunnel the player has never opened must be black. A point light does
## not know the rock is there and lights it exactly as brightly as the shaft,
## which is the difference between "the picture got darker" and "I can only see
## where my lamp reaches".
func test_an_unconnected_pocket_stays_dark(t: TestHarness) -> void:
	var cells := _shaft(20, 40)
	# A pocket two cells to the side with no path to the shaft.
	for d in range(28, 33):
		cells.append(Vector2i(4, d))
	var w := _carved(cells)
	var f := Light.flood(w, 0, 30)
	t.approx(Light.at(f, 4, 0), 0.0, 1e-6,
		"an open pocket with no path to the lamp is black, however close it is")
	t.gt(Light.at(f, 0, 5), 0.5, "while the connected shaft below is lit")


## Surfaces are lit by being NEAR a lit space. Without the spill every rock face
## is black, because the flood only ever reaches open cells and a wall is not
## one - and the game is then a black screen with a lit tunnel in it.
func test_rock_faces_pick_up_the_light_beside_them(t: TestHarness) -> void:
	var w := _carved(_shaft(20, 40))
	var f := Light.flood(w, 0, 30)
	var s := Light.spill(w, f, 0, 30)
	t.approx(Light.at(f, 1, 0), 0.0, 1e-6, "the wall gets nothing from the flood itself")
	t.gt(Light.at(s, 1, 0), 0.5, "but the wall beside the shaft is lit once it spills")
	t.approx(Light.at(s, 4, 0), 0.0, 1e-6, "and rock four cells in is still black")
	t.approx(Light.at(s, 0, 0), Light.at(f, 0, 0), 1e-6, "the spill leaves open cells alone")


## The rock dims over about three layers, which is the spec he gave in numbers
## rather than adjectives: "around 3 layers should be visible but start bright
## and dim quickly by the third. rocks any further than that should be almost
## completely black."
func test_the_wall_dims_over_about_three_layers(t: TestHarness) -> void:
	var cells := _shaft(20, 40)
	# Widen the shaft so there is a real wall to read into, then let the spill
	# carry light one layer at a time.
	for d in range(24, 37):
		cells.append(Vector2i(1, d))
	var w := _carved(cells)
	var f := Light.flood(w, 0, 30)
	var s := Light.spill(w, f, 0, 30)
	t.gt(Light.at(s, 2, 0), 0.4, "the first layer of rock is clearly lit")
	t.lt(Light.at(s, 3, 0), 0.05, "and the layer behind it is nearly gone")
	t.approx(Light.at(s, 5, 0), 0.0, 1e-6, "five layers in is completely black")


## **The artefact that cost five rounds.** A wall's face is the surface the
## light is falling ON and has to stay lit; shadow starts BEHIND it. Recording
## where the ray leaves the cell instead of the cell's far corner put thirteen
## per cent of every wall face into its own shadow, and on screen that is a hard
## diagonal cut across every single block in the frame.
##
## The test has to interpolate the way the shader does and assert a RATIO. A
## nearest-ray lookup cannot see the artefact at all, because it only exists
## once two rays are blended, and sampling cell centres cannot see it either,
## because a centre passes under both rules.
func test_the_first_wall_is_lit_not_in_its_own_shadow(t: TestHarness) -> void:
	var cells := _shaft(20, 40)
	for x in range(1, 7):
		cells.append(Vector2i(x, 34))          ## a branch, so there are real corners
	var w := _carved(cells)
	var from := Vector2(0.0, 30.0)
	var fan := Light.fan(w, from, 18.0)

	var lit := 0
	var shadowed := 0
	# Sample ACROSS each wall face, not at its centre.
	for d in range(22, 39):
		for x in [1, -1]:
			if w.is_open(x, d):
				continue
			if not w.is_open(x - signi(x), d):
				continue                       ## only faces that front the shaft
			for k in range(9):
				var along := -0.45 + 0.1125 * float(k)
				var p := Vector2(float(x) - 0.45 * float(signi(x)), float(d) + along)
				if Light.shadow_at(fan, from, p) > 0.5:
					lit += 1
				else:
					shadowed += 1
	var total := lit + shadowed
	t.gt(float(total), 100.0, "the fixture samples enough of the wall to mean something")
	var frac := float(shadowed) / float(maxi(total, 1))
	t.lt(frac, 0.05,
		"%.1f%% of the first wall is in its own shadow; the fan is recording the near side"
		% (frac * 100.0))


## And the fan must still actually cast a shadow, or the test above passes by
## the fan doing nothing at all. A construct that cannot fail is untested.
func test_the_fan_really_does_shadow_something(t: TestHarness) -> void:
	var cells := _shaft(20, 40)
	for x in range(1, 9):
		cells.append(Vector2i(x, 34))
	var w := _carved(cells)
	var from := Vector2(0.0, 30.0)
	var fan := Light.fan(w, from, 20.0)
	# A point far down the branch, behind the corner the branch turns at.
	var behind := Vector2(7.0, 34.0)
	t.approx(Light.shadow_at(fan, from, behind), 0.0, 1e-6,
		"a point round a corner from the lamp is in shadow")
	t.approx(Light.shadow_at(fan, from, Vector2(0.0, 33.0)), 1.0, 1e-6,
		"a point straight down the open shaft is not")


## Two lights, not one, and the difference has to be real. Sharing one number
## made every side passage read as a hole and made three rounds of playtest
## notes point at the wrong thing.
func test_surface_light_and_air_light_are_different_numbers(t: TestHarness) -> void:
	var cells := _shaft(20, 40)
	for x in range(1, 9):
		cells.append(Vector2i(x, 34))
	var w := _carved(cells)
	var from := Vector2(0.0, 30.0)
	var f := Light.flood(w, 0, 30)
	var s := Light.spill(w, f, 0, 30)
	var fan := Light.fan(w, from, 20.0)

	# Down the branch, behind the corner: the AIR is shadowed, the wall face
	# beside it is not, because a surface is lit by being near a lit space.
	var air := Light.at(f, 7, 4) * Light.shadow_at(fan, from, Vector2(7.0, 34.0))
	var surface := Light.at(s, 7, 5)
	t.approx(air, 0.0, 1e-6, "the air round the corner is shadowed")
	t.gt(surface, 0.0, "the wall beside it is still lit")
	t.gt(surface - air, 0.0, "the two terms genuinely differ where the corner is")


## The solve has to be cheap enough to run on a cell change. This is a bound,
## not a benchmark: it fails if someone makes it quadratic.
func test_the_solve_is_cheap_enough_to_run_on_a_dig(t: TestHarness) -> void:
	var cells: Array = []
	for d in range(10, 60):
		for x in range(-12, 13):
			cells.append(Vector2i(x, d))
	var w := _carved(cells)
	var t0 := Time.get_ticks_usec()
	for _i in range(10):
		Light.flood(w, 0, 34)
	var per := float(Time.get_ticks_usec() - t0) / 10000.0
	t.lt(per, 60.0, "a flood over the worst-case open window takes %.1f ms" % per)
