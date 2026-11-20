class_name ProjectileArt
extends RefCounted

static func style(tower: Dictionary, attack: String) -> String:
	if attack in ["shell", "pulse", "impact", "chain"]:
		return attack
	if tower.kind == "arrow":
		return "arrow"
	var traits: Dictionary = TowerRules.stats(tower).get("effect", {})
	var element: String = TowerRules.primary_element(tower)
	if element.is_empty():
		var best: float = 0.0
		var split: Dictionary = TowerRules.damage_split(tower)
		for ingredient: String in split:
			var share: float = split[ingredient]
			if share > best:
				best = share
				element = ingredient
	if element == "electric" or traits.has("chain"):
		return "chain"
	if attack == "beam":
		return "beam"
	match element:
		"fire": return "flame" if int(tower.level) >= 4 or tower.kind == "ascended" or TowerRules.is_fusion(tower) else "ember"
		"water": return "water"
		"nature": return "thorn"
		"dark": return "shadow"
		"light": return "beam"
	return attack

static func draw_stream(canvas: CanvasItem, shot: Dictionary, progress: float, life: float) -> void:
	var source: Vector2 = shot.from
	var target: Vector2 = shot.to
	var axis: Vector2 = (target - source).normalized()
	var cross_axis: Vector2 = axis.orthogonal()
	var lead: float = minf(1.0, progress * 4.2)
	var tail: float = maxf(0.0, (progress - .63) / .37)
	if lead - tail < .002 or source.is_equal_approx(target):
		return
	if String(shot.style) == "flame":
		var cloud := PackedVector2Array([source.lerp(target, tail)])
		for side: float in [-1.0, 1.0]:
			cloud.append(source.lerp(target, lead * .83) + cross_axis * .23 * side * lead)
			cloud.append(source.lerp(target, lead) + cross_axis * .1 * side)
		# The two edges are ordered around the outside of the jet.
		var cone := PackedVector2Array([cloud[0], cloud[1], cloud[2], cloud[4], cloud[3]])
		canvas.draw_colored_polygon(cone, Color("#f15c37", life * .50))
		for i: int in range(11):
			var path: float = lerpf(tail, lead, float(i + 1) / 12)
			var swirl: float = sin(float(i) * 3.7 - progress * 23.0) * .25 * path
			var point: Vector2 = source.lerp(target, path) + cross_axis * swirl
			var radius: float = (.08 + .18 * path) * life
			canvas.draw_circle(point, radius, Color("#e84f31", life * .75))
			canvas.draw_circle(point - axis * .03, radius * .63, Color("#ffbb58", life))
			canvas.draw_circle(point - axis * .06, radius * .31, Color("#fff2b4", life))
		return
	var ribbon := PackedVector2Array()
	for i: int in range(9):
		var path: float = lerpf(tail, lead, float(i) / 8)
		var wave: float = sin(path * 12.0 - progress * 29.0) * .078 * path
		ribbon.append(source.lerp(target, path) + cross_axis * wave)
	canvas.draw_polyline(ribbon, Color("#207ea9", life * .75), .17)
	canvas.draw_polyline(ribbon, Color("#73dbfb", life), .105)
	canvas.draw_polyline(ribbon, Color("#e1fbff", life), .034)
	if lead >= 1.0:
		for i: int in range(7):
			var spray: Vector2 = Vector2.from_angle(axis.angle() - 1.8 + float(i) * .60)
			var droplet: Vector2 = target + spray * progress * .48 - Vector2(0, sin(progress * PI) * .15)
			canvas.draw_circle(droplet, .064 * life, Color("#d3f7ff", life))

static func draw_missile(canvas: CanvasItem, shot: Dictionary, progress: float, life: float) -> void:
	var origin: Vector2 = shot.from
	var target: Vector2 = shot.to
	var aim: Vector2 = (target - origin).normalized()
	var side: Vector2 = aim.orthogonal()
	var flight: float = minf(1.0, progress / .76)
	var p: Vector2 = origin.lerp(target, flight)
	var tint := Color(shot.color, minf(life * 2, 1.0))
	var style_name: String = shot.style
	if flight >= 1.0:
		canvas.draw_arc(p, .10 + (progress - .76) * .86, 0, TAU, 18, tint, .055)
		if style_name != "arrow" or String(shot.element) != "":
			Glyphs.draw(canvas, String(shot.element), p, .11 * life, tint)
		return
	match style_name:
		"arrow", "thorn":
			var shaft: Color = Color("#765134") if style_name == "arrow" else Color("#365d31")
			canvas.draw_line(p - aim * .23, p, shaft, .044)
			canvas.draw_colored_polygon(PackedVector2Array([p + aim * .08, p - aim * .08 + side * .064,
				p - aim * .08 - side * .064]), tint if style_name == "arrow" else Color("#b8e070"))
			var fletching: Vector2 = p - aim * .18
			for sign_value: float in [-1.0, 1.0]:
				canvas.draw_line(fletching, fletching - aim * .078 + side * .056 * sign_value, tint, .055)
		"ember":
			for i: int in range(5):
				var trail: Vector2 = p - aim * float(i) * .056 + side * sin(progress * 22.0 + float(i)) * .035
				canvas.draw_circle(trail, .10 - float(i) * .015, Color("#ef6138", life))
			canvas.draw_circle(p, .073, Color("#ffd881"))
			canvas.draw_circle(p + aim * .025, .040, Color("#fff5ba"))
		"shadow":
			canvas.draw_circle(p, .125, Color("#51365f", life))
			canvas.draw_arc(p, .115, progress * 10.0, progress * 10.0 + 4.6, 21, Color("#e2b7fb", life), .037)
			for i: int in range(4):
				var speck: Vector2 = p - aim * (.10 + float(i) * .078) + side * .065 * sin(progress * 30 + i)
				canvas.draw_circle(speck, .045, Color(tint, life * .75))
