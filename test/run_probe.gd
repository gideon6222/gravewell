extends SceneTree

## A balance probe, not a test. **Nothing here can fail.**
##
##   godot --headless --path . --script res://test/run_probe.gd
##
## A test says whether the game still does what it did. This says what the game
## currently IS, and it is the file that answers the question he asked by name:
## "is there a way for you to add some kind of log to see how fast certain
## things drain, if the cost is worth the benefit, or if certain abilities don't
## really seem to be necessary?" - with both of his acceptance criteria attached,
## that it costs the game nothing and that it is actually helpful.
##
## **A single planet is not a calibration.** Scripted policies swing about 25%
## planet to planet on layout luck alone, so every number below is a mean over
## six seeds. Numbers marked in the table as a mean are the only ones worth
## quoting back.
##
## **If two policies score the same, one of them is not testing anything**, and
## that is the single most useful signal this file produces.

const SEEDS := [1, 2, 3, 4, 5, 6]
const SECONDS := 240.0


func _initialize() -> void:
	_policy_table()
	_descent_shape()
	_power_budget()
	_filament_supply()
	quit(0)


func _policy_table() -> void:
	print("")
	print("  POLICIES  (mean of %d planets, %.0f s each)" % [SEEDS.size(), SECONDS])
	print("  %-9s %9s %9s %8s %9s   %s" % ["policy", "credits", "deepest", "filam", "time", "ended"])
	print("  %s" % "-".repeat(72))
	for name in Policies.ALL:
		var credits := 0.0
		var deepest := 0.0
		var filam := 0.0
		var t := 0.0
		var ends := {}
		for s in SEEDS:
			var r := Policies.run(name, s, SECONDS)
			credits += float(r["credits"])
			deepest += float(r["deepest"])
			filam += float(r["filament"])
			t += float(r["time"])
			var why: String = r["outcome"] if r["outcome"] != "" else "still going"
			ends[why] = int(ends.get(why, 0)) + 1
		var n := float(SEEDS.size())
		print("  %-9s %9.0f %9.1f %8.1f %9.1f   %s" % [
			name, credits / n, deepest / n, filam / n, t / n, str(ends)])
	print("")


## How long a descent actually takes, which is the number the whole structure
## rests on: a planet has to be one sitting, and PLAN.md says the core depth is
## provisional until this measures it.
func _descent_shape() -> void:
	print("  DESCENT SHAPE  (a diver, straight down, nothing else)")
	print("  %-9s %9s %9s %9s" % ["seed", "reached", "seconds", "m/s"])
	print("  %s" % "-".repeat(42))
	var total_rate := 0.0
	for s in SEEDS:
		var sim := Sim.new(s)
		var dt := 1.0 / 60.0
		var t := 0.0
		while sim.phase == Sim.Phase.DESCENT and t < 900.0:
			sim.step(Vector2(0, 1), true, dt)
			t += dt
		var rate: float = sim.deepest / maxf(t, 0.001)
		total_rate += rate
		print("  %-9d %9.1f %9.1f %9.2f" % [s, sim.deepest, t, rate])
	var mean_rate := total_rate / float(SEEDS.size())
	print("  mean %.2f m/s -> a full %d m descent is about %.0f s of pure digging"
		% [mean_rate, Tuning.CORE_DEPTH, float(Tuning.CORE_DEPTH) / maxf(mean_rate, 0.001)])
	print("  target from PLAN.md: five to ten minutes with ore detours and uplinks.")
	print("")


## Where the power goes. He asks this kind of question about numbers he is told,
## so the numbers should be measured before he does.
func _power_budget() -> void:
	print("  POWER BUDGET  (a cautious descent, mean of %d planets)" % SEEDS.size())
	var drill := 0.0
	var thrust := 0.0
	var lamp := 0.0
	var carry := 0.0
	var uplinks := 0.0
	var n := 0.0
	for s in SEEDS:
		var sim := Sim.new(s)
		var p := Policies.new(s)
		var dt := 1.0 / 60.0
		var last := sim.power
		var t := 0.0
		while sim.phase == Sim.Phase.DESCENT and t < SECONDS:
			var a := p.act(Policies.CAUTIOUS, sim, dt)
			if bool(a["uplink"]):
				var before := sim.power
				sim.uplink()
				uplinks += before - sim.power
				last = sim.power
				continue
			var held: bool = a["dir"].length_squared() > 0.001
			sim.step(a["dir"], bool(a["drilling"]), dt)
			var spent := last - sim.power
			last = sim.power
			# Attribute what is knowable exactly; the rest is the drill.
			var l: float = Tuning.LAMP_DRAIN[sim.lamp_mode] * dt
			var th: float = (Tuning.POWER_PER_THRUST_S * dt) if held else 0.0
			var ca: float = Tuning.POWER_PER_KG_S * sim.load_kg * dt
			lamp += l
			thrust += th
			carry += ca
			drill += maxf(spent - l - th - ca, 0.0)
			t += dt
		n += 1.0
	var total: float = maxf(drill + thrust + lamp + carry + uplinks, 0.001)
	print("  %-10s %9s %7s" % ["source", "power", "share"])
	print("  %s" % "-".repeat(30))
	for row in [["drill", drill], ["thrust", thrust], ["lamp", lamp], ["carrying", carry], ["uplinks", uplinks]]:
		print("  %-10s %9.1f %6.1f%%" % [row[0], float(row[1]) / n, float(row[1]) / total * 100.0])
	print("")


## Filament is the only thing that buys a counter to a threat, so its supply is
## the single most important number in the economy. Too little and survival
## cannot be bought at any price; too much and it is just another currency.
func _filament_supply() -> void:
	print("  FILAMENT  (what is in the ground, per planet)")
	print("  %-9s %8s %10s %10s" % ["seed", "caches", "above Line", "below Line"])
	print("  %s" % "-".repeat(42))
	var total := 0.0
	for s in SEEDS:
		var w := World.new(s)
		var above := 0
		var below := 0
		var caches := 0
		for d in range(0, Tuning.CORE_DEPTH):
			for x in range(-Tuning.HALF_WIDTH, Tuning.HALF_WIDTH + 1):
				if w.material_at(x, d) != Ore.CACHE:
					continue
				caches += 1
				var f: int = Tuning.CACHE_FILAMENT[Tuning.band_at(float(d))]
				if d < Tuning.LINE_DEPTH:
					above += f
				else:
					below += f
		total += float(above + below)
		print("  %-9d %8d %10d %10d" % [s, caches, above, below])
	print("  mean total filament a planet: %.1f" % (total / float(SEEDS.size())))
	print("  a Line counter should cost a meaningful fraction of that, never all of it.")
	print("")
