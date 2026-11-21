class_name Glyphs
extends RefCounted

static func hue(id: String) -> Color:
	if id == "phasing":
		return Color("#75c4f6")
	var element: Dictionary = DataDB.read("elements").get(id, {})
	return Color(element.get("color", "#c1d1d4"))

static func draw(canvas: CanvasItem, id: String, p: Vector2, r: float, tint: Color) -> void:
	match id:
		"fire":
			_shape(canvas, p, r, [Vector2(0,-1), Vector2(.18,-.24), Vector2(.65,-.46), Vector2(.76,.23), Vector2(.4,.78), Vector2(-.35,.78), Vector2(-.72,.26), Vector2(-.5,-.3), Vector2(-.21,-.06)], tint)
		"water":
			_shape(canvas, p, r, [Vector2(0,-1), Vector2(.68,.08), Vector2(.61,.6), Vector2(.24,.89), Vector2(-.24,.89), Vector2(-.61,.6), Vector2(-.68,.08)], tint)
		"nature":
			_shape(canvas, p, r, [Vector2(-.52,.53), Vector2(-.72,.28), Vector2(-.72,-.02),
				Vector2(-.57,-.30), Vector2(-.30,-.52), Vector2(.08,-.65), Vector2(.52,-.73),
				Vector2(.91,-.89), Vector2(.80,-.39), Vector2(.70,.02), Vector2(.54,.35),
				Vector2(.28,.58), Vector2(-.02,.67), Vector2(-.30,.64)], tint)
			var vein: Color = tint.lightened(.60)
			canvas.draw_polyline(PackedVector2Array([p + Vector2(-.78,.83) * r, p + Vector2(-.23,.28) * r,
				p + Vector2(.17,-.10) * r, p + Vector2(.63,-.59) * r]), vein, r * .11, r > 2.0)
			canvas.draw_line(p + Vector2(-.10,.15) * r, p + Vector2(-.28,-.19) * r, vein, r * .072, r > 2.0)
			canvas.draw_line(p + Vector2(.15,-.07) * r, p + Vector2(.47,-.02) * r, vein, r * .072, r > 2.0)
		"electric":
			_shape(canvas, p, r, [Vector2(.24,-1), Vector2(-.7,.12), Vector2(-.1,.12), Vector2(-.32,1), Vector2(.74,-.23), Vector2(.14,-.23)], tint)
		"light":
			canvas.draw_circle(p, r * .44, tint, true, -1, r > 2.0)
			for i: int in range(8):
				var axis := Vector2.from_angle(TAU * i / 8.0)
				canvas.draw_line(p + axis * r * .59, p + axis * r, tint, r * .14, r > 2.0)
		"dark":
			canvas.draw_arc(p, r * .72, -.8, 3.9, 24, tint, r * .35, r > 2.0)
		"earth":
			_shape(canvas, p, r, [Vector2(-.93,.53), Vector2(-.56,-.12), Vector2(-.11,-.80),
				Vector2(.25,-.32), Vector2(.59,-.34), Vector2(.94,.53)], tint)
			canvas.draw_polyline(PackedVector2Array([p + Vector2(-.47,.48) * r, p + Vector2(-.06,-.01) * r,
				p + Vector2(.12,.21) * r, p + Vector2(.37,.05) * r]), tint.lightened(.52), r * .105, r > 2.0)
		"arrow":
			_shape(canvas, p, r, [Vector2(0,-.93), Vector2(.68,.5), Vector2(0,.24), Vector2(-.68,.5)], tint)
			canvas.draw_line(p, p + Vector2(0,.83) * r, tint, r * .22, r > 2.0)
		"cannon":
			canvas.draw_circle(p, r * .62, tint, true, -1, r > 2.0)
			canvas.draw_line(p, p + Vector2(.56,-.55) * r, tint, r * .73, r > 2.0)
			canvas.draw_circle(p + Vector2(.51,-.52) * r, r * .23, Color("#20313a"))
		_:
			_shape(canvas, p, r, [Vector2(-.68,-.66), Vector2(.68,-.66), Vector2(.61,.22), Vector2(0,.83), Vector2(-.61,.22)], tint)

static func _shape(canvas: CanvasItem, p: Vector2, r: float, points: Array[Vector2], tint: Color) -> void:
	var path := PackedVector2Array()
	for point: Vector2 in points:
		path.append(p + point * r)
	canvas.draw_colored_polygon(path, tint)
