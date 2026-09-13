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
var _main
var _frames := 0


## **Freeze first, then let real frames pass, THEN assert.**
##
## Both halves matter and they pull in opposite directions.
##
## Freezing first is what makes the run deterministic: `_process` returns early
## while frozen, so the simulation does not advance by however many milliseconds
## the window took to open, and sixty game seconds is sixty game seconds on every
## machine.
##
## Letting frames pass is what makes the assertions mean anything. `_ready` does
## not run at `add_child()` inside `_initialize()`; it is deferred to the first
## processed frame. Until then **Control layout is unresolved and a Camera3D is
## not inside the scene at all** - `unproject_position` errors outright and every
## anchored control reports zero size. A harness that does everything in
## `_initialize()` is asserting against a scene that has not been built yet,
## which is how a hundred-pixel layout displacement passed every check in this
## file for a whole milestone.
func _initialize() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	_t.begin("smoke > the scene loads")
	_t.ok(scene != null, "main.tscn failed to load")
	if scene == null:
		_finish()
		return
	_main = scene.instantiate()
	root.add_child(_main)
	_main.freeze()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	_run(_main)
	return true


func _run(main) -> void:
	_t.begin("smoke > the scene builds its world")
	_t.ok(main.sim != null, "Sim was never created")
	_t.ok(main._terrain != null, "the terrain is missing from the scene")
	_t.ok(main._haze != null, "the air-light quad is missing from the scene")
	_t.ok(main._ship != null, "the ship is missing from the scene")
	_t.ok(main._lamp != null, "the lamp is missing from the scene")

	# The layout has actually resolved by now, which is the whole reason for
	# waiting: a control at zero size passes every anchor assertion trivially.
	_t.gt(main._hud._pad.get_global_rect().size.x, 100.0,
		"the d-pad has no size, so the layout has not resolved and nothing below means anything")

	_check_the_way_in(main)
	_drive_a_descent(main)
	_check_everything_that_exists_is_drawn(main)
	_check_the_controls_are_anchored(main)
	_check_there_is_always_a_way_on(main)
	_check_the_buttons_do_their_jobs(main)
	_check_the_ship_is_a_real_machine(main)
	_check_the_goal_is_on_screen(main)
	_check_the_hold_is_a_place(main)
	_check_the_game_makes_a_sound(main)
	_check_the_lamp_is_one_light(main)
	_check_the_pause_button(main)
	_check_the_log_wall(main)
	_check_the_back_button(main)

	main.free()
	_finish()


## **Cross the title like a player, never through a bypass flag.**
##
## The title is the one screen in front of everything, so a suite that skips it
## is a suite in which the title is the single path nothing covers. Every
## assertion below goes through the same button a thumb would press.
func _check_the_way_in(main) -> void:
	_t.begin("smoke > the way in")
	var shell: Shell = main._shell
	_t.ok(shell != null, "there is no shell at all")
	_t.eq(shell.screen, Shell.Screen.TITLE, "the game does not start at the title")
	_t.eq(shell._title.visible, true, "the title is not drawn")

	# CONTINUE is GREYED, not hidden, on a first run. An absent button tells a
	# new player nothing; a greyed one says where their game will be.
	Save.erase()
	shell._show()
	_t.eq(shell._continue.visible, true, "CONTINUE is hidden rather than greyed on a first run")
	_t.eq(shell._continue._enabled, false, "CONTINUE is offered with no save")
	_t.ok(shell._continue._note.contains("no run"), "CONTINUE is greyed without saying why")

	# And the game is NOT running behind it: HOME is the level you are about to
	# play with `advance` not being called.
	var before: float = main.sim.flight.depth()
	main.press_pad(Vector2(0, 1))
	main.advance(2.0)
	_t.approx(main.sim.flight.depth(), before, 0.001,
		"the game plays behind the title screen")

	# NEW GAME, through the button. It goes to the BRIEFING, because "I am not
	# sure what the goal of the game is" is answered before the first descent
	# rather than after it.
	Save._reset_latch_for_tests()
	shell._new.pressed.emit()
	main.advance(0.1)
	_t.eq(shell.screen, Shell.Screen.BRIEFING, "NEW GAME did not offer the contract")
	_t.eq(shell._briefing.visible, true, "the briefing is not drawn")
	_t.eq(shell._title.visible, false, "the title is still drawn over the briefing")

	# **It states the objective**, and the numbers in it are the real ones rather
	# than a painted seven: a briefing that drifts from the drive is worse than
	# none, because it is the one screen the player believes.
	var said := " ".join(Shell.BriefingPlate.LINES)
	_t.ok(said.contains("Seven") or said.contains("seven"),
		"the contract never says how many cores the drive takes")
	_t.ok(said.contains("core"), "the contract never mentions a core")
	_t.ok(said.contains("sell") or said.contains("sells"),
		"the contract never says what to do with what you dig up")
	_t.eq(Classes.ALL.size(), 7,
		"the contract promises seven worlds and the game has %d classes" % Classes.ALL.size())

	# **Every line fits on the screen.** The first filmed run of this screen had
	# the third line clipped at the right edge, and it filmed perfectly: a
	# sentence missing its last word reads as bad writing, not as a layout bug.
	# Measured against the real font rather than counted in characters.
	# **Measured against the PROJECT's width, not the control's.** The first
	# version of this guard used `shell._briefing.size.x`, which is whatever the
	# harness viewport happens to be, so it passed with the clipped line put back
	# and proved nothing. 1080 is the width the phone actually has.
	var mono: FontFile = shell._mono
	var wide: float = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	_t.approx(wide, 1080.0, 0.5,
		"the project is %.0f wide, so this guard is measuring against the wrong screen" % wide)
	var room: float = wide - Shell.BriefingPlate.MARGIN * 2.0
	for line in Shell.BriefingPlate.LINES:
		var w: float = mono.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1,
			Shell.BriefingPlate.BODY_SIZE).x
		_t.ok(w <= room, "\"%s\" is %.0f px wide in %.0f px of room" % [line, w, room])
	for note in Shell.BriefingPlate.NOTES:
		var w: float = mono.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1,
			Shell.BriefingPlate.NOTE_SIZE).x
		_t.ok(w <= room, "\"%s\" is %.0f px wide in %.0f px of room" % [note, w, room])

	# And the game is still not running behind it.
	var held: float = main.sim.flight.depth()
	main.press_pad(Vector2(0, 1))
	main.advance(1.0)
	_t.approx(main.sim.flight.depth(), held, 0.001, "the game plays behind the briefing")

	# Take the contract, through the button a thumb presses.
	shell._begin.pressed.emit()
	main.advance(0.1)
	_t.eq(shell.screen, Shell.Screen.PLAYING, "taking the contract did not start the game")
	_t.eq(shell._briefing.visible, false, "the briefing is still drawn over the game")


## **The air and the rock are lit by ONE lamp, and the fan is cast and decoded
## with one number.**
##
## Three separate quantities have to agree between the sim, `main.gd` and two
## shaders, and none of them shows up in a picture as anything more specific than
## "the tunnel looks wrong". The one that actually shipped broken: the fan was
## cast to `reach * 1.8` and the shader decoded it against `reach`, so every
## shadow began at 55% of its true distance. That is the third instance in this
## repo of one quantity written down twice, so it gets an assertion on the
## derived value rather than a comment asking the next person to be careful.
func _check_the_lamp_is_one_light(main) -> void:
	_t.begin("smoke > the lamp is one light")
	var rock: ShaderMaterial = main._rock_mat
	var haze: ShaderMaterial = main._haze_mat
	var reach: float = main.sim.lamp_reach()

	_t.approx(float(rock.get_shader_parameter("lamp_reach")), reach, 1e-3,
		"the rock is lit to a different reach than the lamp has")
	_t.approx(float(haze.get_shader_parameter("lamp_reach")), reach, 1e-3,
		"the air is lit to a different reach than the rock")

	# The fan, at both ends.
	_t.approx(float(haze.get_shader_parameter("fan_reach")), reach * Tuning.FAN_REACH_MULT,
		1e-3, "the shader decodes the fan against a different range than it was cast to")

	# The angular profile is SHARED, so the beam in the air and the pool it lands
	# in are one light and not two kept in agreement by hand.
	for k in ["cone_lo", "cone_hi", "density", "lamp_dir"]:
		_t.eq(str(rock.get_shader_parameter(k)), str(haze.get_shader_parameter(k)),
			"the rock and the air disagree about %s, so they are two lamps" % k)

	# And the diagnostic is off in the shipped picture.
	_t.eq(int(haze.get_shader_parameter("debug_term")), 0,
		"the air is rendering a debug term instead of the game")
	_t.eq(int(rock.get_shader_parameter("debug_term")), 0,
		"the rock is rendering a debug term instead of the game")

	# **Depth grows downward, so "no water" is a large POSITIVE parking spot.**
	# Parked negative it sits above the whole planet and every class renders as
	# submerged; Crush came out blue and it was the picture that said so, not a
	# test. Now a test says so.
	var wy := float(haze.get_shader_parameter("water_y"))
	if Classes.floods(main.sim.world.class_id):
		_t.approx(wy, main.sim.world.water_depth(), 1e-3,
			"the air is drawing the waterline somewhere the simulation does not have it")
	else:
		_t.gt(wy, float(Tuning.CORE_DEPTH) * 2.0,
			"a world with no water parks its surface at %.1f, which is inside the planet" % wy)

	# The rock picks its normal-map projection from where the front face sits in
	# z, because the mesh's smoothed normals cannot tell a wall from a face. That
	# plane is `Terrain.HALF` and the shader has to be handed the same number:
	# get it wrong and every tunnel wall goes back to vertical streaks.
	_t.approx(float(rock.get_shader_parameter("face_z")), Terrain.HALF, 1e-4,
		"the rock shader thinks the front face is somewhere it is not")

	# The bearing filter is stated in rays, and the ray count lives in `Light`.
	_t.approx(float(haze.get_shader_parameter("fan_texel")), 1.0 / float(Light.RAYS), 1e-9,
		"the air filters the fan over a different angle than the fan was cast at")


## **A pause the thumb can find, clear of everything else.**
##
## His ask: "can you also add a pause button?" The back gesture already opened
## the sheet, and on a phone with gesture navigation a back SWIPE is not a
## control anyone discovers.
##
## The rects are asserted at the phone's real aspect, because a control that
## overlaps another is invisible to every test that only presses it - the first
## placement sat exactly on the credits line and the suite was perfectly happy.
func _check_the_pause_button(main) -> void:
	_t.begin("smoke > the pause button")
	var hud: Hud = main._hud
	var shell: Shell = main._shell
	var btn: Hud.PlateButton = hud._pause_btn
	_t.ok(btn != null, "there is no pause button")
	_t.eq(btn.visible, true, "the pause button is not drawn during a descent")

	var r := btn.get_global_rect()
	_t.gt(r.size.x, 60.0, "the pause button has no width, so nothing below means anything")
	for other in [hud._pad, hud._bank, hud._depth, hud._load_btn, hud._power, hud._hull]:
		_t.ok(not r.intersects(other.get_global_rect()),
			"the pause button overlaps another control, so one of them cannot be read or pressed")

	# And it does what it says, through the same press a thumb makes.
	shell.screen = Shell.Screen.PLAYING
	shell._show()
	btn.pressed.emit()
	_t.eq(shell.screen, Shell.Screen.PAUSED, "the pause button did not open the pause sheet")
	_t.eq(shell._pause.visible, true, "the pause sheet is not drawn")
	shell.go_back()


## **The wall shows what has been found and hides what has not.**
##
## A collection screen that draws nothing until the player has something is a
## screen nobody discovers, and one that leaks the text of a fragment they have
## not opened gives away the only thing the game withholds. Both halves matter,
## so both are asserted.
func _check_the_log_wall(main) -> void:
	_t.begin("smoke > the log wall")
	var shell: Shell = main._shell
	_t.ok(shell.sim != null, "the wall has no run to read, so it can only ever be blank")
	_t.eq(shell.sim, main.sim, "the wall is reading a different run than the one being played")

	# The table itself has to be real, or the wall is a frame around nothing.
	_t.gt(Fragments.total(), 6, "there are almost no fragments written at all")
	for p in range(1, 8):
		_t.gt(Fragments.lines_of(p).size(), 0, "planet %d has no fragment written for it" % p)
		_t.ok(not String(Fragments.keepsake_of(p)["name"]).is_empty(),
			"planet %d has no keepsake" % p)

	# Nothing found, nothing shown.
	_t.eq(Fragments.found_on(1, 0), 0, "a planet with nothing picked up reports fragments anyway")
	_t.eq(Fragments.found_on(1, 1), 1, "picking one up did not show one")
	# And picking up more than exist cannot print more than exist.
	_t.eq(Fragments.found_on(1, 99), Fragments.lines_of(1).size(),
		"the wall prints more fragments for a planet than were ever written")

	# It draws without throwing, with and without a find, which is the thing a
	# table-driven screen actually fails at.
	var sheet = shell._pause
	# Typed arrays: an untyped literal will not assign to an `Array[int]`, and
	# the failure is a script error rather than a test failure - which is exactly
	# what the gate's error count exists to catch.
	var none: Array[int] = []
	main.sim.logs = none
	main.sim.keepsakes = none.duplicate()
	sheet.queue_redraw()
	main.advance(0.1)
	var some: Array[int] = [1, 1, 3]
	var one: Array[int] = [1]
	main.sim.logs = some
	main.sim.keepsakes = one
	sheet.queue_redraw()
	main.advance(0.1)
	_t.ok(true, "the wall drew with and without finds")


## **The back button unwinds one layer per press and never quits.** Both halves
## in the same commit: the setting alone is a dead system button.
func _check_the_back_button(main) -> void:
	_t.begin("smoke > the back button unwinds one layer at a time")
	var shell: Shell = main._shell
	shell.screen = Shell.Screen.PLAYING
	shell._show()

	main._notification(main.NOTIFICATION_WM_GO_BACK_REQUEST)
	_t.eq(shell.screen, Shell.Screen.PAUSED, "back in play did not pause")
	_t.eq(shell._pause.visible, true, "the pause sheet is not drawn")

	main._notification(main.NOTIFICATION_WM_GO_BACK_REQUEST)
	_t.ok(shell.screen != Shell.Screen.PAUSED, "back in the pause sheet did not leave it")

	# It never quits on its own from the outermost layer either.
	shell.screen = Shell.Screen.TITLE
	shell._show()
	main._notification(main.NOTIFICATION_WM_GO_BACK_REQUEST)
	_t.eq(shell.screen, Shell.Screen.TITLE, "back at the title did something unexpected")

	_t.begin("smoke > home then resume returns to a paused game")
	shell.screen = Shell.Screen.PLAYING
	shell._show()
	main.sim.credits = 777.0
	main._notification(main.NOTIFICATION_APPLICATION_PAUSED)
	_t.eq(shell.screen, Shell.Screen.PAUSED, "backgrounding the app did not pause it")
	_t.ok(Save.exists(), "backgrounding the app did not save")

	# And the pause sheet says which build this is, which he asked for by name.
	_t.gt(float(Changelog.VERSION.length()), 2.0, "there is no version to show")
	_t.gt(float(Changelog.RELEASES.size()), 1.0, "there are no patch notes to show")


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

	# **Through the thumb, never through the method.** This check used to call
	# `main.sim.redescend()` here, which proved the rule works and never that any
	# control on screen reaches it. It passed for the whole of build 25, in which
	# a finished descent froze the game forever: nothing called `enter_hold()` and
	# no control listened for the tap the HUD was asking for. A way on that only
	# the simulation knows about is not a way on.
	_t.ok(main._hud._touch.visible,
		"the descent is over and nothing on screen can take a tap")
	var at: Vector2 = main._hud._touch.get_global_rect().get_center()
	main._hud._touch.touched.emit(at, true)
	main._hud._touch.touched.emit(at, false)
	main.advance(0.5)
	_t.eq(main.sim.phase, Sim.Phase.HOLD,
		"tapping a finished descent did not reach the Hold, which is where the game is")
	_t.ok(main._in_hold, "the sim entered the Hold and the scene did not follow it there")

	# And the Hold has a way out, which is the same bug one room along.
	_t.eq(main._hud._launch_btn.visible, true, "the Hold offers no way back down")
	main._hud._launch_btn.pressed.emit()
	main.advance(2.0)
	_t.eq(main.sim.phase, Sim.Phase.DESCENT, "LAUNCH in the Hold did not start a descent")
	_t.ok(not main._in_hold, "the descent started with the Hold still over it")
	_t.approx(main.sim.credits, banked, 1e-4, "going round the loop lost the bank")
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


## The Hold is the screen he opens first, and the one Coreward got wrong four
## times running. These are the four things that made the fourth attempt work.
## **The goal is legible while you are digging.**
##
## His words on build 25: "I am not sure what the goal of the game is." The drive
## was written in exactly one room and that room could not be entered, so the
## counter now sits on the descent HUD.
##
## A filmed run cannot check this. Movie Maker renders 1080x1920 while the UI is
## laid out in about 1080x2338, so the top couple of hundred pixels are off the
## frame and the bank line and the depth readout are both missing from every
## sheet. That is the film's shape and not the game's, which is exactly why the
## claim needs an assertion here instead of an eye on a contact sheet.
func _check_the_goal_is_on_screen(main) -> void:
	_t.begin("smoke > the goal is readable during a descent")
	if main.sim.phase != Sim.Phase.DESCENT:
		main.sim.redescend()
	main.advance(0.5)

	_t.eq(main._hud._bank.visible, true, "the bank line is hidden while digging")
	_t.ok(main._hud._bank.text.contains("/7"),
		"the descent HUD reads \"%s\", which does not say how much of the drive is filled"
			% main._hud._bank.text)
	_t.ok(main._hud._bank.text.contains("cores"),
		"the drive count is on screen without the word that says what it counts")

	# And it tracks the drive rather than being a painted "0/7".
	main.sim.fit_core(Classes.RIME)
	main.advance(0.5)
	_t.ok(main._hud._bank.text.contains("1/7"),
		"a core went into the drive and the HUD still reads \"%s\"" % main._hud._bank.text)
	# `.clear()`, never `= []`: assigning an untyped array literal to an
	# `Array[int]` is a SCRIPT ERROR rather than a failed assertion, so the
	# assertions all pass and `check.ps1` fails the step on the error count.
	# Second time this repo has paid for it (NOTES 48).
	main.sim.core_classes.clear()

	# On screen, not merely assigned: a label pushed off the top of the viewport
	# is the failure the film actually showed, and it reads as a pass everywhere
	# that only checks the text.
	var line: Rect2 = main._hud._bank.get_global_rect()
	var vis: Rect2 = main.get_viewport().get_visible_rect()
	_t.ok(line.position.y >= vis.position.y and line.end.y <= vis.end.y,
		"the bank line sits at y %.0f..%.0f in a viewport of %.0f..%.0f"
			% [line.position.y, line.end.y, vis.position.y, vis.end.y])


func _check_the_hold_is_a_place(main) -> void:
	_t.begin("smoke > the Hold is a place, not a panel")
	main.sim.credits = 100000.0
	main.sim.filament = 99
	main.sim.record = 250.0
	main.sim.fit_core(Classes.CINDER)
	main.sim.fit_core(Classes.RIME)
	main.sim.outcome = "out of power"
	main.sim.enter_hold()
	main.advance(0.2)

	_t.ok(main._in_hold, "the Hold never opened")
	_t.ok(main._hold != null, "there is no room")

	# **It hides the game entirely.** Leaving half the world visible behind a
	# shop is what makes it read as a pop-up however it is styled.
	_t.eq(main._terrain.visible, false, "the world is still drawn behind the Hold")
	_t.eq(main._haze.visible, false, "the tunnel glow is still drawn behind the Hold")

	# The REAL ship is in the room, not a model of it, so a part bolted on here
	# is bolted on out there by construction.
	_t.ok(main._ship.get_parent() == main._hold._ship_cradle,
		"the Hold shows a copy of the ship rather than the ship")

	# The room lays out from the COUNT. Coreward went from ten cases to fifteen
	# without the room changing, and the report was words cut off and clutter.
	var rows: Array = main.sim.rack()
	_t.gt(float(rows.size()), 3.0, "the rack is empty")
	_t.eq(main._hold._cases.size(), rows.size(), "the room does not lay out from the rack")
	_t.eq(main._hold._slots.size(), 7, "the drive does not have seven slots")

	# The way out never scrolls.
	_t.eq(main._hud._launch_btn.anchor_bottom, 1.0, "LAUNCH is not pinned to the bottom")
	_t.lt(main._hud._launch_btn.offset_bottom, 0.0, "LAUNCH is not offset up from the edge")
	_t.eq(main._hud._launch_btn.visible, true, "there is no way out of the Hold")
	_t.eq(main._hud._pad.visible, false, "the d-pad is still live inside the shop")

	# Tapping a case fits the part. Driven through the room's own ray pick, so
	# the hit box is the geometry rather than a rectangle somebody typed.
	var first: Node3D = main._hold._cases[0]
	var id: String = String(first.get_meta("id"))
	var level_before: int = main.sim.level_of(id)
	var at: Vector2 = main._hold._cam.unproject_position(first.position + Vector3(0, 0, 0.15))
	_t.eq(main._hold.pick(at), id, "the ray pick does not hit the case it was aimed at")
	main._on_hold_touch(at, true)
	main._on_hold_touch(at, false)
	_t.eq(main.sim.level_of(id), level_before + 1, "tapping a case did not fit the part")

	# And a drag pans rather than buying, or the two verbs fight.
	var level_now: int = main.sim.level_of(id)
	main._on_hold_touch(at, true)
	main._on_hold_drag(at + Vector2(0, 60), Vector2(0, 60))
	main._on_hold_touch(at + Vector2(0, 60), false)
	_t.eq(main.sim.level_of(id), level_now, "a drag across a case bought it")

	_t.begin("smoke > leaving the Hold puts the world back")
	main.sim.launch()
	main.advance(0.2)
	_t.eq(main.sim.phase, Sim.Phase.DESCENT, "LAUNCH did not start a descent")
	_t.eq(main._terrain.visible, true, "the world did not come back")
	_t.ok(main._ship.get_parent() == main, "the ship was left in the Hold")
	main.press_pad(Vector2(0, 1))
	var before: float = main.sim.flight.depth()
	main.advance(2.0)
	_t.gt(main.sim.flight.depth(), before, "the game does not play after leaving the Hold")


## **Give the settings panel nothing to switch that does not exist.** If there is
## a music toggle, there is music, and every sound the game names has to load.
func _check_the_game_makes_a_sound(main) -> void:
	_t.begin("smoke > every sound the game names exists")
	var a: GameAudio = main._audio
	_t.ok(a != null, "there is no audio at all")

	for bus in [GameAudio.MUSIC_BUS, GameAudio.SFX_BUS, GameAudio.UI_BUS]:
		_t.gt(float(AudioServer.get_bus_index(bus)), -1.0,
			"the %s bus does not exist, so its slider would switch nothing" % bus)

	# Every name the game plays has to have loaded a stream, or a sound that
	# silently does nothing reads as a missing feature rather than a missing file.
	for name in ["drill", "break", "ore", "hull", "click", "confirm", "deny", "uplink"]:
		_t.ok(a._sfx.has(name), "the sound named '%s' did not load" % name)
		if a._sfx.has(name):
			_t.gt(float((a._sfx[name] as Array).size()), 1.0,
				"'%s' has one variant, so a round robin cannot avoid a repeat" % name)

	_t.ok(a._bed_shallow != null, "the shallow ambient bed did not load")
	_t.ok(a._bed_deep != null, "the deep ambient bed did not load")
	_t.ok(a._theme != null, "the theme did not load")
	_t.gt(float(a._players.size()), 2.0,
		"the one-shot pool is too small, so a repeated sound cuts its own tail off")

	# **The mood arc is a crossfade on a gameplay quantity, and it has to have a
	# real span.** Assert monotonicity across the actual depth range rather than
	# trusting the formula.
	_t.begin("smoke > the score crossfades on depth, with a real span")
	main.sim.flight.pos = Vector2(0, 5.0)
	for _i in range(120):
		a.tick(main.sim, 0.1)
	var shallow_top: float = a._bed_shallow.volume_db
	var deep_top: float = a._bed_deep.volume_db
	main.sim.flight.pos = Vector2(0, float(Tuning.CORE_DEPTH) - 5.0)
	for _i in range(120):
		a.tick(main.sim, 0.1)
	_t.lt(a._bed_shallow.volume_db, shallow_top - 6.0,
		"the shallow bed does not leave, and the layer that leaves does the work")
	_t.gt(a._bed_deep.volume_db, deep_top + 6.0, "the deep bed never arrives")

	# The reverb reads the light solver's own openness, so a cavern is enormous
	# and a shaft is dry. One quantity, two uses.
	_t.begin("smoke > the room sounds like the room it is")
	var tight := Sim.new(77)
	for d in range(-1, 40):
		tight.world.set_fill(0, d, 0.0)
		tight.world.mat[tight.world.idx(0, d)] = Ore.AIR
	tight.flight.pos = Vector2(0, 30.0)
	for _i in range(200):
		a.tick(tight, 0.1)
	var dry: float = a._reverb.wet
	for d in range(20, 42):
		for x in range(-8, 9):
			tight.world.set_fill(x, d, 0.0)
			tight.world.mat[tight.world.idx(x, d)] = Ore.AIR
	for _i in range(200):
		a.tick(tight, 0.1)
	_t.gt(a._reverb.wet, dry + 0.05,
		"opening a cavern around the ship did not open the reverb with it")


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
