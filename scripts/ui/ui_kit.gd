class_name UIKit
extends RefCounted

const INK: Color = Color("#2f463b")
const MUTED: Color = Color("#526e60")
const MINT: Color = Color("#387861")
const GOLD: Color = Color("#f7ca75")
const BORDER: Color = Color("#c8d9bf")
const SURFACE: Color = Color("#fdfbef")
const BACK: Color = Color("#edf4df")
const WARN: Color = Color("#a44c38")
const UPGRADE: Color = Color("#8b541d")
static var heading_font: SystemFont
static var body_font: SystemFont
static var background_texture: GradientTexture2D

class TouchButton extends Button:
	var feedback: Tween

	func _ready() -> void:
		button_down.connect(_press_feedback.bind(true))
		button_up.connect(_press_feedback.bind(false))

	func _press_feedback(down: bool) -> void:
		if feedback:
			feedback.kill()
		pivot_offset = size * .5
		feedback = create_tween()
		feedback.tween_property(self, "scale", Vector2.ONE * (.965 if down else 1.0), .065 if down else .15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

class ElementBadge extends Control:
	var element: String

	func _draw() -> void:
		var tint: Color = Glyphs.hue(element)
		var center: Vector2 = size * .5
		var radius: float = minf(size.x, size.y) * .44
		draw_circle(center + Vector2(0, 1.5), radius, tint.darkened(.30), true, -1, true)
		draw_circle(center, radius, tint.lerp(Color("#fff9df"), .27), true, -1, true)
		Glyphs.draw(self, element, center, radius * .62, tint.darkened(.47))

class TowerPortrait extends Control:
	var tower: Dictionary

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		resized.connect(queue_redraw)

	func _draw() -> void:
		var radius: float = minf(size.x, size.y) * .36
		var p: Vector2 = size * .5
		draw_circle(p, radius * 1.28, Color("#e5edcf"), true, -1, true)
		TowerArt.draw(self, tower, p + Vector2(0, radius * .17), radius, 1.34)

class ForecastPortrait extends Control:
	var enemy: Dictionary

	func _draw() -> void:
		var side: float = minf(size.x, size.y)
		if side <= 0.0:
			return
		var center: Vector2 = size * .5
		if enemy.kind == "spirit":
			var tint: Color = Glyphs.hue(enemy.element)
			draw_circle(center, side * .32, tint.lightened(.29), true, -1, true)
			Glyphs.draw(self, enemy.element, center, side * .21, tint.darkened(.43))
		else:
			if enemy.kind == "bonus":
				draw_circle(center, side * .44, Color("#fff0ae"), true, -1, true)
			var direction: Vector2 = Vector2.UP if enemy.kind == "boss" else Vector2.RIGHT
			if enemy.get("boss_type", "") in ["warlock", "necromancer"]:
				direction = Vector2.DOWN
			MobArt.draw(self, enemy, center, direction, side * (.31 if enemy.kind == "boss" else .38), Color.WHITE, 0, 1.3)

class UtilityIcon extends Control:
	var kind: String

	func _draw() -> void:
		var p: Vector2 = size * .5
		var ink: Color = UIKit.MINT
		if kind == "damage":
			var blade := PackedVector2Array([p + Vector2(-3, 1), p + Vector2(3, -6),
				p + Vector2(8, -8), p + Vector2(6, -3), p + Vector2(0, 4)])
			draw_colored_polygon(blade, ink)
			draw_line(p + Vector2(-6, -1), p + Vector2(2, 7), ink, 1.7, true)
			draw_line(p + Vector2(-3, 4), p + Vector2(-7, 8), ink, 2, true)
		elif kind == "range":
			draw_arc(p, 6.2, 0, TAU, 22, ink, 1.5, true)
			for axis: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(p + axis * 4.5, p + axis * 8.2, ink, 1.5, true)
			draw_circle(p, 1.3, ink, true, -1, true)
		elif kind == "speed":
			draw_arc(p + Vector2(0, 1), 6.1, 0, TAU, 24, ink, 1.5, true)
			draw_line(p + Vector2(-2.3, -7.3), p + Vector2(2.3, -7.3), ink, 1.6, true)
			draw_line(p + Vector2(0, 1), p + Vector2(2.7, -2), ink, 1.5, true)
		elif kind == "splash":
			for radius: float in [3.2, 6.0, 8.4]:
				draw_arc(p + Vector2(0, 4), radius, PI * 1.14, PI * 1.86, 12, ink, 1.4, true)
		elif kind == "menu":
			for y: float in [-6.0, 0.0, 6.0]:
				draw_line(p + Vector2(-9, y), p + Vector2(9, y), ink, 2.4, true)
		elif kind == "health":
			draw_circle(p + Vector2(-3.4, -2.3), 4.1, Color("#b9594d"), true, -1, true)
			draw_circle(p + Vector2(3.4, -2.3), 4.1, Color("#b9594d"), true, -1, true)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-7.2, -.8), p + Vector2(7.2, -.8), p + Vector2(0, 7.1)]), Color("#b9594d"))
		elif kind == "armor":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-6,-6), p + Vector2(6,-6), p + Vector2(5,2),
				p + Vector2(0,8), p + Vector2(-5,2)]), ink)
			draw_line(p + Vector2(0,-4), p + Vector2(0,4), Color("#d8eadb"), 1.3, true)
		elif kind == "gold":
			draw_circle(p, 7.2, UIKit.UPGRADE, true, -1, true)
			draw_circle(p, 5.6, UIKit.GOLD, true, -1, true)
			draw_line(p + Vector2(0, -3.4), p + Vector2(0, 3.4), UIKit.UPGRADE, 1.5, true)
		elif kind == "info":
			draw_arc(p, 10, 0, TAU, 26, ink, 1.9, true)
			draw_circle(p + Vector2(0,-4), 1.30, ink, true, -1, true)
			draw_line(p + Vector2(0,-.1), p + Vector2(0,4.5), ink, 2.2, true)
		elif kind == "chart":
			for index: int in range(3):
				var height: float = [7.0, 12.0, 18.0][index]
				draw_rect(Rect2(p + Vector2(-10.0 + 7.0 * index, 8.0 - height), Vector2(5, height)), ink)
			draw_line(p + Vector2(-11, 10), p + Vector2(11, 10), ink, 1.2, true)
		else:
			draw_polyline(PackedVector2Array([p + Vector2(0,-7), p + Vector2(-10,-10), p + Vector2(-10,6),
				p + Vector2(0,9), p + Vector2(10,6), p + Vector2(10,-10), p + Vector2(0,-7), p + Vector2(0,9)]),
				ink, 2.0, true)
			for side: float in [-1.0, 1.0]:
				draw_line(p + Vector2(side * 3,-3), p + Vector2(side * 7,-5), ink, 1.5, true)

static func stat_value(kind: String, value: String, hint: String, font_size: int, tint: Color,
		support: String = "") -> HBoxContainer:
	var item: HBoxContainer = row(3)
	item.name = kind.capitalize()
	item.tooltip_text = hint
	var icon := UtilityIcon.new()
	icon.kind = kind
	icon.custom_minimum_size = Vector2(19, 19)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(icon)
	var amount: Label = label(value, font_size, tint)
	amount.name = "Value"
	item.add_child(amount)
	if not support.is_empty():
		var bonus: Label = label(support, font_size, Color("#28754f"))
		bonus.name = "SupportBonus"
		bonus.add_theme_font_override("font", heading())
		var background: StyleBoxFlat = style(Color("#ecf5df"), Color("#ccdfbd"), 7, 1)
		background.content_margin_left = 4
		background.content_margin_right = 4
		bonus.add_theme_stylebox_override("normal", background)
		item.add_child(bonus)
		item.tooltip_text += " · Support " + support
	return item

static func icon_button(kind: String, hint: String, callback: Callable, height: int = 45) -> Button:
	var control: Button = button("", callback, false, height)
	control.custom_minimum_size.x = 50
	control.size_flags_horizontal = Control.SIZE_FILL
	control.tooltip_text = hint
	control.name = hint
	var icon := UtilityIcon.new()
	icon.kind = kind
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.add_child(icon)
	return control

static func portrait(tower: Dictionary, side: float = 70.0) -> Control:
	var image := TowerPortrait.new()
	image.tower = tower
	image.custom_minimum_size = Vector2(side, side)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

static func heading() -> SystemFont:
	if heading_font == null:
		heading_font = SystemFont.new()
		heading_font.font_names = PackedStringArray(["Avenir Next", "Trebuchet MS", "Noto Sans", "Verdana"])
		heading_font.font_weight = 700
	return heading_font

static func body_typeface() -> SystemFont:
	if body_font == null:
		body_font = heading().duplicate()
		body_font.font_weight = 400
	return body_font

static func style(fill: Color, stroke: Color, curve: int = 12, padding: int = 12) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = stroke
	result.set_border_width_all(2)
	result.set_corner_radius_all(curve)
	result.content_margin_left = padding
	result.content_margin_right = padding
	result.content_margin_top = padding
	result.content_margin_bottom = padding
	return result

static func label(value: String, font_size: int = 22, tint: Color = INK, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", tint)
	l.add_theme_font_override("font", heading() if font_size >= 26 else body_typeface())
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func button(value: String, callback: Callable, primary: bool = false, height: int = 64) -> Button:
	var b := TouchButton.new()
	b.text = value
	b.custom_minimum_size.y = height
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_font_override("font", heading())
	var edge: Color = Color("#daa054") if primary else BORDER
	var fill: Color = GOLD if primary else SURFACE
	b.add_theme_stylebox_override("normal", raised(fill, edge))
	b.add_theme_stylebox_override("hover", raised(fill.lightened(.18), MINT))
	b.add_theme_stylebox_override("pressed", style(fill.darkened(.065), MINT, 16, 8))
	b.add_theme_stylebox_override("disabled", style(Color("#e9eddf"), Color("#d9e1d2"), 16, 8))
	b.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, MINT, 16, 8))
	b.add_theme_color_override("font_disabled_color", Color("#66786d"))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, Color("#4a3522") if primary else INK)
	if callback.is_valid():
		b.pressed.connect(callback)
	return b

static func raised(fill: Color, edge: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = style(fill, edge, 16, 8)
	box.border_width_bottom = 4
	box.shadow_color = Color("#485c3d24")
	box.shadow_size = 2
	box.shadow_offset = Vector2(0, 3)
	return box

static func element_button(button: Button, element: String, show_badge: bool = false, compact: bool = false) -> void:
	var tint: Color = Glyphs.hue(element)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var fill: Color = tint.lerp(SURFACE, .80 if state == "normal" else .63)
		var card: StyleBoxFlat = raised(fill, tint.lerp(MUTED, .42))
		if show_badge:
			card.content_margin_top = 27 if compact else 42
		if compact:
			card.content_margin_left = 2
			card.content_margin_right = 2
			card.content_margin_bottom = 4
		if state == "focus":
			card.bg_color = Color.TRANSPARENT
			card.border_color = MINT
		button.add_theme_stylebox_override(state, card)
	if compact:
		var disabled: StyleBoxFlat = style(tint.lerp(BACK, .92), BORDER, 14, 2)
		disabled.content_margin_top = 27
		button.add_theme_stylebox_override("disabled", disabled)
	if not show_badge:
		return
	var badge := ElementBadge.new()
	badge.element = element
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	badge.offset_left = -12 if compact else -19
	badge.offset_right = 12 if compact else 19
	badge.offset_top = 3 if compact else 5
	badge.offset_bottom = 27 if compact else 43
	button.add_child(badge)

static func badge(id: String, side: float = 25.0) -> Control:
	var icon := ElementBadge.new()
	icon.element = id
	icon.custom_minimum_size = Vector2(side, side)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

static func composition(tower: Dictionary, side: float = 23.0, names: bool = true) -> HBoxContainer:
	var icons: PackedStringArray = TowerRules.ingredients(tower)
	if tower.kind in ["arrow", "cannon"]:
		icons.insert(0, tower.kind)
	var result: HBoxContainer = row(4)
	result.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for id: String in icons:
		if result.get_child_count() > 0:
			result.add_child(label("+", 14, MUTED))
		result.add_child(badge(id, side))
		if names:
			result.add_child(label(id.capitalize(), 15, Glyphs.hue(id).darkened(.61)))
	return result

static func toggle_row(title: String, active: bool, callback: Callable) -> HBoxContainer:
	var result: HBoxContainer = row(12)
	var text: Label = label(title, 19)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_child(text)
	var toggle: Button = button("●  On" if active else "○  Off", callback, active, 48)
	toggle.name = title
	toggle.custom_minimum_size.x = 96
	toggle.size_flags_horizontal = Control.SIZE_FILL
	toggle.toggle_mode = true
	toggle.set_pressed_no_signal(active)
	result.add_child(toggle)
	return result

static func creature_forecast(button: Button, group: Dictionary, wave: int, total: int, icons: PackedStringArray, bosses: Array, wave_caption: String = "") -> void:
	var card: HBoxContainer = row(3)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 5
	card.offset_right = -5
	card.offset_top = 4
	card.offset_bottom = -4
	button.add_child(card)
	var pet := ForecastPortrait.new()
	pet.enemy = group if bosses.is_empty() else bosses[0]
	pet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pet.custom_minimum_size = Vector2(33, 0)
	card.add_child(pet)
	var details: VBoxContainer = column(1)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(details)
	var head: HBoxContainer = row(2)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(head)
	var wave_text: Label = label("W%d" % wave if wave_caption.is_empty() else wave_caption, 15, MINT if bosses.is_empty() else WARN)
	wave_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(wave_text)
	for element: String in icons:
		head.add_child(badge(element, 12))
	head.add_child(label("×%d" % total, 13, MUTED))
	var title: String = StatusInfo.enemy_name(pet.enemy)
	var description: String = title
	if bosses.size() == 1:
		title = "Boss · " + title
	elif bosses.size() > 1:
		title = "%d bosses" % bosses.size()
		var names := PackedStringArray()
		for boss: Dictionary in bosses:
			names.append(StatusInfo.enemy_name(boss))
		description = " / ".join(names)
	var caption: Label = label(title, 13, INK)
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.add_child(caption)
	var round_name: String = "Wave %d" % wave if wave_caption.is_empty() else wave_caption
	button.tooltip_text = "%s · %s · %d enemies" % [round_name, description, total]

static func gate_fill(ratio: float) -> Color:
	if ratio <= .25:
		return Color("#ec7357")
	if ratio <= .55:
		return Color("#f6c05b")
	return Color("#a1da82")

static func column(gap: int = 10) -> VBoxContainer:
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", gap)
	return layout

static func row(gap: int = 10) -> HBoxContainer:
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", gap)
	return layout

static func clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

static func screen_background(parent: Control) -> void:
	if background_texture == null:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color("#fbf1da"), Color("#e0ebd8")])
		background_texture = GradientTexture2D.new()
		background_texture.gradient = gradient
		background_texture.fill_from = Vector2(.05, 0)
		background_texture.fill_to = Vector2(.94, 1)
	var background := TextureRect.new()
	background.texture = background_texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(background)

static func screen_margin(parent: Control, margin: int) -> MarginContainer:
	var result := MarginContainer.new()
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets := Vector4.ZERO
	if OS.has_feature("mobile"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var window_size := Vector2(DisplayServer.window_get_size())
		if safe.size.x > 0 and window_size.x > 0 and window_size.y > 0:
			var factor: Vector2 = parent.get_viewport_rect().size / window_size
			var screen_size: Vector2i = DisplayServer.screen_get_size()
			insets = Vector4(safe.position.x * factor.x, safe.position.y * factor.y, (screen_size.x - safe.end.x) * factor.x, (screen_size.y - safe.end.y) * factor.y)
	var edges: Array[String] = ["left", "top", "right", "bottom"]
	for index: int in range(edges.size()):
		result.add_theme_constant_override("margin_" + edges[index], margin + maxi(0, roundi(insets[index])))
	parent.add_child(result)
	return result

static func dialog(parent: Control, width: float) -> Dictionary:
	var shade := ColorRect.new()
	shade.color = Color(0.12, .24, .20, .53)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shade)
	var card := PanelContainer.new()
	var card_style: StyleBoxFlat = style(SURFACE, BORDER, 26, 22)
	card_style.shadow_color = Color("#223c3255")
	card_style.shadow_size = 10
	card_style.shadow_offset = Vector2(0, 5)
	card.add_theme_stylebox_override("panel", card_style)
	var available: Vector2 = parent.get_viewport_rect().size
	card.custom_minimum_size = Vector2(minf(width, available.x - 38.0), 0)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	center.add_child(card)
	var stack: VBoxContainer = column(12)
	card.add_child(stack)
	shade.modulate.a = 0.0
	shade.create_tween().tween_property(shade, "modulate:a", 1.0, .14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return {"overlay": shade, "body": stack}
