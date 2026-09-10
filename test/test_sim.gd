extends RefCounted

## The descent: the three clocks, the uplink, the hold, and the ways it ends.

const DT := 1.0 / 60.0


func _drive(sim: Sim, dir: Vector2, drilling: bool, seconds: float) -> void:
	for _i in range(int(seconds / DT)):
		if sim.phase == Sim.Phase.OVER:
			return
		sim.step(dir, drilling, DT)


## Doing nothing must lose. A wear clock makes caution a cost; without one there
## are no stakes and every balance number below means nothing.
func test_doing_nothing_loses(t: TestHarness) -> void:
	var sim := Sim.new(1)
	_drive(sim, Vector2.ZERO, false, 60.0 * 45.0)
	t.eq(sim.phase, Sim.Phase.OVER, "an idle ship eventually runs out")
	t.approx(sim.credits, 0.0, 1e-6, "and has banked nothing at all")


## Going dark is a verb, not a wait: it has to actually buy time.
func test_going_dark_buys_time(t: TestHarness) -> void:
	var lit := Sim.new(1)
	lit.lamp_mode = Tuning.Lamp.FLOOD
	_drive(lit, Vector2.ZERO, false, 120.0)
	var dark := Sim.new(1)
	dark.lamp_mode = Tuning.Lamp.DARK
	_drive(dark, Vector2.ZERO, false, 120.0)
	t.gt(dark.power, lit.power, "sitting dark keeps more power than sitting lit")
	t.gt(dark.power, Tuning.POWER_MAX * 0.99, "and actually recovers toward full")


## The whole reason the lamp is not just a bar: being in trouble has to LOOK
## like the world closing in.
func test_running_low_closes_the_world_in(t: TestHarness) -> void:
	var sim := Sim.new(1)
	var full := sim.lamp_reach()
	sim.power = Tuning.POWER_MAX * 0.5
	t.approx(sim.lamp_reach(), full, 1e-5, "half power does not dim the lamp")
	sim.power = Tuning.POWER_MAX * 0.10
	t.lt(sim.lamp_reach(), full * 0.8, "a tenth of a tank visibly shortens the reach")
	sim.power = 0.001
	t.gt(sim.lamp_reach(), 0.0, "and it never goes fully black, which would read as a crash")


## The drill NEVER refuses. His ask: "make it so I can always dig but if the
## hull is full, just leave the resources floating in place for me to pick up
## later." A full hold that stops the drill is a wall that asks nothing.
func test_a_full_hold_never_stops_the_drill(t: TestHarness) -> void:
	var sim := Sim.new(3)
	sim.hold = {Ore.IRON: {"kg": Tuning.HOLD_KG, "value": 10.0, "count": 1}}
	sim.load_kg = Tuning.HOLD_KG
	var before_depth := sim.flight.depth()
	_drive(sim, Vector2(0, 1), true, 12.0)
	t.gt(sim.flight.depth(), before_depth + 2.0, "it still digs with a full hold")
	t.gt(float(sim.drops.size()), 0.0, "and what it cuts is left lying where it fell")
	t.approx(sim.load_kg, Tuning.HOLD_KG, 1e-4, "the hold never goes over capacity")


func test_dropped_ore_can_be_picked_up_later(t: TestHarness) -> void:
	var sim := Sim.new(3)
	sim.hold = {Ore.IRON: {"kg": Tuning.HOLD_KG, "value": 10.0, "count": 1}}
	sim.load_kg = Tuning.HOLD_KG
	_drive(sim, Vector2(0, 1), true, 12.0)
	var left := sim.drops.size()
	t.gt(float(left), 0.0, "the fixture actually produced drops")
	# Empty the hold where it stands, then come back past them.
	sim.hold = {}
	sim.load_kg = 0.0
	_drive(sim, Vector2(0, -1), false, 8.0)
	t.lt(float(sim.drops.size()), float(left), "flying back over them picks them up")
	t.gt(sim.load_kg, 0.0, "and they land in the hold")


## Selling is an action taken in place. The cost has to be real and visible,
## because "Right now it doesnt say it costs anything, so it feels free."
func test_uplinking_costs_power_and_banks_the_value(t: TestHarness) -> void:
	var sim := Sim.new(5)
	_drive(sim, Vector2(0, 1), true, 25.0)
	t.gt(sim.load_kg, 0.0, "the fixture actually mined something")
	var value := sim.hold_value()
	var power_before := sim.power
	var cost := sim.uplink_cost()
	var got := sim.uplink()
	t.approx(got, value, 1e-4, "the uplink banks exactly what the hold was worth")
	t.approx(sim.credits, value, 1e-4, "and it lands in credits")
	t.approx(sim.power, power_before - cost, 1e-4, "and it costs exactly what it said it would")
	t.approx(sim.load_kg, 0.0, 1e-6, "the hold is empty afterwards")
	t.ok(not sim.can_uplink(), "an empty hold cannot be uplinked")


func test_an_uplink_you_cannot_afford_does_nothing(t: TestHarness) -> void:
	var sim := Sim.new(5)
	_drive(sim, Vector2(0, 1), true, 25.0)
	sim.power = 1.0
	var held := sim.load_kg
	t.ok(not sim.can_uplink(), "it is refused")
	t.approx(sim.uplink(), 0.0, 1e-9, "calling it anyway banks nothing")
	t.approx(sim.load_kg, held, 1e-9, "and does not silently empty the hold")


## Running out never takes the run. Keep what was banked, lose the hold, keep
## every tunnel. His own Coreward design.
func test_running_out_costs_the_hold_and_never_the_planet(t: TestHarness) -> void:
	var sim := Sim.new(7)
	_drive(sim, Vector2(0, 1), true, 25.0)
	sim.uplink()
	var banked := sim.credits
	t.gt(banked, 0.0, "the fixture banked something first")
	_drive(sim, Vector2(0, 1), true, 25.0)
	var cut_depth := sim.flight.depth()
	sim.power = 0.01
	sim.step(Vector2(0, 1), true, DT)
	t.eq(sim.phase, Sim.Phase.OVER, "it ends")
	t.eq(sim.outcome, "out of power", "and says why")
	t.approx(sim.credits, banked, 1e-4, "what was already uplinked is kept")
	t.approx(sim.load_kg, 0.0, 1e-6, "what was in the hold is lost")

	sim.redescend()
	t.eq(sim.phase, Sim.Phase.DESCENT, "the next descent starts")
	t.approx(sim.power, Tuning.POWER_MAX, 1e-6, "refuelled")
	t.approx(sim.credits, banked, 1e-4, "with the bank intact")
	t.ok(sim.world.is_open(0, int(cut_depth) - 4),
		"and the shaft that was cut is still open, so getting back down is fast")


## Filament is FOUND, never mined. If it can be earned by grinding the shallow
## band, the central balance fix is gone.
func test_filament_is_never_a_by_product_of_ore(t: TestHarness) -> void:
	var sim := Sim.new(9)
	var iron := sim.world.cut(0, 20, 0.0)
	t.eq(int(iron["filament"]), 0, "cutting nothing yields no filament")
	# Cut every kind of ore cell in a planet and check none of them pay filament.
	var w := World.new(9)
	var paid := 0
	for d in range(1, 60):
		for x in range(-4, 5):
			var m := w.material_at(x, d)
			if m == Ore.CACHE or m == Ore.AIR:
				continue
			var r := w.cut(x, d, 999.0)
			paid += int(r["filament"])
	t.eq(paid, 0, "no ore cell anywhere pays filament")


func test_a_cache_pays_filament_and_nothing_else(t: TestHarness) -> void:
	var w := World.new(9)
	var found := Vector2i(-999, -999)
	for d in range(Tuning.CACHE_MIN_DEPTH, Tuning.CORE_DEPTH):
		for x in range(-Tuning.HALF_WIDTH, Tuning.HALF_WIDTH + 1):
			if w.material_at(x, d) == Ore.CACHE:
				found = Vector2i(x, d)
				break
		if found.x != -999:
			break
	t.ok(found.x != -999, "the fixture found a cache to open")
	var r := w.cut(found.x, found.y, 999.0)
	t.gt(float(r["filament"]), 0.0, "a cache pays filament")
	t.approx(float(r["kg"]), 0.0, 1e-9, "and adds no weight")
	t.approx(float(r["value"]), 0.0, 1e-9, "and pays no credits")


## The Line: announced before it charges, and it charges by a readable rate.
func test_the_line_charges_only_past_it(t: TestHarness) -> void:
	var sim := Sim.new(11)
	sim.flight.pos = Vector2(0, float(Tuning.LINE_DEPTH) - 5.0)
	t.approx(sim.pressure_rate(), 0.0, 1e-9, "above the Line nothing drains")
	var hull_before := sim.hull
	sim.step(Vector2.ZERO, false, DT * 60.0)
	t.approx(sim.hull, hull_before, 1e-6, "and the hull is untouched")

	sim.flight.pos = Vector2(0, 150.0)
	t.gt(sim.pressure_rate(), 0.0, "below the Line there is a rate to read")
	hull_before = sim.hull
	for _i in range(60):
		sim.step(Vector2.ZERO, false, DT)
	t.lt(sim.hull, hull_before, "and the hull actually goes down")


func test_hull_zero_ends_the_descent(t: TestHarness) -> void:
	var sim := Sim.new(11)
	sim.hull = 0.5
	sim.flight.pos = Vector2(0, 190.0)
	_drive(sim, Vector2.ZERO, false, 30.0)
	t.eq(sim.phase, Sim.Phase.OVER, "a breached hull ends it")
	t.eq(sim.outcome, "hull breached", "and says why")


## Cutting the core hands off to the extraction. M6 builds the ascent; M1 only
## has to prove the hand-off exists and that it cannot be reached by accident.
##
## The hull is held up through the cut **on purpose**, and that is a finding
## rather than a convenience: at the core the pressure drain measured about
## 4.4 hull a second and the core takes about eleven seconds to cut, so a stock
## hull cannot currently survive long enough to finish it. The core is meant to
## be unreachable without the Line counter, which is not built yet. Removing the
## confounder is the right move here because the subject of this test is the
## hand-off; the survivable depth per fit is the probe's job.
func test_cutting_the_core_starts_the_extraction(t: TestHarness) -> void:
	var sim := Sim.new(13)
	var cd := sim.world.core_depth()
	sim.flight.pos = Vector2(float(sim.world.core_x), float(cd) - 1.2)
	sim.power = Tuning.POWER_MAX
	t.eq(sim.world.material_at(sim.world.core_x, cd), Ore.CORE,
		"the fixture is actually pointed at the core")
	t.eq(sim.phase, Sim.Phase.DESCENT, "not in extraction before the core is cut")

	for _i in range(int(60.0 / DT)):
		if sim.phase != Sim.Phase.DESCENT:
			break
		sim.hull = Tuning.HULL_MAX          ## the confounder, removed deliberately
		sim.step(Vector2(0, 1), true, DT)
	t.eq(sim.phase, Sim.Phase.EXTRACTION, "cutting the core hands off to the extraction")

	# And it must not be reachable without cutting it: the same drive one cell
	# to the side, where there is no core, must never hand off.
	var other := Sim.new(13)
	other.flight.pos = Vector2(float(other.world.core_x) + 2.0, float(cd) - 1.2)
	for _i in range(int(60.0 / DT)):
		if other.phase != Sim.Phase.DESCENT:
			break
		other.hull = Tuning.HULL_MAX
		other.step(Vector2(0, 1), true, DT)
	t.ok(other.phase != Sim.Phase.EXTRACTION,
		"digging next to the core does not start the extraction")


## The manifest is what makes two ores comparable on screen, which is what makes
## the choice between them real.
func test_the_manifest_shows_count_weight_and_value(t: TestHarness) -> void:
	var sim := Sim.new(5)
	_drive(sim, Vector2(0, 1), true, 30.0)
	var rows := sim.manifest()
	t.gt(float(rows.size()), 0.0, "there is something in the manifest")
	var total := 0.0
	for r in rows:
		t.gt(float(r["kg"]), 0.0, "%s has a weight" % r["name"])
		t.gt(float(r["count"]), 0.0, "%s has a count" % r["name"])
		total += float(r["value"])
	t.approx(total, sim.hold_value(), 1e-4, "the rows add up to the hold's value")
	for i in range(1, rows.size()):
		t.ok(float(rows[i - 1]["value"]) >= float(rows[i]["value"]),
			"the manifest is sorted by what a line is worth")


# ── the extraction ────────────────────────────────────────────────────────

func _at_the_core(seed_value: int) -> Sim:
	var sim := Sim.new(seed_value)
	var cd := sim.world.core_depth()
	# Cut a shaft from the surface to the chamber, so there is a real route out
	# and the fixture is testing the extraction rather than a sealed pocket.
	for d in range(-1, cd + 1):
		sim.world.fill[sim.world.idx(sim.world.core_x, d)] = 0.0
		sim.world.mat[sim.world.idx(sim.world.core_x, d)] = Ore.AIR
	sim.world.mat[sim.world.idx(sim.world.core_x, cd)] = Ore.CORE
	sim.world.fill[sim.world.idx(sim.world.core_x, cd)] = 1.0
	sim.flight.pos = Vector2(float(sim.world.core_x), float(cd) - 1.2)
	return sim


func _cut_the_core(sim: Sim) -> void:
	for _i in range(int(90.0 / DT)):
		if sim.phase != Sim.Phase.DESCENT:
			return
		sim.hull = Tuning.HULL_MAX          ## the Line is not the subject here
		sim.power = Tuning.POWER_MAX
		sim.step(Vector2(0, 1), true, DT)


## The core is a physical object and it is heavy, so the climb out is laboured
## and something has to be dropped to make room for it.
func test_the_core_takes_up_room_and_weighs(t: TestHarness) -> void:
	var sim := _at_the_core(21)
	sim.hold = {Ore.IRON: {"kg": 50.0, "value": 90.0, "count": 30}}
	sim.load_kg = 50.0
	_cut_the_core(sim)
	t.eq(sim.phase, Sim.Phase.EXTRACTION, "the fixture reached the extraction")
	t.ok(sim.carrying_core, "the core is aboard")
	t.approx(sim.load_kg, Tuning.CORE_KG, 0.01,
		"the hold was cleared to make room and the core is what is left in it")
	t.lt(Tuning.speed_for(sim.load_kg), Tuning.speed_for(0.0) * 0.8,
		"carrying the core is genuinely slower")


## **Never let a hazard take the run.** The clock is derived from the route the
## player actually has, so it can never be unwinnable by construction.
func test_the_clock_is_derived_from_the_route_not_set_flat(t: TestHarness) -> void:
	var sim := _at_the_core(21)
	_cut_the_core(sim)
	var cell := Vector2i(int(roundf(sim.flight.pos.x)), int(roundf(sim.flight.pos.y)))
	var route := sim.world.route_out(cell.x, cell.y)
	t.gt(float(route), 100.0, "the fixture's route out is a real climb")

	var speed := Tuning.speed_for(sim.load_kg + 0.0) * 0.72
	var fastest := float(route) / speed
	t.gt(sim.extract_total, fastest,
		"the clock is shorter than the fastest possible climb, so it is unwinnable")
	t.lt(sim.extract_total, fastest * 3.0,
		"the clock is so long it is a stroll rather than a chase")

	# And a longer route gets a longer clock, which is what makes it derived
	# rather than a constant wearing a formula's clothes.
	var short_route := Tuning.extraction_seconds(40, 40.0)
	var long_route := Tuning.extraction_seconds(400, 40.0)
	t.gt(long_route, short_route, "a longer climb does not get more time")


## Reaching the surface with the core is the only way a planet is finished.
func test_climbing_out_with_the_core_finishes_the_planet(t: TestHarness) -> void:
	var sim := _at_the_core(21)
	_cut_the_core(sim)
	var before := sim.cores
	# Fly straight up the shaft that was cut.
	for _i in range(int(Tuning.EXTRACT_MAX_S / DT)):
		if sim.phase != Sim.Phase.EXTRACTION:
			break
		sim.hull = Tuning.HULL_MAX
		sim.power = Tuning.POWER_MAX
		sim.step(Vector2(0, -1), false, DT)
	t.eq(sim.phase, Sim.Phase.OVER, "the extraction ended")
	t.eq(sim.outcome, "escaped with the core", "and it ended by escaping")
	t.eq(sim.cores, before + 1, "the core is in the drive")
	t.ok(not sim.carrying_core, "and is no longer being carried")


## Failing it costs the core and the planet, and never the save.
func test_failing_the_extraction_never_takes_the_save(t: TestHarness) -> void:
	var sim := _at_the_core(21)
	sim.credits = 500.0
	sim.filament = 9
	_cut_the_core(sim)
	var before_cores := sim.cores
	# Sit still and let it come up.
	for _i in range(int((Tuning.EXTRACT_MAX_S + 10.0) / DT)):
		if sim.phase != Sim.Phase.EXTRACTION:
			break
		sim.hull = Tuning.HULL_MAX
		sim.power = Tuning.POWER_MAX
		sim.step(Vector2.ZERO, false, DT)
	t.eq(sim.phase, Sim.Phase.OVER, "sitting still ends it")
	t.eq(sim.outcome, "taken by the collapse", "and says why")
	t.eq(sim.cores, before_cores, "the core is not banked")
	t.approx(sim.credits, 500.0, 1e-4, "credits already banked are kept")
	t.eq(sim.filament, 9, "filament already found is kept")
	sim.redescend()
	t.eq(sim.phase, Sim.Phase.DESCENT, "and the game carries on")


## The thing coming up is a quantity the renderer and the clock BOTH read, so
## what the player sees and what kills them cannot disagree.
func test_the_rise_and_the_clock_are_one_quantity(t: TestHarness) -> void:
	var sim := _at_the_core(21)
	_cut_the_core(sim)
	var start_rise := sim.rising
	t.gt(start_rise, float(Tuning.CORE_DEPTH), "it starts below the core")
	t.approx(sim.extract_frac(), 0.0, 0.05, "and the clock starts at zero")
	for _i in range(int((sim.extract_total * 0.5) / DT)):
		sim.hull = Tuning.HULL_MAX
		sim.power = Tuning.POWER_MAX
		sim.flight.pos = Vector2(float(sim.world.core_x), 5.0)   ## out of its way
		sim.step(Vector2.ZERO, false, DT)
		if sim.phase != Sim.Phase.EXTRACTION:
			break
	t.lt(sim.rising, start_rise, "the collapse climbs")
	t.gt(sim.extract_frac(), 0.35, "and the clock agrees with how far it has come")


## A collapse may cost the takings, never the run. If filling a cell would seal
## the only way out, the fill is reverted.
func test_a_collapse_that_would_seal_you_in_is_refused(t: TestHarness) -> void:
	var w := World.new(33)
	# A one-cell-wide shaft: every cell in it is the only way out.
	for d in range(-1, 30):
		w.fill[w.idx(0, d)] = 0.0
		w.mat[w.idx(0, d)] = Ore.AIR
	t.gt(float(w.route_out(0, 25)), 0.0, "the fixture has a way out to begin with")

	var sealed := w.collapse(0, 10, 0, 25)
	t.ok(not sealed, "the collapse sealed the only route to the surface")
	t.ok(w.is_open(0, 10), "and the cell was left open")
	t.gt(float(w.route_out(0, 25)), 0.0, "the way out survives")

	# And the guard is not vacuous: a collapse that does NOT seal must succeed,
	# or the test above passes because collapse never does anything.
	for d in range(-1, 30):
		w.fill[w.idx(1, d)] = 0.0
		w.mat[w.idx(1, d)] = Ore.AIR
	t.ok(w.collapse(0, 10, 0, 25), "a collapse beside a second route is allowed")
	t.ok(not w.is_open(0, 10), "and it actually filled the cell")


func test_there_is_no_route_out_of_solid_rock(t: TestHarness) -> void:
	var w := World.new(33)
	t.eq(w.route_out(0, 50), -1, "solid rock reports no route rather than a short one")
	t.gt(float(w.route_out(0, -1)), -1.0, "the open sky above the pad is already out")
