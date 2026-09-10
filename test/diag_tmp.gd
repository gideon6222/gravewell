extends SceneTree

func _initialize() -> void:
	var sim := Sim.new(9)
	var p := Policies.new(9)
	var dt := 1.0 / 60.0
	for _i in range(int(45.0 / dt)):
		if sim.phase == Sim.Phase.OVER:
			break
		var a := p.act(Policies.GREEDY, sim, dt)
		if bool(a["uplink"]):
			sim.uplink()
			continue
		sim.step(a["dir"], bool(a["drilling"]), dt)

	var cell := Vector2i(int(roundf(sim.flight.pos.x)), int(roundf(sim.flight.pos.y)))
	print("ship at ", sim.flight.pos, " cell ", cell, " reach ", sim.lamp_reach())
	var flood := Light.flood(sim.world, cell.x, cell.y)
	var spill := Light.spill(sim.world, flood, cell.x, cell.y)
	print("      x:  ", range(-6, 7))
	for d in range(-6, 7):
		var row := ""
		for x in range(-6, 7):
			var open := sim.world.is_open(cell.x + x, cell.y + d)
			var v := Light.at(spill, x, d)
			row += ("%s%4d " % ["." if open else "#", int(v * 100.0)])
		print("d=%3d %s" % [d, row])
	quit(0)
