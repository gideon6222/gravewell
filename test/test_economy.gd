extends RefCounted

## The economy, and the one complaint it exists to answer.
##
## "I can afford upgrades pretty early on for fuel and cooling so neither is a
## risk." Every case here is aimed at some part of that sentence.


## **The whole structural fix in one assertion.** If a counter to a threat can be
## bought with mined ore at any price, the two-currency split is decoration and
## the game is back to Coreward's failure.
func test_no_threat_counter_can_be_bought_with_ore(t: TestHarness) -> void:
	t.gt(float(Upgrades.COUNTERS.size()), 0.0, "there are counters to test")
	for u in Upgrades.COUNTERS:
		t.ok(not u.has("base"),
			"%s has a credit price, so ore can buy safety" % u["name"])
		t.ok(u.has("cost"), "%s has no filament price at all" % u["name"])
		t.lt(Upgrades.price(String(u["id"]), 0, 0), 0.0,
			"%s returns a credit price when asked for one" % u["name"])

	# And the inverse: nothing on the credit ladder may cost filament, or
	# filament stops being the thing that only exploring earns.
	for u in Upgrades.LADDER:
		t.eq(Upgrades.counter_cost(String(u["id"]), 0), -1,
			"%s has a filament price, so exploring is being spent on a bigger hold" % u["name"])


## **The counter has to be affordable from what a planet actually holds.** The
## probe measured 17.5 filament a planet with only about 4.5 of it above the
## Line, so the first seal has to fit inside roughly that, or it can never be
## bought before the threat it counters.
func test_the_first_seal_fits_inside_one_planet_of_filament(t: TestHarness) -> void:
	var first := Upgrades.counter_cost("seal", 0)
	t.gt(float(first), 0.0, "the first seal has a price")
	t.lt(float(first), 6.0,
		"the first seal costs %d filament, more than a planet yields above the Line" % first)
	# And the ladder as a whole must not be affordable off one planet either, or
	# there is no reason to visit a second.
	var total := 0
	for u in Upgrades.COUNTERS:
		for c in u["cost"]:
			total += int(c)
	t.gt(float(total), 20.0,
		"every counter in the game costs %d filament, which one planet very nearly pays for" % total)


## Motherload's ladder rises: late rungs demand more trips than early ones, not
## fewer. A flat multiplier makes the last rung the cheapest in real terms.
func test_the_price_curve_steepens(t: TestHarness) -> void:
	for u in Upgrades.LADDER:
		var id: String = u["id"]
		var last_ratio := 0.0
		var prev := Upgrades.price(id, 0, 0)
		t.gt(prev, 0.0, "%s has a first rung" % id)
		for level in range(1, Upgrades.max_level(id)):
			var p := Upgrades.price(id, level, 0)
			t.gt(p, prev, "%s rung %d costs more than rung %d" % [id, level, level - 1])
			var ratio := p / prev
			t.gt(ratio, last_ratio,
				"%s rung %d does not steepen: %.2fx after %.2fx" % [id, level, ratio, last_ratio])
			last_ratio = ratio
			prev = p
		t.lt(Upgrades.price(id, Upgrades.max_level(id), 0), 0.0,
			"%s does not report itself maxed at the top" % id)


## Rogue Legacy's fix: every purchase anywhere in the tree makes the next one
## dearer, so a farmed currency cannot trivialise the late game.
func test_buying_anything_makes_everything_dearer(t: TestHarness) -> void:
	var fresh := Upgrades.price("drill", 0, 0)
	var after := Upgrades.price("drill", 0, 6)
	t.gt(after, fresh * 1.2, "six purchases elsewhere do not raise this price")
	t.lt(after, fresh * 2.0, "the surcharge is a lever, not a wall")


## Every ladder actually does something, and the top of it is worth reaching.
func test_every_ladder_is_a_real_ladder(t: TestHarness) -> void:
	for u in Upgrades.LADDER:
		var id: String = u["id"]
		t.approx(Upgrades.mult(id, 0), 1.0, 1e-6, "%s starts at the base value" % id)
		var top := Upgrades.mult(id, Upgrades.max_level(id))
		t.gt(top, 1.25, "%s tops out at %.2fx, which is not worth five rungs" % [id, top])
		for level in range(1, Upgrades.max_level(id) + 1):
			t.gt(Upgrades.mult(id, level), Upgrades.mult(id, level - 1),
				"%s rung %d is no better than rung %d" % [id, level, level - 1])
		# Past the end it clamps rather than reading off the array.
		t.approx(Upgrades.mult(id, 99), top, 1e-6, "%s clamps past its top rung" % id)


## A tool that reopens a sealed place must also give a new VERB, or backtracking
## is a fetch and return. Metroid Dread's weakest abilities are the key-only ones.
func test_every_tool_gate_also_gives_a_verb(t: TestHarness) -> void:
	for u in Upgrades.COUNTERS:
		var verb := String(u.get("verb", ""))
		t.gt(float(verb.length()), 12.0,
			"%s is a key and nothing else, so opening its door is a fetch quest" % u["name"])


## An upgrade that removes a threat removes the mechanic with it.
func test_a_seal_never_removes_the_line(t: TestHarness) -> void:
	var last := 2.0
	for level in range(Upgrades.SEAL_RELIEF.size()):
		var r := Upgrades.seal_relief(level)
		t.lt(r, last, "seal rung %d relieves more than rung %d" % [level, level - 1])
		t.gt(r, 0.0, "seal rung %d removes the Line entirely" % level)
		last = r
	t.gt(Upgrades.seal_relief(99), 0.25,
		"a fully sealed hull still feels the deep, or the mechanic is bought away")


## **Everything unlocked plus exactly one teaser.** At most one sealed row, and
## never zero while something is still gated.
func test_the_rack_shows_one_teaser_and_no_furniture(t: TestHarness) -> void:
	for deepest in [0.0, 20.0, 55.0, 90.0, 140.0, 199.0]:
		var rows := Upgrades.rack({}, deepest, 0, 99999.0, 99)
		var sealed := 0
		for r in rows:
			if bool(r["sealed"]):
				sealed += 1
		t.lt(float(sealed), 2.0,
			"at %.0f m the rack shows %d sealed rows, which is furniture" % [deepest, sealed])

		var anything_gated := false
		for u in Upgrades.LADDER + Upgrades.COUNTERS:
			if deepest < Upgrades._gate_of(String(u["id"]), 0):
				anything_gated = true
		if anything_gated:
			t.eq(sealed, 1,
				"at %.0f m something is gated but the rack shows no teaser" % deepest)


func test_the_teaser_is_the_shallowest_thing_out_of_reach(t: TestHarness) -> void:
	var deepest := 30.0
	var rows := Upgrades.rack({}, deepest, 0, 0.0, 0)
	var teaser := {}
	for r in rows:
		if bool(r["sealed"]):
			teaser = r
	t.ok(not teaser.is_empty(), "the fixture has a teaser to check")

	# Nothing gated shallower than the teaser may be missing from the rack.
	for u in Upgrades.LADDER + Upgrades.COUNTERS:
		var g := Upgrades._gate_of(String(u["id"]), 0)
		if g <= deepest or g >= float(teaser["gate"]):
			continue
		t.ok(false, "%s is gated shallower than the teaser and is not shown" % u["name"])


## Three separate booleans, and only refusal is grey.
func test_sealed_maxed_and_unaffordable_are_three_different_states(t: TestHarness) -> void:
	var poor := Upgrades.rack({}, 200.0, 0, 0.0, 0)
	for r in poor:
		t.ok(not bool(r["afford"]), "%s is affordable with nothing at all" % r["name"])
		t.ok(not bool(r["sealed"]), "%s is sealed at the bottom of the world" % r["name"])

	var maxed_levels := {}
	for u in Upgrades.LADDER:
		maxed_levels[u["id"]] = Upgrades.max_level(String(u["id"]))
	var rich := Upgrades.rack(maxed_levels, 200.0, 0, 1.0e9, 999)
	for r in rich:
		if not bool(r["filament"]):
			t.ok(bool(r["maxed"]), "%s is not reported maxed when it is" % r["name"])
			t.ok(not bool(r["afford"]), "%s offers a purchase when it is maxed" % r["name"])


# ── the ladder has to actually change the world ───────────────────────────
#
# An upgrade that is a number in a shop and nothing in the hand is the thing
# `CRAFT.md` calls "bought on trust". Each of these buys a rung and measures the
# difference in the simulation.

const DT := 1.0 / 60.0


func _rich(id: String) -> Sim:
	var sim := Sim.new(31)
	sim.credits = 1.0e7
	sim.filament = 999
	sim.record = 999.0
	return sim


func test_the_drill_ladder_cuts_faster(t: TestHarness) -> void:
	var sim := _rich("drill")
	var before := sim.drill_rate()
	t.ok(sim.buy("drill"), "the drill rung could not be bought with everything")
	t.gt(sim.drill_rate(), before * 1.2, "buying a drill rung did not speed the drill up")


func test_the_hold_ladder_carries_more(t: TestHarness) -> void:
	var sim := _rich("hold")
	var before := sim.hold_capacity()
	t.ok(sim.buy("hold"), "the hold rung could not be bought")
	t.gt(sim.hold_capacity(), before * 1.2, "buying a hold rung did not add capacity")


func test_the_thrust_ladder_is_felt_in_the_hand(t: TestHarness) -> void:
	var slow := _rich("thrust")
	var fast := _rich("thrust")
	fast.buy("thrust")
	fast.buy("thrust")
	# Drive both down an open shaft and compare where they end up. Measuring the
	# multiplier would only prove the table; this proves the flight reads it.
	for sim in [slow, fast]:
		for d in range(-2, 40):
			sim.world.fill[sim.world.idx(0, d)] = 0.0
			sim.world.mat[sim.world.idx(0, d)] = Ore.AIR
		for _i in range(90):
			sim.step(Vector2(0, 1), false, DT)
	t.gt(fast.flight.depth(), slow.flight.depth() + 0.4,
		"two thrust rungs did not move the ship any further in a second and a half")


func test_the_lamp_ladder_reaches_further(t: TestHarness) -> void:
	var sim := _rich("lamp")
	var before := sim.lamp_reach()
	t.ok(sim.buy("lamp"), "the lamp rung could not be bought")
	t.gt(sim.lamp_reach(), before * 1.1, "buying a lamp rung did not lengthen the reach")


## **The whole point of the second currency, measured in the simulation rather
## than in the table.** Credits cannot buy the counter at any amount.
func test_ore_money_cannot_buy_the_seal(t: TestHarness) -> void:
	var sim := Sim.new(31)
	sim.record = 999.0
	sim.credits = 1.0e9        ## every ore on every planet, several times over
	sim.filament = 0
	t.ok(not sim.buy("seal"), "a billion credits bought a pressure seal")
	t.eq(sim.level_of("seal"), 0, "and it took a rung anyway")
	t.approx(sim.credits, 1.0e9, 1.0, "and it charged for it")

	sim.filament = Upgrades.counter_cost("seal", 0)
	t.ok(sim.buy("seal"), "the right currency does not buy it either")
	t.eq(sim.filament, 0, "and the filament was spent")


## And the seal must actually relieve the Line, or it is a purchase with no
## effect at exactly the moment the player needed one.
func test_a_seal_relieves_the_line_in_the_simulation(t: TestHarness) -> void:
	var bare := Sim.new(31)
	var sealed := Sim.new(31)
	sealed.record = 999.0
	sealed.filament = 99
	t.ok(sealed.buy("seal"), "the fixture could not buy a seal")

	for sim in [bare, sealed]:
		sim.flight.pos = Vector2(0, 160.0)
	t.gt(bare.pressure_rate(), 0.0, "the fixture is actually past the Line")
	t.lt(sealed.pressure_rate(), bare.pressure_rate() * 0.9,
		"a seal does not reduce the drain")
	t.gt(sealed.pressure_rate(), 0.0,
		"a seal removes the Line entirely, and with it the mechanic")


## Filament found underground reaches the shop. If the two ever disagree, the
## secret layer stops paying for itself.
func test_filament_found_is_filament_spendable(t: TestHarness) -> void:
	var sim := Sim.new(9)
	sim.record = 999.0
	var found := 0
	sim.found_cache.connect(func(n): found += n)
	# Open every cache in the shallow bands.
	for d in range(Tuning.CACHE_MIN_DEPTH, 120):
		for x in range(-Tuning.HALF_WIDTH, Tuning.HALF_WIDTH + 1):
			if sim.world.material_at(x, d) == Ore.CACHE:
				var r := sim.world.cut(x, d, 9999.0)
				sim.filament += int(r["filament"])
				found += int(r["filament"])
	t.gt(float(sim.filament), 0.0, "the fixture opened no caches at all")
	var before := sim.filament
	var cost := Upgrades.counter_cost("seal", 0)
	t.ok(sim.filament >= cost,
		"a planet's caches down to 120 m yield %d filament, under the %d a seal costs"
		% [sim.filament, cost])
	t.ok(sim.buy("seal"), "the filament in hand did not buy the seal")
	t.eq(sim.filament, before - cost, "the seal charged the wrong amount")


# ── the Hold, and what carries between planets ────────────────────────────

## Everything the player has KEPT comes with them to a new world, and only the
## planet is new. A meta-goal that resets is not a meta-goal.
func test_a_new_planet_keeps_everything_you_earned(t: TestHarness) -> void:
	var sim := Sim.new(4)
	sim.credits = 1234.0
	sim.filament = 7
	sim.cores = 2
	sim.record = 143.0
	sim.levels = {"drill": 2, "hold": 1}
	sim.bought = 3
	var old_world := sim.world

	sim.next_planet()

	t.approx(sim.credits, 1234.0, 1e-4, "credits did not survive the crossing")
	t.eq(sim.filament, 7, "filament did not survive the crossing")
	t.eq(sim.cores, 2, "the cores did not survive the crossing")
	t.approx(sim.record, 143.0, 1e-4, "the record did not survive, so the rack re-seals")
	t.eq(sim.level_of("drill"), 2, "the ladder did not survive the crossing")
	t.eq(sim.bought, 3, "the purchase count did not survive, so prices reset")
	t.ok(sim.world != old_world, "it is the same planet")
	t.eq(sim.phase, Sim.Phase.DESCENT, "the new planet does not start a descent")
	t.approx(sim.flight.depth(), -1.5, 0.5, "the ship did not start at the new surface")


## Leaving the Hold does the right one of two things, and only carrying a core
## out finishes a planet.
func test_launching_redescends_unless_the_core_came_out(t: TestHarness) -> void:
	var recovered := Sim.new(4)
	recovered.outcome = "out of power"
	recovered.phase = Sim.Phase.OVER
	var same := recovered.world
	recovered.enter_hold()
	t.eq(recovered.phase, Sim.Phase.HOLD, "the descent did not end in the Hold")
	recovered.launch()
	t.ok(recovered.world == same,
		"running out moved the player to a new planet, so the tunnels are lost")
	t.eq(recovered.phase, Sim.Phase.DESCENT, "launching did not start a descent")

	var escaped := Sim.new(4)
	escaped.outcome = "escaped with the core"
	escaped.phase = Sim.Phase.OVER
	var before := escaped.world
	escaped.enter_hold()
	escaped.launch()
	t.ok(escaped.world != before, "carrying the core out did not finish the planet")
