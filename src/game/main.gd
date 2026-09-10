extends Node3D

## The shell. Reads `Sim` and draws it; never decides anything.
##
## M1 draws the world as instanced boxes so the simulation can be seen, driven
## and filmed. M2 replaces the box field with a marching-squares contour and the
## flat lighting with the propagated light field, and M4 replaces this HUD with
## the real one. Everything here that M2 will delete is marked.
##
## Everything visible is built in code rather than laid out in the editor: a
## procedural game's world is built at runtime anyway, so an editor layout would
## be a second source of truth, and it keeps the whole project reviewable as
## text.

## Sim (x, depth) maps to 3D (x, -depth, 0), so depth grows downward on screen
## and one cell is one unit. Every conversion in the game goes through here.
const DEPTH_SIGN := -1.0

## Enough for the visible window plus a wide margin. The frame holds about 8 x 16
## cells; this is 30 x 44, so a camera pull-back from a lamp upgrade cannot
## silently start culling.
const POOL := 1320

const CAM_FOV := 46.0        ## vertical degrees. Portrait's horizontal cone is
                             ## about 22 degrees at this aspect
const CAM_DIST := 18.0       ## about 7 cells across and 15 down
const CAM_RATE := 6.0        ## exponential follow

## How far in front of the rock plane the lamp sits. Enough to rake the visible
## faces, close enough that the pool still reads as coming from the ship.
const LAMP_Z := 2.2

var sim: Sim

var _cam: Camera3D
var _cells: MultiMeshInstance3D
var _ship: MeshInstance3D
var _lamp: SpotLight3D
var _ui: Control
var _hud: Label
var _readout: Label
var _pad: Control
var _lamp_btn: Button
var _uplink_btn: Button

var _pad_vec := Vector2.ZERO
var _pad_touch := -1
var _drilling := false
var _booted := false
var _frozen := false

## The materials the cell pool tints between. Colour is per-instance so one
## MultiMesh covers every material, which keeps the whole terrain at one draw
## call. M2 moves this into the contour shader.
const MAT_COLOUR := {
	Ore.ROCK: Color(0.26, 0.24, 0.23),
	Ore.IRON: Color(0.42, 0.33, 0.27),
	Ore.COBALT: Color(0.25, 0.35, 0.48),
	Ore.ARGENT: Color(0.62, 0.66, 0.70),
	Ore.PYRE: Color(0.72, 0.36, 0.18),
	Ore.VOIDGLASS: Color(0.45, 0.28, 0.62),
	Ore.CACHE: Color(0.85, 0.74, 0.35),
	Ore.CORE: Color(0.95, 0.55, 0.25),
}


func _ready() -> void:
	_ensure_booted()
	# Now that the node is in the tree the viewport exists, so the safe-area
	# hook that could not be attached during a headless boot gets attached here.
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_apply_safe_area):
		vp.size_changed.connect(_apply_safe_area)
	_apply_safe_area()


## `_ready` does not run at `add_child()` inside `SceneTree._initialize()`; it is
## deferred to the first processed frame. Every harness entry point calls this,
## and it is idempotent, so a headless run does not fail with a hundred
## "Nonexistent function in base 'Nil'" lines and never terminate.
func _ensure_booted() -> void:
	if _booted:
		return
	_booted = true
	sim = Sim.new(1)
	_build_world()
	_build_ui()
	_sync_camera(1.0)
	_redraw_cells()


# ── the scene ─────────────────────────────────────────────────────────────

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.021, 0.026)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.10, 0.11, 0.14)
	e.ambient_light_energy = 0.22
	e.fog_enabled = true
	e.fog_light_color = Color(0.05, 0.05, 0.06)
	e.fog_density = 0.02
	# Any effect applied by distance hits the background hardest, so the sky
	# gets only a fifth of the fog.
	e.fog_sky_affect = 0.2
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	add_child(env)

	_cam = Camera3D.new()
	_cam.fov = CAM_FOV
	_cam.near = 0.1
	_cam.far = 120.0
	add_child(_cam)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# use_colors MUST be set before instance_count or every instance is
	# silently untinted.
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = POOL
	mm.visible_instance_count = 0

	_cells = MultiMeshInstance3D.new()
	_cells.multimesh = mm
	var cell_mat := StandardMaterial3D.new()
	cell_mat.vertex_color_use_as_albedo = true
	cell_mat.roughness = 0.92
	cell_mat.metallic = 0.0
	_cells.material_override = cell_mat
	add_child(_cells)

	_ship = MeshInstance3D.new()
	var hull := BoxMesh.new()
	hull.size = Vector3(Tuning.SHIP_HALF * 2.0, Tuning.SHIP_HALF * 2.0, Tuning.SHIP_HALF * 2.0)
	_ship.mesh = hull
	var ship_mat := StandardMaterial3D.new()
	ship_mat.albedo_color = Color(0.58, 0.60, 0.64)
	ship_mat.roughness = 0.55
	ship_mat.metallic = 0.7
	_ship.material_override = ship_mat
	add_child(_ship)

	# The lamp is the game's light. The ship gets its own key light on a
	# separate layer at M2, because the world's light is an upgrade and the hull
	# must not brighten when the player buys one.
	_lamp = SpotLight3D.new()
	_lamp.light_energy = 3.2
	_lamp.light_color = Color(1.0, 0.94, 0.84)
	_lamp.spot_range = Tuning.LAMP_REACH[Tuning.Lamp.FLOOD]
	_lamp.spot_angle = 55.0
	_lamp.shadow_enabled = false
	add_child(_lamp)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# One full-rect Control that everything anchors to. Nothing in the HUD is
	# positioned against a literal screen size: the project keeps its base WIDTH
	# and extends the HEIGHT, so a control placed against the base 1920 lands
	# hundreds of pixels high on a 2340-tall phone.
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)

	_hud = Label.new()
	_hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud.offset_top = 40.0
	_hud.offset_left = 24.0
	_hud.offset_right = -24.0
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_hud)

	# The rate readout. A number beats a bar when the player needs causation.
	_readout = Label.new()
	_readout.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_readout.offset_top = 150.0
	_readout.offset_left = 24.0
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_readout)

	_pad = Control.new()
	_pad.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_pad.custom_minimum_size = Vector2(300, 300)
	_pad.size = Vector2(300, 300)
	_pad.offset_left = -150.0
	_pad.offset_right = 150.0
	# Anchored to the BOTTOM and offset upward, so the distance from the real
	# bottom edge is fixed at any aspect ratio.
	_pad.offset_top = -340.0
	_pad.offset_bottom = -40.0
	_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	_pad.gui_input.connect(_on_pad_input)
	_ui.add_child(_pad)

	_lamp_btn = _make_button("LAMP", -300.0, -170.0)
	_lamp_btn.pressed.connect(func(): sim.cycle_lamp())
	_uplink_btn = _make_button("UPLINK", -300.0, -320.0)
	_uplink_btn.pressed.connect(func(): sim.uplink())

	_apply_safe_area()
	# `get_viewport()` is null until the node is inside the tree, and a harness
	# boots the scene from `SceneTree._initialize()` where it is not yet. An
	# engine ERROR line is a test failure even when every assertion passes, so
	# this is guarded and re-attempted from `_ready`.
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_apply_safe_area):
		vp.size_changed.connect(_apply_safe_area)


## Every interactive control handles its own input, so its hit box and its
## drawing are one object. A manual hit test in `_unhandled_input` is a second
## source of truth for where a button is, and it is how a control ends up half
## an inch from where it looks.
func _make_button(text: String, from_right: float, from_bottom: float) -> Button:
	var b := Button.new()
	b.text = text
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.custom_minimum_size = Vector2(200, 110)   ## well over 48 dp
	b.offset_left = from_right
	b.offset_right = from_right + 200.0
	b.offset_top = from_bottom
	b.offset_bottom = from_bottom + 110.0
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(b)
	return b


func _apply_safe_area() -> void:
	var view := get_viewport()
	if view == null:
		return
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0:
		return
	var vp := Vector2(view.get_visible_rect().size)
	var sx := vp.x / float(screen.x)
	var sy := vp.y / float(screen.y)
	_ui.offset_left = float(safe.position.x) * sx
	_ui.offset_top = float(safe.position.y) * sy
	_ui.offset_right = -float(screen.x - safe.end.x) * sx
	_ui.offset_bottom = -float(screen.y - safe.end.y) * sy


# ── input ─────────────────────────────────────────────────────────────────

## The d-pad reads as eight directions from where the finger sits relative to
## the pad's own centre, so it is absolute rather than relative: the picture
## always says which way the machine is pointing.
func _on_pad_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_pad_touch = event.index
			_pad_vec = _dir_from(event.position)
		elif event.index == _pad_touch:
			_pad_touch = -1
			_pad_vec = Vector2.ZERO
		_pad.accept_event()
	elif event is InputEventScreenDrag and event.index == _pad_touch:
		_pad_vec = _dir_from(event.position)
		_pad.accept_event()
	elif event is InputEventMouseButton:
		_pad_vec = _dir_from(event.position) if event.pressed else Vector2.ZERO
		_pad.accept_event()
	elif event is InputEventMouseMotion and _pad_vec != Vector2.ZERO:
		_pad_vec = _dir_from(event.position)
		_pad.accept_event()
	_drilling = _pad_vec != Vector2.ZERO


func _dir_from(local: Vector2) -> Vector2:
	var c := _pad.size * 0.5
	var v := local - c
	if v.length() < 26.0:
		return Vector2.ZERO
	# Snap to eight. A d-pad that reports a continuous angle cannot be squared
	# up to the grid, and squaring up is what makes a cut go straight.
	var a := snappedf(v.angle(), PI / 4.0)
	return Vector2(cos(a), sin(a))


# ── the frame ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _frozen:
		return
	_tick(delta)


func _tick(dt: float) -> void:
	sim.step(_pad_vec, _drilling, dt)
	_sync_camera(dt)
	_redraw_cells()
	_draw_hud()


func _sync_camera(dt: float) -> void:
	var want := Vector3(sim.flight.pos.x, DEPTH_SIGN * sim.flight.pos.y, CAM_DIST)
	var k := SimUtil.smooth(CAM_RATE, dt) if dt < 1.0 else 1.0
	_cam.position = _cam.position.lerp(want, k)
	# Transform3D.looking_at, never Node3D.look_at: the node method errors
	# outside the tree, and global_transform outside the tree silently returns
	# identity.
	_cam.transform = Transform3D(Basis(), _cam.position)

	var sp := Vector3(sim.flight.pos.x, DEPTH_SIGN * sim.flight.pos.y, 0.0)
	_ship.position = sp
	# The reach is measured in the plane, and the lamp is LAMP_Z out of it, so
	# the range has to cover the hypotenuse or the pool is clipped short.
	_lamp.spot_range = sqrt(sim.lamp_reach() * sim.lamp_reach() + LAMP_Z * LAMP_Z)
	_lamp.spot_angle = clampf(rad_to_deg(Tuning.LAMP_CONE[sim.lamp_mode]) * 0.5, 5.0, 88.0)
	# The lamp sits in FRONT of the rock plane and rakes across it.
	#
	# The obvious placement - at the ship, pointing along the heading - lights
	# the backs of the cells and leaves the whole screen black, because this is a
	# 2.5D scene: every cell is a box centred on z = 0 and the only faces the
	# camera can see are the ones at z = +0.5. A light in the plane with them
	# reaches none of those faces. The first screenshot of this game was an
	# entirely black frame with a working HUD on top of it.
	#
	# So the lamp is pulled toward the camera and aimed back at the plane, offset
	# along the heading so the pool of light still leads the ship. M2 replaces
	# this with the propagated light field, where the flood decides what is lit
	# and this positioning stops mattering.
	var np := sim.flight.nose_point()
	var lamp_at := Vector3(sp.x, sp.y, LAMP_Z)
	var aim := Vector3(np.x, DEPTH_SIGN * np.y, 0.0)
	_lamp.transform = Transform3D(Basis(), lamp_at).looking_at(aim, Vector3.UP)


## Draw every cell in the visible window. M2 replaces this whole function with
## the marching-squares contour, at which point the box field goes away.
func _redraw_cells() -> void:
	var mm := _cells.multimesh
	var cx := int(roundf(sim.flight.pos.x))
	var cd := int(roundf(sim.flight.pos.y))
	var n := 0
	for d in range(cd - 21, cd + 22):
		for x in range(cx - 14, cx + 15):
			if n >= POOL:
				break
			if sim.world.is_open(x, d):
				continue
			var m := sim.world.material_at(x, d)
			if m == Ore.AIR:
				continue
			var fill := sim.world.fill_at(x, d)
			var t := Transform3D(Basis().scaled(Vector3(1.0, 1.0, 1.0)), Vector3(float(x), DEPTH_SIGN * float(d), 0.0))
			mm.set_instance_transform(n, t)
			var col: Color = MAT_COLOUR.get(m, MAT_COLOUR[Ore.ROCK])
			if sim.world.is_seam(x, d):
				col = col.lightened(0.22)
			# A part-cut cell reads as darker and smaller, so damage is visible
			# before the cell breaks. M2 makes this the contour instead.
			mm.set_instance_color(n, col.darkened((1.0 - fill) * 0.45))
			n += 1
	# visible_instance_count IS the flush. Forgetting it fails completely
	# silently: the instances exist and nothing is drawn.
	mm.visible_instance_count = n


func _draw_hud() -> void:
	_hud.text = "%d m    POWER %d%%    HULL %d%%    LOAD %.0f/%.0f kg    CR %s" % [
		int(sim.flight.depth()),
		int(sim.power_frac() * 100.0),
		int(sim.hull_frac() * 100.0),
		sim.load_kg, Tuning.HOLD_KG,
		SimUtil.fmt(sim.credits),
	]
	var lines: Array[String] = []
	var rate := sim.pressure_rate()
	if rate > 0.0:
		lines.append("HULL -%.1f/s" % rate)
	if sim.phase == Sim.Phase.OVER:
		lines.append("RECOVERED: %s" % sim.outcome)
		lines.append("TAP LAMP TO DESCEND AGAIN")
	elif sim.phase == Sim.Phase.EXTRACTION:
		lines.append("CORE FREE. GET OUT.")
	_readout.text = "\n".join(lines)
	_uplink_btn.disabled = not sim.can_uplink()
	_uplink_btn.text = "UPLINK\n%s cr" % SimUtil.fmt(sim.hold_value()) if sim.load_kg > 0.0 else "UPLINK"
	_lamp_btn.text = ["FLOOD", "LANCE", "DARK"][sim.lamp_mode]


# ── the harness seam ──────────────────────────────────────────────────────

## Freeze real frames and drive game time by hand. Sixty game seconds is sixty
## game seconds on every machine, which is what makes a filmed run and a smoke
## test comparable between runs and between machines.
func freeze() -> void:
	_ensure_booted()
	_frozen = true


func advance(seconds: float, step: float = 1.0 / 60.0) -> void:
	_ensure_booted()
	var n := int(seconds / step)
	for _i in range(n):
		_tick(step)


## Drive the pad the way a thumb does, for tests and replays. Tests that assert
## on movement go through this rather than writing `_pad_vec`, because a way in
## that the input handler never calls is a missing feature with full coverage.
func press_pad(dir: Vector2) -> void:
	_ensure_booted()
	_pad_vec = dir
	_drilling = dir != Vector2.ZERO
