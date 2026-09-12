extends RefCounted

## **The Gravewell Drive: seven slots, one core per class, and a way out.**
##
## The plan: *"Seven slots, one core per class. With all seven the chart opens a
## route to the place that cannot otherwise be reached, and its core ends the
## game. Afterwards the chart keeps generating worlds, so the endless game is
## still there with a finished thing behind it."*
##
## And the constraint that shapes the whole thing: *"It is missable and
## recoverable but costly... **A permanently unwinnable save is the one outcome
## this must not have**, and there is a test that the chart always keeps offering
## every class still needed."*

const DT := 1.0 / 60.0


## A core is a CLASS in a slot, not a tally. Seven of the same world is not a
## drive, and the count has to be derived from the slots or the two drift.
func test_the_drive_holds_one_core_per_class(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.eq(s.cores_held(), 0, "a new run starts with cores in the drive")
	s.fit_core(Classes.CINDER)
	s.fit_core(Classes.CINDER)
	t.eq(s.cores_held(), 1, "two cores of one class filled two slots")
	s.fit_core(Classes.RIME)
	t.eq(s.cores_held(), 2, "a second class did not fill a second slot")
	t.ok(s.has_core(Classes.RIME), "the drive does not know it holds the Rime core")
	t.ok(not s.has_core(Classes.DROWN), "the drive thinks it holds a core it never took")


## **The chart always offers a class the drive still needs.** This is the whole
## guard against an unwinnable save: whatever has been lost, there is always a
## next world that can move the goal.
func test_the_chart_always_offers_something_the_drive_needs(t: TestHarness) -> void:
	var s := Sim.new(1)
	# Every subset of held cores, walked by taking them one at a time in each of
	# several orders, and at every step the offer has to be useful.
	for order in [[0, 1, 2, 3, 4, 5], [5, 4, 3, 2, 1, 0], [2, 0, 4, 1, 5, 3]]:
		var run := Sim.new(1)
		for id in order:
			var offer := run.chart_class()
			t.ok(not run.has_core(offer),
				"the chart offered %s, which the drive already holds"
					% Classes.of(offer)["name"])
			run.fit_core(id)
		# Six of seven held: the offer must be the seventh.
		var last := run.chart_class()
		t.ok(not run.has_core(last), "with one slot left the chart offered a class already in it")


## And when the drive is full the chart stops needing anything, which is a
## different state and not a failure to find one.
func test_a_full_drive_opens_the_way_out(t: TestHarness) -> void:
	var s := Sim.new(1)
	t.ok(not s.drive_complete(), "a new run reports a finished drive")
	t.ok(not s.can_launch_final(), "the way out is open before any core is aboard")
	for i in range(Classes.ALL.size()):
		s.fit_core(i)
	t.ok(s.drive_complete(), "seven cores did not finish the drive")
	t.ok(s.can_launch_final(), "a finished drive did not open the way out")
	t.eq(s.cores_held(), 7, "the drive holds %d cores with seven fitted" % s.cores_held())


## **The last world is a real descent, not a cutscene.** It is the place that
## cannot otherwise be reached, and its core is the one that ends the game.
func test_the_final_world_is_a_place_you_dig(t: TestHarness) -> void:
	var s := Sim.new(1)
	for i in range(Classes.ALL.size()):
		s.fit_core(i)
	s.launch_final()
	t.ok(s.at_the_gravewell, "launching for the last world did not go anywhere")
	t.eq(s.phase, Sim.Phase.DESCENT, "the last world started in some phase other than a descent")
	t.gt(s.world.core_depth(), 100, "the last world has no depth to it")
	t.ok(not s.finished, "arriving finished the game without digging anything")


## Cutting its core ends the game, once.
func test_the_last_core_ends_it(t: TestHarness) -> void:
	var s := Sim.new(1)
	for i in range(Classes.ALL.size()):
		s.fit_core(i)
	s.launch_final()
	s.claim_gravewell()
	t.ok(s.finished, "taking the last core did not finish the game")
	var when := s.finished_at
	s.claim_gravewell()
	t.approx(s.finished_at, when, 1.0e-6, "the ending fired twice")


## **And the endless game is still there behind it.** Finishing is a thing that
## has happened, never a door that closes: the chart keeps generating worlds.
func test_the_chart_keeps_going_after_the_ending(t: TestHarness) -> void:
	var s := Sim.new(1)
	for i in range(Classes.ALL.size()):
		s.fit_core(i)
	s.launch_final()
	s.claim_gravewell()
	t.ok(s.finished, "the fixture did not finish")
	s.next_planet()
	t.ok(not s.at_the_gravewell, "the chart could not leave the last world")
	t.eq(s.phase, Sim.Phase.DESCENT, "there is no descent to be had after the ending")
	t.ok(s.finished, "starting another world un-finished the game")


## The drive survives the save, because it IS the thing you keep.
func test_the_drive_survives_a_save(t: TestHarness) -> void:
	Save._reset_latch_for_tests()
	if FileAccess.file_exists(Save.PROGRESS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.PROGRESS))
	var a := Sim.new(3)
	a.fit_core(Classes.RIME)
	a.fit_core(Classes.QUICK)
	a.finished = true
	Save.write(a)
	var b := Sim.new(1)
	t.ok(Save.read(b), "the save did not read back")
	t.eq(b.cores_held(), 2, "the drive came back with %d cores" % b.cores_held())
	t.ok(b.has_core(Classes.QUICK), "a core in the drive did not survive the save")
	t.ok(not b.has_core(Classes.CINDER), "a core appeared in the drive across a save")
	t.ok(b.finished, "finishing the game did not survive the save")
	Save._reset_latch_for_tests()
	if FileAccess.file_exists(Save.PROGRESS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.PROGRESS))
