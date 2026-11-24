class_name Effects
extends RefCounted

const SLIDE_SPEED: float = 1.45
const STUMBLE_SPEED: float = .15

static func tick(mob: Dictionary, hz: float, invulnerable: bool = false, towers: Dictionary = {}, at_tick: int = -1) -> void:
	for status: String in ["slow", "curse", "shred", "freeze", "root", "silence", "heal_block", "dispel", "tenacity_shred", "paralysis"]:
		var key: String = status + "_time"
		if not mob.has(key):
			continue
		mob[key] = maxi(0, int(mob[key]) - 1)
		if int(mob[key]) == 0 and mob.has(status):
			mob[status] = 0
			if status == "shred":
				mob.shred_stacks = 0
	if mob.has("control_recovery") and int(mob.freeze_time) == 0 and int(mob.root_time) == 0:
		mob.control_recovery -= 1
		if int(mob.control_recovery) <= 0:
			mob.erase("control_recovery")
	for type: String in mob.dots.keys():
		var dot: Dictionary = mob.dots[type]
		if not invulnerable and float(mob.hp) > 0.0:
			_tick_dot(mob, type, dot, hz, towers, at_tick)
		dot.time -= 1
		if int(dot.time) <= 0 and float(mob.hp) > 0.0:
			mob.dots.erase(type)
	if mob.has("disease"):
		var disease: Dictionary = mob.disease
		if not invulnerable and float(mob.hp) > 0.0:
			Damage.deal(mob, disease_rate(mob) / hz, towers.get(disease.source, {}))
		disease.time -= 1
		if int(disease.time) <= 0 and float(mob.hp) > 0.0:
			mob.erase("disease")

static func _tick_dot(mob: Dictionary, type: String, dot: Dictionary, hz: float, towers: Dictionary, at_tick: int) -> void:
	var owners: Array = dot.get("owners", [])
	var stacks: int = int(dot.stacks)
	var first: int = -1 if owners.is_empty() else int(owners[0])
	var element: String = "nature" if type == "poison" else "fire"
	if mob.get("immune_element", "") == element and EnemyRules.property(mob, "chameleon"):
		return
	var per_stack: float = float(dot.dps) / hz * Damage.special_matchup(element, mob)
	if owners.is_empty() or owners.count(first) == stacks:
		Damage.deal(mob, per_stack * stacks, towers.get(first, {}), at_tick)
		return
	for index: int in range(stacks):
		var owner: int = int(owners[index]) if index < owners.size() else -1
		Damage.deal(mob, per_stack, towers.get(owner, {}), at_tick)
		if float(mob.hp) <= 0.0:
			break

static func apply(mob: Dictionary, trait_profile: Dictionary, potency: float, infusion: bool, hit_number: int, raw: float, hz: float, source: int = -1) -> void:
	if mob.kind == "bonus":
		return
	if trait_profile.has("searing_burn"):
		var burn: Array = trait_profile.searing_burn
		ignite(mob, float(burn[0]) * potency, raw, ticks(duration(burn[1], potency), hz), burn[2], source)
	for type: String in ["burn", "poison"]:
		if trait_profile.has(type):
			var effect: Array = trait_profile[type]
			var stacks: int = ceili(float(effect[0]) * potency) if infusion else roundi(float(effect[0]) * potency)
			var spread: float = float(trait_profile.get("spread", 0.0)) if not infusion and type == "burn" else 0.0
			var dps: float = raw * float(effect[1]) * potency
			add_dot(mob, type, dps, stacks, 1, ticks(duration(effect[2], potency), hz), spread, [source])
			if type == "poison" and trait_profile.has("poison_burst"):
				var rule: Dictionary = trait_profile.poison_burst
				var hit: float = raw * float(rule.damage) * potency
				var poison: Dictionary = mob.dots.poison
				if hit >= float(poison.get("burst", {}).get("damage", 0.0)):
					poison.burst = {"damage": hit, "dps": dps * .5, "source": source, "radius": rule.radius,
						"targets": rule.max_targets, "duration": ticks(rule.duration, hz)}
	if trait_profile.has("tenacity_shred"):
		var shred: Array = trait_profile.tenacity_shred
		timed(mob, "tenacity_shred", float(shred[0]) * potency, _boss_debuff_ticks(mob, ticks(duration(shred[1], potency), hz)))
	if trait_profile.has("slow") and mob.kind != "wizard":
		var strength: float = minf(float(mob.slow_cap), slow_strength(trait_profile.slow[0], potency))
		strength *= 1.0 - EnemyRules.effective_tenacity(mob)
		timed(mob, "slow", strength, ticks(slow_duration(trait_profile.slow[1], potency), hz))
	if trait_profile.has("paralysis") and mob.kind != "wizard":
		var paralysis: Array = trait_profile.paralysis
		if hit_number % control_interval(paralysis[0], potency, infusion, "paralysis") == 0:
			var strength: float = minf(float(mob.slow_cap), float(paralysis[1])) * (1.0 - EnemyRules.effective_tenacity(mob))
			timed(mob, "paralysis", strength, ticks(duration(paralysis[2], potency), hz))
	if trait_profile.has("curse"):
		timed(mob, "curse", float(trait_profile.curse[0]) * potency, _boss_debuff_ticks(mob, ticks(duration(trait_profile.curse[1], potency), hz)))
	if trait_profile.has("shred"):
		var stacks: int = mini(int(mob.shred_stacks) + 1, roundi(float(trait_profile.shred[1]) * potency))
		mob.shred_stacks = stacks
		mob.shred = float(trait_profile.shred[0]) * stacks * potency
		mob.shred_time = _boss_debuff_ticks(mob, ticks(trait_profile.shred[2], hz))
	if trait_profile.has("heal_block"):
		var seconds: float = float(trait_profile.heal_block) * (potency if infusion else 1.0)
		mob.heal_block_time = maxi(mob.heal_block_time, _boss_debuff_ticks(mob, ticks(seconds, hz)))
	if trait_profile.has("disease"):
		var rules: Dictionary = trait_profile.disease
		var lifetime: int = ticks(duration(rules.duration, potency), hz)
		infect(mob, {"fraction": float(rules.fraction) * potency, "duration": lifetime, "time": lifetime,
			"source": source, "radius": rules.radius})
	if mob.kind == "spirit":
		return
	for cc: String in ["freeze", "root"]:
		if trait_profile.has(cc):
			var every: int = control_interval(trait_profile[cc][0], potency, infusion, cc)
			if hit_number % every == 0:
				_apply_hard_control(mob, cc, control_duration(trait_profile[cc][1], potency, cc), hz)
	if trait_profile.has("silence") and mob.kind != "boss":
		mob.silence_time = maxi(mob.silence_time, ticks(trait_profile.silence, hz))

static func _apply_hard_control(mob: Dictionary, effect: String, seconds: float, hz: float) -> void:
	if mob.kind == "wizard" or mob.has("control_recovery") or (effect == "root" and EnemyRules.airborne(mob)):
		return
	var resistance: float = EnemyRules.effective_tenacity(mob)
	var key: String = effect + "_time"
	mob[key] = maxi(int(mob[key]), ticks(seconds * (1.0 - resistance), hz))
	if resistance > 0.0:
		# Leave at least one movement tick before another tower can stop this enemy.
		mob.control_recovery = ticks(seconds * resistance, hz) + 1

static func infect(mob: Dictionary, strain: Dictionary) -> void:
	if mob.kind == "bonus":
		return
	var active: Dictionary = mob.get("disease", {})
	if active.is_empty() or float(strain.fraction) >= float(active.fraction):
		var next: Dictionary = strain.duplicate()
		next.time = maxi(int(active.get("time", 0)), _boss_debuff_ticks(mob, int(strain.duration)))
		mob.disease = next

static func disease_rate(mob: Dictionary) -> float:
	return float(mob.get("recent_damage", 0.0)) * float(mob.get("disease", {}).get("fraction", 0.0)) * Damage.special_matchup("dark", mob)

static func ice_speed(mob: Dictionary, ice: Dictionary) -> float:
	if mob.kind in ["spirit", "bonus", "wizard"] or EnemyRules.airborne(mob):
		return 1.0
	if not ice.is_empty() and not bool(mob.get("on_ice", false)) and int(mob.get("slip_time", 0)) == 0:
		mob.slip_time = int(ice.slide) + int(ice.stumble)
		mob.slip_stumble = int(ice.stumble)
	mob.on_ice = not ice.is_empty()
	var left: int = int(mob.get("slip_time", 0))
	if left <= 0:
		return 1.0
	var multiplier: float = slip_speed(mob)
	mob.slip_time -= 1
	return multiplier

static func slip_speed(mob: Dictionary) -> float:
	var left: int = int(mob.get("slip_time", 0))
	if left <= 0:
		return 1.0
	return SLIDE_SPEED if left > int(mob.slip_stumble) else lerpf(STUMBLE_SPEED, 1.0, EnemyRules.effective_tenacity(mob))

static func timed(mob: Dictionary, status: String, strength: float, duration: int) -> void:
	var key: String = status + "_time"
	var previous: float = mob.get(status, 0.0)
	if strength > 0.0 and strength >= previous:
		mob[key] = maxi(int(mob.get(key, 0)) if strength == previous else 0, duration)
		mob[status] = strength

static func dispel(mob: Dictionary, seconds: float, hz: float) -> void:
	if mob.kind in ["boss", "spirit"]:
		return
	if not mob.get("bannered", false) and not mob.props.has("banner") and not mob.props.has("phasing") and not mob.props.has("chameleon"):
		return
	mob.erase("bannered")
	mob.erase("immune_element")
	mob.dispel_time = maxi(int(mob.get("dispel_time", 0)), ticks(seconds, hz))

static func ignite(mob: Dictionary, fraction: float, hit: float, time: int, spread: float, source: int) -> void:
	var dps: float = float(mob.max_hp) * fraction
	if mob.kind in ["boss", "spirit"]:
		dps = minf(dps, hit * float(DataDB.read("balance").max_hp_burn_special_dps_cap))
	var active: Dictionary = mob.dots.get("searing_burn", {})
	if dps >= float(active.get("dps", 0.0)) and time > 0:
		mob.dots.searing_burn = {"dps": dps, "stacks": 1, "owners": [source], "fraction": fraction,
			"hit": hit, "spread": spread, "time": maxi(_boss_debuff_ticks(mob, time), int(active.get("time", 0)))}

static func add_dot(mob: Dictionary, type: String, dps: float, cap: int, count: int, duration: int, spread: float, sources: Array = []) -> void:
	if mob.kind == "bonus":
		return
	var dot: Dictionary = mob.dots.get(type, {"stacks": 0, "cap": 0, "time": 0, "dps": 0.0, "spread": 0.0})
	var owners: Array = dot.get("owners", [])
	var previous: int = int(dot.stacks)
	while owners.size() < previous:
		owners.append(-1)
	dot.cap = maxi(int(dot.cap), cap)
	dot.stacks = mini(int(dot.cap), previous + count)
	for index: int in range(int(dot.stacks) - previous):
		owners.append(-1 if index >= sources.size() else int(sources[index]))
	dot.owners = owners
	dot.time = maxi(int(dot.time), _boss_debuff_ticks(mob, duration))
	dot.dps = maxf(float(dot.dps), dps)
	dot.spread = maxf(float(dot.spread), spread)
	mob.dots[type] = dot

static func inherit_sources(mobs: Array, first: int, second: int, replacement: int) -> void:
	for mob: Dictionary in mobs:
		for dot: Dictionary in mob.dots.values():
			var owners: Array = dot.get("owners", [])
			for index: int in range(owners.size()):
				if int(owners[index]) in [first, second]:
					owners[index] = replacement
			var burst: Dictionary = dot.get("burst", {})
			if int(burst.get("source", -1)) in [first, second]:
				burst.source = replacement

static func ticks(seconds: float, hz: float) -> int:
	return ceili(seconds * hz)

static func _boss_debuff_ticks(mob: Dictionary, base_ticks: int) -> int:
	return ceili(base_ticks * (1.0 - EnemyRules.effective_tenacity(mob))) if mob.kind == "boss" else base_ticks

static func duration(seconds: float, potency: float) -> float:
	return seconds * (1.0 + maxf(0.0, potency - 1.0) * .6)

static func slow_strength(base: float, potency: float) -> float:
	return base * (potency + maxf(0.0, potency - 1.0) * .3)

static func slow_duration(seconds: float, potency: float) -> float:
	return seconds * (1.0 + maxf(0.0, potency - 1.0) * 1.15)

static func control_duration(seconds: float, potency: float, status: String) -> float:
	return seconds * (1.0 + maxf(0.0, potency - 1.0) * 1.25) if status == "root" else duration(seconds, potency)

static func control_interval(every: int, potency: float, infused: bool, status: String) -> int:
	var interval: int = every
	if status == "root" and potency >= 1.5:
		interval = maxi(2, every - 1)
	return interval * (2 if infused else 1)

static func chain_range(base: float, potency: float) -> float:
	return base * (1.0 + maxf(0.0, potency - 1.0) * .4)

static func chain_falloff(base: float, potency: float) -> float:
	return minf(.95, base + maxf(0.0, potency - 1.0) * .1)
