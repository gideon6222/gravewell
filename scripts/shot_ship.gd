extends SceneTree

## The picture that goes with a build. Crosses the title like a player, then
## plays for a while, so it is a picture of the game being played rather than of
## the game sitting still.

var _main
var _frames := 0

func _initialize() -> void:
	_main = load("res://src/game/main.tscn").instantiate()
	root.add_child(_main)
	_main.freeze()

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	if _frames == 4:
		_main._shell._new.pressed.emit()
		var p := Policies.new(9)
		var step := 1.0 / 60.0
		for _i in int(52.0 / step):
			var act := p.act(Policies.GREEDY, _main.sim, step)
			if bool(act["uplink"]):
				_main.sim.uplink()
				continue
			_main.press_pad(act["dir"])
			_main.advance(step, step)
		return false
	if _frames < 9:
		return false
	root.get_texture().get_image().save_png("user://ship.png")
	print("wrote ship.png at %d m" % int(_main.sim.flight.depth()))
	_main.free()
	quit(0)
	return true
