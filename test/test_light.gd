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

	# **Measured as a MEAN, not as a count over a threshold.**
	#
	# `shadow_at` filters across neighbouring bearings now, so it answers in
	# fifths rather than in 0 or 1, and a wall face a few centimetres from a
	# corner correctly comes back part shadowed: that penumbra is the whole point
	# of the filter and it is what stopped the lamp reading as a fan of separate
	# beams. A binary count called every one of those a failure and put the
	# fraction at 10.4% against a 5% bound, on a fan that had got BETTER.
	#
	# The claim has not moved: a wall fronting the lamp is lit, not sitting in its
	# own shadow. The mean says that more precisely than a threshold did.
	var total := 0
	var sum := 0.0
	var darkest := 1.0
	for d in range(22, 39):
		for x in [1, -1]:
			if w.is_open(x, d):
				continue
			if not w.is_open(x - signi(x), d):
				continue                       ## only faces that front the shaft
			for k in range(9):
				var along := -0.45 + 0.1125 * float(k)
				var p := Vector2(float(x) - 0.45 * float(signi(x)), float(d) + along)
				var v := Light.shadow_at(fan, from, p)
				sum += v
				darkest = minf(darkest, v)
				total += 1
	t.gt(float(total), 100.0, "the fixture samples enough of the wall to mean something")
	var mean := sum / float(maxi(total, 1))
	t.gt(mean, 0.65,
		"the first wall averages %.2f lit; the fan is recording the near side of it"
		% mean)
	# **And no part of a fronting wall is BLACK.** This is the assertion that
	# carries the claim now. Measured with a single tap the darkest sample was
	# 0.000 - parts of the wall genuinely sat in their own shadow, and the old
	# threshold count let it through at 4.9%; with the filter the darkest is
	# 0.40. A penumbra is a fifth or two off full. Its own shadow is nothing.
	t.gt(darkest, 0.15,
		"some of the first wall reads %.2f, which is its own shadow rather than a soft edge"
		% darkest)


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


## **The light is one glow, not a fan of separate beams.**
##
## His report on the first phone build: "there appears to be multiple separate
## beams when using the light on certain settings rather than a glow that extends
## from the front of the ship." The starburst is the fan's angular resolution
## showing through: two adjacent rays that hit different occluders store very
## different distances, a single tap blends those DISTANCES, and the boundary
## lands as a hard wedge.
##
## The fixture is a ragged wall on purpose. A smooth tunnel cannot show this at
## all - which is why the first attempt to measure it on a carved shaft found
## nothing and proved nothing: the feathered brush had already removed every
## protrusion, so there was no artefact left for the filter to be tested against.
##
## The measure is how much the lit fraction JUMPS between neighbouring bearings
## on a ring around the lamp. A starburst is large jumps; a glow is small ones.
func test_the_shadow_is_a_glow_and_not_a_fan_of_beams(t: TestHarness) -> void:
	var w := World.new(77)
	var cx := 0
	var cd := 30
	# Open ground with single-cell PILLARS left standing in it. Every pillar
	# throws its own wedge, so a ring drawn past them crosses boundary after
	# boundary, which is exactly the frame he photographed. A smooth carved
	# tunnel cannot show this at all - the first attempt to measure it on one
	# found no difference and proved nothing, because the feathered brush had
	# already removed every protrusion there was.
	for d in range(cd - 12, cd + 13):
		for x in range(cx - 12, cx + 13):
			var r := Vector2(float(x - cx), float(d - cd)).length()
			if r > 11.0:
				continue
			if r > 2.5 and r < 7.0 and (absi(x) * 5 + absi(d) * 3) % 7 == 0:
				continue                       ## a pillar, left standing
			w.fill[w.idx(x, d)] = 0.0
			w.mat[w.idx(x, d)] = Ore.AIR

	var from := Vector2(float(cx), float(cd))
	var fan := Light.fan(w, from, 12.0)
	var lit: Array[float] = []
	var n := 240
	for i in range(n):
		var a := TAU * float(i) / float(n)
		var p := from + Vector2(cos(a), sin(a)) * 9.0
		lit.append(Light.shadow_at(fan, from, p))

	# The fixture has to actually cast something, or this passes on a lit room.
	var mean := 0.0
	for v in lit:
		mean += v
	mean /= float(n)
	t.gt(mean, 0.05, "the ragged chamber casts no shadow at all, so nothing is being tested")
	t.lt(mean, 0.98, "the ragged chamber shadows nothing, so nothing is being tested")

	# **The discriminating number is the WORST jump, not the mean.** A single tap
	# can only answer 0 or 1, so every boundary is a step of a whole unit; five
	# taps answer in fifths and a boundary is crossed in five steps. Measured on
	# this fixture: worst 1.000 with 22 hard edges unfiltered, worst 0.200 and
	# none with the filter. The MEAN jump barely moves between the two (0.092 to
	# 0.082), because the number of boundaries is the same either way - it was
	# the first thing tried and it does not separate them.
	var worst := 0.0
	var hard := 0
	for i in range(n):
		var d := absf(lit[i] - lit[(i + n - 1) % n])
		worst = maxf(worst, d)
		if d > 0.5:
			hard += 1
	t.eq(hard, 0,
		"%d bearings step by more than half a unit, which draws as that many hard-edged beams" % hard)
	t.lt(worst, 0.5,
		"the lit fraction jumps %.2f between neighbouring bearings, which is a wedge with an edge on it"
			% worst)


## **The lamp lights the rock it is buried in.**
##
## The plow leaves the hull inside material it is still cutting, which means the
## lamp's own cell is routinely NOT passable. The spill only took light from open
## neighbours, so a buried lamp had no lit neighbour anywhere, every face within
## reach returned zero, and **the light went out exactly while the player was
## digging** - which is the state the game spends most of its time in.
##
## He photographed it: a ship in total blackness at 18 m with the power at 87%.
## The report was that the ship "just drives directly through", and half of that
## was the picture going dark rather than anything about the speed.
func test_a_buried_lamp_still_lights_the_face_it_is_cutting(t: TestHarness) -> void:
	# Solid rock in every direction, with the lamp inside it. No tunnel at all,
	# which is the worst case and the one the plow creates on its first bite.
	var w := World.new(11)
	var ox := 0
	var od := 30
	t.ok(not w.is_open(ox, od), "the fixture buries the lamp, or nothing is being tested")

	var field := Light.flood(w, ox, od)
	t.approx(Light.at(field, 0, 0), 1.0, 1.0e-4,
		"the flood does not light its own origin, so there is no lamp at all")

	var lit := Light.spill(w, field, ox, od)
	for c in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		t.gt(Light.at(lit, c.x, c.y), 0.5,
			"the face at %s beside a buried lamp reads %.2f, so the lamp is inside a rock that eats it"
				% [str(c), Light.at(lit, c.x, c.y)])

	# And it is still LOCAL: burying the lamp must not light the whole window,
	# or the fix has replaced a dark game with a flat one.
	t.approx(Light.at(lit, 6, 0), 0.0, 1.0e-4,
		"rock six cells from a buried lamp is lit, so the spill has stopped being a spill")
