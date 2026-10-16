@tool
class_name FieldPlatform
extends Control
## キャラクターが立つ「台」（楕円）。枠いっぱいに楕円を描く。
## 戦闘背景の絵が透けて見えるよう、半透明の影のような色にしている（色はインスペクターで変えられる）。
## 位置と大きさは、エディターで枠を動かして調整する。

@export var fill_color: Color = Color(0.06, 0.05, 0.14, 0.45):
	set(value):
		fill_color = value
		queue_redraw()
@export var border_color: Color = Color(0.75, 0.70, 1.0, 0.3):
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
