extends SceneTree

## What the per-cell-change work actually costs today, so any proposal to make
## the grid finer can be priced instead of guessed at.


func _initialize() -> void:
	var w := World.new(1)
	# A dug-out region, which is the worst case for the flood: an empty window
	# means every cell is reachable and the frontier never stops growing.
	for d in range(20, 60):
		for x in range(-18, 19):
			w.set_fill(x, d, 0.0)
			w.mat[w.idx(x, d)] = Ore.AIR

	var t := Time.get_ticks_usec()
	for _i in range(20):
		Light.flood(w, 0, 40)
	var flood := float(Time.get_ticks_usec() - t) / 20000.0

	t = Time.get_ticks_usec()
	for _i in range(20):
		Light.fan(w, Vector2(0.0, 40.0), 12.6)
	var fan := float(Time.get_ticks_usec() - t) / 20000.0

	var field := Light.flood(w, 0, 40)
	t = Time.get_ticks_usec()
	for _i in range(20):
		Light.spill(w, field, 0, 40)
	var spill := float(Time.get_ticks_usec() - t) / 20000.0

	print("per solve, on a fully open window (the worst case):")
	print("  flood  %.2f ms   over a %dx%d window" % [flood, Light.SIDE, Light.SIDE])
	print("  spill  %.2f ms" % spill)
	print("  fan    %.2f ms   %d rays" % [fan, Light.RAYS])
	print("  total  %.2f ms, against 16.7 ms for a 60 fps frame" % [flood + spill + fan])
	print("")
	# And the mesh, which is the thing that would get 16x more expensive if the
	# contour lattice got four times finer.
	var terrain := Terrain.new()
	terrain.setup(w, null)
	t = Time.get_ticks_usec()
	for i in range(10):
		terrain.touch()
		terrain.refresh(Vector2i(0, 40 + i), 15, 24)
	var mesh := float(Time.get_ticks_usec() - t) / 10000.0
	print("  mesh   %.2f ms   %d vertices over a 31x49 cell window" % [mesh, terrain.vertex_count])
	print("")
	print("what a finer contour lattice would cost, per rebuild:")
	for sub in [2, 4]:
		print("  %.2f m cells: about %.1f ms of mesh, and a rebuild every %.2f m instead of 1 m"
			% [1.0 / float(sub), mesh * float(sub * sub), 1.0 / float(sub)])
	terrain.free()
	quit(0)
