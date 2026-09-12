class_name Hud
extends Control

## The instruments, the thumb controls, and the manifest.
##
## **Where a readout sits matters more than how it looks**, so the layout here is
## the design and the styling is the smaller half:
##
## | Readout | Where | Why |
## |---|---|---|
## | Depth | top centre, large | Depth is the record, and the thing he talks about |
## | POWER | a slim column up the LEFT edge | Watched continuously, so it cannot sit under the thumb |
## | HULL | under the power column | Same, and beside the thing it is compared against |
## | LOAD | top right, tappable | Glanced at, and the tap opens the manifest |
## | rate | beside whichever gauge is draining | A number beats a bar when the player needs causation |
##
## His complaints this answers, in his words: "my thumb will be blocking the
## gauge I am looking at", "it won't scroll down so I can't see all of the
## upgrades or close out of the menu", and "The button icons don't line up with
## where you need to press ... about .5 inches too high".
##
## Everything is drawn rather than themed, because a HUD on a textured world
## needs its own material and Godot's default theme is a different game's.

const INK := Color(0.86, 0.88, 0.90)
const DIM := Color(0.50, 0.53, 0.57)
const PLATE := Color(0.055, 0.058, 0.065, 0.86)
const EDGE := Color(0.26, 0.28, 0.32, 0.9)
const WARN := Color(0.92, 0.42, 0.20)
const GOOD := Color(0.55, 0.78, 0.72)
const GLOW := Color(0.95, 0.78, 0.38)

## A needle has mass: it is damped toward what it shows, so a gauge checked
## under pressure does not twitch. Never so slow that it lies about the number.
const NEEDLE_RATE := 9.0

var sim: Sim

var _depth: Label
var _power: Gauge
var _hull: Gauge
var _load_btn: Button
var _rate: Label
var _bank: Label
var _state: Label
var _pad: DPad
var _lamp_btn: PlateButton
var _uplink_btn: PlateButton
var _manifest: ManifestSheet
var _launch_btn: PlateButton
var _pause_btn: PlateButton
var _hold_hint: Label
var _touch: TouchLayer

var _mono: FontFile
var _face: FontFile


func setup(s: Sim) -> void:
	sim = s
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_mono = load("res://assets/fonts/ShareTechMono/ShareTechMono-Regular.ttf")
	_face = load("res://assets/fonts/ChakraPetch/ChakraPetch-Bold.ttf")

	_build_instruments()
	_build_controls()
	_build_hold_ui()
	_build_manifest()


# ── the instruments ───────────────────────────────────────────────────────

func _build_instruments() -> void:
	# Depth, large, top centre. Monospace, so the number does not jitter sideways
	# as it climbs: that is what a tabular-figures font buys, and Share Tech Mono
	# gives it by being monospace rather than by a feature flag.
	_depth = _label(_mono, 64, INK)
	_depth.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_depth.offset_top = 26.0
	_depth.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_depth)

	# POWER up the left edge. Watched continuously, so it sits where the thumb
	# never goes.
	_power = Gauge.new()
	_power.setup("PWR", GOOD, WARN, true, _face, _mono)
	_power.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_power.offset_left = 22.0
	_power.offset_right = 74.0
	_power.offset_top = -300.0
	_power.offset_bottom = 20.0
	add_child(_power)

	_hull = Gauge.new()
	_hull.setup("HULL", GOOD, WARN, true, _face, _mono)
	_hull.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_hull.offset_left = 86.0
	_hull.offset_right = 122.0
	_hull.offset_top = -220.0
	_hull.offset_bottom = 20.0
	add_child(_hull)

	# The rate readout, beside the gauge that is draining. A number beats a bar
	# when the player needs causation: `HULL -3.4/s` says what is happening to
	# them and why, which a shrinking bar does not.
	_rate = _label(_mono, 30, WARN)
	_rate.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_rate.offset_left = 132.0
	_rate.offset_top = -30.0
	add_child(_rate)

	# LOAD, top right, and it opens the manifest. Glanced at rather than watched,
	# so the right-hand side is fine.
	_load_btn = Button.new()
	_load_btn.flat = true
	_load_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_load_btn.offset_left = -260.0
	_load_btn.offset_right = -20.0
	_load_btn.offset_top = 104.0
	_load_btn.offset_bottom = 176.0
	_load_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_load_btn.add_theme_font_override("font", _mono)
	_load_btn.add_theme_font_size_override("font_size", 34)
	_load_btn.add_theme_color_override("font_color", INK)
	_load_btn.pressed.connect(_on_manifest)
	add_child(_load_btn)

	_bank = _label(_mono, 32, GLOW)
	_bank.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_bank.offset_left = 22.0
	_bank.offset_top = 104.0
	add_child(_bank)

	# Every state names a visible action. This is where that sentence goes.
	_state = _label(_face, 34, INK)
	_state.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_state.offset_top = 220.0
	_state.offset_left = -400.0
	_state.offset_right = 400.0
	_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_state)


func _label(font: FontFile, size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	# A HUD over a textured world needs to stay readable on top of a lit rock
	# face as well as on black, so everything carries a shadow rather than a box.
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ── the thumb ─────────────────────────────────────────────────────────────

func _build_controls() -> void:
	_pad = DPad.new()
	_pad.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_pad.offset_left = -168.0
	_pad.offset_right = 168.0
	# Anchored to the real BOTTOM and offset upward, so the distance from the
	# bottom edge is fixed at any aspect. Placed against the base height instead,
	# a control lands hundreds of pixels high on a 2340-tall phone, and the
	# report was that the buttons were half an inch off.
	_pad.offset_top = -376.0
	_pad.offset_bottom = -40.0
	add_child(_pad)

	_uplink_btn = PlateButton.new()
	_uplink_btn.setup("UPLINK", _face, _mono)
	_place_button(_uplink_btn, -256.0, -376.0)

	_lamp_btn = PlateButton.new()
	_lamp_btn.setup("FLOOD", _face, _mono)
	_place_button(_lamp_btn, -256.0, -228.0)

	# **A pause the thumb can find.** His ask: "can you also add a pause button?"
	#
	# The back gesture opened the sheet already, and on a phone with gesture
	# navigation a back SWIPE is not a control anyone discovers - `POLISH.md`
	# wants pause reachable without a system gesture, and this is why.
	#
	# **Down the left edge, under the gauges.** The top row is already three
	# readouts wide - the bank on the left, the depth in the middle, the hold on
	# the right - and the first placement put this straight on top of the credits
	# line, which the screenshot showed immediately.
	#
	# Here it is diagonally opposite the d-pad, on the side the driving thumb is
	# not, and far enough down that a hand reaching for it covers nothing that is
	# changing. Small, because it is not a control anyone needs to find in a
	# hurry: the run pauses itself when the phone does.
	_pause_btn = PlateButton.new()
	_pause_btn.setup("PAUSE", _face, _mono)
	_pause_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_pause_btn.offset_left = 22.0
	_pause_btn.offset_right = 22.0 + 152.0
	_pause_btn.offset_top = 196.0
	_pause_btn.offset_bottom = 196.0 + 88.0
	add_child(_pause_btn)


func _place_button(b: PlateButton, from_right: float, from_bottom: float) -> void:
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = from_right
	b.offset_right = from_right + 216.0
	b.offset_top = from_bottom
	b.offset_bottom = from_bottom + 128.0
	add_child(b)


## The Hold's own controls: a pinned LAUNCH and a layer that catches the taps
## and drags the room reads.
func _build_hold_ui() -> void:
	_touch = TouchLayer.new()
	_touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch.visible = false
	add_child(_touch)

	_launch_btn = PlateButton.new()
	_launch_btn.setup("LAUNCH", _face, _mono)
	_launch_btn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_launch_btn.offset_left = 40.0
	_launch_btn.offset_right = -40.0
	# **Pinned to the bottom of the scrolling sheet.** "it won't scroll down so I
	# can't see all of the upgrades or close out of the menu" is a blocker that
	# has shipped once, and the answer is that the way out never scrolls.
	_launch_btn.offset_top = -180.0
	_launch_btn.offset_bottom = -48.0
	_launch_btn.visible = false
	add_child(_launch_btn)

	# Under the bank line at the top, not down among the cases: a hint laid over
	# the rack is one more thing competing with the thing it is explaining.
	_hold_hint = _label(_face, 28, DIM)
	_hold_hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hold_hint.offset_left = 22.0
	_hold_hint.offset_top = 152.0
	_hold_hint.visible = false
	add_child(_hold_hint)


func _build_manifest() -> void:
	_manifest = ManifestSheet.new()
	_manifest.setup(_face, _mono)
	_manifest.visible = false
	add_child(_manifest)


func _on_manifest() -> void:
	_manifest.open(sim)


# ── the frame ─────────────────────────────────────────────────────────────

func tick(dt: float) -> void:
	var in_hold := sim.phase == Sim.Phase.HOLD
	_touch.visible = in_hold
	_launch_btn.visible = in_hold
	_hold_hint.visible = in_hold
	for c in [_depth, _power, _hull, _load_btn, _rate, _state, _pad, _lamp_btn, _uplink_btn, _pause_btn]:
		c.visible = not in_hold
	if in_hold:
		_bank.text = "%s cr   %d fil   %d/7 cores" % [
			SimUtil.fmt(sim.credits), sim.filament, sim.cores_held()]
		_launch_btn.set_enabled(true)
		if sim.planet_finished():
			_launch_btn.set_caption("LAUNCH", "to a new world")
			_hold_hint.text = "tap a case to fit it - drag to see the rest"
		else:
			_launch_btn.set_caption("DESCEND", "your tunnels are still open")
			_hold_hint.text = "tap a case to fit it - drag to see the rest"
		return

	_depth.text = "%d m" % int(sim.flight.depth())
	_power.set_value(sim.power_frac(), "%d%%" % int(sim.power_frac() * 100.0), dt)
	_hull.set_value(sim.hull_frac(), "%d%%" % int(sim.hull_frac() * 100.0), dt)
	_load_btn.text = "%.0f/%.0f kg" % [sim.load_kg, Tuning.HOLD_KG]
	_bank.text = "%s cr   %d fil" % [SimUtil.fmt(sim.credits), sim.filament]

	# **Whichever gauge is actually going down.** Verge's pressure is on the
	# battery rather than the hull, so a readout hard-wired to HULL would show
	# nothing at all on the one world where the number matters most.
	var rate := sim.pressure_rate()
	var surge := sim.surge_rate()
	if surge > rate:
		_rate.text = "PWR -%.1f/s" % surge
	elif rate > 0.0:
		_rate.text = "HULL -%.1f/s" % rate
	else:
		_rate.text = ""

	# "Unavailable" and "not a control" are two different booleans, and only
	# refusal is grey. UPLINK with an empty hold is not a refusal, it is nothing
	# to do, so it says so rather than sitting there greyed and unexplained.
	_uplink_btn.set_enabled(sim.can_uplink())
	if sim.load_kg <= 0.0:
		_uplink_btn.set_caption("UPLINK", "hold empty")
	elif sim.power <= sim.uplink_cost():
		_uplink_btn.set_caption("UPLINK", "needs %d pwr" % int(sim.uplink_cost()))
	else:
		_uplink_btn.set_caption("UPLINK", "%s cr" % SimUtil.fmt(sim.hold_value()))

	var modes := ["FLOOD", "LANCE", "DARK"]
	var mode_note := ["wide", "far", "recharging"]
	_lamp_btn.set_caption(modes[sim.lamp_mode], mode_note[sim.lamp_mode])
	_lamp_btn.set_enabled(true)

	# **Every state names a visible action.** A way out only the simulation
	# knows about is not a way out, and a frozen HUD with no sentence on it has
	# shipped twice from this template's ancestors.
	if sim.phase == Sim.Phase.OVER:
		if sim.outcome == "escaped with the core":
			_state.text = "OUT, WITH THE CORE.
this world is finished. TAP TO GO ON"
		else:
			_state.text = "RECOVERED - %s
your tunnels are still open. TAP TO DESCEND AGAIN" % sim.outcome
	elif sim.phase == Sim.Phase.EXTRACTION:
		# A number, not a bar: the player needs to know how long, not roughly how
		# much. And it is the same quantity the simulation kills them with, so the
		# picture cannot promise a second the rules do not give.
		_state.text = "THE CORE IS FREE - GET OUT
%d s" % int(ceilf(sim.extract_left))
	elif sim.crack_warning() < Classes.BRITTLE_DELAY:
		# Announced before it charges, and by more than human reaction time. The
		# player hears the ice go and chooses whether to finish the seam.
		_state.text = "THE CEILING IS GOING"
	elif sim.power_frac() < Tuning.LAMP_FADE_START:
		_state.text = "POWER LOW — the lamp is going"
	elif sim.flight.depth() > float(Tuning.LINE_DEPTH) - Tuning.LINE_WARN_M \
			and sim.flight.depth() < float(Tuning.LINE_DEPTH):
		_state.text = "%s BELOW" % Classes.line_name(sim.world.class_id)
	else:
		_state.text = ""


func pad_vector() -> Vector2:
	return _pad.vector


func manifest_open() -> bool:
	return _manifest.visible


# ── the parts ─────────────────────────────────────────────────────────────

## A gauge drawn as an instrument rather than a themed ProgressBar: a slim
## column with a scale, a damped needle and a plate behind it.
class Gauge extends Control:
	var _label_text := ""
	var _readout := ""
	var _target := 1.0
	var _shown := 1.0
	var _good: Color
	var _bad: Color
	var _face: FontFile
	var _mono: FontFile

	func setup(text: String, good: Color, bad: Color, _vertical: bool,
			face: FontFile, mono: FontFile) -> void:
		_label_text = text
		_good = good
		_bad = bad
		_face = face
		_mono = mono
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float, readout: String, dt: float) -> void:
		_target = clampf(v, 0.0, 1.0)
		# Damped, so a gauge glanced at under pressure has mass and does not
		# twitch on every frame's arithmetic.
		_shown = lerpf(_shown, _target, SimUtil.smooth(NEEDLE_RATE, dt))
		_readout = readout
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, PLATE, true)
		draw_rect(r, EDGE, false, 2.0)

		var inner := r.grow(-6.0)
		var h := inner.size.y * _shown
		var col := _bad.lerp(_good, clampf(_shown * 1.6, 0.0, 1.0))
		draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - h),
			Vector2(inner.size.x, h)), col, true)

		# A scale, so the bar is read as a quantity rather than as a colour.
		for i in range(1, 5):
			var y := inner.position.y + inner.size.y * float(i) / 5.0
			draw_line(Vector2(inner.position.x, y),
				Vector2(inner.position.x + inner.size.x * 0.35, y), Color(0, 0, 0, 0.55), 2.0)

		if _face != null:
			draw_string(_face, Vector2(2.0, -10.0), _label_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, DIM)
		if _mono != null:
			draw_string(_mono, Vector2(2.0, size.y + 28.0), _readout,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK)


## A bare surface that reports taps and drags, for the Hold. It exists so the
## room can be picked with a ray against its own geometry: the hit box is then
## the case itself and not a rectangle somebody typed.
class TouchLayer extends Control:
	signal touched(at: Vector2, pressed: bool)
	signal dragged(at: Vector2, relative: Vector2)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)

	func _on_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			touched.emit(event.position, event.pressed)
			accept_event()
		elif event is InputEventScreenDrag:
			dragged.emit(event.position, event.relative)
			accept_event()
		elif event is InputEventMouseButton:
			touched.emit(event.position, event.pressed)
			accept_event()
		elif event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask != 0:
			dragged.emit(event.position, event.relative)
			accept_event()


## The d-pad, drawn, absolute rather than relative: the picture always says
## which way the machine is pointing. Eight directions, snapped, because a
## continuous angle cannot be squared up to the grid and squaring up is what
## makes a cut go straight.
class DPad extends Control:
	var vector := Vector2.ZERO
	var _touch := -1
	var _press := Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)

	func _on_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed:
				_touch = event.index
				_aim_from(event.position)
			elif event.index == _touch:
				_touch = -1
				_aim_from(Vector2(-9999, -9999))
			accept_event()
		elif event is InputEventScreenDrag and event.index == _touch:
			_aim_from(event.position)
			accept_event()
		elif event is InputEventMouseButton:
			_aim_from(event.position if event.pressed else Vector2(-9999, -9999))
			accept_event()
		elif event is InputEventMouseMotion and vector != Vector2.ZERO:
			_aim_from(event.position)
			accept_event()

	## Not `_set`: that is Object's own virtual, and overriding it with a
	## different signature is a parse error that reads as the entire scene
	## failing to compile.
	func _aim_from(local: Vector2) -> void:
		_press = local
		if local.x < -9000.0:
			vector = Vector2.ZERO
			queue_redraw()
			return
		var v := local - size * 0.5
		if v.length() < size.x * 0.13:
			vector = Vector2.ZERO
		else:
			var a := snappedf(v.angle(), PI / 4.0)
			vector = Vector2(cos(a), sin(a))
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var outer: float = size.x * 0.5
		draw_circle(c, outer, Color(0.05, 0.052, 0.058, 0.62))
		draw_arc(c, outer - 2.0, 0.0, TAU, 48, EDGE, 3.0)
		draw_arc(c, size.x * 0.13, 0.0, TAU, 24, Color(0.22, 0.24, 0.27, 0.8), 2.0)

		# Eight ticks, so the control tells you it has eight directions before
		# you have pressed it once.
		for i in range(8):
			var a := TAU * float(i) / 8.0
			var d := Vector2(cos(a), sin(a))
			draw_line(c + d * (outer * 0.42), c + d * (outer * 0.78),
				Color(0.30, 0.33, 0.37, 0.75), 3.0)

		if vector != Vector2.ZERO:
			# A pressed control reads as PUSHED IN, not lit up: the wedge is a
			# darker inset with a bright rim, not a glowing overlay.
			var pts := PackedVector2Array()
			var base := vector.angle()
			pts.append(c)
			for k in range(9):
				var a: float = base - PI / 8.0 + (PI / 4.0) * float(k) / 8.0
				pts.append(c + Vector2(cos(a), sin(a)) * outer * 0.94)
			draw_colored_polygon(pts, Color(0.02, 0.02, 0.024, 0.72))
			draw_line(c + vector * outer * 0.42, c + vector * outer * 0.90, INK, 5.0)


## A button that reads as a plate on a machine: a caption, a small note under
## it, and a pressed state that goes IN.
class PlateButton extends Control:
	signal pressed

	var _caption := ""
	var _note := ""
	var _enabled := true
	var _down := false
	var _face: FontFile
	var _mono: FontFile

	func setup(caption: String, face: FontFile, mono: FontFile) -> void:
		_caption = caption
		_face = face
		_mono = mono
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)

	func set_caption(caption: String, note: String) -> void:
		if caption == _caption and note == _note:
			return
		_caption = caption
		_note = note
		queue_redraw()

	func set_enabled(v: bool) -> void:
		if v == _enabled:
			return
		_enabled = v
		queue_redraw()

	func _on_input(event: InputEvent) -> void:
		var down := false
		var release := false
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			down = event.pressed
			release = not event.pressed
		if down:
			_down = true
			queue_redraw()
			accept_event()
		elif release:
			if _down and _enabled:
				pressed.emit()
			_down = false
			queue_redraw()
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var inset := 3.0 if _down else 0.0
		var body := Rect2(r.position + Vector2(inset, inset), r.size - Vector2(inset, inset) * 2.0)
		draw_rect(body, PLATE, true)
		# Enabled and disabled say it three ways: colour, text and the value.
		# Only refusal is grey.
		var ink: Color = INK if _enabled else DIM
		draw_rect(body, EDGE if _enabled else Color(0.16, 0.17, 0.19, 0.8), false, 2.0)
		if not _down:
			draw_line(body.position + Vector2(2, 2),
				body.position + Vector2(body.size.x - 2, 2), Color(1, 1, 1, 0.06), 2.0)
		if _face != null:
			draw_string(_face, Vector2(16.0, body.size.y * 0.52), _caption,
				HORIZONTAL_ALIGNMENT_LEFT, body.size.x - 24.0, 34, ink)
		if _mono != null and _note != "":
			draw_string(_mono, Vector2(16.0, body.size.y * 0.82), _note,
				HORIZONTAL_ALIGNMENT_LEFT, body.size.x - 24.0, 24, DIM)


## The manifest: count, weight and value per mineral.
##
## This is his ask number three from Coreward, in from the first build: "It is
## difficult to judge the price of the different blocks you are mining." If the
## player cannot compare two things on screen, the choice between them is not a
## real choice.
##
## It scrolls from a finger by hand, because **a ScrollContainer does not
## scroll from a touch drag at all** - measured at wheel 50, pan 400,
## InputEventScreenDrag zero - and its close button is pinned to the bottom,
## because "it won't scroll down so I can't see all of the upgrades or close out
## of the menu" is a blocker that has shipped once.
class ManifestSheet extends Control:
	var _rows: Array[Dictionary] = []
	var _total := 0.0
	var _scroll := 0.0
	var _max_scroll := 0.0
	var _face: FontFile
	var _mono: FontFile
	var _close: PlateButton

	const ROW_H := 74.0

	func setup(face: FontFile, mono: FontFile) -> void:
		_face = face
		_mono = mono
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)

		_close = PlateButton.new()
		_close.setup("CLOSE", face, mono)
		_close.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_close.offset_left = 40.0
		_close.offset_right = -40.0
		_close.offset_top = -168.0
		_close.offset_bottom = -48.0
		_close.pressed.connect(close)
		add_child(_close)

	func open(sim: Sim) -> void:
		_rows = sim.manifest()
		_total = sim.hold_value()
		_scroll = 0.0
		_max_scroll = maxf(0.0, float(_rows.size()) * ROW_H - (size.y - 460.0))
		visible = true
		queue_redraw()

	func close() -> void:
		visible = false

	func _on_input(event: InputEvent) -> void:
		# Translate the drag by hand. A ScrollContainer ignores a finger.
		if event is InputEventScreenDrag or (event is InputEventMouseMotion
				and (event as InputEventMouseMotion).button_mask != 0):
			_scroll = clampf(_scroll - event.relative.y, 0.0, _max_scroll)
			queue_redraw()
			accept_event()

	func _draw() -> void:
		# Hide the game entirely behind it. Leaving half the world visible is
		# what makes a screen read as a pop-up however it is styled.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.021, 0.026, 0.97), true)
		if _face == null:
			return
		draw_string(_face, Vector2(40.0, 130.0), "MANIFEST",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 48, INK)
		draw_string(_mono, Vector2(40.0, 186.0), "%s cr aboard" % SimUtil.fmt(_total),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, GLOW)
		draw_string(_mono, Vector2(40.0, 250.0), "MINERAL        N     KG      CR",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, DIM)

		if _rows.is_empty():
			draw_string(_face, Vector2(40.0, 330.0), "The hold is empty.",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 34, DIM)
			return

		var y := 300.0 - _scroll
		for row in _rows:
			if y > 240.0 and y < size.y - 200.0:
				draw_string(_face, Vector2(40.0, y), String(row["name"]),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 34, INK)
				draw_string(_mono, Vector2(size.x - 380.0, y),
					"%4d  %6.1f  %7s" % [int(row["count"]), float(row["kg"]),
						SimUtil.fmt(float(row["value"]))],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
			y += ROW_H
