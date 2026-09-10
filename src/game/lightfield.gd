class_name LightField
extends RefCounted

## The solved light, as a texture the shader can sample by world position.
##
## `Light` solves it; this uploads it. Keeping the two apart is what lets the
## solver be tested headlessly with no GPU at all, which is where every one of
## its assertions lives.
##
## **A small texture with linear filtering, sampled by world position.** The
## field is 49x49 texels, which is 9.6 KB, and the linear filter is what makes
## light fade ACROSS a rock face instead of stepping at cell edges. The
## one-toggle diagnosis if it ever looks blocky is switching the filter to
## nearest: if the picture does not change, the shader is not sampling this at
## all.
##
## **Brightness and shape are in separate channels.** R is the flood, which is
## the light in open cells and is what the air term reads. G is the spill, the
## same light carried one cell onto the rock faces beside it, and is what the
## surface term reads. One upload, two lights, and the shader cannot accidentally
## hand one of them the other's number.

var texture: ImageTexture
var fan_texture: ImageTexture
var origin := Vector2i(0, 0)

var _image: Image
var _fan_image: Image
var _solved_at := Vector2i(99999, 99999)
var _dirty := true


func _init() -> void:
	_image = Image.create_empty(Light.SIDE, Light.SIDE, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0, 0, 0, 1))
	texture = ImageTexture.create_from_image(_image)
	_fan_image = Image.create_empty(Light.RAYS, 1, false, Image.FORMAT_RGBA8)
	_fan_image.fill(Color(1, 1, 1, 1))
	fan_texture = ImageTexture.create_from_image(_fan_image)


func touch() -> void:
	_dirty = true


## Re-solve and upload if the ship has changed cell or the rock has changed
## shape. Returns true if it actually did the work, so the caller does not need
## a second idea of when things change.
##
## The flood runs here rather than per frame because it is a property of the
## GEOMETRY: a Dijkstra over a few hundred cells costs microseconds and produces
## the same answer every frame the ship stays in one cell.
func refresh(world: World, at: Vector2i) -> bool:
	if not _dirty and at == _solved_at:
		return false
	_solved_at = at
	_dirty = false
	origin = at

	var flood := Light.flood(world, at.x, at.y)
	var spill := Light.spill(world, flood, at.x, at.y)
	for d in range(Light.SIDE):
		for x in range(Light.SIDE):
			var i := d * Light.SIDE + x
			_image.set_pixel(x, d, Color(flood[i], spill[i], 0.0, 1.0))
	texture.update(_image)
	return true


## The shadow fan runs EVERY frame, unlike the flood, because the whole point of
## it is that the shadow moves as the ship does. A few thousand grid steps does
## not show up in a measurement.
func refresh_fan(world: World, from: Vector2, reach: float) -> void:
	var f := Light.fan(world, from, reach)
	for i in range(Light.RAYS):
		# Normalised against the reach so it survives an 8-bit channel: the
		# shader multiplies it back out. 256 levels over the lamp's reach is a
		# fortieth of a metre, far finer than a shadow edge needs.
		var v: float = clampf(f[i] / maxf(reach, 0.001), 0.0, 1.0)
		_fan_image.set_pixel(i, 0, Color(v, v, v, 1.0))
	fan_texture.update(_fan_image)


## Where the field's centre sits in world coordinates, for the shader uniform.
func origin_world() -> Vector2:
	return Vector2(float(origin.x), float(origin.y))
