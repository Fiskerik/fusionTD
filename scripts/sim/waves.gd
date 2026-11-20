class_name Waves
extends RefCounted

static func generate(seed_value: int, wave: int, trial: Dictionary = {}) -> Dictionary:
	if not trial.is_empty():
		return {"wave": wave, "groups": [], "boss": {}, "bosses": [], "spirit": spirit_group(trial.element, int(trial.tier), wave)}
	var rules: Dictionary = DataDB.read("waves")
	var balance: Dictionary = DataDB.read("balance")
	var bosses: Dictionary = DataDB.read("bosses")
	var base: Dictionary = DataDB.read("mobs")
	var rng := SimRng.new((seed_value * 1000003 + wave * 7919 + 12345) & 0x7fffffff)
	var tuning: Dictionary = rules.adjustments.get(str(wave), {})
	var seeded_pattern: String = _pattern(wave, rules, rng)
	var pattern: Dictionary = rules.patterns[tuning.get("pattern", seeded_pattern)]
	var late: Dictionary = rules.late_game
	var late_waves: int = maxi(0, wave - int(late.after))
	var harder_waves: int = maxi(0, wave - int(rules.pressure.after))
	var hp: float = float(base.hp) * pow(float(balance.mob_hp_growth), wave - 1)
	hp *= 1.0 + harder_waves * float(rules.pressure.hp_per_wave)
	hp *= float(tuning.get("hp_scale", 1.0))
	hp *= 1.0 + late_waves * float(late.hp_per_wave)
	var gold: int = ceili(float(balance.kill_gold_base) * (1 + float(balance.kill_gold_growth) * (wave - 1)))
	var count: int = int(balance.mob_count_base) + floori(float(balance.mob_count_per_wave) * wave)
	count += floori(harder_waves * float(rules.pressure.added_count_per_wave))
	count = roundi(count * float(tuning.get("count_scale", 1.0)))
	var bosses_in_wave: Array[Dictionary] = []
	if late_waves > 0:
		count = mini(count, int(late.unit_cap))
	if wave % int(balance.boss_every) == 0:
		count = maxi(1, roundi(count * float(bosses.normal_count)))
		var boss_count: int = 1 if late_waves == 0 else (3 if wave >= int(late.third_boss_from) else 2)
		var first: int = (wave / int(balance.boss_every) - 1) % bosses.order.size()
		for index: int in range(boss_count):
			var boss_type: String = bosses.order[(first + index) % bosses.order.size()]
			var stats: Dictionary = bosses[boss_type]
			bosses_in_wave.append({
				"kind": "boss", "element": "none", "props": [], "count": 1, "interval": 0,
				"hp": hp * float(stats.hp_mult), "armor": float(stats.armor) + wave,
				"speed": float(stats.speed), "gold": Economy.scaled(bosses.gold, wave),
				"leak": int(balance.leak.boss), "slow_cap": float(stats.slow_cap),
				"boss_type": boss_type, "spawn": int(bosses.spawn_tick) + index * Effects.ticks(late.boss_spacing_seconds, balance.sim_hz),
				"armor_rank": EnemyRules.armor_rank(wave),
				"heal_aura": late_waves > 0 and boss_type == "necromancer",
			})
	var element: String = "none"
	var secondary: String = "none"
	var mixed: bool = wave >= int(rules.mixed_elements_from)
	if mixed or (wave >= int(rules.elemental_from) and rng.take(100) < roundi(float(rules.elemental_chance) * 100)):
		var pool_size: int = DataDB.ELEMENTS.size() if wave >= int(rules.all_elements_from) else 4
		var index: int = rng.take(pool_size)
		element = DataDB.ELEMENTS[index]
		if mixed:
			secondary = DataDB.ELEMENTS[(index + 1 + rng.take(pool_size - 1)) % pool_size]
	var elemental_share: float = rules.mixed_elemental_fraction if mixed else rules.elemental_fraction
	var groups: Array[Dictionary] = []
	var remaining: int = count
	for index: int in range(pattern.groups.size()):
		var part: Array = pattern.groups[index]
		var size: int = remaining if index == pattern.groups.size() - 1 else floori(count * float(part[1]))
		remaining -= size
		var props: Array = []
		var elite: bool = part[0] == "elite"
		if elite:
			var choices: Array = base.properties.keys()
			choices.erase("swarm")
			if late_waves > 0:
				choices.erase("splitter")
				choices.erase("revenant")
			props.append(choices.pop_at(rng.take(choices.size())))
			props.append(choices[rng.take(choices.size())])
		elif part[0] != "":
			props.append(part[0])
		var menders: int = floori(float(size) / float(pattern.mender_per)) if pattern.has("mender_per") else 0
		var normal: Dictionary = _group(wave, size - menders, props, hp, gold, elite)
		normal.interval = int(pattern.get("interval", rules.interval))
		_add_group(groups, normal, element, secondary, elemental_share, index)
		if menders > 0:
			var support: Dictionary = _group(wave, menders, ["mender"], hp, gold, false)
			support.interval = int(rules.interval)
			_add_group(groups, support, element, secondary, elemental_share, index + 1)
	var boss: Dictionary = {} if bosses_in_wave.is_empty() else bosses_in_wave[0]
	return {"wave": wave, "groups": groups, "boss": boss, "bosses": bosses_in_wave, "spirit": {}}

static func spirit_group(element: String, tier: int, wave: int) -> Dictionary:
	var data: Dictionary = DataDB.read("spirits")
	var stats: Dictionary = data.tiers[tier - 1]
	return {
		"kind": "spirit", "element": element, "tier": tier, "props": [], "count": 1, "interval": 0,
		"hp": float(stats.hp) * pow(float(stats.growth), maxi(0, wave - int(stats.from))),
		"armor": float(stats.armor), "speed": float(data.speed), "gold": Economy.scaled(data.gold, wave),
		"leak": int(DataDB.read("balance").leak.spirit), "slow_cap": float(data.slow_cap),
		"spawn": int(data.spawn_tick),
	}

static func _pattern(wave: int, rules: Dictionary, rng: SimRng) -> String:
	if wave <= rules.forced.size():
		return rules.forced[wave - 1]
	var pool: Array[String] = []
	for key: String in rules.patterns:
		if wave > int(rules.late_game.after) and key in ["swarm", "split", "revenant"]:
			continue
		var pattern: Dictionary = rules.patterns[key]
		if int(pattern.get("introduce", 0)) == wave:
			return key
		if int(pattern.min) <= wave:
			for entry: int in range(int(pattern.weight)):
				pool.append(key)
	return pool[rng.take(pool.size())]

static func _group(wave: int, count: int, props: Array, hp: float, gold: int, elite: bool) -> Dictionary:
	var base: Dictionary = DataDB.read("mobs")
	var families: Array[String] = []
	for family: String in base.families:
		var first_wave: int = int(base.families[family].get("appears_from", 0))
		if (wave < 20 and first_wave == 0) or (wave >= 20 and first_wave > 0 and wave >= first_wave):
			families.append(family)
	var family_index: int = wave - 1 if wave < 20 else wave - 20
	var armor: float = 0.0
	var speed: float = float(base.speed)
	var reward: float = float(gold)
	for prop: String in props:
		var rule: Dictionary = base.properties[prop]
		hp *= float(rule.get("hp", 1.0)) if prop in ["swift", "armored", "swarm"] else 1.0
		speed *= float(rule.get("speed", 1.0))
		reward *= float(rule.get("gold", 1.0))
		count = roundi(count * float(rule.get("count", 1.0))) if prop == "swarm" else count
		if prop == "armored":
			armor = float(rule.armor[0]) + float(rule.armor[1]) * wave
	if elite:
		hp *= float(base.elite.hp)
		reward *= float(base.elite.gold)
	var pressure: Dictionary = DataDB.read("waves").pressure
	var harder_waves: int = maxi(0, wave - int(pressure.after))
	var fast: bool = props.has("swift")
	var armor_scale: float = float(base.properties.swift.pressure_armor_scale) if fast else 1.0
	armor += harder_waves * float(pressure.armor_per_wave) * armor_scale
	var late: Dictionary = DataDB.read("waves").late_game
	armor += maxi(0, wave - int(late.after)) * float(late.armor_per_wave) * armor_scale
	if fast:
		speed *= 1.0 + minf(float(pressure.speed_cap), harder_waves * float(pressure.speed_per_wave))
	return {
		"kind": "grunt", "element": "none", "props": props, "count": count, "hp": hp,
		"armor": armor, "speed": speed, "gold": ceili(reward), "leak": int(DataDB.read("balance").leak.mob),
		"slow_cap": float(base.slow_cap), "family": families[family_index % families.size()],
		"season": floori(float(wave - 1) / families.size()) % 3,
		"armor_rank": EnemyRules.armor_rank(wave), "control_resistance": EnemyRules.control_resistance(wave),
	}

static func _add_group(groups: Array[Dictionary], group: Dictionary, element: String, secondary: String, fraction: float, index: int) -> void:
	var elemental: int = floori(int(group.count) * fraction) if element != "none" else 0
	group.count = int(group.count) - elemental
	if int(group.count) > 0:
		groups.append(group)
	var second_count: int = 0 if secondary == "none" else floori((elemental + (index % 2)) / 2.0)
	for part: Array in [[element, elemental - second_count], [secondary, second_count]]:
		if int(part[1]) <= 0:
			continue
		var variant: Dictionary = group.duplicate()
		variant.element = part[0]
		variant.count = part[1]
		groups.append(variant)
