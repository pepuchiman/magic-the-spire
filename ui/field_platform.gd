@tool
class_name FieldPlatform
extends Control
## キャラクターが立つ「台」（楕円）。枠いっぱいに楕円を描く。
## 位置と大きさは、エディターで枠を動かして調整する。

@export var fill_color: Color = Color(0.22, 0.19, 0.36):
	set(value):
		fill_color = value
		queue_redraw()
@export var border_color: Color = Color(0.35, 0.30, 0.50):
	set(value):
		border_color = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var points := PackedVector2Array()
	var center := size / 2.0
	for i in 48:
		var angle := TAU * i / 48.0
		points.append(center + Vector2(cos(angle) * size.x / 2.0, sin(angle) * size.y / 2.0))
	draw_colored_polygon(points, fill_color)
	points.append(points[0])
	draw_polyline(points, border_color, 2.0, true)
