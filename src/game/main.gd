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
## 15.5 units puts about 6 cells across the frame, which makes the ship roughly
## 60 px on the phone. Under about sixty pixels a machine reads as a shape rather
## than as a machine, and Coreward's ship was thirty and got called "bubbly".
## **Framing is an upgrade**: the lamp ladder pulls this back, and the darkness is
## what justifies the tight frame at the start. That is his suggestion and it is
## the right shape - a lamp that only grows a radius while the camera frames a
## fixed number of rows can never be felt, because the frame is always inside the
## lit circle.
const CAM_DIST := 15.5
const CAM_RATE := 6.0        ## exponential follow

## The haze quad sits BEHIND the ship and behind the rock's front face, inside
## the tunnel volume. In front of the ship it is an additive splat drawn over the
## hull; behind it, the rock and the ship both occlude it and the glow shows only
## where the player has actually cut.
const HAZE_Z := -0.35

var sim: Sim

var _cam: Camera3D
var _terrain: Terrain
var _haze: MeshInstance3D
var _collapse: MeshInstance3D
var _collapse_mat: ShaderMaterial
var _ship: Ship
var _lamp: OmniLight3D
var _field := LightField.new()
var _rock_mat: ShaderMaterial
var _haze_mat: ShaderMaterial
var _env: Environment
var _last_cell := Vector2i(99999, 99999)
var _hold: Hold
var _audio: GameAudio
var _post: ColorRect
var _shell: Shell
var _post_mat: ShaderMaterial
var _in_hold := false
var _drag_from := Vector2.ZERO
var _dragging := false
var _ui: Control
var _hud: Hud

var _pad_vec := Vector2.ZERO
var _pad_touch := -1
var _drilling := false
var _booted := false
var _frozen := false

## Android system integration, all of it, in one place.
##
## `quit_on_go_back = false` is set in `project.godot` and this handler ships in
## the SAME commit, because the setting alone makes the back button do nothing at
## all. Both states are shippable and neither shows in a headless suite.
##
## The save also happens here rather than only on close, because
## `WM_CLOSE_REQUEST` does not arrive on an Android back-out.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if _shell != null:
				_shell.go_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			# Home then resume returns to a PAUSED game, not a restarted one, and
			# the progress is on disk before the app is anywhere near being killed.
			if sim != null:
				Save.write(sim)
			if _shell != null and _shell.playing():
				_shell.pause_game()
		NOTIFICATION_APPLICATION_RESUMED:
			pass


func _ready() -> void:
	_ensure_booted()
	# Screen sleep is prevented during play. A game you look at for a minute
	# without touching is a game that goes dark in your hand.
	DisplayServer.screen_set_keep_on(true)
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
	_build_audio()
	_sync_camera(1.0)
	_redraw_world()


## Fire visual, audio, camera and haptic channels as ONE event. Any one alone
## reads as cheap, and until this milestone the game had only the first.
func _build_audio() -> void:
	_audio = GameAudio.new()
	add_child(_audio)
	_bind_audio()


## Reconnected whenever `Sim` is replaced, because a signal connected to the old
## one is a sound that stops happening with no error anywhere.
func _bind_audio() -> void:
	sim.drill_bite.connect(func(hardness): _audio.drill_bite(hardness))
	sim.broke_cell.connect(func(x, d, m, v):
		_audio.broke(m != Ore.ROCK, Classes.is_brittle(sim.world.class_id))
		_haptic(18, 0.35))
	sim.hull_hit.connect(func(_speed):
		_audio.hull_hit()
		_haptic(30, 0.6))
	sim.uplinked.connect(func(_value, _cost):
		_audio.uplinked()
		_haptic(24, 0.5))
	sim.found_cache.connect(func(_n):
		_audio.play("confirm", -2.0, 1.15)
		_haptic(30, 0.6))
	sim.collapsed.connect(func(_x, _d):
		_audio.play("break", -2.0, 0.7)
		_haptic(26, 0.55))
	sim.core_cut.connect(func(_seconds):
		_audio.play("uplink", 0.0, 0.6)
		_haptic(60, 0.9))


## Haptics: 10 to 30 ms at 0.3 to 0.6 amplitude. `permissions/vibrate` is set in
## both export presets or this silently does nothing.
func _haptic(ms: int, amplitude: float) -> void:
	if _shell != null and not _shell.haptics_on():
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amplitude)


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

	# What comes up behind you once the core is free. Drawn from the SAME number
	# the simulation kills the player with, so the picture cannot promise a
	# second the rules do not give.
	_collapse_mat = ShaderMaterial.new()
	_collapse_mat.shader = load("res://src/game/collapse.gdshader")
	var cq := QuadMesh.new()
	cq.size = Vector2(float(Tuning.HALF_WIDTH) * 2.6, float(HALF_D) * 2.6)
	_collapse = MeshInstance3D.new()
	_collapse.mesh = cq
	_collapse.material_override = _collapse_mat
	_collapse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_collapse.visible = false
	add_child(_collapse)

	_ship = Ship.new()
	add_child(_ship)

	# The lamp is the game's light. The ship gets its own key light on a
	# separate layer at M2, because the world's light is an upgrade and the hull
	# must not brighten when the player buys one.
	_lamp = OmniLight3D.new()
	# Set against the rock, which the field lights at a gain of 1.7. The ship is
	# the one object in the scene on the other light model, so the two have to be
	# balanced by eye at the phone's aspect or the hull reads as a silhouette.
	_lamp.light_energy = 1.9
	_lamp.light_color = Color(1.0, 0.94, 0.84)
	_lamp.omni_range = 2.6
	_lamp.shadow_enabled = false
	# The rock is lit by the solved field, not by this lamp, so the lamp's job is
	# now only to light the SHIP. `light_cull_mask` and `layers` really do
	# exclude a light from an object in Godot: one flag, not a second pass, and
	# it is why buying a lamp upgrade does not make the hull glow.
	_lamp.light_cull_mask = 2
	add_child(_lamp)


func _build_ui() -> void:
	# **Two layers, and the order is the point.** Post goes on the lower one, the
	# HUD on the higher: a vignette over the instruments dims the one thing that
	# must stay legible, and grain over type is just type that is harder to read.
	# Added as siblings in one layer, the post drew LAST and therefore on top,
	# which put chromatic aberration on the edges of every button.
	var post_layer := CanvasLayer.new()
	post_layer.layer = 0
	add_child(post_layer)

	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)

	# One full-rect Control that everything anchors to, with the safe area
	# applied as its margins. Nothing inside is positioned against a literal
	# screen size: the project keeps its base WIDTH and extends the HEIGHT, so a
	# control placed against the base 1920 lands hundreds of pixels high on a
	# 2340-tall phone and the report is that the buttons are half an inch off.
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)

	# **Post goes UNDER the HUD.** A vignette over the instruments dims the one
	# thing that must stay legible, and grain over type is just type that is
	# harder to read.
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = load("res://src/game/post.gdshader")
	_post = ColorRect.new()
	_post.material = _post_mat
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post.color = Color(1, 1, 1, 1)
	post_layer.add_child(_post)

	_hud = Hud.new()
	_hud.setup(sim)
	_ui.add_child(_hud)

	_shell = Shell.new()
	_shell.setup()
	_ui.add_child(_shell)
	_shell.start_new.connect(_on_new_game)
	_shell.resume.connect(_on_resume)
	_shell.erase.connect(_on_new_game)
	# **Saved on every meaningful change**, not on a timer: a descent ending, a
	# rung bought and a planet finished are the three moments progress moves.
	sim.descent_over.connect(func(_why): Save.write(sim))
	_hud._lamp_btn.pressed.connect(func(): sim.cycle_lamp())
	_hud._uplink_btn.pressed.connect(func(): sim.uplink())
	_hud._launch_btn.pressed.connect(func(): sim.launch())
	_hud._touch.touched.connect(_on_hold_touch)
	_hud._touch.dragged.connect(_on_hold_drag)

	_apply_safe_area()
	# `get_viewport()` is null until the node is inside the tree, and a harness
	# boots the scene from `SceneTree._initialize()` where it is not yet. An
	# engine ERROR line is a test failure even when every assertion passes, so
	# this is guarded and re-attempted from `_ready`.
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_apply_safe_area):
		vp.size_changed.connect(_apply_safe_area)


func _apply_safe_area() -> void:
	var view := get_viewport()
	if view == null:
		return

	# **The safe area is a mobile concept.** On desktop `get_display_safe_area()`
	# returns the usable DESKTOP - the monitor minus the taskbar - which has
	# nothing to do with this window, and applying it inset every control by
	# about a hundred pixels. Measured: the d-pad's real rect sat 104 px above
	# where its offsets said, so a filmed replay tapped empty space, the run
	# filmed perfectly, and the ship never left the surface.
	if not OS.has_feature("mobile"):
		_ui.offset_left = 0.0
		_ui.offset_top = 0.0
		_ui.offset_right = 0.0
		_ui.offset_bottom = 0.0
		return

	var safe := DisplayServer.get_display_safe_area()
	# The WINDOW, not the screen. The safe area is in window pixels and the
	# margins have to be in viewport units; dividing by the screen size mixes
	# the monitor's pixels with the viewport's and the answer is arbitrary.
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return
	var vp := Vector2(view.get_visible_rect().size)
	var sx := vp.x / float(win.x)
	var sy := vp.y / float(win.y)
	_ui.offset_left = float(safe.position.x) * sx
	_ui.offset_top = float(safe.position.y) * sy
	_ui.offset_right = -float(win.x - safe.end.x) * sx
	_ui.offset_bottom = -float(win.y - safe.end.y) * sy


# ── input ─────────────────────────────────────────────────────────────────

## The d-pad owns its own input and its own drawing, so the hit box and the
## picture are one object. Main only reads what it decided.
func _read_input() -> void:
	_pad_vec = _hud.pad_vector()
	# Digging and flying are the same held direction, which is what keeps the
	# game to one thumb. The manifest being open stops both, or a player reading
	# the manifest flies into a wall while they do it.
	if _hud.manifest_open():
		_pad_vec = Vector2.ZERO
	_drilling = _pad_vec != Vector2.ZERO


# ── the frame ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _frozen:
		return
	_tick(delta)


func _on_new_game() -> void:
	Save._reset_latch_for_tests()
	sim = Sim.new(1, Classes.CINDER)
	_rebind()


func _on_resume() -> void:
	var loaded := Sim.new(1)
	if Save.read(loaded):
		sim = loaded
	_rebind()


## Everything that holds a reference to `Sim` is re-pointed in ONE place, so a
## new game or a load cannot leave half the game reading the old one.
func _rebind() -> void:
	_terrain.setup(sim.world, _rock_mat)
	_hud.sim = sim
	_field.touch()
	_terrain.touch()
	_last_cell = Vector2i(99999, 99999)
	_in_hold = false
	if _hold != null:
		_hold.sim = sim
		_hold.visible = false
	_cam.current = true
	_terrain.visible = true
	_haze.visible = true
	_lamp.visible = true
	_bind_audio()


func _tick(dt: float) -> void:
	# The title is a screen in front of the game, and the game is not running
	# behind it: HOME is the level you are about to play with `advance` not being
	# called, which is what makes it playable within ten seconds of the icon.
	if _shell != null and not _shell.playing():
		_hud.visible = false
		return
	_hud.visible = true

	# The Hold is a different place, not a screen over this one. Nothing about
	# the descent runs while the player is in it.
	if sim.phase == Sim.Phase.HOLD:
		if not _in_hold:
			_enter_hold()
		_hold.tick(dt)
		_hud.tick(dt)
		return
	if _in_hold:
		_leave_hold()

	_read_input()
	sim.step(_pad_vec, _drilling, dt)
	_sync_camera(dt)
	_redraw_world()
	_audio.tick(sim, dt)
	# The vignette closes past the Line, which is the fourth thing landing on
	# that metre and the only one the player feels rather than reads.
	_post_mat.set_shader_parameter("pressure",
		clampf(sim.pressure_rate() / 3.0, 0.0, 1.0))
	_hud.tick(dt)


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
	_ship.aim(sim.flight.heading)
	# Throttle is read from the simulation's own velocity rather than from the
	# input, so the nozzles show what the ship is doing and not what was asked.
	var throttle: float = clampf(sim.flight.vel.length() / maxf(Tuning.TOP_SPEED, 0.001), 0.0, 1.0)
	_ship.drive(_drilling, throttle, dt)
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
	# **One number for the fan's range, cast and decoded with the same value.**
	# It was cast to 1.8x the lamp reach and decoded with 1x, so every shadow
	# began at 55% of its true distance and the lit pool was cut short in every
	# direction. That is the same shape of fault as two thresholds for "gone",
	# so the multiplier lives in Tuning and the smoke run asserts that what the
	# fan was cast to is what the shader was handed.
	var fan_reach := reach * Tuning.FAN_REACH_MULT
	_field.refresh_fan(sim.world, sim.flight.pos, fan_reach)

	var density := Tuning.density_at(sim.flight.depth())
	var origin := _field.origin_world()
	var h := sim.flight.heading

	# The lamp MODE changes the beam's shape, not just its reach: the flood is
	# wide and short, the lance is narrow and long, and dark is barely there.
	# The angular profile is shared by the air and the rock so the beam in the
	# tunnel and the pool it lands in are one light.
	var half: float = Tuning.LAMP_CONE[sim.lamp_mode] * 0.5
	var cone_hi: float = cos(clampf(half * 0.45, 0.05, 1.5))
	var cone_lo: float = cos(clampf(half * 1.25, 0.1, 3.0))

	for m in [_rock_mat, _haze_mat]:
		m.set_shader_parameter("field_origin", origin)
		m.set_shader_parameter("lamp_pos", sim.flight.pos)
		m.set_shader_parameter("lamp_dir", h)
		m.set_shader_parameter("lamp_reach", reach)
		m.set_shader_parameter("cone_lo", cone_lo)
		m.set_shader_parameter("cone_hi", cone_hi)
		m.set_shader_parameter("density", density)
	_haze_mat.set_shader_parameter("fan_reach", fan_reach)
	_haze_mat.set_shader_parameter("fan", _field.fan_texture)

	_haze.position = Vector3(sim.flight.pos.x, DEPTH_SIGN * sim.flight.pos.y, HAZE_Z)

	# The collapse rides in front of the rock: the player has to see it coming
	# THROUGH the tunnel they are climbing, not behind the wall.
	_collapse.visible = sim.phase == Sim.Phase.EXTRACTION
	if _collapse.visible:
		_collapse.position = Vector3(0.0, DEPTH_SIGN * sim.flight.pos.y, 0.9)
		_collapse_mat.set_shader_parameter("rise_depth", sim.rising)

	# The air is one number, and it drives the fog as well as the lamp, the drag
	# and the hull load. Volumetric fog is Forward+ only, so this is the built-in
	# depth fog doing the work, thickened by the same quantity.
	if _env != null:
		# Set against a screenshot at the phone's aspect, which is the only place
		# a fog curve can honestly be judged. At 0.020 the deep bands washed the
		# rock out completely: the air being denser has to be felt, and the rock
		# still has to be legible, because the rock is where the ore is.
		_env.fog_density = clampf(0.010 + density * 0.012, 0.0, 0.20)
		# The air changes colour at the same metre the rock does and the hull
		# starts draining. Four things on one metre, from one table, so they
		# cannot drift apart the way they did in Coreward.
		var air := Classes.air_at(sim.world.class_id, sim.flight.depth())
		_env.fog_light_color = _env.fog_light_color.lerp(air, 0.08)
		_env.ambient_light_color = _env.ambient_light_color.lerp(
			Color(air.r * 1.6 + 0.05, air.g * 1.6 + 0.06, air.b * 1.6 + 0.08), 0.08)


# ── the Hold ──────────────────────────────────────────────────────────────

## **Hide the game entirely.** Leaving half the world visible behind a shop is
## what makes it read as a pop-up however it is styled, and that was the note
## Coreward got after the panel had already been restyled twice.
func _enter_hold() -> void:
	_in_hold = true
	if _hold == null:
		_hold = Hold.new()
		add_child(_hold)
		_hold.setup(sim, _ship)
	else:
		_ship.get_parent().remove_child(_ship)
		_ship.position = Vector3.ZERO
		_ship.rotation = Vector3.ZERO
		_ship.scale = Vector3.ONE
		_hold._ship_cradle.add_child(_ship)
	_hold.visible = true
	_hold._cam.current = true
	_hold.refresh()
	_terrain.visible = false
	_haze.visible = false
	_collapse.visible = false
	_lamp.visible = false
	_env.background_color = Color(0.03, 0.031, 0.036)


func _leave_hold() -> void:
	_in_hold = false
	if _hold != null:
		_hold.visible = false
		_ship.get_parent().remove_child(_ship)
		_ship.scale = Vector3.ONE
		add_child(_ship)
	_cam.current = true
	_terrain.visible = true
	_haze.visible = true
	_lamp.visible = true
	_env.background_color = Color(0.02, 0.021, 0.026)
	_last_cell = Vector2i(99999, 99999)      ## force a rebuild on the way back


## A tap in the Hold buys what it hit; a drag pans the room. Discriminated by
## MOVEMENT rather than by time, so the two verbs never fight.
func _on_hold_touch(at: Vector2, pressed: bool) -> void:
	if pressed:
		_drag_from = at
		_dragging = false
		return
	if _dragging:
		return
	var id := _hold.pick(at)
	if id != "" and sim.buy(id):
		_hold.refresh()
		_audio.click(true)
		Save.write(sim)
	elif id != "":
		_audio.click(false)


func _on_hold_drag(at: Vector2, relative: Vector2) -> void:
	if absf(at.y - _drag_from.y) > 14.0:
		_dragging = true
	if _dragging:
		_hold.pan(relative.y, float(get_viewport().get_visible_rect().size.y))


# ── the harness seam ──────────────────────────────────────────────────────

## Freeze real frames and drive game time by hand. Sixty game seconds is sixty
## game seconds on every machine, which is what makes a filmed run and a smoke
## test comparable between runs and between machines.
func freeze() -> void:
	_ensure_booted()
	_frozen = true


## Get past the title, the way NEW GAME does.
##
## `_tick` returns immediately while the shell is not playing, on purpose: the
## title is a screen in FRONT of the game and the game is not running behind it.
## That means a harness that only calls `freeze()` and `advance()` advances
## nothing at all and captures the title. Every shot script here was written
## before the shell existed, and the first lighting screenshot after it landed
## was a picture of the menu.
func start_run() -> void:
	_ensure_booted()
	if _shell != null and not _shell.playing():
		_shell.begin_new()


func advance(seconds: float, step: float = 1.0 / 60.0) -> void:
	_ensure_booted()
	var n := int(seconds / step)
	for _i in range(n):
		_tick(step)


## Drive the pad the way a thumb does, for tests and replays. It sets the PAD's
## own vector rather than main's, so the value goes through the same path a
## finger's does: a way in that the real control never produces is a missing
## feature with full coverage.
func press_pad(dir: Vector2) -> void:
	_ensure_booted()
	_hud._pad.vector = dir
	_read_input()
