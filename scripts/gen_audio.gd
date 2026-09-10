extends SceneTree

## Generate the score and the ambient beds into `assets/audio/`, ONCE, at build
## time.
##
##   godot --headless --path . --script res://scripts/gen_audio.gd
##
## **Generated at build time and committed, never synthesised per frame.**
## GDScript synthesis at runtime costs seconds of black screen on a phone, and
## the output is identical every run, so there is nothing to gain by paying for
## it on the device.
##
## ## Why this is generated at all
##
## `ASSETS.md`: sample where a sample is better, synthesise where the sound must
## answer the game. The impacts and the clicks are Kenney samples, because a
## recorded knock beats a sine every time. The BED is generated because it has to
## crossfade on depth, and a mood arc is a crossfade on a gameplay quantity
## rather than a playlist.
##
## ## His one recorded outright dislike, and what it means here
##
## "The music has random higher pitch beeps that I dont like."
##
## The cause in Coreward was a melody picking notes at random from a scale.
## Musically valid, and it still sounded like beeps, because **without repetition
## there is no phrase for the ear to latch onto** and isolated notes register as
## UI noise. A fast attack on a high sine is also literally the shape of a
## notification sound.
##
## So, three rules, all obeyed below and all of them checkable by reading the
## code rather than by listening:
##
##   1. A WRITTEN theme: a fixed sequence of degrees over a fixed progression,
##      repeated, with a cadence. Nothing here is chosen at random.
##   2. Every note has a slow attack and a long release, and nothing sits in the
##      register where a sine gets shrill.
##   3. A pulse. A texture reads as ambience and only a rhythm reads as movement.

const RATE := 22050
const OUT := "res://assets/audio/"

## A minor. i - VI - III - VII, which is the progression Coreward's rewrite used
## after the complaint and which he did not object to again.
const ROOT := 55.0                      ## A1, well below where a sine gets shrill
const PROGRESSION: Array[int] = [0, 8, 3, 10]

## The theme, in scale degrees, as a WRITTEN phrase. Two bars answered by two
## bars, and the answer resolves. -1 is a rest.
const THEME: Array[int] = [
	0, -1, 2, 3, -1, 2, 0, -1,
	3, -1, 4, 5, -1, 4, 3, -1,
	5, -1, 4, 3, -1, 2, 3, -1,
	2, -1, 0, -1, -1, -1, -1, -1,
]
const MINOR: Array[int] = [0, 2, 3, 5, 7, 8, 10]

const BEAT := 0.5                       ## 120 bpm, a tempo you can nod to
const BARS := 16.0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_write("bed_shallow.wav", _bed(0.0))
	_write("bed_deep.wav", _bed(1.0))
	_write("theme.wav", _theme())
	print("audio written to %s" % OUT)
	quit(0)


## The ambient bed: a drone, filtered air, and a slow swell. `deep` moves it from
## cold and open to close and heavy, so crossfading between the two IS the mood
## arc and there is no playlist anywhere.
##
## The layer that LEAVES does more than any that arrives, so the shallow bed
## carries the open air and the deep one takes it away.
func _bed(deep: float) -> PackedFloat32Array:
	var n := int(BEAT * 4.0 * BARS * float(RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	var air := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260910          ## deterministic: the file must not change per run
	for i in range(n):
		var t := float(i) / float(RATE)
		var v := 0.0
		# The drone: the root and a fifth, detuned a hair so they beat slowly
		# against each other rather than sitting still.
		v += sin(TAU * ROOT * 0.5 * t) * 0.22
		v += sin(TAU * ROOT * 0.5 * 1.4983 * t) * 0.10
		v += sin(TAU * ROOT * 0.25 * t) * (0.10 + 0.14 * deep)
		# Filtered air. A one-pole lowpass over noise, closing as it gets deeper,
		# which is the same thing the density does to the lamp.
		var cut: float = 0.06 - 0.042 * deep
		air += (rng.randf() * 2.0 - 1.0 - air) * cut
		v += air * (0.16 - 0.06 * deep)
		# A slow swell, so a still frame is not a still sound either.
		v *= 0.75 + 0.25 * sin(TAU * t / 11.0)
		out[i] = v * 0.55
	_fade_loop(out)
	return out


## The theme. Written, repeated, and played only every other cycle so silence is
## part of it.
func _theme() -> PackedFloat32Array:
	var n := int(BEAT * float(THEME.size()) * 2.0 * float(RATE))
	var out := PackedFloat32Array()
	out.resize(n)

	for step in range(THEME.size()):
		var degree: int = THEME[step]
		if degree < 0:
			continue
		var chord: int = PROGRESSION[(step / 8) % PROGRESSION.size()]
		var semis: int = chord + MINOR[degree % MINOR.size()] + 12 * (degree / MINOR.size())
		var freq: float = ROOT * 2.0 * pow(2.0, float(semis) / 12.0)
		_place(out, float(step) * BEAT, freq, 1.6, 0.20)
		# The bass answers on the bar, which is the pulse. A texture reads as
		# ambience; only a rhythm reads as movement.
		if step % 4 == 0:
			_place(out, float(step) * BEAT, ROOT * pow(2.0, float(chord) / 12.0), 1.9, 0.26)

	_fade_loop(out)
	return out


## One note. **A 0.28 s attack and a long release**, because a fast attack on a
## high sine is the shape of a notification sound, which is exactly what the
## complaint was about.
func _place(buf: PackedFloat32Array, at: float, freq: float, dur: float, amp: float) -> void:
	var start := int(at * float(RATE))
	var count := int(dur * float(RATE))
	var attack := 0.28 * float(RATE)
	for i in range(count):
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / float(RATE)
		var env: float = minf(float(i) / attack, 1.0) * exp(-t * 1.9)
		var v := sin(TAU * freq * t) * 0.62
		v += sin(TAU * freq * 2.0 * t) * 0.18      ## an octave, for body
		v += sin(TAU * freq * 3.0 * t) * 0.07      ## a fifth above that, for air
		buf[idx] = clampf(buf[idx] + v * env * amp, -1.0, 1.0)


## Crossfade the tail into the head so the file loops without a click. A loop
## with a seam in it is heard as a click every cycle and read as a bug.
func _fade_loop(buf: PackedFloat32Array) -> void:
	var fade := int(0.35 * float(RATE))
	for i in range(fade):
		var k := float(i) / float(fade)
		var head := buf[i]
		var tail := buf[buf.size() - fade + i]
		buf[i] = head * k + tail * (1.0 - k)


## 16-bit mono PCM. Written by hand because it is thirty lines and deterministic,
## and because a dependency for this would be a dependency forever.
func _write(name: String, samples: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)

	var f := FileAccess.open(OUT + name, FileAccess.WRITE)
	if f == null:
		push_error("cannot write %s" % name)
		return
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)                    ## PCM
	f.store_16(1)                    ## mono
	f.store_32(RATE)
	f.store_32(RATE * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()
	print("  %s  %.1f s  %d KB" % [name, float(samples.size()) / float(RATE), data.size() / 1024])
