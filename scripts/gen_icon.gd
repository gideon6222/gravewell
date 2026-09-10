extends SceneTree

## The launcher icon, its adaptive layers, and the splash.
##
##   godot --headless --path . --script res://scripts/gen_icon.gd
##
## Drawn rather than fetched, because an icon IS the game's identity and nothing
## in a CC0 library is this game. Generated rather than hand-painted because it
## is three sizes of the same shape and the shape is arithmetic.
##
## The shape: a shaft cut down into dark rock, with the lamp's pool at the
## bottom of it. It reads at 48 px as a bright wedge in a dark field, which is
## what a launcher icon has to do, and it is literally what the game looks like.
##
## Adaptive icons: foreground and background are separate layers and Android
## masks them to whatever shape the launcher wants, so **everything that must
## survive lives inside the middle 66%**. A monochrome layer is required for
## themed icons on Android 13 and up.

const SIZE := 432
const OUT := "res://build/icon/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_layer("fg"), "icon_fg.png")
	_save(_layer("bg"), "icon_bg.png")
	_save(_layer("mono"), "icon_mono.png")
	_save(_square(), "icon.png")
	_save(_splash(), "splash.png")
	print("icons written to %s" % OUT)
	quit(0)


## One adaptive layer. The safe zone is the middle 66%, so the wedge is drawn
## well inside it and the background is a flat field that can be cropped to any
## shape without losing anything.
func _layer(kind: String) -> Image:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rock := Color(0.075, 0.078, 0.088, 1.0)
	if kind == "bg":
		img.fill(rock)
		# A little relief, so the background is rock rather than a swatch.
		for y in range(SIZE):
			for x in range(SIZE):
				var n := sin(float(x) * 0.09) * cos(float(y) * 0.07) * 0.012
				img.set_pixel(x, y, Color(rock.r + n, rock.g + n, rock.b + n * 1.2, 1.0))
		return img

	img.fill(Color(0, 0, 0, 0))
	var cx := float(SIZE) * 0.5
	var mono := kind == "mono"
	for y in range(SIZE):
		for x in range(SIZE):
			var fx := float(x)
			var fy := float(y)
			# The shaft: a wedge narrowing downward, well inside the safe zone.
			var t: float = clampf((fy - SIZE * 0.16) / (SIZE * 0.52), 0.0, 1.0)
			var half: float = lerpf(SIZE * 0.115, SIZE * 0.052, t)
			var inside: bool = absf(fx - cx) < half and fy > SIZE * 0.16 and fy < SIZE * 0.70
			# The lamp pool at the bottom of it.
			var d := Vector2(fx - cx, fy - SIZE * 0.74).length()
			var pool: float = clampf(1.0 - d / (SIZE * 0.26), 0.0, 1.0)
			pool *= pool

			var a := 0.0
			var col := Color(1.0, 0.92, 0.80, 1.0)
			if inside:
				a = 0.92 * (0.35 + 0.65 * t)
			a = maxf(a, pool * 0.95)
			if a <= 0.004:
				continue
			if mono:
				col = Color(1, 1, 1, 1)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, clampf(a, 0.0, 1.0)))
	return img


## The flat 512 store icon: the two adaptive layers composited, because the store
## listing wants one square image and it must be the same mark.
func _square() -> Image:
	var bg := _layer("bg")
	var fg := _layer("fg")
	bg.blend_rect(fg, Rect2i(0, 0, SIZE, SIZE), Vector2i.ZERO)
	bg.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	return bg


## A splash in the game's palette. `splash_screen/disable_godot_boot_splash` is
## on, so this is the first thing anyone sees.
func _splash() -> Image:
	var w := 720
	var h := 1280
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var d := Vector2(float(x) - float(w) * 0.5, float(y) - float(h) * 0.52).length()
			var v: float = clampf(1.0 - d / (float(w) * 0.75), 0.0, 1.0)
			v = 0.018 + v * v * 0.055
			img.set_pixel(x, y, Color(v * 1.05, v, v * 1.25, 1.0))
	var mark := _layer("fg")
	mark.resize(300, 300, Image.INTERPOLATE_LANCZOS)
	img.blend_rect(mark, Rect2i(0, 0, 300, 300), Vector2i(int(w * 0.5) - 150, int(h * 0.42) - 150))
	return img


func _save(img: Image, name: String) -> void:
	img.save_png(OUT + name)
	print("  %s  %dx%d" % [name, img.get_width(), img.get_height()])
