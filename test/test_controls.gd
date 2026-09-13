extends RefCounted

## THE HANDEDNESS GATE. Swipe right, go right - asserted, not assumed.
##
## This studio has shipped inverted controls in six things: Captain Run for its
## whole life, Coreward twice, Wrecking Crew, Stillwater, Wildform, and the
## project template itself. The rule is written down in `CRAFT.md` and
## `POLISH.md` and has been the whole time, and it has never once prevented it.
## The wildform post-mortem says why: *"the rule was written as advice about a
## convention rather than as a test that fails."* It is a test now.
##
## **Why nothing else in this repo catches it.** There are twenty-odd suites
## here, a whole-run golden, a smoke test that boots the real scene and flies a
## descent, filmed replays and contact sheets. None of them can see an inverted
## d-pad, because every one of them drives the game through `press_pad()` - and
## `press_pad` assigns `_pad.vector` directly:
##
##     func press_pad(dir: Vector2) -> void:
##         _hud._pad.vector = dir
##
## That is the value the control WOULD have produced, handed over without ever
## asking the control to produce it. **A policy that sets the value the control
## would set is not a test of the control.** The bug lives in the two steps
## either side of `vector`: `DPad._aim_from()` turning a thumb's position into
## it, and the camera turning a world +X into a screen left or a screen right.
## A replay of a ship sliding left while nobody is watching a thumb looks
## exactly like a ship sliding left on purpose. **The one thing no bot in this
## studio does is hold a thumb.** This file holds one.
##
## **So it drives `DPad._on_input` itself** - the function the pad's `gui_input`
## signal calls - with a real `InputEventScreenTouch` and a real
## `InputEventScreenDrag`, and asserts where the ship ends up ON SCREEN, in
## camera space. Not in world coordinates: **a world-coordinate assertion passes
## on inverted controls**, which is the entire point.
##
## **And it never adds the scene to a tree**, so it never calls
## `get_viewport()`, never needs a processed frame, and never depends on whether
## a node added during `SceneTree._initialize()` counts as being in the tree - a
## question two files in the knowledge base currently answer differently, and a
## gate that turns red on an unsettled engine fact is a gate nobody trusts. Two
## things make that possible and both were checked rather than assumed:
##
##   - `Control.accept_event()`, which `DPad._on_input` calls on every branch,
##     is wrapped in `if (is_inside_tree())` in every Godot 4 branch (4.3, 4.4,
##     4.5 and master), so outside the tree it is a silent no-op. Not an error,
##     not a warning, nothing in the log.
##   - **The pad's `size` is real off the tree.** `Control._size_changed()` runs
##     on every `set_offset()` whether or not the node is in a tree; only the
##     notifications are gated. The pad's left/right anchors are both 0.5 and
##     its top/bottom anchors are both 1.0, so the parent's size cancels out of
##     the arithmetic entirely and the answer is `offset_right - offset_left`
##     either way. `_aim_from` measures the thumb against that size, so this is
##     the one fact the whole file rests on - and the first assertion below
##     checks it rather than trusting this paragraph.


const STEP := 1.0 / 60.0

## How long the thumb is held. The ship reaches its top speed in about 0.18 s
## and the camera follows it at an exponential rate of 6, so by the end of this
## the lag between the two has settled to about a metre - which is what puts the
## ship measurably off the centre line of the screen.
const HOLD := 1.0

## Longer for the vertical, because the first second of a dive is spent falling
## the metre and a half of open air the ship starts in and then stopping against
## the rock face. The plow is slower than free flight on purpose - that is what
## makes the rock feel like rock - so the thumb has to be held long enough for
## the ship to actually get INTO it.
const DIG_HOLD := 3.0

## How far from the pad's centre the thumb sits, as a fraction of the pad's
## width. The dead zone is 13% of the width, so this is nearly three times
## clear of it: a failure here should mean the DIRECTION is wrong, not that the
## press was too timid to register.
const PUSH := 0.36

## The floor under "the ship actually went somewhere". Without it a d-pad that
## does nothing at all passes both the right-hand and the left-hand assertion,
## because "did not go left" and "did not go right" are both true of a ship
## standing still.
const TRAVELLED := 0.5


## A booted game, past the title, frozen so nothing moves but `advance()`.
##
## All three steps matter. `freeze()` runs `_ensure_booted()`, because `_ready`
## has not fired - nothing is in a tree - and without it `sim` is null and every
## read below is a non-fatal runtime error that silently deletes the rest of the
## check. `start_run()` gets past the title the way NEW GAME does, because
## `_tick` returns immediately while the shell is not playing: a harness that
## skips it advances nothing at all and measures the menu.
func _game():
	var scene: PackedScene = load("res://src/game/main.tscn")
	var main = scene.instantiate()
	main.freeze()
	main.start_run()
	# **And then take the contract.** M21 put a briefing in front of the first
	# descent, so `start_run()` now lands on `Screen.BRIEFING` rather than
	# PLAYING, and `playing()` is false there. `_tick` returns immediately while
	# the shell is not playing, so every hold below moved the ship 0.00 m and all
	# nine assertions in this file failed at once - which reads exactly like a
	# dead d-pad and was actually a game that had not started. A gate measuring a
	# menu is the failure this file was written to prevent, one screen further in.
	#
	# Through the button the player presses, not by assigning `screen`: a harness
	# that sets the state the control would set is not testing the control, which
	# is the whole argument of this file. `run_smoke.gd` takes the same path.
	if main._shell != null and main._shell.screen == Shell.Screen.BRIEFING:
		main._shell._begin.pressed.emit()
	# One tick with nothing held, so every node below is drawn from the sim the
	# run actually started with rather than from the one `_ensure_booted` made.
	main.advance(STEP, STEP)
	return main


## Hold a thumb on the d-pad, off centre, for `HOLD` seconds.
##
## A press at the centre first, because that is what a thumb does - it lands
## somewhere and then slides - and because it proves the press itself is not
## what steers. Then a real drag, re-sent every frame, which is what holding a
## direction actually is: the pad keeps its `vector` between events, and `_tick`
## re-reads it through `_hud.pad_vector()` on every frame.
func _hold_pad(main, dir: Vector2, seconds: float = HOLD) -> void:
	var pad = main._hud._pad
	var centre: Vector2 = pad.size * 0.5
	var at: Vector2 = centre + dir * (pad.size.x * PUSH)

	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = centre
	pad._on_input(down)

	for i in int(round(seconds / STEP)):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = at
		drag.relative = at - centre
		pad._on_input(drag)
		main.advance(STEP, STEP)


## Where a world point sits ON SCREEN, as a signed pair: +x is right of the
## centre line, +y is above it.
##
## `transform.affine_inverse() * p` puts the point in the camera's own space,
## where +X is screen right and +Y is screen up by definition. That is the whole
## of the projection that matters for handedness; it needs no viewport and no
## frame, and it is the quantity a world-coordinate assertion cannot see.
##
## `transform`, never `global_transform`: outside the tree the global one does
## not error, it returns IDENTITY - a plausible wrong answer.
func _on_screen(main, p: Vector3) -> Vector3:
	return main._cam.transform.affine_inverse() * p


## How far the ship travelled along a given screen axis, in metres. Independent
## of where the camera happens to have caught up to, which the reading above is
## not.
func _travelled(main, axis: Vector3, from: Vector3) -> float:
	return axis.normalized().dot(main._ship.position - from)


## The fact the whole file rests on, asserted rather than assumed.
##
## `DPad._aim_from` measures the thumb against `size`, so a pad reporting zero
## size turns every press below into a division of nothing by nothing: the
## centre would be (0, 0), the dead zone would have radius 0, and a thumb
## resting dead centre would come out as a full push to the RIGHT - which would
## make the positive control fail and the right-hand test pass for the worst
## possible reason.
## **The harness reaches the flying game, and not a screen in front of it.**
##
## Every other check in this file measures where the ship ended up, and a ship
## that never started moving satisfies "did not go the wrong way" perfectly. The
## `TRAVELLED` floor below catches that per-direction, but it reports it as a
## d-pad that moved the ship 0.00 m, which is what a broken control looks like.
## On 2026-09-13 all nine of those assertions failed at once because M21 had put
## the contract screen in front of the first descent and `_tick` returns while
## the shell is not playing: nothing was wrong with the pad at all. This says so
## in one line, before any of the measuring starts.
func test_the_harness_gets_past_the_contract_and_into_the_game(t: TestHarness) -> void:
	var main = _game()
	t.eq(main._shell.screen, Shell.Screen.PLAYING,
		"the harness is sitting on screen %d rather than PLAYING, so every hold in this file measures a menu and reads as a dead d-pad"
			% int(main._shell.screen))
	t.ok(main._shell.playing(),
		"the shell says it is not playing, and _tick returns without advancing anything while that is true")
	main.free()


func test_the_pad_has_a_real_size_outside_the_tree(t: TestHarness) -> void:
	var main = _game()
	var pad = main._hud._pad
	t.gt(pad.size.x, 100.0,
		"the d-pad reports a width of %.1f off the tree, so every thumb position in this file is measured against nothing"
			% pad.size.x)
	t.gt(pad.size.y, 100.0,
		"the d-pad reports a height of %.1f off the tree" % pad.size.y)
	t.approx(pad.size.x, pad.offset_right - pad.offset_left, 0.5,
		"the pad's width does not match its own offsets, so the layout is resolving against something unexpected")
	main.free()


func test_a_thumb_on_the_right_of_the_pad_flies_the_ship_right_on_screen(t: TestHarness) -> void:
	var main = _game()
	var from: Vector3 = main._ship.position
	var right: Vector3 = main._cam.transform.basis.x
	_hold_pad(main, Vector2.RIGHT)

	var went := _travelled(main, right, from)
	t.gt(absf(went), TRAVELLED,
		"the ship moved %.2f m in %.1f s with the pad held hard over - the assertions below would be reading noise"
			% [absf(went), HOLD])
	t.gt(went, 0.0,
		"a thumb on the RIGHT of the pad flew the ship %.2f m toward SCREEN LEFT - the controls are inverted. A world-coordinate assertion passes in this state, which is why this one is in camera space."
			% went)
	# And where it ENDED UP, not only which way it went. The camera follows the
	# ship at an exponential rate, so a ship being flown right sits permanently
	# right of the centre line - which is the thing the player is looking at.
	t.gt(_on_screen(main, main._ship.position).x, 0.0,
		"the ship is being flown right and is sitting at screen x %.2f, which is the LEFT half of the frame"
			% _on_screen(main, main._ship.position).x)
	main.free()


func test_a_thumb_on_the_left_mirrors_it(t: TestHarness) -> void:
	# The pair that proves the control exists differs in exactly one thing: the
	# side the thumb is on. A single-direction test passes on a d-pad that is
	# stuck to one direction, which is a real failure mode for a control that
	# snaps to eight of them.
	var main = _game()
	var from: Vector3 = main._ship.position
	var right: Vector3 = main._cam.transform.basis.x
	_hold_pad(main, Vector2.LEFT)

	var went := _travelled(main, right, from)
	t.gt(absf(went), TRAVELLED,
		"the ship moved %.2f m with the pad held hard over to the left" % absf(went))
	t.lt(went, 0.0,
		"a thumb on the LEFT of the pad flew the ship %.2f m toward SCREEN RIGHT - the controls are INVERTED"
			% went)
	t.lt(_on_screen(main, main._ship.position).x, 0.0,
		"the ship is being flown left and is sitting at screen x %.2f, which is the RIGHT half of the frame"
			% _on_screen(main, main._ship.position).x)
	main.free()


## Down is the other half of this game, and it has its own sign to get wrong.
##
## `Sim` counts depth as a POSITIVE number going down and the world draws it
## through `Main.DEPTH_SIGN`, which is the one place the simulation's down
## becomes a world axis. Flip that constant and the ship digs upward out of the
## sky while every depth assertion in every other suite goes on passing.
func test_a_thumb_on_the_bottom_of_the_pad_digs_down_the_screen(t: TestHarness) -> void:
	var main = _game()
	var from: Vector3 = main._ship.position
	var deep_before: float = main.sim.flight.depth()
	var up: Vector3 = main._cam.transform.basis.y
	# +y is DOWN in a Control's local space, so this is the bottom of the pad.
	_hold_pad(main, Vector2.DOWN, DIG_HOLD)

	var went := _travelled(main, up, from)
	t.gt(absf(went), TRAVELLED,
		"the ship moved %.2f m with the pad held down for %.1f s" % [absf(went), DIG_HOLD])
	t.lt(went, 0.0,
		"a thumb on the BOTTOM of the pad carried the ship %.2f m UP the screen - the vertical axis is inverted"
			% went)
	# The screen and the simulation must agree about which way down is. They are
	# joined by exactly one constant, `Main.DEPTH_SIGN`, and this is the only
	# assertion here that reads both ends of it in one breath - every other depth
	# assertion in the suite is inside `Sim`, on the far side of that constant.
	t.gt(main.sim.flight.depth(), deep_before,
		"the ship travelled DOWN the screen and got no deeper (%.2f -> %.2f), so DEPTH_SIGN and the pad disagree"
			% [deep_before, main.sim.flight.depth()])
	main.free()


## THE NDC TEST, as arithmetic.
##
## A Godot camera looks down its own -Z. This one is built as
## `Transform3D(Basis(), position)` - deliberately never rotated - so screen
## right IS world +X and screen up IS world +Y. That is a claim, and it is the
## claim that broke in five other games: a camera turned 180 degrees about Y to
## follow a world laid out the other way mirrors X, and then every drag moves
## the ship backwards while every world-coordinate assertion in the suite goes
## on passing. One assertion, no GPU, no frame - the camera's own basis is the
## entire thing.
func test_screen_right_is_world_plus_x(t: TestHarness) -> void:
	var main = _game()
	var right: Vector3 = main._cam.transform.basis.x
	# Normalised first, because a basis carries the node's scale and a dot
	# product against an unnormalised axis reads low for a perfectly correct
	# camera - which is how this same assertion has been "fixed" by loosening it
	# before now.
	t.approx(right.length(), 1.0, 0.001,
		"the camera basis is scaled (%.3f), so the assertion below measures scale as well as direction"
			% right.length())
	t.gt(right.normalized().x, 0.5,
		"the camera's right-hand vector points at world %s, so screen right is world -X and every swipe in the game is backwards"
			% str(right.normalized()))
	t.gt(main._cam.transform.basis.y.normalized().y, 0.5,
		"the camera's up vector points at world %s, so the screen is upside down"
			% str(main._cam.transform.basis.y.normalized()))
	main.free()


## The positive control. A construct that cannot fail is untested, not safe -
## and the way the assertions above go vacuous is for the pad to move nothing at
## all, in which case "did not go left" and "did not go right" are both true of
## a game that has stopped reading the screen.
func test_a_thumb_resting_in_the_middle_moves_nothing(t: TestHarness) -> void:
	var main = _game()
	var pad = main._hud._pad
	var from: Vector3 = main._ship.position
	var centre: Vector2 = pad.size * 0.5

	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = centre
	pad._on_input(down)
	t.eq(pad.vector, Vector2.ZERO,
		"a thumb resting on the centre of the pad asked for a direction - the dead zone is gone, and the first touch of every run will yank the ship sideways")

	for i in int(round(HOLD / STEP)):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = centre
		drag.relative = Vector2.ZERO
		pad._on_input(drag)
		main.advance(STEP, STEP)

	t.approx(main._ship.position.distance_to(from), 0.0, 0.01,
		"a thumb that never left the centre of the pad flew the ship %.3f m, so the assertions above may be reading drift rather than input"
			% main._ship.position.distance_to(from))

	# And what Main reads must be what the pad decided. `press_pad()` writes
	# `vector` straight past `_aim_from`, so this is the only place the two ends
	# of that wire are checked against each other.
	t.eq(main._hud.pad_vector(), pad.vector,
		"Main reads a different direction from the one the d-pad decided on")
	main.free()
