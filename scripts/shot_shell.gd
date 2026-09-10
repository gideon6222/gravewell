extends SceneTree

## Pictures of the title and the pause sheet. Every screen gets looked at once as
## a picture at the phone's aspect before it ships.

var _main
var _frames := 0
var _which := "title"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		_which = a
	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)
	_main.freeze()

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	if _frames == 4:
		if _which == "pause":
			Save._reset_latch_for_tests()
			_main.sim.credits = 2600.0
			Save.write(_main.sim)
			_main._shell.screen = Shell.Screen.PAUSED
			_main._shell._show()
		else:
			_main._shell.screen = Shell.Screen.TITLE
			_main._shell._show()
		_main.advance(0.4)
		return false
	if _frames < 9:
		return false
	root.get_texture().get_image().save_png("user://%s.png" % _which)
	print("wrote %s.png" % _which)
	_main.free()
	quit(0)
	return true
