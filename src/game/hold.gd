class_name Hold
extends Node3D

## The Hold: the inside of your own ship, and the only shop in the game.
##
## `techniques/coreward-shop-room-and-hud.md` is the write-up. The lesson in one
## line: **if the player is meant to feel they are somewhere, the somewhere has
## to be geometry.** A panel over the game is a pop-up however it is styled and a
## list is a list however it is styled, and Coreward's shop went panel, styled
## panel, list, room over four rounds of him asking for the same thing:
##
##   "can you update the shop to look more like a separate upgrade screen, like
##   an actual shop or building?"
##   "can you make the shop an actually different screen instead of a pop up
##   screen and make it look more like a space station shop?"
##   "make it look like a full room where upgrades have a physical model
##   associated with it instead of a list of upgrades"
##
## So: a room, with the REAL ship in the middle of it - not a preview, the same
## `Ship` the game flies, so the shop and the world cannot disagree - the upgrade
## parts as physical objects on plinths, and the drive frame on the wall with its
## seven slots visible from the first hour.
##
## **It hides the game entirely.** Leaving half the world visible behind a shop is
## what makes it read as a pop-up.
##
## The room is laid out vertically and the camera pans with a finger, because
## portrait's horizontal cone is about 22 degrees and a rack laid out sideways
## does not fit. Two cases across is the most that reads.

## The camera sits this far from the back wall. At a 46 degree vertical field on
## a 0.46 aspect the visible width is about 0.39 x distance, so 7.0 gives about
## 2.7 units across: two cases with a gap, and no more.
const CAM_DIST := 7.0
const CAM_FOV := 46.0

## How far the camera can pan, in units. Set from the content rather than
## guessed, so a rack that grows cannot scroll off the end of its own travel.
const PAN_TOP := 1.4

const COLS := 2
const CASE_W := 1.18
const CASE_H := 1.05

var sim: Sim

var _cam: Camera3D
var _ship_cradle: Node3D
var _cases: Array[Node3D] = []
var _slots: Array[MeshInstance3D] = []
var _pan := 0.0
var _pan_max := 0.0
var _spin := 0.0

var _plate_font: FontFile
var _mono: FontFile

signal case_pressed(id: String)


func setup(s: Sim, ship: Ship) -> void:
	sim = s
	_plate_font = load("res://assets/fonts/ChakraPetch/ChakraPetch-Bold.ttf")
	_mono = load("res://assets/fonts/ShareTechMono/ShareTechMono-Regular.ttf")

	_cam = Camera3D.new()
	_cam.fov = CAM_FOV
	_cam.near = 0.05
	_cam.far = 60.0
	_cam.position = Vector3(0, 0, CAM_DIST)
	add_child(_cam)

	_build_room()
	_build_drive()

	# The REAL ship, reparented in. Not a model of it: the same node, so a part
	# bolted on here is bolted on out there by construction.
	_ship_cradle = Node3D.new()
	_ship_cradle.position = Vector3(0.0, 0.72, 0.0)
	add_child(_ship_cradle)
	if ship.get_parent() != null:
		ship.get_parent().remove_child(ship)
	ship.position = Vector3.ZERO
	ship.rotation = Vector3.ZERO
	ship.scale = Vector3.ONE * 1.0
	_ship_cradle.add_child(ship)

	# A key light for the room, on the ship's own layer plus the room's, so the
	# rack is lit without the world's lamp having anything to do with it.
	var key := OmniLight3D.new()
	key.position = Vector3(1.2, 1.6, 2.6)
	key.light_energy = 3.0
	key.omni_range = 9.0
	key.light_color = Color(1.0, 0.93, 0.84)
	add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.6, -0.6, 2.2)
	fill.light_energy = 1.1
	fill.omni_range = 8.0
	fill.light_color = Color(0.55, 0.68, 0.85)
	add_child(fill)


func _build_room() -> void:
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.085, 0.088, 0.098)
	wall_mat.roughness = 0.92
	wall_mat.metallic = 0.05
	var rock_n := load("res://assets/textures/Rock035/Rock035_1K-JPG_NormalGL.jpg")
	if rock_n != null:
		wall_mat.normal_enabled = true
		wall_mat.normal_texture = rock_n
		wall_mat.normal_scale = 0.7
		wall_mat.uv1_scale = Vector3(3.0, 3.0, 1.0)

	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(9.0, 22.0, 0.4)
	back.mesh = bm
	back.material_override = wall_mat
	back.position = Vector3(0, 0, -1.1)
	add_child(back)

	# Ribs, so the wall reads as the inside of a hull rather than as a backdrop.
	var rib_mat := StandardMaterial3D.new()
	rib_mat.albedo_color = Color(0.14, 0.145, 0.16)
	rib_mat.roughness = 0.6
	rib_mat.metallic = 0.55
	for i in range(-8, 9):
		var rib := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(6.4, 0.07, 0.16)
		rib.mesh = rm
		rib.material_override = rib_mat
		rib.position = Vector3(0, float(i) * 1.35, -0.85)
		add_child(rib)


## The drive frame: seven slots, one per world class, filled by the cores you
## carried out. **It is furniture you walk past**, visible from the first hour,
## which is the whole difference between a goal and a progress bar. Coreward's
## version of this existed and he never once reached it, because it lived past a
## wall an hour in.
func _build_drive() -> void:
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.17, 0.175, 0.19)
	frame_mat.roughness = 0.45
	frame_mat.metallic = 0.8

	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.72
	tm.outer_radius = 0.84
	# `rings` is the tessellation, not the number of slots. At 7 it is a lumpy
	# heptagon of black blobs rather than a ring, which is what the first
	# screenshot showed.
	tm.rings = 48
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = frame_mat
	ring.position = Vector3(0, 2.30, -0.55)
	add_child(ring)

	for i in range(7):
		var a := TAU * float(i) / 7.0 - PI * 0.5
		var slot := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.17, 0.17, 0.13)
		slot.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.09, 0.09, 0.10)
		m.roughness = 0.5
		m.metallic = 0.3
		m.emission_enabled = true
		m.emission = Color(1.0, 0.58, 0.22)
		m.emission_energy_multiplier = 0.0
		slot.material_override = m
		slot.position = Vector3(cos(a) * 0.78, 2.30 + sin(a) * 0.78, -0.5)
		slot.rotation.z = a + PI * 0.5
		add_child(slot)
		_slots.append(slot)

	# **Centred, and sized from the pixels it will occupy.** Left-aligned from a
	# centre position it ran off the right of the frame, which is the exact
	# "some of the words are cut off" complaint arriving in a new room. At this
	# camera the visible width is about 2.7 units, so the text has to fit inside
	# that before anything else about it matters.
	var t := _label(Vector3(0, 1.30, -0.5), "GRAVEWELL DRIVE", 0.115, Hud.DIM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Build the rack from the simulation's own rows, so the room lays out from the
## COUNT rather than from a fixed table. Coreward's shop went from ten cases to
## fifteen without the room changing and the report was that words were cut off
## and it felt cluttered.
func refresh() -> void:
	for c in _cases:
		c.queue_free()
	_cases.clear()

	var rows := sim.rack()
	for i in range(rows.size()):
		var row := rows[i]
		var col := i % COLS
		var line := i / COLS
		var x := (float(col) - float(COLS - 1) * 0.5) * CASE_W
		var y := -0.30 - float(line) * CASE_H
		_cases.append(_build_case(row, Vector3(x, y, -0.55)))

	var lines := int(ceil(float(rows.size()) / float(COLS)))
	_pan_max = maxf(0.0, float(lines) * CASE_H - 1.6)

	for i in range(_slots.size()):
		var m: StandardMaterial3D = _slots[i].material_override
		# A slot that is filled GLOWS, and one that is not is dark metal. The
		# collection is a thing you look at, not a number that will look small
		# next week.
		m.emission_energy_multiplier = 2.4 if sim.has_core(i) else 0.0


func _build_case(row: Dictionary, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = at
	add_child(node)

	var plinth := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(CASE_W - 0.10, CASE_H - 0.14, 0.30)
	plinth.mesh = pm
	var mat := StandardMaterial3D.new()
	# Only refusal is grey. A sealed case is dark and cold; an affordable one has
	# a lit edge; a maxed one is bright metal with nothing to buy.
	if bool(row["sealed"]):
		mat.albedo_color = Color(0.055, 0.056, 0.062)
	elif bool(row["maxed"]):
		mat.albedo_color = Color(0.16, 0.165, 0.175)
	elif bool(row["afford"]):
		mat.albedo_color = Color(0.13, 0.15, 0.155)
	else:
		mat.albedo_color = Color(0.085, 0.088, 0.095)
	mat.roughness = 0.7
	mat.metallic = 0.35
	plinth.material_override = mat
	node.add_child(plinth)

	# **The part itself, as an object.** An upgrade you cannot see is bought on
	# trust, and he asked twice for the parts to be physical and for the ship to
	# change when they are fitted.
	var part := MeshInstance3D.new()
	part.mesh = _part_mesh(String(row["id"]))
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.42, 0.44, 0.47) if not bool(row["sealed"]) \
		else Color(0.11, 0.11, 0.12)
	pmat.roughness = 0.42
	pmat.metallic = 0.6
	part.material_override = pmat
	part.position = Vector3(-CASE_W * 0.26, 0.03, 0.22)
	part.scale = Vector3.ONE * 0.5
	node.add_child(part)

	# Labels are sized by the pixels they will occupy, not by the words wanted.
	# At this camera a case is about 190 px wide, so the name gets six or seven
	# characters and the rest goes underneath at half the size.
	var name_text: String = row["name"]
	if bool(row["sealed"]):
		_label(at + Vector3(0.10, 0.20, 0.20), "SEALED", 0.085, Hud.DIM, node)
		_label(at + Vector3(0.10, 0.04, 0.20), "%d m" % int(row["gate"]), 0.075, Hud.DIM, node)
	else:
		_label(at + Vector3(0.10, 0.22, 0.20), name_text, 0.10, Hud.INK, node)
		var pips := ""
		for i in range(int(row["max"])):
			pips += "|" if i < int(row["level"]) else "."
		_label(at + Vector3(0.10, 0.08, 0.20), pips, 0.085, Hud.GOOD, node)
		if bool(row["maxed"]):
			_label(at + Vector3(0.10, -0.08, 0.20), "MAX", 0.075, Hud.DIM, node)
		else:
			var unit := "fil" if bool(row["filament"]) else "cr"
			var cost := "%d %s" % [int(row["cost"]), unit]
			_label(at + Vector3(0.10, -0.08, 0.20), cost, 0.075,
				Hud.GLOW if bool(row["afford"]) else Hud.DIM, node)
	node.set_meta("id", String(row["id"]))
	node.set_meta("afford", bool(row["afford"]))
	return node


## One primitive per upgrade, chosen so the silhouettes differ. Repainting a
## thirty-pixel part per tier is invisible; a different SHAPE is not.
func _part_mesh(id: String) -> Mesh:
	match id:
		"drill":
			var m := CylinderMesh.new()
			m.top_radius = 0.01
			m.bottom_radius = 0.16
			m.height = 0.34
			m.radial_segments = 6
			return m
		"hold":
			var m := BoxMesh.new()
			m.size = Vector3(0.30, 0.24, 0.22)
			return m
		"power":
			var m := CylinderMesh.new()
			m.top_radius = 0.13
			m.bottom_radius = 0.13
			m.height = 0.32
			m.radial_segments = 8
			return m
		"thrust":
			var m := CylinderMesh.new()
			m.top_radius = 0.16
			m.bottom_radius = 0.07
			m.height = 0.30
			m.radial_segments = 6
			return m
		"lamp":
			var m := PrismMesh.new()
			m.size = Vector3(0.28, 0.26, 0.20)
			return m
		"seal":
			var m := TorusMesh.new()
			m.inner_radius = 0.10
			m.outer_radius = 0.17
			m.rings = 6
			return m
		"bore":
			var m := PrismMesh.new()
			m.size = Vector3(0.22, 0.34, 0.20)
			return m
	var s := BoxMesh.new()
	s.size = Vector3(0.24, 0.24, 0.24)
	return s


## A label that BELONGS to the case and turns with it, rather than HTML hovering
## in front of the room. Sized in world units, which is what makes the pixel
## arithmetic above meaningful.
func _label(at: Vector3, text: String, size: float, col: Color,
		parent: Node3D = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _plate_font
	l.font_size = 96
	l.pixel_size = size / 96.0
	l.modulate = col
	l.outline_size = 18
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.position = at if parent == null else at - parent.position
	if parent == null:
		add_child(l)
	else:
		parent.add_child(l)
	return l


# ── the frame ─────────────────────────────────────────────────────────────

func tick(dt: float) -> void:
	# An idle world reads as a screenshot, so the ship turns slowly on its
	# cradle and the frame is never a still.
	_spin += dt * 0.32
	_ship_cradle.rotation.y = sin(_spin) * 0.55
	_ship_cradle.position.y = 0.55 + sin(_spin * 1.7) * 0.02
	_cam.position.y = lerpf(_cam.position.y, _pan, SimUtil.smooth(10.0, dt))


## Scroll from a finger. The camera pans; the room does not move, because a room
## that slides is a list with a parallax effect.
func pan(delta_px: float, viewport_h: float) -> void:
	var units := delta_px / maxf(viewport_h, 1.0) * 6.0
	_pan = clampf(_pan + units, -_pan_max, PAN_TOP)


## What was tapped, in viewport coordinates, or "" for nothing.
##
## A ray from the camera, so the hit box IS the geometry. Anything else is a
## second source of truth for where a case is.
func pick(at: Vector2) -> String:
	var from := _cam.project_ray_origin(at)
	var dir := _cam.project_ray_normal(at)
	var best := ""
	var best_t := 1.0e9
	for c in _cases:
		# Cases are axis-aligned slabs, so a plane crossing plus a rect test is
		# exact and needs no physics server in the scene.
		var pz: float = c.position.z + 0.15
		if absf(dir.z) < 1e-6:
			continue
		var t := (pz - from.z) / dir.z
		if t < 0.0 or t > best_t:
			continue
		var p := from + dir * t
		if absf(p.x - c.position.x) > CASE_W * 0.5:
			continue
		if absf(p.y - c.position.y) > CASE_H * 0.5:
			continue
		best_t = t
		best = String(c.get_meta("id"))
	return best
