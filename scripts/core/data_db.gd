class_name DataDB
extends RefCounted

const ELEMENTS: Array[String] = ["fire", "water", "nature", "electric", "light", "dark"]
const TABLES: Array[String] = ["balance", "elements", "towers", "duals", "triples", "mobs", "spirits", "bosses", "waves", "map_greenmarch", "campaign_maps", "run_boons", "strings_en"]
static var tables: Dictionary = {}

static func read(key: String) -> Dictionary:
	if not tables.has(key):
		var file: String = "res://data/%s.json" % key
		var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
		assert(decoded is Dictionary, "Invalid data table: " + key)
		tables[key] = decoded
	return tables[key]

static func text(key: String) -> String:
	return String(read("strings_en").get(key, key))

static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for key: String in TABLES:
		if read(key).is_empty():
			errors.append("Empty data table: " + key)
	var elements: Dictionary = read("elements")
	var towers: Dictionary = read("towers")
	for element: String in ELEMENTS:
		if not elements.has(element) or not towers.has(element):
			errors.append("Missing element: " + element)
			continue
		if elements[element].effects.size() != 3 or not elements.has(elements[element].weak):
			errors.append("Invalid trait definition: " + element)
	_validate_recipes("duals", "pair", 2, 15, errors)
	_validate_recipes("triples", "elements", 3, 20, errors)
	for kind: String in ["arrow", "cannon"] + ELEMENTS:
		if float(towers[kind].cost) <= 0 or float(towers[kind].range) <= 0 or float(towers[kind].rate) <= 0:
			errors.append("Invalid tower stats: " + kind)
	return errors

static func _validate_recipes(table: String, ingredient_key: String, arity: int, expected: int, errors: PackedStringArray) -> void:
	var unique: Dictionary = {}
	for key: String in read(table):
		var rule: Dictionary = read(table)[key]
		var ingredients := PackedStringArray(rule[ingredient_key])
		ingredients.sort()
		var seen: Dictionary = {}
		for element: String in ingredients:
			if not ELEMENTS.has(element) or seen.has(element):
				errors.append("Invalid ingredient: " + key)
			seen[element] = true
		var signature: String = "-".join(ingredients)
		if unique.has(signature) or ingredients.size() != arity:
			errors.append("Invalid recipe: " + key)
		unique[signature] = true
		var weight: float = 0.0
		for element: String in rule.split:
			if not seen.has(element):
				errors.append("Invalid damage element: " + key)
			weight += float(rule.split[element])
		if not rule.split.is_empty() and not is_equal_approx(weight, 1.0):
			errors.append("Invalid damage weights: " + key)
	if unique.size() != expected:
		errors.append("Wrong recipe count: " + table)
