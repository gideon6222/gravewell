extends RefCounted

## **Verge: it was inhabited, and some of it still has current.**
##
## The plan's row: "Dead machinery, sealed structure, powered doors, things that
## still have current... Radiation, and power surges that drain you."
##
## Its pressure is the only one in the game that goes for the BATTERY rather than
## the hull. That is the whole design of it: every other world asks "can the ship
## survive this", and this one asks "can you get out before the lamp does". The
## two questions have different answers and different mistakes.

const DT := 1.0 / 60.0


func _shaft(s: Sim, from: int, to: int) -> void:
	for d in range(from, to):
		s.world.set_fill(0, d, 0.0)
		s.world.mat[s.world.idx(0, d)] = Ore.AIR


## **Only Verge goes for the power**, and it is the only class that does.
func test_only_verge_drains_the_cell(t: TestHarness) -> void:
	for id in [Classes.CINDER, Classes.RIME, Classes.DROWN, Classes.CRUSH, Classes.HOLLOW]:
		t.ok(not Classes.drains_power(id),
			"%s drains the cell, so the rule is not Verge's" % Classes.of(id)["name"])
	t.ok(Classes.drains_power(Classes.VERGE), "Verge does not drain the cell, which is the class")


## The surge is a REAL cost, and it is on the battery rather than the hull, so
## the mistake it punishes is staying too long rather than being careless.
func test_the_surge_takes_power_and_leaves_the_hull_alone(t: TestHarness) -> void:
	var s := Sim.new(9, Classes.VERGE)
	var at := Tuning.LINE_DEPTH + 40
	_shaft(s, at - 8, at + 8)
	s.flight.pos = Vector2(0.0, float(at))
	s.power = s.power_capacity()
	s.hull = Tuning.HULL_MAX
	var p0 := s.power
	for _i in range(120):
		s.step(Vector2.ZERO, false, DT)
	var drained := p0 - s.power
	t.gt(drained, 1.0, "two seconds deep on Verge cost %.2f power, which is nothing" % drained)
	t.approx(s.hull, Tuning.HULL_MAX, 0.01,
		"Verge took hull as well, so its pressure is not on the battery after all")

	# And the control loses power far more slowly standing in the same place.
	var c := Sim.new(9, Classes.CINDER)
	_shaft(c, at - 8, at + 8)
	c.flight.pos = Vector2(0.0, float(at))
	c.power = c.power_capacity()
	c.hull = Tuning.HULL_MAX
	var c0 := c.power
	for _i in range(120):
		c.step(Vector2.ZERO, false, DT)
	t.gt(drained, (c0 - c.power) * 2.0,
		"Verge drains %.2f against the control's %.2f, which is the same world"
			% [drained, c0 - c.power])


## It starts at the Line like every pressure but Crush's, so the shallow half of
## a Verge descent is safe and the decision is whether to cross.
func test_the_surge_starts_at_the_line(t: TestHarness) -> void:
	var s := Sim.new(9, Classes.VERGE)
	_shaft(s, 4, Tuning.LINE_DEPTH + 20)
	s.flight.pos = Vector2(0.0, float(Tuning.LINE_DEPTH) - 20.0)
	t.approx(s.surge_rate(), 0.0, 1.0e-6, "Verge is surging well above its own Line")
	s.flight.pos = Vector2(0.0, float(Tuning.LINE_DEPTH) + 20.0)
	t.gt(s.surge_rate(), 0.0, "Verge is not surging below its own Line")


## Deeper is worse, or there is no reason to ever come back up.
func test_the_surge_gets_worse_with_depth(t: TestHarness) -> void:
	var s := Sim.new(9, Classes.VERGE)
	_shaft(s, 4, 190)
	var last := -1.0
	for d in [Tuning.LINE_DEPTH + 5, 120, 160, 185]:
		s.flight.pos = Vector2(0.0, float(d))
		var r := s.surge_rate()
		t.gt(r, last, "the surge at %d m is no worse than it was shallower" % d)
		last = r


## **Going dark is the counter, and it has to actually work.** Verge is the one
## world where the lamp is the thing hunting you, so the verb the game already
## has - turning it off - has to be the answer rather than a consolation.
func test_running_dark_survives_verge_longer(t: TestHarness) -> void:
	var out := {}
	for dark in [false, true]:
		var s := Sim.new(9, Classes.VERGE)
		var at := Tuning.LINE_DEPTH + 30
		_shaft(s, at - 10, at + 10)
		s.flight.pos = Vector2(0.0, float(at))
		s.power = 60.0
		s.hull = Tuning.HULL_MAX
		if dark:
			while s.lamp_mode != Tuning.Lamp.DARK:
				s.cycle_lamp()
		var ticks := 0
		while s.power > 0.0 and ticks < 60 * 400:
			s.step(Vector2.ZERO, false, DT)
			ticks += 1
		out[dark] = float(ticks) * DT
	t.gt(float(out[true]), float(out[false]) * 1.25,
		"running dark lasts %.1f s against %.1f lit, so the counter is not a counter"
			% [out[true], out[false]])

	# **And the SURGE itself has to be most of that**, not the lamp's own draw.
	# Lasting longer in the dark is true on every world, because a dark lamp
	# recharges: measured, this test passed unchanged with the surge's dependence
	# on the lamp removed entirely. The claim is that the world is hunting your
	# LIGHT, so the claim has to be made about the surge.
	var lit := Sim.new(9, Classes.VERGE)
	_shaft(lit, 90, 130)
	lit.flight.pos = Vector2(0.0, 120.0)
	var dark := Sim.new(9, Classes.VERGE)
	_shaft(dark, 90, 130)
	dark.flight.pos = Vector2(0.0, 120.0)
	while dark.lamp_mode != Tuning.Lamp.DARK:
		dark.cycle_lamp()
	t.lt(dark.surge_rate(), lit.surge_rate() * 0.65,
		"the surge is %.2f dark against %.2f lit, so the world is not hunting the light"
			% [dark.surge_rate(), lit.surge_rate()])
