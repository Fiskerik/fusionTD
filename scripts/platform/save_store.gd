class_name SaveStore
extends RefCounted

const CHECKPOINT: String = "user://survival_save.dat"
const PROFILE: String = "user://profile.json"
const REPLAY: String = "user://last_replay.json"
const VERSION: int = 1
const RECENT_LIMIT: int = 3

static func encode(sim: Sim) -> Dictionary:
	return {"version": VERSION, "state": sim.state, "undo": sim.undo_stack, "history": sim.history,
		"intermission_left": sim.intermission_left, "intermission_paused": sim.intermission_paused}

static func decode(payload: Variant) -> Sim:
	if not payload is Dictionary or int(payload.get("version", 0)) != VERSION:
		return null
	var state: Variant = payload.get("state")
	if not state is Dictionary or state.get("phase") not in ["build", "wave"] or not state.has("seed"):
		return null
	if not state.has("barrier"):
		state = state.duplicate()
		state.barrier = 0
	var sim := Sim.new(int(state.seed))
	for key: String in sim.state:
		if not state.has(key) or typeof(state[key]) != typeof(sim.state[key]):
			return null
	sim.state = state
	for enemy: Dictionary in state.mobs:
		EnemyRules.apply_wave_traits(enemy, int(state.wave))
	for entry: Dictionary in state.spawn_queue:
		EnemyRules.apply_wave_traits(entry.group, int(state.wave))
	sim.intermission_left = clampf(float(payload.get("intermission_left", sim.cfg.intermission_seconds)), 0, float(sim.cfg.intermission_seconds))
	sim.intermission_paused = bool(payload.get("intermission_paused", false))
	for snapshot: Dictionary in payload.get("undo", []):
		var restored: Dictionary = snapshot.duplicate()
		restored.barrier = int(restored.get("barrier", 0))
		sim.undo_stack.append(restored)
	sim.history.assign(payload.get("history", []))
	return sim

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
	_write_json(REPLAY, {"seed": sim.state.seed, "final_tick": sim.state.tick, "actions": sim.history})
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
