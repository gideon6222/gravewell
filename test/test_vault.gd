extends RefCounted

## **Vaults: the thing you see in the first hour and open in the sixth.**
##
## The plan: "Sealed behind rock a drill tier you do not have yet cannot cut.
## Visible from the first hour, opened at hour six." They are the only HARD gate
## in the game - everything else on the ladder is a soft speedup, and the genre
## research is explicit that a ladder of pure soft speedups makes repeat runs
## predictable, which is the documented critique of Dome Keeper.
##
## The rule the whole economy has to keep: **the game is completable with zero
## vaults opened.** A vault is what makes coming back worth it, never a tax on
## players who do not.

const DT := 1.0 / 60.0


func _find_vault(w: World) -> Vector2i:
	for d in range(0, Tuning.CORE_DEPTH):
		for x in range(-Tuning.HALF_WIDTH, Tuning.HALF_WIDTH + 1):
			if w.material_at(x, d) == Ore.VAULT:
				return Vector2i(x, d)
	return Vector2i(-99999, 0)


## **They exist, and there are several.** A secret tier the generator never makes
## fails as absence, and one per planet is a curiosity rather than a system.
func test_a_planet_has_vaults_in_it(t: TestHarness) -> void:
	for planet in [1, 3, 5]:
		var w := World.new(planet)
		var n := w.count_of(Ore.VAULT)
		t.gt(n, 8, "planet %d has %d vault seal cells, which is not a sealed place" % [planet, n])
	# And they are not everywhere: a vault you trip over is not a secret.
	var w2 := World.new(1)
	t.lt(w2.count_of(Ore.VAULT), 400,
		"there are %d vault cells, which is a material and not a secret" % w2.count_of(Ore.VAULT))


## **Visible from the first hour.** At least one is shallow enough to be met on a
## first descent, or the gate is something read about rather than seen.
func test_one_is_shallow_enough_to_meet_early(t: TestHarness) -> void:
	var shallowest := Tuning.CORE_DEPTH
	for planet in [1, 2, 3]:
		var w := World.new(planet)
		var c := _find_vault(w)
		if c.x != -99999:
			shallowest = mini(shallowest, c.y)
	t.lt(shallowest, 60, "the shallowest vault on any of three planets is at %d m" % shallowest)


## **The seal refuses a drill it out-ranks, and refusing costs nothing.** A gate
## that eats power while it says no is a gate that punishes finding it.
func test_a_seal_refuses_a_drill_that_is_too_weak(t: TestHarness) -> void:
	var s := Sim.new(1)
	var c := _find_vault(s.world)
	t.ok(c.x != -99999, "the fixture found no vault at all")
	s.levels = {"drill": 0}
	var before := s.world.fill_at(c.x, c.y)
	var res := s.world.cut(c.x, c.y, 500.0, 0)
	t.approx(s.world.fill_at(c.x, c.y), before, 1.0e-4,
		"a tier 0 drill cut the seal anyway, so the gate is not a gate")
	t.approx(float(res["cut"]), 0.0, 1.0e-4,
		"the seal refused the drill and charged for the attempt")
	t.ok(bool(res["sealed"]), "the seal did not say it was a seal, so nothing can explain it")


## And yields to one that out-ranks it. A gate with no key is a wall.
func test_a_seal_yields_to_the_tier_it_names(t: TestHarness) -> void:
	var s := Sim.new(1)
	var c := _find_vault(s.world)
	var need := Tuning.vault_tier(float(c.y))
	t.gt(need, 0, "the seal at %d m needs tier 0, which every ship already has" % c.y)
	t.lt(need, Upgrades.rungs("drill"),
		"the seal needs tier %d, which is past the top of the drill ladder" % need)
	for _i in range(400):
		s.world.cut(c.x, c.y, 20.0, need)
	t.ok(s.world.is_open(c.x, c.y),
		"a tier %d drill could not open a seal that asks for tier %d" % [need, need])


## **Behind it is something worth the trip**, and it is never ore: a vault that
## pays in credits is a slow mine, and the whole point is that it pays in things
## money cannot buy.
func test_a_vault_holds_something_money_cannot_buy(t: TestHarness) -> void:
	var w := World.new(1)
	var keeps := w.count_of(Ore.KEEPSAKE)
	var logs := w.count_of(Ore.LOG)
	t.eq(keeps, 1, "the planet holds %d keepsakes, and a keepsake is the ONE thing it has" % keeps)
	t.gt(logs, 0, "the planet holds no log fragments at all")


## Cutting one banks it, and the same one never banks twice.
func test_taking_a_keepsake_banks_it_once(t: TestHarness) -> void:
	var s := Sim.new(1)
	var c := Vector2i(-99999, 0)
	for d in range(0, Tuning.CORE_DEPTH):
		for x in range(-Tuning.HALF_WIDTH, Tuning.HALF_WIDTH + 1):
			if s.world.material_at(x, d) == Ore.KEEPSAKE:
				c = Vector2i(x, d)
				break
	t.ok(c.x != -99999, "no keepsake to take")
	t.eq(s.keepsakes.size(), 0, "the run started with a keepsake already in it")
	for _i in range(400):
		var res := s.world.cut(c.x, c.y, 40.0, 9)
		if bool(res["keepsake"]):
			s.take_keepsake()
	t.eq(s.keepsakes.size(), 1, "cutting the keepsake did not bank it, or banked it twice")
	s.take_keepsake()
	t.eq(s.keepsakes.size(), 1, "the same planet's keepsake banked twice")


## **The run is completable with zero vaults opened.** Animal Well's rule, and the
## one the plan calls out by name: a secret is a reason to come back, never a tax
## on the player who does not.
func test_nothing_required_is_behind_a_seal(t: TestHarness) -> void:
	var w := World.new(1)
	# The core, and a clear route to it, must not pass through a seal. Checked by
	# asking whether the core is reachable treating every seal as solid rock,
	# which is what a player without the tier actually faces.
	t.ok(w.route_to_core_without_vaults() >= 0.0,
		"the core cannot be reached without opening a vault, so the gate is a wall")
