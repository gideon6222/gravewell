extends SceneTree

## A class, at the moment its rule is doing something.
##
##   godot --path . --resolution 460x996 --script res://scripts/shot_class_rule.gd -- <class> <stage>
##
## Drown: 0 is the ship dropping through the waterline, the frame that has to say
## "water" without a caption; 1 is well under it, where the lamp has closed in
## and the hull is going. Crush: 0 is shallow and 1 is deep, and what the pair
## has to show is that the dark and the weight were there the whole way.

var _main
var _frames := 0
var _stage := 0
var _class := Classes.DROWN


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_class = int(args[0])
	if args.size() > 1:
		_stage = int(args[1])
	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)
	_main.freeze()
	_main.start_run()

	# A Drown planet, and a shaft cut down to the water so the ship arrives the
	# way a player would rather than being teleported into a pocket.
	_main.sim = Sim.new(3, _class)
	_main._rebind()
	var w: World = _main.sim.world
	# Drown is framed around its surface; every other class around plain depth.
	var table := int(w.water_depth()) if Classes.floods(_class) else 30
	var to := table + (2 if _stage == 0 else 24)
	for d in range(-1, to + 2):
		w.set_fill(0, d, 0.0)
		w.mat[w.idx(0, d)] = Ore.AIR
	_main.sim.flight.pos = Vector2(0.0, float(to) - 1.0)
	_main._last_cell = Vector2i(99999, 99999)

	var step := 1.0 / 60.0
	for _i in int(1.6 / step):
		_main.sim.power = _main.sim.power_capacity()
		_main.sim.hull = Tuning.HULL_MAX
		_main.press_pad(Vector2(0, 1))
		_main.advance(step, step)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 6:
		return false
	root.get_texture().get_image().save_png("user://rule%d_%d.png" % [_class, _stage])
	var t: Terrain = _main._terrain
	var null_meshes := 0
	var total := 0
	for c in t._chunks.values():
		total += 1
		var mi: MeshInstance3D = c
		if mi.mesh == null:
			null_meshes += 1
	print("  chunks %d, of which %d draw nothing; dirty %d" % [total, null_meshes, t._dirty.size()])
	print("wrote rule%d_%d.png  depth %.1f  water %.1f  submerged %s" % [
		_class, _stage, _main.sim.flight.depth(), _main.sim.world.water_depth(),
		str(_main.sim.submerged)])
	_main.free()
	quit(0)
	return true
