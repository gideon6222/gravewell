class_name GameAudio
extends Node

## Every sound the game makes.
##
## Two halves, and `ASSETS.md` decides which is which: **sample where a sample is
## better, synthesise where the sound must answer the game.** The impacts and the
## clicks are Kenney recordings, because a real knock beats a sine every time.
## The bed and the theme are generated, because they crossfade on depth and a
## recording cannot.
##
## ## The reverb comes from the light solver
##
## The flood already computes how open the space around the ship is, in order to
## decide what the lamp reaches. The reverb reads **the same number**: a tight
## shaft is dry and close, a cavern is enormous. One quantity, two uses, and no
## second notion of "how big is this room" that could disagree with the first.
##
## ## The muffle comes from the air
##
## `Tuning.density_at` drives the fog, the lamp reach, the drag and the hull
## load, and it drives a lowpass here too. The deep sounds muffled because it IS
## denser, from the same number that makes it look it.

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const UI_BUS := "UI"

## Round-robin pools. One restarted player cuts its own tail off, which on a
## drill firing several times a second is the difference between a machine and a
## stutter.
const POOL := 5

## Pitch jitter on repeats. Without it the twentieth identical impact reads as a
## loop rather than as a sound.
const JITTER := 0.12

var _sfx: Dictionary = {}            ## name -> Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _next := 0

var _bed_shallow: AudioStreamPlayer
var _bed_deep: AudioStreamPlayer
var _theme: AudioStreamPlayer

## **The drill is a LOOP, not a shot per bite.**
##
## It used to fire a one-shot every time the drill removed something, rate
## limited to twelve a second. Under the old model a bite was an event a second
## or two apart and that read fine; the plow removes something on every single
## tick, and a one-shot per tick is a machine gun. The research on continuous
## drilling says the same thing about haptics: one persistent effect that gets
## modulated, never a retrigger per hit.
##
## So: one looping player whose volume, pitch and filter all track `dig_load`,
## and short one-shot grit on top at a rate proportional to the same number, so
## the density of clatter is what says how hard the work is.
var _drill_loop: AudioStreamPlayer
var _drill_level := 0.0              ## smoothed dig load, 0..1
var _grit_wait := 0.0
var _rng := RandomNumberGenerator.new()

var _reverb: AudioEffectReverb
var _lowpass: AudioEffectLowPassFilter


func _ready() -> void:
	_rng.seed = 4242
	_make_buses()
	_load_sfx()
	_make_players()
	_make_music()


## Buses `Master / Music / SFX / UI`, so the options screen can set each
## independently and a mute means what it says.
func _make_buses() -> void:
	for name in [MUSIC_BUS, SFX_BUS, UI_BUS]:
		if AudioServer.get_bus_index(name) >= 0:
			continue
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")

	# The reverb and the lowpass live on the SFX bus, because they describe the
	# SPACE the player is in, and the music is not in that space.
	var sfx := AudioServer.get_bus_index(SFX_BUS)
	_reverb = AudioEffectReverb.new()
	_reverb.room_size = 0.4
	_reverb.wet = 0.15
	_reverb.dry = 0.9
	AudioServer.add_bus_effect(sfx, _reverb)

	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 12000.0
	AudioServer.add_bus_effect(sfx, _lowpass)


func _load_sfx() -> void:
	# Named by what they DO in this game, not by what the pack called them, so a
	# swapped sample is one line here and nothing anywhere else.
	_add("drill", "res://assets/kenney/impact-sounds/Audio/impactMining_%03d.ogg", 4)
	_add("break", "res://assets/kenney/impact-sounds/Audio/impactPlate_light_%03d.ogg", 4)
	_add("ore", "res://assets/kenney/impact-sounds/Audio/impactPlate_medium_%03d.ogg", 4)
	_add("hull", "res://assets/kenney/impact-sounds/Audio/impactMetal_heavy_%03d.ogg", 4)
	_add("ice", "res://assets/kenney/impact-sounds/Audio/footstep_snow_%03d.ogg", 5)
	_add("click", "res://assets/kenney/interface-sounds/Audio/click_%03d.ogg", 4)
	_add("confirm", "res://assets/kenney/interface-sounds/Audio/confirmation_%03d.ogg", 3)
	_add("deny", "res://assets/kenney/interface-sounds/Audio/error_%03d.ogg", 3)
	_add("uplink", "res://assets/kenney/interface-sounds/Audio/open_%03d.ogg", 3)


func _add(name: String, pattern: String, count: int) -> void:
	var list: Array[AudioStream] = []
	for i in range(count):
		var path := pattern % i
		if not ResourceLoader.exists(path):
			continue
		var s: AudioStream = load(path)
		if s != null:
			list.append(s)
	if not list.is_empty():
		_sfx[name] = list


func _make_players() -> void:
	for _i in range(POOL):
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_players.append(p)


func _make_music() -> void:
	# The drill loop rides the SFX bus, not the music bus: it is the game making a
	# sound, and it has to duck with the sound effects slider rather than with the
	# score.
	_drill_loop = _music_player("res://assets/audio/drill.wav")
	if _drill_loop != null:
		_drill_loop.bus = SFX_BUS
		_drill_loop.volume_db = -60.0
		_drill_loop.stop()

	_bed_shallow = _music_player("res://assets/audio/bed_shallow.wav")
	_bed_deep = _music_player("res://assets/audio/bed_deep.wav")
	_theme = _music_player("res://assets/audio/theme.wav")
	if _bed_deep != null:
		_bed_deep.volume_db = -60.0
	if _theme != null:
		_theme.volume_db = -14.0


func _music_player(path: String) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var p := AudioStreamPlayer.new()
	var s: AudioStream = load(path)
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = (s as AudioStreamWAV).data.size() / 2
	p.stream = s
	p.bus = MUSIC_BUS
	add_child(p)
	# **Start playback from `_ready`**, never from `_enter_tree` or right after
	# add_child, or every player logs "Playback can only happen when a node is
	# inside the scene tree".
	p.play()
	return p


# ── one-shots ─────────────────────────────────────────────────────────────

## Play a named sound with pitch jitter, through a round-robin pool.
func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _sfx.has(name):
		return
	var list: Array = _sfx[name]
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = list[_rng.randi() % list.size()]
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + _rng.randf_range(-JITTER, JITTER))
	p.play()


func click(ok: bool = true) -> void:
	if not _sfx.has("click"):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.bus = UI_BUS
	var list: Array = _sfx["confirm" if ok else "deny"] if _sfx.has("confirm") else _sfx["click"]
	p.stream = list[_rng.randi() % list.size()]
	p.volume_db = -4.0
	p.pitch_scale = 1.0 + _rng.randf_range(-JITTER, JITTER)
	p.play()
	p.bus = SFX_BUS


# ── the frame ─────────────────────────────────────────────────────────────

## Drive the space and the mood from the simulation's own numbers.
func tick(sim: Sim, dt: float) -> void:
	var depth := sim.flight.depth()

	# **The reverb reads the light solver's openness.** A tight shaft is dry and
	# close; a cavern is enormous. One quantity, two uses.
	var cell := Vector2i(int(roundf(sim.flight.pos.x)), int(roundf(depth)))
	var open := sim.world.openness(cell.x, cell.y, 5)
	if _reverb != null:
		_reverb.room_size = lerpf(_reverb.room_size, 0.25 + open * 0.72,
			SimUtil.smooth(1.5, dt))
		_reverb.wet = lerpf(_reverb.wet, 0.10 + open * 0.34, SimUtil.smooth(1.5, dt))

	# The muffle reads the air, from the same number that thickens the fog.
	var density := Tuning.density_at(depth)
	if _lowpass != null:
		var want: float = clampf(13000.0 / (1.0 + density * 0.55), 1400.0, 13000.0)
		_lowpass.cutoff_hz = lerpf(_lowpass.cutoff_hz, want, SimUtil.smooth(1.2, dt))

	# **The mood arc is a crossfade on a gameplay quantity, never a playlist.**
	# Depth is the quantity, and the layer that LEAVES does more than any that
	# arrives: the open air of the shallow bed going is what makes the deep feel
	# closed in.
	var deepness: float = clampf(depth / float(Tuning.CORE_DEPTH), 0.0, 1.0)
	# Places arrive slowly. An alarm would snap in; this is a place.
	if _bed_shallow != null:
		_bed_shallow.volume_db = lerpf(_bed_shallow.volume_db,
			linear_to_db(maxf(1.0 - deepness * 1.15, 0.0001)) - 6.0, SimUtil.smooth(0.7, dt))
	if _bed_deep != null:
		_bed_deep.volume_db = lerpf(_bed_deep.volume_db,
			linear_to_db(maxf(deepness, 0.0001)) - 4.0, SimUtil.smooth(0.7, dt))

	# The theme thins out under pressure rather than getting louder, so the
	# quietest the game ever is is the moment it is most dangerous.
	if _theme != null:
		var pressure: float = clampf(sim.pressure_rate() / 3.0, 0.0, 1.0)
		var want_db: float = -14.0 - pressure * 22.0
		if sim.phase == Sim.Phase.EXTRACTION:
			want_db = -60.0                ## silence, deliberately, for the climb
		_theme.volume_db = lerpf(_theme.volume_db, want_db, SimUtil.smooth(0.9, dt))

	_drill(sim, dt)


## **One continuous drill, modulated.**
##
## `sim.dig_load` is 0 when not drilling and rises with the hardness of what is
## under the head, and every channel in the game that sells the work reads that
## same number: this, the particles, the haptics and the shake.
##
## Loud, low and slow is heavy work; quiet, high and fast is fluffy dirt. The
## level is smoothed rather than assigned, because the load can step the moment
## the head crosses a band boundary and a step in a loop's volume is a click.
func _drill(sim: Sim, dt: float) -> void:
	var want: float = sim.dig_load if sim.phase == Sim.Phase.DESCENT else 0.0
	var digging := want > 0.0
	_drill_level = lerpf(_drill_level, 1.0 if digging else 0.0, SimUtil.smooth(9.0, dt))
	if _drill_loop != null:
		# Under a whisper it is switched off rather than left running at -60 dB,
		# so a parked ship is genuinely silent.
		if _drill_level < 0.02:
			if _drill_loop.playing:
				_drill_loop.stop()
		else:
			if not _drill_loop.playing:
				_drill_loop.play()
			_drill_loop.volume_db = linear_to_db(_drill_level * (0.35 + want * 0.65)) - 7.0
			# Heavier material drags the pitch down. The range is wide on purpose:
			# this is the one channel that is audible with the phone in a pocket.
			_drill_loop.pitch_scale = lerpf(1.25, 0.62, want)

	# Grit on top, at a rate that falls as the material gets harder: loose dirt
	# rattles constantly, dense rock gives a few sharp chips.
	if not digging:
		return
	_grit_wait -= dt
	if _grit_wait > 0.0:
		return
	_grit_wait = lerpf(0.07, 0.26, want)
	play("drill", lerpf(-15.0, -8.0, want), lerpf(1.35, 0.7, want))


func broke(is_ore: bool, brittle: bool) -> void:
	if brittle:
		play("ice", -5.0, 0.85)
	play("ore" if is_ore else "break", -6.0)


func hull_hit() -> void:
	play("hull", -3.0, 0.8)


func uplinked() -> void:
	play("uplink", -3.0, 0.9)
