extends SceneTree

## Smoke test: boots the real scene and plays it.
##
##   godot --headless --script res://test/run_smoke.gd
##
## The pure tests cannot see a wiring bug - a scene that fails to build, a node
## that is never added, a render path that stopped being flushed, a HUD reading
## a field that no longer exists. Those only show up when something actually
## instantiates the game.
##
## The load-bearing assertion is that **what exists is drawn**. A subsystem that
## renders nothing and a subsystem that does not exist look identical from
## outside, and `visible_instance_count` is the flush: forgetting it fails
## completely silently.

var _t := TestHarness.new()


func _initialize() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	_t.begin("smoke > the scene loads")
	_t.ok(scene != null, "main.tscn failed to load")
	if scene == null:
		_finish()
		return

	var main = scene.instantiate()
	root.add_child(main)

	# Freeze first, then step. `_ready` has not fired yet - add_child() during
	# SceneTree._initialize() defers it to the first processed frame - so
	# freeze() boots the scene explicitly, and the assertions come after it.
	main.freeze()

	_t.begin("smoke > the scene builds its world")
	_t.ok(main.sim != null, "Sim was never created")
	_t.ok(main._cells != null, "the terrain field is missing from the scene")
	_t.ok(main._ship != null, "the ship is missing from the scene")
	_t.ok(main._lamp != null, "the lamp is missing from the scene")

	_drive_a_descent(main)
	_check_everything_that_exists_is_drawn(main)
	_check_the_controls_are_anchored(main)
	_check_there_is_always_a_way_on(main)
	_check_the_buttons_do_their_jobs(main)

	main.free()
	_finish()


## Drive it the way a thumb does, through the input handler, not by writing the
## direction vector. A way in the handler never calls is a missing feature with
## full coverage.
func _drive_a_descent(main) -> void:
	_t.begin("smoke > holding down actually digs")
	var before: float = main.sim.flight.depth()
	main.press_pad(Vector2(0, 1))
	main.advance(20.0)
	_t.gt(main.sim.flight.depth(), before + 4.0,
		"twenty seconds of holding down barely moved the ship")
	_t.lt(main.sim.power, Tuning.POWER_MAX,
		"digging cost no power at all, so the drill is not wired to the drain")


func _check_everything_that_exists_is_drawn(main) -> void:
	_t.begin("smoke > everything that exists is actually drawn")
	var drawn: int = main._cells.multimesh.visible_instance_count
	_t.gt(float(drawn), 0.0,
		"rock exists in the model but none is drawn - visible_instance_count is not being set")
	_t.lt(float(drawn), float(main.POOL) + 1.0, "the pool is not being overrun")

	# Count what the model says should be visible in the same window the
	# renderer uses, and require the two to agree exactly.
	var cx := int(roundf(main.sim.flight.pos.x))
	var cd := int(roundf(main.sim.flight.pos.y))
	var live := 0
	for d in range(cd - 21, cd + 22):
		for x in range(cx - 14, cx + 15):
			if not main.sim.world.is_open(x, d) and main.sim.world.material_at(x, d) != Ore.AIR:
				live += 1
	_t.eq(drawn, mini(live, main.POOL), "drawn cells do not match the model")

	_t.begin("smoke > the HUD reflects the run")
	_t.ok(main._hud.text.contains("POWER"), "the HUD is not being written")
	_t.ok(main._hud.text.contains("%d m" % int(main.sim.flight.depth())),
		"the depth on the HUD disagrees with the run")


## The controls must be ANCHORED to the viewport, never placed at a literal
## coordinate.
##
## A structural assertion rather than a behavioural one, because the bug it
## guards against is invisible at the size the tests run. The project stretches
## with `aspect = "expand"`, which keeps the base WIDTH and extends the HEIGHT,
## so on a 19.5:9 phone the canvas is about 1080x2340 while the base is
## 1080x1920. Controls laid out against the literal 1920 drew hundreds of pixels
## above where they belonged, and the report was "the button icons don't line up
## with where you need to press ... about .5 inches too high".
##
## **A headless run uses the base size, where the wrong layout and the right one
## are identical**, so no screenshot or coordinate check taken here could ever
## catch it. What CAN be checked is the property that makes it impossible.
func _check_the_controls_are_anchored(main) -> void:
	_t.begin("smoke > the controls are anchored, not placed")
	for pair in [["pad", main._pad], ["lamp button", main._lamp_btn], ["uplink button", main._uplink_btn]]:
		var name: String = pair[0]
		var c: Control = pair[1]
		_t.eq(c.anchor_bottom, 1.0,
			"the %s is not anchored to the bottom - it will drift on a tall screen" % name)
		_t.eq(c.anchor_top, 1.0,
			"the %s is anchored to the TOP, so its distance from the bottom follows the aspect" % name)
		_t.lt(c.offset_bottom, 1.0,
			"the %s is not offset upward from its anchor" % name)
		_t.eq(c.mouse_filter, Control.MOUSE_FILTER_STOP,
			"the %s does not consume its own touches, so one gesture drives two things" % name)
	_t.ok(main._pad.gui_input.get_connections().size() > 0,
		"the pad does not handle its own input, so its hit box is a second source of truth")
	_t.gt(main._lamp_btn.custom_minimum_size.y, 47.0, "the lamp button is at least thumb sized")
	_t.gt(main._uplink_btn.custom_minimum_size.y, 47.0, "the uplink button is at least thumb sized")


## Every state names a visible action, and there is always a way on.
##
## The assertion that would have caught the first bug a game built from this
## template shipped: the run ended, `advance()` returned early from then on, and
## the game froze with a live HUD. **A suite that always stops where the content
## stops cannot see past the end of the content**, so this one drives THROUGH
## the boundary, and through the real scene.
func _check_there_is_always_a_way_on(main) -> void:
	_t.begin("smoke > a finished descent can be left")
	main.press_pad(Vector2(0, 1))
	var guard := 0
	while main.sim.phase != Sim.Phase.OVER and guard < 400:
		main.advance(1.0)
		guard += 1
	_t.eq(main.sim.phase, Sim.Phase.OVER, "the descent never ended one way or the other")
	_t.ok(main.sim.outcome != "", "it ended without saying why")

	var banked: float = main.sim.credits
	var cut_depth: float = main.sim.deepest
	main.sim.redescend()
	main.advance(2.0)
	_t.eq(main.sim.phase, Sim.Phase.DESCENT, "redescending did not start a new descent")
	_t.approx(main.sim.credits, banked, 1e-4, "redescending lost the bank")
	_t.ok(main.sim.world.is_open(0, 3),
		"the shaft cut on the last descent did not survive into this one")

	var before: float = main.sim.flight.depth()
	main.press_pad(Vector2(0, 1))
	main.advance(3.0)
	_t.gt(main.sim.flight.depth(), before, "the next descent does not move when the loop runs")
	_t.gt(cut_depth, 1.0, "the first descent actually went somewhere")


func _check_the_buttons_do_their_jobs(main) -> void:
	_t.begin("smoke > the buttons are wired to the simulation")
	var mode: int = main.sim.lamp_mode
	main._lamp_btn.pressed.emit()
	_t.ok(main.sim.lamp_mode != mode, "pressing LAMP did not change the lamp mode")
	for _i in range(3):
		main._lamp_btn.pressed.emit()
	_t.ok(main.sim.lamp_mode >= 0 and main.sim.lamp_mode <= 2, "the lamp mode stayed in range")

	# Uplink with nothing aboard must be refused AND must look refused.
	main.sim.hold = {}
	main.sim.load_kg = 0.0
	main.advance(0.1)
	_t.eq(main._uplink_btn.disabled, true, "UPLINK is offered with an empty hold")


func _finish() -> void:
	print("")
	if _t.failures.is_empty():
		print("  smoke: %d assertions, all passing" % _t.checks)
		quit(0)
		return
	for f in _t.failures:
		print("  FAIL  %s" % f)
	print("")
	print("  smoke: %d assertions, %d FAILED" % [_t.checks, _t.failures.size()])
	quit(1)
