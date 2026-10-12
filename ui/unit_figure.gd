class_name UnitFigure
extends Control
## キャラクターの姿（絵がない間の仮の図形）。
## 正面向きは顔（目）を描き、背中向きは描かない。
## 絵を入れる時は、UnitSprite の front_texture／back_texture に画像を入れる（図形の代わりに表示される）。

enum Facing { FRONT, BACK }  # 正面・背中

## 向き
var facing: Facing = Facing.FRONT:
	set(value):
		facing = value
		queue_redraw()
## 体の色
var body_color: Color = Color.GRAY:
	set(value):
		body_color = value
		queue_redraw()
## 選べる対象として光らせるか
var highlighted: bool = false:
	set(value):
		highlighted = value
		queue_redraw()
## 図形を描くか（絵が入っている時は描かない。光る枠だけ描く）
var draw_shape: bool = true:
	set(value):
		draw_shape = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	# 体の大きさは、枠の縦横の小さいほうに合わせる（横長・縦長の枠でも形が崩れないように）
	var unit := minf(w, h * 0.8)
	var center_x := w / 2.0
	var body_w := unit * 0.7
	var body_h := h * 0.58
	var body_top := h - body_h
	var head_r := minf(unit * 0.22, body_top * 0.55)
	var head_center := Vector2(center_x, body_top - head_r * 0.5)
	if highlighted:
		var glow := UiPalette.HIGHLIGHT
		draw_rect(Rect2(Vector2(center_x - body_w / 2.0 - 6.0, head_center.y - head_r - 6.0),
			Vector2(body_w + 12.0, h - head_center.y + head_r + 6.0)), glow, false, 4.0)
	if not draw_shape:
		return
	var dark := body_color.darkened(0.35)
	# 体（下が広い台形）
	var body := PackedVector2Array([
		Vector2(center_x - body_w * 0.32, body_top),
		Vector2(center_x + body_w * 0.32, body_top),
		Vector2(center_x + body_w * 0.5, h),
		Vector2(center_x - body_w * 0.5, h),
	])
	draw_colored_polygon(body, body_color)
	# 頭
	draw_circle(head_center, head_r, body_color.lightened(0.1))
	if facing == Facing.FRONT:
		# 顔（目）
		var eye_y := head_center.y + head_r * 0.05
		var eye_dx := head_r * 0.38
		var eye_r := maxf(head_r * 0.14, 2.0)
		draw_circle(Vector2(center_x - eye_dx, eye_y), eye_r, Color.WHITE)
		draw_circle(Vector2(center_x + eye_dx, eye_y), eye_r, Color.WHITE)
	else:
		# 背中（頭の後ろの影と、背中の線）
		draw_circle(head_center + Vector2(0.0, head_r * 0.15), head_r * 0.8, dark)
		draw_line(Vector2(center_x, body_top + body_h * 0.1), Vector2(center_x, h - body_h * 0.1), dark, maxf(unit * 0.03, 2.0))
