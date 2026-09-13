extends RefCounted

## **The loop has to close, and it did not.**
##
## His words on build 25: *"If I run out of fuel, it says to tap to return or
## something like that but the game doesn't do anything. If I return to the
## surface before running out of fuel, I don't get more fuel or see what I am
## supposed to do."*
##
## Both are the same hole. Every rule below this line was already built and
## tested - the Hold, the ladder, the drive, the vaults - and none of it could be
## reached with a thumb, because nothing ever called `enter_hold()` and nothing
## reacted to a descent ending. A suite full of passing rules proved all of it
## and none of it was in the game.
##
## So these tests are about the SHAPE of the loop rather than any one rule:
## a descent ends, you arrive in the Hold, you spend, you launch, you are back
## down. If this file passes, the game has a middle.

const DT := 1.0 / 60.0


func _dig_to(s: Sim, depth: float, ticks: int = 60 * 90) -> void:
	for _i in range(ticks):
		s.power = s.power_capacity()
		s.hull = Tuning.HULL_MAX
		s.step(Vector2(0, 1), true, DT)
		if s.flight.depth() >= depth or s.phase != Sim.Phase.DESCENT:
			return


## **The pad does not take a ship that never left.** The ship starts ON the pad
## at depth zero, so a dock that fires on contact with the surface ends the
## descent on the frame it begins, which is the whole game gone.
func test_you_cannot_dock_without_having_gone_down(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.eq(s.phase, Sim.Phase.DESCENT, "a new run does not start in a descent")
	t.ok(not s.can_dock(), "the pad accepted a ship still sitting on it")
	for _i in range(120):
		s.step(Vector2.ZERO, false, DT)
	t.eq(s.phase, Sim.Phase.DESCENT, "two seconds on the pad ended the descent by itself")


## Once you have been down, arriving back at the surface takes you in.
func test_reaching_the_surface_docks_you(t: TestHarness) -> void:
	var s := Sim.new(1)
	_dig_to(s, Tuning.DOCK_ARM + 4.0)
	t.gt(s.flight.depth(), Tuning.DOCK_ARM, "the fixture never got deep enough to arm the pad")
	s.flight.pos.y = 0.0
	s.step(Vector2.ZERO, false, DT)
	t.eq(s.phase, Sim.Phase.HOLD, "the ship reached the surface and the descent just carried on")


## **Carrying it up yourself pays in full.** That is the decision the uplink
## exists against: sell from depth at a power cost, or haul it home for
## everything and risk not arriving. A dock that paid the recovery cut would make
## the trip back pointless and the uplink the only move.
func test_docking_banks_the_full_value(t: TestHarness) -> void:
	var a := Sim.new(1)
	_dig_to(a, Tuning.DOCK_ARM + 4.0)
	t.gt(a.hold_value(), 0.0, "the fixture dug to the pad arm and found nothing to carry")
	var worth := a.hold_value()
	a.flight.pos.y = 0.0
	a.step(Vector2.ZERO, false, DT)
	t.approx(a.credits, worth, 0.01,
		"docking paid %.1f for a hold worth %.1f" % [a.credits, worth])
	# And the same load lost to a failed descent pays only the recovery cut, or
	# there is no difference between arriving and dying.
	var b := Sim.new(1)
	_dig_to(b, Tuning.DOCK_ARM + 4.0)
	var lost := b.hold_value()
	b._end("out of power")
	t.lt(b.credits, lost, "a failed descent paid the same as carrying it home")


## Docking empties the hold, because the ore is sold and not still aboard.
func test_docking_empties_the_hold(t: TestHarness) -> void:
	var s := Sim.new(1)
	_dig_to(s, Tuning.DOCK_ARM + 4.0)
	s.flight.pos.y = 0.0
	s.step(Vector2.ZERO, false, DT)
	t.approx(s.load_kg, 0.0, 1.0e-4, "the hold still weighs %.2f after selling it" % s.load_kg)
	t.eq(s.manifest().size(), 0, "the manifest still lists ore that has been sold")


## **Every way a descent can end arrives in the same room.** Out of power, hull
## gone, or walked home: the Hold is the only place between descents, so a player
## who fails has somewhere to be rather than a frozen screen.
func test_every_ending_reaches_the_hold(t: TestHarness) -> void:
	for why in ["out of power", "hull gone", "taken by the collapse"]:
		var s := Sim.new(1)
		_dig_to(s, 12.0)
		s._end(why)
		t.eq(s.phase, Sim.Phase.OVER, "%s did not end the descent" % why)
		s.enter_hold()
		t.eq(s.phase, Sim.Phase.HOLD, "%s could not get to the Hold" % why)


## **And the Hold has a way out.** A shop you cannot leave is the same bug as a
## game over you cannot tap past.
func test_the_hold_launches_you_back_down(t: TestHarness) -> void:
	var s := Sim.new(1)
	_dig_to(s, 12.0)
	s._end("out of power")
	s.enter_hold()
	s.launch()
	t.eq(s.phase, Sim.Phase.DESCENT, "LAUNCH in the Hold did not start a descent")


## **Launching refills the ship.** His ask in his own words: "I don't get more
## fuel". A refit that does not refuel makes the second descent shorter than the
## first and the tenth impossible.
func test_launching_refuels_and_repairs(t: TestHarness) -> void:
	var s := Sim.new(1)
	_dig_to(s, 12.0)
	s.power = 0.0
	s.hull = 3.0
	s._end("out of power")
	s.enter_hold()
	s.launch()
	t.approx(s.power, s.power_capacity(), 0.01,
		"the ship launched with %.1f power of %.1f" % [s.power, s.power_capacity()])
	t.approx(s.hull, Tuning.HULL_MAX, 0.01, "the ship launched still damaged")


## The tunnels survive the trip home, which is the whole reason to come back to a
## world rather than being given a fresh one.
func test_docking_keeps_the_tunnels(t: TestHarness) -> void:
	var s := Sim.new(1)
	_dig_to(s, Tuning.DOCK_ARM + 4.0)
	var cut := 0
	for d in range(2, 10):
		if s.world.is_open(0, d):
			cut += 1
	t.gt(cut, 2, "the fixture cut no shaft to preserve")
	s.flight.pos.y = 0.0
	s.step(Vector2.ZERO, false, DT)
	s.launch()
	var still := 0
	for d in range(2, 10):
		if s.world.is_open(0, d):
			still += 1
	t.eq(still, cut, "the shaft was %d metres before docking and %d after" % [cut, still])
