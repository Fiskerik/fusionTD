class_name Damage
extends RefCounted

const RING: Dictionary = {"fire": "nature", "nature": "electric", "electric": "water", "water": "fire"}

static func matchup(attacker: String, defender: String) -> float:
	if defender == "none" or attacker == "normal":
		return 1.0
	if attacker in ["light", "dark"] and defender in ["light", "dark"]:
		return 0.75 if attacker == defender else 1.5
	if RING.get(attacker) == defender:
		return 1.5
	if RING.get(defender) == attacker:
		return 0.75
	return 1.0

static func blend(split: Dictionary, defender: String) -> float:
	var result: float = 0.0
	for element: String in split:
		result += float(split[element]) * matchup(element, defender)
	return result

static func hit(raw: float, armor: float, pierce: float, shred: float, curse: float) -> float:
	var amplified: float = raw * (1.0 + curse)
	var remaining: float = maxf(0.0, armor * (1.0 - pierce) - shred)
	return maxf(amplified - remaining, amplified * float(DataDB.read("balance").armor_floor))

static func deal(enemy: Dictionary, amount: float, tower: Dictionary, at_tick: int = -1) -> void:
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
