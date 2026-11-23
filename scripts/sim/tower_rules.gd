class_name TowerRules
extends RefCounted

const PURE_DISPLAY_LEVEL: int = 7
const DUAL_DPS_EDGE: float = 1.12
static var _triple_dps_by_pair: Dictionary = {}

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
	return String(stats(tower).pure_name) if tower.kind == "ascended" else title

static func progression(tower: Dictionary) -> Dictionary:
	var key: String = tower.kind + "_levels" if tower.kind in ["pure", "dual", "triple", "ascended"] else "normal_levels"
	return DataDB.read("towers")[key]

static func base_rate(tower: Dictionary, rule: Dictionary) -> float:
	return float(rule.get("rank_two_rate", rule.rate)) if int(tower.level) >= 2 else float(rule.rate)

static func _starter_triple_dps(id: String) -> float:
	if not _triple_dps_by_pair.has(id):
		var pair: Array = DataDB.read("duals")[id].pair
		var best: float = 0.0
		for recipe_id: String in DataDB.read("triples"):
			var recipe_rule: Dictionary = DataDB.read("triples")[recipe_id]
			if recipe_rule.elements.has(pair[0]) and recipe_rule.elements.has(pair[1]):
				var starter: Dictionary = create(0, "", "triple", "", recipe_id, 0)
				var profile: Dictionary = attack_profile(starter)
				best = maxf(best, float(profile.damage) * float(profile.rate))
		_triple_dps_by_pair[id] = best
	return _triple_dps_by_pair[id]

static func attack_profile(tower: Dictionary, victories: Dictionary = {}, boon: Dictionary = {}) -> Dictionary:
	var rule: Dictionary = stats(tower)
	var levels: Dictionary = progression(tower)
	var level: int = int(tower.level) - 1
	var config: Dictionary = DataDB.read("balance")
	var upgrade: float = upgrade_strength(tower)
	var recipe_scale: float = float(config.fusion_starting_damage_scale) if is_fusion(tower) and level == 0 else 1.0
	var elemental_scale: float = element_damage_scale(tower)
	var base_hit: float = float(rule.damage) * recipe_scale * elemental_scale
	var rate: float = base_rate(tower, rule) * float(levels.rate[level])
	if tower.kind == "dual" and rate > 0.0:
		var towers: Dictionary = DataDB.read("towers")
		var stronger: float = 0.0
		for element: String in rule.pair:
			var scale: float = 1.0 if element == "dark" else float(config.non_dark_element_damage_scale)
			stronger = maxf(stronger, float(towers[element].damage) * scale)
		var reference: int = int(config.fuse_min_level if level == 0 else config.dual_damage_reference_level)
		var input_hit: float = stronger * float(towers.pure_levels.damage[reference - 1])
		if level == 0 and reference > 1:
			input_hit *= float(config.upgraded_tower_strength)
		base_hit = maxf(base_hit * float(config.dual_damage_scale), input_hit * float(config.dual_min_hit_ratio))
	var boost: float = spirit_multiplier(tower, victories)
	var stored_floor: float = float(tower.get("fusion_damage_floor", 0.0)) * elemental_scale
	var damage: float = maxf(base_hit * float(levels.damage[level]), stored_floor)
	if tower.kind == "dual" and level >= 1 and rate > 0.0:
		# Compare against starter triples sharing this pair without changing the tower's firing rhythm.
		var dps_floor: float = _starter_triple_dps(tower.dual) * DUAL_DPS_EDGE * (1.0 if level == 1 else 1.4)
		damage = maxf(damage, dps_floor / rate)
	damage *= upgrade * boost * (1.0 + crystal_damage_bonus(tower)) * (1.0 + float(boon.get("damage", 0.0)))
	var splash_level: int = 5 if tower.kind == "ascended" else level
	var splash: float = float(rule.get("splash", 0.0)) + float(rule.get("splash_per_level", 0.0)) * splash_level
	if tower.infusion == "earth":
		splash += .72 + .08 * level
	splash *= upgrade * (1.0 + float(boon.get("splash", 0.0)))
	return {"damage": damage, "rate": rate * (1.0 + float(boon.get("rate", 0.0))),
		"range": attack_range(tower, float(boon.get("range", 0.0))),
		"potency": effect_potency(tower, boon), "splash": splash, "splash_core": splash * float(config.splash_core_ratio),
		"splash_fringe": float(config.splash_fringe_damage)}

static func crystal_damage_bonus(tower: Dictionary) -> float:
	return int(tower.get("crystals", 0)) * float(DataDB.read("balance").pure_crystal_damage)

static func upgrade_strength(tower: Dictionary) -> float:
	return float(DataDB.read("balance").upgraded_tower_strength) if int(tower.level) > 1 or tower.kind == "ascended" else 1.0

static func effect_potency(tower: Dictionary, boon: Dictionary = {}) -> float:
	var level: int = int(tower.level) - 1
	var levels: Dictionary = progression(tower)
	var potency: float = float(levels.potency[level]) if levels.has("potency") else 1.0
	if tower.infusion != "":
		potency = float(DataDB.read("balance").infusion.potency) * (1.0 + .14 * float(level - 1))
	return potency * upgrade_strength(tower) * (1.0 + float(boon.get("effect", 0.0)))

static func element_damage_scale(tower: Dictionary) -> float:
	var split: Dictionary = damage_split(tower)
	var boosted_share: float = 1.0 - float(split.get("dark", 0.0)) - float(split.get("normal", 0.0))
	return lerpf(1.0, float(DataDB.read("balance").non_dark_element_damage_scale), boosted_share)

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

static func support_sources(towers: Array) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	for tower: Dictionary in towers:
		if not is_fusion(tower):
			continue
		var effect: Dictionary = stats(tower).effect
		if effect.has("aura_damage") or effect.has("aura_speed") or effect.has("aura_range"):
			sources.append(tower)
	return sources

static func disabled(tower: Dictionary) -> bool:
	return int(tower.get("reflect", 0)) > 0 or bool(tower.get("sabotaged", false)) or bool(tower.get("petrified", false))

static func support_bonuses(tower: Dictionary, sources: Array[Dictionary], track: Track, slot: String = "", scopes: Dictionary = {}) -> Vector3:
	# Damage, attack rate, and attack range each use the strongest active aura.
	var bonuses := Vector3.ZERO
	if sources.is_empty():
		return bonuses
	var at: Vector2 = track.slots[tower.slot if slot.is_empty() else slot].position
	for source: Dictionary in sources:
		if source.dual == tower.dual or int(source.stun) > 0 or disabled(source):
			continue
		var rule: Dictionary = stats(source)
		var origin: Vector2 = track.slots[source.slot].position
		if aura_reaches_tile(origin, at, float(rule.range)):
			var effect: Dictionary = rule.effect
			var potency: float = effect_potency(source, RunBoons.for_tower(source, scopes))
			bonuses.x = maxf(bonuses.x, float(effect.get("aura_damage", 0.0)) * potency)
			bonuses.y = maxf(bonuses.y, float(effect.get("aura_speed", 0.0)) * potency)
			bonuses.z = maxf(bonuses.z, float(effect.get("aura_range", 0.0)) * potency)
	return bonuses

static func attack_range(tower: Dictionary, support_bonus: float = 0.0) -> float:
	var rule: Dictionary = stats(tower)
	if rule.get("global_range", false):
		return INF
	var range_levels: Array = progression(tower).get("range", [])
	var scale: float = 1.0 if range_levels.is_empty() else float(range_levels[int(tower.level) - 1])
	return float(rule.range) * scale * (1.0 + support_bonus)

static func level_requirement(tower: Dictionary, tier_by_element: Dictionary) -> String:
	var next: int = int(tower.level) + 1
	if next > progression(tower).damage.size():
		return DataDB.text("max_level")
	return rank_requirement(tower, next, tier_by_element)

static func rank_requirement(tower: Dictionary, level: int, tier_by_element: Dictionary) -> String:
	if tower.kind == "pure":
		var caps: Array = DataDB.read("balance").pure_caps
		for tier: int in range(1, caps.size()):
			if level <= int(caps[tier]):
				return _require_tier(tower.element, tier, tier_by_element)
	elif is_fusion(tower):
		for element: String in ingredients(tower):
			var requirement: String = _require_tier(element, level, tier_by_element)
			if not requirement.is_empty():
				return requirement
	return ""

static func _require_tier(element: String, tier: int, tier_by_element: Dictionary) -> String:
	return DataDB.text("requires_tier") % [element.capitalize(), roman(tier)] if int(tier_by_element.get(element, 0)) < tier else ""

static func can_socket_crystal(tower: Dictionary) -> bool:
	return tower.get("kind", "") == "pure" and int(tower.level) >= progression(tower).damage.size()

static func empower_pure(tower: Dictionary) -> void:
	tower.kind = "ascended"
	tower.level = 1

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

static func trait_profile(tower: Dictionary, unlocked: Dictionary, boon: Dictionary = {}) -> Dictionary:
	var traits: Dictionary = _base_traits(tower, unlocked)
	var upgrade: float = upgrade_strength(tower)
	var scale_fixed_effects: bool = upgrade > 1.0 and (traits.has("silence") or traits.has("heal_block"))
	if boon.is_empty() and not scale_fixed_effects:
		return traits
	traits = traits.duplicate(true)
	if scale_fixed_effects:
		for effect: String in ["silence", "heal_block"]:
			if traits.has(effect):
				traits[effect] = float(traits[effect]) * upgrade
	if traits.has("burn"):
		traits.burn[1] *= 1.0 + float(boon.get("burn_rate", 0.0))
	if traits.has("searing_burn"):
		traits.searing_burn[0] *= 1.0 + float(boon.get("burn_rate", 0.0))
	if traits.has("slow"):
		traits.slow[0] *= 1.0 + float(boon.get("slow", 0))
	if traits.has("chain"):
		traits.chain[0] = maxi(1, int(traits.chain[0]) + roundi(float(boon.get("chain", 0))))
	if boon.has("pierce"):
		traits.pierce = float(traits.get("pierce", 0)) + float(boon.pierce)
	return traits

static func _base_traits(tower: Dictionary, unlocked: Dictionary) -> Dictionary:
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
	var tier: int = maxi(1, infusion_tier(tower.level, unlocked[element]))
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

static func fusion_fee(first: Dictionary, second: Dictionary, tiers: Dictionary, base_fee: int) -> int:
	var result: Dictionary = fusion_result(fusion_recipe(first, second))
	var rank: int = _result_rank(result, first, second, tiers)
	var bands: Array = DataDB.read("balance").infusion.min_levels
	var pre_upgrades: int = 0
	for input: Dictionary in [first, second]:
		if input.kind == "dual":
			pre_upgrades += _rank_cost(input, 1, rank)
		else:
			pre_upgrades += _rank_cost(input, int(bands[0]), int(bands[rank - 1]))
	return maxi(0, base_fee + _rank_cost(result, 1, rank) - pre_upgrades)

static func _rank_cost(tower: Dictionary, from: int, to: int) -> int:
	var prices: Array = progression(tower).upgrade
	var cost: int = 0
	for level: int in range(from, to):
		cost += int(prices[level - 1])
	return cost

static func _result_rank(result: Dictionary, first: Dictionary, second: Dictionary, tiers: Dictionary) -> int:
	var desired: int = mini(_fusion_level(first), _fusion_level(second))
	var rank: int = 1
	while rank < desired and rank_requirement(result, rank + 1, tiers).is_empty():
		rank += 1
	return rank

static func combine(id: String, first: Dictionary, second: Dictionary, tiers: Dictionary, victories: Dictionary, tower_id: int = 0, fee: Variant = null) -> Dictionary:
	var paid: int = fusion_fee(first, second, tiers, fusion_cost(first, second)) if fee == null else int(fee)
	var invested: int = int(first.invested) + int(second.invested) + paid
	var result: Dictionary = fusion_result(id, first.slot, tower_id, invested)
	result.level = _result_rank(result, first, second, tiers)
	var crystals: int = int(first.get("crystals", 0)) + int(second.get("crystals", 0))
	if crystals > 0:
		result.crystals = crystals
	var reflect: int = maxi(int(first.get("reflect", 0)), int(second.get("reflect", 0)))
	if reflect > 0:
		result.reflect = reflect
	for status: String in ["stone_pending", "petrified"]:
		if first.get(status, false) or second.get(status, false):
			result[status] = true
	if base_rate(result, stats(result)) > 0.0:
		var strongest_hit: float = maxf(attack_profile(first, victories).damage, attack_profile(second, victories).damage)
		var scale: float = element_damage_scale(result) * spirit_multiplier(result, victories) * upgrade_strength(result)
		result.fusion_damage_floor = strongest_hit / (scale * (1.0 + crystal_damage_bonus(result)))
	inherit_record(result, first, second)
	return result

static func _fusion_level(tower: Dictionary) -> int:
	return int(tower.level) if tower.kind == "dual" else infusion_tier(tower.level, 3)

static func inherit_record(result: Dictionary, first: Dictionary, second: Dictionary) -> void:
	result.damage_dealt = float(first.get("damage_dealt", 0.0)) + float(second.get("damage_dealt", 0.0))
	result.kills = int(first.get("kills", 0)) + int(second.get("kills", 0))

static func damage_split(tower: Dictionary) -> Dictionary:
	if is_fusion(tower):
		if base_rate(tower, stats(tower)) <= 0.0:
			return {}
		return stats(tower).split
	var element: String = primary_element(tower)
	if not element.is_empty():
		return {element: 1.0}
	return {"normal": 1.0}

static func roman(tier: int) -> String:
	return ["", "I", "II", "III"][tier]
