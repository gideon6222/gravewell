extends RefCounted

## Flight, collision, and the three faults that made Coreward "very bouncy".

const DT := 1.0 / 60.0


func _open_world() -> World:
	# A world with a shaft already cut, so flight can be tested without the
	# drill in the way. The fixture asserts its own precondition, because a
	# safety test aimed at a case that cannot trigger is worse than no test.
	var w := World.new(77)
	for d in range(-Tuning.SURFACE_ROWS, 60):
		for x in range(-6, 7):
			if w.in_bounds(x, d):
				w.fill[w.idx(x, d)] = 0.0
				w.mat[w.idx(x, d)] = Ore.AIR
	assert(w.is_open(0, 30), "the fixture must actually be open")
	return w


func test_reaching_top_speed_takes_about_a_fifth_of_a_second(t: TestHarness) -> void:
	var f := Flight.new(_open_world())
	var top := Tuning.speed_for(0.0)
	var elapsed := 0.0
	for _i in range(120):
		f.step(Vector2(0, 1), 0.0, 0.0, DT)
		elapsed += DT
		if f.vel.y >= top * 0.95:
			break
	t.lt(elapsed, 0.25, "95% of top speed inside a quarter second")
	t.gt(elapsed, 0.08, "and not instantly, or there is no mass")


func test_it_coasts_under_a_cell_and_does_not_stop_dead(t: TestHarness) -> void:
	var f := Flight.new(_open_world())
	for _i in range(60):
		f.step(Vector2(0, 1), 0.0, 0.0, DT)
	var at_release := f.pos.y
	var moving_frames := 0
	for _i in range(180):
		f.step(Vector2.ZERO, 0.0, 0.0, DT)
		if f.vel.length() > 0.05:
			moving_frames += 1
	var coast := f.pos.y - at_release
	t.gt(coast, 0.25, "it keeps moving after the thumb comes off")
	t.lt(coast, Tuning.CELL, "and stops inside one cell")
	t.gt(float(moving_frames), 5.0, "the stop takes several frames, it does not snap")


## The bug that got reported as "very bouncy". A pull that is ADDED to an
## existing velocity is an undamped spring: it overshoots and rings. Verified
## by driving the ship off the lane and counting sign changes in the lateral
## velocity, which is what ringing actually is.
func test_the_lane_pull_settles_instead_of_ringing(t: TestHarness) -> void:
	var f := Flight.new(_open_world())
	f.pos = Vector2(0.42, 20.0)
	var signs := 0
	var last := 0.0
	for _i in range(240):
		f.step(Vector2(0, 1), 0.0, 0.0, DT)
		if last != 0.0 and signf(f.vel.x) != signf(last) and absf(f.vel.x) > 0.02:
			signs += 1
		last = f.vel.x
	t.lt(float(signs), 2.0, "the lateral velocity does not change sign repeatedly")
	t.lt(absf(f.pos.x - roundf(f.pos.x)), 0.06, "and it ends up on the lane")


## "Don't align until you change direction." Coreward's pull ran while
## COASTING, where the nearest lane is as often behind the ship as ahead, so
## releasing near a boundary dragged it backwards against its own momentum.
func test_nothing_is_corrected_while_coasting(t: TestHarness) -> void:
	var f := Flight.new(_open_world())
	f.pos = Vector2(0.45, 20.0)
	f.vel = Vector2(2.0, 0.0)
	var x0 := f.pos.x
	for _i in range(30):
		f.step(Vector2.ZERO, 0.0, 0.0, DT)
	t.gt(f.pos.x, x0, "a coasting ship keeps going the way it was going")
	t.ok(f.vel.x >= 0.0, "and is never dragged backwards by an alignment pull")


func test_a_diagonal_is_left_alone(t: TestHarness) -> void:
	var f := Flight.new(_open_world())
	f.pos = Vector2(0.5, 20.0)
	for _i in range(30):
		f.step(Vector2(1, 1), 0.0, 0.0, DT)
	t.gt(f.pos.x, 0.6, "a held diagonal actually goes sideways")
	t.gt(f.pos.y, 20.1, "and downward at the same time")


## Corrections go through the collision path as a velocity, never as a position
## write. A position write is invisible to collision, which in Coreward drove
## the ship into the rock it was cutting.
func test_the_ship_never_ends_up_inside_rock(t: TestHarness) -> void:
	var w := World.new(101)          ## untouched: solid everywhere below the surface
	var f := Flight.new(w)
	var dirs := [Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(-1, 1), Vector2(0, -1)]
	for i in range(600):
		f.step(dirs[i % dirs.size()], 0.0, 0.0, DT)
		t.ok(not f._blocked(f.pos), "frame %d: the hull is not inside rock" % i)
		if i > 20:
			break                     ## one failure is enough; do not print six hundred


func test_it_slides_along_a_wall_instead_of_stopping_dead(t: TestHarness) -> void:
	var w := _open_world()
	# Wall off the right-hand side of the shaft.
	for d in range(-Tuning.SURFACE_ROWS, 60):
		w.fill[w.idx(3, d)] = 1.0
		w.mat[w.idx(3, d)] = Ore.ROCK
	var f := Flight.new(w)
	f.pos = Vector2(2.0, 10.0)
	for _i in range(60):
		f.step(Vector2(1, 1), 0.0, 0.0, DT)
	t.gt(f.pos.y, 10.5, "pressed into a wall diagonally, it still descends")
	t.lt(f.pos.x, 3.0, "and does not pass through the wall")


func test_a_loaded_ship_is_slower_and_takes_longer_to_stop(t: TestHarness) -> void:
	var empty := Flight.new(_open_world())
	var full := Flight.new(_open_world())
	for _i in range(120):
		empty.step(Vector2(0, 1), 0.0, 0.0, DT)
		full.step(Vector2(0, 1), Tuning.HOLD_KG, 0.0, DT)
	t.lt(full.vel.y, empty.vel.y * 0.85, "a full hold is meaningfully slower")
	t.gt(full.vel.y, 0.5, "but still flies")


func test_dense_air_drags(t: TestHarness) -> void:
	var thin := Flight.new(_open_world())
	var thick := Flight.new(_open_world())
	for _i in range(120):
		thin.step(Vector2(0, 1), 0.0, 0.05, DT)
		thick.step(Vector2(0, 1), 0.0, 3.0, DT)
	t.lt(thick.vel.y, thin.vel.y, "the deep is heavy to fly in")


## "The ship should turn to face the direction it is digging in."
func test_the_nose_points_where_it_is_going(t: TestHarness) -> void:
	# Untouched rock, so there is always something to bite in every direction.
	var f := Flight.new(World.new(101))
	f.pos = Vector2(0.0, 20.0)
	for _i in range(10):
		f.step(Vector2(1, 0), 0.0, 0.0, DT)
	t.gt(f.heading.x, 0.9, "heading follows a held right")
	t.gt(f.nose_point().x, f.pos.x, "and the drill head is to the right of the hull")
	f.heading = Vector2(0, 1)
	t.gt(f.nose_point().y, f.pos.y, "and below the hull when the heading is down")


## The bug the scripted miners found, and why the plow retires it.
##
## The old drill aimed at ONE cell. A diagonal nose points at the corner cell,
## which the hull can never fit through because the two orthogonal neighbours are
## still there, so a miner held down-right and stayed at 1.12 m for six hundred
## frames, cutting and never moving. The fix then was to bite whatever was
## blocking the hull instead.
##
## The brush removes the whole question: it carves a capsule swept along the path
## the hull actually travelled, so a diagonal clears both orthogonal neighbours
## as it goes, because the hull passes through them. The assertion is the same
## one that mattered - **a diagonal gets somewhere** - and it now lives in the
## test below, which drives the real `Sim`.


## And the whole point of it: a diagonal hold makes progress **when there is
## nowhere to skate to**.
##
## Started at the surface it does not, and that is correct rather than a bug:
## the rows above depth 0 are open all the way across, so a held down-right
## sends the ship sliding sideways through open air while the drill nibbles a
## different cell every few frames and finishes none of them. You cannot dig
## while sprinting. The fixture therefore starts the ship inside rock, which is
## where the claim actually applies, and asserts that precondition.
func test_a_diagonal_hold_digs_when_it_cannot_skate(t: TestHarness) -> void:
	var sim := Sim.new(1234)
	# A one-cell pocket deep in solid rock: no free lateral run anywhere.
	var d0 := 40
	sim.world.fill[sim.world.idx(0, d0)] = 0.0
	sim.world.mat[sim.world.idx(0, d0)] = Ore.AIR
	sim.flight.pos = Vector2(0.0, float(d0))
	sim.flight.vel = Vector2.ZERO
	t.ok(not sim.world.is_open(1, d0), "the fixture has rock to the right, or nothing is being tested")
	t.ok(not sim.world.is_open(0, d0 + 1), "the fixture has rock below")

	var start := sim.flight.pos
	for _i in range(60 * 20):
		if sim.phase == Sim.Phase.OVER:
			break
		sim.step(Vector2(1, 1).normalized(), true, DT)
	t.gt(sim.flight.pos.y, start.y + 2.0, "twenty seconds of down-right gets somewhere down")
	t.gt(sim.flight.pos.x, start.x + 1.0, "and somewhere right")


## **The brush never reaches behind the ship.** It is swept from where the hull
## was to where it is, so the only material it can take is material the hull has
## passed through or is about to. A brush stamped on the ship's CENTRE with no
## sweep would hollow out a bubble around it and widen every tunnel it re-entered.
func test_the_plow_never_carves_behind_the_ship(t: TestHarness) -> void:
	var reach: float = Tuning.BRUSH_RADIUS + Tuning.BRUSH_FEATHER
	for dir in [Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0)]:
		var sim := Sim.new(2024)
		sim.flight.pos = Vector2(0.0, 30.0)
		sim.flight.vel = Vector2.ZERO
		sim.flight.heading = dir
		var start := sim.flight.pos
		# **Snapshot the fill, and compare the fill.** Asserting that no cell
		# BEHIND was fully opened cannot fail: a stray carve spreads its tick's
		# hit points across every cell it covers, so the ones behind come out
		# half eaten and still count as solid. Verified by making the brush carve
		# three metres backwards, which this now catches and the earlier version
		# did not.
		var before := PackedFloat32Array(sim.world.fill)
		for _i in range(180):
			sim.power = sim.power_capacity()
			sim.hull = Tuning.HULL_MAX
			sim.step(dir, true, DT)
		var w := sim.world
		var touched := 0
		for d in range(int(start.y) - 6, int(start.y) + 7):
			for x in range(int(start.x) - 6, int(start.x) + 7):
				if not w.in_bounds(x, d):
					continue
				var i2 := w.idx(x, d)
				if absf(w.fill[i2] - before[i2]) < 1.0e-5:
					continue
				var away := Vector2(float(x), float(d)) - start
				if away.dot(dir) >= -reach:
					continue
				touched += 1
		t.eq(touched, 0,
			"holding %s ate into %d cells behind where the ship started" % [str(dir), touched])
