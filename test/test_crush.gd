extends RefCounted

## **Crush: the world with no Line, because the Line is everywhere.**
##
## The plan's row for it: "High density: thrust is weak, everything is heavy,
## hull load rises continuously rather than past a line." Every other class has
## one metre where four things land at once and you can feel yourself cross it.
## This one has no such metre: the pressure starts at the pad and never stops
## rising, so the decision is never "do I go below the Line" and always "how much
## longer can I stay down".
##
## Its light is the other half of the rule. This is the dark one.

const DT := 1.0 / 60.0


func _open_shaft(s: Sim, from: int, to: int) -> void:
	for d in range(from, to):
		s.world.set_fill(0, d, 0.0)
		s.world.mat[s.world.idx(0, d)] = Ore.AIR


# ── the rule ──────────────────────────────────────────────────────────────

## **Only Crush crushes.** A rule that fires on every world is a rule the player
## cannot attribute to the world they are on.
func test_only_crush_crushes(t: TestHarness) -> void:
	for id in [Classes.CINDER, Classes.RIME, Classes.DROWN]:
		t.ok(not Classes.crushes(id),
			"%s crushes, so the rule is not Crush's" % Classes.of(id)["name"])
	t.ok(Classes.crushes(Classes.CRUSH), "Crush does not crush, which is the whole class")


## **The pressure is there before the Line, and everywhere above it.** On any
## other world the hull is safe until a known metre; here there is no safe band
## at all, only a shallower one.
func test_the_crush_starts_at_the_surface(t: TestHarness) -> void:
	var s := Sim.new(4, Classes.CRUSH)
	_open_shaft(s, -2, 40)
	for shallow in [6, 18, 30]:
		s.flight.pos = Vector2(0.0, float(shallow))
		t.gt(s.pressure_rate(), 0.0,
			"at %d m, well above the Line, a Crush world is not pressing at all" % shallow)

	# And on the control it is exactly zero up there, or nothing is being compared.
	var cinder := Sim.new(4, Classes.CINDER)
	cinder.flight.pos = Vector2(0.0, 18.0)
	t.approx(cinder.pressure_rate(), 0.0, 1.0e-6,
		"Cinder presses above its own Line, so the comparison means nothing")


## It rises with depth rather than sitting flat, or "continuous" would just mean
## a constant tax and the descent would have no shape.
func test_the_crush_rises_with_depth(t: TestHarness) -> void:
	var s := Sim.new(4, Classes.CRUSH)
	_open_shaft(s, -2, 190)
	var last := -1.0
	for d in [10, 50, 100, 150, 185]:
		s.flight.pos = Vector2(0.0, float(d))
		var r := s.pressure_rate()
		t.gt(r, last, "the crush at %d m is no worse than it was shallower" % d)
		last = r
	s.flight.pos = Vector2(0.0, 10.0)
	var top := s.pressure_rate()
	s.flight.pos = Vector2(0.0, 185.0)
	t.gt(s.pressure_rate(), top * 4.0,
		"the deep crush is only %.2fx the shallow one, which is not a descent"
			% (s.pressure_rate() / maxf(top, 1.0e-6)))


## **And it has no step in it.** Every other class's pressure switches on at one
## metre; this one's whole character is that nothing ever switches on. A jump at
## the Line would be the old rule leaking through.
func test_the_crush_has_no_line_in_it(t: TestHarness) -> void:
	var s := Sim.new(4, Classes.CRUSH)
	_open_shaft(s, -2, 120)
	var line := float(Tuning.LINE_DEPTH)
	s.flight.pos = Vector2(0.0, line - 0.5)
	var before := s.pressure_rate()
	s.flight.pos = Vector2(0.0, line + 0.5)
	var after := s.pressure_rate()
	t.gt(before, 0.0, "the fixture is not pressing at all just above the Line")
	t.lt(after - before, before * 0.15,
		"the crush jumps from %.3f to %.3f across the Line, so the Line is still in it"
			% [before, after])


# ── one rate, applied once ────────────────────────────────────────────────

## **The number the HUD shows is the number the hull loses.**
##
## `pressure_rate()` and the drain used to be two copies of one formula in two
## functions, which is exactly how a readout and a rule drift apart: this repo
## has already shipped two thresholds for "gone" twice and a fan cast to one
## range and decoded against another. One computes, one applies.
func test_the_rate_shown_is_the_rate_applied(t: TestHarness) -> void:
	for id in [Classes.CINDER, Classes.RIME, Classes.DROWN, Classes.CRUSH]:
		var s := Sim.new(4, id)
		var at := 150
		_open_shaft(s, at - 8, at + 8)
		s.flight.pos = Vector2(0.0, float(at))
		s.hull = Tuning.HULL_MAX
		var rate := s.pressure_rate()
		t.gt(rate, 0.0, "%s does not press at 150 m at all" % Classes.of(id)["name"])
		for _i in range(60):
			s.power = s.power_capacity()
			s.step(Vector2.ZERO, false, DT)
		var lost := Tuning.HULL_MAX - s.hull
		t.approx(lost, rate, rate * 0.08,
			"%s shows %.3f hull a second and loses %.3f" % [Classes.of(id)["name"], rate, lost])


# ── weak thrust, and the dark ─────────────────────────────────────────────

## Everything is heavy. The same held direction over the same open shaft covers
## less ground than on the control.
func test_thrust_is_weak_on_crush(t: TestHarness) -> void:
	var runs := {}
	for id in [Classes.CINDER, Classes.CRUSH]:
		var s := Sim.new(4, id)
		_open_shaft(s, 10, 60)
		s.flight.pos = Vector2(0.0, 14.0)
		s.flight.vel = Vector2.ZERO
		for _i in range(90):
			s.power = s.power_capacity()
			s.hull = Tuning.HULL_MAX
			s.step(Vector2(0, 1), false, DT)
		runs[id] = s.flight.depth() - 14.0
	t.gt(float(runs[Classes.CINDER]), 1.0, "the control did not move, so nothing is compared")
	t.lt(float(runs[Classes.CRUSH]), float(runs[Classes.CINDER]) * 0.8,
		"a Crush ship covers %.2f m against %.2f, which is not heavy"
			% [runs[Classes.CRUSH], runs[Classes.CINDER]])


## **This is the dark one**, and it is dark in the two ways that compound: the
## lamp does not reach, and what light there is does not get round a corner.
func test_crush_is_the_dark_one(t: TestHarness) -> void:
	var crush := Sim.new(4, Classes.CRUSH)
	var cinder := Sim.new(4, Classes.CINDER)
	for s in [crush, cinder]:
		s.power = s.power_capacity()
		s.flight.pos = Vector2(0.0, 30.0)
	t.lt(crush.lamp_reach(), cinder.lamp_reach() * 0.8,
		"the Crush lamp reaches %.2f m against %.2f, which is not dark"
			% [crush.lamp_reach(), cinder.lamp_reach()])
	t.gt(Classes.detour_att(Classes.CRUSH), Classes.detour_att(Classes.CINDER) * 1.5,
		"light turns a corner as easily on Crush as on Cinder")


# ── and it happens in a real descent ──────────────────────────────────────

## **A construct that can never be true fails as absence.** A scripted miner has
## to actually lose hull to the crush, and lose more of it than the same miner
## loses on the control, or every assertion above is about a state the game does
## not reach.
func test_a_real_descent_on_crush_is_worn_down(t: TestHarness) -> void:
	var lost := {}
	for id in [Classes.CINDER, Classes.CRUSH]:
		var s := Sim.new(4, id)
		s.hull = Tuning.HULL_MAX
		for _i in range(60 * 120):
			s.power = s.power_capacity()
			s.step(Vector2(0, 1), true, DT)
			if s.flight.depth() > 70.0 or s.phase != Sim.Phase.DESCENT:
				break
		t.gt(s.flight.depth(), 40.0,
			"%s never got deep enough to be tested" % Classes.of(id)["name"])
		lost[id] = Tuning.HULL_MAX - s.hull
	t.gt(float(lost[Classes.CRUSH]), 3.0,
		"seventy metres of Crush cost %.1f hull, which the player will never notice"
			% lost[Classes.CRUSH])
	t.gt(float(lost[Classes.CRUSH]), float(lost[Classes.CINDER]) + 2.0,
		"Crush costs %.1f hull over the same descent Cinder costs %.1f"
			% [lost[Classes.CRUSH], lost[Classes.CINDER]])
