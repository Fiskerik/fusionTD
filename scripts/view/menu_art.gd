class_name MenuArt
extends Control

const GATE: Texture2D = preload("res://assets/woodland/gate.webp")
var elapsed: float = 0.0

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
