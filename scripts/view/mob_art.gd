class_name MobArt
extends RefCounted

const BONE: Color = Color("#fbecce")
const EYES: Color = Color("#392e36")

const CREATURES: Texture2D = preload("res://assets/woodland/creatures.png")
const GRIM_CREATURES: Texture2D = preload("res://assets/woodland/grim_creatures.webp")
const CELLS: Dictionary = {"acorn": 0, "beetle": 1, "hare": 2, "guard": 3, "cap": 4, "moth": 5, "boar": 6, "drake": 7}
const GAITS: Dictionary = {"acorn": "hop", "hare": "hop", "cap": "hop", "moth": "fly", "guard": "lumber", "boar": "lumber"}
const ARMOR: Array[Color] = [Color("#c28b53"), Color("#b4cbd4"), Color("#e2b969"), Color("#bba1ef")]
const CAMPAIGN_TINTS: Array[Color] = [Color("#ddc397"), Color("#9fb9d9"), Color("#a2a7af"), Color("#ad91d1")]

static func draw(canvas: CanvasItem, enemy: Dictionary, p: Vector2, direction: Vector2, r: float, tint: Color, distance: float, clock: float, impact: float = 0.0) -> void:
	if enemy.kind == "boss":
		_boss(canvas, enemy.boss_type, p - direction * impact * .045, r, direction, clock, distance)
		_draw_armor(canvas, p, r, int(enemy.get("armor_rank", 0)), clock)
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

static func _boss(canvas: CanvasItem, id: String, p: Vector2, r: float, forward: Vector2, clock: float, distance: float) -> void:
	var side: Vector2 = forward.orthogonal()
	match id:
		"warlock":
			var center: Vector2 = p - Vector2(0,.12 + .09 * sin(clock * 4.7)) * r
			var ink := Color("#4a294b")
			_shape(canvas, center, forward, r, [Vector2(-1.29,-.86),Vector2(-.20,-.51),Vector2(.71,-.63),
				Vector2(1.03,-.14),Vector2(.81,.51),Vector2(-.22,.76),Vector2(-1.28,.90),Vector2(-.96,.06)], ink)
			_oval(canvas, center, forward, Vector2(.77,.67) * r, Color("#b95a82"))
			_oval(canvas, center + forward * .28 * r, forward, Vector2(.51,.44) * r, Color("#432936"))
			_face(canvas, center + forward * .42 * r, forward, side, r, Color("#ffef9a"))
			var staff: Vector2 = center + side * r * 1.02
			canvas.draw_line(staff - forward * r * .74, staff + forward * r * .52, Color("#7e5242"), r * .17)
			canvas.draw_circle(staff + forward * r * .53, r * .28, Color("#ed88d1", .62 + sin(clock * 8) * .22))
			canvas.draw_circle(staff + forward * r * .53, r * .12, BONE)
		"ram":
			var ink := Color("#464d55")
			var gait: float = sin(distance * 16)
			_legs(canvas, p, forward, side, r, ink, Color("#9da7a7"), gait, 2)
			_body(canvas, p, forward, 1.05, .96, r, Color("#a1aaa4"), ink)
			_oval(canvas, p + forward * r * .41, forward, Vector2(.67,.58) * r, Color("#6f8285"))
			for sign_x: float in [-1., 1.]:
				var horn: Vector2 = p + side * sign_x * r * .89 + forward * r * .17
				canvas.draw_arc(horn, r * .42, forward.angle() - 1.0, forward.angle() + 3.0, 15, ink, .27 * r)
				canvas.draw_arc(horn, r * .42, forward.angle() - .91, forward.angle() + 2.9, 15, BONE, .18 * r)
				canvas.draw_circle(p - forward * r * .35 + side * sign_x * r * .62, r * .10, Color("#e7bd77"))
			_face(canvas, p + forward * .71 * r, forward, side, r, Color("#74483f"))
		_:
			var center: Vector2 = p - Vector2(0,.11 + sin(clock * 3.8) * .11) * r
			var ink := Color("#304654")
			_shape(canvas, center, forward, r, [Vector2(-1.35,-.66),Vector2(-.64,-.51),Vector2(.12,-.82),
				Vector2(.85,-.54),Vector2(1.03,0),Vector2(.86,.58),Vector2(.08,.82),Vector2(-.57,.51),Vector2(-1.38,.71)], ink)
			canvas.draw_arc(center, 1.04 * r, clock, clock + PI * 1.65, 26, Color("#6fb999",.65), r * .11)
			_oval(canvas, center + forward * .24 * r, forward, Vector2(.67,.59) * r, BONE)
			_face(canvas, center + forward * .48 * r, forward, side, r, Color("#297665"))
			for i: int in range(3):
				var wisp: Vector2 = center + Vector2.from_angle(-clock * 1.4 + TAU * i / 3.0) * r * 1.20
				canvas.draw_circle(wisp, r * .15, Color("#9fe8b0",.72))
				canvas.draw_circle(wisp, r * .07, Color("#efffbd"))

static func _face(canvas: CanvasItem, p: Vector2, forward: Vector2, side: Vector2, r: float, color: Color) -> void:
	for sign_x: float in [-1., 1.]:
		var eye: Vector2 = p + side * sign_x * r * .27
		canvas.draw_circle(eye, maxf(.027,r * .123), color)
		canvas.draw_circle(eye - Vector2(.023,.028), r * .041, BONE)
	var nose: Vector2 = p + forward * r * .24
	canvas.draw_line(nose - side * .09 * r, nose + side * .09 * r, color, .07 * r)

static func _legs(canvas: CanvasItem, p: Vector2, forward: Vector2, side: Vector2, r: float, ink: Color, tint: Color, gait: float, pairs: int) -> void:
	for index: int in range(pairs):
		for sign_x: float in [-1., 1.]:
			var swing: float = sign_x * gait * .26
			var foot: Vector2 = p + (side * sign_x * .72 + forward * (.55 - index * .54 + swing)) * r
			canvas.draw_circle(foot, r * .25, ink)
			canvas.draw_circle(foot - Vector2(0,.022), r * .165, tint.darkened(.25))

static func _body(canvas: CanvasItem, p: Vector2, direction: Vector2, length: float, width: float, r: float, tint: Color, ink: Color) -> void:
	_oval(canvas,p,direction,Vector2(length,width) * r,ink)
	_oval(canvas,p - Vector2(0,r * .075),direction,Vector2(length * .86,width * .81) * r,tint)
	canvas.draw_circle(p - direction * r * .28 - Vector2(0,r * .29), r * .14, tint.lightened(.47))

static func _shape(canvas: CanvasItem, p: Vector2, direction: Vector2, r: float, points: Array[Vector2], tint: Color) -> void:
	var geometry := PackedVector2Array()
	var side: Vector2 = direction.orthogonal()
	for point: Vector2 in points:
		geometry.append(p + (direction * point.x + side * point.y) * r)
	canvas.draw_colored_polygon(geometry,tint)

static func _oval(canvas: CanvasItem, p: Vector2, direction: Vector2, radius: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	var side: Vector2 = direction.orthogonal()
	for i: int in range(16):
		var angle: float = TAU * i / 16.0
		points.append(p + direction * cos(angle) * radius.x + side * sin(angle) * radius.y)
	canvas.draw_colored_polygon(points,tint)
