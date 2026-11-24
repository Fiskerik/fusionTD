class_name EnemyRules
extends RefCounted

static func create(id: int, group: Dictionary, distance: float, born: int) -> Dictionary:
	var enemy := {
		"id": id, "kind": group.kind, "element": group.element, "tier": int(group.get("tier", 0)),
		"props": group.props, "hp": float(group.hp), "max_hp": float(group.hp), "armor": float(group.armor),
		"speed": float(group.speed), "s": distance, "prev_s": distance, "gold": int(group.gold),
		"leak": int(group.leak), "slow_cap": float(group.slow_cap), "born": born,
		"dots": {}, "slow": 0.0, "slow_time": 0, "curse": 0.0, "curse_time": 0, "shred": 0.0,
		"shred_time": 0, "shred_stacks": 0, "freeze_time": 0, "root_time": 0, "silence_time": 0,
		"heal_block_time": 0, "revived": bool(group.get("revived", false)), "boss_type": group.get("boss_type", ""),
		"telegraph": {}, "family": group.get("family", "acorn"), "season": int(group.get("season", 0)),
		"armor_rank": int(group.get("armor_rank", 0)), "control_resistance": float(group.get("control_resistance", 0.0)),
		"heal_aura": bool(group.get("heal_aura", false)),
	}
	if group.has("weakness"):
		enemy.weakness = group.weakness
	if group.has("forms"):
		enemy.forms = group.forms
	if group.has("turn_seconds"):
		enemy.turn_seconds = group.turn_seconds
	if group.kind == "boss":
		enemy.control_resistance = float(DataDB.read("bosses").control_resistance)
		enemy.reflect_wave = int(group.get("reflect_wave", 1))
	if group.get("finale", false):
		enemy.finale = true
	return enemy

static func reflect_rule(wave: int) -> Dictionary:
	var rules: Array = DataDB.read("bosses").reflect
	for rule: Dictionary in rules:
		if wave >= int(rule.from_wave):
			return rule
	return rules.back()

static func is_first_boss(enemy: Dictionary) -> bool:
	return enemy.get("boss_type", "") == "warlock" and int(enemy.get("reflect_wave", 0)) == int(DataDB.read("balance").boss_every)

static func has_rebirth(enemy: Dictionary) -> bool:
	return enemy.get("boss_type", "") == "necromancer" and int(enemy.get("reflect_wave", 0)) == int(DataDB.read("bosses").necromancer.rebirth.wave)

static func reflect_window_start(enemy: Dictionary, tick: int, hz: float, rule: Dictionary) -> int:
	if is_first_boss(enemy) and enemy.has("reflect_ready_tick"):
		return -1
	var start: int = int(enemy.get("reflect_ready_tick", enemy.born))
	if tick < start:
		return -1
	var active: int = Effects.ticks(rule.active_seconds, hz)
	var elapsed: int = (tick - start) % (active + Effects.ticks(rule.cooldown_seconds, hz))
	return tick - elapsed if elapsed < active else -1

static func reflect_ready(enemy: Dictionary, tick: int, hz: float) -> bool:
	if enemy.kind != "boss":
		return false
	var rule: Dictionary = reflect_rule(int(enemy.get("reflect_wave", 1)))
	return reflect_window_start(enemy, tick, hz, rule) >= 0

static func airborne(enemy: Dictionary) -> bool:
	return enemy.get("boss_type", "") == "tempest"

static func update_form(enemy: Dictionary, tick: int, hz: float) -> void:
	var forms: PackedStringArray = enemy.get("forms", PackedStringArray())
	if forms.size() < 2:
		return
	var period: int = morph_period(hz)
	var index: int = ((tick - int(enemy.born)) / period) % forms.size()
	enemy.element = forms[index]

static func morph_period(hz: float) -> int:
	return Effects.ticks(DataDB.read("bosses").prismheart.morph_seconds, hz)

static func move(enemy: Dictionary, track: Track, hz: float, skid: float) -> void:
	if enemy.has("corner"):
		enemy.turn_left -= 1
		if int(enemy.turn_left) > 0:
			return
		enemy.erase("corner")
		enemy.erase("turn_left")
	if int(enemy.freeze_time) > 0 or int(enemy.root_time) > 0:
		return
	var from: float = enemy.s
	var pace: float = 1.20 if enemy.get("bannered", false) else 1.0
	var slow: float = maxf(float(enemy.slow), float(enemy.get("paralysis", 0.0)))
	var to: float = from + float(enemy.speed) * (1.0 - slow) * skid * pace / hz
	if enemy.has("turn_seconds"):
		var corner: int = track.corner_crossed(from, to)
		if corner >= 0:
			enemy.s = track.lengths[corner]
			enemy.corner = corner
			enemy.turn_left = Effects.ticks(enemy.turn_seconds, hz)
			return
	enemy.s = to

static func courier_hits(tower_count: int) -> int:
	return maxi(1, tower_count) * int(DataDB.read("waves").bonus_mob.hits_per_tower)

static func wizard_visible_seconds(wave: int) -> float:
	var wizard: Dictionary = DataDB.read("waves").wizard
	return float(wizard.extended_visible_seconds if wave >= int(wizard.extended_from_wave) else wizard.visible_seconds)

static func wizard_visible_ticks(enemy: Dictionary, hz: float) -> int:
	return Effects.ticks(enemy.get("visible_seconds", wizard_visible_seconds(1)), hz)

static func wizard_cycle(enemy: Dictionary, hz: float) -> int:
	return wizard_visible_ticks(enemy, hz) + Effects.ticks(DataDB.read("waves").wizard.void_seconds, hz)

static func in_void(enemy: Dictionary, tick: int, hz: float) -> bool:
	if enemy.kind != "wizard":
		return false
	return (tick - int(enemy.born)) % wizard_cycle(enemy, hz) >= wizard_visible_ticks(enemy, hz)

static func warp(enemy: Dictionary, track: Track, tick: int, hz: float) -> void:
	var age: int = tick - int(enemy.born)
	if age <= 0 or age % wizard_cycle(enemy, hz) != 0:
		return
	var corner: int = track.corner_crossed(float(enemy.s), track.total)
	enemy.s = track.lengths[corner] if corner >= 0 else track.total
	enemy.prev_s = enemy.s

static func hidden(enemy: Dictionary, track: Track, tick: int, hz: float) -> bool:
	return in_void(enemy, tick, hz) or burrowed(enemy, track.total)

static func armor_rank(wave: int) -> int:
	return mini(4, wave / 20)

static func control_resistance(wave: int) -> float:
	var rules: Dictionary = DataDB.read("waves").control_resistance
	return clampf((wave - int(rules.from) + 1) * float(rules.per_wave), 0.0, float(rules.cap))

static func effective_tenacity(enemy: Dictionary) -> float:
	var base: float = enemy.get("control_resistance", 0.0)
	var floor_value: float = minf(base, float(DataDB.read("balance").boss_minimum_tenacity)) if enemy.kind == "boss" else 0.0
	return maxf(floor_value, base - float(enemy.get("tenacity_shred", 0.0)))

static func dispelled(enemy: Dictionary) -> bool:
	return int(enemy.get("dispel_time", 0)) > 0

static func apply_wave_traits(enemy: Dictionary, wave: int, speed_scale: float = 1.0) -> void:
	if enemy.kind == "spirit":
		return
	if enemy.kind not in ["boss", "bonus", "wizard"] and speed_scale != 1.0:
		enemy.speed *= speed_scale
	if not enemy.has("armor_rank"):
		enemy.armor_rank = armor_rank(wave)
	if not enemy.has("control_resistance") and enemy.kind != "boss":
		enemy.control_resistance = control_resistance(wave)
	if enemy.kind == "boss":
		var bosses: Dictionary = DataDB.read("bosses")
		enemy.control_resistance = float(bosses.control_resistance)
		enemy.reflect_wave = int(enemy.get("reflect_wave", wave))
		if enemy.boss_type == "ram" and enemy.has("turn_seconds"):
			var previous: float = enemy.turn_seconds
			var duration: float = bosses.ram.turn_seconds
			if enemy.has("turn_left") and not is_equal_approx(previous, duration):
				var hz: float = DataDB.read("balance").sim_hz
				enemy.turn_left = ceili(float(enemy.turn_left) * Effects.ticks(duration, hz) / maxi(1, Effects.ticks(previous, hz)))
			enemy.speed = float(bosses.ram.speed)
			enemy.turn_seconds = duration
		if enemy.element == "none":
			enemy.element = bosses[enemy.boss_type].element
			enemy.slow_cap = float(DataDB.read("mobs").slow_cap)
		if not enemy.has("heal_aura"):
			enemy.heal_aura = enemy.boss_type == "necromancer" and wave > int(DataDB.read("waves").late_game.after)

static func from_enemy(enemy: Dictionary) -> Dictionary:
	var group: Dictionary = enemy.duplicate()
	group.hp = enemy.max_hp
	return group

static func phased(enemy: Dictionary, tick: int, hz: float) -> bool:
	if not enemy.props.has("phasing") or int(enemy.silence_time) > 0 or dispelled(enemy):
		return false
	var data: Dictionary = DataDB.read("mobs").properties.phasing
	var age: int = tick - int(enemy.born)
	var cycle: int = Effects.ticks(data.cycle, hz)
	return age >= cycle and age % cycle < Effects.ticks(data.duration, hz)

static func burrowed(enemy: Dictionary, road_length: float) -> bool:
	if not property(enemy, "burrower"):
		return false
	var progress: float = float(enemy.s) / road_length
	return (progress >= .24 and progress < .38) or (progress >= .65 and progress < .77)

static func property(enemy: Dictionary, key: String) -> bool:
	return int(enemy.silence_time) == 0 and enemy.props.has(key)
