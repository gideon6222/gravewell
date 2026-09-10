extends RefCounted

## The grid, generation, and the one float doing three jobs.


func test_a_planet_is_reproducible_from_its_seed(t: TestHarness) -> void:
	var a := World.new(4242)
	var b := World.new(4242)
	t.eq(a.mat, b.mat, "same seed, same materials")
	t.eq(a.seam, b.seam, "same seed, same seams")
	t.eq(a.core_x, b.core_x, "same seed, same core position")
	var c := World.new(4243)
	t.ok(a.mat != c.mat, "a different seed is a different planet")


func test_the_edges_are_walls_and_the_sky_is_open(t: TestHarness) -> void:
	var w := World.new(1)
	t.ok(not w.is_open(Tuning.HALF_WIDTH + 1, 40), "past the right edge is solid")
	t.ok(not w.is_open(-Tuning.HALF_WIDTH - 1, 40), "past the left edge is solid")
	t.ok(not w.is_open(0, Tuning.CORE_DEPTH + 1), "below the world is solid")
	t.ok(w.is_open(0, -1), "above the surface is open")
	t.ok(w.is_open(0, -Tuning.SURFACE_ROWS - 4), "well above the surface is open")


## `fill` is the damage, the contour input and what the flood calls passable.
## One number, so the picture, the damage and the light cannot disagree.
func test_partial_damage_is_kept_when_the_drill_stops(t: TestHarness) -> void:
	var w := World.new(9)
	var x := 0
	var d := 12
	while w.is_open(x, d):
		d += 1
	var hardness := Tuning.hardness_at(float(d))
	var before := w.fill_at(x, d)

	var r1 := w.cut(x, d, hardness * 0.4)
	t.ok(not bool(r1["broke"]), "a partial cut does not break the cell")
	t.lt(w.fill_at(x, d), before, "the cell remembers the damage")
	var mid := w.fill_at(x, d)

	# The drill stops. Nothing is called. Nothing may reset.
	t.approx(w.fill_at(x, d), mid, 1e-9, "the damage survives the drill stopping")

	var r2 := w.cut(x, d, hardness * 0.7)
	t.ok(bool(r2["broke"]), "finishing it off from where it was left breaks it")
	t.ok(w.is_open(x, d), "and the cell is now open")


## Power is charged for hit points actually spent, so the last partial cut of a
## cell must not bill for a whole one.
func test_cutting_bills_only_for_work_actually_done(t: TestHarness) -> void:
	var w := World.new(11)
	var d := 12
	while w.is_open(0, d):
		d += 1
	var hardness := Tuning.hardness_at(float(d))
	var r := w.cut(0, d, hardness * 10.0)
	t.ok(bool(r["broke"]), "a huge bite breaks the cell")
	t.approx(float(r["cut"]), hardness, 1e-4,
		"and bills for one cell's hit points, not for the ten it was offered")
	var again := w.cut(0, d, hardness)
	t.approx(float(again["cut"]), 0.0, 1e-9, "cutting air bills nothing")


func test_every_ore_actually_occurs_in_a_real_planet(t: TestHarness) -> void:
	# A condition that can never be true fails as absence, so check the ore
	# exists in the ground rather than that the roll could return it. Several
	# seeds, because one planet's layout is not a property of the game.
	for o in Ore.ORES:
		var found := false
		for s in [1, 2, 3, 4, 5, 6]:
			if World.new(s).count_of(int(o["id"])) > 0:
				found = true
				break
		t.ok(found, "%s occurs in at least one of six planets" % o["name"])


func test_ore_gets_richer_with_depth(t: TestHarness) -> void:
	var w := World.new(21)
	var shallow := 0.0
	var deep := 0.0
	for d in range(6, 40):
		for x in range(-Tuning.HALF_WIDTH, Tuning.HALF_WIDTH + 1):
			shallow += float(Ore.yield_of(w.material_at(x, d), w.is_seam(x, d))["value"])
	for d in range(150, 184):
		for x in range(-Tuning.HALF_WIDTH, Tuning.HALF_WIDTH + 1):
			deep += float(Ore.yield_of(w.material_at(x, d), w.is_seam(x, d))["value"])
	t.gt(deep, shallow * 2.0, "the deep band is worth more than twice the shallow one")


## Filament is the only thing that buys a counter to a threat, so a planet that
## generates none is a planet where survival cannot be bought at any price.
func test_every_planet_carries_findable_filament(t: TestHarness) -> void:
	for s in [1, 2, 3, 4, 5, 6]:
		var w := World.new(s)
		var n := w.count_of(Ore.CACHE)
		t.gt(float(n), 3.0, "planet %d has more than three caches" % s)
		t.lt(float(n), 40.0, "planet %d has few enough that a cache is still a find" % s)


func test_caches_are_never_adjacent(t: TestHarness) -> void:
	var w := World.new(31)
	var bad := 0
	for d in range(0, Tuning.CORE_DEPTH):
		for x in range(-Tuning.HALF_WIDTH, Tuning.HALF_WIDTH + 1):
			if w.material_at(x, d) != Ore.CACHE:
				continue
			for od in range(-2, 3):
				for ox in range(-2, 3):
					if od == 0 and ox == 0:
						continue
					if w.material_at(x + ox, d + od) == Ore.CACHE:
						bad += 1
	t.eq(bad, 0, "no two caches sit within two cells; a pair reads as a vein, not a find")


func test_the_core_is_reachable_and_not_always_under_the_pad(t: TestHarness) -> void:
	var offsets := {}
	for s in range(1, 12):
		var w := World.new(s)
		var cd := w.core_depth()
		t.eq(w.material_at(w.core_x, cd), Ore.CORE, "planet %d has a core cell" % s)
		t.ok(w.is_open(w.core_x, cd - 2), "the core sits in a chamber, not in solid rock")
		t.ok(absi(w.core_x) <= Tuning.HALF_WIDTH - 5, "the chamber fits inside the world")
		offsets[w.core_x] = true
	t.gt(float(offsets.size()), 1.0,
		"the core is not in the same place on every planet, or 'straight down' is the only route")


func test_openness_reads_the_space_not_the_material(t: TestHarness) -> void:
	var w := World.new(3)
	t.approx(w.openness(0, -6, 3), 1.0, 1e-6, "open sky is fully open")
	var packed := w.openness(0, 60, 3)
	t.lt(packed, 0.6, "deep untouched rock is mostly closed")


## **A cell that is passable must always be a cell that BROKE.**
##
## `is_open` calls a cell passable at `OPEN_FILL` and `cut` used to break it only
## at exactly 0.0, which leaves a gap between the two. A cell whose fill lands
## inside that gap is flyable, never breaks, never pays and keeps its ore
## material forever. Measured on Rime: a scripted miner ping-ponged between two
## dug-out cells that still reported themselves as iron, reached 15 m in forty
## seconds and mined nothing.
##
## Reintroducing the bug means comparing against 0.0 instead of OPEN_FILL, and
## what catches it is sweeping the bite size so some cut lands in the gap.
func test_a_passable_cell_has_always_broken(t: TestHarness) -> void:
	var checked := 0
	for bite in [0.017, 0.033, 0.05, 0.0833, 0.1, 0.137, 0.25, 0.331]:
		for cls in [Classes.CINDER, Classes.RIME]:
			var w := World.new(4, cls)
			for d in [15, 45, 95, 150, 185]:
				for x in [-2, 0, 3]:
					if w.is_open(x, d):
						continue
					var broke := false
					for _i in range(400):
						if w.is_open(x, d):
							break
						if bool(w.cut(x, d, bite)["broke"]):
							broke = true
					checked += 1
					if not w.is_open(x, d):
						continue
					t.ok(broke,
						"(%d,%d) on %s became passable at bite %.4f without ever breaking"
						% [x, d, Classes.of(cls)["name"], bite])
					t.eq(w.material_at(x, d), Ore.AIR,
						"(%d,%d) on %s is passable and still reports material %d"
						% [x, d, Classes.of(cls)["name"], w.material_at(x, d)])
	t.gt(float(checked), 100.0, "the sweep did not actually cut anything")
