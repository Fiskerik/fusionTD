extends SceneTree

const ORDER: Array[String] = ["water", "light", "electric", "nature", "dark", "fire"]
var site_order: Array[String] = []
var runs: int = 20
var first_seed: int = 1
var max_wave: int = 60
var forced_tier: int = 0
var forced_wave: int = 0
var fusion: bool = true

func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < arguments.size():
		var option: String = arguments[i]
		if option == "--no-fusion":
			fusion = false
			i += 1
			continue
		if option not in ["--runs", "--seed", "--force-trial", "--max-wave"] or i + 1 == arguments.size():
			printerr("Usage: --runs N --seed N [--max-wave N] [--force-trial TIER:WAVE] [--no-fusion]")
			quit(2)
			return
		var value: String = arguments[i + 1]
		match option:
			"--runs": runs = int(value)
			"--seed": first_seed = int(value)
			"--max-wave": max_wave = int(value)
			"--force-trial":
				var pair: PackedStringArray = value.split(":")
				if pair.size() == 2:
					forced_tier = int(pair[0])
					forced_wave = int(pair[1])
				if forced_tier < 1 or forced_tier > 3 or forced_wave < 4:
					printerr("Invalid forced trial. Use tier 1–3 and wave 4 or later.")
					quit(2)
					return
		i += 2
	if runs <= 0 or max_wave <= 0:
		quit(2)
		return
	call_deferred("_main")

func _main() -> void:
	_rank_sites()
	var reports: Array[Dictionary] = []
	for seed_value: int in range(first_seed, first_seed + runs):
		var report: Dictionary = _play(seed_value)
		reports.append(report)
		print("RUN ", JSON.stringify(report))
	var waves: Array = reports.map(func(report: Dictionary) -> int: return int(report.cleared))
	waves.sort()
	var median: float = (float(waves[floori((runs - 1) / 2.0)]) + float(waves[floori(runs / 2.0)])) * .5
	print("SUMMARY ", JSON.stringify({"runs": runs, "median_wave": median, "fusion": fusion, "forced_wave": forced_wave, "forced_tier": forced_tier}))
	quit()

func _rank_sites() -> void:
	var track := Track.new()
	var coverage: Dictionary = {}
	for slot: String in track.reference_slots:
		var count: int = 0
		for sample: int in range(floori(track.total * 10.0) + 1):
			if track.at(sample * .1).distance_squared_to(track.slots[slot].position) <= 9.0:
				count += 1
		coverage[slot] = count
		site_order.append(slot)
	site_order.sort_custom(func(a: String, b: String) -> bool:
		return int(coverage[a]) > int(coverage[b]) if coverage[a] != coverage[b] else int(a.substr(1)) < int(b.substr(1))
	)

func _play(seed_value: int) -> Dictionary:
	var sim := Sim.new(seed_value)
	var lives: Array[int] = []
	var gold: Array[int] = []
	var trials: Dictionary = {}
	var bosses: Dictionary = {}
	var forced_used: bool = false
	while sim.state.phase == "build" and int(sim.state.wave) <= max_wave:
		var wave: int = sim.state.wave
		_choose(sim)
		if wave == forced_wave and not forced_used:
			forced_used = true
			var element: String = "water"
			sim.state.tiers[element] = maxi(int(sim.state.tiers[element]), forced_tier - 1)
			sim.state.trial = {"element": element, "tier": forced_tier}
		var bonus: bool = not sim.state.trial.is_empty()
		if bonus:
			trials[str(wave)] = {"tier": sim.state.trial.tier, "element": sim.state.trial.element, "killed": false, "leaked": false}
		_spend(sim)
		if not bonus:
			gold.append(sim.state.gold)
		var preview: Dictionary = sim.preview(wave)
		if not preview.bosses.is_empty():
			bosses[str(wave)] = {"killed": false, "defeated": 0, "total": preview.bosses.size()}
		sim.apply({"type": "start_wave"})
		while sim.state.phase == "wave":
			sim.step()
			for event: Dictionary in sim.events:
				match event.type:
					"tower_stunned":
						sim.apply({"type": "rally", "slot": event.data.slot})
					"element_unlocked":
						trials[str(wave)].killed = bool(event.data.defeated)
					"mob_leaked":
						var hp_fraction: float = float(event.data.hp) / float(event.data.max_hp)
						if event.data.kind == "boss":
							var record: Dictionary = bosses[str(wave)]
							record.remaining = maxf(float(record.get("remaining", 0.0)), snappedf(hp_fraction, .001))
						elif event.data.kind == "spirit":
							trials[str(wave)].leaked = true
							trials[str(wave)].remaining = snappedf(hp_fraction, .001)
					"mob_killed":
						if event.data.kind == "boss":
							var record: Dictionary = bosses[str(wave)]
							record.defeated += 1
							record.killed = int(record.defeated) == int(record.total)
			sim.events.clear()
		if not bonus:
			lives.append(sim.state.lives)
	return {"seed": seed_value, "cleared": int(sim.state.wave) - 1, "lives": lives, "gold": gold, "trials": trials, "bosses": bosses, "fusions": sim.state.stats.fusions}

func _choose(sim: Sim) -> void:
	if not sim.state.selection_pending:
		return
	var options: Array[Dictionary] = sim.choices()
	for tier: int in range(1, 4):
		for element: String in ORDER:
			if options.has({"element": element, "tier": tier}):
				sim.apply({"type": "select_element", "element": element, "tier": tier})
				return

func _spend(sim: Sim) -> void:
	var wave: int = sim.state.wave
	var reserve: int = 40 if wave > 10 else 0
	if wave <= 8:
		for slot: String in site_order:
			if sim.state.towers.size() >= 6:
				break
			_purchase(sim, {"type": "build", "slot": slot, "kind": "arrow"}, reserve)
	for level: int in range(1, 3):
		for tower: Dictionary in sim.ordered_towers():
			if tower.kind in ["arrow", "cannon"] and int(tower.level) == level:
				_purchase(sim, {"type": "upgrade", "slot": tower.slot}, reserve)
	if fusion:
		_fuse(sim, reserve)
	for element: String in ORDER:
		if int(sim.state.tiers[element]) == 0:
			continue
		var pure: Dictionary = {}
		for tower: Dictionary in sim.state.towers.values():
			if tower.kind == "pure" and tower.element == element:
				pure = tower
				break
		if pure.is_empty():
			for slot: String in site_order:
				if _purchase(sim, {"type": "build", "slot": slot, "kind": element}, reserve):
					pure = sim.state.towers[slot]
					break
		while not pure.is_empty() and _purchase(sim, {"type": "upgrade", "slot": pure.slot}, reserve):
			pass
	if fusion:
		_fuse(sim, reserve)
	for level: int in range(1, 6):
		for slot: String in site_order:
			if int(sim.state.towers.get(slot, {}).get("level", 0)) == level:
				_purchase(sim, {"type": "upgrade", "slot": slot}, reserve)
	var forecast: Dictionary = sim.preview(wave)
	for tower: Dictionary in sim.ordered_towers():
		if tower.kind not in ["arrow", "cannon"] or int(tower.level) < 3 or tower.infusion != "":
			continue
		var score: float = 0.0
		var chosen: String = ""
		for element: String in ORDER:
			if int(sim.state.tiers[element]) == 0:
				continue
			var benefit: float = 1.0
			for group: Dictionary in forecast.groups:
				benefit += (Damage.matchup(element, group.element) - 1.0) * int(group.count)
			for special: String in ["boss", "spirit"]:
				if not forecast[special].is_empty():
					benefit += (Damage.matchup(element, forecast[special].element) - 1.0) * 15.0
			if benefit > score:
				score = benefit
				chosen = element
		if chosen != "":
			_purchase(sim, {"type": "infuse", "slot": tower.slot, "element": chosen}, reserve)
	for slot: String in site_order:
		_purchase(sim, {"type": "build", "slot": slot, "kind": "cannon" if sim.state.towers.size() % 2 == 0 else "arrow"}, reserve)

func _fuse(sim: Sim, reserve: int) -> void:
	for origin: String in site_order:
		var dual: Dictionary = sim.state.towers.get(origin, {})
		if dual.get("kind") != "dual":
			continue
		for site: String in site_order:
			if _purchase(sim, {"type": "fuse", "slot_a": origin, "slot_b": site}, maxi(reserve, 100)):
				return
	var owned: Dictionary = {}
	for tower: Dictionary in sim.state.towers.values():
		if tower.kind == "dual":
			owned[tower.dual] = true
	for id: String in DataDB.read("duals"):
		if owned.has(id):
			continue
		var pair: Array = DataDB.read("duals")[id].pair
		for a: String in site_order:
			var first: Dictionary = sim.state.towers.get(a, {})
			if first.get("kind") != "pure" or not pair.has(first.element):
				continue
			for b: String in site_order:
				var second: Dictionary = sim.state.towers.get(b, {})
				if second.get("kind") == "pure" and pair.has(second.element):
					if _purchase(sim, {"type": "fuse", "slot_a": a, "slot_b": b}, maxi(reserve, 100)):
						return

func _purchase(sim: Sim, action: Dictionary, reserve: int) -> bool:
	# Compare balance against the same sites and timing used in the original runs.
	if action.type == "build" and int(sim.track.slots[action.slot].reference_wave) > int(sim.state.wave):
		return false
	var info: Dictionary = sim.describe(action)
	return info.ok and int(sim.state.gold) >= int(info.cost) + reserve and bool(sim.apply(action).ok)
