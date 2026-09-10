extends SceneTree

## A picture of a named class, at the phone's aspect. Two worlds painted
## differently still behave identically, so this exists to check the half that IS
## only a picture.

var _main
var _frames := 0
var _cls := 1
var _seconds := 40.0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("class="):
			_cls = int(a.split("=")[1])
		elif a.begins_with("t="):
			_seconds = float(a.split("=")[1])
	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)
	_main.freeze()
	_main.start_run()

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	if _frames == 4:
		_main.sim = Sim.new(4, _cls)
		_main._terrain.setup(_main.sim.world, _main._rock_mat)
		_main._hud.sim = _main.sim
		_main._last_cell = Vector2i(99999, 99999)
		var p := Policies.new(4)
		var step := 1.0 / 60.0
		for _i in int(_seconds / step):
			var act := p.act(Policies.GREEDY, _main.sim, step)
			if bool(act["uplink"]):
				_main.sim.uplink()
				continue
			_main.press_pad(act["dir"])
			_main.advance(step, step)
		return false
	if _frames < 9:
		return false
	root.get_texture().get_image().save_png("user://class%d.png" % _cls)
	print("wrote class%d.png" % _cls)
	quit(0)
	return true
