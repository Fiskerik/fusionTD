class_name Sim
extends RefCounted

var state: Dictionary
var track: Track
var _boon_modifiers: Dictionary = {}
var cfg: Dictionary = DataDB.read("balance")
var hz: float = float(cfg.sim_hz)
var intermission_left: float = float(cfg.opening_seconds)
var events: Array[Dictionary] = []
var history: Array[Dictionary] = []
var undo_stack: Array[Dictionary] = []

static func campaign(seed_value: int) -> Sim:
	return Sim.new(seed_value, Track.campaign_layout(seed_value))

func _init(seed_value: int = 1, layout: String = Track.LEGACY) -> void:
	track = Track.new(layout)
	var tiers: Dictionary = {}
	for element: String in DataDB.ELEMENTS:
		tiers[element] = 0
	state = {
		"seed": seed_value, "map_id": track.layout_id, "active_boon": {}, "boon_queue": [], "tick": 0, "wave_tick": 0, "phase": "build", "wave": 1,
		"wave_has_rolled_weaknesses": true,
		"wave_uses_expanded_boss_roster": true,
		"lives": int(cfg.start_lives), "barrier": 0, "gold": int(cfg.start_gold), "next_id": 1,
		"towers": {}, "mobs": [], "spawn_queue": [], "tiers": tiers, "trial": {},
		"selection_pending": false, "rally_cd": 0, "stats": {"kills": 0, "spirits": 0, "fusions": 0, "leaked": 0},
	}
	state.merge(tactical_defaults())

func tactical_defaults() -> Dictionary:
	return {"stone_blocks": int(cfg.stone_blocks), "stone": {}, "stone_last_wave": 0,
		"stone_ready_tick": 0, "swap_tokens": int(cfg.swap_tokens), "wave_swaps": {}}

func effective_tower(tower: Dictionary) -> Dictionary:
	var element: String = state.wave_swaps.get(tower.kind, "")
	if element.is_empty() or element == tower.infusion:
		return tower
	var current: Dictionary = tower.duplicate()
	current.infusion = element
	return current

func stone_cooldown() -> int:
	return ceili(maxf(0.0, float(int(state.stone_ready_tick) - int(state.tick))) / hz)

func step() -> void:
	if state.phase != "wave":
		return
	state.tick += 1
	state.wave_tick += 1
	state.rally_cd = maxi(0, int(state.rally_cd) - 1)
	if not state.stone.is_empty() and int(state.tick) >= int(state.stone.until):
		emit_event("stone_expired", {"tile": state.stone.tile})
		state.stone = {}
	while not state.spawn_queue.is_empty() and int(state.spawn_queue[0].tick) <= int(state.wave_tick) and state.mobs.size() < Waves.unit_cap():
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
		not current_active or state.wave_uses_expanded_boss_roster, track if track.layout_id != Track.LEGACY else null)
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

func boon_choices() -> PackedStringArray:
	if state.boon_queue.is_empty():
		return PackedStringArray()
	return RunBoons.offers(int(state.seed), state.boon_queue[0], state.active_boon)

func refresh_boon() -> void:
	_boon_modifiers = RunBoons.modifiers(state.active_boon)

func tower_boon(tower: Dictionary) -> Dictionary:
	return RunBoons.for_tower(tower, _boon_modifiers)

func tower_profile(tower: Dictionary) -> Dictionary:
	var effective: Dictionary = effective_tower(tower)
	return TowerRules.attack_profile(effective, spirit_victories(), tower_boon(effective))

func wave_matchups(summary: Dictionary) -> Dictionary:
	var groups: Array = summary.groups + summary.bosses
	if not summary.spirit.is_empty():
		groups.append(summary.spirit)
	var good: Array[Dictionary] = []
	var weak: Array[Dictionary] = []
	for original: Dictionary in ordered_towers():
		if TowerRules.disabled(original) or float(TowerRules.stats(original).rate) <= 0.0:
			continue
		var tower: Dictionary = effective_tower(original) if int(summary.wave) == int(state.wave) else original
		var boon: Dictionary = tower_boon(tower)
		var profile: Dictionary = TowerRules.attack_profile(tower, spirit_victories(), boon)
		var effects: Dictionary = TowerRules.trait_profile(tower, state.tiers, boon)
		var split: Dictionary = TowerRules.damage_split(tower)
		var pierce: float = minf(.9, float(effects.get("pierce", 0.0)) * float(profile.potency))
		var raw: float = profile.damage
		var actual: float = 0.0
		var neutral: float = 0.0
		for group: Dictionary in groups:
			var count: int = int(group.count)
			var armor: float = group.armor
			var factor: float = Damage.against(split, group, effects.has("adaptive"))
			var forms: PackedStringArray = group.get("forms", PackedStringArray())
			if forms.size() > 1:
				factor = 0.0
				for form: String in forms:
					var variant: Dictionary = group.duplicate()
					variant.element = form
					factor += Damage.against(split, variant, effects.has("adaptive")) / forms.size()
			actual += count * Damage.hit(raw * factor, armor, pierce, 0.0, 0.0)
			neutral += count * Damage.hit(raw, armor, pierce, 0.0, 0.0)
		if neutral <= 0.0:
			continue
		var score: float = actual / neutral
		var entry: Dictionary = {"slot": tower.slot, "name": TowerRules.display_name(tower), "score": score}
		if score >= 1.05:
			good.append(entry)
		elif score <= .95:
			weak.append(entry)
	weak.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.slot < b.slot if is_equal_approx(float(a.score), float(b.score)) else float(a.score) < float(b.score))
	return {"good": good, "weak": weak.slice(0, 2)}

func support_bonuses(tower: Dictionary, sources: Array[Dictionary], slot: String = "") -> Vector3:
	return TowerRules.support_bonuses(tower, sources, track, slot, _boon_modifiers)

func fusion_fee(first: Dictionary, second: Dictionary) -> int:
	var discount: float = RunBoons.limited("fusion_discount", float(_boon_modifiers.get("fusion", {}).get("fusion_discount", 0)))
	var base_fee: int = ceili(float(TowerRules.fusion_cost(first, second)) * (1.0 - discount) - .000001)
	if TowerRules.fusion_recipe(first, second).is_empty():
		return base_fee
	return TowerRules.fusion_fee(first, second, state.tiers, base_fee)

func record_boss_kill() -> void:
	var boss_kills: int = int(state.stats.get("bosses_defeated", 0)) + 1
	state.stats.bosses_defeated = boss_kills
	state.boon_queue.append({"source": "boss", "wave": int(state.wave), "index": state.boon_queue.size(),
		"potency": RunBoons.reward_potency(boss_kills)})

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
		if tower.kind != "triple" or int(tower.stun) > 0 or TowerRules.disabled(tower):
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
	if state.phase == "wave" and type not in ["build", "build_pure", "upgrade", "empower_pure", "sell", "move", "infuse", "remove_infusion", "fuse", "set_target", "rally", "place_stone", "swap_element"]:
		return {"ok": false, "reason": DataDB.text("between_waves"), "cost": 0}
	match type:
		"place_stone":
			if state.phase != "wave":
				reason = "Place a stone during combat."
			elif not track.road_tiles.has(action.get("tile")):
				reason = "Choose a road tile."
			elif int(state.stone_blocks) == 0:
				reason = "No stone blocks left."
			elif int(state.stone_last_wave) == int(state.wave):
				reason = "One stone block per wave."
			elif stone_cooldown() > 0:
				reason = "Stone block ready in %ds." % stone_cooldown()
		"swap_element":
			var kind: String = action.get("kind", "")
			var element: String = action.get("element", "")
			if kind not in ["arrow", "cannon"] or int(state.tiers.get(element, 0)) <= 0:
				reason = "Choose an unlocked element."
			elif int(state.swap_tokens) == 0:
				reason = "No swap tokens left."
			elif state.wave_swaps.get(kind, "") == element:
				reason = "That element is already active."
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
			elif pure_tower and pure_crystals() == 0:
				reason = "Building a Pure tower also requires one Pure Crystal."
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
			if tower.get("kind", "") == "ascended":
				reason = DataDB.text("max_level")
			elif not TowerRules.can_socket_crystal(tower):
				reason = "Choose a level-6 elemental tower."
			elif int(state.tiers[tower.element]) < 3:
				reason = DataDB.text("requires_tier") % [String(tower.element).capitalize(), "III"]
			elif pure_count() >= int(cfg.pure_tower_limit):
				reason = "All %d Pure tower slots are in use." % int(cfg.pure_tower_limit)
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
			if tower.get("kind") == "ascended" or second.get("kind") == "ascended":
				reason = "Pure towers cannot be fused."
			elif TowerRules.is_fusion(tower) and TowerRules.is_fusion(second):
				reason = DataDB.text("fusion_at_most_three")
			elif not TowerRules.can_fuse(tower) or not TowerRules.can_fuse(second):
				reason = DataDB.text("select_elemental_towers")
			elif TowerRules.fusion_recipe(tower, second).is_empty():
				reason = DataDB.text("select_different")
			elif (tower.kind == "pure" and int(tower.level) < int(cfg.fuse_min_level)) or (second.kind == "pure" and int(second.level) < int(cfg.fuse_min_level)):
				reason = DataDB.text("requires_fuse_level") % int(cfg.fuse_min_level)
			if reason.is_empty():
				cost = fusion_fee(tower, second)
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
		"choose_boon":
			if not boon_choices().has(String(action.get("id", ""))):
				reason = "Choose one of the three offered boons."
		"keep_boon":
			if state.active_boon.is_empty() or state.boon_queue.is_empty():
				reason = "Keeping a boon requires an active boon and a pending boss reward."
		"start_wave":
			if not state.boon_queue.is_empty():
				reason = "Choose a run boon first."
			elif state.selection_pending:
				reason = DataDB.text("choose_spirit")
		"select_element":
			var choice: Dictionary = {"element": action.get("element", ""), "tier": int(action.get("tier", 0))}
			if not state.boon_queue.is_empty() or not state.selection_pending or not choices().has(choice):
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
	if state.phase == "build" and type not in ["undo", "start_wave", "set_target", "choose_boon", "keep_boon", "swap_element"]:
		undo_stack.append(state.duplicate(true))
		if undo_stack.size() > int(cfg.undo_limit):
			undo_stack.pop_front()
	state.gold -= int(result.cost)
	match type:
		"place_stone":
			_place_stone(action.tile)
		"swap_element":
			undo_stack.clear()
			state.swap_tokens -= 1
			state.wave_swaps[action.kind] = action.element
			emit_event("element_swapped", {"kind": action.kind, "element": action.element})
		"build":
			var kind: String = action.kind
			var pure: bool = DataDB.ELEMENTS.has(kind)
			state.towers[slot] = TowerRules.create(next_id(), slot, "pure" if pure else kind, kind if pure else "normal", "", result.cost)
		"build_pure":
			state.towers[slot] = TowerRules.create(next_id(), slot, "ascended", action.kind, "", result.cost)
			state.stats.pure_crystals_spent = int(state.stats.get("pure_crystals_spent", 0)) + 1
			state.stats.pure_built = int(state.stats.get("pure_built", 0)) + 1
		"upgrade":
			tower.level += 1
			tower.erase("sabotaged")
			tower.invested += int(result.cost)
		"empower_pure":
			state.stats.pure_built = int(state.stats.get("pure_built", 0)) + 1
			TowerRules.empower_pure(tower)
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
			var merged: Dictionary = TowerRules.combine(dual, tower, second, state.tiers, spirit_victories(), next_id(), int(result.cost))
			Effects.inherit_sources(state.mobs, tower.id, second.id, merged.id)
			state.towers[slot] = merged
			state.towers.erase(action.slot_b)
			state.stats.fusions += 1
			emit_event("fused", {"slot": slot, "from": second.slot, "dual": dual, "elements": TowerRules.ingredients(merged), "refund": maxi(0, -int(result.cost))})
		"set_target":
			tower.target = action.mode
		"rally":
			tower.stun = 0
			state.rally_cd = int(cfg.rally_cooldown_ticks)
			emit_event("tower_rallied", {"slot": slot})
		"choose_boon", "keep_boon":
			var reward: Dictionary = state.boon_queue.pop_front()
			if type == "choose_boon":
				state.active_boon = {"id": action.id, "wave": reward.wave, "potency": reward.potency}
				refresh_boon()
			undo_stack.clear()
		"select_element":
			state.trial = {"element": action.element, "tier": int(action.tier)}
			state.selection_pending = false
		"start_wave":
			_start_wave()
		"undo":
			state = undo_stack.pop_back()
			refresh_boon()
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
	if EnemyRules.property(enemy, "thief"):
		var stolen: int = mini(int(state.gold), mini(250, 45 + int(state.wave) * 2))
		state.gold -= stolen
		emit_event("gold_stolen", {"s": enemy.s, "gold": stolen})
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
	var interest: int = Economy.interest(state.gold)
	state.gold += interest
	emit_event("interest_paid", {"gold": interest})
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
	state.stone = {}
	state.wave_swaps = {}
	if not state.trial.is_empty():
		state.trial = {}
		state.phase = "build"
		emit_event("bonus_finished")
		return
	var cleared: int = state.wave
	state.gold += Economy.clear_reward(cleared)
	state.wave += 1
	state.phase = "build"
	if cleared % int(cfg.gate_repair_every) == 0:
		_restore_gate()
	for tower: Dictionary in state.towers.values():
		tower.erase("petrified")
		if tower.get("stone_pending", false):
			tower.petrified = true
			tower.erase("stone_pending")
	if int(state.wave) % int(cfg.selection_every) == 0:
		state.selection_pending = not choices().is_empty()
	emit_event("wave_cleared", {"wave": cleared, "pure_crystal": int(state.wave) % int(cfg.pure_crystal_every) == 0})

func _place_stone(tile: Vector2i) -> void:
	var stop: float = track.stone_stop(tile)
	state.stone = {"tile": tile, "stop": stop, "until": int(state.tick) + Effects.ticks(cfg.stone_seconds, hz)}
	state.stone_blocks -= 1
	state.stone_last_wave = state.wave
	state.stone_ready_tick = int(state.tick) + Effects.ticks(cfg.stone_cooldown_seconds, hz)
	for enemy: Dictionary in state.mobs:
		if Vector2i(track.at(enemy.s).floor()) == tile:
			enemy.s = track.previous_corner(stop) if enemy.kind == "wizard" else stop
			enemy.prev_s = enemy.s
	emit_event("stone_placed", {"tile": tile})

func gate_repair_per_cycle() -> int:
	var repair: int = 0
	for tower: Dictionary in state.towers.values():
		if TowerRules.is_fusion(tower) and not TowerRules.disabled(tower):
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
