class_name Ship
extends Node3D

## The drill ship, modelled by hand.
##
## **This is a milestone rather than an import because there is nothing to
## import.** The asset scout searched Poly Pizza and Poly Haven for a photoreal
## CC0 ship or drone and every result was flat-shaded low-poly, which is the
## exact "cartoonie" failure mode and the wrong style family beside photoreal
## rock. `ASSETS.md` puts a thing that is 120 to 200 px and permanently on screen
## firmly on the import side of the rule; the rule assumes something exists to
## import, and here nothing does.
##
## So it is built from prisms, and every choice below is a rule from `CRAFT.md`:
##
## - **No spheres.** "A sphere reads as a bubble at any size. Prisms with hard
##   corners catch light on one face and not the next." Coreward's cockpit was a
##   sphere and the report was that the ship looked "bubbly and cartoonish".
## - **Upgrades bolt on and are visible in play.** He asked for this twice, in
##   two different sessions: "when you upgrade thrusters and starts to change the
##   way they look, it also changes the way that they look when you're actually
##   playing the game". The mount points exist from this milestone even though
##   nothing hangs on them until M7.
## - **The nose points where it is digging.** His words exactly.
##
## The whole rig sits on render layer 2 and is lit by its own key light, because
## the world's light is an upgrade and the hull must not brighten when the player
## buys one.

const LAYER := 2

## Roughly a metre of ship inside a 0.76-metre collision box, so it reads as
## bigger than its hitbox, which is forgiving in the player's favour.
const BODY := Vector3(0.62, 0.46, 0.40)

var drill: Node3D
var mounts: Dictionary = {}      ## upgrade slots, by name, empty until M7

var _drill_head: MeshInstance3D
var _spin := 0.0
var _nozzles: Array[MeshInstance3D] = []
var _hot: StandardMaterial3D


func _init() -> void:
	# **Low metallic on purpose.** A metal with nothing to reflect is black plus
	# hotspots: it needs an environment, and this scene is a hole in the ground
	# with a background colour and no sky. At 0.55 metallic the hull rendered as
	# a white blob with no readable shape at all. Roughness and the prism facets
	# do the work instead.
	var steel := _mat(Color(0.22, 0.23, 0.25), 0.66, 0.12)
	var dark := _mat(Color(0.10, 0.105, 0.115), 0.82, 0.06)
	var brass := _mat(Color(0.30, 0.245, 0.145), 0.52, 0.22)
	_hot = _mat(Color(0.35, 0.16, 0.08), 0.55, 0.20)
	_hot.emission_enabled = true
	_hot.emission = Color(1.0, 0.42, 0.14)
	_hot.emission_energy_multiplier = 0.0

	# The hull: a slab with the corners taken off rather than a box, so the
	# lamp catches three different planes as the ship turns.
	_add(_prism(BODY, 6), steel, Vector3.ZERO, Vector3(0, 0, PI * 0.5))

	# The cockpit: a wedge, flat-topped, angled back. Deliberately NOT a dome.
	var canopy := _prism(Vector3(0.26, 0.16, 0.30), 4)
	_add(canopy, brass, Vector3(0.0, 0.10, 0.16), Vector3(0.25, 0, PI * 0.5))

	# The drill assembly, at the nose. Its own node so it can spin without
	# turning the ship with it.
	drill = Node3D.new()
	drill.position = Vector3(0.0, -BODY.y * 0.5 - 0.10, 0.0)
	add_child(drill)

	var collar := CylinderMesh.new()
	collar.top_radius = 0.17
	collar.bottom_radius = 0.20
	collar.height = 0.10
	collar.radial_segments = 8
	_add(collar, dark, Vector3(0, 0.06, 0), Vector3.ZERO, drill)

	# The bit itself: a cone with few enough sides to read as faceted metal.
	var bit := CylinderMesh.new()
	bit.top_radius = 0.005
	bit.bottom_radius = 0.17
	bit.height = 0.26
	bit.radial_segments = 6
	_drill_head = _add(bit, steel, Vector3(0, -0.12, 0), Vector3(PI, 0, 0), drill)

	# Thrusters: two stubs at the tail whose nozzles light with the throttle, so
	# thrust is a thing you can SEE rather than a number.
	for side in [-1.0, 1.0]:
		var pod := CylinderMesh.new()
		pod.top_radius = 0.085
		pod.bottom_radius = 0.10
		pod.height = 0.22
		pod.radial_segments = 6
		_add(pod, dark, Vector3(side * 0.20, BODY.y * 0.5 + 0.02, 0.0))
		var nozzle := CylinderMesh.new()
		nozzle.top_radius = 0.075
		nozzle.bottom_radius = 0.045
		nozzle.height = 0.09
		nozzle.radial_segments = 6
		_nozzles.append(_add(nozzle, _hot, Vector3(side * 0.20, BODY.y * 0.5 + 0.16, 0.0)))

	# The lamp housing. If the game names a thing, the thing exists as visible
	# geometry within reach of its interaction point: the light comes out of
	# here, so here is a real object.
	_add(_prism(Vector3(0.16, 0.10, 0.13), 6), dark,
		Vector3(0.0, -BODY.y * 0.30, 0.20), Vector3(0.4, 0, PI * 0.5))

	# Where upgrades bolt on. Empty nodes at real positions, so M7 hangs a tank
	# or a plate on one and it lands where the hull expects it.
	for slot in [
		["tank", Vector3(0.0, 0.14, -0.22)],
		["plating", Vector3(0.0, -0.04, 0.24)],
		["instrument", Vector3(-0.22, -0.10, 0.14)],
		["ordnance", Vector3(0.22, -0.10, 0.14)],
	]:
		var n := Node3D.new()
		n.name = String(slot[0])
		n.position = slot[1]
		add_child(n)
		mounts[String(slot[0])] = n

	_set_layers(self)


## A prism with `sides` faces around its length, which is what gives the hull
## hard corners for the lamp to catch. Built from a cylinder rather than by hand
## because the vertex count is identical and the normals come out right.
func _prism(size: Vector3, sides: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = size.x * 0.5
	m.bottom_radius = size.x * 0.5
	m.height = size.y
	m.radial_segments = sides
	m.rings = 1
	return m


func _mat(albedo: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	return m


func _add(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO,
		parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	if parent == null:
		add_child(mi)
	else:
		parent.add_child(mi)
	return mi


## Every mesh in the rig goes on the ship's own layer, including the ones added
## to child nodes. A single mesh left on layer 1 would be the one object in the
## scene lit by both light models, and it would look it.
func _set_layers(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = LAYER
	for c in n.get_children():
		_set_layers(c)


## Point the drill along the heading, in SIM coordinates where y is depth and
## positive is down. At zero rotation the drill points at the floor.
func aim(heading: Vector2) -> void:
	if heading.length_squared() < 0.0001:
		return
	# Rotating the rest position (0, -1) about Z by t gives (sin t, -cos t), so
	# to reach the scene direction (hx, -hd) the angle is atan2(hx, hd).
	rotation.z = atan2(heading.x, heading.y)


## Spin the bit while it is cutting, and light the nozzles with the throttle.
## Fire visual, audio and haptic channels as one event: this is the visual one,
## and it is driven from the simulation's own state so it cannot disagree.
func drive(cutting: bool, throttle: float, dt: float) -> void:
	if cutting:
		_spin += dt * 22.0
		drill.rotation.y = _spin
	_hot.emission_energy_multiplier = clampf(throttle, 0.0, 1.0) * 2.6
