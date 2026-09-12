extends RefCounted

## Progress, settings, and the two ways they are allowed to interact, which is
## none.


func _clean() -> void:
	Save._reset_latch_for_tests()
	if FileAccess.file_exists(Save.PROGRESS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.PROGRESS))
	if FileAccess.file_exists(Save.SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.SETTINGS))


## **A test must not depend on what the case before it left on disk.** Both the
## file AND the latch are reset, because the latch is a static that outlives any
## one fixture.
func test_a_save_round_trips(t: TestHarness) -> void:
	_clean()
	var a := Sim.new(3)
	a.credits = 4321.5
	a.filament = 11
	a.fit_core(Classes.CINDER)
	a.fit_core(Classes.RIME)
	a.fit_core(Classes.DROWN)
	a.record = 167.25
	a.planet = 5
	a.levels = {"drill": 2, "lamp": 1}
	a.bought = 3
	Save.write(a)

	var b := Sim.new(1)
	t.ok(Save.read(b), "the save did not read back")
	t.approx(b.credits, 4321.5, 1e-4, "credits")
	t.eq(b.filament, 11, "filament")
	t.eq(b.cores_held(), 3, "cores")
	t.approx(b.record, 167.25, 1e-4, "the record, which gates the whole rack")
	t.eq(b.planet, 5, "the planet")
	t.eq(b.level_of("drill"), 2, "a ladder level")
	t.eq(b.bought, 3, "the purchase count, which prices everything")
	_clean()


## Levels have to come back as INTS. A Dictionary from JSON is Variants, and a
## float level indexes the multiplier array with a float, which is a different
## kind of wrong from a missing save.
func test_ladder_levels_come_back_as_integers(t: TestHarness) -> void:
	_clean()
	var a := Sim.new(3)
	a.levels = {"drill": 3}
	Save.write(a)
	var b := Sim.new(1)
	Save.read(b)
	t.eq(typeof(b.levels["drill"]), TYPE_INT, "a level came back as something other than an int")
	t.approx(b.drill_rate(), Tuning.DRILL_RATE * Upgrades.mult("drill", 3), 1e-4,
		"the restored level does not reach the drill")
	_clean()


## **A save is nine numbers, not a planet.** The world is rebuilt from its seed,
## which is the whole point of generation being a pure seeded hash.
func test_the_world_is_rebuilt_from_its_seed(t: TestHarness) -> void:
	_clean()
	var a := Sim.new(7, Classes.RIME)
	a.planet = 7
	Save.write(a)
	var b := Sim.new(1, Classes.CINDER)
	Save.read(b)
	t.eq(b.world.class_id, Classes.RIME, "the world class did not survive")
	t.eq(b.world.planet_seed, 7, "the world seed did not survive")
	t.eq(b.world.mat, a.world.mat, "the rebuilt planet is a different planet")
	var size := FileAccess.get_file_as_bytes(Save.PROGRESS).size()
	t.lt(float(size), 1200.0,
		"the save is %d bytes, so something is storing the world rather than its seed" % size)
	_clean()


## No save means a fresh game, and CONTINUE greyed rather than hidden.
func test_no_save_is_a_first_run(t: TestHarness) -> void:
	_clean()
	t.ok(not Save.exists(), "a save exists before anything was written")
	var s := Sim.new(1)
	t.ok(not Save.read(s), "reading a missing save reported success")
	t.approx(s.credits, 0.0, 1e-6, "a failed read left something behind")
	_clean()


## **The one-way latch.** Erasing progress has to survive the save that fires on
## the way out, or backgrounding the app writes the state straight back.
func test_erasing_progress_survives_the_save_on_the_way_out(t: TestHarness) -> void:
	_clean()
	var s := Sim.new(3)
	s.credits = 900.0
	Save.write(s)
	t.ok(Save.exists(), "the fixture did not save")

	Save.erase()
	t.ok(not Save.exists(), "erase did not remove the save")

	# This is exactly what NOTIFICATION_APPLICATION_PAUSED does a moment later.
	Save.write(s)
	t.ok(not Save.exists(), "the save on the way out wrote the erased progress back")

	var fresh := Sim.new(1)
	t.ok(not Save.read(fresh), "the erased save read back")
	t.approx(fresh.credits, 0.0, 1e-6, "and it brought the credits with it")
	_clean()


## **Preferences are not progress.** Two files, and neither touches the other.
func test_settings_and_progress_are_separate_files(t: TestHarness) -> void:
	_clean()
	Save.write_settings(0.3, 0.55, false)
	var s := Sim.new(3)
	s.credits = 500.0
	Save.write(s)

	Save.erase()
	var kept := Save.read_settings()
	t.approx(float(kept["music"]), 0.3, 1e-4,
		"erasing progress reset the music volume, so the two files are one file")
	t.approx(float(kept["sfx"]), 0.55, 1e-4, "erasing progress reset the sfx volume")
	t.eq(bool(kept["haptics"]), false, "erasing progress reset haptics")
	t.ok(Save.SETTINGS != Save.PROGRESS, "settings and progress share a path")
	_clean()


func test_settings_default_sensibly_when_missing(t: TestHarness) -> void:
	_clean()
	var d := Save.read_settings()
	t.gt(float(d["music"]), 0.0, "music defaults to silent, so a first run has no score")
	t.gt(float(d["sfx"]), 0.0, "sfx defaults to silent")
	t.eq(bool(d["haptics"]), true, "haptics default off")
	_clean()


## A save from an older shape starts fresh rather than half-loading.
func test_a_save_from_another_version_is_ignored(t: TestHarness) -> void:
	_clean()
	var f := FileAccess.open(Save.PROGRESS, FileAccess.WRITE)
	f.store_string(JSON.stringify({"v": Save.VERSION + 99, "credits": 5000.0}))
	f.close()
	var s := Sim.new(1)
	t.ok(not Save.read(s), "a save from another version was read anyway")
	t.approx(s.credits, 0.0, 1e-6, "and it brought its credits with it")
	_clean()


## **The version has to be bumped when the shape of a field changes, not only
## when a field is added.** Version 2 stored `cores` as a tally, an integer.
## Version 3 stores the drive, an array of class ids. Left at 2, such a save
## passes the version check and then `as Array` on an integer yields null, which
## the loop walks straight into. The bump is what makes that unreachable, so this
## pins the bump rather than the crash.
func test_a_version_2_save_with_a_core_tally_is_refused(t: TestHarness) -> void:
	_clean()
	var f := FileAccess.open(Save.PROGRESS, FileAccess.WRITE)
	f.store_string(JSON.stringify({"v": 2, "credits": 900.0, "cores": 3}))
	f.close()
	var s := Sim.new(1)
	t.ok(not Save.read(s), "a save whose cores field is a tally was read into a drive")
	t.eq(s.cores_held(), 0, "the drive came back holding %d cores from a v2 save" % s.cores_held())
	t.approx(s.credits, 0.0, 1e-6, "and it brought its credits with it")
	_clean()
