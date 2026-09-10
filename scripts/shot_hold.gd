extends SceneTree

## A picture of the Hold, at the phone's aspect. Every screen gets looked at
## once as a picture before it ships.

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
		_main.sim.credits = 2600.0
		_main.sim.filament = 12
		_main.sim.cores = 2
		_main.sim.record = 118.0
		_main.sim.levels = {"drill": 1, "hold": 2}
		_main.sim.bought = 3
		_main.sim.outcome = "out of power"
		_main.sim.enter_hold()
		_main.advance(1.2)
		return false
	if _frames < 9:
		return false
	root.get_texture().get_image().save_png("user://hold.png")
	print("wrote hold.png")
	quit(0)
	return true
