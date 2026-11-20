class_name Track
extends RefCounted

var points: PackedVector2Array
var slots: Dictionary = {}
var slot_by_tile: Dictionary = {}
var road_tiles: Dictionary = {}
var road_coverage: Dictionary = {}
var reference_slots: Array[String] = []
var lengths: PackedFloat64Array
var total: float = 0.0
var bounds: Vector2

func _init() -> void:
	var map: Dictionary = DataDB.read("map_greenmarch")
	bounds = Vector2(map.width, map.height)
	for raw: Array in map.path:
		var point := Vector2(raw[0], raw[1])
		if not points.is_empty():
			total += points[-1].distance_to(point)
		points.append(point)
		lengths.append(total)
	for index: int in range(map.slots.size()):
		var raw: Array = map.slots[index]
		var id: String = "s%d" % (index + 1)
		reference_slots.append(id)
		_add_slot(id, Vector2i(raw[0], raw[1]), int(raw[2]))
	for y: int in range(int(bounds.y)):
		for x: int in range(int(bounds.x)):
			var tile := Vector2i(x, y)
			var center := Vector2(tile) + Vector2(.5, .5)
			if _on_road(center):
				road_tiles[tile] = center
			elif not slot_by_tile.has(tile):
				_add_slot("tile_%d_%d" % [x, y], tile)

func reachable_road(slot: String, radius: float) -> Array:
	var key: String = "%s:%s" % [slot, radius]
	if not road_coverage.has(key):
		var origin: Vector2 = slots[slot].position
		var covered: Array[Vector2i] = []
		for tile: Vector2i in road_tiles:
			if origin.distance_squared_to(road_tiles[tile]) <= radius * radius:
				covered.append(tile)
		road_coverage[key] = covered
	return road_coverage[key]

func slot_at(position: Vector2) -> String:
	return slot_by_tile.get(Vector2i(position.floor()), "")

func _add_slot(id: String, tile: Vector2i, reference_wave: int = 0) -> void:
	slot_by_tile[tile] = id
	slots[id] = {"position": Vector2(tile) + Vector2(.5, .5), "order": slots.size(),
		"reference_wave": reference_wave}

func _on_road(center: Vector2) -> bool:
	for i: int in range(1, points.size()):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(center, points[i - 1], points[i])
		if center.distance_squared_to(closest) <= .25:
			return true
	return false

func at(distance: float) -> Vector2:
	var s: float = clampf(distance, 0.0, total)
	for index: int in range(1, points.size()):
		if s <= lengths[index]:
			return points[index - 1].lerp(points[index], (s - lengths[index - 1]) / (lengths[index] - lengths[index - 1]))
	return points[-1]
