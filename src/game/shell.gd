class_name Shell
extends Control

## The way in, the way out, and the pause sheet.
##
## ## The title
##
## Over a LIVE scene, not a painted one, and CONTINUE is greyed rather than
## hidden on a first run. He asked for greyed and he was right: an absent button
## tells a new player nothing, and a greyed one says "this is where your game
## will be".
##
## It is also where the audio gesture happens. `AudioContext`-style unlocking
## aside, the first tap of a game should not be the one that is silent, and a
## title screen is a tap before anything is at stake.
##
## ## The pause sheet
##
## Version, build stamp and patch notes, which he asked for by name after several
## sessions of the build stamp alone not being enough, and the lesson recorded
## was to do it much earlier in the next game. This is the next game.
##
## Settings and Notes are the SAME sheet with a different heading, because it is
## already the settings screen and a second copy of those controls is a second
## place for them to drift.
##
## ## The back button
##
## `quit_on_go_back = false` and the `NOTIFICATION_WM_GO_BACK_REQUEST` handler
## ship in the same commit, or the setting alone makes the system button do
## nothing at all. Both states are shippable and neither shows in a headless
## suite. It unwinds one layer per press and never quits without asking.

signal start_new
signal resume
signal erase

enum Screen { TITLE, PLAYING, PAUSED, NOTES }

var screen: int = Screen.TITLE

var _face: FontFile
var _mono: FontFile
var _title: Control
var _pause: Control
var _continue: Hud.PlateButton
var _new: Hud.PlateButton
var _confirm_wipe := false
var _sheet_scroll := 0.0
var _sheet_max := 0.0
var _notes_mode := false

var _music := 0.8
var _sfx := 1.0
var _haptics := true


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face = load("res://assets/fonts/ChakraPetch/ChakraPetch-Bold.ttf")
	_mono = load("res://assets/fonts/ShareTechMono/ShareTechMono-Regular.ttf")

	var s := Save.read_settings()
	_music = float(s["music"])
	_sfx = float(s["sfx"])
	_haptics = bool(s["haptics"])
	_apply_audio()

	_build_title()
	_build_pause()
	_show()


func _build_title() -> void:
	_title = TitlePlate.new()
	(_title as TitlePlate).fonts(_face, _mono)
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_title)

	_continue = Hud.PlateButton.new()
	_continue.setup("CONTINUE", _face, _mono)
	_place(_continue, _title, -430.0)
	_continue.pressed.connect(func():
		if Save.exists():
			screen = Screen.PLAYING
			_show()
			resume.emit())

	_new = Hud.PlateButton.new()
	_new.setup("NEW GAME", _face, _mono)
	_place(_new, _title, -290.0)
	_new.pressed.connect(begin_new)

	var settings := Hud.PlateButton.new()
	settings.setup("SETTINGS", _face, _mono)
	_place(settings, _title, -150.0)
	settings.pressed.connect(func():
		_notes_mode = false
		screen = Screen.PAUSED
		_show())


func _place(b: Hud.PlateButton, parent: Control, from_bottom: float) -> void:
	b.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	b.offset_left = 60.0
	b.offset_right = -60.0
	b.offset_top = from_bottom
	b.offset_bottom = from_bottom + 124.0
	parent.add_child(b)


func _build_pause() -> void:
	_pause = PauseSheet.new()
	(_pause as PauseSheet).fonts(_face, _mono)
	(_pause as PauseSheet).shell = self
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause)

	var back := Hud.PlateButton.new()
	back.setup("BACK", _face, _mono)
	# Pinned to the bottom of the scrolling sheet. The way out never scrolls.
	_place(back, _pause, -160.0)
	back.pressed.connect(func(): go_back())


func _show() -> void:
	# **One writer per UI phase.** This assigns the screen AND recomputes every
	# panel's visibility, so there is no path that sets one without the other.
	# Assigning the phase next to a show call worked in four places out of five
	# in a sibling game, and the fifth left a screen drawn over the whole game.
	_title.visible = screen == Screen.TITLE
	_pause.visible = screen == Screen.PAUSED or screen == Screen.NOTES
	_continue.set_enabled(Save.exists())
	_continue.set_caption("CONTINUE", "" if Save.exists() else "no run yet")
	_pause.queue_redraw()
	_title.queue_redraw()


func pause_game() -> void:
	if screen != Screen.PLAYING:
		return
	_notes_mode = false
	screen = Screen.PAUSED
	_show()


func playing() -> bool:
	return screen == Screen.PLAYING


## What NEW GAME does, as a method rather than as a closure on a button.
##
## A filmed run and a screenshot have to get past the title the same way a thumb
## does. When this only existed inside the button's lambda, the only way in was
## `_new.pressed.emit()`, so the shot scripts written before the shell simply
## never got in: `light_a.png` is a photograph of the title screen filed as
## evidence about tunnel lighting.
func begin_new() -> void:
	screen = Screen.PLAYING
	_show()
	start_new.emit()


## **Unwind ONE layer per press, and never quit without asking.** This is what
## `quit_on_go_back = false` is for, and shipping the setting without this is a
## dead system button.
func go_back() -> void:
	match screen:
		Screen.NOTES:
			_notes_mode = false
			screen = Screen.PAUSED
		Screen.PAUSED:
			_confirm_wipe = false
			screen = Screen.PLAYING if Save.exists() else Screen.TITLE
			if screen == Screen.PLAYING:
				resume.emit()
		Screen.PLAYING:
			pause_game()
			return
		Screen.TITLE:
			# The outermost layer. Still does not quit on its own.
			pass
	_show()


func _apply_audio() -> void:
	_set_bus(GameAudio.MUSIC_BUS, _music)
	_set_bus(GameAudio.SFX_BUS, _sfx)
	_set_bus(GameAudio.UI_BUS, _sfx)


func _set_bus(name: String, v: float) -> void:
	var i := AudioServer.get_bus_index(name)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.005)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))


func set_music(v: float) -> void:
	_music = clampf(v, 0.0, 1.0)
	_apply_audio()
	Save.write_settings(_music, _sfx, _haptics)


func set_sfx(v: float) -> void:
	_sfx = clampf(v, 0.0, 1.0)
	_apply_audio()
	Save.write_settings(_music, _sfx, _haptics)


func toggle_haptics() -> void:
	_haptics = not _haptics
	Save.write_settings(_music, _sfx, _haptics)


func haptics_on() -> bool:
	return _haptics


# ── the two sheets ────────────────────────────────────────────────────────

## The title, drawn over whatever the game is rendering behind it. A live scene
## rather than a painted one: the level you are about to play is already there.
class TitlePlate extends Control:
	var _face: FontFile
	var _mono: FontFile

	func fonts(face: FontFile, mono: FontFile) -> void:
		_face = face
		_mono = mono

	func _draw() -> void:
		# Dark enough to read type over, light enough that the world behind is
		# still visibly a place rather than a backdrop.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.021, 0.028, 0.80), true)
		if _face == null:
			return
		draw_string(_face, Vector2(56.0, size.y * 0.30), "GRAVEWELL",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Hud.INK)
		draw_string(_mono, Vector2(58.0, size.y * 0.30 + 54.0),
			"a graveyard of dead worlds", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Hud.DIM)
		draw_string(_mono, Vector2(58.0, size.y * 0.30 + 96.0),
			"seven cores. one drive. one way out.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Hud.GLOW)
		# Above the buttons, not under them: the version line sat on top of
		# SETTINGS at the bottom of the frame.
		draw_string(_mono, Vector2(58.0, size.y - 470.0),
			"v%s   build %s" % [Changelog.VERSION, BuildStamp.SHA],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Hud.DIM)


## Settings and Notes are the same sheet with a different heading. It is already
## the settings screen, and a second copy of these controls is a second place for
## them to drift.
class PauseSheet extends Control:
	var shell: Shell
	var _face: FontFile
	var _mono: FontFile
	var _scroll := 0.0

	func fonts(face: FontFile, mono: FontFile) -> void:
		_face = face
		_mono = mono
		gui_input.connect(_on_input)

	func _on_input(event: InputEvent) -> void:
		# Translated by hand: a ScrollContainer does not scroll from a finger.
		if event is InputEventScreenDrag or (event is InputEventMouseMotion
				and (event as InputEventMouseMotion).button_mask != 0):
			_scroll = clampf(_scroll - event.relative.y, 0.0, 1400.0)
			queue_redraw()
			accept_event()
		elif event is InputEventScreenTouch or event is InputEventMouseButton:
			if not event.pressed:
				_tap(event.position)
			accept_event()

	func _tap(at: Vector2) -> void:
		if shell == null:
			return
		var y := at.y + _scroll
		# The sliders are wide bars, so the touch target is the whole row.
		if y > 330.0 and y < 406.0:
			shell.set_music(clampf((at.x - 60.0) / maxf(size.x - 120.0, 1.0), 0.0, 1.0))
		elif y > 430.0 and y < 506.0:
			shell.set_sfx(clampf((at.x - 60.0) / maxf(size.x - 120.0, 1.0), 0.0, 1.0))
		elif y > 530.0 and y < 606.0:
			shell.toggle_haptics()
		elif y > 640.0 and y < 716.0:
			# **Erase progress asks first**, and it is nowhere near the sliders.
			if shell._confirm_wipe:
				Save.erase()
				shell._confirm_wipe = false
				shell.screen = Shell.Screen.TITLE
				shell.erase.emit()
				shell._show()
			else:
				shell._confirm_wipe = true
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.021, 0.028, 0.97), true)
		if _face == null or shell == null:
			return
		var y := 130.0 - _scroll
		# An opaque band behind the pinned button, so scrolling text cannot show
		# through the one control that must always be readable.
		var band := Rect2(Vector2(0.0, size.y - 200.0), Vector2(size.x, 200.0))

		draw_string(_face, Vector2(56.0, y), "PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Hud.INK)
		y += 46.0
		# Version, build stamp and patch notes, which he asked for by name.
		draw_string(_mono, Vector2(58.0, y), "v%s   build %s" % [Changelog.VERSION, BuildStamp.SHA],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Hud.DIM)

		y = 360.0 - _scroll
		_slider(Vector2(60.0, y), "MUSIC", shell._music)
		_slider(Vector2(60.0, y + 100.0), "SOUND", shell._sfx)
		_toggle(Vector2(60.0, y + 200.0), "HAPTICS", shell._haptics)

		y += 300.0
		var wipe: String = "TAP AGAIN TO CONFIRM" if shell._confirm_wipe else "ERASE PROGRESS"
		draw_rect(Rect2(Vector2(56.0, y), Vector2(size.x - 112.0, 76.0)),
			Color(0.10, 0.04, 0.04, 0.9), true)
		draw_string(_face, Vector2(76.0, y + 50.0), wipe,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 32,
			Hud.WARN if shell._confirm_wipe else Hud.DIM)

		# What's new, in the player's terms. The build stamp says whether an
		# update landed; this says what it was.
		y += 130.0
		if y > _bottom():
			return
		draw_string(_face, Vector2(56.0, y), "WHAT'S NEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Hud.INK)
		y += 20.0
		for release in Changelog.RELEASES:
			y += 46.0
			if y > size.y + 40.0:
				break
			draw_string(_mono, Vector2(58.0, y), "%s  %s" % [release["version"], release["title"]],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Hud.GLOW)
			for note in release["notes"]:
				y += 34.0
				if y > _bottom():
					break
				# **`draw_string` CLIPS at its width; it does not wrap.** The
				# first version of this sheet cut every patch note off mid-word
				# at the right edge, which is the same complaint that has now
				# arrived in three different screens of this game.
				var lines := _mono.get_multiline_string_size("- %s" % note,
					HORIZONTAL_ALIGNMENT_LEFT, size.x - 150.0, 24)
				draw_multiline_string(_mono, Vector2(74.0, y), "- %s" % note,
					HORIZONTAL_ALIGNMENT_LEFT, size.x - 150.0, 24, -1, Hud.DIM)
				y += maxf(lines.y - 24.0, 0.0)
		_draw_band(band)

	## Where the scrolling content has to stop, so nothing is drawn under the
	## pinned way out. The button never scrolls, so the text must not run beneath
	## it either.
	func _bottom() -> float:
		return size.y - 210.0


	func _slider(at: Vector2, label: String, v: float) -> void:
		var w := size.x - 120.0
		draw_string(_mono, at + Vector2(0, -12.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Hud.DIM)
		draw_rect(Rect2(at, Vector2(w, 46.0)), Color(0.07, 0.075, 0.085, 0.95), true)
		draw_rect(Rect2(at, Vector2(w * v, 46.0)), Hud.GOOD, true)
		draw_rect(Rect2(at, Vector2(w, 46.0)), Hud.EDGE, false, 2.0)
		draw_string(_mono, at + Vector2(w - 70.0, 34.0), "%d%%" % int(v * 100.0),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Hud.INK)

	func _draw_band(band: Rect2) -> void:
		draw_rect(band, Color(0.02, 0.021, 0.028, 1.0), true)


	func _toggle(at: Vector2, label: String, on: bool) -> void:
		var w := size.x - 120.0
		draw_string(_mono, at + Vector2(0, -12.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Hud.DIM)
		draw_rect(Rect2(at, Vector2(w, 46.0)), Color(0.07, 0.075, 0.085, 0.95), true)
		draw_rect(Rect2(at, Vector2(w, 46.0)), Hud.EDGE, false, 2.0)
		draw_string(_face, at + Vector2(18.0, 34.0), "ON" if on else "OFF",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Hud.GOOD if on else Hud.DIM)
