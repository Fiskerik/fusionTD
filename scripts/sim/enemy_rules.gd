class_name EnemyRules
extends RefCounted

static func create(id: int, group: Dictionary, distance: float, born: int) -> Dictionary:
	return {
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

static func armor_rank(wave: int) -> int:
	return mini(4, wave / 20)

static func control_resistance(wave: int) -> float:
	var rules: Dictionary = DataDB.read("waves").control_resistance
	return clampf((wave - int(rules.from) + 1) * float(rules.per_wave), 0.0, float(rules.cap))

static func apply_wave_traits(enemy: Dictionary, wave: int) -> void:
	if enemy.kind == "spirit":
		return
	if not enemy.has("armor_rank"):
		enemy.armor_rank = armor_rank(wave)
	if not enemy.has("control_resistance") and enemy.kind != "boss":
		enemy.control_resistance = control_resistance(wave)
	if enemy.kind == "boss" and not enemy.has("heal_aura"):
		enemy.heal_aura = enemy.boss_type == "necromancer" and wave > int(DataDB.read("waves").late_game.after)

static func from_enemy(enemy: Dictionary) -> Dictionary:
	var group: Dictionary = enemy.duplicate()
	group.hp = enemy.max_hp
	return group

static func phased(enemy: Dictionary, tick: int, hz: float) -> bool:
	if not enemy.props.has("phasing") or int(enemy.silence_time) > 0:
		return false
	var data: Dictionary = DataDB.read("mobs").properties.phasing
	var age: int = tick - int(enemy.born)
	var cycle: int = Effects.ticks(data.cycle, hz)
	return age >= cycle and age % cycle < Effects.ticks(data.duration, hz)

static func property(enemy: Dictionary, key: String) -> bool:
	return int(enemy.silence_time) == 0 and enemy.props.has(key)
