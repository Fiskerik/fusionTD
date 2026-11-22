class_name StatusInfo
extends RefCounted

const ICONS: Dictionary = {
	"burn": "fire", "poison": "nature", "slow": "water", "freeze": "water",
	"root": "nature", "curse": "dark", "shred": "normal", "silence": "dark",
	"heal_block": "light", "phasing": "phasing",
	"disease": "dark", "slip": "water",
}
const TRAITS: Dictionary = {
	"swift": ["Swift", "Moves faster and has less health.", "electric"],
	"armored": ["Armored", "Armor reduces incoming hit damage.", "normal"],
	"swarm": ["Swarm", "Travels in larger groups with less health per enemy.", "nature"],
	"mender": ["Mender", "Heals nearby enemies on defeat.", "light"],
	"splitter": ["Splitter", "Spawns smaller enemies when defeated.", "nature"],
	"phasing": ["Phasing", "", "phasing"],
	"revenant": ["Revenant", "Revives once with partial health unless healing is blocked.", "dark"],
	"warlock": ["Hex", "Marks a tower, then temporarily stuns it.", "dark"],
	"ram": ["Corner charge", "Rushes along straights, bounces at each bend, then spends %s seconds pivoting.", "speed"],
	"necromancer": ["Raise husks", "Summons two husks every 10 seconds, up to four alive at once.", "dark"],
	"prismheart": ["Shapeshifter", "Cycles through your unlocked elements every %s seconds. Each form resists its own element and the element it counters.", "light"],
	"tempest": ["Airborne", "Flies over roots and ice puddles. Slows and freezes still work.", "water"],
	"ironwood": ["Elemental plating", "", "armor"],
	"heal_aura": ["Mending aura", "Periodically heals the Necromancer and nearby enemies.", "nature"],
	"boss_guard": ["Damage reduction", "Reduces damage from all sources, including damage over time.", "armor"],
	"resistance": ["Tenacity", "Weakens slows and shortens roots and freezes. The enemy can move briefly before it can be stopped again.", "normal"],
	"chameleon": ["Chameleon", "Adapts to the last element that damaged it. Neutral hits always work.", "nature"],
	"banner": ["Banner Bearer", "Nearby enemies move 20% faster. Banners do not stack.", "light"],
	"burrower": ["Burrower", "Burrows beneath two sections of the road and cannot be targeted underground.", "normal"],
	"thief": ["Thief", "Steals gold if it reaches the gate.", "gold"],
	"saboteur": ["Saboteur", "Jams the closest upgradeable tower mid-route. Upgrade or fuse the tower to repair it.", "electric"],
	"bonus": ["Unstoppable", "Immune to slowing, roots, and freezes. Reaches the gate in 12 seconds. Its gold reward is %s of all other enemies' combined bounty.", "gold"],
	"petrifier": ["Petrification", "Marks two random towers on arrival. They turn to stone through the next wave, including its Spirit trial.", "armor"],
	"wizard": ["Void step", "Stays at each stop for %s seconds, then disappears for %s seconds before appearing at the next corner. Cannot be hit in the void.", "dark"],
}
const ACCENTS: Dictionary = {
	"Burn": "#963c24", "Spreading": "#963c24", "Poison": "#436b26", "Root": "#436b26",
	"Slow": "#1d6288", "Freeze": "#345597", "Curse": "#72478a", "Silence": "#72478a",
	"Shred": "#845a2d", "Armor": "#845a2d", "Pierce": "#845a2d", "Chain": "#795d1b",
	"Splash": "#32627b", "Stun": "#806019", "Heal": "#806019",
	"Disease": "#6b437e", "Ice": "#205e8c", "Slip": "#205e8c", "Gate": "#39766b",
	"Pure": "#1d6288",
}

static func active(enemy: Dictionary, tick: int, hz: float) -> PackedStringArray:
	var result := PackedStringArray()
	for dot: String in ["burn", "poison"]:
		if enemy.dots.has(dot):
			result.append(dot)
	for status: String in ["slow", "freeze", "root", "curse", "shred", "silence", "heal_block"]:
		if int(enemy.get(status + "_time", 0)) > 0:
			result.append(status)
	if int(enemy.get("slip_time", 0)) > 0:
		result.append("slip")
	if int(enemy.get("disease", {}).get("time", 0)) > 0:
		result.append("disease")
	if EnemyRules.phased(enemy, tick, hz):
		result.append("phasing")
	return result

static func title(status: String) -> String:
	return DataDB.read("strings_en").statuses[status][0]

static func description(status: String) -> String:
	var value: String = DataDB.read("strings_en").statuses[status][1]
	if status == "phasing":
		var rule: Dictionary = DataDB.read("mobs").properties.phasing
		return value % [int(rule.duration), int(rule.cycle)]
	if status == "disease":
		return value % int(DataDB.read("balance").disease_lookback)
	return value

static func tooltip(statuses: PackedStringArray) -> String:
	var lines := PackedStringArray()
	for status: String in statuses:
		lines.append("%s · %s" % [title(status), description(status)])
	return "\n".join(lines)

static func accent(label: String) -> Color:
	return Color(ACCENTS.get(label.get_slice(" ", 0), "#387861"))

static func enemy_name(enemy: Dictionary) -> String:
	var specials: Dictionary = DataDB.read("mobs").specials
	for prop: String in enemy.props:
		if specials.has(prop):
			return TRAITS[prop][0]
	match enemy.kind:
		"boss": return DataDB.read("bosses")[enemy.boss_type].name
		"spirit": return "%s Spirit %s" % [String(enemy.element).capitalize(), TowerRules.roman(enemy.tier)]
		"splitling": return "Splitling"
		"husk": return "Husk"
		"bonus": return "Gilded Courier"
		"petrifier": return "Stonegaze Basilisk"
		"wizard": return "Void Wizard"
	return DataDB.read("mobs").families[enemy.family].name

static func enemy_traits(enemy: Dictionary) -> PackedStringArray:
	var result := PackedStringArray(enemy.props)
	if enemy.kind == "boss":
		var boss_trait: String = enemy.boss_type
		if enemy.get("heal_aura", false):
			boss_trait = "heal_aura"
		elif boss_trait == "ram" and not enemy.has("turn_seconds"):
			boss_trait = "armored"
		result.append(boss_trait)
		result.append("boss_guard")
	elif enemy.kind == "bonus":
		result.append("bonus")
	if float(enemy.get("control_resistance", 0.0)) > 0.0:
		result.append("resistance")
	return result

static func trait_title(id: String, enemy: Dictionary) -> String:
	if id == "resistance":
		return "%s tenacity" % TowerInspector.percent(float(enemy.control_resistance))
	if id == "boss_guard":
		return "%s damage reduction" % TowerInspector.percent(float(DataDB.read("bosses").damage_reduction))
	return TRAITS[id][0]

static func trait_description(id: String) -> String:
	if id == "ram":
		return String(TRAITS[id][1]) % TowerInspector.number(DataDB.read("bosses").ram.turn_seconds)
	if id == "prismheart":
		return String(TRAITS[id][1]) % TowerInspector.number(DataDB.read("bosses").prismheart.morph_seconds)
	if id == "ironwood":
		var plating: Dictionary = DataDB.read("bosses").ironwood
		return "Takes %s of elemental damage. Uninfused Arrow and Cannon towers deal %s damage." % [
			TowerInspector.percent(plating.elemental_damage), TowerInspector.percent(plating.neutral_damage)]
	if id == "bonus":
		return String(TRAITS[id][1]) % TowerInspector.percent(float(DataDB.read("waves").bonus_mob.gold_share))
	if id == "wizard":
		var wizard: Dictionary = DataDB.read("waves").wizard
		return String(TRAITS[id][1]) % [int(wizard.visible_seconds), int(wizard.void_seconds)]
	return description(id) if id == "phasing" else TRAITS[id][1]

static func state_value(enemy: Dictionary, id: String, tick: int, hz: float) -> String:
	match id:
		"slow", "curse":
			return TowerInspector.percent(enemy[id])
		"burn", "poison":
			var dot: Dictionary = enemy.dots[id]
			return "%d× · %s HP/s" % [dot.stacks, TowerInspector.number(float(dot.dps) * int(dot.stacks))]
		"disease":
			return "%s HP/s · %.1f s left" % [TowerInspector.number(Effects.disease_rate(enemy)), float(enemy.disease.time) / hz]
		"shred":
			return "−%s armor" % TowerInspector.number(enemy.shred)
		"phasing":
			var interval: Dictionary = DataDB.read("mobs").properties.phasing
			var age: int = tick - int(enemy.born)
			return "%.1f s" % (float(Effects.ticks(interval.duration, hz) - age % Effects.ticks(interval.cycle, hz)) / hz)
	return "%.1f s" % (float(enemy[id + "_time"]) / hz)

static func weakness_title(element: String) -> String:
	return "Weak to Neutral" if element == "normal" else "Weak to %s" % element.capitalize()

static func weakness_icon(element: String) -> String:
	return "damage" if element == "normal" else element

static func weakness_description(element: String, multiplier: float = Damage.WEAKNESS_MULTIPLIER) -> String:
	var source: String = "uninfused Arrow and Cannon towers" if element == "normal" else element.capitalize()
	return "Takes %s more damage from %s." % [TowerInspector.percent(multiplier - 1.0), source]

static func describe_enemy(enemy: Dictionary, tick: int, hz: float) -> String:
	var heading: String = enemy_name(enemy)
	if enemy.element != "none" and enemy.kind != "spirit":
		heading += "   ·   " + String(enemy.element).capitalize()
	var lines := PackedStringArray([heading])
	var weakness: String = Damage.weakness(enemy)
	if not weakness.is_empty():
		lines.append(weakness_description(weakness, Damage.weakness_multiplier(enemy)))
	var immune: String = enemy.get("immune_element", "")
	if not immune.is_empty() and int(enemy.get("silence_time", 0)) == 0:
		lines.append("Immune to " + immune.capitalize())
	if enemy.get("bannered", false):
		lines.append("Banner rally · +20% movement speed")
	for property_info: String in enemy_traits(enemy):
		lines.append("%s · %s" % [trait_title(property_info, enemy), trait_description(property_info)])
	for id: String in active(enemy, tick, hz):
		lines.append("%s · %s" % [title(id), description(id)])
	return "\n".join(lines)
