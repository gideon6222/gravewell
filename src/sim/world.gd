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
## PLAN.md stores this per CORNER; it is stored per CELL here and averaged to
## corners at contour time, because collision is on the cell grid and a
## per-corner store would let a dig bleed into three neighbouring cells that
## collision still calls solid. Recorded in NOTES.md.
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
var fill: PackedFloat32Array = PackedFloat32Array()
var seam: PackedByteArray = PackedByteArray()

## Where the core chamber sits. Offset per planet so a straight dive down the
## centre is a real route rather than the only one, and so "the core is
## directly below the pad" never becomes something the player can assume.
var core_x: int = 0


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
	return fill[idx(x, d)]


## The ONE definition of passable, shared by collision, the flood and the drill.
## A cell is passable only when it is fully cut: a half-cut cell you can fly
## through is a cell that never breaks and never pays.
func is_open(x: int, d: int) -> bool:
	return fill_at(x, d) <= Tuning.OPEN_FILL


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
	fill.resize(n)
	seam.resize(n)

	# 1. Rock, ore and seams. Ore rolls on SEED_ORE and the seam texture rolls
	#    on SEED_SEAM, and the seam roll is read once and used for BOTH the
	#    texture and the payout, so the wall cannot lie about what it pays.
	for d in range(-Tuning.SURFACE_ROWS, Tuning.CORE_DEPTH + 1):
		for x in range(-Tuning.HALF_WIDTH, Tuning.HALF_WIDTH + 1):
			var i := idx(x, d)
			if d < 0:
				mat[i] = Ore.AIR
				fill[i] = 0.0
				seam[i] = 0
				continue
			mat[i] = Ore.roll(float(d), _roll(x, d, Tuning.SEED_ORE))
			fill[i] = 1.0
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
			if _roll(x, d, Tuning.SEED_CAVERN) < Tuning.CAVERN_CHANCE:
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
				fill[i] = 0.0
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
			fill[i] = 0.0
			seam[i] = 0
	var ci := idx(core_x, cd)
	mat[ci] = Ore.CORE
	fill[ci] = 1.0


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
	if fill[i] <= 0.0:
		return out

	var hardness := Tuning.hardness_at(float(d))
	var m := int(mat[i])
	# The core takes far longer than anything else and it is meant to: the cut
	# is the tell that the extraction is about to start.
	if m == Ore.CORE:
		hardness *= 6.0

	var removed: float = minf(hp / hardness, fill[i])
	fill[i] -= removed
	out["cut"] = removed * hardness      ## hit points actually spent, for the power charge

	if fill[i] > 0.0:
		return out

	fill[i] = 0.0
	out["broke"] = true
	out["mat"] = m
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


# ── reading the shape, for the light flood and the contour ────────────────

## The corner value the contour interpolates: the mean fill of the four cells
## meeting at that corner. Out of bounds counts as solid at the sides so the
## world's edge is a wall rather than a cliff the surface falls off.
func corner_fill(x: int, d: int) -> float:
	return 0.25 * (fill_at(x - 1, d - 1) + fill_at(x, d - 1) + fill_at(x - 1, d) + fill_at(x, d))


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
