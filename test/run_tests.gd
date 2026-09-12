extends SceneTree

## Entry point for the pure tests.
##
##   godot --headless --script res://test/run_tests.gd
##
## Almost nothing loaded here touches a Node, a viewport or an input event, so
## this runs in a container with no GPU and no display in about a second. The
## scene is exercised separately by run_smoke.gd, which is slower and catches a
## different class of bug.
##
## The one deliberate exception is `test_controls.gd`, whose subject IS the
## wiring between a thumb and the simulation. It instantiates the scene and
## drives real input events through the d-pad's own handler, but it never adds
## anything to a tree and never opens a viewport, so it still runs here. See its
## header for why that boundary is exactly where it is.
##
## **The suite list is a glob, not a hand-written array.** TESTING.md: any list
## of things to run that is maintained by hand fails silently in the safe-looking
## direction - a new `test_*.gd` that nobody added to the array is a file full of
## assertions that never run and a suite that goes green having proved less than
## it did yesterday.


func _initialize() -> void:
	var suites := []
	var names: Array[String] = []
	var dir := DirAccess.open("res://test")
	if dir == null:
		print("  FAIL  cannot open res://test")
		quit(1)
		return
	for f in dir.get_files():
		# .gd in the editor, .gd.remap in an exported build.
		var file := f.trim_suffix(".remap")
		if not file.begins_with("test_") or not file.ends_with(".gd"):
			continue
		names.append(file)
	names.sort()
	for file in names:
		suites.append(load("res://test/" + file).new())

	if suites.is_empty():
		print("  FAIL  the glob matched no suites, which means the runner is broken, not that the game is fine")
		quit(1)
		return

	print("  suites: %s" % ", ".join(names))
	var code := TestHarness.run_all(suites)
	quit(code)
