class_name Replay
extends RefCounted

static func from_data(record: Dictionary) -> Sim:
	return run(int(record.seed), record.actions, int(record.final_tick), String(record.get("map_id", Track.LEGACY)), String(record.get("mode", "legacy")))

static func run(seed_value: int, actions: Array, final_tick: int, layout: String = Track.LEGACY, mode: String = "legacy") -> Sim:
	var sim := Sim.new(seed_value, layout, mode)
	for entry: Dictionary in actions:
		_advance(sim, int(entry.tick))
		if int(sim.state.tick) != int(entry.tick) or not sim.apply(entry.action).ok:
			return null
		sim.events.clear()
	_advance(sim, final_tick)
	return sim

static func _advance(sim: Sim, tick: int) -> void:
	while int(sim.state.tick) < tick and sim.state.phase == "wave":
		sim.step()
		sim.events.clear()
