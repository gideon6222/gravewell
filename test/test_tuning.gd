extends RefCounted

## Design tests: the INTENT behind the numbers, not the numbers.
##
## Every case here has either caught a design mistake in a past game or is
## aimed at one that shipped. Assert the property the message states, never a
## literal: "the Line equals the rock band change", not "the Line is 80".


func test_bands_are_a_monotonic_ladder(t: TestHarness) -> void:
	for i in range(1, Tuning.BAND_DEPTHS.size()):
		t.gt(float(Tuning.BAND_DEPTHS[i]), float(Tuning.BAND_DEPTHS[i - 1]),
			"band %d starts deeper than band %d" % [i, i - 1])
		t.gt(Tuning.BAND_HP[i], Tuning.BAND_HP[i - 1],
			"band %d is harder than band %d" % [i, i - 1])
	t.gt(float(Tuning.CORE_DEPTH), float(Tuning.BAND_DEPTHS[Tuning.BAND_DEPTHS.size() - 1]),
		"the core is below the last band, or the last band is unreachable")


## Four things land on the same metre: the rock changes, the air changes, the
## hull starts draining and a sound arrives. In Coreward the rock band moved to
## 60 m and the heat threshold stayed at 70, so the only marker of the boundary
## was a number that never appears on screen, and his note was that he could
## feel the line was there and could not find it.
func test_the_line_is_a_rock_boundary(t: TestHarness) -> void:
	var found := false
	for depth in Tuning.BAND_DEPTHS:
		if depth == Tuning.LINE_DEPTH:
			found = true
	t.ok(found, "LINE_DEPTH must be one of BAND_DEPTHS, or the boundary is invisible")
	t.gt(Tuning.hardness_at(float(Tuning.LINE_DEPTH)),
		Tuning.hardness_at(float(Tuning.LINE_DEPTH) - 1.0),
		"the rock is harder on the far side of the Line")


## Announce a zone before charging for it.
func test_the_line_warns_before_it_charges(t: TestHarness) -> void:
	t.gt(Tuning.LINE_WARN_M, 0.0, "there is a warning band above the Line")
	t.lt(Tuning.LINE_WARN_M, float(Tuning.LINE_DEPTH), "the warning starts below the surface")


## Air density is the one number driving fog, lamp reach, muffling, drag and
## hull load. If it is not strictly increasing, every one of those goes
## non-monotonic at once and the deep stops reading as deeper.
func test_air_density_only_ever_thickens(t: TestHarness) -> void:
	var last := -1.0
	for d in range(0, Tuning.CORE_DEPTH + 1, 5):
		var v := Tuning.density_at(float(d))
		t.gt(v, last, "density at %d m is above density at %d m" % [d, d - 5])
		last = v
	t.gt(Tuning.density_at(float(Tuning.CORE_DEPTH)),
		Tuning.density_at(float(Tuning.LINE_DEPTH)) * 2.0,
		"the core is at least twice the Line's density, or the deep is a tint")


## The pressure drain has to be a clock the player can read and act on, not a
## cliff. A minute at the top of the deep band and half a minute at the core.
func test_pressure_is_a_clock_not_a_cliff(t: TestHarness) -> void:
	var line_density := Tuning.density_at(float(Tuning.LINE_DEPTH))
	var at_130: float = Tuning.PRESSURE_RATE * (Tuning.density_at(130.0) - line_density)
	var at_core: float = Tuning.PRESSURE_RATE * (Tuning.density_at(float(Tuning.CORE_DEPTH)) - line_density)
	t.gt(Tuning.HULL_MAX / at_130, 30.0, "a full hull survives over 30 s at 130 m")
	t.gt(Tuning.HULL_MAX / at_core, 15.0, "a full hull survives over 15 s at the core")
	t.lt(Tuning.HULL_MAX / at_core, 60.0, "the core is not survivable indefinitely")


## Ordered deepest-first with strictly rising chance. That ordering is what
## makes adding a new deepest ore convert only the band above it rather than
## reshuffling every band in the game.
func test_ore_table_is_ordered_and_reachable(t: TestHarness) -> void:
	var last_chance := 0.0
	var last_depth := 99999
	for o in Ore.ORES:
		t.gt(float(o["chance"]), last_chance,
			"%s is rarer than the ore below it" % o["name"])
		t.lt(float(o["min_depth"]), float(last_depth),
			"%s starts shallower than the ore below it" % o["name"])
		t.lt(float(o["min_depth"]), float(Tuning.CORE_DEPTH),
			"%s is reachable before the core" % o["name"])
		last_chance = float(o["chance"])
		last_depth = int(o["min_depth"])


## Quality is a multiplier on quantity, never an amount added, so both axes stay
## alive at every scale.
func test_a_seam_multiplies_rather_than_adds(t: TestHarness) -> void:
	var plain := Ore.yield_of(Ore.IRON, false)
	var seamed := Ore.yield_of(Ore.IRON, true)
	t.approx(float(seamed["value"]) / float(plain["value"]), Tuning.SEAM_MULT, 1e-4,
		"a seam multiplies the value")
	t.approx(float(seamed["kg"]), float(plain["kg"]), 1e-6,
		"a seam does not change the weight, or weight stops being comparable")
	t.gt(Tuning.SEAM_MULT, 2.0, "a seam is worth going out of the way for")


## Plain rock pays a very small amount, which is his suggestion: "most regular
## dirt and rock give you a very small amount of resource, and those textured
## areas give you more".
func test_plain_rock_pays_something_but_barely(t: TestHarness) -> void:
	var slag := Ore.yield_of(Ore.ROCK, false)
	t.gt(float(slag["value"]), 0.0, "plain rock is worth cutting at all")
	var iron := Ore.yield_of(Ore.IRON, false)
	t.lt(float(slag["value"]) * 3.0, float(iron["value"]),
		"plain rock is worth far less than the shallowest ore")


## Reach top speed in about a fifth of a second and coast under a cell. On a
## thumb, momentum reads as latency.
func test_the_feel_constants_are_a_thumbs(t: TestHarness) -> void:
	var to_top := 3.0 / Tuning.THRUST_RATE
	t.lt(to_top, 0.25, "top speed inside a quarter second")
	t.gt(to_top, 0.10, "not instant, or there is no momentum at all")
	var coast := Tuning.TOP_SPEED / Tuning.COAST_RATE
	t.lt(coast, Tuning.CELL, "coasts less than one cell")
	t.gt(coast, 0.3, "coasts far enough to feel like mass")


## A full hold is a real cost, and the cost is felt rather than announced.
func test_a_full_hold_is_slower_but_not_a_wall(t: TestHarness) -> void:
	var empty := Tuning.speed_for(0.0)
	var full := Tuning.speed_for(Tuning.HOLD_KG)
	t.lt(full, empty * 0.75, "a full hold costs at least a quarter of the top speed")
	t.gt(full, empty * 0.4, "a full hold is not a crawl")


## The lamp is a choice, not a meter: the modes have to actually trade.
func test_lamp_modes_trade_against_each_other(t: TestHarness) -> void:
	t.gt(Tuning.LAMP_REACH[Tuning.Lamp.LANCE], Tuning.LAMP_REACH[Tuning.Lamp.FLOOD],
		"the lance sees further than the flood")
	t.lt(Tuning.LAMP_CONE[Tuning.Lamp.LANCE], Tuning.LAMP_CONE[Tuning.Lamp.FLOOD],
		"the lance is narrower than the flood")
	t.gt(Tuning.LAMP_DRAIN[Tuning.Lamp.LANCE], Tuning.LAMP_DRAIN[Tuning.Lamp.FLOOD],
		"the lance costs more than the flood")
	t.lt(Tuning.LAMP_DRAIN[Tuning.Lamp.DARK], 0.0,
		"going dark gives power back, or it is a wait rather than a verb")
	t.gt(Tuning.LAMP_REACH[Tuning.Lamp.DARK], 0.0,
		"even dark shows something; a black screen reads as a crash")


## Power low dims the lamp, and it does so smoothly and never to nothing.
func test_low_power_closes_the_world_in(t: TestHarness) -> void:
	var full := Tuning.lamp_reach(Tuning.Lamp.FLOOD, 1.0)
	var edge := Tuning.lamp_reach(Tuning.Lamp.FLOOD, Tuning.LAMP_FADE_START)
	t.approx(edge, full, 1e-4, "above the fade threshold the reach is untouched")
	var last := full + 1.0
	for i in range(11):
		var f := Tuning.LAMP_FADE_START * float(10 - i) / 10.0
		var r := Tuning.lamp_reach(Tuning.Lamp.FLOOD, f)
		t.lt(r, last, "reach falls as power falls (at %.2f)" % f)
		last = r
	t.approx(Tuning.lamp_reach(Tuning.Lamp.FLOOD, 0.0), Tuning.LAMP_MIN_REACH, 1e-4,
		"at zero power the lamp is at its floor, not off")


## An uplink has to cost more the deeper and heavier you are, or "bank it now
## or carry it further" is not a decision.
func test_uplinking_costs_more_the_further_you_have_committed(t: TestHarness) -> void:
	var shallow := Tuning.uplink_cost(20.0, 30.0)
	var deep := Tuning.uplink_cost(160.0, 30.0)
	var heavy := Tuning.uplink_cost(20.0, Tuning.HOLD_KG)
	t.gt(deep, shallow * 1.5, "depth matters to the cost")
	t.gt(heavy, shallow, "weight matters to the cost")
	t.lt(Tuning.uplink_cost(float(Tuning.CORE_DEPTH), Tuning.HOLD_KG), Tuning.POWER_MAX * 0.35,
		"even the worst uplink is affordable, or the mechanic is a trap")


## Every generator must roll on its own offset. Consuming another's roll shifts
## every ore at every depth on every planet and the diff looks like three lines.
func test_seed_offsets_are_unique(t: TestHarness) -> void:
	var seen := {}
	for o in Tuning.SEED_OFFSETS:
		t.ok(not seen.has(o), "seed offset %d is used once" % o)
		seen[o] = true
	t.eq(Tuning.SEED_OFFSETS.size(), seen.size(), "no duplicate seed offsets")
