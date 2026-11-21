class_name RunBoons
extends RefCounted

const LIMITS: Dictionary = {"damage": .45, "rate": .35, "range": .35, "effect": .30, "splash": .35,
	"slow": .25, "pierce": .25, "burn_stacks": 6, "chain": 3, "fusion_discount": .25}
const LABELS: Dictionary = {"damage": "damage", "rate": "attack speed", "range": "range", "effect": "effect potency",
	"splash": "splash radius", "slow": "slow strength", "pierce": "armor pierce", "burn_stacks": "burn stacks",
	"chain": "chain jumps", "fusion_discount": "fusion discount"}

static func offers(seed_value: int, reward: Dictionary, picks: Array) -> PackedStringArray:
	var pool: Array = DataDB.read("run_boons").keys()
	var unused: Array = pool.duplicate()
	for pick: Dictionary in picks:
		unused.erase(pick.id)
	var seed_offset: int = int(reward.index) + (100 if reward.source == "spirit" else 0)
	var rng := SimRng.new((seed_value * 7919 + int(reward.wave) * 65537 + seed_offset * 104729 + 8749) & 0xffffffff)
	var result := PackedStringArray()
	for i: int in range(3):
		var available: Array = unused if not unused.is_empty() else pool
		var id: String = available[rng.take(available.size())]
		result.append(id)
		unused.erase(id)
		pool.erase(id)
	return result

static func total(picks: Array) -> Dictionary:
	var scopes: Dictionary = {}
	var library: Dictionary = DataDB.read("run_boons")
	for pick: Dictionary in picks:
		for mod: Dictionary in library[pick.id].mods:
			var stats: Dictionary = scopes.get(mod.scope, {})
			stats[mod.stat] = float(stats.get(mod.stat, 0.0)) + amount(mod, int(pick.wave))
			scopes[mod.scope] = stats
	return scopes

static func amount(mod: Dictionary, wave: int) -> float:
	var value: float = float(mod.amount) * (1.0 + .20 * mini(4, maxi(0, (wave - 1) / 20)))
	if mod.stat in ["burn_stacks", "chain"]:
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
		if scope == tower.kind or (scope == "fusion" and TowerRules.is_fusion(tower)):
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

static func describe(boon: Dictionary, wave: int) -> String:
	var lines := PackedStringArray()
	for mod: Dictionary in boon.mods:
		var value: float = amount(mod, wave)
		var percentage: float = snappedf(absf(value) * 100.0, .01)
		var percent_text: String = str(roundi(percentage)) if is_equal_approx(percentage, roundf(percentage)) else String.num(percentage, 2)
		var unit: String = str(roundi(absf(value))) if mod.stat in ["burn_stacks", "chain"] else percent_text + "%"
		lines.append("%s %s%s %s" % [tag_name(mod.scope), "+" if value >= 0.0 else "−", unit, LABELS[mod.stat]])
	return "\n".join(lines)

static func tag_name(scope: String) -> String:
	match scope:
		"normal": return "Neutral"
		"ascended": return "Pure"
		"dual": return "Dual fusion"
		"triple": return "Triple fusion"
	return scope.capitalize()
