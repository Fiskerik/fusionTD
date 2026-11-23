class_name SaveStore
extends RefCounted

const CHECKPOINT: String = "user://survival_save.dat"
const PROFILE: String = "user://profile.json"
const REPLAY: String = "user://last_replay.json"
const VERSION: int = 3
const RECENT_LIMIT: int = 3

static func encode(sim: Sim) -> Dictionary:
	return {"version": VERSION, "state": sim.state, "undo": sim.undo_stack, "history": sim.history,
		"intermission_left": sim.intermission_left}

static func decode(payload: Variant) -> Sim:
	if not payload is Dictionary:
		return null
	var version: int = int(payload.get("version", 0))
	if version < 1 or version > VERSION:
		return null
	var state: Variant = payload.get("state")
	if not state is Dictionary or state.get("phase") not in ["build", "wave"] or not state.has("seed"):
		return null
	if not state.has("barrier"):
		state = state.duplicate()
		state.barrier = 0
	for key: String in ["wave_has_rolled_weaknesses", "wave_uses_expanded_boss_roster"]:
		if not state.has(key):
			state = state.duplicate()
			state[key] = false
	state = state.duplicate()
	state.map_id = String(state.get("map_id", Track.LEGACY))
	state.active_boon = state.get("active_boon", _legacy_boon(state.get("boons", [])))
	state.erase("boons")
	state.boon_queue = state.get("boon_queue", [])
	var sim := Sim.new(int(state.seed), state.map_id, String(state.get("run_mode", "legacy")))
	state.map_id = sim.track.layout_id
	state.merge(sim.tactical_defaults())
	state.run_mode = sim.state.run_mode
	for key: String in ["act_pending", "outcome", "finale_defeated"]:
		if not state.has(key):
			state[key] = sim.state[key]
	for key: String in sim.state:
		if not state.has(key) or typeof(state[key]) != typeof(sim.state[key]):
			return null
	state.tiers = state.tiers.duplicate()
	state.tiers.merge(sim.state.tiers)
	state.boon_queue = _boss_rewards(state.boon_queue, int(state.stats.get("bosses_defeated", 0)))
	sim.state = state
	sim.refresh_boon()
	_ascend_legacy_towers(state.towers)
	var needs_pre_boss_trial: bool = version == 1 and sim.has_pre_boss_trial(int(state.wave))
	var replaces_old_merchant: bool = version < 3 and int(state.wave) == 35 and sim.event_kind(35) == "spirit"
	var restore_trial: bool = (needs_pre_boss_trial or replaces_old_merchant) and state.phase == "build" \
		and state.trial.is_empty() and not sim.choices().is_empty()
	if version == 1:
		_upgrade_encounters(state, int(sim.cfg.boss_every))
	if restore_trial:
		state.selection_pending = true
	var bosses_by_type: Dictionary = {}
	if state.phase == "wave":
		var late_game: bool = int(state.wave) > int(DataDB.read("waves").late_game.after)
		for boss: Dictionary in sim.preview(state.wave).bosses:
			if late_game or boss.boss_type in ["prismheart", "tempest"]:
				bosses_by_type[boss.boss_type] = boss
	for enemy: Dictionary in state.mobs:
		EnemyRules.apply_wave_traits(enemy, int(state.wave))
		_retune_enemy(enemy, int(state.wave), bosses_by_type)
		if version < 3:
			_upgrade_active_special(enemy, state, sim.hz)
	for entry: Dictionary in state.spawn_queue:
		EnemyRules.apply_wave_traits(entry.group, int(state.wave))
		_retune_enemy(entry.group, int(state.wave), bosses_by_type)
	var countdown: float = sim.breather()
	sim.intermission_left = clampf(float(payload.get("intermission_left", countdown)), 0, countdown)
	for snapshot: Dictionary in payload.get("undo", []):
		var restored: Dictionary = snapshot.duplicate()
		restored.map_id = state.map_id
		restored.merge(sim.tactical_defaults())
		restored.run_mode = state.run_mode
		for key: String in ["act_pending", "outcome", "finale_defeated"]:
			if not restored.has(key):
				restored[key] = sim.state[key]
		restored.tiers = restored.get("tiers", {}).duplicate()
		for element: String in DataDB.ELEMENTS:
			if not restored.tiers.has(element):
				restored.tiers[element] = 0
		restored.active_boon = restored.get("active_boon", _legacy_boon(restored.get("boons", [])))
		restored.erase("boons")
		restored.boon_queue = _boss_rewards(restored.get("boon_queue", []), int(restored.get("stats", {}).get("bosses_defeated", 0)))
		restored.barrier = int(restored.get("barrier", 0))
		restored.wave_has_rolled_weaknesses = bool(restored.get("wave_has_rolled_weaknesses", false))
		restored.wave_uses_expanded_boss_roster = bool(restored.get("wave_uses_expanded_boss_roster", false))
		_ascend_legacy_towers(restored.get("towers", {}))
		if version == 1:
			_upgrade_encounters(restored, int(sim.cfg.boss_every))
		if restore_trial and restored.wave == state.wave and restored.phase == "build" and restored.trial.is_empty():
			restored.selection_pending = true
		sim.undo_stack.append(restored)
	sim.history.assign(payload.get("history", []))
	return sim

static func _upgrade_active_special(enemy: Dictionary, state: Dictionary, hz: float) -> void:
	if enemy.kind == "bonus":
		var remaining: float = float(enemy.hp) / maxf(1.0, float(enemy.max_hp))
		enemy.max_hp = float(EnemyRules.courier_hits(state.towers.size()))
		enemy.hp = clampf(ceilf(remaining * float(enemy.max_hp)), 1.0, float(enemy.max_hp))
		enemy.armor = 0.0
		enemy.speed = float(DataDB.read("waves").bonus_mob.speed)
		enemy.dots = {}
		enemy.erase("disease")
	elif enemy.kind == "wizard":
		var elapsed: int = int(state.tick) - int(enemy.born)
		var previous_stand: int = EnemyRules.wizard_visible_ticks(enemy, hz)
		var phase: int = elapsed % EnemyRules.wizard_cycle(enemy, hz)
		enemy.visible_seconds = EnemyRules.wizard_visible_seconds(int(state.wave))
		if phase >= previous_stand:
			phase += EnemyRules.wizard_visible_ticks(enemy, hz) - previous_stand
		enemy.born = int(state.tick) - phase

static func _upgrade_encounters(state: Dictionary, first_boss: int) -> void:
	var wave: int = state.wave
	if wave == first_boss - 1 or wave == first_boss:
		for tower: Dictionary in state.towers.values():
			tower.erase("stone_pending")
			if wave == first_boss:
				tower.erase("petrified")
				tower.stun = 0
	if wave >= int(DataDB.read("waves").wizard.first_wave):
		return
	var enemies: Array = state.mobs.duplicate()
	for entry: Dictionary in state.spawn_queue:
		enemies.append(entry.group)
	for enemy: Dictionary in enemies:
		if enemy.kind == "wizard" or (wave == first_boss - 1 and enemy.kind == "petrifier"):
			enemy.kind = "grunt"
			enemy.props = []

static func _retune_enemy(enemy: Dictionary, wave: int, bosses: Dictionary) -> void:
	var tuned: Dictionary = bosses.get(enemy.get("boss_type", ""), {})
	if enemy.kind == "spirit":
		tuned = Waves.spirit_group(enemy.element, int(enemy.tier), wave)
	if tuned.is_empty():
		return
	if enemy.has("max_hp"):
		if not is_equal_approx(float(enemy.max_hp), float(tuned.hp)):
			var fraction: float = float(enemy.hp) / maxf(1.0, float(enemy.max_hp))
			enemy.max_hp = float(tuned.hp)
			enemy.hp = float(tuned.hp) * fraction
	else:
		enemy.hp = tuned.hp
	enemy.armor = tuned.armor
	if enemy.get("boss_type", "") in ["prismheart", "tempest"]:
		enemy.speed = tuned.speed

static func _legacy_boon(picks: Variant) -> Dictionary:
	if not picks is Array or picks.is_empty():
		return {}
	var pick: Dictionary = picks.back()
	var wave: int = int(pick.wave)
	return {"id": pick.id, "wave": wave, "potency": 1.0 + .20 * clampi((wave - 1) / 20, 0, 4)}

static func _boss_rewards(queue: Array, boss_kills: int) -> Array:
	var rewards: Array = queue.filter(func(reward: Variant) -> bool: return reward is Dictionary and reward.get("source") == "boss")
	var first_kill: int = boss_kills - rewards.size() + 1
	for index: int in range(rewards.size()):
		if not rewards[index].has("potency"):
			var reward: Dictionary = rewards[index].duplicate()
			reward.potency = RunBoons.reward_potency(first_kill + index)
			rewards[index] = reward
	return rewards

static func _ascend_legacy_towers(towers: Dictionary) -> void:
	for tower: Dictionary in towers.values():
		if tower.kind == "pure" and int(tower.get("crystals", 0)) > 0 and TowerRules.can_socket_crystal(tower):
			TowerRules.empower_pure(tower)
			tower.crystals -= 1

static func checkpoint(sim: Sim, path: String = CHECKPOINT) -> Error:
	if sim.state.phase not in ["build", "wave"]:
		return ERR_INVALID_DATA
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(encode(sim))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return _publish(path) if error == OK else error

static func resume(path: String = CHECKPOINT) -> Sim:
	for candidate: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file != null:
			var sim: Sim = decode(file.get_var(false))
			if sim != null:
				return sim
	return null

static func clear(path: String = CHECKPOINT) -> void:
	for candidate: String in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)

static func profile() -> Dictionary:
	var defaults: Dictionary = {"best_wave": 0, "runs": 0, "total_kills": 0, "recent_runs": [], "seen": [], "haptics": true, "sound": true, "music": true, "speed": 1, "gate_on_top": false}
	for path: String in [PROFILE, PROFILE + ".bak"]:
		if FileAccess.file_exists(path):
			var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if value is Dictionary:
				defaults.merge(value, true)
				break
	return defaults

static func write_profile(values: Dictionary) -> void:
	_write_json(PROFILE, values)

static func finish(sim: Sim, values: Dictionary) -> void:
	record_run(sim, values)
	values.best_wave = maxi(int(values.best_wave), int(sim.state.wave) - 1)
	values.runs = int(values.runs) + 1
	values.total_kills = int(values.total_kills) + int(sim.state.stats.kills)
	write_profile(values)
	_write_json(REPLAY, {"seed": sim.state.seed, "map_id": sim.track.layout_id, "mode": sim.state.run_mode,
		"final_tick": sim.state.tick, "actions": sim.history})
	clear()

static func record_run(sim: Sim, values: Dictionary) -> void:
	var damage: float = float(sim.state.stats.get("sold_damage", 0.0))
	for tower: Dictionary in sim.state.towers.values():
		damage += float(tower.get("damage_dealt", 0.0))
	var ranking: Array = sim.top_damage()
	var top: Dictionary = {}
	if not ranking.is_empty():
		var tower: Dictionary = ranking[0]
		top = {"name": TowerRules.display_name(tower), "damage": tower.get("damage_dealt", 0.0), "kills": tower.get("kills", 0)}
	var runs: Array = values.get("recent_runs", [])
	runs.push_front({
		"date": Time.get_datetime_string_from_system(false, true).left(16),
		"mode": sim.state.run_mode, "outcome": sim.state.outcome,
		"reached": int(sim.state.wave), "cleared": int(sim.state.wave) - 1,
		"kills": int(sim.state.stats.kills), "bosses": int(sim.state.stats.get("bosses_defeated", 0)),
		"trials": int(sim.state.stats.spirits), "spirits_defeated": int(sim.state.stats.get("spirits_defeated", 0)),
		"fusions": int(sim.state.stats.fusions), "leaks": int(sim.state.stats.leaked),
		"pures": int(sim.state.stats.get("pure_built", 0)),
		"gold": int(sim.state.gold), "seconds": floori(float(sim.state.tick) / sim.hz),
		"damage": damage, "tiers": sim.state.tiers.duplicate(), "top": top,
	})
	values.recent_runs = runs.slice(0, RECENT_LIMIT)

static func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value))
		file.flush()
		var error: Error = file.get_error()
		file.close()
		if error == OK:
			_publish(path)

static func _publish(path: String) -> Error:
	var backup: String = path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		var moved: Error = DirAccess.rename_absolute(path, backup)
		if moved != OK:
			return moved
	return DirAccess.rename_absolute(path + ".tmp", path)
