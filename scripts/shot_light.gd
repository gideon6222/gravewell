extends SceneTree

## The one scene where the lighting can be judged.
##
##   godot --path . --resolution 460x996 --script res://scripts/shot_light.gd -- 0
##
## Straight down a shaft, every lighting question looks the same: the only open
## air is BEHIND the ship, so the forward beam has nothing to fall on and a
## corner never enters the frame. Four rounds went into that scene on the last
## game before anyone noticed it was the one scene where the artefact cannot
## appear.
##
## So this cuts a real junction and then flies past it:
##
##   1. down a shaft, so there is a way home to fill
##   2. sideways, so there is a SIDE BRANCH
##   3. back to the shaft
##   4. down again, ending just past the mouth of the branch
##
## At the capture the ship is heading down with the branch beside and slightly
## behind it, which puts all four of his asks in one frame: a forward beam into
## the air it is about to cut, fill up the shaft it came down, a wedge of shadow
## thrown by the branch's corner, and rock faces close enough for the second
## light. Argument selects the stage, so the same run can be photographed at
## each step: 0 is the finished junction.

var _main
var _frames := 0
var _stage := 0
## How long to dig before cutting the branch. The air thickens with DEPTH, so a
## frame taken at 20 m cannot answer whether it thickens at all.
var _descend := 9.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_stage = int(args[0])
	if args.size() > 1:
		_descend = float(args[1])

	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)
	_main.freeze()
	_main.start_run()

	var step := 1.0 / 60.0
	_hold(Vector2(0, 1), _descend, step)     # a shaft to come home up
	if _stage != 1:
		_hold(Vector2(1, 0), 3.5, step)      # the branch
	if _stage > 1 or _stage == 0:
		_hold(Vector2(-1, 0), 3.5, step)     # back to the shaft
		_hold(Vector2(0, 1), 1.6, step)      # just past its mouth
	# Stage 3 turns round and climbs its own shaft. This is the ONLY state in
	# which there is open air in front of the ship, so it is the only one that
	# can show a beam rather than the pool a beam lands in.
	if _stage == 3:
		_hold(Vector2(0, -1), 2.2, step)
	# Stage 4 climbs well clear and then turns back down, so there is open shaft
	# in BOTH directions: a beam falling away into air ahead and a filled tunnel
	# behind, in one frame, with no rock close enough to hide either.
	# Stage 5 reproduces the frame he sent: an irregular carved chamber, with the
	# ship flying LEFT across it. The starburst of separate hard-edged rays is at
	# its worst here, because the ambient carries the fan's shadow in every
	# direction at once and every protrusion throws its own wedge.
	if _stage == 5:
		_hold(Vector2(1, 0), 1.2, step)
		_hold(Vector2(0, 1), 1.0, step)
		_hold(Vector2(-1, 0), 2.0, step)
		_hold(Vector2(0, -1), 1.0, step)
		_hold(Vector2(-1, 0), 1.4, step)
	if _stage == 4:
		_hold(Vector2(0, -1), 5.0, step)
		_hold(Vector2(0, 1), 0.9, step)
	_main.press_pad(Vector2.ZERO)
	_main.advance(0.25, step)


## Power and hull are topped up every frame. This is a photograph of the LIGHT,
## and a run that dies of a flat battery half way through the branch is a
## photograph of the failure screen instead.
func _hold(dir: Vector2, seconds: float, step: float) -> void:
	for _i in int(round(seconds / step)):
		_main.sim.power = _main.sim.power_capacity()
		_main.sim.hull = Tuning.HULL_MAX
		_main.press_pad(dir)
		_main.advance(step, step)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 5:
		return false
	root.get_texture().get_image().save_png("user://light.png")
	print("wrote light.png  stage=%d  depth=%.1f m  heading=%s" % [
		_stage, _main.sim.flight.depth(), str(_main.sim.flight.heading)])
	_main.free()
	quit(0)
	return true
