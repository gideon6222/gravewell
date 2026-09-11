extends RefCounted

## **Quick: the rock is tissue, and the tunnel closes behind you.**
##
## The plan's row: "The rock is tissue. Cuts heal, so a tunnel closes behind you.
## It reacts to light."
##
## This is the only world where standing still is losing ground, and the only one
## where the way home is being taken away rather than merely getting longer. So it
## is also the one that most needs the studio's oldest rule about hazards: **a
## hazard may take the takings; it may never take the run.** The heal is forbidden
## from sealing the only route out, by construction and not by tuning.

const DT := 1.0 / 60.0


func _shaft(s: Sim, from: int, to: int) -> void:
	for d in range(from, to):
		s.world.set_fill(0, d, 0.0)
		s.world.mat[s.world.idx(0, d)] = Ore.AIR


## **Only Quick heals.**
func test_only_quick_heals(t: TestHarness) -> void:
	for id in [Classes.CINDER, Classes.RIME, Classes.DROWN, Classes.CRUSH, Classes.HOLLOW,
			Classes.VERGE]:
		t.ok(not Classes.heals(id),
			"%s heals, so the rule is not Quick's" % Classes.of(id)["name"])
	t.ok(Classes.heals(Classes.QUICK), "Quick does not heal, which is the whole class")


## A cut left alone closes. The measurable form: fill goes back up.
func test_a_cut_left_alone_closes(t: TestHarness) -> void:
	var s := Sim.new(11, Classes.QUICK)
	_shaft(s, 40, 60)
	s.flight.pos = Vector2(0.0, 41.0)
	var far := 55
	t.approx(s.world.fill_at(0, far), 0.0, 1.0e-4, "the fixture did not open the cell")
	for _i in range(60 * 30):
		s.power = s.power_capacity()
		s.hull = Tuning.HULL_MAX
		s.step(Vector2.ZERO, false, DT)
	t.gt(s.world.fill_at(0, far), 0.35,
		"thirty seconds left alone and the cut at %d m is still %.2f open"
			% [far, s.world.fill_at(0, far)])


## **And it does not heal where the lamp is.** "It reacts to light" is the
## player's lever on the rule: the tunnel you are lighting stays open, and the one
## behind you in the dark is the one that closes. Turning the lamp off to save
## power therefore costs you the way home, which is a real decision rather than a
## free one.
func test_the_lamp_holds_the_tunnel_open(t: TestHarness) -> void:
	var s := Sim.new(11, Classes.QUICK)
	_shaft(s, 40, 60)
	s.flight.pos = Vector2(0.0, 48.0)
	for _i in range(60 * 30):
		s.power = s.power_capacity()
		s.hull = Tuning.HULL_MAX
		s.step(Vector2.ZERO, false, DT)
	# **Both samples are outside `HEAL_SAFE`**, or this measures the safe radius
	# rather than the light. It did: with the lamp's effect removed entirely the
	# test still passed, because the near sample was a metre from the ship and
	# suppressed by the safe radius whatever the ramp said. Four metres is past
	# the safe radius and inside the lamp; ten is past both.
	var near := s.world.fill_at(0, 52)
	var far := s.world.fill_at(0, 58)
	t.lt(near, far * 0.6,
		"the cell beside the lamp closed to %.2f and the far one to %.2f, so light does nothing"
			% [near, far])


## **It may never take the run, and the guarantee is room to cut.**
##
## The first version refused any seal that would break the route to the surface.
## On a one-metre shaft EVERY cell is the only way out, so it refused every seal
## and the tunnel never closed at all: the rule was toothless in exactly the case
## it exists for. The guarantee is smaller and better - nothing heals within
## `HEAL_SAFE` of the ship - because a ship that can always turn and cut can always
## dig its way back out, which makes a closed tunnel a cost in power and time
## rather than a death.
func test_the_ship_is_never_sealed_in(t: TestHarness) -> void:
	var s := Sim.new(11, Classes.QUICK)
	_shaft(s, -1, 60)
	s.flight.pos = Vector2(0.0, 58.0)
	for _i in range(60 * 240):
		s.power = s.power_capacity()
		s.hull = Tuning.HULL_MAX
		s.step(Vector2.ZERO, false, DT)
		if s.phase != Sim.Phase.DESCENT:
			break
	var x := int(roundf(s.flight.pos.x))
	var d := int(roundf(s.flight.pos.y))
	var room := 0
	for dd in range(-1, 2):
		for dx in range(-1, 2):
			if s.world.is_open(x + dx, d + dd):
				room += 1
	t.gt(room, 2,
		"four minutes of healing left the ship with %d open cells around it, which is entombed"
			% room)
	# And the shaft further up HAS closed, or the safe radius is the whole rule.
	t.gt(s.world.fill_at(0, 20), 0.5,
		"the shaft near the surface is still open after four minutes, so nothing ever closes")


## And the rule has to fire in a real descent, or every assertion above is about
## a state the game does not reach.
func test_a_real_descent_on_quick_closes_behind_you(t: TestHarness) -> void:
	var s := Sim.new(11, Classes.QUICK)
	for _i in range(60 * 120):
		s.power = s.power_capacity()
		s.hull = Tuning.HULL_MAX
		s.step(Vector2(0, 1), true, DT)
		if s.flight.depth() > 55.0 or s.phase != Sim.Phase.DESCENT:
			break
	t.gt(s.flight.depth(), 30.0, "the miner never got deep enough to be tested")
	# Well behind the ship, the shaft has started to close again.
	var behind := int(s.flight.depth()) - 25
	t.gt(s.world.fill_at(0, behind), 0.05,
		"the shaft %d m behind the ship is still wide open, so nothing healed" % behind)
	# And right at the drill it is still open, or the ship would be sealed in.
	t.lt(s.world.fill_at(0, int(s.flight.depth()) - 2), 0.5,
		"the tunnel closed right behind the ship, which is a wall and not a world")
