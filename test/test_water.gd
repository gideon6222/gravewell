extends RefCounted

## **Drown: the water you let in.**
##
## Every other pressure in this game arrives on a schedule - the air thickens
## with depth, the hull drains past the Line, the collapse rises on a clock. This
## one is caused by the player. Water fills the tunnels from the lowest point up,
## so the shaft you cut becomes a well, and the more you open below the surface
## the higher that surface climbs.
##
## The plan's line for the class: "Water fills tunnels from the lowest point up.
## A shaft you cut becomes a well. Buoyancy changes flight."

const DT := 1.0 / 60.0


func _drown(planet: int = 3) -> Sim:
	return Sim.new(planet, Classes.DROWN)


## Hold down and keep the ship alive, so the subject is the water and not the
## battery. Returns the sim.
func _dig(s: Sim, seconds: float) -> Sim:
	for _i in int(round(seconds / DT)):
		s.power = s.power_capacity()
		s.hull = Tuning.HULL_MAX
		s.step(Vector2(0, 1), true, DT)
	return s


# ── the table ─────────────────────────────────────────────────────────────

## **Only Drown has water.** A rule that fires on every world is a rule the
## player cannot attribute to the world they are on.
func test_only_drown_floods(t: TestHarness) -> void:
	for id in [Classes.CINDER, Classes.RIME]:
		var w := World.new(3, id)
		t.ok(not Classes.floods(id), "%s floods, so the rule is not Drown's" % Classes.of(id)["name"])
		t.ok(not w.is_submerged(0, Tuning.CORE_DEPTH - 5),
			"%s has water at the bottom of it" % Classes.of(id)["name"])
	t.ok(Classes.floods(Classes.DROWN), "Drown does not flood, which is the whole class")


## The table starts below the surface, so the opening of a Drown descent is dry
## and the water is something you go down to rather than something you land in.
func test_the_table_starts_below_the_surface(t: TestHarness) -> void:
	var w := World.new(3, Classes.DROWN)
	t.gt(w.water_depth(), 10.0,
		"the water starts at %.1f m, so a Drown planet is wet before the player has done anything"
			% w.water_depth())
	t.lt(w.water_depth(), float(Tuning.LINE_DEPTH),
		"the water starts below the Line, so most of a descent never meets it")


## **An open cell below the surface holds water, and a solid one does not.**
## Water is in the space you made, not in the rock.
func test_water_is_in_the_space_you_made(t: TestHarness) -> void:
	var w := World.new(3, Classes.DROWN)
	var d := int(w.water_depth()) + 6
	t.ok(not w.is_submerged(0, d), "solid rock below the table is already flooded")
	w.set_fill(0, d, 0.0)
	t.ok(w.is_submerged(0, d), "a cell opened below the table did not flood")
	t.ok(not w.is_submerged(0, int(w.water_depth()) - 6),
		"a cell opened above the table flooded anyway, so the table means nothing")


## **The surface rises because YOU dug, and by how much.** This is the whole
## pressure: it is not a timer, and sitting still costs nothing.
func test_the_surface_rises_only_when_you_open_volume_below_it(t: TestHarness) -> void:
	var w := World.new(3, Classes.DROWN)
	var start := w.water_depth()

	# Open a chamber ABOVE the table. Nothing should happen: water does not run
	# uphill and there is no new room under the surface for it to spread into.
	for d in range(int(start) - 9, int(start) - 4):
		for x in range(-2, 3):
			w.set_fill(x, d, 0.0)
	t.approx(w.water_depth(), start, 1.0e-4,
		"digging above the water raised it, so the rule is a timer wearing a rule's clothes")

	# Now open the same volume BELOW it.
	for d in range(int(start) + 4, int(start) + 9):
		for x in range(-2, 3):
			w.set_fill(x, d, 0.0)
	t.lt(w.water_depth(), start - 0.05,
		"opening twenty-five cells under the water did not raise it at all")
	# And it is proportional, not a step: twice the room, twice the rise.
	var after_one := start - w.water_depth()
	for d in range(int(start) + 9, int(start) + 14):
		for x in range(-2, 3):
			w.set_fill(x, d, 0.0)
	var after_two := start - w.water_depth()
	t.gt(after_two, after_one * 1.5,
		"the second chamber raised the water far less than the first, so the rise is a step")


## Filling a cell back in gives the room back. A collapse in water is a reprieve,
## which is the kind of thing a player should be able to discover.
func test_sealing_a_cell_lowers_the_water_again(t: TestHarness) -> void:
	var w := World.new(3, Classes.DROWN)
	var d := int(w.water_depth()) + 5
	for x in range(-3, 4):
		w.set_fill(x, d, 0.0)
	var risen := w.water_depth()
	t.lt(risen, float(int(w.water_depth()) + 1), "the fixture did not raise the water")
	for x in range(-3, 4):
		w.set_fill(x, d, 1.0)
	t.approx(w.water_depth(), World.new(3, Classes.DROWN).water_depth(), 1.0e-3,
		"filling the room back in did not put the water back where it was")


# ── what being in it does ─────────────────────────────────────────────────

## **Submerged, the ship is slow and it floats.** Down becomes the expensive
## direction, which inverts the game's motion for one world.
func test_water_drags_and_lifts(t: TestHarness) -> void:
	var dry := Sim.new(3, Classes.DROWN)
	var wet := Sim.new(3, Classes.DROWN)
	# Two identical open shafts, one above the water and one below it.
	var top := int(dry.world.water_depth()) - 12
	var bottom := int(dry.world.water_depth()) + 12
	for s in [dry, wet]:
		for d in range(top - 6, bottom + 8):
			s.world.set_fill(0, d, 0.0)
	dry.flight.pos = Vector2(0.0, float(top))
	wet.flight.pos = Vector2(0.0, float(bottom))
	t.ok(not dry.world.is_submerged(0, top), "the dry fixture is dry")
	t.ok(wet.world.is_submerged(0, bottom), "the wet fixture is wet")

	for _i in range(90):
		for s in [dry, wet]:
			s.power = s.power_capacity()
			s.hull = Tuning.HULL_MAX
			s.step(Vector2(0, 1), false, DT)
	var dry_run: float = dry.flight.depth() - float(top)
	var wet_run: float = wet.flight.depth() - float(bottom)
	t.gt(dry_run, 1.0, "the dry ship did not move, so nothing is being compared")
	t.lt(wet_run, dry_run * 0.75,
		"the ship swims down at %.2f m against %.2f in air, which is not water" % [wet_run, dry_run])

	# And with nothing held, water pushes it UP while air lets it sit.
	var float_up := Sim.new(3, Classes.DROWN)
	for d in range(bottom - 10, bottom + 8):
		float_up.world.set_fill(0, d, 0.0)
	float_up.flight.pos = Vector2(0.0, float(bottom))
	float_up.flight.vel = Vector2.ZERO
	for _i in range(120):
		float_up.power = float_up.power_capacity()
		float_up.hull = Tuning.HULL_MAX
		float_up.step(Vector2.ZERO, false, DT)
	t.lt(float_up.flight.depth(), float(bottom) - 0.3,
		"a ship left alone underwater did not rise, so there is no buoyancy in it")


## **Drowning is the Line, and surfacing stops it.** A pressure with no off
## switch is a wall; this one has a way out that is always the same way out.
func test_the_hull_drains_under_water_and_stops_at_the_surface(t: TestHarness) -> void:
	var s := Sim.new(3, Classes.DROWN)
	var deep := int(s.world.water_depth()) + 20
	for d in range(int(s.world.water_depth()) - 8, deep + 4):
		s.world.set_fill(0, d, 0.0)
	s.flight.pos = Vector2(0.0, float(deep))
	s.hull = Tuning.HULL_MAX
	s.power = s.power_capacity()
	for _i in range(120):
		s.power = s.power_capacity()
		s.step(Vector2.ZERO, false, DT)
	var lost := Tuning.HULL_MAX - s.hull
	t.gt(lost, 0.5, "two seconds twenty metres under water cost no hull at all")

	# The same two seconds in air, on the same planet, costs nothing.
	var air := Sim.new(3, Classes.DROWN)
	var shallow := int(air.world.water_depth()) - 14
	for d in range(shallow - 6, shallow + 6):
		air.world.set_fill(0, d, 0.0)
	air.flight.pos = Vector2(0.0, float(shallow))
	air.hull = Tuning.HULL_MAX
	for _i in range(120):
		air.power = air.power_capacity()
		air.step(Vector2.ZERO, false, DT)
	t.approx(air.hull, Tuning.HULL_MAX, 0.01,
		"the hull drains above the water too, so surfacing is not a way out")


## Deeper under the surface is worse, so the water has a shape and not just an
## edge: a dive is a decision about how far.
func test_deeper_water_drains_faster(t: TestHarness) -> void:
	var table := World.new(3, Classes.DROWN).water_depth()
	var shallow := _drain_over(int(table) + 5)
	var deep := _drain_over(int(table) + 30)
	t.gt(deep, shallow * 1.4,
		"thirty metres down costs %.2f hull against %.2f at five, which is not a depth" % [deep, shallow])


func _drain_over(at: int) -> float:
	var s := Sim.new(3, Classes.DROWN)
	for d in range(at - 4, at + 4):
		s.world.set_fill(0, d, 0.0)
	s.flight.pos = Vector2(0.0, float(at))
	s.hull = Tuning.HULL_MAX
	for _i in range(60):
		s.power = s.power_capacity()
		s.step(Vector2.ZERO, false, DT)
	return Tuning.HULL_MAX - s.hull


## **The lamp does not reach as far through water.** Half of what makes a
## flooded tunnel read as flooded without a caption.
func test_water_shortens_the_lamp(t: TestHarness) -> void:
	var s := Sim.new(3, Classes.DROWN)
	var deep := int(s.world.water_depth()) + 10
	for d in range(deep - 6, deep + 4):
		s.world.set_fill(0, d, 0.0)
	s.power = s.power_capacity()
	# **The dry sample has to be above the SURFACE, not merely somewhere the
	# shaft has not been cut.** It used to sit two metres under the table and
	# passed only because the metre there happened not to be open yet, which
	# stopped being the deciding question the moment the ship could be under
	# water in a cell it was still cutting. The fixture asserts its own
	# precondition now rather than relying on one.
	s.flight.pos = Vector2(0.0, s.world.water_depth() - 6.0)
	t.ok(not s.world.submerged_at(s.flight.pos), "the dry sample is under water")
	var dry_reach := s.lamp_reach()
	s.flight.pos = Vector2(0.0, float(deep))
	t.ok(s.world.submerged_at(s.flight.pos), "the wet sample is not under water")
	var wet_reach := s.lamp_reach()
	t.lt(wet_reach, dry_reach * 0.8,
		"the lamp reaches %.2f m under water against %.2f in air" % [wet_reach, dry_reach])
	t.gt(wet_reach, 1.0, "the lamp goes out entirely under water, which is not a lamp")


# ── and it happens in a real descent ──────────────────────────────────────

## **A construct that can never be true fails as absence.** A scripted miner
## digging straight down a Drown planet has to actually get wet, or every
## assertion above is about a state the game cannot reach.
func test_a_real_descent_on_drown_gets_wet(t: TestHarness) -> void:
	var s := _drown(3)
	var wet_ticks := 0
	for _i in range(60 * 150):
		s.power = s.power_capacity()
		s.hull = Tuning.HULL_MAX
		s.step(Vector2(0, 1), true, DT)
		if s.submerged:
			wet_ticks += 1
		if s.flight.depth() > s.world.water_depth() + 25.0:
			break
	t.gt(s.flight.depth(), World.new(3, Classes.DROWN).water_depth(),
		"a hundred and fifty seconds of digging never reached the water")
	t.gt(wet_ticks, 60, "the ship reached the water and never counted as being in it")

	# And the shaft it cut is a well: the water came UP to meet the way home.
	t.lt(s.world.water_depth(), World.new(3, Classes.DROWN).water_depth() - 0.2,
		"digging a whole shaft below the table did not raise the water at all")
