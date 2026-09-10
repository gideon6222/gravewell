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

## The window of rock rebuilt around the ship, in cells. Wide enough that a
## camera pull-back from a lamp upgrade cannot reach the edge of it.
const HALF_W := 15
const HALF_D := 24

const CAM_FOV := 46.0        ## vertical degrees. Portrait's horizontal cone is
                             ## about 22 degrees at this aspect
const CAM_DIST := 18.0       ## about 7 cells across and 15 down
const CAM_RATE := 6.0        ## exponential follow

## The haze quad sits just behind the rock's front face, so the rock occludes it
## and the glow shows only through the openings the player has cut.
const HAZE_Z := 0.42

var sim: Sim

var _cam: Camera3D
var _terrain: Terrain
var _haze: MeshInstance3D
var _ship: MeshInstance3D
var _lamp: OmniLight3D
var _field := LightField.new()
var _rock_mat: ShaderMaterial
var _haze_mat: ShaderMaterial
var _env: Environment
var _last_cell := Vector2i(99999, 99999)
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
	_redraw_world()


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
	_env = e
	add_child(env)

	_cam = Camera3D.new()
	_cam.fov = CAM_FOV
	_cam.near = 0.1
	_cam.far = 120.0
	add_child(_cam)

	_rock_mat = ShaderMaterial.new()
	_rock_mat.shader = load("res://src/game/rock.gdshader")
	_rock_mat.set_shader_parameter("field", _field.texture)
	_rock_mat.set_shader_parameter("field_side", float(Light.SIDE))
	_rock_mat.set_shader_parameter("field_radius", float(Light.R))
	# The single highest-value import in the game. "Cartoonie" from him means
	# under-lit and under-textured, never the model style, and a normal map on
	# the largest surface plus a real light with falloff does more than any
	# amount of geometry. The NORMAL only, never the colour map: that is what
	# lets a photographed texture into a game whose palette decides colour.
	var rock_n := load("res://assets/textures/Rock035/Rock035_1K-JPG_NormalGL.jpg")
	if rock_n != null:
		_rock_mat.set_shader_parameter("rock_normal", rock_n)
		_rock_mat.set_shader_parameter("has_normal", true)

	_terrain = Terrain.new()
	_terrain.setup(sim.world, _rock_mat)
	add_child(_terrain)

	# Light in the AIR. A dug cell contains no geometry, so without this the
	# tunnel itself stays dead however well its walls are lit: a black slot with
	# bright edges. It sits behind the rock's front face, so the rock occludes it.
	_haze_mat = ShaderMaterial.new()
	_haze_mat.shader = load("res://src/game/haze.gdshader")
	_haze_mat.set_shader_parameter("field", _field.texture)
	_haze_mat.set_shader_parameter("fan", _field.fan_texture)
	_haze_mat.set_shader_parameter("field_side", float(Light.SIDE))
	_haze_mat.set_shader_parameter("field_radius", float(Light.R))

	var quad := QuadMesh.new()
	quad.size = Vector2(float(HALF_W) * 2.4, float(HALF_D) * 2.4)
	_haze = MeshInstance3D.new()
	_haze.mesh = quad
	_haze.material_override = _haze_mat
	# Never casts or receives: it is a light, not a surface.
	_haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_haze)

	_ship = MeshInstance3D.new()
	var hull := BoxMesh.new()
	hull.size = Vector3(Tuning.SHIP_HALF * 2.0, Tuning.SHIP_HALF * 2.0, Tuning.SHIP_HALF * 2.0)
	_ship.mesh = hull
	var ship_mat := StandardMaterial3D.new()
	ship_mat.albedo_color = Color(0.42, 0.44, 0.48)
	ship_mat.roughness = 0.55
	ship_mat.metallic = 0.45
	_ship.material_override = ship_mat
	_ship.layers = 2
	add_child(_ship)

	# The lamp is the game's light. The ship gets its own key light on a
	# separate layer at M2, because the world's light is an upgrade and the hull
	# must not brighten when the player buys one.
	_lamp = OmniLight3D.new()
	_lamp.light_energy = 1.3
	_lamp.light_color = Color(1.0, 0.94, 0.84)
	_lamp.omni_range = 4.0
	_lamp.shadow_enabled = false
	# The rock is lit by the solved field, not by this lamp, so the lamp's job is
	# now only to light the SHIP. `light_cull_mask` and `layers` really do
	# exclude a light from an object in Godot: one flag, not a second pass, and
	# it is why buying a lamp upgrade does not make the hull glow.
	_lamp.light_cull_mask = 2
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
	_redraw_world()
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
	# **The rock is not lit by this light.** It is lit by the solved field in
	# `rock.gdshader`, which is the whole technique: a Godot light does not know
	# the rock is there and would light an unopened side tunnel exactly as
	# brightly as the shaft the player flew down.
	#
	# So this is the SHIP's own key light and nothing else's, confined to layer 2
	# by `light_cull_mask`. Coreward needed a second pass for this because
	# three.js cannot exclude a light from an object; in Godot it is one flag.
	# It matters because the world's light is an upgrade, and the hull must not
	# get brighter when the player buys one.
	_lamp.position = sp + Vector3(0.0, 0.0, 1.6)
	_lamp.omni_range = 4.0
	_lamp.light_energy = 1.3


## Rebuild the rock and re-solve the light, but only when something changed.
##
## The flood is a property of the GEOMETRY, so it is re-solved when the ship
## enters a new cell or the rock changes shape, not per frame. The fan is the
## opposite: it answers "what is in shadow from here", which moves continuously,
## so it runs every frame.
func _redraw_world() -> void:
	var cell := Vector2i(int(roundf(sim.flight.pos.x)), int(roundf(sim.flight.pos.y)))
	if cell != _last_cell:
		_last_cell = cell
		_terrain.touch()
		_field.touch()
	_terrain.refresh(cell, HALF_W, HALF_D)
	_field.refresh(sim.world, cell)

	var reach := sim.lamp_reach()
	_field.refresh_fan(sim.world, sim.flight.pos, reach * 1.8)

	var density := Tuning.density_at(sim.flight.depth())
	var origin := _field.origin_world()
	var h := sim.flight.heading
	var cone: float = cos(Tuning.LAMP_CONE[sim.lamp_mode] * 0.5)

	for m in [_rock_mat, _haze_mat]:
		m.set_shader_parameter("field_origin", origin)
		m.set_shader_parameter("lamp_pos", sim.flight.pos)
		m.set_shader_parameter("lamp_dir", h)
		m.set_shader_parameter("lamp_reach", reach)
		m.set_shader_parameter("lamp_cos", cone)
		m.set_shader_parameter("density", density)
	_haze_mat.set_shader_parameter("fan", _field.fan_texture)

	_haze.position = Vector3(sim.flight.pos.x, DEPTH_SIGN * sim.flight.pos.y, HAZE_Z)

	# The air is one number, and it drives the fog as well as the lamp, the drag
	# and the hull load. Volumetric fog is Forward+ only, so this is the built-in
	# depth fog doing the work, thickened by the same quantity.
	if _env != null:
		_env.fog_density = clampf(0.010 + density * 0.020, 0.0, 0.35)


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
