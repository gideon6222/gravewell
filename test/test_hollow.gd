extends RefCounted

## **Hollow: the world you fly through rather than dig through.**
##
## The plan's row: "Enormous caverns. You fly more than you dig, falls hurt, and
## the dark has scale." Its light carries far, which is not generosity: it is what
## lets a room be big enough to be frightening. A cavern you cannot see the far
## side of is a black screen; a cavern you CAN see the far side of is a cavern.

const DT := 1.0 / 60.0


## **The caverns are the rule, so they have to be there and be big.** A class
## whose rule is its geometry fails as absence if the generator never makes any.
func test_hollow_is_mostly_holes(t: TestHarness) -> void:
	var open_of := {}
	for id in [Classes.CINDER, Classes.HOLLOW]:
		var w := World.new(7, id)
		var open := 0
		var total := 0
		for d in range(Tuning.CAVERN_MIN_DEPTH, Tuning.CORE_DEPTH - 20):
			for x in range(-Tuning.HALF_WIDTH, Tuning.HALF_WIDTH + 1):
				total += 1
				if w.is_open(x, d):
					open += 1
		open_of[id] = float(open) / float(total)
	t.gt(float(open_of[Classes.HOLLOW]), 0.10,
		"Hollow is %.1f%% open, which is not a world made of caverns"
			% (float(open_of[Classes.HOLLOW]) * 100.0))
	t.gt(float(open_of[Classes.HOLLOW]), float(open_of[Classes.CINDER]) * 2.0,
		"Hollow is %.1f%% open against Cinder's %.1f%%, which is the same cave"
			% [float(open_of[Classes.HOLLOW]) * 100.0, float(open_of[Classes.CINDER]) * 100.0])


## And the rooms are big, not merely numerous: a hundred pockets is a sponge.
func test_the_rooms_are_big_enough_to_fly_in(t: TestHarness) -> void:
	var w := World.new(7, Classes.HOLLOW)
	var widest := 0
	for d in range(Tuning.CAVERN_MIN_DEPTH, Tuning.CORE_DEPTH - 20):
		var run := 0
		for x in range(-Tuning.HALF_WIDTH, Tuning.HALF_WIDTH + 1):
			run = run + 1 if w.is_open(x, d) else 0
			widest = maxi(widest, run)
	t.gt(widest, 12, "the widest room on Hollow is %d m across, which is a corridor" % widest)


## **Falls hurt.** The counterweight: a world you fly in is a world where the
## floor is a hazard, and the same impact that costs nothing on Cinder bites here.
func test_a_fall_that_is_survivable_elsewhere_hurts_here(t: TestHarness) -> void:
	var lost := {}
	for id in [Classes.CINDER, Classes.HOLLOW]:
		var s := Sim.new(7, id)
		# A clear drop onto a floor, identical on both worlds.
		for d in range(10, 40):
			s.world.set_fill(0, d, 0.0)
			s.world.mat[s.world.idx(0, d)] = Ore.AIR
		s.flight.pos = Vector2(0.0, 11.0)
		s.hull = Tuning.HULL_MAX
		# **Held, not dropped.** Nothing falls in this game: a released ship
		# coasts to a stop inside a metre, so a fixture that sets a velocity and
		# lets go arrives at the floor below the free-impact speed and costs
		# nothing on any world. The thrust is what carries it into the floor.
		# Long enough to cross the shaft AND arrive: at seven metres a second a
		# thirty-metre drop is about four and a half seconds, and the first fixture
		# ran out of ticks in mid-air, which reads exactly like a fall that costs
		# nothing.
		for _i in range(400):
			s.power = s.power_capacity()
			s.step(Vector2(0, 1), false, DT)
		lost[id] = Tuning.HULL_MAX - s.hull
	t.gt(float(lost[Classes.CINDER]), 0.0, "the control fall cost nothing, so nothing is compared")
	t.gt(float(lost[Classes.HOLLOW]), float(lost[Classes.CINDER]) * 1.6,
		"the same fall costs %.1f on Hollow and %.1f on Cinder, which is not a drop"
			% [lost[Classes.HOLLOW], lost[Classes.CINDER]])


## Its light carries far, because the point of the dark having scale is being
## able to see the scale. A room you cannot see across is just a black screen.
func test_the_light_shows_how_big_the_room_is(t: TestHarness) -> void:
	t.lt(Classes.detour_att(Classes.HOLLOW), Classes.detour_att(Classes.CINDER) * 0.7,
		"light turns a corner no better on Hollow than on Cinder")
	var s := Sim.new(7, Classes.HOLLOW)
	s.power = s.power_capacity()
	s.flight.pos = Vector2(0.0, 40.0)
	var c := Sim.new(7, Classes.CINDER)
	c.power = c.power_capacity()
	c.flight.pos = Vector2(0.0, 40.0)
	t.gt(s.lamp_reach(), c.lamp_reach() * 1.15,
		"the Hollow lamp reaches %.1f m against %.1f, so the rooms cannot be read"
			% [s.lamp_reach(), c.lamp_reach()])
