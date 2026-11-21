class_name TowerArt
extends RefCounted

const INK: Color = Color("#41372d")
const LANDMARKS: Texture2D = preload("res://assets/woodland/landmarks.png")
const PAINTED: Texture2D = preload("res://assets/woodland/towers-painted.webp")
const CELL: int = 160
const SPRITES: Dictionary = {
	"arrow": 0, "cannon": 1, "fire": 2, "water": 3, "nature": 4, "electric": 5, "light": 6,
	"dark": 7, "pure_fire": 8, "pure_water": 9, "pure_nature": 10, "pure_electric": 11, "pure_light": 12, "pure_dark": 13,
	"steam": 14, "wildfire": 15, "forge": 16, "flare": 17, "cinder": 18, "spring": 19, "storm": 20,
	"frost": 21, "venom": 22, "overgrowth": 23, "bloom": 24, "blight": 25, "prism": 26, "null": 27,
	"eclipse": 28, "boilgrove": 29, "thunderkiln": 30, "dawngeysers": 31, "smoketide": 32, "sparkthorn": 33, "daystar": 34,
	"ashorchard": 35, "arcfurnace": 36, "blackglass": 37, "embershade": 38, "monsoonroot": 39, "pearllotus": 40, "mireheart": 41,
	"glaciercoil": 42, "umbratide": 43, "moonglacier": 44, "auroraarbor": 45, "nightbriar": 46, "moonorchid": 47, "eventide": 48,
}

static func draw_landmark(canvas: CanvasItem, id: String, center: Vector2, span: Vector2) -> void:
	var column: int = 2 if id == "gate" else 3
	var region := Rect2(column * 192, 192, 192, 192)
	canvas.draw_texture_rect_region(LANDMARKS, Rect2(center - span * .5, span), region)

static func sprite_id(tower: Dictionary) -> String:
	match tower.kind:
		"arrow", "cannon": return tower.kind
		"pure": return tower.element
		"ascended": return "pure_" + String(tower.element)
	return tower.dual

static func draw(canvas: CanvasItem, tower: Dictionary, p: Vector2, r: float, clock: float,
		heading: Vector2 = Vector2.UP, recoil: float = 0.0) -> void:
	if tower.is_empty():
		return
	var ascended: bool = tower.kind == "ascended"
	var fusion: bool = TowerRules.is_fusion(tower)
	var grade: int = 7 if ascended else (int(tower.level) * 2 - 1 if fusion else int(tower.level))
	var ingredients: PackedStringArray = TowerRules.ingredients(tower)
	var tint: Color = Color("#e4c282") if ingredients.is_empty() else Glyphs.hue(ingredients[0])
	if ingredients.size() > 1:
		tint = tint.lerp(Glyphs.hue(ingredients[1]), .24)
	var scale: float = 1.0 + .045 * mini(grade - 1, 5)
	var span: float = r * 2.42 * scale
	var plinth: Vector2 = p + Vector2(0, .53) * r
	var is_launcher: bool = tower.kind in ["arrow", "cannon"]
	_oval(canvas, plinth + Vector2(.07, .09) * r, Vector2(1.03, .31) * r, Color("#2f362d", .25))
	if grade >= 3:
		_rank_stonework(canvas, plinth, r, grade, tint)
	if grade >= 5:
		var halo_color: Color = tint.lerp(Color("#ffdf91"), .64 if ascended else .36)
		canvas.draw_arc(plinth, r * 1.14, clock * .88, clock * .88 + PI * 1.4, 28, Color(halo_color, .79), r * .066, true)
		canvas.draw_arc(plinth, r * 1.07, -clock * .67, -clock * .67 + PI * .58, 16, Color(halo_color.lightened(.3), .70), r * .048, true)
	var center: Vector2 = p - Vector2(0, .19 + .022 * grade) * r - heading * recoil * r * .20
	if ingredients.has("earth") and not is_launcher:
		_draw_earth(canvas, center, r * scale, grade, ingredients, clock, heading)
	else:
		var sprite: int = int(SPRITES[sprite_id(tower)])
		var cell_origin := Vector2(sprite % 8, sprite / 8) * CELL
		var paint: Color = Color.WHITE
		if not String(tower.get("infusion", "")).is_empty():
			paint = paint.lerp(tint.lightened(.45), .31)
		if is_launcher:
			_draw_rotated(canvas, cell_origin, center, span, heading, paint)
		else:
			var rect := Rect2(center - Vector2.ONE * span * .5, Vector2.ONE * span)
			canvas.draw_texture_rect_region(PAINTED, rect, Rect2(cell_origin, Vector2.ONE * CELL), paint)
	if grade >= 4 or ascended:
		_draw_power_motes(canvas, center, r, tint, grade, clock, int(tower.id))
	if recoil > .02:
		var muzzle: Vector2 = center + heading * r * (.76 if is_launcher else .66)
		_draw_flash(canvas, muzzle, heading, r, recoil, tint)

static func _draw_earth(canvas: CanvasItem, p: Vector2, r: float, grade: int, ingredients: PackedStringArray,
		clock: float, heading: Vector2) -> void:
	var accents: PackedStringArray = ingredients.duplicate()
	accents.erase("earth")
	var stone := Color("#6f513d")
	var glow: Color = Glyphs.hue("earth").lightened(.31)
	_oval(canvas, p + Vector2(0, .56) * r, Vector2(.94, .27) * r, INK)
	_oval(canvas, p + Vector2(0, .47) * r, Vector2(.83, .23) * r, stone.lightened(.22))
	for side: float in [-1.0, 1.0]:
		var index: int = 0 if side < 0 else 1
		var color: Color = Glyphs.hue(accents[index % accents.size()]) if not accents.is_empty() else glow
		var height: float = .55 + grade * .04
		if not accents.is_empty():
			height += float(DataDB.ELEMENTS.find(accents[index % accents.size()])) * .065
		var pillar: Vector2 = p + Vector2(side * .59, .11) * r
		var edge := PackedVector2Array([pillar + Vector2(-.22, .31) * r, pillar + Vector2(-.24, -.20) * r,
			pillar + Vector2(-.04, -height) * r, pillar + Vector2(.22, -.33) * r, pillar + Vector2(.19, .33) * r])
		canvas.draw_colored_polygon(edge, stone.darkened(.23))
		canvas.draw_colored_polygon(PackedVector2Array([edge[1], edge[2], edge[3], pillar + Vector2(0, -.12) * r]), color.darkened(.29))
		canvas.draw_line(edge[1], edge[2], color.lightened(.26), r * .065, true)
		if not accents.is_empty():
			Glyphs.draw(canvas, accents[index % accents.size()], pillar - Vector2(0, .21) * r, r * .17, color.lightened(.41))
	var core: Vector2 = p + heading * (r * .12) - Vector2(0, r * .25)
	var corners := PackedVector2Array([core + Vector2(-.42,.35) * r, core + Vector2(-.50,-.25) * r,
		core + Vector2(-.14,-.64) * r, core + Vector2(.34,-.53) * r, core + Vector2(.46,-.04) * r,
		core + Vector2(.27,.40) * r])
	canvas.draw_colored_polygon(corners, stone)
	canvas.draw_colored_polygon(PackedVector2Array([corners[1], corners[2], corners[3], core]), glow)
	canvas.draw_colored_polygon(PackedVector2Array([core, corners[3], corners[4], corners[5]]), glow.darkened(.31))
	Glyphs.draw(canvas, "earth", core + Vector2(.02,.03) * r, r * .30, Color("#fff0bf"))
	if grade >= 4:
		canvas.draw_arc(core, r * .68, sin(clock * 1.4), sin(clock * 1.4) + PI * 1.26, 22, glow, r * .047, true)

static func _draw_rotated(canvas: CanvasItem, cell: Vector2, p: Vector2, span: float, up: Vector2, color: Color) -> void:
	var width := Vector2(-up.y, up.x) * span * .5
	var height: Vector2 = up * span * .5
	var positions := PackedVector2Array([p - width + height, p + width + height, p + width - height, p - width - height])
	var origin: Vector2 = cell / PAINTED.get_size()
	var size: Vector2 = Vector2.ONE * CELL / PAINTED.get_size()
	var uv := PackedVector2Array([origin, origin + Vector2(size.x, 0), origin + size, origin + Vector2(0, size.y)])
	canvas.draw_polygon(positions, PackedColorArray([color]), uv, PAINTED)

static func _rank_stonework(canvas: CanvasItem, p: Vector2, r: float, grade: int, tint: Color) -> void:
	var edge: Color = Color("#b68848") if grade >= 5 else Color("#787369")
	var face: Color = tint.darkened(.53).lerp(edge, .44)
	_oval(canvas, p, Vector2(1.11, .32) * r, INK)
	_oval(canvas, p - Vector2(0, .075) * r, Vector2(1.04, .27) * r, face)
	canvas.draw_arc(p - Vector2(0, .045) * r, r * .97, .23, PI - .23, 21, edge.lightened(.27), r * .07, true)
	for side: float in [-1.0, 1.0]:
		var shoe: Vector2 = p + Vector2(side * .83, -.075) * r
		var foot: float = .24 if grade >= 5 else .18
		_diamond(canvas, shoe, Vector2(foot, foot * .54) * r, edge)
		if grade >= 5:
			_diamond(canvas, shoe - Vector2(0, .035) * r, Vector2(.13, .08) * r, tint.lightened(.44))
		if grade >= 6:
			var crest: Vector2 = shoe + Vector2(side * .10, -.42) * r
			canvas.draw_line(shoe, crest, edge.darkened(.18), r * .15, true)
			_diamond(canvas, crest, Vector2(.14, .22) * r, edge.lightened(.4))
			_diamond(canvas, crest, Vector2(.073, .12) * r, tint.lightened(.42))

static func _draw_power_motes(canvas: CanvasItem, p: Vector2, r: float, tint: Color, grade: int, clock: float, id: int) -> void:
	var count: int = 4 if grade >= 7 else (3 if grade >= 5 else 2)
	for index: int in range(count):
		var phase: float = fposmod(clock * .82 + index / float(count) + id * .31, 1.0)
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var drift := Vector2(side * (.65 + .24 * sin(phase * TAU + index)), .34 - phase * 1.5)
		var color: Color = Color(tint.lightened(.54 if grade < 7 else .75), sin(phase * PI) * .80)
		_diamond(canvas, p + drift * r, Vector2(.056, .105) * r, color)

static func _draw_flash(canvas: CanvasItem, p: Vector2, aim: Vector2, r: float, recoil: float, tint: Color) -> void:
	var glow: Color = tint.lightened(.40)
	var side := aim.orthogonal()
	var length: float = r * (.19 + recoil * .46)
	canvas.draw_line(p - aim * r * .11, p + aim * length, Color(glow, recoil * .75), r * (.16 + .12 * recoil), true)
	for sign_x: float in [-1.0, 1.0]:
		canvas.draw_line(p, p + (aim + side * sign_x * .50) * length * .63, Color(glow, recoil * .66), r * .075, true)
	canvas.draw_circle(p, r * (.06 + recoil * .09), Color("#fff2c2", recoil), true, -1, true)

static func _oval(canvas: CanvasItem, p: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index: int in range(20):
		points.append(p + Vector2.from_angle(TAU * index / 20.0) * radii)
	canvas.draw_colored_polygon(points, color)

static func _diamond(canvas: CanvasItem, p: Vector2, radii: Vector2, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([p - Vector2(0, radii.y), p + Vector2(radii.x, 0),
		p + Vector2(0, radii.y), p - Vector2(radii.x, 0)]), color)
