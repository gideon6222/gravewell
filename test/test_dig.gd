extends RefCounted

## **Digging is a plow, not a sequence of block-breaks.**
##
## His words, after the first phone session: "digging feels very rigid and
## chunky. while I am digging, it takes large chunks out, slows me down, then
## speeds up. I would rather dig at a more consistent speed ... instead of taking
## longer to destroy a chunk I would like it to continously plow through but get
## slowed down on denser materials."
##
## The old model targeted ONE cell, spent `fill * hardness / rate` seconds taking
## it to zero, and refused to let the hull move until it was gone. Every
## assertion here is about the property that model could not have: the ship
## advances on every tick, and what changes with the material is the SPEED.


func _sim(planet: int, cls: int = Classes.CINDER) -> Sim:
	return Sim.new(planet, cls)


## Hold down for a while and record how far the ship got on each tick. **The
## count of ticks that moved the ship is the whole complaint**: under the old
## model most ticks moved it nothing at all and one tick in sixty moved it a
## whole cell.
func _run(s: Sim, seconds: float, step: float = 1.0 / 60.0) -> Dictionary:
	var moved := 0
	var ticks := 0
	var start: float = s.flight.depth()
	for _i in int(round(seconds / step)):
		# Power and hull are held up: this is a test of the DIG, and a run that
		# dies of a flat battery half way measures the failure screen.
		s.power = s.power_capacity()
		s.hull = Tuning.HULL_MAX
		var was: float = s.flight.depth()
		s.step(Vector2(0, 1), true, step)
		ticks += 1
		if s.flight.depth() - was > 1.0e-5:
			moved += 1
	return {
		"depth": s.flight.depth() - start,
		"ticks": ticks,
		"moved": moved,
		"rate": (s.flight.depth() - start) / seconds,
	}


## **Every tick moves the ship.** This is the assertion the old model fails, and
## it fails it by construction rather than by a little: a cell takes
## `hardness / DRILL_RATE` seconds, which is tens of frames of standing still.
func test_the_ship_advances_on_every_tick_of_a_drill(t: TestHarness) -> void:
	var s := _sim(1)
	var r := _run(s, 4.0)
	var frac := float(r["moved"]) / float(r["ticks"])
	t.gt(frac, 0.95,
		"only %d of %d drilling ticks moved the ship, so the dig still gates motion on a whole cell"
			% [int(r["moved"]), int(r["ticks"])])


## **And it never stops.** A drill that reaches zero is indistinguishable from an
## input that did not register, on a phone with no rumble to tell them apart.
## The floor is a property the BAND TABLE keeps, never a clamp applied to the
## speed: a clamp lets the hull advance faster than the drill clears the cell in
## front of it, and a ship that outruns its own carve passes through unbroken
## material. Measured with the clamp in: it went straight through a planet's core
## without cutting it and ended forty metres past, the core still at fill 0.62.
func test_the_plow_never_reaches_zero(t: TestHarness) -> void:
	for band in range(Tuning.BAND_HP.size()):
		var h: float = Tuning.BAND_HP[band]
		var v := Tuning.plow_speed(Tuning.DRILL_RATE, h)
		t.gt(v, Tuning.PLOW_MIN_ROCK,
			"band %d plows at %.3f m/s, under the %.2f that still reads as moving"
				% [band, v, Tuning.PLOW_MIN_ROCK])


## **Denser material is slower, and the spread is the one the player can feel.**
## Research on the genre puts the readable band at roughly 4:1 to 6:1 from the
## softest material to the hardest: under that the difference does not register,
## over it the hardest reads as stuck rather than as slow.
func test_hardness_spreads_the_speed_across_a_readable_range(t: TestHarness) -> void:
	var last := Tuning.BAND_HP.size() - 1
	var soft := Tuning.plow_speed(Tuning.DRILL_RATE, Tuning.BAND_HP[0])
	var hard := Tuning.plow_speed(Tuning.DRILL_RATE, Tuning.BAND_HP[last])
	var ratio := soft / hard
	t.gt(ratio, 3.5, "the deepest rock plows only %.2fx slower than the surface, which is not felt" % ratio)
	t.lt(ratio, 6.5, "the deepest rock plows %.2fx slower than the surface, which reads as stuck" % ratio)
	for i in range(1, Tuning.BAND_HP.size()):
		t.lt(Tuning.plow_speed(Tuning.DRILL_RATE, Tuning.BAND_HP[i]),
			Tuning.plow_speed(Tuning.DRILL_RATE, Tuning.BAND_HP[i - 1]),
			"band %d is not slower to plow than band %d" % [i, i - 1])


## The rate is **steady inside a band**. He asked for "a more consistent speed",
## and the measurable form of that is the spread of progress across short windows
## within one material, which under the old model ran from zero to a whole cell.
func test_the_rate_is_steady_within_one_material(t: TestHarness) -> void:
	var s := _sim(1)
	# Settle first, so the acceleration ramp is not counted as unsteadiness.
	_run(s, 1.5)
	var lo := 1.0e9
	var hi := 0.0
	for _w in range(8):
		var v: float = float(_run(s, 0.5)["rate"])
		lo = minf(lo, v)
		hi = maxf(hi, v)
	t.gt(lo, 0.0, "a half-second window of drilling made no progress at all")
	t.lt(hi / lo, 1.45,
		"the dig rate swings %.2fx between half-second windows in one material (%.2f to %.2f m/s)"
			% [hi / lo, lo, hi])


## **The plow still pays for the hole.** Speed is derived from the same hit
## points the power bill is derived from, so making the dig feel better must not
## have made it cheaper.
func test_the_plow_costs_what_it_removes(t: TestHarness) -> void:
	var s := _sim(1)
	s.power = s.power_capacity()
	var p0: float = s.power
	var d0: float = s.flight.depth()
	var step := 1.0 / 60.0
	for _i in range(240):
		s.hull = Tuning.HULL_MAX
		s.step(Vector2(0, 1), true, step)
	var dug: float = s.flight.depth() - d0
	var spent: float = p0 - s.power
	t.gt(dug, 1.0, "the fixture did not dig")
	var floor_cost: float = dug * Tuning.BAND_HP[0] * Tuning.POWER_PER_HP * 0.5
	t.gt(spent, floor_cost,
		"digging %.2f m cost %.2f power, under the %.2f the rock alone is worth"
			% [dug, spent, floor_cost])


## **A carved tunnel is passable AND paid for, in every class.** The companion to
## the old "every bite size breaks and pays" sweep: a brush that feathers its rim
## can leave a cell just above the threshold, flyable-looking and never broken,
## which is the fault this repo has already had twice.
func test_a_carved_tunnel_is_passable_and_paid_for(t: TestHarness) -> void:
	for cls in [Classes.CINDER, Classes.RIME]:
		for planet in [1, 4]:
			var s := _sim(planet, cls)
			var step := 1.0 / 60.0
			for _i in range(600):
				s.power = s.power_capacity()
				s.hull = Tuning.HULL_MAX
				s.step(Vector2(0, 1), true, step)
			var depth: float = s.flight.depth()
			t.gt(depth, 4.0,
				"class %d planet %d only reached %.2f m in ten seconds" % [cls, planet, depth])
			var x := int(roundf(s.flight.pos.x))
			for d in range(1, int(depth) - 1):
				t.ok(s.world.is_open(x, d),
					"class %d: cell (%d, %d) is behind the ship and still solid" % [cls, x, d])
				t.eq(s.world.mat[s.world.idx(x, d)], Ore.AIR,
					"class %d: cell (%d, %d) is flyable and still reports material" % [cls, x, d])


## **The hull is never left standing inside rock.** Plowing means the ship IS
## inside partly-dug material, which is the point of it; releasing the drill
## there must not wedge it. The carve has to clear the hull's own footprint.
func test_releasing_the_drill_never_leaves_the_ship_stuck(t: TestHarness) -> void:
	var s := _sim(3)
	var step := 1.0 / 60.0
	for _i in range(300):
		s.power = s.power_capacity()
		s.hull = Tuning.HULL_MAX
		s.step(Vector2(0, 1), true, step)
	var at: float = s.flight.depth()
	for _i in range(120):
		s.power = s.power_capacity()
		s.hull = Tuning.HULL_MAX
		s.step(Vector2(0, -1), false, step)
	t.lt(s.flight.depth(), at - 0.5,
		"the ship could not climb its own shaft after releasing the drill, so the plow wedges it")


## **`dig_load` is the one number every effect channel reads.** Particles, the
## drill loop, the haptics and the shake all derive from it, so they cannot
## disagree about how hard the current material is.
func test_dig_load_is_monotonic_in_hardness_and_spans_its_range(t: TestHarness) -> void:
	var prev := -1.0
	for band in range(Tuning.BAND_HP.size()):
		var l := Tuning.dig_load(Tuning.BAND_HP[band])
		t.ok(l >= 0.0 and l <= 1.0, "band %d reports a load of %.2f, outside 0..1" % [band, l])
		t.gt(l, prev, "band %d is not a heavier load than the band above it" % band)
		prev = l
	t.lt(Tuning.dig_load(Tuning.BAND_HP[0]), 0.2,
		"the softest rock already reads as heavy work, so there is nothing for the deep to say")
	t.gt(Tuning.dig_load(Tuning.BAND_HP[Tuning.BAND_HP.size() - 1]), 0.8,
		"the hardest rock does not reach the top of the range")
