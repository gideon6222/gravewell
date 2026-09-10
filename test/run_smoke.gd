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
	_t.ok(main._terrain != null, "the terrain is missing from the scene")
	_t.ok(main._haze != null, "the air-light quad is missing from the scene")
	_t.ok(main._ship != null, "the ship is missing from the scene")
	_t.ok(main._lamp != null, "the lamp is missing from the scene")

	_drive_a_descent(main)
	_check_everything_that_exists_is_drawn(main)
	_check_the_controls_are_anchored(main)
	_check_there_is_always_a_way_on(main)
	_check_the_buttons_do_their_jobs(main)
	_check_the_ship_is_a_real_machine(main)

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
	# A subsystem that renders nothing and a subsystem that does not exist look
	# identical from outside, so the assertion is that the mesh the simulation
	# implies is the mesh that got built.
	var drawn: int = main._terrain.vertex_count
	_t.gt(float(drawn), 0.0, "rock exists in the model but the contour built no geometry")

	var cx := int(roundf(main.sim.flight.pos.x))
	var cd := int(roundf(main.sim.flight.pos.y))
	var expected := Contour.build(main.sim.world,
		cx - main.HALF_W, cx + main.HALF_W, cd - main.HALF_D, cd + main.HALF_D)
	_t.gt(float(expected.size()), 0.0, "the model itself says there is a surface here")
	# Every contour segment becomes two triangles of wall, and the faces add
	# more, so the mesh must be at least the wall geometry the contour implies.
	_t.gt(float(drawn), float(expected.size()) * 2.0,
		"the mesh is smaller than the contour the simulation solved")

	_t.begin("smoke > the light field is solved and uploaded")
	_t.ok(main._field.texture != null, "the light field texture was never created")
	_t.eq(main._field.texture.get_width(), Light.SIDE, "the field is the size the solver produces")
	_t.eq(main._field.fan_texture.get_width(), Light.RAYS, "the shadow fan is the width the solver produces")
	_t.eq(main._field.origin, Vector2i(cx, cd), "the field is solved around the ship, not somewhere else")

	_t.begin("smoke > the HUD reflects the run")
	# Assert on the reading the PLAYER sees, not on how the view draws it.
	_t.eq(main._hud._depth.text, "%d m" % int(main.sim.flight.depth()),
		"the depth on the HUD disagrees with the run")
	_t.ok(main._hud._bank.text.contains("cr"), "the bank readout is not being written")
	_t.ok(main._hud._load_btn.text.contains("kg"), "the load readout is not being written")
	_t.approx(main._hud._power._target, main.sim.power_frac(), 1e-4,
		"the power gauge is not reading the simulation")


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
	for pair in [["pad", main._hud._pad], ["lamp button", main._hud._lamp_btn],
			["uplink button", main._hud._uplink_btn]]:
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
	# **The safe area is mobile-only, and on desktop it must be exactly nothing.**
	# `get_display_safe_area()` returns the usable DESKTOP off a phone, which has
	# nothing to do with the game's window: applying it inset every control by
	# 104 px, so a filmed replay tapped empty space, the run filmed perfectly and
	# the ship never left the surface. That is the failure mode the replay README
	# warns about, arriving from the other direction.
	if not OS.has_feature("mobile"):
		for pair in [["left", main._ui.offset_left], ["top", main._ui.offset_top],
				["right", main._ui.offset_right], ["bottom", main._ui.offset_bottom]]:
			_t.approx(float(pair[1]), 0.0, 0.001,
				"the HUD root has a %s margin off a phone, so every control is displaced" % pair[0])

	_t.ok(main._hud._pad.gui_input.get_connections().size() > 0,
		"the pad does not handle its own input, so its hit box is a second source of truth")
	# Thumb-sized: at least 48 dp. Measured from the offsets, because that is what
	# decides the hit box, and the hit box IS the drawing here.
	_t.gt(main._hud._pad.offset_right - main._hud._pad.offset_left, 200.0,
		"the d-pad is smaller than a thumb")
	for pair in [["lamp", main._hud._lamp_btn], ["uplink", main._hud._uplink_btn]]:
		var b: Control = pair[1]
		_t.gt(b.offset_bottom - b.offset_top, 96.0, "the %s button is smaller than a thumb" % pair[0])
		_t.gt(b.offset_right - b.offset_left, 96.0, "the %s button is narrower than a thumb" % pair[0])


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
	main._hud._lamp_btn.pressed.emit()
	_t.ok(main.sim.lamp_mode != mode, "pressing LAMP did not change the lamp mode")
	for _i in range(3):
		main._hud._lamp_btn.pressed.emit()
	_t.ok(main.sim.lamp_mode >= 0 and main.sim.lamp_mode <= 2, "the lamp mode stayed in range")

	# Uplink with nothing aboard must be refused AND must SAY WHY. "Unavailable"
	# and "not a control" are two different booleans, and a button that is grey
	# with no reason on it teaches the player to stop reading buttons.
	main.sim.hold = {}
	main.sim.load_kg = 0.0
	main.advance(0.1)
	_t.eq(main._hud._uplink_btn._enabled, false, "UPLINK is offered with an empty hold")
	_t.ok(main._hud._uplink_btn._note.contains("empty"),
		"UPLINK is refused without saying why")

	_t.begin("smoke > the manifest opens, scrolls and closes")
	main.sim.hold = {Ore.IRON: {"kg": 4.0, "value": 9.0, "count": 3}}
	main.sim.load_kg = 4.0
	_t.ok(not main._hud.manifest_open(), "the manifest starts closed")
	main._hud._load_btn.pressed.emit()
	_t.ok(main._hud.manifest_open(), "tapping LOAD does not open the manifest")

	# The primary way out is PINNED to the bottom, because "it won't scroll down
	# so I can't see all of the upgrades or close out of the menu" is a blocker
	# that has already shipped once.
	var close: Control = main._hud._manifest._close
	_t.eq(close.anchor_bottom, 1.0, "the manifest's CLOSE is not pinned to the bottom")
	_t.lt(close.offset_bottom, 0.0, "CLOSE is not offset up from the bottom edge")
	close.pressed.emit()
	_t.ok(not main._hud.manifest_open(), "CLOSE does not close the manifest")

	# And a player reading the manifest must not be flying into a wall while
	# they do it.
	main._hud._load_btn.pressed.emit()
	main.press_pad(Vector2(0, 1))
	_t.eq(main._pad_vec, Vector2.ZERO, "the ship still flies while the manifest is open")
	main._hud._manifest.close()


## The ship is modelled by hand because there was nothing to import, so the
## things that make it a machine rather than a shape are worth asserting.
func _check_the_ship_is_a_real_machine(main) -> void:
	_t.begin("smoke > the ship is a machine with parts")
	var ship: Ship = main._ship
	_t.ok(ship.drill != null, "the drill assembly is missing")
	_t.gt(float(ship.get_child_count()), 6.0, "the hull is one mesh, so it is a shape and not a machine")

	# Upgrades bolt on and are visible in play - he asked for that twice. The
	# mounts exist from this milestone so M7 hangs a part on one and it lands
	# where the hull expects it.
	for slot in ["tank", "plating", "instrument", "ordnance"]:
		_t.ok(ship.mounts.has(slot), "there is nowhere to bolt the %s upgrade on" % slot)

	# Every mesh in the rig is on the ship's own render layer. One left on layer
	# 1 would be the single object in the scene lit by both light models, and it
	# would look it.
	var stray := _count_wrong_layer(ship)
	_t.eq(stray, 0, "%d of the ship's meshes are not on its own render layer" % stray)

	# The nose points where it is digging. His words exactly.
	ship.aim(Vector2(0, 1))
	var down := ship.rotation.z
	ship.aim(Vector2(1, 0))
	_t.ok(absf(ship.rotation.z - down) > 1.0, "the ship does not turn to face where it is digging")

	# The thrusters light with the throttle, so thrust is something you can see.
	ship.drive(false, 0.0, 0.016)
	var idle: float = ship._hot.emission_energy_multiplier
	ship.drive(false, 1.0, 0.016)
	_t.gt(ship._hot.emission_energy_multiplier, idle + 0.5,
		"the thruster nozzles do not light when the ship is under power")

	# And the bit spins only while it is cutting.
	var before: float = ship.drill.rotation.y
	ship.drive(false, 0.0, 0.5)
	_t.approx(ship.drill.rotation.y, before, 1e-6, "the drill spins when it is not cutting")
	ship.drive(true, 0.0, 0.5)
	_t.ok(absf(ship.drill.rotation.y - before) > 0.1, "the drill does not spin when it is cutting")


func _count_wrong_layer(n: Node) -> int:
	var bad := 0
	if n is VisualInstance3D and (n as VisualInstance3D).layers != Ship.LAYER:
		bad += 1
	for c in n.get_children():
		bad += _count_wrong_layer(c)
	return bad


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
