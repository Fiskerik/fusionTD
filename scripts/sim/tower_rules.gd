class_name TowerRules
extends RefCounted

static func create(id: int, slot: String, kind: String, element: String, dual: String, invested: int) -> Dictionary:
	return {
		"id": id, "slot": slot, "kind": kind, "element": element, "dual": dual, "level": 1,
		"infusion": "", "target": "first", "cooldown": 0, "invested": invested, "stun": 0,
		"hits": 0, "beam_target": -1, "beam_start": 0,
		"damage_dealt": 0.0, "kills": 0,
	}

static func stats(tower: Dictionary) -> Dictionary:
	if is_fusion(tower):
		return DataDB.read("triples" if tower.kind == "triple" else "duals")[tower.dual]
	var kind: String = tower.element if tower.kind in ["pure", "ascended"] else tower.kind
	return DataDB.read("towers")[kind]

static func display_name(tower: Dictionary) -> String:
	var title: String = stats(tower).name
	return "Pure " + title if tower.kind == "ascended" else title

static func progression(tower: Dictionary) -> Dictionary:
	var key: String = tower.kind + "_levels" if tower.kind in ["pure", "dual", "triple", "ascended"] else "normal_levels"
	return DataDB.read("towers")[key]

static func attack_profile(tower: Dictionary, victories: Dictionary = {}) -> Dictionary:
	var rule: Dictionary = stats(tower)
	var levels: Dictionary = progression(tower)
	var level: int = int(tower.level) - 1
	var config: Dictionary = DataDB.read("balance")
	var recipe_scale: float = float(config.fusion_starting_damage_scale) if is_fusion(tower) and level == 0 else 1.0
	var base_hit: float = float(rule.damage) * recipe_scale
	if tower.kind == "dual" and float(rule.rate) > 0:
		var towers: Dictionary = DataDB.read("towers")
		var stronger: float = maxf(float(towers[rule.pair[0]].damage), float(towers[rule.pair[1]].damage))
		var reference: int = int(config.fuse_min_level if level == 0 else config.dual_damage_reference_level)
		var input_hit: float = stronger * float(towers.pure_levels.damage[reference - 1])
		base_hit = maxf(base_hit * float(config.dual_damage_scale), input_hit * float(config.dual_min_hit_ratio))
	var potency: float = float(levels.potency[level]) if levels.has("potency") else 1.0
	if tower.infusion != "":
		potency = float(config.infusion.potency) * (1.0 + .14 * float(level - 1))
	var boost: float = spirit_multiplier(tower, victories)
	var damage: float = maxf(base_hit * float(levels.damage[level]), float(tower.get("fusion_damage_floor", 0.0)))
	damage *= boost * (1.0 + crystal_damage_bonus(tower))
	var splash_level: int = 5 if tower.kind == "ascended" else level
	var splash: float = float(rule.get("splash", 0.0)) + float(rule.get("splash_per_level", 0.0)) * splash_level
	return {"damage": damage, "rate": float(rule.rate) * float(levels.rate[level]), "range": attack_range(tower),
		"potency": potency, "splash": splash, "splash_core": splash * float(config.splash_core_ratio),
		"splash_fringe": float(config.splash_fringe_damage)}

static func crystal_damage_bonus(tower: Dictionary) -> float:
	return int(tower.get("crystals", 0)) * float(DataDB.read("balance").pure_crystal_damage)

static func spirit_multiplier(tower: Dictionary, victories: Dictionary) -> float:
	var boost: float = 0.0
	if not victories.is_empty():
		var split: Dictionary = damage_split(tower)
		for element: String in split:
			boost += float(split[element]) * spirit_bonus(element, victories)
	return 1.0 + boost

static func spirit_bonus(element: String, victories: Dictionary) -> float:
	var wins: int = int(victories.get(element, 0))
	return float((wins & 1) + ((wins >> 1) & 1)) * float(DataDB.read("balance").spirit_victory_damage)

static func aura_reaches_tile(origin: Vector2, tile_center: Vector2, radius: float) -> bool:
	var offset: Vector2 = ((tile_center - origin).abs() - Vector2(.5, .5)).max(Vector2.ZERO)
	var distance_squared: float = offset.length_squared()
	var radius_squared: float = radius * radius
	return distance_squared <= radius_squared or is_equal_approx(distance_squared, radius_squared)

static func attack_range(tower: Dictionary) -> float:
	var rule: Dictionary = stats(tower)
	return INF if rule.get("global_range", false) else float(rule.range)

static func level_requirement(tower: Dictionary, tier_by_element: Dictionary) -> String:
	var next: int = int(tower.level) + 1
	if next > progression(tower).damage.size():
		return DataDB.text("max_level")
	if tower.kind == "pure":
		var caps: Array = DataDB.read("balance").pure_caps
		var element: String = tower.element
		for tier: int in range(1, caps.size()):
			if next <= int(caps[tier]):
				if int(tier_by_element[element]) < tier:
					return DataDB.text("requires_tier") % [element.capitalize(), roman(tier)]
				break
	if tower.kind == "dual" and next == int(DataDB.read("balance").dual_cap):
		for element: String in stats(tower).pair:
			if int(tier_by_element[element]) < 2:
				return DataDB.text("requires_dual_tier") % element.capitalize()
	if tower.kind == "triple":
		for element: String in ingredients(tower):
			if int(tier_by_element[element]) < next:
				return DataDB.text("requires_tier") % [element.capitalize(), roman(next)]
	return ""

static func upgrade_cost(tower: Dictionary) -> int:
	var prices: Array = stats(tower).upgrade if tower.kind in ["arrow", "cannon"] else progression(tower).upgrade
	return int(prices[int(tower.level) - 1]) if int(tower.level) <= prices.size() else 0

static func infusion_tier(level: int, unlocked: int) -> int:
	var bands: Array = DataDB.read("balance").infusion.min_levels
	var tier: int = 0
	for index: int in range(bands.size()):
		if level >= int(bands[index]):
			tier = index + 1
	return mini(tier, unlocked)

static func infusion_cost(tier: int) -> int:
	return Economy.scaled(DataDB.read("balance").infusion.cost, tier)

static func trait_profile(tower: Dictionary, unlocked: Dictionary) -> Dictionary:
	if is_fusion(tower):
		return stats(tower).effect
	if tower.kind == "ascended":
		return DataDB.read("elements")[tower.element].effects[2]
	if tower.kind == "pure":
		var caps: Array = DataDB.read("balance").pure_caps
		for tier: int in range(1, caps.size()):
			if int(tower.level) <= int(caps[tier]):
				var available: int = clampi(int(unlocked.get(tower.element, 1)), 1, tier)
				return DataDB.read("elements")[tower.element].effects[available - 1]
		return {}
	var element: String = tower.infusion
	if element == "":
		return {}
	var tier: int = infusion_tier(tower.level, unlocked[element])
	return DataDB.read("elements")[element].effects[tier - 1]

static func recipe(first: String, second: String) -> String:
	for id: String in DataDB.read("duals"):
		var pair: Array = DataDB.read("duals")[id].pair
		if first != second and pair.has(first) and pair.has(second):
			return id
	return ""

static func primary_element(tower: Dictionary) -> String:
	match tower.get("kind", ""):
		"pure", "ascended":
			return tower.element
		"arrow", "cannon":
			return tower.infusion
	return ""

static func fusion_recipe(first: Dictionary, second: Dictionary) -> String:
	if not can_fuse(first) or not can_fuse(second):
		return ""
	var left: PackedStringArray = ingredients(first)
	var right: PackedStringArray = ingredients(second)
	var arity: int = left.size() + right.size()
	if left.is_empty() or right.is_empty() or arity > 3:
		return ""
	if arity == 2:
		return recipe(left[0], right[0])
	for element: String in right:
		if left.has(element):
			return ""
		left.append(element)
	for id: String in DataDB.read("triples"):
		var group: Array = DataDB.read("triples")[id].elements
		if group.has(left[0]) and group.has(left[1]) and group.has(left[2]):
			return id
	return ""

static func can_fuse(tower: Dictionary) -> bool:
	return tower.get("kind", "") in ["pure", "dual"]

static func fusion_cost(first: Dictionary, second: Dictionary) -> int:
	var balance: Dictionary = DataDB.read("balance")
	return int(balance.triple_fuse_cost if first.get("kind") == "dual" or second.get("kind") == "dual" else balance.fuse_cost)

static func is_fusion(tower: Dictionary) -> bool:
	return tower.get("kind", "") in ["dual", "triple"]

static func ingredients(tower: Dictionary) -> PackedStringArray:
	match tower.get("kind", ""):
		"dual": return PackedStringArray(stats(tower).pair)
		"triple": return PackedStringArray(stats(tower).elements)
	var element: String = primary_element(tower)
	return PackedStringArray() if element.is_empty() else PackedStringArray([element])

static func fusion_result(id: String, slot: String = "", tower_id: int = 0, invested: int = 0) -> Dictionary:
	return create(tower_id, slot, "triple" if DataDB.read("triples").has(id) else "dual", "", id, invested)

static func combine(id: String, first: Dictionary, second: Dictionary, tiers: Dictionary, victories: Dictionary, tower_id: int = 0) -> Dictionary:
	var invested: int = int(first.invested) + int(second.invested) + fusion_cost(first, second)
	var result: Dictionary = fusion_result(id, first.slot, tower_id, invested)
	var desired_level: int = mini(_fusion_level(first), _fusion_level(second))
	while int(result.level) < desired_level and level_requirement(result, tiers).is_empty():
		result.level += 1
	if float(stats(result).rate) > 0.0:
		var strongest_hit: float = maxf(attack_profile(first, victories).damage, attack_profile(second, victories).damage)
		result.fusion_damage_floor = strongest_hit / spirit_multiplier(result, victories)
	inherit_record(result, first, second)
	return result

static func _fusion_level(tower: Dictionary) -> int:
	return int(tower.level) if tower.kind == "dual" else infusion_tier(tower.level, 3)

static func inherit_record(result: Dictionary, first: Dictionary, second: Dictionary) -> void:
	result.damage_dealt = float(first.get("damage_dealt", 0.0)) + float(second.get("damage_dealt", 0.0))
	result.kills = int(first.get("kills", 0)) + int(second.get("kills", 0))

static func damage_split(tower: Dictionary) -> Dictionary:
	if is_fusion(tower):
		return stats(tower).split
	var element: String = primary_element(tower)
	if not element.is_empty():
		return {element: 1.0}
	return {"normal": 1.0}

static func roman(tier: int) -> String:
	return ["", "I", "II", "III"][tier]
