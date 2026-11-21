class_name MobArt
extends RefCounted

const CREATURES: Texture2D = preload("res://assets/woodland/creatures.png")
const GRIM_CREATURES: Texture2D = preload("res://assets/woodland/grim_creatures.webp")
const BOSSES: Texture2D = preload("res://assets/woodland/bosses.webp")
const CASTER_DIRECTIONS: Texture2D = preload("res://assets/woodland/boss-directions.webp")
const BOSS_CELLS: Dictionary = {"ram": 1, "tempest": 3, "ironwood": 4}
const BOSS_CELL: int = 192
const PRISMHEART: Texture2D = preload("res://assets/woodland/prismheart.webp")
const PRISMHEART_FORMS: Array[String] = ["none", "fire", "water", "nature", "electric", "light", "dark"]
const PRISMHEART_CELL: int = 192
const CELLS: Dictionary = {"acorn": 0, "beetle": 1, "hare": 2, "guard": 3, "cap": 4, "moth": 5, "boar": 6, "drake": 7}
const GAITS: Dictionary = {"acorn": "hop", "hare": "hop", "cap": "hop", "moth": "fly", "guard": "lumber", "boar": "lumber"}
const ARMOR: Array[Color] = [Color("#c28b53"), Color("#b4cbd4"), Color("#e2b969"), Color("#bba1ef")]
const CAMPAIGN_TINTS: Array[Color] = [Color("#ddc397"), Color("#9fb9d9"), Color("#a2a7af"), Color("#ad91d1")]

static func draw(canvas: CanvasItem, enemy: Dictionary, p: Vector2, direction: Vector2, r: float, tint: Color, distance: float, clock: float, impact: float = 0.0) -> void:
	if enemy.kind == "boss":
		_boss(canvas, enemy, p - direction * impact * .045, r, direction, clock, distance)
		return
	var family: String = enemy.get("family", "acorn")
	var entry: Dictionary = DataDB.read("mobs").families.get(family, {})
	var gait: String = entry.get("gait", GAITS.get(family, "scuttle"))
	var variation: float = float(enemy.get("id", 0))
	var stride: float = distance * (8.0 if gait == "lumber" else 13.0) + variation
	var step: float = sin(stride)
	var hop: float = absf(step)
	var width: float = 1.0
	var lift: float = hop * .13
	var sway: float = sin(stride * .5) * .035
	match gait:
		"hop":
			lift = hop * (.54 if family in ["hare", "mire_toad", "dread_goat"] else .28)
			width += (1.0 - hop * 2.0) * .084
		"fly":
			var flap: float = sin(clock * 14.0 + variation)
			lift = .29 + flap * .08
			width += flap * .16
		"lumber":
			sway = step * .10
			width += hop * .035
		"scuttle":
			sway = step * .105
			width -= hop * .045
	if int(enemy.get("freeze_time", 0)) > 0 or int(enemy.get("root_time", 0)) > 0:
		lift = .0
		width = 1.0
		sway = .0
	width += .14 * impact
	var facing: float = -1.0 if direction.x + direction.y * .45 < 0.0 else 1.0
	var span := Vector2(width, 1.0 / width) * r * 2.45
	var center: Vector2 = p + Vector2(sway * r, -r * (.13 + lift)) - direction * impact * .07
	var rect := Rect2(center - span * .5, span)
	rect.size.x *= facing
	var wash: Color = Color.WHITE.lerp(tint, .30 if enemy.element != "none" else .09)
	var rank: int = int(enemy.get("armor_rank", 0))
	if rank > 0:
		wash = wash.lerp(CAMPAIGN_TINTS[rank - 1], .34)
	wash = wash.lightened(impact * .5)
	var grim: int = int(entry.get("grim_index", -1))
	var tile: int = 160 if grim >= 0 else 192
	var columns: int = 5 if grim >= 0 else 4
	var index: int = grim if grim >= 0 else CELLS.get(family, 0)
	var region := Rect2(index % columns * tile, index / columns * tile, tile, tile)
	canvas.draw_texture_rect_region(GRIM_CREATURES if grim >= 0 else CREATURES, rect, region, wash)
	_draw_armor(canvas, center, r, rank, clock)
	if rank == 0 and enemy.props.has("armored"):
		canvas.draw_arc(p + Vector2(0,r*.65), r*.66, .25, PI-.25, 10, Color("#ffebaf"), r*.105, true)

static func _draw_armor(canvas: CanvasItem, p: Vector2, r: float, rank: int, clock: float) -> void:
	if rank <= 0:
		return
	var metal: Color = ARMOR[rank - 1]
	var ink: Color = metal.darkened(.63)
	for side: float in [-1.0, 1.0]:
		var shoulder: Vector2 = p + Vector2(side * .64, .24) * r
		_shape(canvas, shoulder, Vector2.RIGHT, r,
			[Vector2(-.29, -.19), Vector2(.18, -.23), Vector2(.29, .01), Vector2(.11, .30), Vector2(-.22, .17)], ink)
		canvas.draw_line(shoulder + Vector2(-.21, -.14) * r, shoulder + Vector2(.15, -.17) * r, metal, .103 * r, true)
		if rank >= 2:
			canvas.draw_circle(shoulder + Vector2(.04, .07) * r, r * .09, metal, true, -1, true)
		if rank >= 3:
			var tip: Vector2 = shoulder + Vector2(side * .27, -.49) * r
			canvas.draw_colored_polygon(PackedVector2Array([shoulder, tip, shoulder + Vector2(side * .20, -.04) * r]), metal)
	if rank >= 4:
		canvas.draw_arc(p + Vector2(0, r * .58), r * .88, .15, PI - .15, 16, Color(metal, .68 + .17 * sin(clock * 6.0)), r * .12, true)

static func _boss(canvas: CanvasItem, enemy: Dictionary, p: Vector2, r: float, forward: Vector2, clock: float, distance: float) -> void:
	var boss_type: String = enemy.boss_type
	if boss_type == "prismheart":
		draw_prismheart(canvas, enemy.element, p, r, clock)
		return
	if boss_type in ["warlock", "necromancer"]:
		_caster(canvas, enemy, p, r, forward, clock, distance)
		return
	var up: Vector2 = forward if forward != Vector2.ZERO else Vector2.UP
	var center: Vector2 = p
	var wing_span: float = 1.0
	match boss_type:
		"ram":
			center -= up * (1.0 - cos(distance * 21.0)) * r * .026
		"tempest":
			wing_span = .86 + .14 * sin(clock * 12.0)
		"ironwood":
			center += up * sin(distance * 32.0) * r * .032
			if distance > 0.0:
				for i: int in range(2):
					var drift: float = fposmod(clock * 1.5 + float(i) * .5, 1.0)
					var smoke: Vector2 = center - up * r * (.92 + drift * .85)
					canvas.draw_circle(smoke, r * (.09 + drift * .15), Color("#aa886a", (1.0 - drift) * .34), true, -1, true)
	_painted_boss(canvas, boss_type, center, r, up, wing_span)

static func _caster(canvas: CanvasItem, enemy: Dictionary, p: Vector2, r: float, heading: Vector2,
		clock: float, distance: float) -> void:
	var warlock: bool = enemy.boss_type == "warlock"
	var row: int = 0 if warlock else 1
	var stride: float = distance * (10.5 if warlock else 8.5)
	var center: Vector2 = p + _caster_drift(heading, r, stride)
	var flutter: float = sin(stride) * .035
	var span := Vector2(1.0 + flutter, 1.0 - flutter) * r * 3.18
	var side: float = _caster_side_weight(heading)
	if side < 1.0:
		var column: int = 2 if heading.y < 0.0 else 0
		_caster_pose(canvas, Rect2(center - span * .5, span), Vector2i(column, row), false, 1.0 - side)
	if side > 0.0:
		_caster_pose(canvas, Rect2(center - span * .5, span), Vector2i(1, row), heading.x < 0.0, side)
	if warlock and not enemy.get("telegraph", {}).is_empty():
		var staff: Vector2 = p + warlock_staff_offset(heading, r, distance)
		canvas.draw_circle(staff, r * (.13 + .05 * sin(clock * 13.0)), Color("#ffade6", .48), true, -1, true)

static func _caster_side_weight(heading: Vector2) -> float:
	return smoothstep(.36, .85, absf(heading.x))

static func _caster_drift(heading: Vector2, r: float, stride: float) -> Vector2:
	return (heading * (.07 + .045 * sin(stride)) + Vector2(0.0, -.18 + .10 * cos(stride))) * r

static func warlock_staff_offset(heading: Vector2, r: float, distance: float) -> Vector2:
	var side: float = _caster_side_weight(heading)
	var upright_x: float = -.89 if heading.y < 0.0 else .84
	var side_x: float = -.86 if heading.x < 0.0 else .86
	return _caster_drift(heading, r, distance * 10.5) + Vector2(lerpf(upright_x, side_x, side), -.85) * r

static func _caster_pose(canvas: CanvasItem, target: Rect2, cell: Vector2i, mirror: bool, opacity: float) -> void:
	var origin: Vector2 = Vector2(cell * BOSS_CELL) / CASTER_DIRECTIONS.get_size()
	var size: Vector2 = Vector2.ONE * BOSS_CELL / CASTER_DIRECTIONS.get_size()
	var left: float = origin.x + (size.x if mirror else 0.0)
	var right: float = origin.x + (0.0 if mirror else size.x)
	var points := PackedVector2Array([target.position, Vector2(target.end.x, target.position.y), target.end,
		Vector2(target.position.x, target.end.y)])
	var uv := PackedVector2Array([Vector2(left, origin.y), Vector2(right, origin.y),
		Vector2(right, origin.y + size.y), Vector2(left, origin.y + size.y)])
	canvas.draw_polygon(points, PackedColorArray([Color(1, 1, 1, opacity)]), uv, CASTER_DIRECTIONS)

static func _painted_boss(canvas: CanvasItem, boss_type: String, center: Vector2, r: float, up: Vector2, wing_span: float) -> void:
	var index: int = int(BOSS_CELLS.get(boss_type, 0))
	var atlas_size: Vector2 = BOSSES.get_size()
	var uv_origin: Vector2 = Vector2(index % 3, index / 3) * BOSS_CELL / atlas_size
	var uv_size: Vector2 = Vector2.ONE * BOSS_CELL / atlas_size
	var across: Vector2 = Vector2(-up.y, up.x) * r * 3.18
	var down: Vector2 = -up * r * 3.18
	var columns := PackedFloat32Array([0.0, .30, .70, 1.0] if boss_type == "tempest" else [0.0, 1.0])
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	# Keep Stormwing's torso fixed while its outer wing sections fold toward it.
	for column: float in columns:
		var x: float = column - .5
		var wing_tip: bool = boss_type == "tempest" and absf(x) > .49
		var sweep: float = (1.0 - wing_span) * .34 if wing_tip else 0.0
		if wing_tip:
			x *= wing_span
		upper.append(center + across * x + down * (-.5 + sweep))
		lower.append(center + across * x + down * (.5 + sweep))
	for i: int in range(columns.size() - 1):
		var points := PackedVector2Array([upper[i], upper[i + 1], lower[i + 1], lower[i]])
		var left: Vector2 = uv_origin + Vector2(columns[i] * uv_size.x, 0)
		var right: Vector2 = uv_origin + Vector2(columns[i + 1] * uv_size.x, 0)
		var vertical := Vector2(0, uv_size.y)
		var uv := PackedVector2Array([left, right, right + vertical, left + vertical])
		canvas.draw_polygon(points, PackedColorArray([Color.WHITE]), uv, BOSSES)

static func draw_prismheart(canvas: CanvasItem, form: String, p: Vector2, r: float, clock: float,
		previous_form: String = "", transition: float = 1.0) -> void:
	var pivot: Vector2 = p + Vector2(0, -.15 + sin(clock * 4.5) * .11) * r
	var blend: float = smoothstep(0.0, 1.0, transition)
	if not previous_form.is_empty() and blend < 1.0:
		_prismheart_sprite(canvas, previous_form, pivot, r * lerpf(1.0, 1.18, blend), clock, 1.0 - blend)
	_prismheart_sprite(canvas, form, pivot, r * lerpf(.85, 1.0, blend), clock, blend)

static func _prismheart_sprite(canvas: CanvasItem, form: String, pivot: Vector2, r: float, clock: float, opacity: float) -> void:
	var index: int = maxi(0, PRISMHEART_FORMS.find(form))
	var cell := Vector2(PRISMHEART_CELL, PRISMHEART_CELL)
	var source := Rect2(Vector2(index % 4, index / 4) * cell, cell)
	var breath: float = sin(clock * (3.7 if form == "water" else 5.7)) * .025
	var span: Vector2 = Vector2(1.0 + breath, 1.0 - breath) * r * 3.4
	var target := Rect2(pivot - span * Vector2(.5, 100.0 / PRISMHEART_CELL), span)
	canvas.draw_texture_rect_region(PRISMHEART, target, source, Color(1.0, 1.0, 1.0, opacity))

static func _shape(canvas: CanvasItem, p: Vector2, direction: Vector2, r: float, points: Array[Vector2], tint: Color) -> void:
	var geometry := PackedVector2Array()
	var side: Vector2 = direction.orthogonal()
	for point: Vector2 in points:
		geometry.append(p + (direction * point.x + side * point.y) * r)
	canvas.draw_colored_polygon(geometry,tint)
