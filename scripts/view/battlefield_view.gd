class_name BattlefieldView
extends Control

signal site_pressed(slot: String)
signal enemy_pressed(id: int)

var sim: Sim
var selected: String = ""
var partners: Array[String] = []
var move_targets: Dictionary = {}
var placement_preview: Dictionary = {}
var upgrade_ready: Dictionary = {}
var hover_kind: String = ""
var fraction: float = 0.0
var animation_paused: bool = false
var shake: float = 0.0
var elapsed: float = 0.0
var zoom: float = 1.0
var origin := Vector2.ZERO
var gate_on_top: bool = false:
	set(value):
		gate_on_top = value
		aiming_touch = false
		tap_ripple = 0.0
		_clear_hover()
		queue_redraw()
var canvas_transform := Transform2D.IDENTITY
var font: Font = ThemeDB.fallback_font
var shots: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var fusion_trails: Array[Dictionary] = []
var area_hits: Array[Dictionary] = []
var rewards: Array[Dictionary] = []
var aim_by_slot: Dictionary = {}
var hit_times: Dictionary = {}
var place_times: Dictionary = {}
var hover_slot: String = ""
var pointer_over_board: bool = false
var aiming_touch: bool = false
var tap_ripple: float = 0.0
var tap_point := Vector2.ZERO
var inspected_enemy: int = -1
var status_vfx := StatusVfx.new()

const MEADOW: Texture2D = preload("res://assets/woodland/greenmarch.webp")
const CASTLE_HORIZON: Texture2D = preload("res://assets/woodland/castle_horizon.webp")
const HORIZON_HEIGHT: float = 2.1
const PATH: Color = Color("#ecd0a5")
const GOLD: Color = Color("#f5c57c")
const REWARD: Color = Color("#ffdc64")
const WALKER: Color = Color("#ffc4a0")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_exited.connect(_clear_hover)

func _process(delta: float) -> void:
	if not animation_paused and sim != null:
		elapsed += delta
		tap_ripple = maxf(0, tap_ripple - delta)
		shake = maxf(0, shake - delta * 22)
		_age(shots, delta)
		_age(bursts, delta)
		_age(fusion_trails, delta)
		_age(area_hits, delta)
		_age(rewards, delta)
		for id: int in hit_times.keys():
			hit_times[id] = maxf(0, float(hit_times[id]) - delta)
			if float(hit_times[id]) == 0.0:
				hit_times.erase(id)
		for slot: String in place_times.keys():
			place_times[slot] = maxf(0, float(place_times[slot]) - delta)
			if float(place_times[slot]) == 0.0:
				place_times.erase(slot)
		_track_aim(delta)
		_update_status_vfx(delta)
	if pointer_over_board and sim != null and zoom > 1.0:
		_update_status_tooltip(_world_position(get_local_mouse_position()))
	queue_redraw()

func _age(effects: Array[Dictionary], delta: float) -> void:
	for i: int in range(effects.size() - 1, -1, -1):
		effects[i].time -= delta
		if float(effects[i].time) <= 0:
			effects.remove_at(i)

func _update_status_vfx(delta: float) -> void:
	status_vfx.advance(delta)
	for enemy: Dictionary in sim.state.mobs:
		var statuses: PackedStringArray = StatusInfo.active(enemy, sim.state.tick, sim.hz)
		if not statuses.is_empty():
			status_vfx.observe(enemy.id, _enemy_position(enemy), statuses)
	status_vfx.finish_frame()

func reset_animation() -> void:
	shots.clear()
	bursts.clear()
	fusion_trails.clear()
	area_hits.clear()
	rewards.clear()
	aim_by_slot.clear()
	hit_times.clear()
	place_times.clear()
	status_vfx.clear()
	fraction = 0
	aiming_touch = false
	tap_ripple = 0.0
	shake = 0
	animation_paused = false

func animate(event: Dictionary) -> void:
	var data: Dictionary = event.data
	match event.type:
		"tower_fired":
			_fire(data)
		"mob_killed":
			var point: Vector2 = sim.track.at(data.s)
			var tint: Color = Glyphs.hue(data.element) if data.element != "none" else WALKER
			var special: bool = data.kind in ["spirit", "boss"]
			bursts.append({"at": point, "color": tint, "time": .48, "max": .48, "radius": .7 if special else .28})
			if int(data.gold) > 0:
				rewards.append({"at": point, "time": 1.30, "max": 1.30, "gold": int(data.gold),
					"offset": float(rewards.size() % 3) * .12})
		"tower_placed":
			place_times[data.slot] = .30
			bursts.append({"at": sim.track.slots[data.slot].position, "color": GOLD, "time": .42, "max": .42, "radius": .60})
		"tower_upgraded", "infusion_changed":
			place_times[data.slot] = .30
			var element: String = data.get("element", "")
			bursts.append({"at": sim.track.slots[data.slot].position, "color": GOLD if element.is_empty() else Glyphs.hue(element),
				"time": .58, "max": .58, "radius": .66, "action": event.type, "element": element})
		"tower_moved":
			aim_by_slot.erase(data.from)
			place_times.erase(data.from)
			place_times[data.slot] = .30
			bursts.append({"at": sim.track.slots[data.slot].position, "color": Color("#a2e9e4"), "time": .50, "max": .50, "radius": .68})
		"fused":
			var destination: Vector2 = sim.track.slots[data.slot].position
			fusion_trails.append({"from": sim.track.slots[data.from].position, "to": destination,
				"elements": data.elements, "time": .78})
			place_times[data.slot] = .30
		"mob_leaked":
			shake = 5
			if int(data.absorbed) > 0:
				_gate_pulse(Color("#86ddff"))
		"gate_restored":
			_gate_pulse(Color("#86ddff") if int(data.barrier) > 0 else Color("#c3f094"))
		"boss_healed":
			bursts.append({"at": sim.track.at(data.s), "color": Color("#8ad8a6"),
				"time": .75, "max": .75, "radius": data.radius})
		"element_unlocked":
			if not bool(data.defeated):
				var gate: Vector2 = sim.track.at(sim.track.total)
				bursts.append({"at": gate, "color": Glyphs.hue(data.element), "time": .65, "max": .65, "radius": .8})
				if int(data.gold) > 0:
					rewards.append({"at": gate, "time": 1.30, "max": 1.30, "gold": int(data.gold), "offset": 0.0})

func _gate_pulse(color: Color) -> void:
	bursts.append({"at": sim.track.points[-1], "color": color, "time": .75, "max": .75, "radius": .94})

func _fire(data: Dictionary) -> void:
	var tower: Dictionary = sim.state.towers[data.slot]
	var center: Vector2 = sim.track.slots[data.slot].position
	var target: Vector2 = sim.track.at(data.s)
	var style: String = ProjectileArt.style(tower, String(data.style))
	var area_radius: float = float(data.get("area", 0.0))
	if data.primary and area_radius > 0.0 and style != "pulse":
		if area_hits.size() == 60:
			area_hits.pop_front()
		var delay: float = .26 if style == "shell" else 0.0
		area_hits.append({"at": target, "radius": area_radius, "core": data.get("core", 0.0), "time": .52 + delay,
			"ingredients": TowerRules.ingredients(tower)})
	var direction: Vector2 = (target - center).normalized()
	if data.primary and style != "pulse":
		var previous: Dictionary = aim_by_slot.get(data.slot, {})
		var start_angle: float = float(previous.angle) if previous.get("tower_id", -1) == tower.id else direction.angle()
		aim_by_slot[data.slot] = {
			"tower_id": tower.id, "target": data.target_id, "angle": start_angle,
			"point": target, "recoil": .18,
		}
	var source: Vector2 = center + direction * .36
	var duration: float = .22
	match style:
		"shell": duration = .40
		"chain":
			if not data.primary:
				source = sim.track.at(data.from_s)
			duration = .21
		"beam", "impact": duration = .16
		"flame": duration = .48
		"water": duration = .36
		"ember", "thorn", "shadow": duration = .30
		"pulse":
			source = center
			duration = .34
	var tint: Color = _tower_color(tower).lerp(Color.WHITE, .30)
	if tower.kind == "cannon" and tower.infusion == "":
		tint = Color("#ffbc69")
	var contact: float = .76
	match style:
		"impact", "beam", "chain", "pulse": contact = 0.0
		"flame", "water": contact = 1.0 / 4.2
		"shell": contact = .65
	if contact == 0.0:
		hit_times[int(data.target_id)] = .15
	shots.append({"from": source, "to": target, "style": style, "color": tint,
		"target_id": data.target_id, "contact": contact, "landed": contact == 0.0,
		"element": TowerRules.primary_element(tower), "time": duration, "max": duration,
		"range": float(TowerRules.stats(tower).range)})

func _track_aim(delta: float) -> void:
	if aim_by_slot.is_empty() and shots.is_empty():
		return
	var active: Dictionary = {}
	for enemy: Dictionary in sim.state.mobs:
		active[enemy.id] = enemy
	for shot: Dictionary in shots:
		if shot.landed:
			continue
		var victim: Dictionary = active.get(shot.target_id, {})
		if not victim.is_empty():
			shot.to = _enemy_position(victim)
		if 1.0 - float(shot.time) / float(shot.max) >= float(shot.contact):
			shot.landed = true
			if not victim.is_empty():
				hit_times[int(victim.id)] = .15
	for slot: String in aim_by_slot.keys():
		var aim: Dictionary = aim_by_slot[slot]
		var tower: Dictionary = sim.state.towers.get(slot, {})
		if tower.is_empty() or int(tower.id) != int(aim.tower_id):
			aim_by_slot.erase(slot)
			continue
		var enemy: Dictionary = active.get(aim.target, {})
		var base: Vector2 = sim.track.slots[slot].position
		if not enemy.is_empty() and int(tower.stun) == 0:
			var target: Vector2 = _enemy_position(enemy)
			if base.distance_to(_enemy_position(enemy, true)) <= TowerRules.attack_range(tower):
				aim.point = target
		var point: Vector2 = aim.point
		aim.angle = rotate_toward(float(aim.angle), (point - base).angle(), delta * 15.0)
		aim.recoil = maxf(0.0, float(aim.recoil) - delta)

func _gui_input(event: InputEvent) -> void:
	if sim == null or zoom <= 1.0 or animation_paused:
		aiming_touch = false
		return
	if event is InputEventMouseMotion:
		pointer_over_board = true
		var point: Vector2 = _world_position(event.position)
		hover_slot = sim.track.slot_at(point)
		_update_status_tooltip(point)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var world: Vector2 = _world_position(event.position)
		var inside: bool = Rect2(Vector2.ZERO, sim.track.bounds).has_point(world)
		if event.canceled:
			aiming_touch = false
		elif event.pressed:
			aiming_touch = inside
			hover_slot = sim.track.slot_at(world)
		elif aiming_touch:
			aiming_touch = false
			if inside:
				var slot: String = sim.track.slot_at(world)
				var enemy: Dictionary = _enemy_at(world, .48)
				tap_point = world
				tap_ripple = .34
				if not enemy.is_empty() and not sim.state.towers.has(slot) and partners.is_empty() and move_targets.is_empty():
					enemy_pressed.emit(int(enemy.id))
				else:
					site_pressed.emit(slot)
		accept_event()

func _world_position(pixel: Vector2) -> Vector2:
	return _board_transform().affine_inverse() * pixel

func _board_transform() -> Transform2D:
	var corner: Vector2 = origin + Vector2(sin(elapsed * 50) * shake, 0)
	if gate_on_top:
		return Transform2D(Vector2(-zoom, 0), Vector2(0, -zoom), corner + sim.track.bounds * zoom)
	return Transform2D(0, Vector2.ONE * zoom, 0, corner)

func _set_board_transform() -> void:
	canvas_transform = _board_transform()
	draw_set_transform_matrix(canvas_transform)

func _set_upright(anchor: Vector2) -> void:
	if gate_on_top:
		canvas_transform = Transform2D(0, Vector2.ONE * zoom, 0, _board_transform() * anchor - anchor * zoom)
		draw_set_transform_matrix(canvas_transform)

func _clear_hover() -> void:
	pointer_over_board = false
	hover_slot = ""
	tooltip_text = ""

func _update_status_tooltip(point: Vector2) -> void:
	var enemy: Dictionary = _enemy_at(point, .56)
	var text: String = "" if enemy.is_empty() else StatusInfo.describe_enemy(enemy, sim.state.tick, sim.hz)
	if tooltip_text != text:
		tooltip_text = text

func _enemy_at(point: Vector2, closest: float) -> Dictionary:
	var result: Dictionary = {}
	for enemy: Dictionary in sim.state.mobs:
		var distance: float = _enemy_position(enemy).distance_to(point)
		if distance < closest:
			closest = distance
			result = enemy
	return result

func _draw() -> void:
	if sim == null or size.x == 0 or size.y == 0:
		return
	var field_size: Vector2 = sim.track.bounds
	var horizon: float = HORIZON_HEIGHT if gate_on_top else 0.0
	var frame_size: Vector2 = field_size + Vector2(0, horizon)
	zoom = minf((size.x - 8) / frame_size.x, (size.y - 8) / frame_size.y)
	if zoom <= 1:
		return
	origin = (size - frame_size * zoom) * .5 + Vector2(0, horizon * zoom)
	if gate_on_top:
		_draw_castle_horizon(field_size)
	_set_board_transform()
	_draw_field(field_size)
	_draw_ice_puddles()
	status_vfx.draw_floor(self)
	_draw_area_hits()
	_draw_selection()
	if aiming_touch and not hover_slot.is_empty():
		var tile: Vector2 = sim.track.slots[hover_slot].position
		draw_rect(Rect2(tile - Vector2(.48,.48), Vector2(.96,.96)), Color("#fff4cd68"))
		_tile_outline(tile, Color("#fff3ae"), .44, .064)
	if sim.state.phase == "build" or sim.state.phase == "wave":
		_draw_build_tiles()
	if not placement_preview.is_empty() and move_targets.has(hover_slot) and (pointer_over_board or aiming_touch):
		_draw_placement_preview()
	for tower: Dictionary in sim.state.towers.values():
		_draw_tower(tower)
	for enemy: Dictionary in sim.state.mobs:
		if int(enemy.id) == inspected_enemy:
			var focus: Vector2 = _enemy_position(enemy)
			draw_arc(focus, .43, 0, TAU, 30, Color("#fff7cc"), .09, true)
			draw_arc(focus, .49, 0, TAU, 30, Color("#456452"), .045, true)
		if enemy.kind == "boss" and not enemy.telegraph.is_empty():
			var site: Vector2 = sim.track.slots[enemy.telegraph.slot].position
			draw_arc(site, .4 + absf(sin(elapsed * 14)) * .12, 0, TAU, 32, Color("#ff8d70"), .065, false)
			var caster: Vector2 = _enemy_position(enemy)
			draw_line(caster, site, Color("#b95a82", .48 + sin(elapsed * 17) * .18), .06)
			Glyphs.draw(self, "dark", site - Vector2(0,.51), .17, Color("#ad3479"))
		_draw_enemy(enemy)
	for shot: Dictionary in shots:
		_draw_shot(shot)
	for trail: Dictionary in fusion_trails:
		_draw_fusion(trail)
	for burst: Dictionary in bursts:
		_draw_burst(burst)
	status_vfx.draw_bursts(self)
	if tap_ripple > 0.0:
		var fade: float = tap_ripple / .34
		draw_arc(tap_point, .14 + (1.0 - fade * fade) * .39, 0, TAU, 28, Color("#fffbd4", fade), .045, true)
	_draw_gate_health()
	for reward: Dictionary in rewards:
		_draw_reward(reward)
	draw_set_transform(Vector2.ZERO)

func _draw_castle_horizon(bounds: Vector2) -> void:
	_set_upright(Vector2(bounds.x * .5, bounds.y))
	var sky := Rect2(0, bounds.y - HORIZON_HEIGHT, bounds.x, HORIZON_HEIGHT)
	draw_rect(sky.grow(.055), Color("#ded3aa"))
	draw_texture_rect(CASTLE_HORIZON, sky, false)
	draw_rect(sky, Color("#8eaa83"), false, .035)

func _draw_field(bounds: Vector2) -> void:
	var board := Rect2(Vector2.ZERO, bounds)
	draw_rect(Rect2(board.position + Vector2(0,.07), bounds).grow(.065), Color("#637651"))
	draw_rect(board.grow(.055), Color("#ded3aa"))
	draw_texture_rect(MEADOW, board, false)
	var grid_alpha: float = .32 if sim.state.phase == "build" or aiming_touch or not selected.is_empty() else .16
	var ink := Color("#476546", grid_alpha)
	for x: int in range(1, int(bounds.x)):
		draw_line(Vector2(x, 0), Vector2(x, bounds.y), ink, .018)
	for y: int in range(1, int(bounds.y)):
		draw_line(Vector2(0, y), Vector2(bounds.x, y), ink, .018)
	var track: Track = sim.track
	var road_points := PackedVector2Array(track.points)
	road_points[0] = track.at(.90)
	_road(road_points, .94, Color("#a4af83"))
	_road(road_points, .84, Color("#fff0c9"))
	_road(road_points, .73, PATH)
	for index: int in range(1, floori(track.total * 2.0)):
		var pos: Vector2 = track.at(index * .5)
		if pos.x < .32:
			continue
		var direction: Vector2 = (track.at(index * .5 + .035) - pos).normalized()
		var side := direction.orthogonal()
		var pebble: Vector2 = pos + side * (.19 if index % 3 == 0 else -.24)
		draw_circle(pebble, .037 + (index % 3) * .008, Color("#be9c71"), true, -1, true)
		draw_line(pebble - direction * .018, pebble + direction * .012, Color("#ffe8bb"), .021)
		if index % 8 == 5:
			draw_polyline(PackedVector2Array([pos - side * .10 - direction * .07,
				pos + direction * .05, pos + side * .10 - direction * .07]), Color("#bc9371"), .040)
	var entrance: Vector2 = track.at(.9)
	_set_upright(entrance)
	TowerArt.draw_landmark(self, "portal", entrance - Vector2(0, .04), Vector2(1.20, 1.20))
	draw_arc(entrance + Vector2(0,.035), .18, elapsed, elapsed + PI * 1.5, 20, Color("#f8ffe1", .8), .027, true)
	var gate: Vector2 = track.points[-1]
	_set_board_transform()
	_set_upright(gate)
	_draw_gate(gate)
	_set_board_transform()
	draw_rect(board, Color("#8eaa83"), false, .035)
	_draw_pollen()

func _draw_pollen() -> void:
	for i: int in range(14):
		var phase: float = elapsed * (.35 + (i % 4) * .064) + i * 1.73
		var x: float = .38 + (i * 23 % 82) * .10
		var y: float = .28 + (i * 37 % 112) * .10
		var p := Vector2(x + sin(phase) * .22, y + cos(phase * .62) * .19)
		draw_circle(p, .026 + .009 * sin(phase), Color("#fff9d1", .22 + .16 * sin(phase + .5)))

func _draw_gate(p: Vector2) -> void:
	TowerArt.draw_landmark(self, "gate", p, Vector2(1.66, 1.48) if gate_on_top else Vector2(1.42, 1.13))
	if int(sim.state.barrier) > 0:
		var field_shield: PackedVector2Array = PackedVector2Array([p + Vector2(-.64,.14), p + Vector2(-.63,-.31),
			p + Vector2(-.29,-.61), p + Vector2(.29,-.61), p + Vector2(.63,-.31), p + Vector2(.64,.14)])
		draw_colored_polygon(field_shield, Color("#94efff", .25 + .10 * sin(elapsed * 3.0)))
		draw_polyline(field_shield, Color("#9de4ff"), .075)
		draw_line(p + Vector2(-.48,-.24), p + Vector2(.48,-.24), Color("#e6fcff", .71), .039)

func _draw_gate_health() -> void:
	var gate: Vector2 = sim.track.points[-1]
	_set_upright(gate)
	if gate_on_top:
		gate.y -= .15
	var max_lives: int = sim.cfg.start_lives
	var lives: int = sim.state.lives
	var ratio: float = clampf(float(lives) / max_lives, 0.0, 1.0)
	var barrier: int = sim.state.barrier
	var plate := Rect2(gate + Vector2(-1.25, -1.06), Vector2(2.50, .55))
	draw_rect(plate.grow(.024), Color("#f7efd3"))
	draw_rect(plate, Color("#354e43"))
	var bar := Rect2(plate.position + Vector2(.11, .35), Vector2(2.28 if barrier == 0 else 1.27, .13))
	draw_rect(bar, Color("#773d40"))
	bar.size.x *= ratio
	if bar.size.x > 0.0:
		draw_rect(bar, UIKit.gate_fill(ratio))
	var text: String = DataDB.text("gate_meter") % [lives, max_lives]
	if barrier > 0:
		var shield := Rect2(plate.position + Vector2(1.47, .35), Vector2(.92, .13))
		draw_rect(shield, Color("#3d6e83"))
		shield.size.x *= float(barrier) / int(sim.cfg.gate_barrier_cap)
		draw_rect(shield, Color("#86ddff"))
		text += "  +%d" % barrier
	_caption(text, gate + Vector2(0,-.78), .23, Color("#fffbe5"))
	_set_board_transform()

func _draw_ice_puddles() -> void:
	for tile: Vector2i in sim.ice_tiles():
		var p: Vector2 = sim.track.road_tiles[tile]
		var rim: PackedVector2Array = PackedVector2Array([
			p + Vector2(-.46, -.18), p + Vector2(-.22, -.34), p + Vector2(.24, -.31),
			p + Vector2(.46, -.15), p + Vector2(.38, .22), p + Vector2(.08, .33),
			p + Vector2(-.36, .25), p + Vector2(-.46, -.18)])
		draw_colored_polygon(rim, Color("#9ae0f2a6"))
		draw_polyline(rim, Color("#559ab5"), .029)
		for offset: Vector2 in [Vector2(-.24,-.11), Vector2(.04,.13), Vector2(.12,-.18)]:
			draw_line(p + offset, p + offset + Vector2(.19,-.075), Color("#e4faff", .85), .024)
		var glimmer: float = maxf(0.0, sin(elapsed * 3.0 + float(tile.x - tile.y) * 1.63))
		var star: Vector2 = p + Vector2(.24,-.10)
		draw_line(star - Vector2(.08,0), star + Vector2(.08,0), Color("#fff", glimmer), .025)
		draw_line(star - Vector2(0,.08), star + Vector2(0,.08), Color("#fff", glimmer), .025)

func _road(points: PackedVector2Array, width: float, color: Color) -> void:
	draw_polyline(points, color, width, false)
	for point: Vector2 in points:
		draw_circle(point, width * .5, color, true, -1, false)

func _draw_selection() -> void:
	if selected == "":
		return
	var p: Vector2 = sim.track.slots[selected].position
	var source: Vector2 = p
	if move_targets.has(hover_slot):
		p = sim.track.slots[hover_slot].position
	var tower: Dictionary = sim.state.towers.get(selected, {})
	var tint: Color = _tower_color(tower) if not tower.is_empty() else Color("#338477")
	var radius: float = 0
	if not tower.is_empty():
		radius = TowerRules.attack_range(tower)
		if TowerRules.is_fusion(tower):
			var effect: Dictionary = TowerRules.stats(tower).effect
			if effect.has("aura_speed") or effect.has("aura_damage"):
				_draw_aura_tiles(tower, p, radius, tint)
	elif hover_kind != "":
		var rule: Dictionary = DataDB.read("towers")[hover_kind]
		radius = INF if rule.get("global_range", false) else float(rule.range)
	if is_inf(radius):
		var field_rect := Rect2(Vector2.ZERO, sim.track.bounds).grow(-.045)
		draw_rect(field_rect, Color("#fff1b6", .18))
		draw_rect(field_rect, Color("#c89841"), false, .085)
	elif radius > 0:
		draw_circle(p, radius, Color(tint, .14))
		draw_arc(p, radius, 0, TAU, 64, Color(tint, .65), .038)
	_tile_outline(p, Color("#fff5c7"), .43, .065)
	if source != p:
		_tile_outline(source, Color("#ffd287"), .43, .065)

func _draw_aura_tiles(source: Dictionary, origin: Vector2, radius: float, tint: Color) -> void:
	for slot: String in sim.track.slots:
		if slot == source.slot or sim.state.towers.get(slot, {}).get("dual", "") == source.dual:
			continue
		var point: Vector2 = sim.track.slots[slot].position
		if not TowerRules.aura_reaches_tile(origin, point, radius):
			continue
		var glow: float = .55 + .30 * sin(elapsed * 5.0 - origin.distance_to(point) * 2.0)
		draw_rect(Rect2(point - Vector2(.455, .455), Vector2(.91, .91)), Color(tint.lightened(.31), glow * .46))
		_tile_outline(point, Color("#eaffc7", glow + .12), .43, .051)
		var a: Vector2 = point + Vector2(-.26, .32)
		draw_polyline(PackedVector2Array([a + Vector2(-.09, .035), a - Vector2(0, .055), a + Vector2(.09, .035)]),
			Color("#4b896c", glow + .15), .037)
	var phase: float = fposmod(elapsed * .72, 1.0)
	draw_arc(origin, lerpf(.15, radius, phase), 0, TAU, 56, Color("#e9ffcc", .70 * (1.0 - phase)), .062)

func _draw_build_tiles() -> void:
	var building: bool = sim.state.phase == "build"
	for id: String in sim.track.slots:
		if sim.state.towers.has(id):
			continue
		var p: Vector2 = sim.track.slots[id].position
		if move_targets.has(id):
			draw_rect(Rect2(p - Vector2(.45, .45), Vector2(.90, .90)), Color("#91e8dd", .18))
			_tile_outline(p, Color("#ebfff4") if hover_slot == id else Color("#478d83"), .43, .039)
			continue
		var focus: bool = id == hover_slot or id == selected
		if not building and not focus:
			continue
		var color: Color = Color("#fcfbd3") if focus else Color("#739d7c")
		if focus:
			draw_circle(p, .28, Color("#64a68a"))
			_tile_outline(p, color, .43, .04)
			draw_line(p - Vector2(.105, 0), p + Vector2(.105, 0), color, .04)
			draw_line(p - Vector2(0, .105), p + Vector2(0, .105), color, .04)

func _draw_placement_preview() -> void:
	var p: Vector2 = sim.track.slots[hover_slot].position
	var radius: float = TowerRules.attack_range(placement_preview)
	var color: Color = _tower_color(placement_preview)
	if is_inf(radius):
		draw_rect(Rect2(Vector2.ZERO, sim.track.bounds).grow(-.04), Color(color, .65), false, .08)
	else:
		draw_circle(p, radius, Color(color, .12))
		draw_arc(p, radius, 0, TAU, 72, Color(color, .72), .04, true)
	_tile_outline(p, Color("#fff5bb"), .45, .065)
	_set_upright(p)
	_draw_foundation(p, 1, color.lightened(.35), color.darkened(.22))
	var head := p - Vector2(0, .11 + sin(elapsed * 4.0) * .025)
	if placement_preview.kind in ["arrow", "cannon"]:
		_draw_launcher(head, Vector2.UP, color, placement_preview.kind == "cannon")
	else:
		TowerArt.draw(self, placement_preview, head, .50 if placement_preview.kind == "ascended" else .42, elapsed)
	_set_board_transform()

func _tile_outline(p: Vector2, color: Color, radius: float, width: float) -> void:
	for sign_x: float in [-1., 1.]:
		for sign_y: float in [-1., 1.]:
			var corner: Vector2 = p + Vector2(sign_x, sign_y) * radius
			draw_polyline(PackedVector2Array([corner - Vector2(sign_x * .19, 0), corner,
				corner - Vector2(0, sign_y * .19)]), color, width)

func _draw_tower(tower: Dictionary) -> void:
	var p: Vector2 = sim.track.slots[tower.slot].position
	_set_upright(p)
	var tint: Color = _tower_color(tower)
	var ascended: bool = tower.kind == "ascended"
	var level: int = 6 if ascended else int(tower.level)
	var placement: float = float(place_times.get(tower.slot, 0.0)) / .30
	if placement > 0.0:
		p.y -= sin(placement * PI) * placement * .24
	var aim: Dictionary = aim_by_slot.get(tower.slot, {})
	var direction := Vector2.from_angle(float(aim.get("angle", -PI * .5)))
	if gate_on_top and not aim.is_empty():
		direction = -direction
	var recoil: float = float(aim.get("recoil", 0.0)) / .18
	var color: Color = tint.lightened(.14)
	var rim: Color = tint.darkened(.32)
	if tower.element == "normal" and tower.infusion == "":
		color = tint.lerp(Color("#f3e9b6"), .39)
		rim = Color("#628879")
	_draw_foundation(p, level, color, rim)
	if ascended:
		draw_arc(p, .515, 0, TAU, 35, Color("#fff1a7"), .057)
	var head: Vector2 = p - Vector2(0, .045 + float(level - 1) * .012)
	if tower.kind in ["arrow", "cannon"]:
		_draw_launcher(head - direction * recoil * .10, direction, color, tower.kind == "cannon")
	else:
		if not aim.is_empty():
			var tip: Vector2 = head + direction * (.39 - recoil * .08)
			draw_line(head, tip, rim, .14)
			draw_circle(tip, .064 + .04 * recoil, Color("#fff9d7"))
		var crown: Vector2 = head - Vector2(0,.065) - direction * recoil * .085
		TowerArt.draw(self, tower, crown, .51 if ascended else .40 + minf(.085, level * .017), elapsed)
		if recoil > .0:
			var spark: Vector2 = head + direction * .35
			draw_circle(spark, .08 + .10 * recoil, Color(tint, .48 * recoil))
			draw_circle(spark, .075 * recoil, Color("#fff7cf"))
	if tower.infusion != "":
		draw_arc(p, .43, 0, TAU, 28, tint, .062)
		var emblem: Vector2 = p + Vector2(-.27, .24)
		draw_circle(emblem, .115, rim)
		Glyphs.draw(self, tower.infusion, emblem, .075, tint.lightened(.37))
	var badge: Vector2 = p + Vector2(.27, .28)
	draw_circle(badge, .126, Color("#506658"))
	var badge_fill: Color = REWARD if level >= 4 else Color("#fcf0d2")
	if int(tower.get("crystals", 0)) > 0:
		badge_fill = Color("#acf0ff")
	draw_circle(badge - Vector2(0,.013), .096, badge_fill)
	_caption("◆" if ascended else str(level), badge + Vector2(0,.059), .17, Color("#493e32"))
	if upgrade_ready.has(tower.slot):
		var marker: Vector2 = p + Vector2(-.31, -.27)
		draw_circle(marker, .132, Color("#f5ffce"), true, -1, true)
		draw_circle(marker, .109, Color("#27684d"), true, -1, true)
		draw_polyline(PackedVector2Array([marker + Vector2(-.062, .027), marker - Vector2(0, .039),
			marker + Vector2(.062, .027)]), Color("#e0ff9a"), .038, true)
	if partners.has(tower.slot):
		draw_arc(p, .49 + sin(elapsed * 7) * .045, 0, TAU, 27, Color("#fff1a0"), .065)
	if int(tower.stun) > 0:
		Glyphs.draw(self, "electric", p + Vector2(.30, -.30), .19, Color("#aa64c6"))
	_set_board_transform()

func _draw_foundation(p: Vector2, level: int, color: Color, rim: Color) -> void:
	var top: Vector2 = p - Vector2(0,.055 + (level - 1) * .013)
	draw_circle(p + Vector2(.04,.095), .415, Color("#85956d"))
	if level == 1:
		draw_circle(p, .387, rim)
		draw_circle(top, .342, color)
	elif level <= 3:
		_draw_polygon_base(p, .415, 8 if level == 2 else 6, PI / 8, rim)
		_draw_polygon_base(top, .355, 8 if level == 2 else 6, PI / 8, color)
		if level == 3:
			_draw_corner_caps(p, .305, .075, color.lightened(.32), rim)
	else:
		_draw_polygon_base(p, .437, 8, PI / 8, rim.darkened(.18))
		_draw_polygon_base(top, .376, 8, PI / 8, color)
		_draw_corner_caps(p, .31, .10, Color("#e6ae58"), rim.darkened(.14))
		if level >= 5:
			draw_arc(top, .302, 0, TAU, 28, Color("#fbe29b"), .045)
			for side: float in [-1., 1.]:
				var fin: Vector2 = top + Vector2(side * .368, -.075)
				_draw_polygon_base(fin, .136, 4, 0, rim)
				_draw_polygon_base(fin, .085, 4, 0, color.lightened(.38))
		if level == 6:
			draw_arc(top, .433, -.8 + elapsed * .8, 3.8 + elapsed * .8, 24, Color("#fff2a9"), .045)
			for side: float in [-1., 1.]:
				var crest: Vector2 = top + Vector2(side * .19, -.35)
				_draw_polygon_base(crest, .11, 4, 0, Color("#a26a44"))
				_draw_polygon_base(crest, .069, 4, 0, Color("#ffdc76"))
	draw_arc(top, .29, -PI * .94, -.66, 13, color.lightened(.42), .039)

func _draw_polygon_base(p: Vector2, r: float, sides: int, tilt: float, color: Color) -> void:
	var points := PackedVector2Array()
	for side: int in range(sides):
		points.append(p + Vector2.from_angle(tilt + TAU * side / sides) * r)
	draw_colored_polygon(points, color)

func _draw_corner_caps(p: Vector2, spread: float, cap: float, color: Color, rim: Color) -> void:
	for i: int in range(4):
		var corner: Vector2 = p + Vector2.from_angle(PI * .25 + TAU * i / 4.0) * spread
		draw_circle(corner, cap, rim)
		draw_circle(corner - Vector2(0,.025), cap * .68, color)

func _draw_launcher(p: Vector2, aim: Vector2, tint: Color, cannon: bool) -> void:
	var side: Vector2 = aim.orthogonal()
	var dark: Color = Color("#3b514b")
	var muzzle: Vector2 = p + aim * .37
	draw_circle(p, .19, dark)
	draw_circle(p - Vector2(0, .025), .135, tint.lightened(.16))
	if cannon:
		draw_line(p, muzzle, dark, .238)
		draw_line(p + aim * .035 - side * .055, muzzle - side * .055, Color("#89978e"), .055)
		draw_circle(muzzle, .12, dark)
		draw_circle(muzzle, .056, Color("#fbd9a0"))
	else:
		draw_line(p, muzzle, dark, .106)
		var bow: Vector2 = p + aim * .18
		draw_polyline(PackedVector2Array([p + side * .205, bow + side * .105, bow - side * .105,
			p - side * .205]), Color("#79553d"), .076)
		draw_line(p + side * .20, p - side * .20, Color("#fff0bf"), .027)
		draw_circle(muzzle, .063, Color("#ffedba"))

func _enemy_position(enemy: Dictionary, ground_only: bool = false) -> Vector2:
	var distance: float = lerpf(enemy.prev_s, enemy.s, fraction)
	var p: Vector2 = sim.track.at(distance)
	if enemy.kind in ["splitling", "husk"] or enemy.props.has("swarm"):
		var side: Vector2 = _travel_direction(distance).orthogonal()
		p += side * (float(int(enemy.id) % 3) - 1.0) * .15
	if not ground_only and EnemyRules.airborne(enemy):
		p.y += _flight_height() * (1.0 if gate_on_top else -1.0)
	return p

func _flight_height() -> float:
	return .32 + .075 * sin(elapsed * 8.0)

func _travel_direction(distance: float) -> Vector2:
	var direction: Vector2 = sim.track.at(distance + .065) - sim.track.at(distance - .065)
	return direction.normalized()

func _draw_enemy(enemy: Dictionary) -> void:
	var p: Vector2 = _enemy_position(enemy, true)
	_set_upright(p)
	var distance: float = lerpf(enemy.prev_s, enemy.s, fraction)
	var direction: Vector2 = _travel_direction(distance)
	if enemy.has("turn_seconds"):
		direction = (sim.track.at(distance + .002) - sim.track.at(distance)).normalized()
	var turn: float = -1.0
	if enemy.has("corner"):
		var corner: int = enemy.corner
		var turn_ticks: float = Effects.ticks(enemy.turn_seconds, sim.hz)
		turn = clampf(1.0 - (float(enemy.turn_left) - fraction) / turn_ticks, 0.0, 1.0)
		var from: Vector2 = sim.track.points[corner] - sim.track.points[corner - 1]
		var to: Vector2 = sim.track.points[corner + 1] - sim.track.points[corner]
		direction = from.normalized().rotated(from.angle_to(to) * smoothstep(.12, 1.0, turn))
	if gate_on_top:
		direction = -direction
	var spirit: bool = enemy.kind == "spirit"
	var boss: bool = enemy.kind == "boss"
	var prismheart: bool = enemy.boss_type == "prismheart"
	var bonus: bool = enemy.kind == "bonus"
	var radius: float = .31
	if spirit:
		radius = spirit_radius(enemy.tier)
	elif boss:
		radius = .475
	elif enemy.kind in ["splitling", "husk"] or enemy.props.has("swarm"):
		radius = .205
	var variant: Dictionary = DataDB.read("mobs").families.get(enemy.get("family", "acorn"), {})
	var tint: Color = Color(variant.get("color", "#ecc393"))
	if enemy.element != "none":
		tint = Glyphs.hue(enemy.element)
	elif boss:
		tint = Color("#ed89a2")
	else:
		match int(enemy.get("season", 0)):
			1: tint = tint.lerp(Color("#d2c0ed"), .30)
			2: tint = tint.lerp(Color("#f4a87f"), .40)
	var impact: float = float(hit_times.get(int(enemy.id), 0.0)) / .15
	tint = tint.lerp(Color("#fffcef"), impact * .62)
	var shielded: bool = EnemyRules.phased(enemy, sim.state.tick, sim.hz)
	if shielded:
		draw_circle(p, radius + .10, Color("#9bdcff", .48))
		tint = tint.lerp(Color("#d2effe"), .36)
	if bonus:
		draw_arc(p, .36, 0, TAU, 24, Color("#ffe584"), .05, true)
		for index: int in range(3):
			var sparkle: Vector2 = p - direction * (.21 + index * .15)
			var offset: float = sin(elapsed * 13.0 + index * 2.2) * .15
			draw_circle(sparkle + direction.orthogonal() * offset, .051 - index * .009, Color("#fff1a1"), true, -1, true)
	var airborne: bool = EnemyRules.airborne(enemy)
	_draw_oval(p + Vector2(.035, radius * .53), Vector2(radius, radius * .42), Color("#614f42", .23 if airborne or prismheart else .34))
	_draw_status_ground(enemy, p, direction, radius)
	var previous_form: String = ""
	var morph_progress: float = 1.0
	if enemy.boss_type == "ram" and enemy.has("turn_seconds"):
		if turn >= 0.0:
			var impact_age: float = turn * float(enemy.turn_seconds)
			if impact_age < .42:
				draw_arc(p, radius * (1.0 + impact_age * 3.8), 0, TAU, 25,
					Color("#b97842", 1.0 - impact_age / .42), .054, true)
			draw_arc(p, radius * 1.49, -PI / 2.0, -PI / 2.0 + TAU * maxf(turn, .025), 28, Color("#ffda82"), .056, true)
			p -= direction * .22 * sin(PI * clampf(impact_age / .34, 0.0, 1.0))
		elif float(enemy.s) > float(enemy.prev_s):
			for i: int in range(3):
				var edge: Vector2 = p - direction * (radius + .12 * i)
				edge += direction.orthogonal() * (float(i) - 1.0) * .22
				draw_line(edge, edge - direction * (.24 + float(i) * .07), Color("#bd8956", .65), .055, true)
	elif prismheart and enemy.get("forms", PackedStringArray()).size() > 1:
		var period: int = EnemyRules.morph_period(sim.hz)
		var age: int = int(sim.state.tick) - int(enemy.born)
		var cycle: float = fposmod(float(age) + fraction, float(period)) / period
		if cycle > .82:
			var next: String = enemy.forms[(age / period + 1) % enemy.forms.size()]
			draw_arc(p, radius * 1.70, -PI / 2.0, -PI / 2.0 + TAU * (cycle - .82) / .18, 28,
				Glyphs.hue(next).lightened(.30), .065, true)
		elif age >= period and cycle < .08:
			previous_form = enemy.forms[(age / period - 1) % enemy.forms.size()]
			morph_progress = cycle / .08
			var shard_color := Color(Glyphs.hue(enemy.element).lightened(.42), 1.0 - morph_progress)
			for index: int in range(6):
				var angle: float = float(index) * TAU / 6.0 + morph_progress * .24
				var shard: Vector2 = p + Vector2.from_angle(angle) * radius * lerpf(.72, 2.05, morph_progress)
				_draw_polygon_base(shard, radius * lerpf(.20, .08, morph_progress), 4, angle, shard_color)
	if airborne:
		p.y -= _flight_height()
	if spirit:
		p.y -= .08 + sin(elapsed * 5.5) * .065
		_draw_spirit(p, direction, radius, tint, enemy.element, enemy.tier)
	elif prismheart:
		MobArt.draw_prismheart(self, enemy.element, p - direction * impact * .045, radius, elapsed, previous_form, morph_progress)
	else:
		MobArt.draw(self, enemy, p, direction, radius, tint, distance, elapsed, impact)
	_draw_status_glints(enemy, p, radius)
	if shielded:
		var shield_radius: float = radius + .10
		draw_arc(p, shield_radius, 0.0, TAU, 29, Color("#2d759a"), .052)
		draw_arc(p, shield_radius + .025, elapsed * 4.8, elapsed * 4.8 + PI * .83, 14, Color("#f0fdff"), .057)
		for i: int in range(4):
			var shield_spark: Vector2 = p + Vector2.from_angle(elapsed * 2.2 + TAU * i / 4.0) * (shield_radius + .045)
			_draw_polygon_base(shield_spark, .057, 4, elapsed * 3.0, Color("#d9f8ff"))
	var bar_lift: float = .17 if prismheart else (.10 if boss else 0.0)
	_draw_health(enemy, p - Vector2(0, bar_lift), radius)
	if enemy.element != "none" and not spirit:
		var flag: Vector2 = p + Vector2(-radius * (1.43 if boss else 1.0) - .045, -radius * .70)
		var element_color: Color = Glyphs.hue(enemy.element)
		draw_circle(flag, .125, element_color.darkened(.58))
		draw_circle(flag, .101, element_color.lightened(.32))
		Glyphs.draw(self, enemy.element, flag, .074, element_color.darkened(.63))
	elif enemy.boss_type == "ironwood":
		var flag: Vector2 = p + Vector2(-radius * 1.43 - .045, -radius * .70)
		draw_circle(flag, .13, Color("#433626"), true, -1, true)
		draw_circle(flag, .102, Color("#f5cf83"), true, -1, true)
		Glyphs.draw(self, "damage", flag, .075, Color("#493428"))
	_draw_status_icons(enemy, p, radius)
	if not enemy.props.is_empty():
		var badges: String = ""
		for prop: String in enemy.props:
			badges += DataDB.read("mobs").properties[prop].badge
		_caption(badges, p + Vector2(radius + .13, .15), .19, Color("#fff7e2"), Color("#65534c"))
	_set_board_transform()

func _draw_status_icons(enemy: Dictionary, p: Vector2, radius: float) -> void:
	var statuses: PackedStringArray = StatusInfo.active(enemy, sim.state.tick, sim.hz)
	for index: int in range(statuses.size()):
		var icon: String = StatusInfo.ICONS[statuses[index]]
		var point: Vector2 = p + Vector2((index - (statuses.size() - 1) * .5) * .18, radius + .10)
		var tint: Color = Glyphs.hue(icon)
		draw_circle(point, .090, tint.darkened(.56))
		draw_circle(point, .071, tint.lightened(.25))
		Glyphs.draw(self, icon, point, .055, tint.darkened(.59))

static func spirit_radius(tier: int) -> float:
	return [.29, .42, .54][clampi(tier - 1, 0, 2)]

func _draw_spirit(p: Vector2, direction: Vector2, r: float, tint: Color, element: String, tier: int) -> void:
	var ink: Color = tint.darkened(.55)
	var side: Vector2 = direction.orthogonal()
	var pulse: float = (sin(elapsed * 6.0) + 1) * .5
	var wing_reach: float = r * (1.08 + absf(sin(elapsed * 19)) * .66)
	draw_circle(p, r * (1.31 + pulse * .13), Color(tint, .35))
	for wing: float in [-1., 1.]:
		var base: Vector2 = p + side * wing * r * .20
		var tip: Vector2 = p + side * wing * wing_reach + direction * r * .61
		var crescent: Vector2 = p + side * wing * wing_reach * .75 - direction * r * .47
		draw_colored_polygon(PackedVector2Array([base, base + direction * r * .45, tip, crescent]), Color(tint.lightened(.55), .88))
		draw_polyline(PackedVector2Array([base, tip, crescent]), Color(tint.darkened(.16), .62), .048)
		if tier >= 2:
			draw_colored_polygon(PackedVector2Array([base, crescent - direction * r * .55,
				p - direction * r * .92 + side * wing * r * .55]), Color(tint, .78))
	if tier >= 2:
		for i: int in range(tier + 1):
			var axis := Vector2.from_angle(elapsed * (1.9 if tier == 2 else -2.05) + TAU * i / float(tier + 1))
			var mote: Vector2 = p + axis * r * 1.43
			draw_circle(mote, .086, Color(tint, .38))
			draw_circle(mote, .045, Color("#fffde0"))
	if tier == 3:
		_draw_spirit_crown(p, direction, r, tint, element)
	draw_circle(p, r * .82, ink)
	draw_circle(p - Vector2(0,.035), r * .72, tint)
	draw_circle(p - Vector2(.03,.055), r * .50, tint.lightened(.57))
	Glyphs.draw(self, element, p - Vector2(0,.034), r * .43, ink)
	var tag: Vector2 = p + Vector2(r * .77, r * .64)
	draw_circle(tag, r * .30 + .034, ink)
	_caption(TowerRules.roman(tier), tag + Vector2(0, .055), .17 if tier < 3 else .21, Color("#fff3c9"))

func _draw_spirit_crown(p: Vector2, direction: Vector2, r: float, tint: Color, element: String) -> void:
	var angle: float = direction.angle()
	draw_arc(p, r * 1.10, angle + .51, angle + TAU - .51, 34, tint.darkened(.36), .081)
	var dark: Color = tint.darkened(.39)
	match element:
		"fire":
			for i: int in range(4):
				var flare: Vector2 = p + Vector2.from_angle(angle + .65 + i * 1.23) * r * 1.29
				Glyphs.draw(self, "fire", flare, .24 + .04 * sin(elapsed * 8 + i), tint.darkened(.20))
		"water", "dark":
			var rotation: float = elapsed * (2.3 if element == "water" else -1.8)
			for offset: float in [0., PI]:
				draw_arc(p, r * 1.54, rotation + offset, rotation + offset + 1.37, 16, Color(tint, .77), .096)
				var tail: Vector2 = p + Vector2.from_angle(rotation + offset + 1.37) * r * 1.54
				Glyphs.draw(self, element, tail, .15, dark)
		"nature", "light":
			for i: int in range(6):
				var branch := Vector2.from_angle(angle + TAU * i / 6.0)
				draw_line(p + branch * r * .88, p + branch * r * 1.49, Color(tint, .83), .066)
				Glyphs.draw(self, element, p + branch * r * 1.44, .14, dark)
		"electric":
			for sign_x: float in [-1., 1.]:
				var axis: Vector2 = direction.orthogonal() * sign_x
				draw_polyline(PackedVector2Array([p + axis * r * .70, p + axis * r * 1.30 - direction * r * .31,
					p + axis * r * 1.30 + direction * r * .19, p + axis * r * 1.83 + direction * r * .38]), Color("#fff3a6"), .083)
	for i: int in range(5):
		var axis := Vector2.from_angle(angle + TAU * i / 5.0)
		var point: Vector2 = p + axis * r * (1.10 + .10 * sin(elapsed * 6.0 + i))
		Glyphs.draw(self, element, point, .155 if i == 0 else .108, dark)
		draw_circle(point - axis * .09, .040, Color("#fff7c2"))
	draw_arc(p, r * 1.29, elapsed * 1.7, elapsed * 1.7 + PI * .82, 17, Color("#fff6b9"), .065)

func _draw_status_ground(enemy: Dictionary, p: Vector2, direction: Vector2, r: float) -> void:
	var ground: Vector2 = p + Vector2(0,.12)
	if int(enemy.get("slip_time", 0)) > 0:
		for index: int in range(3):
			var skid: Vector2 = ground - direction * (.06 + index * .09) + direction.orthogonal() * .08 * (index - 1)
			draw_line(skid, skid - direction * .13, Color("#edfcff", .91 - index * .20), .046)
	if int(enemy.get("disease", {}).get("time", 0)) > 0:
		_draw_oval(ground, Vector2(r + .15, .15), Color("#8a4f9b8a"))
		for index: int in range(4):
			var t: float = fposmod(elapsed * .7 + index * .26, 1.0)
			var spore: Vector2 = p + Vector2(sin(elapsed * 2.0 + index * 3.4) * (r + .10), .13 - t * .65)
			draw_circle(spore, .042 + t * .032, Color("#613978", 1.0 - t))
			draw_circle(spore - Vector2(.012,.015), .025, Color("#e9b5fc", 1.0 - t))
	if enemy.dots.has("poison"):
		_draw_oval(ground, Vector2(r + .19,.135), Color("#83b544ba"))
		_draw_oval(ground, Vector2(r * .65 + .12,.082), Color("#d0f47ca8"))
		for i: int in range(3):
			var bubble: Vector2 = ground - direction * i * .12 + Vector2(sin(elapsed * 4 + i) * .14, .02)
			draw_circle(bubble, .047 + .022 * sin(elapsed * 5 + i), Color("#e8ffad"))
	if int(enemy.slow_time) > 0 or int(enemy.freeze_time) > 0:
		for i: int in range(3):
			var spot: Vector2 = ground - direction * i * .16
			_draw_oval(spot, Vector2(r * .57 + .11,.080), Color("#77c7e4", .82 - i * .18))
			draw_arc(spot, r * .47 + .08, .18, 2.88, 13, Color("#e3fbff", .95 - i * .21), .036)
	if int(enemy.root_time) > 0:
		draw_arc(ground, r + .10, .2, TAU - .2, 23, Color("#568340"), .066)
		for sign_x: float in [-1., 1.]:
			var vine: Vector2 = ground + Vector2(sign_x * (r + .13), .08)
			draw_polyline(PackedVector2Array([ground + Vector2(sign_x * .06, .03), vine,
				vine + Vector2(sign_x * .06,-.14), vine + Vector2(sign_x * .10,-.20)]), Color("#658a4a"), .060)
			Glyphs.draw(self, "nature", vine + Vector2(sign_x * .065,-.12), .13, Color("#a8d975"))
	if int(enemy.curse_time) > 0:
		draw_arc(ground, r + .09, elapsed * 3, elapsed * 3 + PI * 1.67, 24, Color("#aa64c6"), .065)
		for i: int in range(3):
			var mote: Vector2 = ground + Vector2.from_angle(elapsed * 3.0 + TAU * i / 3.0) * (r + .105)
			draw_circle(mote, .049, Color("#764988"))
			draw_circle(mote - Vector2(0,.022), .030, Color("#f2c4fc"))

func _draw_status_glints(enemy: Dictionary, p: Vector2, r: float) -> void:
	if enemy.dots.has("burn"):
		for i: int in range(3):
			var fade: float = fposmod(elapsed * 2.2 + i * .34, 1.0)
			var spark: Vector2 = p + Vector2((i - 1) * r * .77, r * .20 - fade * (r + .20))
			Glyphs.draw(self, "fire", spark, .108 - .042 * fade, Color("#ff7645", 1.0 - fade * .43))
			draw_circle(spark + Vector2(0,.025), .041, Color("#ffe683", 1.0 - fade * .63))
	if int(enemy.freeze_time) > 0:
		for i: int in range(3):
			var shard: Vector2 = p + (Vector2.RIGHT.rotated(.3 + i * 1.8)) * (r + .014)
			_draw_polygon_base(shard, .132 - i * .012, 4, .20 + i * .11, Color("#a9e2f0"))
			_draw_polygon_base(shard, .079 - i * .009, 4, .20 + i * .11, Color("#f1fbff"))
	if int(enemy.silence_time) > 0 or int(enemy.heal_block_time) > 0:
		Glyphs.draw(self, "dark", p + Vector2(-r,.0), .115, Color("#9c6bb4"))
	if int(enemy.shred_time) > 0:
		draw_line(p + Vector2(r * .22,.04), p + Vector2(r * .88,.17), Color("#ffe6a6"), .06)

func _draw_oval(center: Vector2, radius: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for i: int in range(18):
		points.append(center + Vector2.from_angle(TAU * i / 18) * radius)
	draw_colored_polygon(points, tint)

func _draw_health(enemy: Dictionary, p: Vector2, radius: float) -> void:
	var width: float = maxf(.50, radius * 2.28)
	var ratio: float = clampf(float(enemy.hp) / maxf(1.0, float(enemy.max_hp)), 0, 1)
	var lane: float = .10 * (float(int(enemy.id) % 3) - 1) if radius < .23 else 0.0
	var bar := Rect2(p + Vector2(-width * .5, -radius * 1.34 - .17 + lane), Vector2(width, .113))
	_draw_health_bar(bar, ratio)

func _draw_health_bar(bar: Rect2, ratio: float) -> void:
	draw_rect(bar.grow(.029), Color("#514349"))
	draw_rect(bar, Color("#d1847b"))
	bar.size.x *= ratio
	if bar.size.x > 0:
		draw_rect(bar, Color("#a4ed81").lerp(Color("#ffe072"), 1.0 - ratio))

func _draw_area_hits() -> void:
	for impact: Dictionary in area_hits:
		var p: Vector2 = impact.at
		var remaining: float = float(impact.time) / .52
		if remaining > 1.0:
			continue
		var expansion: float = 1.0 - remaining
		var radius: float = float(impact.radius)
		var elements: PackedStringArray = impact.ingredients
		var color: Color = Glyphs.hue(elements[0]) if not elements.is_empty() else Color("#e9ad61")
		var reach: float = radius * lerpf(.18, 1.0, 1.0 - remaining * remaining)
		draw_circle(p, reach, Color(color, remaining * .20))
		draw_arc(p, reach, 0.0, TAU, 38, Color(color.darkened(.36), remaining * .76), .058)
		draw_arc(p, reach * .87, .8, 4.0, 21, Color("#fff7c5", remaining * .79), .049)
		var core: float = float(impact.core) * reach / radius
		if core > 0.0:
			draw_circle(p, core, Color(color, remaining * .30))
			draw_arc(p, core, 0.0, TAU, 28, Color("#fff6cb", remaining * .86), .064)
		for i: int in range(8):
			var axis := Vector2.from_angle(TAU * i / 8.0 + .21)
			var speck: Vector2 = p + axis * reach - Vector2(0, sin(expansion * PI) * .12)
			if elements.is_empty():
				draw_circle(speck, .036 + remaining * .048, Color(color, remaining))
			else:
				var element: String = elements[i % elements.size()]
				Glyphs.draw(self, element, speck, .066 + remaining * .11, Color(Glyphs.hue(element).darkened(.25), remaining))

func _draw_shot(shot: Dictionary) -> void:
	var fraction_left: float = float(shot.time) / float(shot.max)
	var progress: float = 1.0 - fraction_left
	var tint := Color(shot.color, clampf(fraction_left * 1.6, 0.0, 1.0))
	var source: Vector2 = shot.from
	var target: Vector2 = shot.to
	match String(shot.style):
		"flame", "water":
			ProjectileArt.draw_stream(self, shot, progress, fraction_left)
		"ember", "thorn", "shadow", "arrow":
			ProjectileArt.draw_missile(self, shot, progress, fraction_left)
		"pulse":
			draw_arc(source, lerpf(.16, shot.range, progress), 0, TAU, 44, tint, .10)
		"chain":
			var points := PackedVector2Array([source])
			var axis: Vector2 = (target - source).normalized().orthogonal()
			for i: int in range(1, 7):
				var zigzag: float = sin(float(i) * 7.3 + progress * 15.0)
				var arc: Vector2 = source.lerp(target, i / 7.0) + axis * zigzag * .20 * fraction_left
				points.append(arc)
			points.append(target)
			draw_polyline(points, Color("#ae85ee", fraction_left * .54), .25)
			draw_polyline(points, Color("#f6d165", fraction_left * .85), .123)
			draw_polyline(points, Color("#fff9bd", fraction_left), .047)
			var fork: Vector2 = points[4] + axis * sin(progress * 9.0) * .27
			draw_polyline(PackedVector2Array([points[3], points[4], fork]), Color("#fff9bd", fraction_left * .75), .035)
			draw_circle(target, .095 + progress * .073, tint)
		"beam":
			draw_line(source, target, Color(shot.color, .37 * fraction_left), .19)
			draw_line(source, target, Color("#fffcdf", fraction_left), .064)
			draw_circle(target, .11 + progress * .08, tint)
			var glint: Vector2 = source.lerp(target, smoothstep(0.0, 1.0, progress))
			Glyphs.draw(self, "light", glint, .10 + fraction_left * .09, tint)
		"impact":
			draw_arc(target, .07 + progress * .32, 0, TAU, 21, tint, .078)
		_:
			var shell: bool = shot.style == "shell"
			var flight: float = minf(1., progress / (.65 if shell else .76))
			if flight >= 1.0:
				var after: float = (progress - (.65 if shell else .76)) / (.35 if shell else .24)
				draw_arc(target, lerpf(.10, .49 if shell else .24, after), 0, TAU, 28, tint, .085)
				if shell:
					var spark_color: Color = Glyphs.hue(shot.element) if not String(shot.element).is_empty() else Color("#ffdb91")
					for i: int in range(5):
						var axis := Vector2.from_angle(TAU * i / 5.0 + .3)
						var spark: Vector2 = target + axis * (.14 + after * .40) - Vector2(0, sin(after * PI) * .09)
						draw_circle(spark, .056 * (1.0 - after) + .014, Color(spark_color, (1.0 - after) * .85))
				return
			var trail: Vector2 = source.lerp(target, maxf(0.0, flight - .25))
			var missile: Vector2 = source.lerp(target, flight)
			if shell:
				draw_circle(missile + Vector2(.045, .05), .096, Color("#927f55"))
				missile.y -= sin(flight * PI) * .54
				trail.y -= sin(maxf(0.0, flight - .25) * PI) * .54
				for i: int in range(3):
					var puff: Vector2 = missile.lerp(trail, (.28 + i * .24))
					draw_circle(puff, .035 + i * .027, Color("#8e7155", .40 - i * .10))
			draw_line(trail, missile, tint, .098 if shell else .062)
			draw_circle(missile, .113 if shell else .070, Color("#fff7cb"))
			if not shell and not String(shot.element).is_empty():
				Glyphs.draw(self, shot.element, missile, .098, tint.darkened(.31))

func _draw_fusion(trail: Dictionary) -> void:
	var age: float = .78 - float(trail.time)
	var travel: float = smoothstep(.0, .55, age)
	var source: Vector2 = trail.from
	var target: Vector2 = trail.to
	var side: Vector2 = (target - source).normalized().orthogonal()
	var elements: PackedStringArray = trail.elements
	for i: int in range(elements.size()):
		var bend: float = (i - (elements.size() - 1) * .5) * .85
		var tint: Color = Glyphs.hue(elements[i])
		var path := PackedVector2Array()
		for j: int in range(7):
			var t: float = lerpf(maxf(.0, travel - .23), travel, j / 6.0)
			path.append(source.lerp(target, t) + side * sin(PI * t) * bend)
		if age < .55:
			if travel > .001:
				draw_polyline(path, Color(tint, .70), .085, true)
			draw_circle(path[-1], .16, Color(tint, .6))
			Glyphs.draw(self, elements[i], path[-1], .115, Color("#fffbd6"))
	if age > .50:
		var bloom: float = clampf((age - .50) / .28, 0.0, 1.0)
		draw_arc(target, .23 + .52 * bloom, 0, TAU, 40, Color(GOLD, 1.0 - bloom), .075, true)
		for i: int in range(6):
			var star: Vector2 = target + Vector2.from_angle(TAU * i / 6.0) * (.30 + .47 * bloom)
			draw_circle(star, .075 * (1.0 - bloom), Color("#fff8bf"))

func _draw_burst(burst: Dictionary) -> void:
	var remaining: float = float(burst.time) / float(burst.max)
	var shade := Color(burst.color, remaining * .90)
	var p: Vector2 = burst.at
	var r: float = float(burst.radius) * (1.0 - remaining)
	draw_arc(p, .11 + r, 0, TAU, 30, shade, .062)
	if burst.get("action", "") == "tower_upgraded":
		for i: int in range(2):
			var tip: Vector2 = p + Vector2(0, -.14 - (1.0 - remaining) * .65 - i * .16)
			var chevron := PackedVector2Array([tip + Vector2(-.14, .12), tip, tip + Vector2(.14, .12)])
			draw_polyline(chevron, Color("#775122", remaining), .105, true)
			draw_polyline(chevron, Color("#fff0a3", remaining), .055, true)
		return
	if burst.get("action", "") == "infusion_changed" and not String(burst.element).is_empty():
		for i: int in range(3):
			var orbit := Vector2.from_angle(i * TAU / 3.0 + remaining * 3.2) * (.23 + remaining * .47)
			Glyphs.draw(self, burst.element, p + orbit, .09 + remaining * .06, Color(shade.lightened(.35), remaining))
		return
	for i: int in range(6):
		var axis := Vector2.from_angle(TAU * i / 6.0)
		draw_circle(p + axis * (.13 + r), .055 * remaining + .021, shade)

func _draw_reward(reward: Dictionary) -> void:
	var progress: float = 1.0 - float(reward.time) / float(reward.max)
	var p: Vector2 = reward.at
	p.x = clampf(p.x, .52, sim.track.bounds.x - .52)
	var rise: float = .32 + float(reward.offset) + progress * .90
	p.y = minf(sim.track.bounds.y - .44, p.y + rise) if gate_on_top else maxf(.44, p.y - rise)
	var fade: float = 1.0 - smoothstep(.74, 1.0, progress)
	var pop: float = .45 + sin(minf(progress * 6.0, 1.0) * PI) * .10
	_caption("+%d" % reward.gold, p, pop, Color(REWARD, fade), Color("#51402c", fade))

func _tower_color(tower: Dictionary) -> Color:
	if TowerRules.is_fusion(tower):
		var ingredients: PackedStringArray = TowerRules.ingredients(tower)
		return Glyphs.hue(ingredients[0]).lerp(Glyphs.hue(ingredients[1]), .27)
	if tower.infusion != "":
		return Glyphs.hue(tower.infusion)
	return Glyphs.hue(tower.element)

func _caption(value: String, p: Vector2, height: float, tint: Color, outline: Color = Color.TRANSPARENT) -> void:
	var em: int = 64
	var offset: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, em).x * height / em
	draw_set_transform(canvas_transform * p - Vector2(offset * zoom * .5, 0), 0, Vector2.ONE * zoom * height / em)
	if outline.a > 0:
		draw_string_outline(font, Vector2.ZERO, value, HORIZONTAL_ALIGNMENT_LEFT, -1, em, 8, outline)
	draw_string(font, Vector2.ZERO, value, HORIZONTAL_ALIGNMENT_LEFT, -1, em, tint)
	draw_set_transform_matrix(canvas_transform)
