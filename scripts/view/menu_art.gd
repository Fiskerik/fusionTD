class_name MenuArt
extends Control

const GATE: Texture2D = preload("res://assets/woodland/gate.webp")
var elapsed: float = 0.0
var emblem_backdrop: StyleBoxFlat

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	var ratio: float = maxf(size.x / GATE.get_width(), size.y / GATE.get_height())
	var crop: Vector2 = size / (ratio * 1.035)
	var offset: Vector2 = (GATE.get_size() - crop) * .5
	offset.x += sin(elapsed * .16) * crop.x * .009
	draw_texture_rect_region(GATE, Rect2(Vector2.ZERO, size), Rect2(offset, crop))
	for i: int in range(12):
		var phase: float = elapsed * .65 + i * 1.91
		var p := Vector2(fposmod(i * .382 + .12, 1.0), .39 + fposmod(i * .17, .55)) * size
		p += Vector2(sin(phase) * 6, cos(phase * .9) * 9)
		var glow: float = pow((sin(phase) + 1.0) * .5, 2)
		draw_circle(p, 4.4, Color("#ffde81", glow * .23), true, -1, true)
		draw_circle(p, 1.75, Color("#fff4ab", glow * .94), true, -1, true)
	draw_rect(Rect2(Vector2.ZERO, size).grow(-2), Color("#594b38"), false, 4)
	draw_rect(Rect2(Vector2.ZERO, size).grow(-6), Color("#ffeece99"), false, 1.5)
	_draw_element_emblem()

func _draw_element_emblem() -> void:
	var count: int = DataDB.ELEMENTS.size()
	var gap: float = clampf(size.x / 16.0, 21.0, 34.0)
	var center := Vector2(size.x * .5, size.y - 28.0)
	var length: float = gap * (count + .10)
	draw_style_box(_emblem_backdrop(), Rect2(center - Vector2(length * .5, 16.0), Vector2(length, 32.0)))
	for index: int in range(count):
		var element: String = DataDB.ELEMENTS[index]
		var p: Vector2 = center + Vector2((index - (count - 1) * .5) * gap, 0.0)
		var tint: Color = Glyphs.hue(element)
		draw_circle(p, 10.5, tint.darkened(.5), true, -1, true)
		draw_circle(p, 8.8, tint, true, -1, true)
		Glyphs.draw(self, element, p, 6.1, tint.darkened(.57))

func _emblem_backdrop() -> StyleBoxFlat:
	if emblem_backdrop == null:
		emblem_backdrop = UIKit.style(Color("#253b30df"), Color("#e7cf96b0"), 16, 0)
	return emblem_backdrop
