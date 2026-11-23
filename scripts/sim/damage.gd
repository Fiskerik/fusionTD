class_name Damage
extends RefCounted

const WEAKNESS_MULTIPLIER: float = 1.5

static func matchup(attacker: String, defender: String, rolled_weakness: String = "") -> float:
	var fixed: String = fixed_weakness(defender)
	if not fixed.is_empty():
		rolled_weakness = fixed
	if not rolled_weakness.is_empty():
		if attacker == rolled_weakness:
			return WEAKNESS_MULTIPLIER
		return minf(1.0, _base_matchup(attacker, defender))
	return _base_matchup(attacker, defender)

static func _base_matchup(attacker: String, defender: String) -> float:
	if defender == "none" or attacker == "normal":
		return 1.0
	if attacker in ["light", "dark"] and defender in ["light", "dark"]:
		return 0.75 if attacker == defender else WEAKNESS_MULTIPLIER
	var elements: Dictionary = DataDB.read("elements")
	if elements.get(defender, {}).get("weak", "") == attacker:
		return WEAKNESS_MULTIPLIER
	return .75 if elements.get(attacker, {}).get("weak", "") == defender else 1.0

static func fixed_weakness(element: String) -> String:
	var affinity: Dictionary = DataDB.read("elements").get(element, {})
	return affinity.weak if affinity.get("fixed_weakness", false) else ""

static func blend(split: Dictionary, defender: String, rolled_weakness: String = "") -> float:
	var result: float = 0.0
	for element: String in split:
		result += float(split[element]) * matchup(element, defender, rolled_weakness)
	return result

static func against(split: Dictionary, enemy: Dictionary, adaptive: bool) -> float:
	if adaptive:
		return maxf(against_element("light", enemy), against_element("dark", enemy))
	var multiplier: float = 0.0
	for element: String in split:
		multiplier += float(split[element]) * against_element(element, enemy)
	return multiplier

static func against_element(element: String, enemy: Dictionary) -> float:
	if element == enemy.get("immune_element", "") and int(enemy.get("silence_time", 0)) == 0:
		return 0.0
	if has_special_resistances(enemy):
		return special_matchup(element, enemy)
	return matchup(element, enemy.element, enemy.get("weakness", ""))

static func adapt(enemy: Dictionary, split: Dictionary, adaptive: bool) -> void:
	if EnemyRules.dispelled(enemy) or not EnemyRules.property(enemy, "chameleon"):
		return
	var options: Dictionary = {"light": 1.0, "dark": 1.0} if adaptive else split
	var strongest: float = 0.0
	var last: String = ""
	for element: String in options:
		var hit: float = float(options[element]) * against_element(element, enemy)
		if element != "normal" and hit > strongest:
			last = element
			strongest = hit
	if not last.is_empty():
		enemy.immune_element = last

static func has_special_resistances(enemy: Dictionary) -> bool:
	return enemy.get("boss_type", "") in ["prismheart", "ironwood"]

static func special_matchup(attacker: String, enemy: Dictionary) -> float:
	match enemy.get("boss_type", ""):
		"ironwood":
			var armor: Dictionary = DataDB.read("bosses").ironwood
			return float(armor.neutral_damage if attacker == "normal" else armor.elemental_damage)
		"prismheart":
			if attacker == enemy.element:
				return float(DataDB.read("bosses").prismheart.same_element_damage)
			return _base_matchup(attacker, enemy.element)
	return 1.0

static func weakness_multiplier(enemy: Dictionary) -> float:
	return float(DataDB.read("bosses").ironwood.neutral_damage) if enemy.get("boss_type", "") == "ironwood" else WEAKNESS_MULTIPLIER

static func weakness(enemy: Dictionary) -> String:
	var affinity: Dictionary = DataDB.read("elements").get(enemy.element, {})
	if affinity.get("fixed_weakness", false):
		return affinity.weak
	return enemy.get("weakness", affinity.get("weak", ""))

static func hit(raw: float, armor: float, pierce: float, shred: float, curse: float) -> float:
	var amplified: float = raw * (1.0 + curse)
	var remaining: float = maxf(0.0, armor * (1.0 - pierce) - shred)
	return maxf(amplified - remaining, amplified * float(DataDB.read("balance").armor_floor))

static func deal(enemy: Dictionary, amount: float, tower: Dictionary, at_tick: int = -1) -> void:
	if enemy.kind == "boss":
		amount *= 1.0 - float(DataDB.read("bosses").damage_reduction)
	var dealt: float = minf(maxf(0.0, float(enemy.hp)), amount)
	enemy.hp -= amount
	if dealt <= 0.0:
		return
	if at_tick >= 0:
		var history: Array = enemy.get("damage_history", [])
		if history.is_empty() or int(history[-1][0]) != at_tick:
			history.append([at_tick, dealt])
		else:
			history[-1][1] += dealt
		enemy.damage_history = history
		enemy.recent_damage = float(enemy.get("recent_damage", 0.0)) + dealt
	if not tower.is_empty():
		tower.damage_dealt = float(tower.get("damage_dealt", 0.0)) + dealt
	if float(enemy.hp) <= 0.0:
		enemy.kill_credit = int(tower.get("id", -1))

static func expire_history(enemy: Dictionary, cutoff: int) -> void:
	var history: Array = enemy.get("damage_history", [])
	if history.is_empty() or int(history[0][0]) > cutoff:
		return
	var total: float = float(enemy.recent_damage)
	while not history.is_empty() and int(history[0][0]) <= cutoff:
		total -= float(history.pop_front()[1])
	enemy.recent_damage = 0.0 if history.is_empty() else maxf(0.0, total)
