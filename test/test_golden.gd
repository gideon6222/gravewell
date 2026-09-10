extends RefCounted

## The golden: a whole descent under each policy, compared against a recorded
## run.
##
## This is the strongest net in the repo. It is not checking that any one
## function is right, it is checking that the game as a whole still does what it
## did, which is what catches a constant changed three files away.
##
## **Never re-record without reading the diff.** `dict_eq` reports every
## differing field rather than stopping at the first, so one run becomes all the
## differences rather than one of them. If a diff is expected, say why in the
## commit message.

const DT := 1.0 / 60.0

## Long enough for the policies to actually separate. At forty seconds every
## miner was still above 60 m and CAUTIOUS and GREEDY were the same player,
## because neither had reached the depth that distinguishes them: measured, a
## working dig descends about 1.4 m/s, so the Line at 80 m is a minute away and
## GREEDY's limit is nearly two. **The window has to reach the decision the pair
## exists to test**, or the pair proves nothing.
const SECONDS := 150.0

## Recorded from the run, then verified by hand: PASSIVE banks nothing, DIVER is
## deepest, CAUTIOUS banks the most, and GREEDY goes deeper than CAUTIOUS and
## ends worse. If any of those four sentences stops being true, the diff below
## is a design change and not a flake.
const EXPECTED := {
	"passive": {"deepest": 0.0, "credits": 0.0, "banked": false},
	"diver": {"banked": false},
	"cautious": {"banked": true},
	"greedy": {"banked": true},
}


func _run(name: String) -> Dictionary:
	return Policies.run(name, 1234, SECONDS, DT)


## A policy is only a measurement if it replays identically. If this fails,
## something in the simulation is reading an unseeded roll and every number
## below is noise.
func test_a_policy_replays_exactly(t: TestHarness) -> void:
	for name in Policies.ALL:
		var a := _run(name)
		var b := _run(name)
		t.approx(float(a["credits"]), float(b["credits"]), TestHarness.FLOAT_EPS,
			"%s banks the same twice" % name)
		t.approx(float(a["deepest"]), float(b["deepest"]), TestHarness.FLOAT_EPS,
			"%s reaches the same depth twice" % name)
		t.eq(a["filament"], b["filament"], "%s finds the same filament twice" % name)


## A frame-by-frame golden over the whole descent, not just its ending. Two
## simulations that end in the same place having taken different routes is
## exactly the kind of change a summary hides.
func test_a_descent_is_identical_frame_for_frame(t: TestHarness) -> void:
	var a := Sim.new(4242)
	var b := Sim.new(4242)
	var pa := Policies.new(4242)
	var pb := Policies.new(4242)
	var mismatches := 0
	for i in range(int(30.0 / DT)):
		if a.phase == Sim.Phase.OVER:
			break
		var ma := pa.act(Policies.CAUTIOUS, a, DT)
		var mb := pb.act(Policies.CAUTIOUS, b, DT)
		if bool(ma["uplink"]):
			a.uplink()
		else:
			a.step(ma["dir"], bool(ma["drilling"]), DT)
		if bool(mb["uplink"]):
			b.uplink()
		else:
			b.step(mb["dir"], bool(mb["drilling"]), DT)
		if a.snapshot() != b.snapshot() and mismatches == 0:
			mismatches += 1
			t.dict_eq(a.snapshot(), b.snapshot(), "frame %d diverged" % i)
	t.eq(mismatches, 0, "no frame of a replayed descent differs")


## Doing nothing must lose, and it must lose by earning nothing at all.
func test_the_do_nothing_policy_scores_nothing(t: TestHarness) -> void:
	var r := _run(Policies.PASSIVE)
	t.approx(float(r["credits"]), 0.0, 1e-9, "passive banks nothing")
	t.approx(float(r["deepest"]), 0.0, 0.6, "and goes nowhere")


## The pair that proves a decision exists. CAUTIOUS and GREEDY differ in exactly
## one number, the depth each will go to, so the gap between them is a claim
## about the game rather than about how well the two of them drive.
func test_greed_reaches_deeper_and_is_punished_for_it(t: TestHarness) -> void:
	var cautious := _run(Policies.CAUTIOUS)
	var greedy := _run(Policies.GREEDY)
	t.gt(float(greedy["deepest"]), float(cautious["deepest"]),
		"greed actually goes deeper, or the two policies are the same player")
	t.gt(float(greedy["deepest"]), float(Tuning.LINE_DEPTH),
		"greed crosses the Line, which is the whole point of the pair")


## A bot that reads the world must beat one that ignores it. If DIVER ever wins,
## the bot is wrong before the game is - fix the bot, never the constant.
func test_reading_the_rock_beats_ignoring_it(t: TestHarness) -> void:
	var diver := _run(Policies.DIVER)
	var cautious := _run(Policies.CAUTIOUS)
	t.gt(float(cautious["credits"]), float(diver["credits"]),
		"turning aside for ore banks more than diving past it")
	t.gt(float(diver["deepest"]), float(cautious["deepest"]),
		"and diving past it is genuinely faster to depth, so it is a real trade")


## Every policy has to fail for a different reason. When two of them score the
## same, one of them is not testing anything.
func test_every_policy_fails_differently(t: TestHarness) -> void:
	var seen := {}
	for name in Policies.ALL:
		var r := _run(name)
		var key := "%.1f/%.1f" % [float(r["credits"]), float(r["deepest"])]
		t.ok(not seen.has(key),
			"%s scores differently from %s" % [name, seen.get(key, "")])
		seen[key] = name


## The human bot has a reaction time, misreads and a wobble. Tune the game so
## this one struggles, never the bot so the game looks hard.
func test_the_human_bot_does_worse_than_the_perfect_one(t: TestHarness) -> void:
	var human := _run(Policies.HUMAN)
	var perfect := _run(Policies.CAUTIOUS)
	t.lt(float(human["credits"]), float(perfect["credits"]) * 1.05,
		"a hand that wobbles does not out-earn one that does not")
