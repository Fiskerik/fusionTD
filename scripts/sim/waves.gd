class_name Waves
extends RefCounted

static func unit_cap() -> int:
	return int(DataDB.read("waves").unit_cap)

static func generate(seed_value: int, wave: int, trial: Dictionary = {}, roll_weaknesses: bool = true,
		expanded_roster: bool = true, campaign_track: Track = null) -> Dictionary:
	if not trial.is_empty():
		return {"wave": wave, "groups": [], "boss": {}, "bosses": [], "spirit": spirit_group(trial.element, int(trial.tier), wave)}
	var rules: Dictionary = DataDB.read("waves")
	var balance: Dictionary = DataDB.read("balance")
	var bosses: Dictionary = DataDB.read("bosses")
	var base: Dictionary = DataDB.read("mobs")
	var rng := SimRng.new((seed_value * 1000003 + wave * 7919 + 12345) & 0x7fffffff)
	var bonus_rng := SimRng.new(rng.state ^ 0x53a9c1)
	var weakness_rng := SimRng.new(rng.state ^ 0x7c694e31)
	var tuning: Dictionary = rules.adjustments.get(str(wave), {})
	var seeded_pattern: String = _pattern(wave, rules, rng)
	var pattern: Dictionary = rules.patterns[tuning.get("pattern", seeded_pattern)]
	var late: Dictionary = rules.late_game
	var late_waves: int = maxi(0, wave - int(late.after))
	var harder_waves: int = maxi(0, wave - int(rules.pressure.after))
	var hp: float = base_enemy_hp(wave)
	hp *= 1.0 + harder_waves * float(rules.pressure.hp_per_wave)
	hp *= float(tuning.get("hp_scale", 1.0))
	hp *= 1.0 + late_waves * float(late.hp_per_wave)
	var gold: int = ceili(float(balance.kill_gold_base) * (1 + float(balance.kill_gold_growth) * (wave - 1)))
	var count: int = int(balance.mob_count_base) + floori(float(balance.mob_count_per_wave) * wave)
	count += floori(harder_waves * float(rules.pressure.added_count_per_wave))
	count = roundi(count * float(tuning.get("count_scale", 1.0)))
	var bonus: Dictionary = rules.bonus_mob
	var include_bonus: bool = bonus_rng.take(100) < int(bonus.chance_percent)
	if wave % int(balance.boss_every) == 0:
		var bosses_in_wave: Array[Dictionary] = []
		var health_adjustment: Dictionary = bosses.health_adjustment
		var boss_hp: float = hp * float(health_adjustment.multiplier) if wave >= int(health_adjustment.from) else hp
		var boss_count: int = 1 if late_waves == 0 else (3 if wave >= int(late.third_boss_from) else 2)
		var roster_size: int = bosses.order.size() if expanded_roster else 3
		var first: int = (wave / int(balance.boss_every) - 1) % roster_size
		for index: int in range(boss_count):
			var boss_type: String = bosses.order[(first + index) % roster_size]
			var stats: Dictionary = bosses[boss_type]
			bosses_in_wave.append({
				"kind": "boss", "element": stats.element, "props": [], "count": 1, "interval": 0,
				"hp": boss_hp * float(stats.hp_mult), "armor": float(stats.armor) + wave,
				"speed": float(stats.speed), "gold": Economy.scaled(bosses.gold, wave),
				"leak": int(balance.leak.boss), "slow_cap": float(base.slow_cap),
				"control_resistance": float(bosses.control_resistance),
				"boss_type": boss_type, "spawn": int(bosses.spawn_tick) + index * Effects.ticks(late.boss_spacing_seconds, balance.sim_hz),
				"armor_rank": EnemyRules.armor_rank(wave),
				"heal_aura": late_waves > 0 and boss_type == "necromancer",
			})
			if boss_type == "ram":
				if expanded_roster:
					bosses_in_wave[-1].turn_seconds = float(stats.turn_seconds)
				else:
					bosses_in_wave[-1].hp = boss_hp * 11.0
					bosses_in_wave[-1].speed = .4
			if stats.has("weakness"):
				bosses_in_wave[-1].weakness = stats.weakness
			elif roll_weaknesses and stats.element != "none":
				bosses_in_wave[-1].weakness = _roll_weakness(weakness_rng, stats.element)
		return {"wave": wave, "groups": [], "boss": bosses_in_wave[0], "bosses": bosses_in_wave, "spirit": {}}
	var veterans: Dictionary = rules.veterans
	hp *= 1.0 + maxi(0, wave - int(veterans.from) + 1) * float(veterans.hp_per_wave)
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
	var scheduled_cap: int = floori(float(unit_cap()) * float(tuning.get("count_scale", 1.0)))
	_limit_groups(groups, scheduled_cap - (1 if include_bonus else 0))
	if include_bonus:
		var courier: Dictionary = _group(wave, 1, [], hp, gold, false)
		courier.kind = "bonus"
		courier.family = "hare"
		courier.hp *= 2.0
		courier.armor *= 2.0
		courier.gold += int(bonus.extra_gold)
		courier.speed = (campaign_track.total if campaign_track != null else Track.new().total) / float(bonus.travel_seconds)
		courier.slow_cap = 0.0
		courier.control_resistance = 0.0
		courier.interval = int(rules.interval)
		groups.insert(maxi(1, groups.size() / 2), courier)
	if campaign_track != null:
		_add_specials(groups, wave, SimRng.new((seed_value * 65537 + wave * 1879) ^ 0x6d1da1))
	if roll_weaknesses and wave >= int(rules.elemental_from):
		var weaknesses: Dictionary = {}
		for group: Dictionary in groups:
			var affinity: String = group.element
			if not weaknesses.has(affinity):
				weaknesses[affinity] = _roll_weakness(weakness_rng, affinity)
			group.weakness = weaknesses[affinity]
	return {"wave": wave, "groups": groups, "boss": {}, "bosses": [], "spirit": {}}

static func _limit_groups(groups: Array[Dictionary], limit: int) -> void:
	var remaining: int = 0
	for group: Dictionary in groups:
		remaining += int(group.count)
	if remaining <= limit:
		return
	for index: int in range(groups.size()):
		var group: Dictionary = groups[index]
		var old: int = int(group.count)
		var reserve: int = groups.size() - index - 1
		group.count = clampi(roundi(float(old) * limit / remaining), 1, limit - reserve)
		remaining -= old
		limit -= int(group.count)

static func _add_specials(groups: Array[Dictionary], wave: int, rng: SimRng) -> void:
	var types: Dictionary = DataDB.read("mobs").specials
	var available: Array[String] = []
	var picks: Array[String] = []
	for id: String in types:
		if wave == int(types[id].first):
			picks.append(id)
		elif wave > int(types[id].first):
			available.append(id)
	if picks.is_empty() and not available.is_empty() and (wave >= 20 or rng.take(3) == 0):
		var total: int = 3 if wave >= 80 else (2 if wave >= 50 else 1)
		if wave >= 30 and wave < 50 and rng.take(3) == 0:
			total += 1
		for index: int in range(mini(total, available.size())):
			picks.append(available.pop_at(rng.take(available.size())))
	for id: String in picks:
		var candidates: Array[Dictionary] = groups.filter(func(group: Dictionary) -> bool: return group.kind == "grunt" and int(group.count) > 1)
		if candidates.is_empty():
			return
		var source: Dictionary = candidates[rng.take(candidates.size())]
		source.count -= 1
		var special: Dictionary = source.duplicate()
		var rule: Dictionary = types[id]
		special.count = 1
		special.props = [id]
		special.family = rule.family
		special.hp *= float(rule.hp)
		special.speed *= float(rule.speed)
		groups.insert(groups.find(source) + 1, special)

static func _roll_weakness(rng: SimRng, affinity: String) -> String:
	var pool: Array[String] = []
	for element: String in DataDB.ELEMENTS:
		if element != affinity and Damage.matchup(element, affinity) >= 1.0:
			pool.append(element)
	return pool[rng.take(pool.size())]

static func base_enemy_hp(wave: int) -> float:
	var health: float = float(DataDB.read("mobs").hp)
	health *= pow(float(DataDB.read("balance").mob_hp_growth), wave - 1)
	var boost: Dictionary = DataDB.read("waves").health_boost
	return health * float(boost.multiplier) if wave >= int(boost.from) else health

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
	var veterans: Dictionary = DataDB.read("waves").veterans
	armor += maxi(0, wave - int(veterans.from) + 1) * float(veterans.armor_per_wave) * armor_scale
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
