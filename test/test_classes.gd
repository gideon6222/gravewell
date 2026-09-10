extends RefCounted

## A world is a RULE before it is a palette.
##
## Coreward had twelve planets and they were twelve tints on one cave. Every case
## here exists to stop that happening again by construction.

const DT := 1.0 / 60.0


## **The assertion the whole file is for.** Any two classes must differ on at
## least three of the five channels a player can perceive, and the palette counts
## for exactly one of them.
func test_no_two_classes_are_the_same_cave_repainted(t: TestHarness) -> void:
	t.gt(float(Classes.ALL.size()), 1.0, "there is more than one class to compare")
	for a in range(Classes.ALL.size()):
		for b in range(a + 1, Classes.ALL.size()):
			var n := Classes.differences(a, b)
			t.gt(float(n), 2.0,
				"%s and %s differ on only %d channels, which is a repaint"
				% [Classes.of(a)["name"], Classes.of(b)["name"], n])


func test_every_class_names_its_own_line(t: TestHarness) -> void:
	var seen := {}
	for c in Classes.ALL:
		var line := String(c["line"])
		t.gt(float(line.length()), 2.0, "%s has no name for its Line" % c["name"])
		t.ok(not seen.has(line), "%s shares its Line with another class" % c["name"])
		seen[line] = true
		t.eq(c["tint"].size(), Tuning.BAND_DEPTHS.size(), "%s is missing a band tint" % c["name"])
		t.eq(c["air"].size(), Tuning.BAND_DEPTHS.size(), "%s is missing a band air" % c["name"])


## Rime cuts in half the time. Measured through the world's own cut rather than
## read off the table, so the class is proved to reach the rock.
func test_rime_cuts_faster_than_cinder(t: TestHarness) -> void:
	var cinder := World.new(12, Classes.CINDER)
	var rime := World.new(12, Classes.RIME)
	var d := 40
	cinder.cut(0, d, 1.0)
	rime.cut(0, d, 1.0)
	t.lt(cinder.fill_at(0, d), 1.0, "the fixture cut nothing at all on Cinder")
	t.lt(rime.fill_at(0, d), cinder.fill_at(0, d) - 0.2,
		"one bite of Rime removes no more than one bite of Cinder")


## Ice carries light further, so a Rime tunnel is legible past where a Cinder one
## goes black. That is the class changing what you can SEE.
func test_rime_carries_light_further_round_a_corner(t: TestHarness) -> void:
	var reach := {}
	for cls in [Classes.CINDER, Classes.RIME]:
		var w := World.new(12, cls)
		for d in range(20, 41):
			w.fill[w.idx(0, d)] = 0.0
			w.mat[w.idx(0, d)] = Ore.AIR
		for x in range(1, 10):
			w.fill[w.idx(x, 34)] = 0.0
			w.mat[w.idx(x, 34)] = Ore.AIR
		var f := Light.flood(w, 0, 30)
		reach[cls] = Light.at(f, 9, 4)
	t.gt(float(reach[Classes.RIME]), float(reach[Classes.CINDER]) * 1.4,
		"the far end of a branch is no brighter on ice than on rock")
	t.lt(float(reach[Classes.RIME]), 1.0, "ice attenuates nothing at all, so the flood is off")


## **Rime's rule, and the whole reason the class exists.** A wide cut brings the
## ceiling down; a one-cell shaft never does.
func test_a_wide_cut_cracks_a_rime_ceiling(t: TestHarness) -> void:
	var w := World.new(12, Classes.RIME)
	var d := 40
	t.eq(w.unstable.size(), 0, "the fixture starts stable")

	# A narrow shaft: safe forever, which keeps the careful way to dig available
	# and makes the wide cut the gamble.
	w.cut(0, d, 9999.0)
	t.eq(w.unstable.size(), 0, "a single cut cracked a ceiling, so there is no safe way to dig")

	for x in range(1, Classes.BRITTLE_SPAN):
		w.cut(x, d, 9999.0)
	t.gt(float(w.unstable.size()), 0.0,
		"a %d-cell span did not crack anything above it" % Classes.BRITTLE_SPAN)
	for key in w.unstable.keys():
		var c: Vector2i = key
		t.eq(c.y, d - 1, "the crack is not in the ceiling of the span")


## And Cinder must NOT do it, or the rule belongs to the game rather than to the
## class, and the classes are back to being palettes.
func test_cinder_ceilings_hold(t: TestHarness) -> void:
	var w := World.new(12, Classes.CINDER)
	var d := 40
	for x in range(0, Classes.BRITTLE_SPAN + 3):
		w.cut(x, d, 9999.0)
	t.eq(w.unstable.size(), 0, "a Cinder ceiling cracked, so brittleness is not a class property")
	t.eq(w.settle(10.0).size(), 0, "and nothing fell")


## The tell is longer than human reaction time by a wide margin, because this is
## meant to be a decision and not a reaction test.
func test_the_crack_is_announced_before_it_charges(t: TestHarness) -> void:
	t.gt(Classes.BRITTLE_DELAY, 1.0,
		"a %.1f s tell is a reaction test, not a decision" % Classes.BRITTLE_DELAY)
	var w := World.new(12, Classes.RIME)
	var d := 40
	for x in range(0, Classes.BRITTLE_SPAN):
		w.cut(x, d, 9999.0)
	var near := w.nearest_crack(Vector2(1.0, float(d)))
	t.lt(near, Classes.BRITTLE_DELAY + 0.01, "the warning does not report the nearest crack")
	t.gt(near, 0.0, "the warning reports a time already past")
	t.gt(w.nearest_crack(Vector2(40.0, 180.0)), 100.0,
		"a crack on the other side of the world is reported as near")


## It comes DOWN: the cell above empties and the cell below fills. A cell that
## merely vanishes is not a rock falling.
func test_a_falling_ceiling_actually_falls(t: TestHarness) -> void:
	var w := World.new(12, Classes.RIME)
	var d := 40
	for x in range(0, Classes.BRITTLE_SPAN):
		w.cut(x, d, 9999.0)
	var marked: Array = w.unstable.keys()
	t.gt(float(marked.size()), 0.0, "the fixture marked nothing")
	var c: Vector2i = marked[0]
	t.ok(not w.is_open(c.x, c.y), "the marked ceiling starts solid")
	t.ok(w.is_open(c.x, c.y + 1), "the cell it falls into starts open")

	var fell := w.settle(Classes.BRITTLE_DELAY + 0.1)
	t.gt(float(fell.size()), 0.0, "nothing fell after the delay")
	t.ok(w.is_open(c.x, c.y), "the ceiling did not empty")
	t.ok(not w.is_open(c.x, c.y + 1), "the rock did not land anywhere")
	t.eq(w.unstable.size(), 0, "the crack was not cleared after it fell")


## It hurts, and it never ends a descent on its own: a hazard may take the
## takings, never the run.
func test_a_falling_ceiling_hurts_without_taking_the_run(t: TestHarness) -> void:
	t.lt(Classes.BRITTLE_DAMAGE, Tuning.HULL_MAX * 0.5,
		"one falling rock takes more than half the hull, so two end a descent from full")
	var sim := Sim.new(12, Classes.RIME)
	var d := 40
	for x in range(0, Classes.BRITTLE_SPAN):
		sim.world.cut(x, d, 9999.0)
	var marked: Array = sim.world.unstable.keys()
	t.gt(float(marked.size()), 0.0, "the fixture marked nothing to fall")
	var c: Vector2i = marked[0]
	sim.flight.pos = Vector2(float(c.x), float(c.y + 1))
	var before := sim.hull
	for _i in range(int((Classes.BRITTLE_DELAY + 0.4) / DT)):
		sim.step(Vector2.ZERO, false, DT)
		if sim.hull < before - 1.0:
			break
	t.lt(sim.hull, before - 1.0, "standing under a falling ceiling cost nothing")
	t.gt(sim.hull, 0.0, "one falling rock ended the descent from a full hull")


## Every class must be reachable in play, or a content row is decoration.
func test_every_class_comes_round(t: TestHarness) -> void:
	var seen := {}
	var sim := Sim.new(1)
	for _i in range(Classes.ALL.size() * 3):
		seen[sim.world.class_id] = true
		sim.next_planet()
	t.eq(seen.size(), Classes.ALL.size(),
		"only %d of %d classes appear in a dozen planets" % [seen.size(), Classes.ALL.size()])
