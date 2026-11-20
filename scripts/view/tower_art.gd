class_name TowerArt
extends RefCounted

const INK: Color = Color("#354d47")
const IVORY: Color = Color("#fff5cb")
const WOOD: Color = Color("#775849")
const LANDMARKS: Texture2D = preload("res://assets/woodland/landmarks.png")
const CELLS: Dictionary = {"fire": 0, "water": 1, "nature": 2, "electric": 3, "light": 4, "dark": 5, "gate": 6, "portal": 7}

static func draw_landmark(canvas: CanvasItem, id: String, center: Vector2, span: Vector2) -> void:
	var cell: int = CELLS[id]
	var region := Rect2((cell % 4) * 192, floori(cell / 4.0) * 192, 192, 192)
	canvas.draw_texture_rect_region(LANDMARKS, Rect2(center - span * .5, span), region)

static func draw(canvas: CanvasItem, tower: Dictionary, p: Vector2, r: float, clock: float) -> void:
	var ingredients: PackedStringArray = TowerRules.ingredients(tower)
	if ingredients.is_empty() or tower.kind in ["arrow", "cannon"]:
		Glyphs.draw(canvas, tower.kind, p, r * .67, INK)
		return
	var current: Color = Glyphs.hue(ingredients[0])
	var accent: Color = Glyphs.hue(ingredients[1]) if ingredients.size() > 1 else current.lightened(.32)
	var motif: String = TowerRules.stats(tower).get("art", tower.element)
	var pulse: float = sin(clock * 5.7 + p.x * 1.1) * .5 + .5
	if tower.kind == "ascended":
		canvas.draw_circle(p, r * 1.15, Color(current, .21))
		canvas.draw_arc(p, r * 1.15, 0, TAU, 42, Color("#ffe294"), r * .065, true)
		for index: int in range(3):
			var jewel: Vector2 = p + Vector2.from_angle(clock * 1.1 + TAU * index / 3.0) * r * 1.13
			_poly(canvas, jewel, r * .19, [Vector2(0, -1), Vector2(.62, 0), Vector2(0, 1), Vector2(-.62, 0)], Color("#fff0a8"))
	_oval(canvas, p + Vector2(.04,.50) * r, Vector2(.74,.18) * r, Color("#3e4f3c52"))
	if tower.kind == "pure" or tower.kind == "ascended":
		var crown: Vector2 = p - Vector2(0, .17) * r
		draw_landmark(canvas, tower.element, crown, Vector2.ONE * r * 2.22)
		var phase: float = fposmod(clock * .7 + float(tower.id) * .37, 1.0)
		var mote: Vector2 = crown + Vector2(sin(phase * PI * 1.4) * .29, -.50 - phase * .64) * r
		canvas.draw_circle(mote, r * (.06 + (1.0 - phase) * .04), Color(current.lightened(.32), sin(phase * PI)))
		return
	match motif:
		"fire", "crater":
			_poly(canvas, p, r, [Vector2(-.82,.20),Vector2(-.59,-.18),Vector2(.57,-.18),Vector2(.83,.20),Vector2(.53,.53),Vector2(-.55,.53)], INK)
			_oval(canvas, p + Vector2(0,.21) * r, Vector2(.64,.18) * r, current.darkened(.28))
			_flame(canvas, p + Vector2(-.30,.05) * r, r * .42, accent, pulse)
			_flame(canvas, p + Vector2(.29,.12) * r, r * .39, current, 1.0 - pulse)
			_flame(canvas, p - Vector2(.02,.09) * r, r * (.70 + pulse * .10), current, pulse)
		"water", "geyser", "spring":
			var basin: Color = accent.darkened(.27) if motif == "geyser" else current.darkened(.31)
			_oval(canvas, p + Vector2(0,.32) * r, Vector2(.88,.37) * r, INK)
			_oval(canvas, p + Vector2(0,.25) * r, Vector2(.76,.30) * r, basin)
			_oval(canvas, p + Vector2(0,.21) * r, Vector2(.64,.20) * r, Color("#80dbec"))
			for side: float in [-1., 1.]:
				var origin: Vector2 = p + Vector2(side * .16,.12) * r
				var line := PackedVector2Array([origin, p + Vector2(side * .18,-.58 - pulse * .12) * r,
					p + Vector2(side * .42,-.43) * r, p + Vector2(side * .63,.05) * r])
				canvas.draw_polyline(line, Color("#e8fcfb"), r * .088)
				var phase: float = fposmod(clock * 1.1 + side * .31, 1.0)
				var drop: Vector2 = p + Vector2(side * (.23 + phase * .46), -.47 + phase * phase * .63) * r
				canvas.draw_circle(drop, r * .091, Color("#83d7f2"))
			if motif == "geyser":
				for i: int in range(3):
					var t: float = fposmod(clock * .64 + i * .31, 1.0)
					_oval(canvas, p + Vector2(sin(i * 3.2 + clock) * .31, -.46 - t * .68) * r,
						Vector2(.18 + t * .14,.13 + t * .09) * r, Color(IVORY, .62 - t * .55))
			elif motif == "spring":
				_leaf(canvas, p + Vector2(-.55,.27) * r, r * .25, -.7, accent.darkened(.27))
				_leaf(canvas, p + Vector2(.54,.23) * r, r * .25, .9, accent)
		"nature", "grove", "thorn", "trap":
			_grove(canvas, p, r, current, accent, pulse, motif)
		"electric", "anvil", "storm":
			_coil(canvas, p, r, current, accent, clock, motif)
		"light", "sunburst", "prism", "ice":
			_crystal(canvas, p, r, current, accent, clock, motif)
		"dark", "vortex", "eclipse":
			_vortex(canvas, p, r, current, accent, clock, motif)
		"lotus", "starbloom":
			for i: int in range(7):
				var ray := Vector2.from_angle(TAU * i / 7.0)
				if motif == "starbloom":
					canvas.draw_line(p + ray * r * .31, p + ray * (.90 + pulse * .10) * r, Color("#ffd782"), r * .105)
				_leaf(canvas, p + ray * r * .41, r * .42, ray.angle() + .78, current if i % 2 == 0 else accent)
			canvas.draw_circle(p, r * .37, INK)
			canvas.draw_circle(p - Vector2(0,.06) * r, r * .29, accent.lightened(.31))
			canvas.draw_circle(p - Vector2(.07,.13) * r, r * .105, IVORY)
	if ingredients.size() == 3:
		for i: int in range(3):
			var point: Vector2 = p + Vector2.from_angle(clock * .9 + TAU * i / 3.0) * r * 1.05
			var color: Color = Glyphs.hue(ingredients[i])
			canvas.draw_circle(point, r * .139, color.darkened(.45))
			canvas.draw_circle(point - Vector2(0,.035) * r, r * .096, color.lightened(.30))

static func _flame(canvas: CanvasItem, p: Vector2, r: float, tint: Color, sway: float) -> void:
	_poly(canvas, p, r, [Vector2(0,-1.22),Vector2(.19 + sway * .39,-.61),Vector2(.53,-.43),Vector2(.65,.13),
		Vector2(.40,.52),Vector2(-.06,.66),Vector2(-.53,.40),Vector2(-.61,-.07),Vector2(-.31,-.70),Vector2(-.20,-.20)], tint.darkened(.14))
	_poly(canvas, p, r, [Vector2(.02,-.68),Vector2(.22 + sway * .28,-.37),Vector2(.39,.07),Vector2(.20,.45),
		Vector2(-.14,.47),Vector2(-.36,.19),Vector2(-.23,-.19)], Color("#ffc05b"))
	_poly(canvas, p, r, [Vector2(0,-.18),Vector2(.20,.16),Vector2(.09,.41),Vector2(-.11,.40),Vector2(-.18,.18)], IVORY)

static func _grove(canvas: CanvasItem, p: Vector2, r: float, paint: Color, accent: Color, pulse: float, motif: String) -> void:
	var trunk := PackedVector2Array([p + Vector2(-.44,.46) * r, p + Vector2(.02,.11) * r,
		p + Vector2(-.08,-.29) * r, p + Vector2(.14,-.81) * r])
	canvas.draw_polyline(trunk, WOOD.darkened(.24), r * .28)
	canvas.draw_polyline(trunk, WOOD.lightened(.13), r * .15)
	for i: int in range(3):
		var direction: float = float(i - 1)
		var twig: Vector2 = p + Vector2(direction * (.58 + pulse * .03), -.42 - .39 * (1.0 - absf(direction))) * r
		canvas.draw_line(p + Vector2(.02,.11) * r, twig, WOOD, r * .13)
		var color: Color = paint if i != 1 else accent
		if motif == "thorn" or motif == "trap":
			_leaf(canvas, twig, r * .51, -direction * .76, color.darkened(.20))
			_leaf(canvas, twig + Vector2(-direction * .22,.25) * r, r * .36, direction * .92, color)
		else:
			canvas.draw_circle(twig, r * .39, color.darkened(.38))
			canvas.draw_circle(twig - Vector2(0,.065) * r, r * .325, color.lightened(.12))
			_leaf(canvas, twig + Vector2(.17,-.155) * r, r * .22, -.1 + direction * .52, color.lightened(.47))
		if motif == "grove" and paint.r > .80 and paint.g < .65:
			_flame(canvas, twig - Vector2(0,.08) * r, r * .32, paint, pulse)
		elif i != 1:
			canvas.draw_circle(twig + Vector2(.10,.17) * r, r * .09, accent.lightened(.20))
	if motif == "trap":
		var mouth: Vector2 = p + Vector2(.06,.09) * r
		_oval(canvas, mouth, Vector2(.45,.25) * r, INK)
		for side: float in [-1., 1.]:
			var blade: Vector2 = mouth + Vector2(side * .22, -.15) * r
			_poly(canvas, blade, r, [Vector2(-.10,0),Vector2(.10,0),Vector2(0,.23)], IVORY)

static func _coil(canvas: CanvasItem, p: Vector2, r: float, paint: Color, accent: Color, clock: float, motif: String) -> void:
	if motif == "anvil":
		_poly(canvas, p, r, [Vector2(-.84,-.01),Vector2(-.43,-.29),Vector2(.78,-.29),Vector2(.60,.02),
			Vector2(.34,.07),Vector2(.29,.53),Vector2(-.28,.53),Vector2(-.31,.09)], INK)
		canvas.draw_line(p + Vector2(-.38,-.23) * r, p + Vector2(.61,-.23) * r, accent, r * .09)
	else:
		for side: float in [-1., 1.]:
			var pole: Vector2 = p + Vector2(side * .47,-.43) * r
			canvas.draw_line(p + Vector2(side * .50,.49) * r, pole, INK, r * .25)
			canvas.draw_circle(pole, r * .22, paint.darkened(.35))
			canvas.draw_circle(pole + Vector2(-.04,-.05) * r, r * .158, paint.lightened(.20))
	if motif == "storm":
		for i: int in range(4):
			var puff: Vector2 = p + Vector2((i - 1.5) * .38,-.38 - .12 * (i % 2)) * r
			canvas.draw_circle(puff, r * .27, paint.darkened(.33))
			canvas.draw_circle(puff - Vector2(0,.07) * r, r * .225, paint)
	var flicker: float = sin(clock * 17.0) * .10
	var arc := PackedVector2Array([p + Vector2(-.46,-.47) * r, p + Vector2(-.13,-.78 + flicker) * r,
		p + Vector2(-.01,-.45) * r, p + Vector2(.30,-.73 - flicker) * r, p + Vector2(.54,-.45) * r])
	canvas.draw_polyline(arc, accent.darkened(.25), r * .16)
	canvas.draw_polyline(arc, Color("#fff6ab"), r * .076)
	Glyphs.draw(canvas, "electric", p + Vector2(.05,.17) * r, r * .32, IVORY)

static func _crystal(canvas: CanvasItem, p: Vector2, r: float, paint: Color, accent: Color, clock: float, motif: String) -> void:
	if motif == "sunburst":
		for i: int in range(8):
			var ray := Vector2.from_angle(clock * .45 + TAU * i / 8.0)
			canvas.draw_line(p + ray * r * .41, p + ray * r * (.83 + float(i % 2) * .14), accent, r * .105)
	for i: int in range(3):
		var small: bool = i != 2
		var center: Vector2 = p + (Vector2(-.49,.17) if i == 0 else (Vector2(.49,.12) if i == 1 else Vector2(0,-.18))) * r
		var scale: float = r * (.58 if small else (1.13 if motif == "ice" else .85))
		_poly(canvas, center, scale, [Vector2(0,-1.06),Vector2(.56,-.30),Vector2(.50,.38),Vector2(.10,.80),
			Vector2(-.57,.39),Vector2(-.58,-.31)], INK)
		_poly(canvas, center, scale, [Vector2(0,-.89),Vector2(.46,-.28),Vector2(.39,.31),Vector2(.09,.65),
			Vector2(-.43,.34),Vector2(-.45,-.30)], paint.lightened(.20) if not small else accent)
		_poly(canvas, center, scale, [Vector2(0,-.89),Vector2(.12,-.17),Vector2(.09,.65),
			Vector2(-.43,.34),Vector2(-.45,-.30)], accent.lightened(.50))
	if motif == "prism":
		var beam: Vector2 = p + Vector2(.81,-.54) * r
		canvas.draw_line(p, beam, Color("#fff9ba"), r * .11)

static func _vortex(canvas: CanvasItem, p: Vector2, r: float, paint: Color, accent: Color, clock: float, motif: String) -> void:
	_poly(canvas, p, r, [Vector2(-.75,.53),Vector2(-.59,.18),Vector2(-.47,-.29),Vector2(-.10,-.33),
		Vector2(.03,.23),Vector2(.48,.18),Vector2(.76,.51)], INK)
	var orb: Vector2 = p - Vector2(0,.27) * r
	canvas.draw_circle(orb, r * .55, INK.darkened(.34))
	canvas.draw_arc(orb, r * .57, clock * 1.3, clock * 1.3 + TAU * .77, 25, paint.lightened(.20), r * .13)
	canvas.draw_arc(orb, r * .38, -clock * 1.7, -clock * 1.7 + PI * 1.5, 19, accent, r * .10)
	if motif == "eclipse":
		canvas.draw_circle(orb, r * .32, accent.lightened(.22))
		canvas.draw_circle(orb - Vector2(.08,.045) * r, r * .31, INK.darkened(.34))
	else:
		canvas.draw_circle(orb + Vector2.from_angle(clock * 2.3) * r * .18, r * .11, Color("#e4cefa"))

static func _leaf(canvas: CanvasItem, p: Vector2, r: float, angle: float, tint: Color) -> void:
	var points := PackedVector2Array()
	for vector: Vector2 in [Vector2(-.64,.51),Vector2(-.70,-.04),Vector2(-.26,-.57),Vector2(.77,-.81),
			Vector2(.63,.23),Vector2(.21,.68),Vector2(-.23,.73)]:
		points.append(p + vector.rotated(angle) * r)
	canvas.draw_colored_polygon(points, tint)
	canvas.draw_line(p + Vector2(-.42,.43).rotated(angle) * r, p + Vector2(.49,-.52).rotated(angle) * r, tint.lightened(.39), r * .12)

static func _poly(canvas: CanvasItem, p: Vector2, r: float, shape: Array[Vector2], tint: Color) -> void:
	var points := PackedVector2Array()
	for point: Vector2 in shape:
		points.append(p + point * r)
	canvas.draw_colored_polygon(points, tint)

static func _oval(canvas: CanvasItem, p: Vector2, radius: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for i: int in range(20):
		points.append(p + Vector2.from_angle(TAU * i / 20.0) * radius)
	canvas.draw_colored_polygon(points, tint)
