extends "res://tests/test_base.gd"

func test_data_and_map() -> void:
	equal(DataDB.validate(), PackedStringArray(), "All tables and all 15 duals must be valid")
	var track := Track.new()
	near(track.total, 33.0)
	for slot: Dictionary in track.slots.values():
		var point: Vector2 = slot.position
		for s: int in range(34):
			check(track.at(s).distance_to(point) >= 1.0, "Build site outside path")

func test_matchups_and_armor() -> void:
	var matrix: Array = [
		[1, .75, 1.5, 1, 1, 1, 1], [1.5, 1, 1, .75, 1, 1, 1],
		[.75, 1, 1, 1.5, 1, 1, 1], [1, 1.5, .75, 1, 1, 1, 1],
		[1, 1, 1, 1, .75, 1.5, 1], [1, 1, 1, 1, 1.5, .75, 1],
		[1, 1, 1, 1, 1, 1, 1],
	]
	var offense: Array = DataDB.ELEMENTS + ["normal"]
	var defense: Array = DataDB.ELEMENTS + ["none"]
	for row: int in range(offense.size()):
		for col: int in range(defense.size()):
			near(Damage.matchup(offense[row], defense[col]), matrix[row][col])
	var dual: Dictionary = DataDB.read("duals")
	near(Damage.blend(dual.steam.split, "fire"), 1.25)
	near(Damage.blend(dual.steam.split, "water"), .875)
	near(Damage.blend(dual.flare.split, "nature"), 1.3)
	near(Damage.blend(dual.flare.split, "dark"), 1.2)
	near(Damage.blend(dual.flare.split, "light"), .9)
	near(Damage.hit(10, 200, 0, 0, 0), 2.5)
	near(Damage.hit(20, 12, .5, 2, .25), 21)

func test_wave_generation_and_preview() -> void:
	var orders: Array = ["warlock", "ram", "necromancer", "prismheart", "tempest", "ironwood"]
	var last_family: String = ""
	for index: int in range(60):
		var wave: int = index + 1
		var output: Dictionary = Waves.generate(42, wave)
		equal(output, Waves.generate(42, wave))
		if wave % 10 == 0:
			check(output.groups.is_empty(), "Bosses spawn without a regular escort")
			equal(output.boss.boss_type, orders[int(float(wave) / 10.0 - 1)])
			equal(output.boss.gold, 225 + 15 * wave)
			if output.boss.has("weakness"):
				check((DataDB.ELEMENTS + ["normal"]).has(output.boss.weakness))
				near(Damage.against({output.boss.weakness: 1.0}, output.boss, false), Damage.weakness_multiplier(output.boss))
		else:
			check(output.boss.is_empty())
			check(output.groups[0].family != last_family, "Each consecutive regular wave has a different enemy family")
			last_family = output.groups[0].family
		for group: Dictionary in output.groups:
			if wave < 6:
				equal(group.element, "none")
				check(not group.has("weakness"))
			if wave < 16:
				check(group.element not in ["light", "dark"])
	var sim := Sim.new()
	sim.state.wave = 10
	var forecast: Dictionary = sim.preview(10)
	sim.apply({"type": "start_wave"})
	var boss: Array = sim.state.spawn_queue.filter(func(entry: Dictionary) -> bool: return entry.group.kind == "boss")
	equal(boss[0].group, forecast.boss)
	var total: int = 1
	for group: Dictionary in forecast.groups:
		total += int(group.count)
	equal(sim.state.spawn_queue.size(), total)

func test_wave_weaknesses_vary_by_seed_and_stay_fixed_in_combat() -> void:
	var neutral_rolls: Dictionary = {}
	var boss_rolls: Dictionary = {}
	for seed_value: int in range(1, 25):
		var by_affinity: Dictionary = {}
		for group: Dictionary in Waves.generate(seed_value, 18).groups:
			check(DataDB.ELEMENTS.has(group.weakness))
			check(group.weakness != group.element)
			equal(group.weakness, by_affinity.get(group.element, group.weakness))
			by_affinity[group.element] = group.weakness
		neutral_rolls[by_affinity.none] = true
		boss_rolls[Waves.generate(seed_value, 20).boss.weakness] = true
	check(neutral_rolls.size() > 1 and boss_rolls.size() > 1, "Regular and boss weaknesses vary across campaign seeds")
	var sim := Sim.new(42)
	sim.state.wave = 18
	var forecast: Dictionary = sim.preview(18)
	check(sim.apply({"type": "start_wave"}).ok)
	while sim.state.mobs.is_empty():
		sim.step()
	equal(sim.state.mobs[0].weakness, forecast.groups[0].weakness)
	var restored: Sim = SaveStore.decode(SaveStore.encode(sim).duplicate(true))
	equal(restored.state.mobs[0].weakness, forecast.groups[0].weakness)
	equal(restored.preview(18), forecast)
	var before_rollout: Dictionary = SaveStore.encode(sim).duplicate(true)
	before_rollout.state.erase("wave_has_rolled_weaknesses")
	for enemy: Dictionary in before_rollout.state.mobs:
		enemy.erase("weakness")
	for entry: Dictionary in before_rollout.state.spawn_queue:
		entry.group.erase("weakness")
	var legacy: Sim = SaveStore.decode(before_rollout)
	check(not legacy.preview(18).groups[0].has("weakness"), "In-progress legacy waves keep their original matchups")
	check(legacy.preview(19).groups[0].has("weakness"))
	var spirit: Dictionary = Waves.generate(42, 18, {"element": "fire", "tier": 2}).spirit
	check(not spirit.has("weakness"))
	equal(Damage.weakness(spirit), "water")

func test_endgame_wave_budget_and_boss_lineup() -> void:
	var families: Dictionary = {}
	for wave: int in range(20, 111):
		var preview: Dictionary = Waves.generate(42, wave)
		for group: Dictionary in preview.groups:
			if group.kind != "bonus":
				families[group.family] = true
				check(DataDB.read("mobs").families[group.family].appears_from <= wave)
		if wave <= 60:
			continue
		var total: int = preview.bosses.size()
		for group: Dictionary in preview.groups:
			total += int(group.count)
			check(not group.props.has("splitter") and not group.props.has("revenant"))
		check(total <= 96, "Bosses count toward the endgame unit cap")
	equal(families.size(), 20)
	for wave: int in [60, 70, 80, 90, 100]:
		var sim := Sim.new(42)
		sim.state.wave = wave
		var forecast: Array = sim.preview(wave).bosses
		equal(forecast.size(), 1 if wave == 60 else (2 if wave < 90 else 3))
		check(sim.apply({"type": "start_wave"}).ok)
		var queued: Array = sim.state.spawn_queue.filter(func(entry: Dictionary) -> bool: return entry.group.kind == "boss")
		equal(queued.size(), forecast.size())
		for i: int in range(queued.size()):
			equal(queued[i].group, forecast[i])
			if i > 0:
				check(int(queued[i].tick) > int(queued[i - 1].tick))
	near(EnemyRules.control_resistance(49), 0)
	near(EnemyRules.control_resistance(50), .01)
	near(EnemyRules.control_resistance(80), .31)
	near(EnemyRules.control_resistance(120), .70)

func test_legacy_active_wave_gains_tenacity_on_resume() -> void:
	var sim := Sim.new()
	sim.state.wave = 80
	sim.state.phase = "wave"
	var group: Dictionary = Waves.generate(42, 81).groups[0].duplicate()
	group.erase("control_resistance")
	group.erase("armor_rank")
	Combat.spawn(sim, group, 6.0)
	sim.state.mobs[0].erase("control_resistance")
	sim.state.mobs[0].erase("armor_rank")
	sim.schedule(group, 100)
	var restored: Sim = SaveStore.decode(SaveStore.encode(sim).duplicate(true))
	near(restored.state.mobs[0].s, 6.0)
	near(restored.state.mobs[0].control_resistance, .31)
	equal(restored.state.mobs[0].armor_rank, 4)
	near(restored.state.spawn_queue[0].group.control_resistance, .31)
	equal(restored.pure_crystals(), 2)

func test_later_enemy_formations_mix_elements_and_pressure() -> void:
	var data: Dictionary = DataDB.read("balance")
	var base_hp: float = DataDB.read("mobs").hp
	for seed_value: int in range(1, 6):
		var shield_round: Dictionary = Waves.generate(seed_value, 8)
		check(shield_round.groups.any(func(group: Dictionary) -> bool: return group.props.has("phasing")))
		var formation: Dictionary = Waves.generate(seed_value, 11)
		var elements: Dictionary = {}
		var speeds: Dictionary = {}
		var armors: Dictionary = {}
		for group: Dictionary in formation.groups:
			if group.kind == "bonus":
				continue
			if group.element != "none":
				elements[group.element] = true
			speeds[group.speed] = true
			armors[group.armor] = true
			if group.props.is_empty():
				check(float(group.hp) > base_hp * pow(float(data.mob_hp_growth), 10))
				near(group.speed, 1.0, "Ordinary enemies keep their movement speed")
				check(float(group.armor) > 0.0)
			elif group.props.has("swift"):
				check(float(group.speed) > 1.3 and float(group.hp) < Waves.base_enemy_hp(11) * .75)
		equal(elements.size(), 2)
		check(speeds.size() > 1 and armors.size() > 1)

func test_wave_20_boss_health_reduction() -> void:
	var adjustment: Dictionary = DataDB.read("bosses").health_adjustment
	var multiplier: float = adjustment.multiplier
	for wave: int in [10, 20, 30, 70, 90]:
		var reduced: Dictionary = Waves.generate(42, wave)
		adjustment.multiplier = 1.0
		var original: Dictionary = Waves.generate(42, wave)
		adjustment.multiplier = multiplier
		equal(reduced.groups, original.groups)
		equal(reduced.bosses.size(), original.bosses.size())
		for i: int in range(reduced.bosses.size()):
			near(float(reduced.bosses[i].hp) / float(original.bosses[i].hp), 1.0 if wave == 10 else .8)

func test_wave_10_health_increase_keeps_enemy_counts() -> void:
	var boost: Dictionary = DataDB.read("waves").health_boost
	var multiplier: float = boost.multiplier
	for wave: int in [9, 10, 11, 48, 90]:
		var boosted: Dictionary = Waves.generate(42, wave)
		boost.multiplier = 1.0
		var original: Dictionary = Waves.generate(42, wave)
		boost.multiplier = multiplier
		var expected: float = 1.0 if wave < 10 else 1.2
		var boosted_enemies: Array = boosted.groups + boosted.bosses
		var original_enemies: Array = original.groups + original.bosses
		equal(boosted_enemies.size(), original_enemies.size())
		for index: int in range(boosted_enemies.size()):
			equal(boosted_enemies[index].count, original_enemies[index].count)
			near(boosted_enemies[index].hp / original_enemies[index].hp, expected)

func test_wave_48_caps_seeded_formation_spikes() -> void:
	var adjustments: Dictionary = DataDB.read("waves").adjustments
	var patch: Dictionary = adjustments["48"]
	for seed_value: int in range(1, 65):
		var tuned: Dictionary = Waves.generate(seed_value, 48)
		var neighbors: Array = [Waves.generate(seed_value, 47), Waves.generate(seed_value, 49), Waves.generate(seed_value, 50)]
		adjustments.erase("48")
		var original: Dictionary = Waves.generate(seed_value, 48)
		var baseline: Array = [Waves.generate(seed_value, 47), Waves.generate(seed_value, 49), Waves.generate(seed_value, 50)]
		adjustments["48"] = patch
		equal(neighbors, baseline, "Wave 48 tuning must leave its neighbors and the next boss unchanged")
		var tuned_hp: float = 0.0
		for group: Dictionary in tuned.groups:
			tuned_hp += float(group.hp) * int(group.count)
			check(group.props.is_empty() or group.props == ["armored"] or group.props == ["swift"])
		var original_hp: float = 0.0
		for group: Dictionary in original.groups:
			original_hp += float(group.hp) * int(group.count)
		check(tuned_hp <= original_hp * .9, "Wave 48 has lower total HP on seed %d" % seed_value)

func test_economy_and_undo() -> void:
	var sim := Sim.new()
	var original: int = sim.state_hash()
	check(sim.apply({"type": "build", "slot": "s1", "kind": "arrow"}).ok)
	equal(sim.state.gold, int(sim.cfg.start_gold) - 50)
	check(not sim.apply({"type": "build", "slot": "tile_0_1", "kind": "arrow"}).ok)
	equal(sim.apply({"type": "upgrade", "slot": "s1"}).cost, 40)
	equal(sim.state.towers.s1.invested, 90)
	equal(Economy.refund(90), 67)
	equal(Economy.clear_reward(1, 30000), Economy.scaled(sim.cfg.wave_clear_bonus, 1) + 15)
	check(sim.apply({"type": "sell", "slot": "s1"}).ok)
	equal(sim.state.gold, int(sim.cfg.start_gold) - 90 + 67)
	for i: int in range(3):
		check(sim.apply({"type": "undo"}).ok)
	equal(sim.state_hash(), original)

func test_place_on_any_open_tile() -> void:
	var sim := Sim.new()
	var corner: String = sim.track.slot_at(Vector2(.1, .1))
	equal(corner, "tile_0_0")
	equal(sim.track.slot_at(Vector2(.99, .99)), corner)
	equal(sim.track.slot_at(Vector2(-.1, .5)), "")
	equal(sim.track.slot_at(Vector2(.2, 1.5)), "", "The road is occupied by the enemy route")
	equal(sim.track.slot_at(Vector2(6.5, 3.5)), "s1", "Existing saved pad ID")
	check(sim.apply({"type": "build", "slot": corner, "kind": "arrow"}).ok)
	check(not sim.apply({"type": "build", "slot": corner, "kind": "arrow"}).ok)
	check(sim.apply({"type": "build", "slot": "s16", "kind": "cannon"}).ok, "Old pads no longer need unlocking")

func test_play_through_first_trial_and_selection_gate() -> void:
	var sim := Sim.new()
	var sites: Array = ["s1", "s2", "s3", "s5", "s7"]
	for wave: int in range(1, 6):
		while sim.state.towers.size() < sites.size() and int(sim.state.gold) >= 50:
			var slot: String = sites[sim.state.towers.size()]
			check(sim.apply({"type": "build", "slot": slot, "kind": "arrow"}).ok)
		equal(sim.state.selection_pending, wave == 5)
		if wave == 5:
			check(sim.state.selection_pending)
			check(not sim.apply({"type": "start_wave"}).ok)
			check(not sim.apply({"type": "skip_selection"}).ok)
			check(not sim.apply({"type": "select_element", "element": "water", "tier": 2}).ok)
			check(sim.apply({"type": "select_element", "element": "water", "tier": 1}).ok)
			equal(sim.preview(5).spirit.element, "water")
			check(sim.apply({"type": "start_wave"}).ok)
			_finish(sim)
			equal(sim.state.wave, 5, "The bonus round leaves the next regular wave intact")
			equal(sim.state.tiers.water, 1)
			equal(sim.state.lives, 20, "Five level-one Arrows stop the first spirit")
			check(sim.apply({"type": "upgrade", "slot": "s1"}).ok)
		check(sim.apply({"type": "start_wave"}).ok)
		_finish(sim)
		equal(sim.state.wave, wave + 1)
	equal(sim.state.lives, 20, "Opening build order holds the gate")
	equal(sim.state.tiers.water, 1, "Spirit must unlock Water I")
	check(sim.apply({"type": "build", "slot": "s4", "kind": "water"}).ok)

func test_first_spirit_six_cannons() -> void:
	var sim := Sim.new()
	var sites: Array[String] = ["s3", "s4", "s1", "s5", "s6", "s7"]
	for wave: int in range(1, 6):
		while sim.state.towers.size() < sites.size() and int(sim.state.gold) >= 80:
			check(sim.apply({"type": "build", "slot": sites[sim.state.towers.size()], "kind": "cannon"}).ok)
		if wave == 5:
			equal(sim.state.towers.size(), 6, "Opening waves fund six Cannons")
			check(sim.apply({"type": "select_element", "element": "fire", "tier": 1}).ok)
		check(sim.apply({"type": "start_wave"}).ok)
		_finish(sim)
	equal(sim.state.tiers.fire, 1)
	equal(sim.state.lives, 20, "Six cannons should win the trial in a single lap")

func test_bonus_round_has_one_attempt_and_spares_the_regular_boss() -> void:
	var sim := Sim.new()
	sim.state.wave = 10
	sim.state.selection_pending = true
	check(sim.apply({"type": "select_element", "element": "fire", "tier": 1}).ok)
	var forecast: Dictionary = sim.preview(10)
	check(forecast.groups.is_empty() and forecast.boss.is_empty())
	equal(forecast.spirit.count, 1)
	check(sim.apply({"type": "start_wave"}).ok)
	equal(sim.state.spawn_queue.size(), 1)
	while sim.state.mobs.is_empty():
		sim.step()
	equal(sim.state.mobs.size(), 1)
	equal(sim.state.mobs[0].kind, "spirit")
	var reward: int = int(sim.state.gold) + int(sim.state.mobs[0].gold)
	sim.state.mobs[0].s = sim.track.total
	sim.step()
	equal(sim.state.lives, 15)
	equal(sim.state.tiers.fire, 1)
	equal(sim.state.gold, reward)
	equal(sim.state.stats.leaked, 1)
	equal(sim.state.stats.kills, 0)
	equal(sim.state.stats.spirits, 1)
	check(sim.state.mobs.is_empty() and sim.state.trial.is_empty())
	equal(sim.state.wave, 10)
	equal(sim.state.phase, "build")
	check(sim.apply({"type": "start_wave"}).ok)
	check(sim.state.spawn_queue.any(func(e: Dictionary) -> bool: return e.group.kind == "boss"))
	check(not sim.state.spawn_queue.any(func(e: Dictionary) -> bool: return e.group.kind == "spirit"))

func test_leaked_spirit_can_end_run() -> void:
	var sim := Sim.new()
	sim.state.lives = 5
	sim.state.wave = 30
	sim.state.tiers.dark = 2
	sim.state.selection_pending = true
	check(sim.apply({"type": "select_element", "element": "dark", "tier": 3}).ok)
	check(sim.apply({"type": "start_wave"}).ok)
	while sim.state.mobs.is_empty():
		sim.step()
	var reward: int = int(sim.state.gold) + int(sim.state.mobs[0].gold)
	sim.state.mobs[0].s = sim.track.total
	sim.step()
	equal(sim.state.lives, 0)
	equal(sim.state.phase, "game_over")
	equal(sim.state.stats.leaked, 1)
	equal(sim.state.tiers.dark, 3)
	equal(sim.state.gold, reward)
	check(sim.state.trial.is_empty() and sim.state.mobs.is_empty())

func test_focused_fire_can_win_early_tier_two_in_one_pass() -> void:
	var sim := Sim.new(1)
	var opening: Array[String] = ["s1", "s5", "s7", "s2", "s6"]
	for wave: int in range(1, 11):
		for index: int in range(mini(wave + 2, opening.size())):
			var slot: String = opening[index]
			if not sim.state.towers.has(slot):
				check(sim.apply({"type": "build", "slot": slot, "kind": "arrow"}).ok)
		if wave >= 5:
			for slot: String in ["tile_5_3", "tile_3_6"]:
				if not sim.state.towers.has(slot) and not sim.apply({"type": "build", "slot": slot, "kind": "fire"}).ok:
					break
				while sim.apply({"type": "upgrade", "slot": slot}).ok:
					pass
				if int(sim.state.towers[slot].level) < 3:
					break
		if wave == 10:
			# Concentrated damage beats the spirit's armor more efficiently than five small hits.
			for level: int in range(1, 5):
				check(sim.apply({"type": "upgrade", "slot": "s1"}).ok)
			for level: int in range(1, 3):
				check(sim.apply({"type": "upgrade", "slot": "s5"}).ok)
		if wave in [5, 10]:
			var lives_before_trial: int = int(sim.state.lives)
			check(sim.apply({"type": "select_element", "element": "fire", "tier": 1 if wave == 5 else 2}).ok)
			check(sim.apply({"type": "start_wave"}).ok)
			_finish(sim)
			equal(sim.state.wave, wave)
			equal(sim.state.lives, lives_before_trial, "Focused defense kills the early spirit")
		if wave < 10:
			check(sim.apply({"type": "start_wave"}).ok)
			_finish(sim)
	equal(sim.state.tiers.fire, 2)

func test_live_build_upgrade_and_sell() -> void:
	var sim := Sim.new()
	check(sim.apply({"type": "start_wave"}).ok)
	var gold: int = sim.state.gold
	var slot: String = "tile_3_0"
	check(sim.apply({"type": "build", "kind": "arrow", "slot": slot}).ok)
	check(sim.apply({"type": "upgrade", "slot": slot}).ok)
	equal(sim.state.towers[slot].level, 2)
	equal(sim.state.gold, gold - 50 - 40)
	check(not sim.apply({"type": "undo"}).ok)
	check(sim.apply({"type": "sell", "slot": slot}).ok)
	equal(sim.state.gold, gold - 90 + Economy.refund(90))
	check(not sim.state.towers.has(slot))
	equal(sim.state.phase, "wave")

func test_travel_and_life_costs() -> void:
	var sim := Sim.new()
	sim.state.phase = "wave"
	var grunt: Dictionary = Waves.generate(1, 1).groups[0]
	Combat.spawn(sim, grunt, 0)
	for index: int in range(989):
		sim.step()
	equal(sim.state.lives, 20)
	sim.step()
	equal(sim.state.lives, 19)
	sim.state.phase = "wave"
	Combat.spawn(sim, Waves.generate(1, 10).boss, sim.track.total)
	sim.step()
	equal(sim.state.lives, 9)

func test_upgrade_bands_and_infusion() -> void:
	var sim := Sim.new()
	sim.state.gold = 20000
	sim.state.tiers.fire = 1
	check(sim.apply({"type": "build", "kind": "fire", "slot": "s1"}).ok)
	check(sim.apply({"type": "build", "kind": "arrow", "slot": "s2"}).ok)
	var pure: Dictionary = {"type": "upgrade", "slot": "s1"}
	var arrow: Dictionary = {"type": "upgrade", "slot": "s2"}
	var infusion: Dictionary = {"type": "infuse", "slot": "s2", "element": "fire"}
	check(not sim.apply(infusion).ok)
	check(sim.apply(arrow).ok)
	equal(sim.apply(infusion).cost, 100)
	check(not sim.apply(infusion).ok)
	var tower: Dictionary = sim.state.towers.s2
	check("7.5%" in TowerInspector.effects(tower, sim.state.tiers)[0], "The inspector shows the real infused burn potency")
	var view := BattlefieldView.new()
	equal(view._tower_color(tower), Glyphs.hue("fire"), "Infused tower uses its element color")
	view.free()
	equal(TowerRules.trait_profile(tower, sim.state.tiers).burn[0], 5.0)
	for level: int in range(2, 7):
		if level == 3 or level == 5:
			check(not sim.apply(pure).ok)
			sim.state.tiers.fire += 1
		check(sim.apply(pure).ok)
		equal(sim.state.towers.s1.level, level)
	check(not sim.apply(pure).ok)
	for level: int in range(2, 7):
		var tier: int = [0, 1, 1, 2, 2, 3][level - 1]
		equal(TowerRules.infusion_tier(tower.level, 3), tier)
		equal(TowerRules.trait_profile(tower, sim.state.tiers).burn[0], [0.0, 5.0, 8.0, 12.0][tier])
		if level < 6:
			check(sim.apply(arrow).ok)
	check(not sim.apply(arrow).ok)
	sim.state.tiers.water = 2
	equal(sim.apply({"type": "infuse", "slot": "s2", "element": "water"}).cost, 140)
	equal(tower.infusion, "water")
	check(sim.apply({"type": "remove_infusion", "slot": "s2"}).ok)
	equal(tower.infusion, "")
	check(not sim.apply({"type": "remove_infusion", "slot": "s2"}).ok)

func test_checkpoint_and_replay() -> void:
	var path: String = "user://test_checkpoint.dat"
	var sim := Sim.new(4321)
	check(sim.apply({"type": "build", "kind": "arrow", "slot": "s1"}).ok)
	check(sim.apply({"type": "build", "kind": "arrow", "slot": "tile_0_0"}).ok)
	equal(SaveStore.checkpoint(sim, path), OK)
	var restored: Sim = SaveStore.resume(path)
	check(restored != null)
	near(restored.intermission_left, 30.0)
	sim.intermission_left = 13.25
	equal(SaveStore.checkpoint(sim, path), OK)
	near(SaveStore.resume(path).intermission_left, 13.25)
	equal(sim.state_hash(), restored.state_hash())
	equal(sim.undo_stack.size(), restored.undo_stack.size())
	equal(SaveStore.checkpoint(restored, path), OK)
	check(sim.apply({"type": "start_wave"}).ok)
	for i: int in range(75):
		sim.step()
	check(sim.apply({"type": "upgrade", "slot": "s1"}).ok)
	equal(SaveStore.checkpoint(sim, path), OK)
	restored = SaveStore.resume(path)
	check(restored != null)
	equal(sim.state_hash(), restored.state_hash(), "Resume restores the exact active wave and new upgrade")
	for trial: Sim in [sim, restored]:
		_finish(trial)
	equal(sim.state_hash(), restored.state_hash())
	var replay: Sim = Replay.run(4321, sim.history, sim.state.tick)
	check(replay != null)
	equal(replay.state_hash(), sim.state_hash())
	SaveStore.clear(path)
	check(SaveStore.resume(path) == null)

func test_infused_normal_towers_cannot_fuse() -> void:
	var sim := Sim.new()
	sim.state.gold = 20000
	sim.state.tiers.fire = 1
	sim.state.tiers.nature = 1
	check(sim.apply({"type": "start_wave"}).ok)
	for kind: String in ["arrow", "cannon"]:
		var slot: String = "s1" if kind == "arrow" else "s2"
		var element: String = "nature" if kind == "arrow" else "fire"
		check(sim.apply({"type":"build", "slot":slot, "kind":kind}).ok)
		var infusion: Dictionary = {"type":"infuse", "slot":slot, "element":element}
		check(not sim.apply(infusion).ok)
		for level: int in range(2, 7):
			check(sim.apply({"type":"upgrade", "slot":slot}).ok)
			equal(sim.apply(infusion).cost, TowerRules.infusion_cost(1))
			equal(TowerRules.infusion_tier(level, sim.state.tiers[element]), 1)
			check(sim.apply({"type":"remove_infusion","slot":slot}).ok)
		check(sim.apply(infusion).ok)
	var edit: Dictionary = {"type": "fuse", "slot_a": "s2", "slot_b": "s1"}
	var gold: int = sim.state.gold
	check(not sim.apply(edit).ok)
	equal(sim.state.phase, "wave")
	equal(sim.state.towers.s2.infusion, "fire")
	equal(sim.state.towers.s1.infusion, "nature")
	equal(sim.state.gold, gold)
	var pure: Dictionary = TowerRules.create(3, "s3", "pure", "nature", "", 0)
	pure.level = 3
	sim.state.towers.s3 = pure
	check(not sim.apply({"type": "fuse", "slot_a": "s3", "slot_b": "s2"}).ok)
	var dual: Dictionary = TowerRules.fusion_result("steam", "s4", 4)
	dual.level = 3
	sim.state.towers.s4 = dual
	check(not sim.apply({"type": "fuse", "slot_a": "s4", "slot_b": "s1"}).ok)

func test_all_twenty_triples_and_third_element_rules() -> void:
	for id: String in DataDB.read("triples"):
		var elements: Array = DataDB.read("triples")[id].elements
		var sim := Sim.new(33)
		sim.state.gold = 3000
		sim.state.tiers[elements[0]] = 1
		sim.state.tiers[elements[1]] = 1
		sim.state.tiers[elements[2]] = 1
		var dual: Dictionary = TowerRules.fusion_result(TowerRules.recipe(elements[0], elements[1]), "s1", 1, 500)
		var pure: Dictionary = TowerRules.create(2, "s2", "pure", elements[2], "", 145)
		var action: Dictionary = {"type": "fuse", "slot_a": "s1", "slot_b": "s2"}
		sim.state.towers = {"s1": dual, "s2": pure}
		sim.state.next_id = 3
		dual.level = 1
		pure.level = 1
		check(not sim.apply(action).ok, "Third ingredient must reach tower level 2")
		pure.level = 2
		equal(TowerRules.fusion_recipe(dual, pure), id)
		equal(TowerRules.fusion_recipe(pure, dual), id)
		equal(sim.apply(action).cost, 638)
		var result: Dictionary = sim.state.towers.s1
		equal(result.kind, "triple")
		equal(result.dual, id)
		equal(result.invested, 645 + int(sim.cfg.triple_fuse_cost))
		check(not sim.state.towers.has("s2"))
		check(TowerRules.attack_profile(result).damage > 0.0)
		check(not TowerRules.level_requirement(result, sim.state.tiers).is_empty(), "All three Tier II unlocks gate triple level 2")
		for element: String in elements:
			sim.state.tiers[element] = 2
		check(sim.apply({"type": "upgrade", "slot": "s1"}).ok)
		check(not TowerRules.level_requirement(result, sim.state.tiers).is_empty(), "All Tier III unlocks gate triple level 3")
		var loaded: Sim = SaveStore.decode(SaveStore.encode(sim))
		check(loaded != null and TowerRules.stats(loaded.state.towers.s1).name == DataDB.read("triples")[id].name)

func test_fusion_inherits_ingredient_levels_and_hit_damage() -> void:
	var sim := Sim.new()
	sim.state.gold = 100000
	for element: String in DataDB.ELEMENTS:
		sim.state.tiers[element] = 3
	var action: Dictionary = {"type": "fuse", "slot_a": "s1", "slot_b": "s2"}
	for id: String in DataDB.read("duals"):
		var pair: Array = DataDB.read("duals")[id].pair
		for sample: Vector3i in [Vector3i(2, 2, 1), Vector3i(3, 3, 1), Vector3i(4, 4, 2),
			Vector3i(5, 5, 2), Vector3i(6, 6, 3), Vector3i(6, 4, 2)]:
			var first: Dictionary = TowerRules.create(sim.next_id(), "s1", "pure", pair[0], "", 100)
			var second: Dictionary = TowerRules.create(sim.next_id(), "s2", "pure", pair[1], "", 100)
			first.level = sample.x
			second.level = sample.y
			sim.state.towers = {"s1": first, "s2": second}
			check(sim.apply(action).ok, id)
			var result: Dictionary = sim.state.towers.s1
			equal(result.level, sample.z, id)
			var attack: Dictionary = TowerRules.attack_profile(result)
			if float(attack.rate) > 0.0:
				var strongest: float = maxf(TowerRules.attack_profile(first).damage, TowerRules.attack_profile(second).damage)
				check(float(attack.damage) >= strongest - .0001, id + " retains the stronger ingredient's hit")
	for id: String in DataDB.read("triples"):
		var elements: Array = DataDB.read("triples")[id].elements
		var pair: String = TowerRules.recipe(elements[0], elements[1])
		for sample: Vector3i in [Vector3i(2, 2, 1), Vector3i(2, 4, 2), Vector3i(3, 6, 3)]:
			var dual: Dictionary = TowerRules.fusion_result(pair, "s1", sim.next_id())
			var third: Dictionary = TowerRules.create(sim.next_id(), "s2", "pure", elements[2], "", 100)
			dual.level = sample.x
			third.level = sample.y
			sim.state.towers = {"s1": dual, "s2": third}
			check(sim.apply(action).ok, id)
			var result: Dictionary = sim.state.towers.s1
			equal(result.level, sample.z, id)
			var strongest: float = maxf(TowerRules.attack_profile(dual).damage, TowerRules.attack_profile(third).damage)
			check(float(TowerRules.attack_profile(result).damage) >= strongest - .0001, id)
			if sample.z == 3:
				sim.state.tiers[elements[0]] = 2
				sim.state.towers = {"s1": dual, "s2": third}
				check(sim.apply(action).ok and sim.state.towers.s1.level == 2, id + " still requires all Tier III spirits for level 3")
				sim.state.tiers[elements[0]] = 3

func test_water_upgrades_and_elemental_specialties() -> void:
	var sim := Sim.new()
	sim.state.tiers.water = 3
	var water: Dictionary = TowerRules.create(1, "s1", "pure", "water", "", 0)
	var expected_slows: Array[float] = [.15, .1851, .27, .33318, .42, .51828]
	for level: int in range(1, 7):
		water.level = level
		near(Effects.slow_strength(TowerRules.trait_profile(water, sim.state.tiers).slow[0], TowerRules.attack_profile(water).potency), expected_slows[level - 1])
	var storm: Dictionary = TowerRules.fusion_result("storm")
	storm.level = 3
	check(float(TowerRules.trait_profile(storm, sim.state.tiers).slow[0]) * float(TowerRules.attack_profile(storm).potency) > .35)
	var dark: Dictionary = TowerRules.create(2, "s1", "pure", "dark", "", 0)
	near(TowerRules.attack_profile(dark).rate, 2.2)
	near(TowerRules.attack_profile(dark).damage, 5.0)

func test_light_nature_triples_heal_then_shield_the_gate() -> void:
	var sim := Sim.new()
	var ids: Array[String] = ["daystar", "pearllotus", "auroraarbor", "moonorchid"]
	for i: int in range(ids.size()):
		var slot: String = "s%d" % (i + 1)
		sim.state.towers[slot] = TowerRules.fusion_result(ids[i], slot, sim.next_id())
	sim.state.towers.s5 = TowerRules.fusion_result("bloom", "s5", sim.next_id())
	sim.state.lives = 17
	equal(sim.gate_repair_per_cycle(), 2, "Only the strongest life tower contributes")
	for wave: int in range(2, 14):
		sim.state.phase = "wave"
		sim.state.wave = wave
		sim.step()
		equal(sim.state.lives, 19 if wave == 2 else 20)
		equal(sim.state.barrier, clampi((wave - 2) * 2 - 1, 0, 20))
	equal(sim.state.barrier, 20)
	var restored: Sim = SaveStore.decode(SaveStore.encode(sim).duplicate(true))
	equal(restored.state.barrier, 20)
	var spirit: Dictionary = EnemyRules.create(11, Waves.spirit_group("dark", 2, 10), restored.track.total, 0)
	restored.lose_lives(spirit)
	equal(restored.state.barrier, 15)
	equal(restored.state.lives, 20)
	equal(restored.state.tiers.dark, 2)
	check(restored.spirit_victories().is_empty(), "A shielded breach grants the tier without credit for a defeat")
	var boss: Dictionary = EnemyRules.create(12, Waves.generate(1, 10).boss, restored.track.total, 0)
	restored.lose_lives(boss)
	restored.lose_lives(boss)
	equal(restored.state.barrier, 0)
	equal(restored.state.lives, 15)
	var legacy: Dictionary = SaveStore.encode(restored).duplicate(true)
	legacy.state.erase("barrier")
	equal(SaveStore.decode(legacy).state.barrier, 0)

func test_bloom_alone_builds_a_barrier_before_the_gate_takes_damage() -> void:
	var sim := Sim.new()
	sim.state.towers.s1 = TowerRules.fusion_result("bloom", "s1")
	sim.state.wave = 4
	sim.state.phase = "wave"
	equal(sim.gate_repair_per_cycle(), 1)
	equal(sim.next_gate_repair(), 4)
	sim.step()
	equal(sim.state.barrier, 1)
	equal(sim.next_gate_repair(), 5)
	sim.state.trial = {"element": "light", "tier": 1}
	sim.state.phase = "wave"
	sim.step()
	equal(sim.state.barrier, 1, "The spirit bonus round does not grant a repair")
	sim.state.phase = "wave"
	sim.step()
	equal(sim.state.barrier, 2, "The next regular wave grants another point")
	var group: Dictionary = Waves.generate(1, 1).groups[0]
	sim.lose_lives(EnemyRules.create(sim.next_id(), group, sim.track.total, 0))
	equal(sim.state.barrier, 1)
	equal(sim.state.lives, 20)

func test_move_charges_invested_value_and_can_be_undone() -> void:
	var sim := Sim.new()
	var tower: Dictionary = TowerRules.create(sim.next_id(), "s1", "arrow", "normal", "", 151)
	tower.level = 2
	tower.damage_dealt = 173.0
	tower.kills = 5
	sim.state.towers.s1 = tower
	sim.state.towers.s3 = TowerRules.create(sim.next_id(), "s3", "cannon", "normal", "", 80)
	for invalid: String in ["s1", "s3", "tile_0_1"]:
		check(not sim.apply({"type": "move", "slot": "s1", "to": invalid}).ok)
	var gold: int = sim.state.gold
	var action: Dictionary = {"type": "move", "slot": "s1", "to": "s2"}
	equal(sim.apply(action).cost, 16)
	check(not sim.state.towers.has("s1"))
	equal(sim.state.gold, gold - 16)
	equal(sim.state.towers.s2.invested, 151)
	equal(sim.state.towers.s2.level, 2)
	near(sim.state.towers.s2.damage_dealt, 173.0)
	equal(sim.state.towers.s2.kills, 5)
	check(sim.apply({"type": "undo"}).ok)
	equal(sim.state.towers.s1.slot, "s1")
	equal(sim.state.gold, gold)
	sim.state.gold = 15
	check(not sim.apply(action).ok)

func test_tier_three_pure_towers_share_three_slots_across_elements() -> void:
	var sim := Sim.new()
	sim.state.gold = 10000
	sim.state.tiers.fire = 2
	var build: Dictionary = {"type": "build_pure", "slot": "s1", "kind": "fire"}
	check(not sim.apply(build).ok)
	sim.state.tiers.fire = 3
	sim.state.tiers.water = 3
	sim.state.tiers.nature = 3
	equal(sim.apply(build).cost, int(sim.cfg.pure_tower_cost))
	check(sim.apply({"type":"build_pure", "slot":"s2", "kind":"water"}).ok)
	check(sim.apply({"type":"build_pure", "slot":"s3", "kind":"nature"}).ok)
	var fourth: Dictionary = {"type":"build_pure", "slot":"s4", "kind":"fire"}
	check(not sim.apply(fourth).ok and sim.pure_count() == 3)
	var base: Dictionary = TowerRules.create(0, "", "pure", "fire", "", 0)
	base.level = 6
	var pure: Dictionary = sim.state.towers.s1
	equal(TowerRules.display_name(pure), "Pure Fire")
	check(float(TowerRules.attack_profile(pure).damage) > 2.0 * float(TowerRules.attack_profile(base).damage))
	check(not TowerRules.can_fuse(pure) and not sim.apply({"type":"upgrade", "slot":"s1"}).ok)
	var restored: Sim = SaveStore.decode(SaveStore.encode(sim).duplicate(true))
	check(not restored.apply(fourth).ok and restored.pure_count() == 3)
	check(restored.apply({"type":"sell", "slot":"s2"}).ok)
	check(restored.apply(fourth).ok and restored.pure_count() == 3)

func test_pure_crystal_rewards_spending_and_save() -> void:
	var sim := Sim.new()
	sim.state.gold = 10000
	sim.state.tiers.fire = 3
	check(sim.apply({"type": "build_pure", "slot": "s1", "kind": "fire"}).ok)
	check(sim.apply({"type": "build", "slot": "s2", "kind": "fire"}).ok)
	sim.state.towers.s2.level = 6
	var action: Dictionary = {"type": "empower_pure", "slot": "s1"}
	var base_hit: float = TowerRules.attack_profile(sim.state.towers.s1).damage
	sim.state.wave = 29
	check(not sim.apply(action).ok, "The milestone award cannot be spent early")
	sim.state.trial = {"element": "fire", "tier": 3}
	sim.state.phase = "wave"
	sim.step()
	equal(sim.pure_crystals(), 0, "The spirit round is separate from the milestone")
	for wave: int in [30, 60, 90]:
		sim.events.clear()
		sim.state.wave = wave - 1
		sim.state.phase = "wave"
		sim.step()
		var expected: int = roundi(float(wave) / 30.0)
		equal(sim.pure_crystals(), expected)
		check(sim.events.back().type == "wave_cleared" and sim.events.back().data.pure_crystal)
		equal(sim.state.wave, wave, "Award arrives as the milestone is reached")
		sim.step()
		equal(sim.pure_crystals(), expected, "Finishing a milestone pays once")
	sim = SaveStore.decode(SaveStore.encode(sim).duplicate(true))
	equal(sim.pure_crystals(), 3)
	var elemental_action: Dictionary = {"type": "empower_pure", "slot": "s2"}
	var elemental_hit: float = TowerRules.attack_profile(sim.state.towers.s2).damage
	sim.state.tiers.fire = 2
	check(not sim.apply(elemental_action).ok, "A legacy level-6 elemental tower still needs Tier III")
	sim.state.tiers.fire = 3
	sim.state.towers.s2.level = 5
	check(not sim.apply(elemental_action).ok, "An elemental tower must be max level to use a crystal")
	sim.state.towers.s2.level = 6
	check(sim.apply(elemental_action).ok)
	equal(sim.pure_crystals(), 2)
	near(TowerRules.attack_profile(sim.state.towers.s2).damage, elemental_hit * 1.25)
	check(sim.apply({"type": "undo"}).ok)
	equal(sim.pure_crystals(), 3)
	check(sim.apply(action).ok)
	equal(sim.pure_crystals(), 2)
	near(TowerRules.attack_profile(sim.state.towers.s1).damage, base_hit * 1.25)
	check(sim.apply({"type": "undo"}).ok)
	equal(sim.pure_crystals(), 3)
	near(TowerRules.attack_profile(sim.state.towers.s1).damage, base_hit)
	sim.state.phase = "wave"
	for remaining: int in [2, 1, 0]:
		check(sim.apply(action).ok)
		equal(sim.pure_crystals(), remaining)
	check(not sim.apply(action).ok)
	check(sim.apply({"type": "move", "slot": "s1", "to": "s3"}).ok)
	var loaded: Sim = SaveStore.decode(SaveStore.encode(sim).duplicate(true))
	equal(loaded.pure_crystals(), 0)
	equal(loaded.state.towers.s3.crystals, 3)
	near(TowerRules.attack_profile(loaded.state.towers.s3).damage, base_hit * 1.75)

func test_fusion_carries_socketed_crystal_without_counting_its_bonus_twice() -> void:
	var sim := Sim.new()
	sim.state.gold = 10000
	sim.state.wave = 30
	sim.state.tiers.fire = 3
	sim.state.tiers.nature = 1
	check(sim.apply({"type": "build", "slot": "s1", "kind": "fire"}).ok)
	check(sim.apply({"type": "build", "slot": "s2", "kind": "nature"}).ok)
	sim.state.towers.s1.level = 6
	sim.state.towers.s2.level = 2
	check(sim.apply({"type": "empower_pure", "slot": "s1"}).ok)
	var empowered_hit: float = TowerRules.attack_profile(sim.state.towers.s1).damage
	check(sim.apply({"type": "fuse", "slot_a": "s1", "slot_b": "s2"}).ok)
	equal(sim.state.towers.s1.crystals, 1)
	equal(sim.pure_crystals(), 0)
	near(TowerRules.attack_profile(sim.state.towers.s1).damage, empowered_hit)

func test_spirit_damage_bonuses_reward_victories_and_follow_damage_elements() -> void:
	var sim := Sim.new()
	var fire: Dictionary = TowerRules.create(0, "", "pure", "fire", "", 0)
	var steam: Dictionary = TowerRules.fusion_result("steam")
	var shot: Dictionary = TowerRules.create(0, "", "arrow", "normal", "", 0)
	shot.infusion = "fire"
	shot.level = 2
	sim.resolve_spirit(EnemyRules.create(1, Waves.spirit_group("fire", 2, 10), 0, 0), 5)
	equal(sim.state.tiers.fire, 2)
	near(TowerRules.spirit_multiplier(fire, sim.spirit_victories()), 1.0)
	sim.resolve_spirit(EnemyRules.create(2, Waves.spirit_group("fire", 3, 15), 0, 0))
	sim.resolve_spirit(EnemyRules.create(3, Waves.spirit_group("water", 2, 20), 0, 0))
	near(TowerRules.spirit_multiplier(fire, sim.spirit_victories()), 1.10)
	near(TowerRules.spirit_multiplier(shot, sim.spirit_victories()), 1.10)
	sim.resolve_spirit(EnemyRules.create(4, Waves.spirit_group("water", 3, 25), 0, 0))
	near(TowerRules.spirit_bonus("water", sim.spirit_victories()), .20)
	near(TowerRules.spirit_multiplier(steam, sim.spirit_victories()), 1.15)

func test_recent_history_retains_three_finished_runs_and_counts_sold_damage() -> void:
	var profile: Dictionary = {}
	for wave: int in range(5, 9):
		var sim := Sim.new()
		sim.state.wave = wave
		sim.state.tick = 300
		check(sim.apply({"type":"build", "slot":"s1", "kind":"arrow"}).ok)
		check(sim.apply({"type":"build", "slot":"s2", "kind":"arrow"}).ok)
		sim.state.towers.s1.damage_dealt = 35.0
		sim.state.towers.s2.damage_dealt = 100.0
		check(sim.apply({"type":"sell", "slot":"s1"}).ok)
		SaveStore.record_run(sim, profile)
	var records: Array = JSON.parse_string(JSON.stringify(profile)).recent_runs
	equal(records.size(), 3)
	equal(int(records[0].reached), 8)
	equal(int(records[2].reached), 6)
	near(records[0].damage, 135.0)
	near(records[0].top.damage, 100.0)
	equal(int(records[0].seconds), 10)

func _finish(sim: Sim) -> void:
	for tick: int in range(12000):
		if sim.state.phase != "wave":
			return
		sim.step()
		sim.events.clear()
	check(false, "Wave exceeded the simulation budget")
