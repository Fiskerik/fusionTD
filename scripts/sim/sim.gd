class_name Sim
extends RefCounted

var state: Dictionary
var track := Track.new()
var cfg: Dictionary = DataDB.read("balance")
var hz: float = float(cfg.sim_hz)
var intermission_left: float = float(cfg.intermission_seconds)
var events: Array[Dictionary] = []
var history: Array[Dictionary] = []
var undo_stack: Array[Dictionary] = []

func _init(seed_value: int = 1) -> void:
	var tiers: Dictionary = {}
	for element: String in DataDB.ELEMENTS:
		tiers[element] = 0
	state = {
		"seed": seed_value, "tick": 0, "wave_tick": 0, "phase": "build", "wave": 1,
		"wave_has_rolled_weaknesses": true,
		"wave_uses_expanded_boss_roster": true,
		"lives": int(cfg.start_lives), "barrier": 0, "gold": int(cfg.start_gold), "next_id": 1,
		"towers": {}, "mobs": [], "spawn_queue": [], "tiers": tiers, "trial": {},
		"selection_pending": false, "rally_cd": 0, "stats": {"kills": 0, "spirits": 0, "fusions": 0, "leaked": 0},
	}

func step() -> void:
	if state.phase != "wave":
		return
	state.tick += 1
	state.wave_tick += 1
	state.rally_cd = maxi(0, int(state.rally_cd) - 1)
	while not state.spawn_queue.is_empty() and int(state.spawn_queue[0].tick) <= int(state.wave_tick):
		var next: Dictionary = state.spawn_queue.pop_front()
		Combat.spawn(self, next.group, next.s)
	Combat.advance(self)
	if state.phase == "wave" and state.spawn_queue.is_empty() and state.mobs.is_empty():
		_finish_wave()

func preview(wave: int, include_trial: bool = true) -> Dictionary:
	var current: bool = wave == int(state.wave)
	var trial: Dictionary = state.trial if include_trial and current else {}
	var current_active: bool = current and state.phase == "wave"
	var wave_data: Dictionary = Waves.generate(state.seed, wave, trial,
		not current_active or state.wave_has_rolled_weaknesses,
		not current_active or state.wave_uses_expanded_boss_roster)
	for boss: Dictionary in wave_data.bosses:
		if boss.boss_type == "prismheart":
			var forms := PackedStringArray()
			for element: String in DataDB.ELEMENTS:
				if int(state.tiers[element]) > 0:
					forms.append(element)
			boss.forms = forms
			if not forms.is_empty():
				boss.element = forms[0]
	return wave_data

func choices() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for element: String in DataDB.ELEMENTS:
		var tier: int = int(state.tiers[element]) + 1
		if tier <= 3:
			options.append({"element": element, "tier": tier})
	return options

func pure_count() -> int:
	var count: int = 0
	for tower: Dictionary in state.towers.values():
		if tower.kind == "ascended":
			count += 1
	return count

func pure_crystals() -> int:
	var earned: int = int(state.wave) / int(cfg.pure_crystal_every)
	return maxi(0, earned - int(state.stats.get("pure_crystals_spent", 0)))

func spirit_victories() -> Dictionary:
	return state.stats.get("spirit_victories", {})

func ice_tiles() -> Dictionary:
	var coverage: Dictionary = {}
	for slot: String in state.towers:
		var tower: Dictionary = state.towers[slot]
		if tower.kind != "triple" or int(tower.stun) > 0:
			continue
		var rule: Dictionary = TowerRules.stats(tower)
		if not rule.effect.has("ice"):
			continue
		var potency: float = TowerRules.attack_profile(tower).potency
		var slide: int = Effects.ticks(rule.effect.ice.slide, hz)
		var stumble: int = Effects.ticks(Effects.slow_duration(rule.effect.ice.stumble, potency), hz)
		for tile: Vector2i in track.reachable_road(slot, rule.range):
			if not coverage.has(tile) or int(coverage[tile].stumble) < stumble:
				coverage[tile] = {"slide": slide, "stumble": stumble}
	return coverage

func describe(action: Dictionary, ignore_affordability: bool = false) -> Dictionary:
	var type: String = action.get("type", "")
	var slot: String = action.get("slot", action.get("slot_a", ""))
	var tower: Dictionary = state.towers.get(slot, {})
	var cost: int = 0
	var reason: String = ""
	if state.phase == "game_over":
		return {"ok": false, "reason": DataDB.text("ended"), "cost": 0}
	if state.phase == "wave" and type not in ["build", "build_pure", "upgrade", "empower_pure", "sell", "move", "infuse", "remove_infusion", "fuse", "set_target", "rally"]:
		return {"ok": false, "reason": DataDB.text("between_waves"), "cost": 0}
	match type:
		"build", "build_pure":
			var kind: String = action.get("kind", "")
			var pure_tower: bool = type == "build_pure"
			if not DataDB.ELEMENTS.has(kind) and (pure_tower or kind not in ["arrow", "cannon"]):
				reason = DataDB.text("unknown_tower")
			elif not track.slots.has(slot):
				reason = DataDB.text("invalid_site")
			elif not tower.is_empty():
				reason = DataDB.text("site_occupied")
			elif pure_tower and int(state.tiers[kind]) < 3:
				reason = DataDB.text("requires_tier") % [kind.capitalize(), "III"]
			elif pure_tower and pure_count() >= int(cfg.pure_tower_limit):
				reason = "All %d Pure tower slots are in use." % int(cfg.pure_tower_limit)
			elif DataDB.ELEMENTS.has(kind) and int(state.tiers[kind]) == 0:
				reason = DataDB.text("requires_spirit") % kind.capitalize()
			else:
				cost = int(cfg.pure_tower_cost) if pure_tower else int(DataDB.read("towers")[kind].cost)
		"upgrade":
			if tower.is_empty():
				reason = DataDB.text("select_tower")
			else:
				reason = TowerRules.level_requirement(tower, state.tiers)
				cost = TowerRules.upgrade_cost(tower)
		"empower_pure":
			if not TowerRules.can_socket_crystal(tower):
				reason = "Choose a level-6 elemental tower or a Pure tower."
			elif int(state.tiers[tower.element]) < 3:
				reason = DataDB.text("requires_tier") % [String(tower.element).capitalize(), "III"]
			elif pure_crystals() == 0:
				reason = "Earn a Pure Crystal on reaching each %d-wave milestone." % int(cfg.pure_crystal_every)
		"move":
			var destination: String = action.get("to", "")
			if tower.is_empty():
				reason = DataDB.text("select_tower")
			elif destination == slot or not track.slots.has(destination):
				reason = "Choose an open build tile for this tower."
			elif state.towers.has(destination):
				reason = DataDB.text("site_occupied")
			else:
				cost = Economy.move_fee(int(tower.invested))
		"infuse", "remove_infusion":
			var element: String = action.get("element", "")
			if tower.get("kind") not in ["arrow", "cannon"]:
				reason = DataDB.text("select_normal")
			elif type == "remove_infusion":
				if tower.infusion == "":
					reason = DataDB.text("no_infusion")
			elif int(tower.level) < int(cfg.infusion.min_levels[0]):
				reason = DataDB.text("requires_level") % int(cfg.infusion.min_levels[0])
			elif not state.tiers.has(element) or int(state.tiers[element]) == 0:
				reason = DataDB.text("requires_element")
			elif tower.infusion == element:
				reason = DataDB.text("already_infused")
			else:
				cost = TowerRules.infusion_cost(TowerRules.infusion_tier(tower.level, state.tiers[element]))
		"fuse":
			var second: Dictionary = state.towers.get(action.get("slot_b", ""), {})
			var a: PackedStringArray = TowerRules.ingredients(tower)
			var b: PackedStringArray = TowerRules.ingredients(second)
			if a.size() + b.size() > 3 and TowerRules.is_fusion(tower) and TowerRules.is_fusion(second):
				reason = DataDB.text("fusion_at_most_three")
			elif not TowerRules.can_fuse(tower) or not TowerRules.can_fuse(second):
				reason = DataDB.text("select_elemental_towers")
			elif TowerRules.fusion_recipe(tower, second).is_empty():
				reason = DataDB.text("select_different")
			elif (tower.kind == "pure" and int(tower.level) < int(cfg.fuse_min_level)) or (second.kind == "pure" and int(second.level) < int(cfg.fuse_min_level)):
				reason = DataDB.text("requires_fuse_level") % int(cfg.fuse_min_level)
			cost = TowerRules.fusion_cost(tower, second)
		"sell", "set_target":
			if tower.is_empty():
				reason = DataDB.text("select_tower")
			elif type == "set_target" and action.get("mode") not in ["first", "strongest"]:
				reason = DataDB.text("unknown_target")
		"rally":
			if state.phase != "wave" or int(tower.get("stun", 0)) == 0:
				reason = DataDB.text("select_stunned")
			elif int(state.rally_cd) > 0:
				reason = DataDB.text("rally_cooldown")
		"start_wave":
			if state.selection_pending:
				reason = DataDB.text("choose_spirit")
		"select_element":
			var choice: Dictionary = {"element": action.get("element", ""), "tier": int(action.get("tier", 0))}
			if not state.selection_pending or not choices().has(choice):
				reason = DataDB.text("unavailable_trial")
		"undo":
			if undo_stack.is_empty():
				reason = DataDB.text("empty_undo")
		_:
			reason = DataDB.text("unknown_action")
	if reason.is_empty() and not ignore_affordability and cost > int(state.gold):
		reason = DataDB.text("requires_gold") % cost
	return {"ok": reason.is_empty(), "reason": reason, "cost": cost}

func apply(action: Dictionary) -> Dictionary:
	var result: Dictionary = describe(action)
	if not result.ok:
		return result
	var type: String = action.type
	var slot: String = action.get("slot", action.get("slot_a", ""))
	var tower: Dictionary = state.towers.get(slot, {})
	history.append({"tick": int(state.tick), "action": action.duplicate(true)})
	if state.phase == "build" and type not in ["undo", "start_wave", "set_target"]:
		undo_stack.append(state.duplicate(true))
		if undo_stack.size() > int(cfg.undo_limit):
			undo_stack.pop_front()
	state.gold -= int(result.cost)
	match type:
		"build":
			var kind: String = action.kind
			var pure: bool = DataDB.ELEMENTS.has(kind)
			state.towers[slot] = TowerRules.create(next_id(), slot, "pure" if pure else kind, kind if pure else "normal", "", result.cost)
		"build_pure":
			state.towers[slot] = TowerRules.create(next_id(), slot, "ascended", action.kind, "", result.cost)
			state.stats.pure_built = int(state.stats.get("pure_built", 0)) + 1
		"upgrade":
			tower.level += 1
			tower.invested += int(result.cost)
		"empower_pure":
			tower.crystals = int(tower.get("crystals", 0)) + 1
			state.stats.pure_crystals_spent = int(state.stats.get("pure_crystals_spent", 0)) + 1
		"infuse":
			tower.infusion = action.element
			tower.invested += int(result.cost)
		"remove_infusion":
			tower.infusion = ""
		"sell":
			state.gold += Economy.refund(tower.invested)
			state.stats.sold_damage = float(state.stats.get("sold_damage", 0.0)) + float(tower.get("damage_dealt", 0.0))
			state.towers.erase(slot)
		"move":
			var destination: String = action.to
			state.towers.erase(slot)
			tower.slot = destination
			tower.beam_target = -1
			tower.beam_start = int(state.tick)
			state.towers[destination] = tower
			for enemy: Dictionary in state.mobs:
				var telegraph: Dictionary = enemy.telegraph
				if telegraph.get("slot", "") == slot:
					telegraph.slot = destination
			emit_event("tower_moved", {"from": slot, "slot": destination})
		"fuse":
			var second: Dictionary = state.towers[action.slot_b]
			var dual: String = TowerRules.fusion_recipe(tower, second)
			var merged: Dictionary = TowerRules.combine(dual, tower, second, state.tiers, spirit_victories(), next_id())
			Effects.inherit_sources(state.mobs, tower.id, second.id, merged.id)
			state.towers[slot] = merged
			state.towers.erase(action.slot_b)
			state.stats.fusions += 1
			emit_event("fused", {"slot": slot, "from": second.slot, "dual": dual, "elements": TowerRules.ingredients(merged)})
		"set_target":
			tower.target = action.mode
		"rally":
			tower.stun = 0
			state.rally_cd = int(cfg.rally_cooldown_ticks)
			emit_event("tower_rallied", {"slot": slot})
		"select_element":
			state.trial = {"element": action.element, "tier": int(action.tier)}
			state.selection_pending = false
		"start_wave":
			_start_wave()
		"undo":
			state = undo_stack.pop_back()
			emit_event("undone")
	return result

func next_id() -> int:
	var id: int = state.next_id
	state.next_id += 1
	return id

func emit_event(kind: String, data: Dictionary = {}) -> void:
	events.append({"type": kind, "data": data})

func ordered_towers() -> Array:
	var towers: Array = state.towers.values()
	towers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.id) < int(b.id))
	return towers

func top_damage() -> Array:
	var towers: Array = state.towers.values()
	towers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var first: float = a.get("damage_dealt", 0.0)
		var second: float = b.get("damage_dealt", 0.0)
		return int(a.id) < int(b.id) if first == second else first > second)
	return towers.slice(0, 5)

func schedule(group: Dictionary, tick: int, distance: float = 0.0) -> void:
	var item: Dictionary = {"group": group, "tick": tick, "s": distance}
	var queue: Array = state.spawn_queue
	var index: int = queue.size()
	while index > 0 and int(queue[index - 1].tick) > tick:
		index -= 1
	queue.insert(index, item)

func lose_lives(enemy: Dictionary) -> void:
	var previous: int = int(state.lives)
	var absorbed: int = mini(int(state.barrier), int(enemy.leak))
	state.barrier -= absorbed
	state.lives = maxi(0, previous - (int(enemy.leak) - absorbed))
	state.stats.leaked += 1
	emit_event("mob_leaked", {"kind": enemy.kind, "lives": state.lives, "absorbed": absorbed, "hp": enemy.hp, "max_hp": enemy.max_hp})
	if enemy.kind == "spirit":
		resolve_spirit(enemy, previous - int(state.lives), absorbed)
	if int(state.lives) == 0:
		state.trial = {}
		state.phase = "game_over"
		emit_event("game_over")

func resolve_spirit(enemy: Dictionary, lost: int = 0, absorbed: int = 0) -> void:
	state.gold += int(enemy.gold)
	state.stats.spirits += 1
	state.tiers[enemy.element] = maxi(int(state.tiers[enemy.element]), int(enemy.tier))
	var defeated: bool = lost == 0 and absorbed == 0
	if defeated:
		state.stats.spirits_defeated = int(state.stats.get("spirits_defeated", 0)) + 1
		if int(enemy.tier) >= 2:
			var victories: Dictionary = spirit_victories()
			victories[enemy.element] = int(victories.get(enemy.element, 0)) | (1 << (int(enemy.tier) - 2))
			state.stats.spirit_victories = victories
	emit_event("element_unlocked", {"element": enemy.element, "tier": enemy.tier,
		"lost": lost, "absorbed": absorbed, "defeated": defeated, "gold": enemy.gold, "s": enemy.s})

func state_hash() -> int:
	return var_to_str(state).hash()

func _start_wave() -> void:
	undo_stack.clear()
	state.wave_has_rolled_weaknesses = true
	state.wave_uses_expanded_boss_roster = true
	state.phase = "wave"
	state.wave_tick = 0
	state.rally_cd = 0
	for tower: Dictionary in state.towers.values():
		tower.cooldown = 0
		tower.stun = 0
		tower.hits = 0
		tower.beam_target = -1
	var wave: Dictionary = preview(state.wave)
	var spawn_tick: int = int(DataDB.read("waves").first_tick)
	for group: Dictionary in wave.groups:
		for index: int in range(int(group.count)):
			schedule(group, spawn_tick)
			spawn_tick += int(group.interval)
	if not wave.spirit.is_empty():
		schedule(wave.spirit, wave.spirit.spawn)
	for boss: Dictionary in wave.bosses:
		schedule(boss, boss.spawn)
	emit_event("wave_started", {"bonus": not wave.spirit.is_empty()})

func _finish_wave() -> void:
	intermission_left = float(cfg.intermission_seconds)
	if not state.trial.is_empty():
		state.trial = {}
		state.phase = "build"
		emit_event("bonus_finished")
		return
	var cleared: int = state.wave
	state.gold += Economy.clear_reward(cleared, state.gold)
	state.wave += 1
	state.phase = "build"
	if cleared % int(cfg.gate_repair_every) == 0:
		_restore_gate()
	if int(state.wave) % int(cfg.selection_every) == 0:
		state.selection_pending = not choices().is_empty()
	emit_event("wave_cleared", {"wave": cleared, "pure_crystal": int(state.wave) % int(cfg.pure_crystal_every) == 0})

func gate_repair_per_cycle() -> int:
	var repair: int = 0
	for tower: Dictionary in state.towers.values():
		if TowerRules.is_fusion(tower):
			repair = maxi(repair, int(TowerRules.stats(tower).effect.get("wall_heal", 0)))
	return repair

func next_gate_repair() -> int:
	var every: int = int(cfg.gate_repair_every)
	return ceili(float(state.wave) / every) * every

func _restore_gate() -> void:
	var old_lives: int = state.lives
	var old_barrier: int = state.barrier
	var charge: int = gate_repair_per_cycle()
	var restored: int = mini(int(cfg.start_lives) - old_lives, charge)
	state.lives += restored
	state.barrier = mini(int(cfg.gate_barrier_cap), old_barrier + charge - restored)
	if state.lives > old_lives or state.barrier > old_barrier:
		emit_event("gate_restored", {"lives": state.lives - old_lives, "barrier": state.barrier - old_barrier})
