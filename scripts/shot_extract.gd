extends SceneTree

## A picture of the extraction: the core is free and the world is coming up.
##
## The clock and the picture are one quantity, so this exists to check that the
## quantity actually reaches the screen.

var _main
var _frames := 0

func _initialize() -> void:
	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)
	_main.freeze()
	_main.start_run()

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	if _frames == 4:
		var sim: Sim = _main.sim
		var cd := sim.world.core_depth()
		# Cut the shaft the player would have dug, so there is a real route out.
		for d in range(-1, cd + 1):
			sim.world.fill[sim.world.idx(sim.world.core_x, d)] = 0.0
			sim.world.mat[sim.world.idx(sim.world.core_x, d)] = Ore.AIR
		sim.world.mat[sim.world.idx(sim.world.core_x, cd)] = Ore.CORE
		sim.world.fill[sim.world.idx(sim.world.core_x, cd)] = 1.0
		sim.flight.pos = Vector2(float(sim.world.core_x), float(cd) - 1.2)
		for _i in range(int(90.0 * 60.0)):
			if sim.phase != Sim.Phase.DESCENT:
				break
			sim.hull = Tuning.HULL_MAX
			sim.power = sim.power_capacity()
			_main.press_pad(Vector2(0, 1))
			_main.advance(1.0 / 60.0, 1.0 / 60.0)
		# A few seconds into the climb, so the front is on screen behind us.
		_main.press_pad(Vector2(0, -1))
		for _i in range(int(7.0 * 60.0)):
			sim.hull = Tuning.HULL_MAX
			sim.power = sim.power_capacity()
			_main.advance(1.0 / 60.0, 1.0 / 60.0)
		return false
	if _frames < 9:
		return false
	root.get_texture().get_image().save_png("user://extract.png")
	print("wrote extract.png  phase=%d left=%.1f rising=%.1f" % [
		_main.sim.phase, _main.sim.extract_left, _main.sim.rising])
	_main.free()
	quit(0)
	return true
