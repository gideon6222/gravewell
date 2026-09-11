class_name World
extends RefCounted

## The planet: what is in every cell, and what happens when you cut it.
##
## Pure. No Node, no Viewport, no input event, no real frame. Everything here
## is decided by a seeded hash of a PLACE, so a planet is reproducible from its
## seed alone and a whole descent can be replayed in a headless test.
##
## ## The one float doing three jobs
##
## `fill[i]` is 1.0 for untouched rock and 0.0 for fully cut, and it is:
##
##   1. the partial dig damage he asked for - "Blocks should stop being dug if
##      you stop drilling but remember how much damage is already done to them"
##   2. what the marching-squares contour interpolates, so the rock reads as
##      eroded stone rather than as stacked cubes
##   3. what the light flood calls passable
##
## One number, so the picture, the damage and the light can never disagree.
## PLAN.md stores this per CORNER; it is stored per CELL here, and the contour
## runs on the lattice of cell CENTRES sampling it directly. A per-corner store
## would let one dig bleed into three neighbouring cells that collision still
## calls solid, and averaging cells into shared corners cannot represent a single
## dug cell at all (one cell at 0 among solid gives every corner 0.75). Recorded
## in NOTES.md.
##
## ## Seed discipline
##
## Every generator rolls on its own offset from `Tuning.SEED_*`. Consuming
## another generator's roll shifts every ore at every depth on every planet and
## the diff looks like three lines. `test_world.gd` asserts the offsets are
## unique and that the frozen baseline still describes this world.

const WIDTH := Tuning.HALF_WIDTH * 2 + 1

var planet_seed: int = 0
var class_id: int = 0
var rows: int = 0

var mat: PackedByteArray = PackedByteArray()
var seam: PackedByteArray = PackedByteArray()

## **The fill field, at `Tuning.SUB` cells per metre.**
##
## This is the truth about what is left in the ground, and it is the ONLY array
## that is finer than a metre. Material, seams, hardness, yields and the whole
## light solve stay on the metre, because none of them is a shape: an ore vein
## is a metre-scale fact and a lit tunnel is a metre-scale fact. What had to get
## finer is the SURFACE, because a marching-squares contour cannot draw anything
## smaller than its own lattice, and the ship is 0.76 m.
##
## Everything coarse is DERIVED from this, never stored beside it - `fill_at` is
## the mean of a metre's fine cells and `is_open` is "every one of them is gone".
## One direction, fine to coarse, so the two can never disagree the way two
## thresholds for "gone" have twice before in this file.
var fine: PackedFloat32Array = PackedFloat32Array()

## **Which metres have changed shape since the renderer last looked.**
##
## The mesh is chunked now, so "rebuild the window because the ship crossed a
## cell" is the wrong question: the ship crossing a cell changes nothing, and the
## drill changes a couple of metres a tick. The simulation is the only thing that
## knows which, so it says so, as a rectangle rather than a list. Kept here
## rather than in the renderer so a headless run does the same bookkeeping and a
## test can assert on it.
var dirty_lo := Vector2i(0, 0)
var dirty_hi := Vector2i(-1, -1)

## **"Is this metre completely gone", cached, one byte each.**
##
## A derived cache and never a second opinion: it is recomputed from the fine
## field by `_resettle` every time that metre's fine cells change, and nothing
## else may write it. It exists because the light flood asks `is_open` about
## 2,401 cells times eight neighbours on every solve, and answering that by
## looping sixteen fine cells turned a 20 ms flood into something far worse.
var open_cache: PackedByteArray = PackedByteArray()

## And its opposite: this metre is entirely untouched rock. The mesh builder asks
## it for every metre in a chunk to decide whether to draw one quad or contour
## sixteen cells, and answering that by looping the fine cells was most of the
## rebuild's cost. Same rule: derived in `_resettle`, written nowhere else.
var solid_cache: PackedByteArray = PackedByteArray()

const FWIDTH := WIDTH * Tuning.SUB

## Where the core chamber sits. Offset per planet so a straight dive down the
## centre is a real route rather than the only one, and so "the core is
## directly below the pad" never becomes something the player can assume.
var core_x: int = 0

## Rime only: cells whose support has been cut away, and how long until they
## fall. Marked when a dig widens the span below them, so the cost is paid at
## the moment the player creates the hazard rather than by scanning the world.
var unstable: Dictionary = {}


func _init(seed_value: int = 1, world_class: int = 0) -> void:
	planet_seed = seed_value
	class_id = world_class
	rows = Tuning.SURFACE_ROWS + Tuning.CORE_DEPTH + 1
	_generate()


# ── addressing ────────────────────────────────────────────────────────────

## Cells are addressed by (x, depth) in metres, with depth 0 at the pad and
## positive downward, so depth and row are the same number everywhere in the
## game and nothing has to convert.
func in_bounds(x: int, d: int) -> bool:
	return x >= -Tuning.HALF_WIDTH and x <= Tuning.HALF_WIDTH \
		and d >= -Tuning.SURFACE_ROWS and d <= Tuning.CORE_DEPTH


func idx(x: int, d: int) -> int:
	return (d + Tuning.SURFACE_ROWS) * WIDTH + (x + Tuning.HALF_WIDTH)


## Out of bounds is SOLID at the sides and at the bottom, and OPEN above the
## surface. A world that is open past its edge lets the ship leave the grid,
## and every consumer of this would then need its own edge case.
func material_at(x: int, d: int) -> int:
	if d < -Tuning.SURFACE_ROWS:
		return Ore.AIR
	if not in_bounds(x, d):
		return Ore.ROCK
	return mat[idx(x, d)]


func fill_at(x: int, d: int) -> float:
	if d < -Tuning.SURFACE_ROWS:
		return 0.0
	if not in_bounds(x, d):
		return 1.0
	return _mean_fill(x, d)


# ── the fine field, and the coarse answers derived from it ────────────────

## Address a FINE cell. Fine coordinates are metre coordinates times `SUB`, so
## fine cell (0, 0) is the top-left quarter of metre cell (0, 0).
func fidx(fx: int, fd: int) -> int:
	return (fd + Tuning.SURFACE_ROWS * Tuning.SUB) * FWIDTH + (fx + Tuning.HALF_WIDTH * Tuning.SUB)


## **Where a fine cell's centre is, in metres.**
##
## Metre cell `x` is centred on `x` and spans `x - 0.5` to `x + 0.5`, so its
## fine cells run from `x - 0.5` upward and NOT from `x`. Getting this wrong is
## a half-metre offset between the two lattices, which does not look like an
## offset: it looks like the drill cutting a lopsided hole that never finishes,
## because the ship is riding the left edge of the block it is clearing. The
## fine profile of a carved metre read `0.02 0.16 0.57 1.00` across, and no metre
## in the game ever became passable.
static func fine_centre(n: int) -> float:
	return (float(n) + 0.5) / float(Tuning.SUB) - 0.5


## And the inverse: the fractional fine index of a point in metres.
static func fine_index(m: float) -> float:
	return (m + 0.5) * float(Tuning.SUB) - 0.5


func fine_in_bounds(fx: int, fd: int) -> bool:
	return fx >= -Tuning.HALF_WIDTH * Tuning.SUB and fx < (Tuning.HALF_WIDTH + 1) * Tuning.SUB 		and fd >= -Tuning.SURFACE_ROWS * Tuning.SUB and fd < (Tuning.CORE_DEPTH + 1) * Tuning.SUB


## Out of bounds is SOLID at the sides and the bottom, OPEN above the surface,
## exactly as the coarse version is.
func fine_at(fx: int, fd: int) -> float:
	if fd < -Tuning.SURFACE_ROWS * Tuning.SUB:
		return 0.0
	if not fine_in_bounds(fx, fd):
		return 1.0
	return fine[fidx(fx, fd)]


## Set a whole METRE to one value. Generation, collapses and falling ceilings all
## work in metres, and so do the tests.
func set_fill(x: int, d: int, v: float) -> void:
	if not in_bounds(x, d):
		return
	mark_dirty(x, d)
	for j in range(Tuning.SUB):
		for i in range(Tuning.SUB):
			fine[fidx(x * Tuning.SUB + i, d * Tuning.SUB + j)] = v
	_resettle(x, d)


## Note that a metre's SHAPE changed, so the chunk drawing it gets rebuilt.
func mark_dirty(x: int, d: int) -> void:
	if dirty_hi.x < dirty_lo.x:
		dirty_lo = Vector2i(x, d)
		dirty_hi = Vector2i(x, d)
		return
	dirty_lo = Vector2i(mini(dirty_lo.x, x), mini(dirty_lo.y, d))
	dirty_hi = Vector2i(maxi(dirty_hi.x, x), maxi(dirty_hi.y, d))


## Read the dirty rectangle and clear it. Empty when `hi` is behind `lo`.
func take_dirty() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if dirty_hi.x >= dirty_lo.x:
		out.append(dirty_lo)
		out.append(dirty_hi)
	dirty_lo = Vector2i(0, 0)
	dirty_hi = Vector2i(-1, -1)
	return out


## Take `amount` of fill out of a metre, spread evenly over its fine cells.
func _take_even(x: int, d: int, amount: float) -> void:
	if not in_bounds(x, d) or amount <= 0.0:
		return
	mark_dirty(x, d)
	for j in range(Tuning.SUB):
		for i in range(Tuning.SUB):
			var k := fidx(x * Tuning.SUB + i, d * Tuning.SUB + j)
			fine[k] = maxf(fine[k] - amount, 0.0)
	_resettle(x, d)


## How much of a metre is left, as the mean of its fine cells. This is what the
## contour used to read directly and what everything coarse still reads.
func _mean_fill(x: int, d: int) -> float:
	if d < -Tuning.SURFACE_ROWS:
		return 0.0
	if not in_bounds(x, d):
		return 1.0
	var total := 0.0
	for j in range(Tuning.SUB):
		for i in range(Tuning.SUB):
			total += fine[fidx(x * Tuning.SUB + i, d * Tuning.SUB + j)]
	return total / float(Tuning.SUB * Tuning.SUB)


## **Fill at a POINT, bilinear on the FINE lattice.**
##
## The same lattice and the same interpolation the contour is built from, so the
## number this returns is the one the player is looking at. It exists because a
## per-cell value is flat inside a cell, and a ship backing out of material it
## has half cut needs to know whether it is getting out, which is a question that
## has to have a different answer half a cell later.
func fill_between(p: Vector2) -> float:
	var fx := fine_index(p.x)
	var fd := fine_index(p.y)
	var x0 := int(floor(fx))
	var d0 := int(floor(fd))
	var tx := fx - float(x0)
	var td := fd - float(d0)
	var a := fine_at(x0, d0)
	var b := fine_at(x0 + 1, d0)
	var c := fine_at(x0, d0 + 1)
	var e := fine_at(x0 + 1, d0 + 1)
	return lerp(lerp(a, b, tx), lerp(c, e, tx), td)


## The ONE definition of passable, shared by collision, the flood and the drill.
## A cell is passable only when it is fully cut: a half-cut cell you can fly
## through is a cell that never breaks and never pays.
## **Has this metre been worked out?** Not "can the ship fit", which is
## `Flight._blocked` asking the fine field directly. This one decides whether
## light travels through, whether the ore has been paid for and whether the route
## home runs here, all of which are metre-scale facts. Derived from the fine
## field through `Tuning.METRE_OPEN`, one direction, so it cannot drift from what
## the player is looking at.
func is_open(x: int, d: int) -> bool:
	if d < -Tuning.SURFACE_ROWS:
		return true
	if not in_bounds(x, d):
		return false
	return open_cache[idx(x, d)] == 1


## Recompute one metre's cached answer from the fine cells under it. The ONLY
## writer of `open_cache`, so the cache cannot say something the field does not.
func _resettle(x: int, d: int) -> void:
	var mean := _mean_fill(x, d)
	var i := idx(x, d)
	open_cache[i] = 1 if mean <= Tuning.METRE_OPEN else 0
	solid_cache[i] = 1 if mean >= 1.0 - 1.0e-6 else 0


## Is this metre entirely untouched? Out of bounds counts as solid at the sides
## and the bottom and as open above the surface, exactly as everything else here.
func is_solid(x: int, d: int) -> bool:
	if d < -Tuning.SURFACE_ROWS:
		return false
	if not in_bounds(x, d):
		return true
	return solid_cache[idx(x, d)] == 1


## **Can the ship be here? Answered with the isovalue the SURFACE is drawn at.**
##
## Deliberately `CONTOUR_ISO` and not `OPEN_FILL`. The contour puts the rock face
## where the fill crosses 0.5, so a fine cell below that is on the air side of the
## line the player is looking at, and anything else means the ship is stopped by
## something that is not drawn. It was `OPEN_FILL` for one round and a ship
## carrying the core sat still against two quarter-metre wisps holding two per
## cent of a metre between them, with clear air on the screen all around it.
##
## This is not a third threshold for one fact. It is the picture and the
## collision finally being the SAME fact - which is the thing this file has got
## wrong twice - while `METRE_OPEN` answers the different, metre-scale question
## of whether a metre has been worked out.
func is_clear(fx: int, fd: int) -> bool:
	return fine_at(fx, fd) < Tuning.CONTOUR_ISO


func is_seam(x: int, d: int) -> bool:
	if not in_bounds(x, d):
		return false
	return seam[idx(x, d)] == 1


# ── generation ────────────────────────────────────────────────────────────

## The salt for one generator on this planet. Offsets are small and the planet
## stride is far larger than the largest offset, so two generators can never
## collide on any planet.
func _salt(offset: int) -> int:
	return offset + planet_seed * 977


func _roll(x: int, d: int, offset: int) -> float:
	return SimUtil.hash3(x, d, _salt(offset))


func _generate() -> void:
	var n := rows * WIDTH
	mat.resize(n)
	seam.resize(n)
	fine.resize(n * Tuning.SUB * Tuning.SUB)
	open_cache.resize(n)
	solid_cache.resize(n)

	# 1. Rock, ore and seams. Ore rolls on SEED_ORE and the seam texture rolls
	#    on SEED_SEAM, and the seam roll is read once and used for BOTH the
	#    texture and the payout, so the wall cannot lie about what it pays.
	for d in range(-Tuning.SURFACE_ROWS, Tuning.CORE_DEPTH + 1):
		for x in range(-Tuning.HALF_WIDTH, Tuning.HALF_WIDTH + 1):
			var i := idx(x, d)
			if d < 0:
				mat[i] = Ore.AIR
				set_fill(x, d, 0.0)
				seam[i] = 0
				continue
			mat[i] = Ore.roll(float(d), _roll(x, d, Tuning.SEED_ORE))
			set_fill(x, d, 1.0)
			seam[i] = 1 if _roll(x, d, Tuning.SEED_SEAM) < Tuning.SEAM_CHANCE else 0

	_carve_caverns()
	_place_caches()
	_carve_core()


## Open space the player did not cut. One candidate per block so the density is
## a property of the block grid rather than of a per-cell roll that clumps.
func _carve_caverns() -> void:
	var b := Tuning.CAVERN_BLOCK
	var d := Tuning.CAVERN_MIN_DEPTH
	while d < Tuning.CORE_DEPTH - 12:
		var x := -Tuning.HALF_WIDTH
		while x <= Tuning.HALF_WIDTH:
			if _roll(x, d, Tuning.SEED_CAVERN) < Classes.cavern_chance(class_id):
				var rr := _roll(x + 1, d, Tuning.SEED_CAVERN)
				var radius: float = Tuning.CAVERN_RADIUS[0] + rr * (Tuning.CAVERN_RADIUS[1] - Tuning.CAVERN_RADIUS[0])
				var cx: int = x + int(_roll(x + 2, d, Tuning.SEED_CAVERN) * float(b))
				var cd: int = d + int(_roll(x + 3, d, Tuning.SEED_CAVERN) * float(b))
				_carve_blob(cx, cd, radius)
			x += b
		d += b


## An ellipse rather than a circle: wider than it is tall, so a cavern reads as
## a seam that opened up rather than as a bubble, and so it does not become a
## vertical shortcut that skips a band.
func _carve_blob(cx: int, cd: int, radius: float) -> void:
	var rx: float = radius * 1.6
	var rd: float = radius
	var x0 := int(floor(float(cx) - rx))
	var x1 := int(ceil(float(cx) + rx))
	var d0 := int(floor(float(cd) - rd))
	var d1 := int(ceil(float(cd) + rd))
	for d in range(d0, d1 + 1):
		for x in range(x0, x1 + 1):
			if not in_bounds(x, d) or d < 1:
				continue
			var nx := (float(x - cx)) / rx
			var nd := (float(d - cd)) / rd
			if nx * nx + nd * nd <= 1.0:
				var i := idx(x, d)
				mat[i] = Ore.AIR
				set_fill(x, d, 0.0)
				seam[i] = 0


## Caches: the only source of filament, and filament is the only thing that
## buys a counter to a threat. One per block guarantees the spacing without a
## rejection pass whose result would depend on visit order.
func _place_caches() -> void:
	var b := Tuning.CACHE_BLOCK
	var d := Tuning.CACHE_MIN_DEPTH
	while d < Tuning.CORE_DEPTH - 6:
		var x := -Tuning.HALF_WIDTH
		while x <= Tuning.HALF_WIDTH:
			if _roll(x, d, Tuning.SEED_CACHE) < Tuning.CACHE_BLOCK_CHANCE:
				# Keep the cache away from the block's own edges, or two caches
				# either side of a boundary land next to each other and the
				# spacing the block grid exists to guarantee is not guaranteed.
				var inner := b - 4
				var cx: int = x + 2 + int(_roll(x + 1, d, Tuning.SEED_CACHE) * float(inner))
				var cd: int = d + 2 + int(_roll(x + 2, d, Tuning.SEED_CACHE) * float(inner))
				if in_bounds(cx, cd) and mat[idx(cx, cd)] != Ore.AIR:
					mat[idx(cx, cd)] = Ore.CACHE
					seam[idx(cx, cd)] = 0
			x += b
		d += b


## The core chamber. Open space around a single CORE cell, so the last thing
## you do is fly into a room rather than cut one more block.
func _carve_core() -> void:
	core_x = int((SimUtil.hash3(0, 0, _salt(Tuning.SEED_VAULT)) - 0.5) * 12.0)
	core_x = clampi(core_x, -Tuning.HALF_WIDTH + 5, Tuning.HALF_WIDTH - 5)
	var cd := Tuning.CORE_DEPTH - 3
	for d in range(cd - 2, cd + 3):
		for x in range(core_x - 3, core_x + 4):
			if not in_bounds(x, d):
				continue
			var i := idx(x, d)
			mat[i] = Ore.AIR
			set_fill(x, d, 0.0)
			seam[i] = 0
	mat[idx(core_x, cd)] = Ore.CORE
	set_fill(core_x, cd, 1.0)


func core_depth() -> int:
	return Tuning.CORE_DEPTH - 3


# ── cutting ───────────────────────────────────────────────────────────────

## Take `hp` hit points out of a cell. Returns what happened, so the caller can
## charge power for the work done rather than for the attempt, and can pick up
## whatever broke loose.
##
## Damage is KEPT when the drill stops, because `fill` IS the damage. There is
## no separate progress number that could be reset while the picture stayed cut.
func cut(x: int, d: int, hp: float) -> Dictionary:
	var out := {"cut": 0.0, "broke": false, "mat": Ore.AIR, "kg": 0.0, "value": 0.0, "filament": 0, "core": false}
	if not in_bounds(x, d):
		return out
	var i := idx(x, d)
	# **The same threshold `is_open` uses, and it has to be the same one.**
	# `is_open` calls a cell passable at `OPEN_FILL`, and this used to break it
	# only at exactly 0.0, which leaves a gap: a cell can land on a fill inside
	# that gap, become flyable, and NEVER break, never yield and never lose its
	# ore material. Measured on Rime, whose hardness multiplier changes the
	# arithmetic enough to land there: a scripted miner ping-ponged between two
	# dug-out cells that still reported themselves as iron, reached 15 m in forty
	# seconds and mined nothing at all.
	#
	# This is the second time two thresholds for "gone" have disagreed in this
	# file. There is one.
	if is_open(x, d):
		return out

	var m := int(mat[i])
	# Depth, class and MATERIAL, in that order. The material term is what makes a
	# vein something you feel rather than only something you see: without it
	# every cell in a band cut at exactly the same rate and the plow ran flat.
	var hardness := Tuning.hardness_at(float(d)) * Classes.hardness_mult(class_id) 		* Ore.hardness_of(m, seam[i] == 1)
	# The core takes far longer than anything else and it is meant to: the cut
	# is the tell that the extraction is about to start.
	if m == Ore.CORE:
		hardness *= 6.0

	# Spread evenly across the metre's fine cells: `cut` is the whole-cell API,
	# used by the tests and by anything that wants a metre gone rather than a
	# shape carved. `carve` is what the drill uses, and it works fine cell by
	# fine cell so the surface can move in quarter metres.
	var removed: float = minf(hp / hardness, _mean_fill(x, d))
	_take_even(x, d, removed)
	out["cut"] = removed * hardness      ## hit points actually spent, for the power charge

	if not is_open(x, d):
		return out

	set_fill(x, d, 0.0)
	out["broke"] = true
	out["mat"] = m
	_check_ceiling(x, d)
	if m == Ore.CACHE:
		out["filament"] = Tuning.CACHE_FILAMENT[Tuning.band_at(float(d))]
		mat[i] = Ore.AIR
		return out
	if m == Ore.CORE:
		out["core"] = true
		mat[i] = Ore.AIR
		return out

	var y := Ore.yield_of(m, seam[i] == 1)
	out["kg"] = y["kg"]
	out["value"] = y["value"]
	mat[i] = Ore.AIR
	return out


## **Carve a feathered capsule from `a` to `b` and return everything it freed.**
##
## This is the plow. `cut()` above is still what removes fill from ONE cell and
## decides what it was worth; this decides which cells the drill head is over and
## how much of the tick's work each of them gets. Keeping the two apart is what
## lets the yield rules stay in one place while the SHAPE of the dig changes.
##
## Three properties it has to have, each of which cost something to learn:
##
## **Feathered.** The weight is 1.0 inside `radius` and falls to 0 across
## `feather`. A hard rim bites in circular arcs that do not line up with the
## grid, and the contour comes out scalloped - which is exactly the "random edges
## that stick out" that his light was catching on.
##
## **Swept.** Distance is measured to the SEGMENT a-b, not to a point. A tick at
## a low frame rate moves the ship further than the brush is wide, and a
## point-sampled brush would leave a standing wall behind it that the hull is
## already past.
##
## **It clears its core completely.** Cells within `radius` of the path get the
## full weight, and `radius` is wider than the hull's half-extent, so the ship
## can never end a tick inside rock it has not paid to remove. Without that,
## releasing the drill mid-cut wedges the ship in a cell it cannot re-enter.
func carve(a: Vector2, b: Vector2, radius: float, feather: float, hp: float) -> Dictionary:
	var out := {
		"cut": 0.0, "broke": 0, "kg": 0.0, "value": 0.0, "filament": 0,
		"core": false, "core_cell": Vector2i.ZERO, "cells": [],
	}
	if hp <= 0.0:
		return out
	var sub := float(Tuning.SUB)
	var reach := radius + feather

	# **Gathered in FINE cells.** This is the whole change: the brush used to
	# take whole metres, so the drawn wall could only ever recede in steps close
	# to the ship's own width however smoothly the float underneath it moved.
	#
	# The weights are normalised, so a wide brush does not dig faster than a
	# narrow one: the tick's hit points are SHARED between everything under it.
	# Without that the dig rate would depend on the brush's area, and the brush is
	# a picture decision while the rate is a balance decision.
	var cells := PackedInt32Array()
	var weights := PackedFloat32Array()
	var total := 0.0
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(reach, reach)
	var fd0 := int(floor(fine_index(lo.y)))
	var fd1 := int(ceil(fine_index(hi.y)))
	var fx0 := int(floor(fine_index(lo.x)))
	var fx1 := int(ceil(fine_index(hi.x)))
	for fd in range(fd0, fd1 + 1):
		for fx in range(fx0, fx1 + 1):
			if not fine_in_bounds(fx, fd):
				continue
			var k := fidx(fx, fd)
			if fine[k] <= Tuning.OPEN_FILL:
				continue
			var p := Vector2(fine_centre(fx), fine_centre(fd))
			var dist := SimUtil.point_to_segment(p, a, b)
			if dist >= reach:
				continue
			var w := 1.0 if dist <= radius else 1.0 - (dist - radius) / maxf(feather, 0.001)
			w = w * w * (3.0 - 2.0 * w)          ## smoothstep, so the rim is soft
			cells.append(k)
			weights.append(w)
			total += w
	if total <= 0.0:
		return out

	# **The hardness of a fine cell is its METRE's hardness.** Material, seam and
	# depth are all metre-scale facts; only the shape got finer. One hit point
	# still buys the same volume it always did, so the plow's speed, the power
	# bill and the yields are all untouched by this.
	var broke_metres: Array[Vector2i] = []
	for i in range(cells.size()):
		var k: int = cells[i]
		var fx := k % FWIDTH - Tuning.HALF_WIDTH * Tuning.SUB
		var fd := k / FWIDTH - Tuning.SURFACE_ROWS * Tuning.SUB
		var x := int(roundf(fine_centre(fx)))
		var d := int(roundf(fine_centre(fd)))
		var m := int(mat[idx(x, d)])
		var hardness := Tuning.hardness_at(float(d)) * Classes.hardness_mult(class_id) 			* Ore.hardness_of(m, seam[idx(x, d)] == 1)
		if m == Ore.CORE:
			hardness *= 6.0
		# A fine cell is 1/SUB² of a metre, so removing all of it costs that
		# fraction of the metre's hit points.
		var share: float = hp * weights[i] / total
		var removed: float = minf(share / hardness * float(Tuning.SUB * Tuning.SUB), fine[k])
		if removed <= 0.0:
			continue
		fine[k] -= removed
		mark_dirty(x, d)
		_resettle(x, d)
		out["cut"] = float(out["cut"]) + removed * hardness / float(Tuning.SUB * Tuning.SUB)
		if fine[k] > Tuning.OPEN_FILL:
			continue
		fine[k] = 0.0
		var metre := Vector2i(x, d)
		if not broke_metres.has(metre) and is_open(x, d) and mat[idx(x, d)] != Ore.AIR:
			broke_metres.append(metre)

	# A metre pays when the last of it is gone. Everything about what a cell is
	# WORTH is still decided in one place.
	for c in broke_metres:
		var res := _break_metre(c.x, c.y)
		out["broke"] = int(out["broke"]) + 1
		if bool(res["core"]):
			out["core"] = true
			out["core_cell"] = c
			continue
		if int(res["filament"]) > 0:
			out["filament"] = int(out["filament"]) + int(res["filament"])
			continue
		# Each broken metre is reported on its own, because the hold can fill
		# half way through a tick and the rest has to land on the ground.
		(out["cells"] as Array).append({
			"x": c.x, "d": c.y, "mat": int(res["mat"]),
			"kg": float(res["kg"]), "value": float(res["value"]),
		})
	return out


## What a metre gives up once the last of it is gone. Split out of `cut` so the
## carve and the whole-cell API reach the same rules by the same road.
func _break_metre(x: int, d: int) -> Dictionary:
	var out := {"mat": Ore.AIR, "kg": 0.0, "value": 0.0, "filament": 0, "core": false}
	var i := idx(x, d)
	var m := int(mat[i])
	out["mat"] = m
	_check_ceiling(x, d)
	if m == Ore.CACHE:
		out["filament"] = Tuning.CACHE_FILAMENT[Tuning.band_at(float(d))]
		mat[i] = Ore.AIR
		return out
	if m == Ore.CORE:
		out["core"] = true
		mat[i] = Ore.AIR
		return out
	var y := Ore.yield_of(m, seam[i] == 1)
	out["kg"] = y["kg"]
	out["value"] = y["value"]
	mat[i] = Ore.AIR
	return out


	return out


# ── reading the shape, for the light flood and the contour ────────────────

## How open the space immediately around a point is, in [0, 1]. The light flood
## computes this already; the audio reverb reads the same number, so a tight
## shaft is dry and close and a cavern is enormous, from one source.
func openness(x: int, d: int, radius: int = 4) -> float:
	var open := 0
	var total := 0
	for dd in range(d - radius, d + radius + 1):
		for xx in range(x - radius, x + radius + 1):
			total += 1
			if is_open(xx, dd):
				open += 1
	return float(open) / float(maxi(total, 1))


## Count of a material still in the ground. Slow, for tests and the probe only.
func count_of(m: int) -> int:
	var n := 0
	for i in range(mat.size()):
		if mat[i] == m:
			n += 1
	return n


## The shortest open route from a cell to the surface, in cells, or -1 if there
## is no way out at all.
##
## A breadth-first search over open cells, eight-connected. It exists for one
## reason: **never let a hazard take the run.** The extraction's clock is derived
## from this rather than set as a flat number, and a collapse that would make the
## surface unreachable is reverted rather than shipped.
##
## Coreward learned this the expensive way: re-run the pathfinder after a
## collapse and revert if home is unreachable, and test the bound.
func route_out(from_x: int, from_d: int) -> int:
	if not is_open(from_x, from_d):
		return -1
	var seen := {}
	var queue: Array[Vector3i] = [Vector3i(from_x, from_d, 0)]
	seen[Vector2i(from_x, from_d)] = true
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		if cur.y <= 0:
			return cur.z
		for sy in range(-1, 2):
			for sx in range(-1, 2):
				if sx == 0 and sy == 0:
					continue
				var nx := cur.x + sx
				var nd := cur.y + sy
				var key := Vector2i(nx, nd)
				if seen.has(key) or not is_open(nx, nd):
					continue
				seen[key] = true
				queue.append(Vector3i(nx, nd, cur.z + 1))
	return -1


## Collapse a cell, refusing the collapse if it would seal the way out.
##
## Returns true if the cell was actually filled. The check is the whole point:
## a hazard may cost the player the run's takings, never the run itself.
func collapse(x: int, d: int, from_x: int, from_d: int) -> bool:
	if not in_bounds(x, d) or not is_open(x, d):
		return false
	var i := idx(x, d)
	var was_mat := mat[i]
	mat[i] = Ore.ROCK
	set_fill(x, d, 1.0)
	if route_out(from_x, from_d) < 0:
		mat[i] = was_mat
		set_fill(x, d, 0.0)
		return false
	return true


# ── brittle ceilings ──────────────────────────────────────────────────────

## **Rime's rule.** Ice cuts in half the time and the ceilings do not hold, so a
## descent is quick and every wide cut is a decision.
##
## Marked at the moment the player CREATES the hazard rather than by scanning the
## world every frame: cutting a cell widens the open span on its row, and if that
## span reaches `BRITTLE_SPAN` the rock above the middle of it starts to go. A
## one-cell shaft is safe forever, which keeps the careful way to dig available
## and makes the wide cut the gamble.
func _check_ceiling(x: int, d: int) -> void:
	if not Classes.is_brittle(class_id):
		return
	var left := x
	while is_open(left - 1, d):
		left -= 1
	var right := x
	while is_open(right + 1, d):
		right += 1
	var span := right - left + 1
	if span < Classes.BRITTLE_SPAN:
		return
	for xx in range(left, right + 1):
		if is_open(xx, d - 1):
			continue
		var key := Vector2i(xx, d - 1)
		if not unstable.has(key):
			unstable[key] = Classes.BRITTLE_DELAY


## Count the marked ceilings down. Returns the cells that actually fell this
## step, so the caller can hurt whoever is standing under them.
##
## Pure: it takes the delta and returns what happened, and decides nothing about
## damage, which is the ship's business.
func settle(dt: float) -> Array[Vector2i]:
	var fell: Array[Vector2i] = []
	if unstable.is_empty():
		return fell
	for key in unstable.keys():
		unstable[key] = float(unstable[key]) - dt
		if float(unstable[key]) > 0.0:
			continue
		var c: Vector2i = key
		fell.append(c)
		if in_bounds(c.x, c.y) and not is_open(c.x, c.y):
			# The ceiling comes DOWN: the cell above empties and the cell below
			# fills, which is a rock falling rather than a cell vanishing.
			var below := Vector2i(c.x, c.y + 1)
			mat[idx(c.x, c.y)] = Ore.AIR
			set_fill(c.x, c.y, 0.0)
			if in_bounds(below.x, below.y):
				mat[idx(below.x, below.y)] = Ore.ROCK
				set_fill(below.x, below.y, 1.0)
	for c in fell:
		unstable.erase(c)
	return fell


## How close the nearest cracking ceiling is, and how long it has. The tell:
## announced before it charges, and by more than human reaction time.
func nearest_crack(from: Vector2) -> float:
	var soonest := 1.0e9
	for key in unstable.keys():
		var c: Vector2i = key
		if (Vector2(float(c.x), float(c.y)) - from).length() < 7.0:
			soonest = minf(soonest, float(unstable[key]))
	return soonest
