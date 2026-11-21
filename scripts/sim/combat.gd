class_name Combat
extends RefCounted

static func spawn(sim: RefCounted, group: Dictionary, distance: float) -> void:
	var enemy: Dictionary = EnemyRules.create(sim.next_id(), group, distance, sim.state.tick)
	sim.state.mobs.append(enemy)
	if enemy.kind == "petrifier":
		_mark_towers(sim, enemy)
	if enemy.kind in ["spirit", "boss"]:
		sim.emit_event("special_spawned", {"kind": enemy.kind, "element": enemy.element})

static func advance(sim: RefCounted) -> void:
	var towers: Array = sim.ordered_towers()
	var support_sources: Array[Dictionary] = TowerRules.support_sources(towers)
	var points: Dictionary = {}
	var by_id: Dictionary = {}
	for tower: Dictionary in towers:
		by_id[tower.id] = tower
	var enemies: Array = sim.state.mobs
	var banners: Array[Vector2] = []
	for enemy: Dictionary in enemies:
		if float(enemy.hp) > 0.0 and EnemyRules.property(enemy, "banner"):
			banners.append(sim.track.at(enemy.s))
	var ice: Dictionary = sim.ice_tiles()
	var cutoff: int = int(sim.state.tick) - Effects.ticks(sim.cfg.disease_lookback, sim.hz)
	for enemy: Dictionary in enemies:
		if enemy.boss_type == "prismheart":
			var previous_form: String = enemy.element
			EnemyRules.update_form(enemy, sim.state.tick, sim.hz)
			if enemy.element != previous_form:
				sim.emit_event("boss_morphed")
		var phased: bool = EnemyRules.phased(enemy, sim.state.tick, sim.hz)
		var hidden: bool = EnemyRules.hidden(enemy, sim.track, sim.state.tick, sim.hz)
		enemy.erase("bannered")
		if not banners.is_empty() and not enemy.props.has("banner"):
			var origin: Vector2 = sim.track.at(enemy.s)
			for banner: Vector2 in banners:
				if banner.distance_squared_to(origin) <= 2.25:
					enemy.bannered = true
					break
		Damage.expire_history(enemy, cutoff)
		Effects.tick(enemy, sim.hz, phased or hidden, by_id, sim.state.tick)
		var old: float = enemy.s
		enemy.prev_s = old
		var skid: float = 1.0
		if not ice.is_empty() or enemy.has("on_ice"):
			var tile := Vector2i(sim.track.at(old).floor())
			skid = Effects.ice_speed(enemy, {} if phased or hidden else ice.get(tile, {}))
		if enemy.kind == "wizard":
			EnemyRules.warp(enemy, sim.track, sim.state.tick, sim.hz)
			if _crossed_stone(sim.state.stone, old, float(enemy.s)):
				enemy.s = old
				enemy.prev_s = old
			if float(enemy.s) != old or (hidden and not EnemyRules.in_void(enemy, sim.state.tick - 1, sim.hz)):
				sim.emit_event("wizard_portal", {"s": enemy.s, "arrived": float(enemy.s) != old})
		else:
			EnemyRules.move(enemy, sim.track, sim.hz, skid)
			if _crossed_stone(sim.state.stone, old, float(enemy.s)):
				enemy.s = sim.state.stone.stop
		points[enemy.id] = sim.track.at(enemy.s)
		if float(enemy.hp) > 0.0 and EnemyRules.property(enemy, "saboteur") and not enemy.get("sabotage_used", false) and float(enemy.s) >= sim.track.total * .45:
			_sabotage(sim, enemy, points[enemy.id], towers)
		if enemy.kind == "boss" and float(enemy.hp) > 0:
			_boss(sim, enemy, points[enemy.id], towers)
	var ready: Array = []
	var exposed: Array = []
	for enemy: Dictionary in enemies:
		if float(enemy.hp) <= 0.0 or EnemyRules.hidden(enemy, sim.track, sim.state.tick, sim.hz):
			continue
		exposed.append(enemy)
		if not EnemyRules.phased(enemy, sim.state.tick, sim.hz):
			ready.append(enemy)
	for tower: Dictionary in towers:
		tower.stun = maxi(0, int(tower.stun) - 1)
		tower.cooldown = maxi(0, int(tower.cooldown) - 1)
		if int(tower.stun) == 0 and int(tower.cooldown) == 0 and not TowerRules.disabled(tower):
			_attack(sim, tower, support_sources, exposed if tower.dual == "null" else ready, points)
	var survivors: Array[Dictionary] = []
	for enemy: Dictionary in enemies:
		if float(enemy.hp) <= 0.0:
			_kill(sim, enemy, enemies, by_id)
		elif float(enemy.s) + 0.000001 >= sim.track.total:
			sim.lose_lives(enemy)
		else:
			survivors.append(enemy)
		if sim.state.phase == "game_over":
			break
	sim.state.mobs = survivors

static func _crossed_stone(stone: Dictionary, from: float, to: float) -> bool:
	return not stone.is_empty() and from <= float(stone.stop) + .011 and to > float(stone.stop)

static func _mark_towers(sim: RefCounted, enemy: Dictionary) -> void:
	var towers: Array = sim.ordered_towers()
	var rng := SimRng.new((int(sim.state.seed) * 65537) ^ (int(sim.state.wave) * 7919) ^ (int(enemy.id) * 104729))
	var targets: int = int(DataDB.read("waves").petrifier.targets)
	for i: int in range(mini(targets, towers.size())):
		var tower: Dictionary = towers.pop_at(rng.take(towers.size()))
		tower.stone_pending = true
		sim.emit_event("tower_stone_marked", {"slot": tower.slot, "s": enemy.s})

static func _attack(sim: RefCounted, tower: Dictionary, support_sources: Array[Dictionary], candidates: Array, points: Dictionary) -> void:
	var stats: Dictionary = TowerRules.stats(tower)
	if float(stats.rate) == 0.0:
		return
	var effective: Dictionary = sim.effective_tower(tower)
	var boon: Dictionary = sim.tower_boon(effective)
	var trait_profile: Dictionary = TowerRules.trait_profile(effective, sim.state.tiers, boon)
	var profile: Dictionary = TowerRules.attack_profile(effective, sim.spirit_victories(), boon)
	var at: Vector2 = sim.track.slots[tower.slot].position
	var aura: Vector3 = sim.support_bonuses(tower, support_sources)
	var radius: float = float(profile.range) * (1.0 + aura.z)
	var target: Dictionary = _best(candidates, points, at, radius, tower.target)
	if target.is_empty():
		tower.beam_target = -1
		return
	var infused: bool = effective.infusion != ""
	var potency: float = profile.potency
	var raw: float = float(profile.damage) * (1.0 + aura.x)
	if trait_profile.has("ramp"):
		if int(tower.beam_target) != int(target.id):
			tower.beam_target = target.id
			tower.beam_start = sim.state.tick
		var seconds: float = (int(sim.state.tick) - int(tower.beam_start)) / sim.hz
		raw *= minf(float(trait_profile.ramp[1]), 1.0 + float(trait_profile.ramp[0]) * seconds * potency)
	tower.cooldown = ceili(sim.hz / (float(profile.rate) * (1.0 + aura.y)))
	tower.hits += 1
	var victims: Array[Dictionary] = [target]
	var pulse: bool = trait_profile.has("pulse")
	var anchor: Vector2 = at if pulse else points[target.id]
	if pulse or float(profile.splash) > 0.0:
		var splash: float = radius if pulse else float(profile.splash)
		for enemy: Dictionary in candidates:
			if enemy.id != target.id and float(enemy.hp) > 0 and anchor.distance_squared_to(points[enemy.id]) <= splash * splash:
				victims.append(enemy)
	var area_count: int = victims.size()
	var jumps: int = 0
	var falloff: float = 1.0
	if trait_profile.has("chain"):
		jumps = ceili(float(trait_profile.chain[0]) * potency) if infused else roundi(float(trait_profile.chain[0]) * potency)
		falloff = Effects.chain_falloff(trait_profile.chain[2], potency)
		var jump_range: float = Effects.chain_range(trait_profile.chain[1], potency)
		var last: Dictionary = target
		for jump: int in range(jumps):
			last = _best(candidates, points, points[last.id], jump_range, "nearest", victims)
			if last.is_empty():
				break
			victims.append(last)
	var split: Dictionary = TowerRules.damage_split(effective)
	var adaptive: bool = trait_profile.has("adaptive")
	var pierce: float = minf(0.9, float(trait_profile.get("pierce", 0.0)) * potency)
	var previous: Dictionary = {}
	for index: int in range(victims.size()):
		var victim: Dictionary = victims[index]
		var chained: bool = index >= area_count
		var scale: float = 1.0
		if chained:
			scale = pow(falloff, index - area_count + 1)
		elif index > 0 and not pulse and anchor.distance_squared_to(points[victim.id]) > float(profile.splash_core) ** 2:
			scale = float(profile.splash_fringe)
		var multiplier: float = Damage.against(split, victim, adaptive)
		var adjusted: float = raw * multiplier * scale
		if tower.dual == "null" and EnemyRules.phased(victim, sim.state.tick, sim.hz):
			victim.silence_time = Effects.ticks(trait_profile.silence, sim.hz)
		Damage.deal(victim, Damage.hit(adjusted, victim.armor, pierce, victim.shred, victim.curse), tower, sim.state.tick)
		if adjusted > 0.0:
			var effect_base: float = raw * scale if Damage.has_special_resistances(victim) else adjusted
			Effects.apply(victim, trait_profile, potency, infused, tower.hits, effect_base, sim.hz, tower.id)
			var previous_immunity: String = victim.get("immune_element", "")
			Damage.adapt(victim, split, adaptive)
			var immunity: String = victim.get("immune_element", "")
			if immunity != previous_immunity and not immunity.is_empty():
				sim.emit_event("chameleon_adapted", {"s": victim.s, "element": immunity})
		var style: String = "bolt"
		if pulse:
			style = "pulse" if previous.is_empty() else "impact"
		elif not previous.is_empty():
			style = "chain" if chained else "impact"
		elif tower.kind == "cannon":
			style = "shell"
		elif tower.element == "light" and tower.kind in ["pure", "ascended"]:
			style = "beam"
		elif trait_profile.has("ramp") or jumps > 0:
			style = "beam"
		sim.emit_event("tower_fired", {
			"slot": tower.slot, "s": victim.s, "target_id": victim.id, "primary": previous.is_empty(), "style": style,
			"infusion": effective.infusion,
			"from_s": float(target.s if index == area_count else previous.s) if style == "chain" else -1.0,
			"area": radius if pulse else float(profile.splash), "core": float(profile.splash_core),
			"range": radius if is_finite(radius) else float(stats.range),
		})
		previous = victim

static func _sabotage(sim: RefCounted, enemy: Dictionary, position: Vector2, towers: Array) -> void:
	enemy.sabotage_used = true
	var chosen: Dictionary = {}
	var nearest: float = INF
	for tower: Dictionary in towers:
		if tower.get("sabotaged", false) or not TowerRules.level_requirement(tower, sim.state.tiers).is_empty():
			continue
		var distance: float = position.distance_squared_to(sim.track.slots[tower.slot].position)
		if distance < nearest:
			nearest = distance
			chosen = tower
	if not chosen.is_empty():
		chosen.sabotaged = true
		sim.emit_event("tower_sabotaged", {"slot": chosen.slot, "s": enemy.s})

static func _best(candidates: Array, points: Dictionary, at: Vector2, radius: float, mode: String, excluded: Array = []) -> Dictionary:
	var best: Dictionary = {}
	var score: float = -INF
	for enemy: Dictionary in candidates:
		if float(enemy.hp) <= 0 or excluded.has(enemy):
			continue
		var distance: float = at.distance_squared_to(points[enemy.id])
		if distance > radius * radius:
			continue
		var value: float = float(enemy.s)
		match mode:
			"nearest": value = -distance
			"strongest": value = float(enemy.hp)
		if value > score or (value == score and int(enemy.id) < int(best.id)):
			best = enemy
			score = value
	return best

static func _kill(sim: RefCounted, enemy: Dictionary, enemies: Array, by_id: Dictionary) -> void:
	var rules: Dictionary = DataDB.read("mobs").properties
	var position: Vector2 = sim.track.at(enemy.s)
	if EnemyRules.property(enemy, "revenant") and not enemy.revived and int(enemy.heal_block_time) == 0:
		var revived: Dictionary = EnemyRules.from_enemy(enemy)
		revived.hp = float(enemy.max_hp) * float(rules.revenant.hp)
		revived.revived = true
		sim.schedule(revived, int(sim.state.wave_tick) + Effects.ticks(rules.revenant.delay, sim.hz), enemy.s)
		return
	if EnemyRules.property(enemy, "mender") and int(enemy.heal_block_time) == 0:
		for other: Dictionary in enemies:
			if float(other.hp) > 0 and int(other.heal_block_time) == 0 and position.distance_to(sim.track.at(other.s)) <= float(rules.mender.radius):
				other.hp = minf(float(other.max_hp), float(other.hp) + float(other.max_hp) * float(rules.mender.heal))
	if EnemyRules.property(enemy, "splitter"):
		var child: Dictionary = EnemyRules.from_enemy(enemy)
		child.merge({"kind": "splitling", "props": [], "gold": 0, "hp": float(enemy.max_hp) * float(rules.splitter.hp)}, true)
		for index: int in range(int(rules.splitter.count)):
			sim.schedule(child, int(sim.state.wave_tick) + 1, enemy.s)
	if enemy.dots.has("burn"):
		var burn: Dictionary = enemy.dots.burn
		var count: int = floori(float(burn.stacks) * 0.5)
		if float(burn.spread) > 0 and count > 0:
			for other: Dictionary in enemies:
				if float(other.hp) > 0 and not EnemyRules.in_void(other, sim.state.tick, sim.hz) and position.distance_to(sim.track.at(other.s)) <= float(burn.spread):
					Effects.add_dot(other, "burn", burn.dps, burn.cap, count, burn.time, burn.spread, burn.get("owners", []))
	if enemy.has("disease"):
		var strain: Dictionary = enemy.disease
		var radius: float = float(strain.radius)
		for other: Dictionary in enemies:
			if float(other.hp) > 0 and not EnemyRules.phased(other, sim.state.tick, sim.hz) and not EnemyRules.in_void(other, sim.state.tick, sim.hz) and position.distance_squared_to(sim.track.at(other.s)) <= radius * radius:
				Effects.infect(other, strain)
	var killer: Dictionary = by_id.get(int(enemy.get("kill_credit", -1)), {})
	if not killer.is_empty():
		killer.kills = int(killer.get("kills", 0)) + 1
	sim.state.stats.kills += 1
	if enemy.kind == "boss":
		sim.record_boss_kill()
	if enemy.kind == "spirit":
		sim.resolve_spirit(enemy)
	else:
		sim.state.gold += int(enemy.gold)
	sim.emit_event("mob_killed", {
		"kind": enemy.kind, "boss": enemy.boss_type, "s": enemy.s, "element": enemy.element, "gold": enemy.gold,
	})

static func _boss(sim: RefCounted, enemy: Dictionary, at: Vector2, towers: Array) -> void:
	var data: Dictionary = DataDB.read("bosses")[enemy.boss_type]
	var age: int = int(sim.state.tick) - int(enemy.born)
	match enemy.boss_type:
		"warlock":
			if not enemy.telegraph.is_empty() and int(sim.state.tick) >= int(enemy.telegraph.tick):
				var tower: Dictionary = sim.state.towers.get(enemy.telegraph.slot, {})
				if not tower.is_empty():
					_stun(sim, tower, towers, data.stun)
				enemy.telegraph = {}
			if age > 0 and age % int(data.period) == 0:
				var best: Dictionary = {}
				for tower: Dictionary in towers:
					var point: Vector2 = sim.track.slots[tower.slot].position
					var preferred: bool = best.is_empty() or int(tower.level) > int(best.level)
					if not best.is_empty() and int(tower.level) == int(best.level):
						preferred = int(sim.track.slots[tower.slot].order) < int(sim.track.slots[best.slot].order)
					if preferred and at.distance_to(point) <= float(data.range):
						best = tower
				if not best.is_empty():
					enemy.telegraph = {"slot": best.slot, "tick": int(sim.state.tick) + int(data.telegraph)}
		"necromancer":
			if age == 0 or age % int(data.period) != 0:
				return
			if enemy.get("heal_aura", false):
				var late: Dictionary = DataDB.read("waves").late_game
				for ally: Dictionary in sim.state.mobs:
					if float(ally.hp) > 0.0 and int(ally.heal_block_time) == 0 and at.distance_to(sim.track.at(ally.s)) <= float(late.necromancer_radius):
						ally.hp = minf(float(ally.max_hp), float(ally.hp) + float(ally.max_hp) * float(late.necromancer_heal))
				sim.emit_event("boss_healed", {"s": enemy.s, "radius": late.necromancer_radius})
				return
			var husks: int = 0
			for mob: Dictionary in sim.state.mobs:
				if mob.kind == "husk" and float(mob.hp) > 0:
					husks += 1
			var mobs: Dictionary = DataDB.read("mobs")
			var group: Dictionary = {
				"kind": "husk", "props": [], "element": "none", "gold": 0, "armor": 0,
				"hp": Waves.base_enemy_hp(int(sim.state.wave)) * float(data.hp) * float(mobs.health_multiplier),
				"speed": float(mobs.speed), "leak": int(sim.cfg.leak.mob), "slow_cap": float(mobs.slow_cap),
			}
			for index: int in range(mini(int(data.count), int(data.cap) - husks)):
				sim.schedule(group, int(sim.state.wave_tick) + 1, enemy.s)

static func _stun(sim: RefCounted, target: Dictionary, towers: Array, duration: int) -> void:
	var resistance: float = 0.0
	var at: Vector2 = sim.track.slots[target.slot].position
	for tower: Dictionary in towers:
		if tower.kind in ["pure", "ascended"] and tower.element == "light" and not TowerRules.disabled(tower):
			var cleanse: Array = TowerRules.trait_profile(tower, sim.state.tiers).get("cleanse", [])
			var source: Vector2 = sim.track.slots[tower.slot].position
			if not cleanse.is_empty() and at.distance_to(source) <= float(cleanse[1]):
				resistance = maxf(resistance, minf(1.0, float(cleanse[0]) * float(sim.tower_profile(tower).potency)))
	var ticks: int = roundi(duration * (1.0 - resistance))
	if ticks > 0:
		target.stun = maxi(int(target.stun), ticks + 1)
		sim.emit_event("tower_stunned", {"slot": target.slot})
