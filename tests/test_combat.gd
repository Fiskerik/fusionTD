extends "res://tests/test_base.gd"

func test_road_stone_pushes_occupants_and_stops_followers_until_it_expires() -> void:
	var sim := Sim.new()
	sim.state.phase = "wave"
	var tile := Vector2i(4, 1)
	var stop: float = sim.track.stone_stop(tile)
	var group: Dictionary = _enemy()
	group.speed = 3.0
	for distance: float in [stop - .1, stop + .51, stop + 1.8]:
		Combat.spawn(sim, group, distance)
	var block: Dictionary = {"type": "place_stone", "tile": tile}
	check(sim.apply(block).ok)
	near(sim.state.mobs[1].s, stop)
	equal(sim.state.stone_blocks, 2)
	equal(sim.stone_cooldown(), 60)
	check(not sim.apply(block).ok)
	for tick: int in range(149):
		sim.step()
	near(sim.state.mobs[0].s, stop)
	near(sim.state.mobs[1].s, stop)
	check(float(sim.state.mobs[2].s) > stop + 1.8)
	sim.step()
	check(sim.state.stone.is_empty() and float(sim.state.mobs[0].s) > stop)
	check(not sim.apply(block).ok)
	sim.state.wave += 1
	check(not sim.apply(block).ok)
	sim.state.tick = int(sim.state.stone_ready_tick)
	check(sim.apply(block).ok)
	sim.state.wave += 1
	sim.state.tick = int(sim.state.stone_ready_tick)
	check(sim.apply(block).ok)
	sim.state.wave += 1
	sim.state.tick = int(sim.state.stone_ready_tick)
	check(not sim.apply(block).ok)
	equal(sim.state.stone_blocks, 0)

func test_boss_damage_reduction_applies_to_hits_and_ongoing_effects() -> void:
	var boss: Dictionary = EnemyRules.create(1, Waves.generate(1, 10).boss, 0.0, 0)
	var start_hp: float = boss.hp
	var tower: Dictionary = {"id": 2}
	var hit: float = Damage.hit(100.0, boss.armor, 0.0, 0.0, 0.0)
	Damage.deal(boss, hit, tower, 1)
	near(start_hp - float(boss.hp), hit * .75)
	near(boss.recent_damage, hit * .75)
	near(tower.damage_dealt, hit * .75)
	for effect: String in ["burn", "poison"]:
		Effects.add_dot(boss, effect, 60.0, 1, 1, 1, 0.0, [2])
	Effects.infect(boss, {"source": 2, "fraction": .2, "duration": 30})
	var before_tick: float = boss.hp
	var dot_damage: float = 4.0 * .75
	var disease_damage: float = (hit * .75 + dot_damage) * .2 / 30.0 * .75
	Effects.tick(boss, 30.0, false, {2: tower}, 2)
	near(before_tick - float(boss.hp), dot_damage + disease_damage)
	near(tower.damage_dealt, hit * .75 + dot_damage + disease_damage)
	near(boss.recent_damage, hit * .75 + dot_damage)

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

func test_support_range_bonus_reaches_enemies_outside_base_range() -> void:
	var sim := Sim.new()
	sim.state.phase = "wave"
	var spring: Dictionary = TowerRules.fusion_result("spring", "s2", sim.next_id())
	var arrow: Dictionary = TowerRules.create(sim.next_id(), "tile_3_0", "arrow", "normal", "", 50)
	sim.state.towers = {spring.slot: spring, arrow.slot: arrow}
	var spring_effect: Dictionary = TowerRules.stats(spring).effect
	spring_effect.aura_range = .13
	Combat.spawn(sim, _enemy(), 15.0)
	sim.step()
	near(arrow.damage_dealt, TowerRules.attack_profile(arrow).damage, "Range support reaches behind the first bend")
	arrow.cooldown = 0
	spring.stun = 2
	sim.step()
	near(arrow.damage_dealt, TowerRules.attack_profile(arrow).damage, "A stunned support tower stops extending range")
	spring_effect.erase("aura_range")

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

func test_ascended_water_uses_the_bonus_range_attack_rate_and_slow_in_combat() -> void:
	var sim := Sim.new()
	sim.state.wave = 30
	sim.state.phase = "wave"
	sim.state.tiers.water = 3
	var tower: Dictionary = TowerRules.create(sim.next_id(), "s1", "pure", "water", "", 1000)
	tower.level = 6
	sim.state.towers.s1 = tower
	Combat.spawn(sim, _enemy(), 4.0)
	sim.step()
	near(tower.damage_dealt, 0.0, "The target starts outside level-six range")
	check(sim.apply({"type": "empower_pure", "slot": "s1"}).ok)
	sim.step()
	var ascended: Dictionary = TowerRules.attack_profile(tower)
	near(tower.damage_dealt, ascended.damage)
	equal(tower.cooldown, ceili(sim.hz / float(ascended.rate)))
	var slow: Array = TowerRules.trait_profile(tower, sim.state.tiers).slow
	var enemy: Dictionary = sim.state.mobs[0]
	near(enemy.slow, minf(float(enemy.slow_cap), Effects.slow_strength(slow[0], ascended.potency)))
	equal(enemy.slow_time, Effects.ticks(Effects.slow_duration(slow[1], ascended.potency), sim.hz))

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

func test_rolled_weakness_controls_elemental_damage() -> void:
	var group: Dictionary = _enemy()
	group.element = "fire"
	group.weakness = "light"
	near(Damage.against({"light": .5, "nature": .5}, group, false), 1.125)
	near(Damage.against({"water": 1.0}, group, false), 1.0)
	near(Damage.against({"normal": 1.0}, group, false), 1.0)
	near(Damage.against({}, group, true), 1.5)
	var sim := Sim.new()
	sim.state.phase = "wave"
	var tower: Dictionary = TowerRules.create(sim.next_id(), "s1", "pure", "light", "", 0)
	sim.state.towers.s1 = tower
	Combat.spawn(sim, group, 10.0)
	sim.step()
	near(tower.damage_dealt, float(TowerRules.stats(tower).damage) * 1.5)

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
		equal(sim.apply(fusion).cost, 313)
		equal(sim.state.towers.s1.dual, recipe)
		equal(sim.state.towers.s1.invested, invested + 313)
		check(not sim.state.towers.has("s2"))
		check(sim.apply({"type": "undo"}).ok)
		equal(sim.state_hash(), before)
		check(sim.apply(fusion).ok)
		var upgrade: Dictionary = {"type": "upgrade", "slot": "s1"}
		equal(sim.state.towers.s1.level, 1)
		check(not sim.apply(upgrade).ok)
		sim.state.tiers[a] = 2
		check(not sim.apply(upgrade).ok)
		sim.state.tiers[b] = 2
		check(sim.apply(upgrade).ok)
		check(not sim.apply(upgrade).ok)
		sim.state.tiers[b] = 3
		check(not sim.apply(upgrade).ok)
		sim.state.tiers[a] = 3
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
	var group: Dictionary = Waves.generate(1, 81).groups[0]
	var mob: Dictionary = EnemyRules.create(1, group, 0, 0)
	var root := {"root": [1, 2.0], "slow": [.5, 3.0]}
	Effects.apply(mob, root, 1.0, false, 1, 0.0, 30.0)
	var initial: int = mob.root_time
	equal(initial, 36)
	near(mob.slow, .30)
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

func test_gilded_courier_payout_and_travel_time() -> void:
	var courier: Dictionary = {}
	var ordinary: Dictionary = {}
	var wave_bounty: int = 0
	for seed_value: int in range(1, 300):
		var wave: Dictionary = Waves.generate(seed_value, 11)
		var bonus: Array = wave.groups.filter(func(group: Dictionary) -> bool: return group.kind == "bonus")
		check(bonus.size() <= 1)
		if not bonus.is_empty():
			courier = bonus[0]
			ordinary = wave.groups.filter(func(group: Dictionary) -> bool: return group.kind == "grunt" and group.props.is_empty())[0]
			for group: Dictionary in wave.groups:
				if group.kind != "bonus":
					wave_bounty += int(group.gold) * int(group.count)
			break
	check(not courier.is_empty())
	if courier.is_empty():
		return
	equal(courier.count, 1)
	near(courier.hp, float(ordinary.hp) * 2.0)
	near(courier.armor, float(ordinary.armor) * 4.0)
	equal(courier.gold, roundi(wave_bounty * .4))
	var sim := Sim.new()
	sim.state.phase = "wave"
	sim.schedule(ordinary, 900)
	Combat.spawn(sim, courier, 0.0)
	var mob: Dictionary = sim.state.mobs[0]
	Effects.apply(mob, {"slow": [.7, 20], "root": [1, 20], "freeze": [1, 20]}, 1.0, false, 1, 0.0, sim.hz)
	check(mob.slow_time == 0 and mob.freeze_time == 0 and mob.root_time == 0)
	near(Effects.ice_speed(mob, {"slide": 1, "stumble": 10}), 1.0)
	for tick: int in range(359):
		sim.step()
	equal(sim.state.mobs.size(), 1)
	sim.step()
	equal(sim.state.mobs.size(), 0)
	equal(sim.state.lives, 19)
	var before: int = sim.state.gold
	Combat.spawn(sim, courier, 0.0)
	sim.state.mobs[0].hp = 0
	sim.step()
	equal(int(sim.state.gold) - before, courier.gold)

func test_void_wizard_waits_and_only_moves_to_corners() -> void:
	var sim := Sim.campaign(7)
	var group: Dictionary = _enemy()
	group.merge({"kind": "wizard", "props": ["wizard"]}, true)
	sim.state.phase = "wave"
	Combat.spawn(sim, group, 0)
	var wizard: Dictionary = sim.state.mobs[0]
	for tick: int in range(89):
		sim.step()
	near(wizard.s, 0.0)
	check(not EnemyRules.in_void(wizard, sim.state.tick, sim.hz))
	sim.step()
	check(EnemyRules.in_void(wizard, sim.state.tick, sim.hz))
	var health: float = wizard.hp
	Effects.add_dot(wizard, "burn", 100.0, 1, 1, 60, 0.0)
	for tick: int in range(59):
		sim.step()
	near(wizard.s, 0.0)
	near(wizard.hp, health)
	sim.step()
	var corner: int = sim.track.corner_crossed(0.0, sim.track.total)
	near(wizard.s, sim.track.lengths[corner])
	near(wizard.prev_s, wizard.s)
	check(not EnemyRules.in_void(wizard, sim.state.tick, sim.hz))
	var events: Array[Dictionary] = sim.events.filter(func(event: Dictionary) -> bool: return event.type == "wizard_portal")
	equal(events.size(), 2)
	for hop: int in range(sim.track.points.size()):
		if sim.state.phase != "wave":
			break
		var previous: float = wizard.s
		corner = sim.track.corner_crossed(previous, sim.track.total)
		for tick: int in range(150):
			sim.step()
		near(wizard.s, sim.track.lengths[corner] if corner >= 0 else sim.track.total)
	equal(sim.state.lives, 19)

func test_springwell_fuses_into_a_stronger_attack_speed_aura() -> void:
	var sim := Sim.new()
	var spring: Dictionary = TowerRules.fusion_result("spring", "s2", 1)
	var electric: Dictionary = TowerRules.create(2, "s4", "pure", "electric", "", 100)
	electric.level = 2
	var arrow: Dictionary = TowerRules.create(3, "s1", "arrow", "normal", "", 50)
	for element: String in ["water", "nature", "electric"]:
		sim.state.tiers[element] = 3
	var recipe: String = TowerRules.fusion_recipe(spring, electric)
	equal(recipe, "monsoonroot")
	var monsoon: Dictionary = TowerRules.combine(recipe, spring, electric, sim.state.tiers, {})
	var spring_boost: float = sim.support_bonuses(arrow, TowerRules.support_sources([spring])).y
	var monsoon_boost: float = sim.support_bonuses(arrow, TowerRules.support_sources([monsoon])).y
	check(monsoon_boost > spring_boost)
	monsoon.petrified = true
	near(sim.support_bonuses(arrow, TowerRules.support_sources([monsoon])).y, 0.0)

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
	near(ram.slow, .3)
	equal(ram.root_time, 45)
	sim.state.towers.clear()
	sim.state.mobs.clear()
	var necromancer: Dictionary = Waves.generate(1, 30).boss
	necromancer.speed = 0.0
	Combat.spawn(sim, necromancer, 5)
	for tick: int in range(980):
		sim.step()
	equal(sim.state.mobs.size(), 5)

func test_ram_stops_at_every_bend_and_resumes_its_charge() -> void:
	var sim := Sim.new()
	sim.state.wave = 20
	sim.state.phase = "wave"
	Combat.spawn(sim, sim.preview(20).boss, sim.track.lengths[1] - .01)
	sim.step()
	var ram: Dictionary = sim.state.mobs[0]
	equal(ram.corner, 1)
	near(ram.s, sim.track.lengths[1])
	var turn_ticks: int = ram.turn_left
	near(ram.speed, 1.05)
	equal(turn_ticks, Effects.ticks(4.0, sim.hz))
	var restored: Sim = SaveStore.decode(SaveStore.encode(sim).duplicate(true))
	equal(restored.state.mobs[0].turn_left, turn_ticks)
	var old_save: Dictionary = SaveStore.encode(sim).duplicate(true)
	var old_ram: Dictionary = old_save.state.mobs[0]
	old_ram.turn_seconds = 3.0
	old_ram.speed = 1.4
	old_ram.turn_left = Effects.ticks(1.5, sim.hz)
	var updated: Sim = SaveStore.decode(old_save)
	near(updated.state.mobs[0].speed, 1.05)
	equal(updated.state.mobs[0].turn_left, Effects.ticks(2.0, sim.hz), "An active turn keeps its progress when retuned")
	for index: int in range(turn_ticks - 1):
		sim.step()
	near(ram.s, sim.track.lengths[1])
	sim.step()
	near(ram.s - sim.track.lengths[1], float(ram.speed) / sim.hz)
	check(not ram.has("corner"))
	var corners := PackedInt32Array([1])
	for tick: int in range(1800):
		if sim.state.mobs.is_empty():
			break
		sim.step()
		if ram.has("corner") and int(ram.corner) != corners[-1]:
			corners.append(ram.corner)
			near(ram.s, sim.track.lengths[ram.corner])
	equal(corners.size(), sim.track.points.size() - 2)
	check(sim.state.mobs.is_empty(), "The boss reaches the gate after its final charge")

func test_prismheart_uses_unlocked_forms_and_swaps_damage_matchups() -> void:
	var sim := Sim.new()
	sim.state.wave = 40
	equal(sim.preview(40).boss.element, "none")
	sim.state.tiers.fire = 2
	sim.state.tiers.water = 1
	sim.state.tiers.earth = 1
	var group: Dictionary = sim.preview(40).boss
	equal(group.forms, PackedStringArray(["fire", "water", "earth"]))
	sim.state.phase = "wave"
	Combat.spawn(sim, group, 3.0)
	var boss: Dictionary = sim.state.mobs[0]
	near(Damage.against({"fire": 1.0}, boss, false), .65)
	near(Damage.against({"nature": 1.0}, boss, false), .75)
	near(Damage.against({"water": 1.0}, boss, false), 1.5)
	var period: int = EnemyRules.morph_period(sim.hz)
	equal(period, roundi(sim.hz * 5.0))
	for tick: int in range(period - 1):
		sim.step()
	equal(boss.element, "fire")
	var restored: Sim = SaveStore.decode(SaveStore.encode(sim).duplicate(true))
	restored.step()
	boss = restored.state.mobs[0]
	equal(boss.element, "water")
	near(Damage.against({"electric": 1.0}, boss, false), 1.5)
	near(Damage.against({"fire": 1.0}, boss, false), .75)
	for tick: int in range(period):
		restored.step()
	equal(boss.element, "earth")
	near(Damage.against({"nature": 1.0}, boss, false), 1.5)
	near(Damage.against({"electric": 1.0}, boss, false), .75)
	for tick: int in range(period):
		restored.step()
	equal(boss.element, "fire")

func test_stormwing_ignores_ground_control_and_ironwood_resists_elements() -> void:
	var bird: Dictionary = EnemyRules.create(1, Waves.generate(1, 50).boss, 0.0, 0)
	Effects.apply(bird, {"root": [1, 4], "freeze": [1, 2], "slow": [.4, 2]}, 1, false, 1, 0, 30)
	equal(bird.root_time, 0)
	check(bird.freeze_time > 0)
	near(bird.slow, .2)
	near(Effects.ice_speed(bird, {"slide": 15, "stumble": 15}), 1.0)
	check(not bird.has("slip_time"))
	near(Damage.against({"electric": 1.0}, bird, false), 1.5)
	var engine: Dictionary = Waves.generate(1, 60).boss
	engine.armor = 0.0
	for infusion: String in ["", "fire"]:
		var sim := Sim.new()
		sim.state.phase = "wave"
		var tower: Dictionary = TowerRules.create(sim.next_id(), "s1", "arrow", "normal", "", 50)
		tower.infusion = infusion
		sim.state.tiers.fire = 1
		sim.state.towers.s1 = tower
		Combat.spawn(sim, engine, 10.0)
		sim.step()
		near(tower.damage_dealt, float(TowerRules.stats(tower).damage) * (2.0 if infusion.is_empty() else .75) * .75)
	near(Damage.against({"fire": .5, "water": .5}, engine, false), .75)
	near(Damage.against({}, engine, true), .75)
	check(StatusInfo.trait_description("ironwood").contains("75% of elemental damage"))

func _enemy(properties: Array = []) -> Dictionary:
	return {"kind": "grunt", "element": "none", "props": properties, "hp": 1000.0,
		"speed": 0.0, "armor": 0.0, "gold": 0, "leak": 1, "slow_cap": .7}

func test_campaign_enemy_behaviors_trigger_on_the_road() -> void:
	var sim := Sim.new()
	sim.state.phase = "wave"
	sim.state.wave = 25
	var adaptive: Dictionary = EnemyRules.create(1, _enemy(["chameleon"]), 5.0, 0)
	Damage.adapt(adaptive, {"fire": 1.0}, false)
	near(Damage.against({"fire": 1.0}, adaptive, false), 0.0)
	near(Damage.against({"normal": 1.0}, adaptive, false), 1.0)
	Damage.adapt(adaptive, {"water": 1.0}, false)
	equal(adaptive.immune_element, "water")
	near(Damage.against({"fire": 1.0}, adaptive, false), 1.0)
	var runner_group: Dictionary = _enemy()
	runner_group.speed = 1.0
	Combat.spawn(sim, runner_group, 5.0)
	Combat.spawn(sim, _enemy(["banner"]), 5.4)
	sim.step()
	var rallied: Dictionary = sim.state.mobs[0]
	near(rallied.s, 5.0 + 1.2 / sim.hz)
	check(EnemyRules.burrowed(EnemyRules.create(9, _enemy(["burrower"]), sim.track.total * .3, 0), sim.track.total))
	var thief: Dictionary = EnemyRules.create(10, _enemy(["thief"]), sim.track.total, 0)
	var gold: int = sim.state.gold
	sim.lose_lives(thief)
	equal(sim.state.gold, gold - 95)
	var capped: Dictionary = TowerRules.create(sim.next_id(), "s2", "arrow", "normal", "", 1000)
	capped.level = 6
	var target: Dictionary = TowerRules.create(sim.next_id(), "s4", "arrow", "normal", "", 50)
	sim.state.towers = {capped.slot: capped, target.slot: target}
	Combat.spawn(sim, _enemy(["saboteur"]), sim.track.total * .5)
	sim.step()
	check(not capped.has("sabotaged") and target.get("sabotaged", false))
	check(sim.apply({"type": "upgrade", "slot": target.slot}).ok)
	check(not target.has("sabotaged"))

func test_summoned_enemies_wait_when_the_battlefield_is_at_its_enemy_cap() -> void:
	var sim := Sim.new()
	sim.state.phase = "wave"
	var enemy: Dictionary = _enemy()
	for i: int in range(50):
		sim.schedule(enemy, 1, 1.0 + float(i) * .1)
	sim.step()
	equal(sim.state.mobs.size(), 48)
	equal(sim.state.spawn_queue.size(), 2)
