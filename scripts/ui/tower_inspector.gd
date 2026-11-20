class_name TowerInspector
extends RefCounted

static func metrics(tower: Dictionary, victories: Dictionary = {}) -> String:
	var attack: Dictionary = TowerRules.attack_profile(tower, victories)
	if float(attack.rate) == 0.0:
		return "Support · %s tile radius" % number(attack.range)
	var reach: String = DataDB.text("whole_map") if is_inf(float(attack.range)) else number(attack.range)
	return "DMG %s     RANGE %s     %s shots/s" % [number(attack.damage), reach, number(attack.rate)]

static func damage_type(tower: Dictionary, traits: Dictionary) -> String:
	if traits.has("adaptive"):
		return "Adaptive Light / Dark"
	var split: Dictionary = TowerRules.damage_split(tower)
	if split.is_empty():
		return "Support aura"
	if split.has("normal"):
		return "Neutral"
	var names := PackedStringArray()
	for element: String in split:
		var share: String = " %s" % percent(split[element]) if split.size() > 1 else ""
		names.append(element.capitalize() + share)
	return " / ".join(names)

static func effects(tower: Dictionary, tiers: Dictionary) -> PackedStringArray:
	var attack: Dictionary = TowerRules.attack_profile(tower)
	var traits: Dictionary = TowerRules.trait_profile(tower, tiers)
	var potency: float = attack.potency
	var infused: bool = tower.infusion != ""
	var lines := PackedStringArray()
	var crystal_bonus: float = TowerRules.crystal_damage_bonus(tower)
	if crystal_bonus > 0.0:
		lines.append("Pure Crystal · Socketed crystals increase damage by %s." % percent(crystal_bonus))
	if traits.has("ice"):
		lines.append("Ice puddles · Ice covers road tiles in range. Ordinary enemies slide at %s speed for %s s, then stumble at %s speed for %s s." % [
			percent(Effects.SLIDE_SPEED), number(traits.ice.slide), percent(Effects.STUMBLE_SPEED), number(Effects.slow_duration(traits.ice.stumble, potency))])
	if traits.has("disease"):
		var rule: Dictionary = traits.disease
		lines.append("Disease · Each second deals %s of the non-disease damage taken in the last %s s. Lasts %s s and spreads within %s tiles on defeat." % [
			percent(float(rule.fraction) * potency), number(DataDB.read("balance").disease_lookback),
			number(Effects.duration(rule.duration, potency)), number(rule.radius)])
	if traits.has("wall_heal"):
		lines.append("Gate repair · Restores %d HP after each regular wave. Only the strongest repair applies. Excess fills the barrier up to %d." % [
			int(traits.wall_heal), int(DataDB.read("balance").gate_barrier_cap)])
	if float(attack.splash) > 0:
		lines.append("Splash · Full damage within %s tiles of impact and %s damage out to %s tiles." % [
			number(attack.splash_core), percent(attack.splash_fringe), number(attack.splash)])
	for dot: String in ["burn", "poison"]:
		if traits.has(dot):
			var effect: Array = traits[dot]
			var stacks: int = ceili(float(effect[0]) * potency) if infused else roundi(float(effect[0]) * potency)
			lines.append("%s · %s of hit damage per second per stack, up to %d stacks for %s s." % [
				dot.capitalize(), percent(float(effect[1]) * potency), stacks, number(Effects.duration(effect[2], potency))])
	if traits.has("spread") and not infused:
		lines.append("Spreading burn · Burning enemies spread stacks on defeat within %s tiles." % number(traits.spread))
	if traits.has("slow"):
		lines.append("Slow · Reduces movement by up to %s for %s s. Spirits and bosses resist slows." % [
			percent(Effects.slow_strength(traits.slow[0], potency)), number(Effects.slow_duration(traits.slow[1], potency))])
	for cc: String in ["freeze", "root"]:
		if traits.has(cc):
			lines.append("%s · Stops ordinary enemies for %s s every %d attacks." % [
				cc.capitalize(), number(Effects.control_duration(traits[cc][1], potency, cc)), Effects.control_interval(traits[cc][0], potency, infused, cc)])
	if traits.has("chain"):
		var jumps: int = ceili(float(traits.chain[0]) * potency) if infused else roundi(float(traits.chain[0]) * potency)
		lines.append("Chain · Jumps to %d additional enemies within %s tiles per jump. Each jump keeps %s damage." % [
			jumps, number(Effects.chain_range(traits.chain[1], potency)), percent(Effects.chain_falloff(traits.chain[2], potency))])
	if traits.has("pierce"):
		lines.append("Armor pierce · Ignores %s of armor." % percent(minf(.90, float(traits.pierce) * potency)))
	if traits.has("curse"):
		lines.append("Curse · Target takes %s more damage for %s s." % [
			percent(float(traits.curse[0]) * potency), number(Effects.duration(traits.curse[1], potency))])
	if traits.has("pulse"):
		lines.append("Pulse · Hits all enemies in range.")
	if traits.has("aura_damage"):
		lines.append("Damage aura · Towers on tiles touched by the aura gain %s damage." % percent(float(traits.aura_damage) * potency))
	if traits.has("aura_speed"):
		lines.append("Attack-speed aura · Towers on tiles touched by the aura fire %s faster." % percent(float(traits.aura_speed) * potency))
	if traits.has("cleanse") and not infused:
		lines.append("Stun protection · Reduces stun duration by %s for towers within %s tiles." % [
			percent(minf(1.0, float(traits.cleanse[0]) * potency)), number(traits.cleanse[1])])
	if traits.has("heal_block") and not infused:
		lines.append("Heal block · Prevents healing for %s s." % number(traits.heal_block))
	if traits.has("shred"):
		lines.append("Armor shred · Removes %s armor per stack for %s s, up to %d stacks." % [
			number(float(traits.shred[0]) * potency), number(traits.shred[2]), roundi(float(traits.shred[1]) * potency)])
	if traits.has("ramp"):
		lines.append("Focused beam · Gains %s damage per second on the same target, up to ×%s." % [
			percent(float(traits.ramp[0]) * potency), number(traits.ramp[1])])
	if traits.has("silence"):
		lines.append("Silence · Suppresses enemy traits for %s s and can dispel phasing." % number(traits.silence))
	if traits.has("adaptive"):
		lines.append("Adaptive hit · Uses whichever of Light or Dark deals more damage.")
	if lines.is_empty():
		lines.append("Single target · Aimed projectiles hit one enemy at a time.")
	return lines

static func effect_values(tower: Dictionary, tiers: Dictionary) -> String:
	return " · ".join(effect_labels(tower, tiers))

static func effect_labels(tower: Dictionary, tiers: Dictionary) -> PackedStringArray:
	var labels := PackedStringArray()
	for entry: Dictionary in effect_entries(tower, tiers):
		labels.append(entry.label)
	return labels

static func effect_entries(tower: Dictionary, tiers: Dictionary) -> Array[Dictionary]:
	var traits: Dictionary = TowerRules.trait_profile(tower, tiers)
	var potency: float = TowerRules.attack_profile(tower).potency
	var labels: Dictionary = {}
	if int(tower.get("crystals", 0)) > 0:
		labels["Pure Crystal"] = "◈ +%s damage" % percent(TowerRules.crystal_damage_bonus(tower))
	if traits.has("slow"):
		labels["Slow"] = "Slow %s · %ss" % [percent(Effects.slow_strength(traits.slow[0], potency)),
			number(Effects.slow_duration(traits.slow[1], potency))]
	if traits.has("curse"):
		labels["Curse"] = "Curse %s" % percent(float(traits.curse[0]) * potency)
	for key: String in ["burn", "poison"]:
		if traits.has(key):
			var effect: Array = traits[key]
			var cap: int = ceili(float(effect[0]) * potency) if tower.infusion != "" else roundi(float(effect[0]) * potency)
			labels[key.capitalize()] = "%s %s/s ×%d" % [key.capitalize(), percent(float(effect[1]) * potency), cap]
	for key: String in ["freeze", "root"]:
		if traits.has(key):
			labels[key.capitalize()] = "%s %ss" % [key.capitalize(), number(Effects.control_duration(traits[key][1], potency, key))]
	if traits.has("disease"):
		labels["Disease"] = "Disease %s/s" % percent(float(traits.disease.fraction) * potency)
	if traits.has("pierce"):
		labels["Armor pierce"] = "Pierce %s" % percent(minf(.9, float(traits.pierce) * potency))
	if traits.has("chain"):
		var jumps: int = ceili(float(traits.chain[0]) * potency) if tower.infusion != "" else roundi(float(traits.chain[0]) * potency)
		labels["Chain"] = "Chain %d jumps" % jumps
	if traits.has("aura_damage"):
		labels["Damage aura"] = "Damage aura +%s" % percent(float(traits.aura_damage) * potency)
	if traits.has("aura_speed"):
		labels["Attack-speed aura"] = "Rate aura +%s" % percent(float(traits.aura_speed) * potency)
	if traits.has("shred"):
		labels["Armor shred"] = "Shred %s armor" % number(float(traits.shred[0]) * potency)
	var entries: Array[Dictionary] = []
	for line: String in effects(tower, tiers):
		var title: String = line.get_slice(" · ", 0)
		entries.append({"label": labels.get(title, title), "detail": line, "tint": StatusInfo.accent(title)})
	return entries

static func history(tower: Dictionary) -> String:
	return "%s damage dealt   ·   %d kills" % [number(float(tower.get("damage_dealt", 0))), int(tower.get("kills", 0))]

static func number(value: float) -> String:
	var rounded: float = snappedf(value, .01)
	return str(roundi(rounded)) if is_equal_approx(rounded, roundf(rounded)) else str(rounded)

static func percent(value: float) -> String:
	return "%s%%" % number(value * 100.0)
