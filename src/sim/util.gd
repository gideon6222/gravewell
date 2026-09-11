class_name SimUtil
extends RefCounted

## Pure helpers. No nodes, no rendering, no scene tree - so the test runner can
## call any of this headlessly without standing a game up.
##
## Everything here is statically typed on purpose. Typed GDScript compiles to
## faster bytecode than untyped, and more usefully it makes a wrong argument a
## load error rather than a nan three frames later.

const MASK_32 := 0xFFFFFFFF


## Frame-rate independent smoothing: the fraction to move toward a target this
## frame, given a rate and a real delta.
##
## `pos += (target - pos) * 0.1` looks fine at 60fps and is a different spring
## at 120, which is what the phone actually runs at.
static func smooth(rate: float, dt: float) -> float:
	return 1.0 - exp(-rate * dt)


## Distance from a point to the SEGMENT a-b, not to the infinite line.
##
## The drill brush is swept along the path the ship actually travelled in a tick,
## so that it cannot skip a thin wall at a low frame rate. A line would carve
## ahead of the ship and behind it forever; the clamp is what makes it a capsule.
static func point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 1.0e-12:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## 32-bit multiply. GDScript ints are 64-bit, so a plain `*` does not wrap the
## way the mixing steps below assume; masking after each one does.
static func imul(a: int, b: int) -> int:
	return (a * b) & MASK_32


## Deterministic 2D hash, uniform over [0, 1).
##
## Every place-keyed decision goes through this rather than randf(), which is
## what makes a whole run reproducible from (chunk, level) alone and is what
## the golden test depends on.
##
## The shifts operate on a value already masked to 32 unsigned bits, so `>>` is
## a logical shift here. That detail is the whole function: in the sibling web
## game the same hash used signed shifts, so `h ^ (h >> 16)` always cleared the
## top bit and it could never return above 0.5 - which silently disabled three
## mechanics whose spawn rolls compared against thresholds above a half, with
## no error and nothing visibly missing. `test/test_util.gd` asserts the range
## and the distribution for exactly that reason.
static func hash2(a: int, b: int) -> float:
	var h: int = (imul(a, 374761393) + imul(b, 668265263)) & MASK_32
	h = imul(h ^ (h >> 13), 1274126177)
	h = (h ^ (h >> 16)) & MASK_32
	return float(h) / 4294967296.0


## Deterministic 3D hash, uniform over [0, 1).
##
## Gravewell keys every generated thing on (x, depth, salt), where the salt
## carries both the generator's own seed offset and the planet. Composing two
## hash2 calls would work and would also make two different generators agree
## whenever their salts happened to compose the same way, so the third term
## goes into the mix directly.
##
## Same unsigned-shift discipline as hash2, and `test_util.gd` asserts the
## range and the distribution for the same reason: a signed shift silently
## returns only [0, 0.5) and disables every mechanic whose threshold is above
## a half, with no error and nothing visibly missing.
static func hash3(a: int, b: int, c: int) -> float:
	var h: int = (imul(a, 374761393) + imul(b, 668265263) + imul(c, 2246822519)) & MASK_32
	h = imul(h ^ (h >> 13), 1274126177)
	h = imul(h ^ (h >> 15), 2654435761)
	h = (h ^ (h >> 16)) & MASK_32
	return float(h) / 4294967296.0


## Compact numbers for a HUD. Thousands keep one decimal until five figures, so
## the width of the readout stays roughly still while the number climbs.
static func fmt(n: float) -> String:
	var v := int(floor(n))
	if v < 1000:
		return str(v)
	if v < 1000000:
		return ("%.1fK" % (v / 1000.0)) if v < 10000 else ("%dK" % (v / 1000))
	if v < 1000000000:
		return ("%.1fM" % (v / 1000000.0)) if v < 10000000 else ("%dM" % (v / 1000000))
	return "%.1fB" % (v / 1000000000.0)
