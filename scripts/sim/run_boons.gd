class_name RunBoons
extends RefCounted

const LIMITS: Dictionary = {"damage": .45, "rate": .35, "range": .35, "effect": .30, "splash": .35,
	"slow": .25, "pierce": .25, "burn_stacks": 6, "chain": 3, "fusion_discount": .25}
const LABELS: Dictionary = {"damage": "damage", "rate": "attack speed", "range": "range", "effect": "effect potency",
	"splash": "splash radius", "slow": "slow strength", "pierce": "armor pierce", "burn_stacks": "burn stacks",
	"chain": "chain jumps", "fusion_discount": "fusion discount"}

static func offers(seed_value: int, reward: Dictionary, active_boon: Dictionary) -> PackedStringArray:
	var pool: Array = DataDB.read("run_boons").keys()
	pool.erase(active_boon.get("id", ""))
	var seed_offset: int = int(reward.index)
	var rng := SimRng.new((seed_value * 7919 + int(reward.wave) * 65537 + seed_offset * 104729 + 8749) & 0xffffffff)
	var result := PackedStringArray()
	for i: int in range(3):
		result.append(pool.pop_at(rng.take(pool.size())))
	return result

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

static func reward_potency(boss_kills: int) -> float:
	return 1.0 + .10 * clampi(boss_kills - 1, 0, 8)

static func amount(mod: Dictionary, potency: float) -> float:
	var value: float = float(mod.amount) * potency
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

static func describe(boon: Dictionary, potency: float) -> String:
	var lines := PackedStringArray()
	for mod: Dictionary in boon.mods:
		var value: float = amount(mod, potency)
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
