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
		MobArt.draw(self, enemy, center, Vector2.RIGHT, side * .38, Color.WHITE, 0, 1.3)

class UtilityIcon extends Control:
	var kind: String

	func _draw() -> void:
		var p: Vector2 = size * .5
		var ink: Color = UIKit.MINT
		if kind == "pause":
			for x: float in [-5.0, 4.0]:
				draw_rect(Rect2(p + Vector2(x - 1.5,-8), Vector2(4,16)), ink)
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

static func creature_forecast(button: Button, group: Dictionary, wave: int, total: int, icons: PackedStringArray, bosses: Array) -> void:
	var card := VBoxContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 7
	card.offset_right = -7
	card.offset_top = 4
	card.offset_bottom = -6
	card.add_theme_constant_override("separation", 1)
	button.add_child(card)
	var head: HBoxContainer = row(2)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(head)
	var wave_text: Label = label("W%d" % wave, 16, MINT if bosses.is_empty() else WARN)
	wave_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(wave_text)
	head.add_child(label("×%d" % total, 14, MUTED))
	var body := Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(body)
	var pet := ForecastPortrait.new()
	pet.enemy = group if bosses.is_empty() else bosses[0]
	pet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(pet)
	var badges: VBoxContainer = column(1)
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(badges)
	for element: String in icons:
		badges.add_child(badge(element, 13))
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
	var caption: Label = label(title, 14, INK)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(caption)
	button.tooltip_text = "Wave %d · %s · %d enemies" % [wave, description, total]

static func forecast_icons(button: Button, icons: PackedStringArray) -> void:
	if icons.is_empty():
		return
	for state: String in ["normal", "hover", "pressed"]:
		var box: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
		box.content_margin_bottom = 29.0
		box.content_margin_top = 4.0
		button.add_theme_stylebox_override(state, box)
	var badges: HBoxContainer = row(2)
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badges.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	var width: float = float(icons.size() * 25 + (icons.size() - 1) * 2)
	badges.offset_left = -width * .5
	badges.offset_right = width * .5
	badges.offset_top = -29
	badges.offset_bottom = -5
	for icon: String in icons:
		var badge := ElementBadge.new()
		badge.element = icon
		badge.custom_minimum_size = Vector2(25, 24)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badges.add_child(badge)
	button.add_child(badges)

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
