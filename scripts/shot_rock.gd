extends SceneTree

## Render ONE term of the rock shader, several in a single run.
##
## A shader has no print. Four separate processes to answer one question is four
## minutes; cycling the uniform between captures in one process is one.

var _main
var _frames := 0
var _term := 0


func _initialize() -> void:
	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)
	_main.freeze()
	_main.start_run()
	var p := Policies.new(9)
	var step := 1.0 / 60.0
	for _i in int(9.0 / step):
		var act := p.act(Policies.GREEDY, _main.sim, step)
		if bool(act["uplink"]):
			_main.sim.uplink()
			continue
		_main.press_pad(act["dir"])
		_main.advance(step, step)
	_main._post.visible = false
	_main._haze.visible = false
	_main._hud.visible = false


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	if (_frames - 4) % 3 == 0:
		var i := (_frames - 4) / 3
		if i > 0:
			root.get_texture().get_image().save_png("user://rock%d.png" % (i - 1))
		if i > 6:
			_main.free()
			quit(0)
			return true
		_main._rock_mat.set_shader_parameter("debug_term", i)
	return false
