class_name RunBoons
extends RefCounted

const LIMITS: Dictionary = {"damage": .45, "rate": .35, "range": .35, "effect": .30, "splash": .35,
	"slow": .25, "pierce": .25, "burn_rate": .30, "chain": 3, "fusion_discount": .25, "clear_gold": .20}
const LABELS: Dictionary = {"damage": "damage", "rate": "attack speed", "range": "range", "effect": "effect potency",
	"splash": "splash radius", "slow": "slow strength", "pierce": "armor pierce", "burn_rate": "burn damage",
	"chain": "chain jumps", "fusion_discount": "fusion discount", "clear_gold": "wave-clear gold"}

static func offers(seed_value: int, reward: Dictionary, active_boon: Dictionary, tiers: Dictionary) -> PackedStringArray:
	var library: Dictionary = DataDB.read("run_boons")
	var general := PackedStringArray()
	var by_element: Dictionary = {}
	for id: String in library:
		if id == active_boon.get("id", ""):
			continue
		var boon: Dictionary = library[id]
		var scope: String = boon.mods[0].scope
		if boon.get("general", false):
			general.append(id)
		elif DataDB.ELEMENTS.has(scope):
			var pool: Array = by_element.get(scope, [])
			pool.append(id)
			by_element[scope] = pool
	var seed_offset: int = int(reward.index)
	var rng := SimRng.new((seed_value * 7919 + int(reward.wave) * 65537 + seed_offset * 104729 + 8749) & 0xffffffff)
	var general_pick: String = general[rng.take(general.size())]
	var unlocked: Array[String] = unlocked_elements(tiers)
	var available: Array = by_element.keys()
	var owned_pool: Array = available if unlocked.is_empty() else unlocked
	var owned_element: String = owned_pool[rng.take(owned_pool.size())]
	var owned_options: Array = by_element[owned_element]
	var owned: String = owned_options.pop_at(rng.take(owned_options.size()))
	var empowered_element: String = available[rng.take(available.size())]
	var empowered_options: Array = by_element[empowered_element]
	var empowered: String = empowered_options[rng.take(empowered_options.size())]
	return PackedStringArray([general_pick, owned, empowered])

static func unlocked_elements(tiers: Dictionary) -> Array[String]:
	var unlocked: Array[String] = []
	for element: String in DataDB.ELEMENTS:
		if int(tiers.get(element, 0)) > 0:
			unlocked.append(element)
	return unlocked

static func offer_potency(potency: float, index: int) -> float:
	return potency * [0.65, 1.0, 1.5][index]

static func modifiers(active_boon: Dictionary) -> Dictionary:
	if active_boon.is_empty():
		return {}
	var scopes: Dictionary = {}
	var boon: Dictionary = DataDB.read("run_boons")[active_boon.id]
	for mod: Dictionary in boon.mods:
		var stats: Dictionary = scopes.get(mod.scope, {})
		stats[mod.stat] = amount(mod, float(active_boon.potency))
		scopes[mod.scope] = stats
	return scopes

static func reward_potency(wave: int) -> float:
	var steps: float = maxf(0.0, (wave - 10) / 10.0)
	return 1.0 + .10 * minf(steps, 9.0) + .04 * maxf(0.0, steps - 9.0)

static func amount(mod: Dictionary, potency: float) -> float:
	var value: float = float(mod.amount) * potency
	if mod.stat == "chain":
		value = roundf(value)
	return limited(mod.stat, value)

static func limited(stat: String, value: float) -> float:
	return clampf(value, -.25, float(LIMITS[stat]))

static func for_tower(tower: Dictionary, scopes: Dictionary) -> Dictionary:
	if scopes.is_empty():
		return {}
	var stats: Dictionary = {}
	var split: Dictionary = TowerRules.damage_split(tower)
	for scope: String in scopes:
		var weight: float = float(split.get(scope, 0.0))
		if scope == "all" or scope == tower.kind or (scope == "fusion" and TowerRules.is_fusion(tower)):
			weight = 1.0
		if weight <= 0.0:
			continue
		for stat: String in scopes[scope]:
			stats[stat] = float(stats.get(stat, 0.0)) + float(scopes[scope][stat]) * weight
	for stat: String in stats:
		stats[stat] = limited(stat, stats[stat])
	return stats

static func tags(boon: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for mod: Dictionary in boon.mods:
		if not result.has(mod.scope):
			result.append(mod.scope)
	return result

static func describe(boon: Dictionary, potency: float) -> String:
	var lines := PackedStringArray()
	for mod: Dictionary in boon.mods:
		var label: String = tag_name(mod.scope)
		var prefix: String = label + " " if not label.is_empty() else ""
		lines.append("%s%s %s" % [prefix, signed_value(mod.stat, amount(mod, potency)), LABELS[mod.stat]])
	return "\n".join(lines)

static func signed_value(stat: String, value: float) -> String:
	var percentage: float = snappedf(absf(value) * 100.0, .01)
	var unit: String = str(roundi(percentage)) if is_equal_approx(percentage, roundf(percentage)) else String.num(percentage, 2)
	unit = str(roundi(absf(value))) if stat == "chain" else unit + "%"
	return ("+" if value >= 0.0 else "−") + unit

static func stat_icon(stat: String) -> String:
	match stat:
		"rate", "slow": return "speed"
		"damage", "burn_rate": return "damage"
		"pierce": return "armor"
		"clear_gold", "fusion_discount": return "gold"
		"range", "splash": return stat
	return "boon"

static func tag_name(scope: String) -> String:
	match scope:
		"all": return "All towers"
		"economy": return ""
		"normal": return "Neutral"
		"ascended": return "Pure"
		"dual": return "Dual fusion"
		"triple": return "Triple fusion"
	return scope.capitalize()
