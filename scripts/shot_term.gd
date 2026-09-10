extends SceneTree

## Render ONE lighting term to the screen.
##
## A shader has no print, so the screen is its only readout. Rendering the terms
## one at a time answers "which of my numbers is wrong" in one frame each, which
## is a question four rounds of reasoning failed to answer on the sibling game.

var _main
var _frames := 0
var _term := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("term="):
			_term = int(a.split("=")[1])
	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)
	_main.freeze()
	_main.start_run()

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	if _frames == 4:
		var p := Policies.new(9)
		var step := 1.0 / 60.0
		for _i in int(40.0 / step):
			var act := p.act(Policies.GREEDY, _main.sim, step)
			if bool(act["uplink"]):
				_main.sim.uplink()
				continue
			_main.press_pad(act["dir"])
			_main.advance(step, step)
		# Hold DOWN at the end, so the heading is unambiguous in the picture.
		_main.press_pad(Vector2(0, 1))
		_main.advance(0.5, step)
		_main._haze_mat.set_shader_parameter("debug_term", _term)
		_main._post.visible = false
		_main._hud.visible = false
		return false
	if _frames < 9:
		return false
	root.get_texture().get_image().save_png("user://term%d.png" % _term)
	print("wrote term%d.png  heading=%s" % [_term, str(_main.sim.flight.heading)])
	_main.free()
	quit(0)
	return true
