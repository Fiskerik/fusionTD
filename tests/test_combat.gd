extends "res://tests/test_base.gd"

func test_splash_applies_full_and_partial_damage_at_distinct_distances() -> void:
	var sim := Sim.new()
	sim.state.phase = "wave"
	sim.state.towers.s1 = TowerRules.create(sim.next_id(), "s1", "cannon", "normal", "", 80)
	for distance: float in [8.9, 9.3, 9.7, 10.15]:
		Combat.spawn(sim, _enemy(), distance)
	sim.step()
	near(sim.state.mobs[3].hp, 986)
	near(sim.state.mobs[2].hp, 986)
	near(sim.state.mobs[1].hp, 992.3)
	near(sim.state.mobs[0].hp, 1000)

func test_support_auras_buff_tiles_at_the_edge_of_the_circle() -> void:
	check(TowerRules.aura_reaches_tile(Vector2.ZERO, Vector2(3, 0), 2.5), "An edge tangent counts")
	check(TowerRules.aura_reaches_tile(Vector2.ZERO, Vector2(2, 2), sqrt(4.5)), "A corner tangent counts")
	check(not TowerRules.aura_reaches_tile(Vector2.ZERO, Vector2(2, 2), 2.0), "A circle can pass beside the corner")
	for recipe: String in ["forge", "spring"]:
		var sim := Sim.new()
		sim.state.phase = "wave"
		var aura: Dictionary = TowerRules.fusion_result(recipe, "s2", sim.next_id())
		var touched: Dictionary = TowerRules.create(sim.next_id(), "tile_3_0", "arrow", "normal", "", 50)
		var outside: Dictionary = TowerRules.create(sim.next_id(), "tile_2_2", "arrow", "normal", "", 50)
		sim.state.towers = {aura.slot: aura, touched.slot: touched, outside.slot: outside}
		Combat.spawn(sim, _enemy(), 4.0)
		sim.step()
		var base: Dictionary = TowerRules.attack_profile(touched)
		near(touched.damage_dealt, float(base.damage) * (1.25 if recipe == "forge" else 1.0), recipe)
		equal(touched.cooldown, ceili(sim.hz / (float(base.rate) * (1.25 if recipe == "spring" else 1.0))), recipe)
		near(outside.damage_dealt, base.damage, recipe + " leaves damage outside the circle unchanged")
		equal(outside.cooldown, ceili(sim.hz / float(base.rate)), recipe + " leaves attack speed outside the circle unchanged")

func test_live_move_retargets_pending_warlock_hex_and_preserves_cooldown() -> void:
	var sim := Sim.new()
	sim.state.phase = "wave"
	var tower: Dictionary = TowerRules.create(sim.next_id(), "s1", "arrow", "normal", "", 50)
	tower.cooldown = 17
	sim.state.towers.s1 = tower
	Combat.spawn(sim, Waves.generate(1, 10).boss, 10)
	sim.state.mobs[0].telegraph = {"slot": "s1", "tick": 1}
	equal(sim.apply({"type": "move", "slot": "s1", "to": "s2"}).cost, 5)
	equal(sim.state.towers.s2.id, tower.id)
	equal(sim.state.towers.s2.cooldown, 17)
	equal(sim.state.mobs[0].telegraph.slot, "s2")
	sim.step()
	check(int(sim.state.towers.s2.stun) > 0)

func test_ice_puddles_make_mobs_bunch_up() -> void:
	var sim := Sim.new()
	sim.state.phase = "wave"
	var glacier: Dictionary = TowerRules.fusion_result("moonglacier", "s1", sim.next_id())
	glacier.cooldown = 90
	sim.state.towers.s1 = glacier
	equal(TowerRules.fusion_recipe(TowerRules.fusion_result("frost"), TowerRules.create(0, "", "pure", "dark", "", 0)), "moonglacier")
	var tiles: Dictionary = sim.ice_tiles()
	check(tiles.has(Vector2i(4, 1)) and not tiles.has(Vector2i(3, 1)) and not tiles.has(Vector2i(4, 2)))
	var group: Dictionary = _enemy()
	group.speed = 1.0
	Combat.spawn(sim, group, 4.51)
	Combat.spawn(sim, group, 3.75)
	var leader: Dictionary = sim.state.mobs[0]
	var follower: Dictionary = sim.state.mobs[1]
	sim.step()
	check(float(leader.s) - 4.51 > 1.0 / sim.hz and int(leader.slip_time) > 0)
	for tick: int in range(34):
		sim.step()
	check(absf(float(leader.s) - float(follower.s)) < .30, "The stumble allows the trailing mob to catch up")
	glacier.stun = 10
	check(sim.ice_tiles().is_empty())

func test_disease_uses_recent_damage_and_spreads_on_defeat() -> void:
	var sim := Sim.new()
	sim.state.phase = "wave"
	var orchid: Dictionary = TowerRules.fusion_result("moonorchid", "s1", sim.next_id())
	orchid.cooldown = 500
	sim.state.towers.s1 = orchid
	for distance: float in [10.0, 10.5, 2.0]:
		Combat.spawn(sim, _enemy(), distance)
	var sick: Dictionary = sim.state.mobs[0]
	var neighbor: Dictionary = sim.state.mobs[1]
	Damage.deal(sick, 200.0, {}, 0)
	Damage.deal(neighbor, 50.0, {}, 0)
	var attack: Dictionary = TowerRules.attack_profile(orchid)
	Effects.apply(sick, TowerRules.trait_profile(orchid, sim.state.tiers), attack.potency, false, 1, attack.damage, sim.hz, orchid.id)
	near(Effects.disease_rate(sick), 26.88)
	sim.step()
	near(orchid.damage_dealt, 26.88 / sim.hz)
	near(Effects.disease_rate(sick), 26.88, "Disease damage cannot feed back into its own history")
	Damage.deal(sick, 1000.0, {}, sim.state.tick)
	sim.step()
	near(Effects.disease_rate(neighbor), 6.72, "Infection uses the new host's damage history")
	check(not sim.state.mobs[1].has("disease"))
	sim.state.tick = 119
	sim.step()
	near(Effects.disease_rate(neighbor), 0.0, "Damage expires after four seconds")

func test_root_upgrades_increase_hold_time_and_frequency() -> void:
	var sim := Sim.new()
	var tower: Dictionary = TowerRules.fusion_result("overgrowth")
	var root: Array = TowerRules.trait_profile(tower, sim.state.tiers).root
	var base: Dictionary = EnemyRules.create(1, _enemy(), 0.0, 0)
	Effects.apply(base, {"root": root}, TowerRules.attack_profile(tower).potency, false, 3, 0.0, sim.hz)
	equal(base.root_time, 30)
	tower.level = 3
	var upgraded: Dictionary = EnemyRules.create(2, _enemy(), 0.0, 0)
	Effects.apply(upgraded, {"root": root}, TowerRules.attack_profile(tower).potency, false, 2, 0.0, sim.hz)
	equal(upgraded.root_time, 57)

func test_spirit_victories_apply_to_actual_hits() -> void:
	var sim := Sim.new()
	sim.state.phase = "wave"
	sim.state.tiers.water = 3
	sim.state.stats.spirit_victories = {"water": 3}
	var tower: Dictionary = TowerRules.create(sim.next_id(), "s1", "pure", "water", "", 0)
	sim.state.towers.s1 = tower
	Combat.spawn(sim, _enemy(), 10.0)
	sim.step()
	near(tower.damage_dealt, 12.0)

func test_attacking_duals_out_hit_each_level_two_ingredient() -> void:
	for id: String in DataDB.read("duals"):
		var dual: Dictionary = TowerRules.fusion_result(id)
		var attack: Dictionary = TowerRules.attack_profile(dual)
		if float(attack.rate) == 0.0:
			near(attack.damage, 0.0, "Support keeps its aura instead of gaining an attack")
			continue
		for element: String in TowerRules.ingredients(dual):
			var input: Dictionary = TowerRules.create(0, "", "pure", element, "", 0)
			input.level = 2
			check(float(attack.damage) >= 1.2 * float(TowerRules.attack_profile(input).damage) - 0.001, id)

func test_daystar_pulses_around_the_tower() -> void:
	var sim := Sim.new()
	sim.state.phase = "wave"
	sim.state.towers.s1 = TowerRules.fusion_result("daystar", "s1", sim.next_id())
	for distance: float in [2.0, 8.9, 12.1]:
		Combat.spawn(sim, _enemy(), distance)
	sim.step()
	equal(sim.state.mobs[0].slow_time, 0)
	for index: int in [1, 2]:
		var enemy: Dictionary = sim.state.mobs[index]
		check(float(enemy.hp) < float(enemy.max_hp) and enemy.dots.has("burn"))
		check(int(enemy.slow_time) > 0)

func test_damage_credit_follows_towers_through_a_live_fusion() -> void:
	var sim := Sim.new()
	sim.state.phase = "wave"
	sim.state.gold = 500
	var first: Dictionary = TowerRules.create(sim.next_id(), "s1", "pure", "fire", "", 0)
	var second: Dictionary = TowerRules.create(sim.next_id(), "s2", "pure", "water", "", 0)
	var ally: Dictionary = TowerRules.create(sim.next_id(), "s3", "cannon", "normal", "", 0)
	for tower: Dictionary in [first, second, ally]:
		tower.level = 3
		tower.cooldown = 99
		sim.state.towers[tower.slot] = tower
	first.damage_dealt = 41.0
	second.damage_dealt = 30.0
	first.kills = 2
	second.kills = 3
	ally.damage_dealt = 72.0
	Combat.spawn(sim, _enemy(), 8.0)
	var enemy: Dictionary = sim.state.mobs[0]
	enemy.hp = 3.0
	Effects.add_dot(enemy, "burn", 60, 4, 2, 90, 0.0, [first.id, second.id])
	check(sim.apply({"type":"fuse", "slot_a":"s1", "slot_b":"s2"}).ok)
	var merged: Dictionary = sim.state.towers.s1
	merged.cooldown = 99
	equal(merged.kills, 5)
	near(merged.damage_dealt, 71.0)
	equal(sim.top_damage()[0].slot, "s3")
	var restored: Sim = SaveStore.decode(SaveStore.encode(sim).duplicate(true))
	restored.step()
	var record: Dictionary = restored.state.towers.s1
	equal(record.kills, 6)
	near(record.damage_dealt, 74.0, "Overkill is excluded, and both burn stacks credit the fusion")
	equal(restored.top_damage()[0].slot, "s1")

func test_effects_and_immunities() -> void:
	var mob: Dictionary = EnemyRules.create(1, _enemy(), 0, 0)
	for hit: int in range(1, 8):
		Effects.apply(mob, {"burn": [5, .15, 4]}, .5, true, hit, 100, 30)
	equal(mob.dots.burn.stacks, 3)
	near(mob.dots.burn.dps, 7.5)
	Effects.tick(mob, 30)
	near(mob.hp, 999.25)
	Effects.tick(mob, 30, true)
	near(mob.hp, 999.25)
	Effects.apply(mob, {"slow": [.6, 2]}, 1, false, 1, 0, 30)
	Effects.apply(mob, {"slow": [.4, 4]}, 1, false, 1, 0, 30)
	near(mob.slow, .6)
	equal(mob.slow_time, 60)
	Effects.apply(mob, {"freeze": [5, .8], "root": [5, .7]}, 1, false, 4, 0, 30)
	equal(mob.freeze_time, 0)
	Effects.apply(mob, {"freeze": [5, .8], "root": [5, .7], "poison": [1, .35, 4], "curse": [.25, 3]}, 1, false, 5, 100, 30)
	equal(mob.freeze_time, 24)
	equal(mob.root_time, 21)
	near(mob.curse, .25)
	Effects.apply(mob, {"poison": [1, .35, 4]}, 1, false, 6, 50, 30)
	equal(mob.dots.poison.stacks, 1)
	near(mob.dots.poison.dps, 35)
	var spirit: Dictionary = EnemyRules.create(1, Waves.spirit_group("water", 1, 4), 0, 0)
	Effects.apply(spirit, {"freeze": [1, 3], "silence": 3, "slow": [.6, 2], "root": [1, 3]}, 1, false, 1, 0, 30)
	equal(spirit.freeze_time, 0)
	equal(spirit.root_time, 0)
	equal(spirit.silence_time, 0)
	near(spirit.slow, .25)

func test_all_fusion_recipes_and_tier_gate() -> void:
	var rules: Dictionary = DataDB.read("duals")
	for recipe: String in rules:
		var entry: Dictionary = rules[recipe]
		var sim := Sim.new()
		sim.state.gold = 20000
		var a: String = entry.pair[0]
		var b: String = entry.pair[1]
		sim.state.tiers[a] = 1
		sim.state.tiers[b] = 1
		check(sim.apply({"type": "build", "slot": "s1", "kind": a}).ok)
		check(sim.apply({"type": "build", "slot": "s2", "kind": b}).ok)
		var fusion: Dictionary = {"type": "fuse", "slot_a": "s1", "slot_b": "s2"}
		check(not sim.apply(fusion).ok)
		for slot: String in ["s1", "s2"]:
			check(sim.apply({"type": "upgrade", "slot": slot}).ok)
		var before: int = sim.state_hash()
		var invested: int = int(sim.state.towers.s1.invested) + int(sim.state.towers.s2.invested)
		equal(sim.apply(fusion).cost, 250)
		equal(sim.state.towers.s1.dual, recipe)
		equal(sim.state.towers.s1.invested, invested + 250)
		check(not sim.state.towers.has("s2"))
		check(sim.apply({"type": "undo"}).ok)
		equal(sim.state_hash(), before)
		check(sim.apply(fusion).ok)
		var upgrade: Dictionary = {"type": "upgrade", "slot": "s1"}
		check(sim.apply(upgrade).ok)
		check(not sim.apply(upgrade).ok)
		sim.state.tiers[a] = 2
		check(not sim.apply(upgrade).ok)
		sim.state.tiers[b] = 2
		check(sim.apply(upgrade).ok)
		sim.state.phase = "wave"
		var group: Dictionary = _enemy()
		group.element = "dark"
		Combat.spawn(sim, group, 10.0)
		sim.step()
		if float(entry.rate) > 0.0:
			check(float(sim.state.mobs[0].hp) < 1000.0, recipe + " fires")
		else:
			near(sim.state.mobs[0].hp, 1000.0, recipe + " is a support")
		if recipe == "eclipse":
			near(sim.state.mobs[0].hp, 1000.0 - 44.0 * 2.6 * 1.5 * float(sim.cfg.dual_damage_scale))

func test_prism_ramp_and_non_stacking_bloom() -> void:
	var sim := Sim.new()
	sim.state.phase = "wave"
	sim.state.towers.s1 = TowerRules.create(1, "s1", "dual", "", "prism", 0)
	var group: Dictionary = _enemy()
	Combat.spawn(sim, group, 10.0)
	var mob: Dictionary = sim.state.mobs[0]
	sim.step()
	var first: float = 1000 - float(mob.hp)
	for tick: int in range(8):
		sim.step()
	check(1000.0 - first - float(mob.hp) > first)
	sim.state.mobs.clear()
	sim.state.wave = 3
	sim.state.lives = 17
	for slot: String in ["s1", "s2", "s3"]:
		sim.state.towers[slot] = TowerRules.create(sim.next_id(), slot, "dual", "", "bloom", 0)
	sim.step()
	equal(sim.state.lives, 18)
	equal(sim.state.wave, 4)

func test_late_enemies_recover_between_disables() -> void:
	var group: Dictionary = Waves.generate(1, 80).groups[0]
	var mob: Dictionary = EnemyRules.create(1, group, 0, 0)
	var root := {"root": [1, 2.0], "slow": [.5, 3.0]}
	Effects.apply(mob, root, 1.0, false, 1, 0.0, 30.0)
	var initial: int = mob.root_time
	equal(initial, 42)
	near(mob.slow, .345)
	var free_ticks := 0
	for i: int in range(initial + 15):
		Effects.tick(mob, 30.0)
		Effects.apply(mob, root if i % 2 == 0 else {"freeze": [1, 2.0]}, 1.0, false, 1, 0.0, 30.0)
		if int(mob.root_time) == 0 and int(mob.freeze_time) == 0:
			free_ticks += 1
	check(free_ticks >= 15, "Repeated roots and freezes allow a recovery window")

func test_late_necromancer_heals_without_adding_units() -> void:
	var sim := Sim.new()
	sim.state.wave = 90
	sim.state.phase = "wave"
	var wave: Dictionary = sim.preview(90)
	var necromancer: Dictionary = wave.bosses.filter(func(group: Dictionary) -> bool: return group.boss_type == "necromancer")[0]
	Combat.spawn(sim, necromancer, 10)
	Combat.spawn(sim, _enemy(), 10.1)
	Combat.spawn(sim, _enemy(), 10.4)
	sim.state.mobs[1].hp = 600
	sim.state.mobs[2].hp = 600
	sim.state.mobs[2].heal_block_time = 30
	sim.state.tick = int(DataDB.read("bosses").necromancer.period) - 1
	sim.step()
	equal(sim.state.mobs.size(), 3)
	check(sim.state.spawn_queue.is_empty())
	near(sim.state.mobs[1].hp, 700.0)
	near(sim.state.mobs[2].hp, 600.0)

func test_chain_falloff_and_fire_spread() -> void:
	var sim := Sim.new()
	sim.state.phase = "wave"
	sim.state.tiers.electric = 1
	sim.state.towers.s1 = TowerRules.create(1, "s1", "pure", "electric", "", 0)
	for distance: float in [9.0, 9.3, 9.6, 10.0]:
		Combat.spawn(sim, _enemy(), distance)
	sim.step()
	near(sim.state.mobs[3].hp, 986)
	near(sim.state.mobs[2].hp, 990.2)
	near(sim.state.mobs[1].hp, 993.14)
	near(sim.state.mobs[0].hp, 1000)
	sim.state.mobs[3].hp = 0.0
	Effects.add_dot(sim.state.mobs[3], "burn", 10, 10, 6, 120, 1.2)
	sim.step()
	equal(sim.state.mobs[2].dots.burn.stacks, 3)

func test_mender_splitter_and_revenant() -> void:
	var sim := Sim.new()
	sim.state.phase = "wave"
	var mender: Dictionary = _enemy(["mender"])
	var splitter: Dictionary = _enemy(["splitter"])
	Combat.spawn(sim, mender, 10.0)
	Combat.spawn(sim, splitter, 10.0)
	sim.state.mobs[0].hp = 0
	sim.state.mobs[1].hp = 100
	sim.step()
	near(sim.state.mobs[0].hp, 300)
	sim.state.mobs[0].hp = 0
	sim.step()
	equal(sim.state.spawn_queue.size(), 2)
	sim.step()
	equal(sim.state.mobs.size(), 2)
	equal(sim.state.mobs[0].kind, "splitling")
	near(sim.state.mobs[0].hp, 350)
	sim.state.mobs.clear()
	Combat.spawn(sim, _enemy(["revenant"]), 10)
	sim.state.mobs[0].hp = 0
	sim.step()
	equal(sim.state.spawn_queue.size(), 1)
	equal(sim.state.phase, "wave")
	for tick: int in range(120):
		sim.step()
	near(sim.state.mobs[0].hp, 330)
	equal(sim.state.mobs[0].revived, true)
	sim.state.mobs[0].hp = 0
	sim.step()
	equal(sim.state.phase, "build")

func test_light_reaches_across_the_map_and_nature_strikes_the_pack() -> void:
	var sim := Sim.new()
	sim.state.phase = "wave"
	sim.state.tiers.light = 1
	sim.state.towers.s1 = TowerRules.create(1, "s1", "pure", "light", "", 0)
	Combat.spawn(sim, _enemy([]), .5)
	var mob: Dictionary = sim.state.mobs[0]
	check(sim.track.at(mob.s).distance_to(sim.track.slots.s1.position) > 5.0)
	sim.step()
	check(float(mob.hp) < 1000.0, "Light can target the entrance from across the board")
	sim.state.towers.s1 = TowerRules.create(2, "s1", "pure", "nature", "", 0)
	sim.state.tiers.nature = 1
	sim.state.mobs.clear()
	Combat.spawn(sim, _enemy([]), 9.52)
	Combat.spawn(sim, _enemy([]), 10.04)
	sim.step()
	for victim: Dictionary in sim.state.mobs:
		check(float(victim.hp) <= 973.0 and victim.dots.has("poison"), "Nature damages and poisons the cluster")

func test_phasing_and_null_silence() -> void:
	var mob: Dictionary = EnemyRules.create(1, _enemy(["phasing", "revenant"]), 10, 0)
	check(not EnemyRules.phased(mob, 149, 30))
	check(EnemyRules.phased(mob, 150, 30))
	check(EnemyRules.phased(mob, 209, 30))
	check(not EnemyRules.phased(mob, 210, 30))
	check(EnemyRules.phased(mob, 300, 30))
	Effects.apply(mob, {"silence": 3}, 1, false, 1, 0, 30)
	check(not EnemyRules.phased(mob, 300, 30))
	check(not EnemyRules.property(mob, "revenant"))
	check(not EnemyRules.phased(mob, 360, 30))
	var sim := Sim.new()
	sim.state.phase = "wave"
	sim.state.towers.s1 = TowerRules.create(1, "s1", "arrow", "normal", "", 0)
	Combat.spawn(sim, _enemy(["phasing"]), 10)
	sim.state.tick = 149
	sim.step()
	near(sim.state.mobs[0].hp, 1000.0, "An immune shield blocks an ordinary shot")
	sim.state.towers.s1 = TowerRules.create(1, "s1", "dual", "", "null", 0)
	sim.step()
	check(not EnemyRules.phased(sim.state.mobs[0], 151, 30))
	check(float(sim.state.mobs[0].hp) < 1000)

func test_warlock_rally_ram_and_necromancer() -> void:
	var sim := Sim.new()
	check(sim.apply({"type": "build", "kind": "arrow", "slot": "s1"}).ok)
	sim.state.phase = "wave"
	sim.state.wave = 10
	var warlock: Dictionary = Waves.generate(1, 10).boss
	warlock.speed = 0.0
	warlock.hp = 50000.0
	Combat.spawn(sim, warlock, 10)
	for tick: int in range(305):
		sim.step()
	check(not sim.state.mobs[0].telegraph.is_empty())
	for tick: int in range(60):
		sim.step()
	check(int(sim.state.towers.s1.stun) > 0)
	check(sim.apply({"type": "rally", "slot": "s1"}).ok)
	equal(sim.state.towers.s1.stun, 0)
	equal(sim.state.rally_cd, 360)
	sim.state.towers.s1.stun = 1
	check(not sim.apply({"type": "rally", "slot": "s1"}).ok)
	var ram: Dictionary = EnemyRules.create(1, Waves.generate(1, 20).boss, 10, 0)
	Effects.apply(ram, {"slow": [.6, 4], "root": [1, 3]}, 1, false, 1, 0, 30)
	near(ram.slow, 0)
	equal(ram.root_time, 0)
	sim.state.towers.clear()
	sim.state.mobs.clear()
	var necromancer: Dictionary = Waves.generate(1, 30).boss
	necromancer.speed = 0.0
	Combat.spawn(sim, necromancer, 5)
	for tick: int in range(980):
		sim.step()
	equal(sim.state.mobs.size(), 13)

func _enemy(properties: Array = []) -> Dictionary:
	return {"kind": "grunt", "element": "none", "props": properties, "hp": 1000.0,
		"speed": 0.0, "armor": 0.0, "gold": 0, "leak": 1, "slow_cap": .7}
