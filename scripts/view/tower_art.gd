class_name TowerArt
extends RefCounted

const INK: Color = Color("#354d47")
const IVORY: Color = Color("#fff5cb")
const WOOD: Color = Color("#775849")
const LANDMARKS: Texture2D = preload("res://assets/woodland/landmarks.png")
const CELLS: Dictionary = {"fire": 0, "water": 1, "nature": 2, "electric": 3, "light": 4, "dark": 5, "gate": 6, "portal": 7}

const FUSION_FRAMES: Dictionary = {
	"steam": "chimney", "wildfire": "flame_gate", "forge": "anvil", "flare": "rays",
	"cinder": "crater", "spring": "fountain", "storm": "fork", "frost": "iceberg",
	"venom": "fangs", "overgrowth": "canopy", "bloom": "petals", "blight": "brambles",
	"prism": "lens", "null": "gate", "eclipse": "crescent", "boilgrove": "kettle",
	"thunderkiln": "kiln", "dawngeysers": "terraces", "smoketide": "stacks",
	"sparkthorn": "cage", "daystar": "sunflower", "ashorchard": "trees", "arcfurnace": "bridge",
	"blackglass": "obelisk", "embershade": "shutters", "monsoonroot": "mast", "pearllotus": "shell",
	"mireheart": "tusks", "glaciercoil": "icicle", "umbratide": "sail", "moonglacier": "moonspires",
	"auroraarbor": "arch", "nightbriar": "thornring", "moonorchid": "orchid", "eventide": "hourglass",
}

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
	if TowerRules.is_fusion(tower):
		_fusion_frame(canvas, FUSION_FRAMES[tower.dual], p, r, current, accent, pulse)
		r *= .72
		p += Vector2(0, r * .20)
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

static func _fusion_frame(canvas: CanvasItem, id: String, p: Vector2, r: float, a: Color, b: Color, pulse: float) -> void:
	var stone: Color = a.lerp(b, .42).darkened(.29)
	var trim: Color = b.lightened(.32)
	var profile: Array[Vector2] = []
	match id:
		"chimney": profile = [Vector2(-.61,.49),Vector2(-.53,-.36),Vector2(-.28,-.36),Vector2(-.31,-1.03),Vector2(.15,-1.14),Vector2(.24,-.35),Vector2(.64,-.29),Vector2(.72,.49)]
		"flame_gate": profile = [Vector2(-.88,.49),Vector2(-.81,-.39),Vector2(-.46,-.91),Vector2(-.33,-.30),Vector2(0,-.1),Vector2(.40,-.97),Vector2(.72,-.52),Vector2(.88,.49)]
		"anvil": profile = [Vector2(-.83,-.45),Vector2(-.94,-.73),Vector2(.91,-.73),Vector2(.75,-.35),Vector2(.38,-.19),Vector2(.39,.55),Vector2(-.53,.55),Vector2(-.42,-.17)]
		"rays": profile = [Vector2(-.96,.15),Vector2(-.69,-.50),Vector2(-.43,-.33),Vector2(-.32,-1.05),Vector2(.04,-.54),Vector2(.57,-1.01),Vector2(.64,-.29),Vector2(.99,-.18),Vector2(.70,.55),Vector2(-.71,.55)]
		"crater": profile = [Vector2(-1.10,.22),Vector2(-.78,-.35),Vector2(-.53,-.32),Vector2(-.26,-.56),Vector2(.66,-.52),Vector2(.92,-.16),Vector2(1.04,.27),Vector2(.59,.55),Vector2(-.60,.55)]
		"fountain": profile = [Vector2(-1.03,.31),Vector2(-.97,-.03),Vector2(-.44,.02),Vector2(-.20,-.89),Vector2(.13,-.89),Vector2(.36,.02),Vector2(.99,-.03),Vector2(1.03,.31),Vector2(.67,.51),Vector2(-.66,.51)]
		"fork": profile = [Vector2(-.61,.53),Vector2(-.77,-.89),Vector2(-.44,-1.13),Vector2(-.29,-.45),Vector2(.22,-.45),Vector2(.43,-1.13),Vector2(.78,-.89),Vector2(.63,.53)]
		"iceberg": profile = [Vector2(-.85,.48),Vector2(-.98,-.22),Vector2(-.54,-.49),Vector2(-.42,-1.12),Vector2(-.05,-.80),Vector2(.24,-.89),Vector2(.57,-.50),Vector2(.86,-.26),Vector2(.83,.48)]
		"fangs": profile = [Vector2(-1.01,.38),Vector2(-.90,-.27),Vector2(-.56,-.71),Vector2(-.40,-.08),Vector2(.27,-.10),Vector2(.65,-.67),Vector2(.83,-.18),Vector2(1.01,.38),Vector2(.57,.56),Vector2(-.58,.56)]
		"canopy": profile = [Vector2(-.52,.57),Vector2(-.52,.10),Vector2(-1.01,-.34),Vector2(-.68,-.77),Vector2(.20,-1.01),Vector2(.88,-.62),Vector2(1.03,-.21),Vector2(.51,.14),Vector2(.53,.57)]
		"petals": profile = [Vector2(-.94,.16),Vector2(-.66,-.42),Vector2(-.47,-.28),Vector2(-.29,-.83),Vector2(0,-.58),Vector2(.29,-.83),Vector2(.47,-.28),Vector2(.67,-.42),Vector2(.94,.16),Vector2(.66,.56),Vector2(-.66,.56)]
		"brambles": profile = [Vector2(-.90,.47),Vector2(-.81,-.46),Vector2(-.52,-.16),Vector2(-.38,-.88),Vector2(-.11,-.23),Vector2(.21,-.51),Vector2(.42,-.80),Vector2(.50,-.19),Vector2(.90,-.48),Vector2(.80,.47)]
		"lens": profile = [Vector2(-.93,.08),Vector2(-.69,-.49),Vector2(.02,-.87),Vector2(.65,-.56),Vector2(.94,.13),Vector2(.48,.51),Vector2(-.43,.51)]
		"gate": profile = [Vector2(-.90,.52),Vector2(-.96,-.58),Vector2(-.62,-.88),Vector2(-.43,-.30),Vector2(.42,-.30),Vector2(.61,-.88),Vector2(.94,-.58),Vector2(.88,.52)]
		"crescent": profile = [Vector2(-.92,.14),Vector2(-.74,-.63),Vector2(-.04,-1.09),Vector2(-.21,-.59),Vector2(.05,-.15),Vector2(.68,-.09),Vector2(.88,-.31),Vector2(.80,.30),Vector2(.28,.56),Vector2(-.45,.50)]
		"kettle": profile = [Vector2(-.89,.29),Vector2(-1.00,-.06),Vector2(-.58,-.12),Vector2(-.62,-.64),Vector2(.49,-.64),Vector2(.66,-.25),Vector2(1.02,-.44),Vector2(.82,.19),Vector2(.52,.53),Vector2(-.54,.53)]
		"kiln": profile = [Vector2(-.88,.49),Vector2(-.84,-.23),Vector2(-.54,-.64),Vector2(-.47,-1.03),Vector2(-.06,-1.03),Vector2(-.06,-.67),Vector2(.55,-.62),Vector2(.84,-.18),Vector2(.88,.49)]
		"terraces": profile = [Vector2(-1.08,.53),Vector2(-1.06,.23),Vector2(-.74,.23),Vector2(-.74,-.10),Vector2(-.42,-.10),Vector2(-.42,-.56),Vector2(.41,-.56),Vector2(.41,-.10),Vector2(.74,-.10),Vector2(.74,.23),Vector2(1.06,.23),Vector2(1.08,.53)]
		"stacks": profile = [Vector2(-.73,.50),Vector2(-.85,-.78),Vector2(-.42,-.78),Vector2(-.35,-.41),Vector2(.02,-.38),Vector2(.19,-1.01),Vector2(.66,-.97),Vector2(.59,-.18),Vector2(.86,.52)]
		"cage": profile = [Vector2(-.95,.40),Vector2(-.76,-.68),Vector2(-.50,-1.01),Vector2(-.30,-.64),Vector2(.28,-.65),Vector2(.53,-1.01),Vector2(.76,-.64),Vector2(.96,.40)]
		"sunflower": profile = [Vector2(-.40,.55),Vector2(-.37,.17),Vector2(-.96,-.13),Vector2(-.70,-.46),Vector2(-.72,-.84),Vector2(-.27,-.74),Vector2(.04,-1.08),Vector2(.31,-.74),Vector2(.77,-.83),Vector2(.74,-.41),Vector2(.97,-.13),Vector2(.40,.17),Vector2(.43,.55)]
		"trees": profile = [Vector2(-.92,.52),Vector2(-.84,-.24),Vector2(-.98,-.48),Vector2(-.71,-.78),Vector2(-.44,-.47),Vector2(-.26,-.26),Vector2(.02,-.81),Vector2(.52,-1.04),Vector2(.92,-.67),Vector2(.72,-.20),Vector2(.83,.52)]
		"bridge": profile = [Vector2(-.94,.57),Vector2(-.97,-.62),Vector2(-.52,-.89),Vector2(-.46,-.39),Vector2(.48,-.39),Vector2(.53,-.69),Vector2(.94,-.52),Vector2(.91,.57),Vector2(.40,.57),Vector2(.28,-.06),Vector2(-.28,-.06),Vector2(-.41,.57)]
		"obelisk": profile = [Vector2(-.69,.52),Vector2(-.56,-.19),Vector2(-.17,-1.13),Vector2(.14,-1.02),Vector2(.51,-.22),Vector2(.69,.52)]
		"shutters": profile = [Vector2(-1.01,.46),Vector2(-.98,-.53),Vector2(-.72,-.83),Vector2(-.12,-.45),Vector2(.13,-.45),Vector2(.73,-.83),Vector2(.98,-.53),Vector2(1.00,.46)]
		"mast": profile = [Vector2(-.76,.53),Vector2(-.27,-.35),Vector2(-.22,-1.1),Vector2(.16,-1.14),Vector2(.20,-.36),Vector2(.99,-.57),Vector2(.69,.05),Vector2(.54,.53)]
		"shell": profile = [Vector2(-.88,.44),Vector2(-1.02,-.22),Vector2(-.71,-.60),Vector2(-.45,-.53),Vector2(-.13,-.91),Vector2(.30,-.69),Vector2(.52,-.71),Vector2(.91,-.26),Vector2(.72,.39)]
		"tusks": profile = [Vector2(-.99,.51),Vector2(-1.01,-.45),Vector2(-.76,-.97),Vector2(-.55,-.35),Vector2(-.33,-.06),Vector2(.35,-.06),Vector2(.60,-.35),Vector2(.75,-.97),Vector2(1.01,-.45),Vector2(.99,.51)]
		"icicle": profile = [Vector2(-.74,.56),Vector2(-.77,-.48),Vector2(-.44,-.38),Vector2(-.25,-1.15),Vector2(.19,-.75),Vector2(.47,-1.06),Vector2(.52,-.32),Vector2(.77,-.14),Vector2(.73,.56)]
		"sail": profile = [Vector2(-.80,.49),Vector2(-.83,-.40),Vector2(.13,-1.10),Vector2(.28,-.53),Vector2(.94,-.46),Vector2(.72,.14),Vector2(.46,.50)]
		"moonspires": profile = [Vector2(-1.0,.51),Vector2(-.78,-1.11),Vector2(-.52,-.73),Vector2(-.36,-.20),Vector2(.11,-.10),Vector2(.62,-.57),Vector2(.84,-.90),Vector2(.99,.51)]
		"arch": profile = [Vector2(-.95,.57),Vector2(-.95,-.38),Vector2(-.5,-.88),Vector2(0,-1.05),Vector2(.55,-.88),Vector2(.95,-.38),Vector2(.95,.57),Vector2(.58,.57),Vector2(.58,-.31),Vector2(0,-.64),Vector2(-.58,-.31),Vector2(-.58,.57)]
		"thornring": profile = [Vector2(-.82,.44),Vector2(-1.04,.08),Vector2(-.73,-.02),Vector2(-.82,-.64),Vector2(-.38,-.42),Vector2(0,-.84),Vector2(.35,-.46),Vector2(.78,-.65),Vector2(.75,-.05),Vector2(1.02,.07),Vector2(.82,.44)]
		"orchid": profile = [Vector2(-.52,.51),Vector2(-.37,.03),Vector2(-.99,-.32),Vector2(-.85,-.75),Vector2(-.43,-.65),Vector2(0,-1.07),Vector2(.30,-.64),Vector2(.93,-.71),Vector2(1.01,-.34),Vector2(.37,.07),Vector2(.53,.51)]
		"hourglass": profile = [Vector2(-.76,.48),Vector2(-.73,.19),Vector2(-.36,-.09),Vector2(-.68,-.47),Vector2(-.74,-.85),Vector2(.75,-.85),Vector2(.66,-.49),Vector2(.36,-.09),Vector2(.72,.19),Vector2(.76,.48)]
	if profile.is_empty():
		return
	_poly(canvas, p, r, profile, INK)
	_poly(canvas, p, r * .86, profile, stone)
	var edge := PackedVector2Array()
	for point: Vector2 in profile:
		edge.append(p + point * r * .86)
	edge.append(edge[0])
	canvas.draw_polyline(edge, Color(trim, .69), r * .058, true)
	canvas.draw_line(p + Vector2(-.44, .40) * r, p + Vector2(.44, .40) * r,
		Color(trim.lightened(.22), .58 + pulse * .35), r * .08, true)

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
