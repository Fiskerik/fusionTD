class_name Replay
extends RefCounted

static func run(seed_value: int, actions: Array, final_tick: int) -> Sim:
	var sim := Sim.new(seed_value)
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
