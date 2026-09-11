class_name Save
extends RefCounted

## Progress on disk, and settings beside it in their own file.
##
## Deliberately inside the simulation wall. It touches `FileAccess` and nothing
## else about the engine: no Node, no Viewport, no input event, no frame. That is
## what lets a headless test round-trip a save without standing a game up, and it
## is the same place `save.gd` sits in the sibling Godot games.
##
## ## Two files, on purpose
##
## **Preferences are not progress.** `POLISH.md` is explicit: settings get their
## own file, and "erase progress" sitting next to the sound switches only holds
## if the two are actually separate. Wiping a save must not silently reset the
## volume, and changing the volume must not touch the save.

const PROGRESS := "user://progress.json"
const SETTINGS := "user://settings.cfg"

## Bumped when the shape changes. A load that does not recognise the version
## starts fresh rather than half-reading an old one into a new game.
const VERSION := 2

## **A one-way latch.** Erasing progress has to survive the save that fires on
## the way out: without this, wiping progress and then backgrounding the app
## writes the wiped-in-memory state back over nothing, or worse, writes the
## pre-wipe state back if anything still holds it. `POLISH.md` names this exact
## failure.
static var _erased := false


static func write(sim: Sim) -> void:
	if _erased:
		return
	var f := FileAccess.open(PROGRESS, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"v": VERSION,
		"credits": sim.credits,
		"filament": sim.filament,
		"cores": sim.cores,
		"record": sim.record,
		"planet": sim.planet,
		"class": sim.world.class_id,
		"levels": sim.levels,
		"bought": sim.bought,
		"keepsakes": sim.keepsakes,
		"logs": sim.logs,
	}))
	f.close()


## True if a save was read. The caller starts a fresh game if not, which is also
## what makes CONTINUE greyed rather than hidden on a first run: an absent button
## tells a new player nothing, a greyed one says where their game will be.
static func read(sim: Sim) -> bool:
	if _erased or not FileAccess.file_exists(PROGRESS):
		return false
	var f := FileAccess.open(PROGRESS, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	if int(d.get("v", 0)) != VERSION:
		return false

	sim.credits = float(d.get("credits", 0.0))
	sim.filament = int(d.get("filament", 0))
	sim.cores = int(d.get("cores", 0))
	sim.record = float(d.get("record", 0.0))
	sim.planet = int(d.get("planet", 1))
	sim.bought = int(d.get("bought", 0))
	# **The things you keep.** A keepsake and a log fragment are not currency and
	# not progress on a ladder: they are the reason to have gone, so losing them
	# to a save format change would lose the only permanent thing in the game.
	sim.keepsakes = []
	for k in (d.get("keepsakes", []) as Array):
		sim.keepsakes.append(int(k))
	sim.logs = []
	for k in (d.get("logs", []) as Array):
		sim.logs.append(int(k))
	# The ladder comes back as a Dictionary of Variants; the levels have to be
	# ints or every `mult()` lookup indexes an array with a float.
	sim.levels = {}
	var raw: Dictionary = d.get("levels", {})
	for k in raw.keys():
		sim.levels[String(k)] = int(raw[k])
	# The world is rebuilt from its seed and class rather than stored, which is
	# the whole point of generation being a pure seeded hash: a save is nine
	# numbers, not a planet.
	sim.world = World.new(sim.planet, int(d.get("class", 0)))
	sim.flight = Flight.new(sim.world)
	return true


static func exists() -> bool:
	return not _erased and FileAccess.file_exists(PROGRESS)


## Erase, and latch it so nothing writes the old state back on the way out.
static func erase() -> void:
	_erased = true
	if FileAccess.file_exists(PROGRESS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS))


## For tests: clear the latch so a fresh fixture can save again. Never called by
## the game, because in the game the latch is meant to be one-way for the rest of
## the session.
static func _reset_latch_for_tests() -> void:
	_erased = false


# ── settings, in their own file ───────────────────────────────────────────

static func write_settings(music: float, sfx: float, haptics: bool) -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "music", music)
	c.set_value("audio", "sfx", sfx)
	c.set_value("feel", "haptics", haptics)
	c.save(SETTINGS)


## Returns {music, sfx, haptics} with sensible defaults, so a missing file is a
## first run rather than a silent game.
static func read_settings() -> Dictionary:
	var out := {"music": 0.8, "sfx": 1.0, "haptics": true}
	var c := ConfigFile.new()
	if c.load(SETTINGS) != OK:
		return out
	out["music"] = float(c.get_value("audio", "music", out["music"]))
	out["sfx"] = float(c.get_value("audio", "sfx", out["sfx"]))
	out["haptics"] = bool(c.get_value("feel", "haptics", out["haptics"]))
	return out
