class_name UnitFigure
extends Control
## キャラクターの姿（絵がない間の仮の図形）。
## 形は種類で変わる（魔法使い＝とんがり帽子とローブ、獣＝耳のある四つ足、精霊＝浮かぶしずく、魔獣＝角のある大きな体）。
## 正面向きは顔（目）を描き、背中向きは描かない。ボスは冠と光の輪を付ける。
## 絵を入れる時は、各データ（主人公・クリーチャー・敵）の絵の項目に画像を入れる（図形の代わりに表示される）。

enum Facing { FRONT, BACK }  # 正面・背中
enum Kind { WIZARD, BEAST, SPIRIT, MONSTER }  # 魔法使い・獣・精霊・魔獣

## 向き
var facing: Facing = Facing.FRONT:
	set(value):
		facing = value
		queue_redraw()
## 形の種類
var kind: Kind = Kind.WIZARD:
	set(value):
		kind = value
		queue_redraw()
## ボスの飾り（冠と光の輪）を付けるか
var is_boss: bool = false:
	set(value):
		is_boss = value
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

## 図形を描く枠（0〜1 の座標をこの枠に当てはめる）
var _box: Rect2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# 描く枠は縦長（横：縦＝4：5）。枠の中央・下にそろえる
	var box_w := minf(size.x, size.y * 0.8)
	var box_h := box_w * 1.25
	_box = Rect2(Vector2((size.x - box_w) / 2.0, size.y - box_h), Vector2(box_w, box_h))
	if highlighted:
		draw_rect(_box.grow(4.0), UiPalette.HIGHLIGHT, false, 4.0)
	if not draw_shape:
		return
	if is_boss:
		draw_circle(_p(0.5, 0.42), _box.size.x * 0.48, Color(UiPalette.ART_GOLD, 0.12))
	match kind:
		Kind.WIZARD:
			_draw_wizard()
		Kind.BEAST:
			_draw_beast()
		Kind.SPIRIT:
			_draw_spirit()
		Kind.MONSTER:
			_draw_monster()


# ---------- 形ごとの描き方 ----------

func _draw_wizard() -> void:
	var c := body_color
	var dark := c.darkened(0.35)
	_poly([Vector2(0.36, 0.5), Vector2(0.64, 0.5), Vector2(0.86, 1.0), Vector2(0.14, 1.0)], c)  # ローブ
	draw_circle(_p(0.5, 0.42), _w(0.15), c.lightened(0.25) if facing == Facing.FRONT else dark)  # 頭
	_poly([Vector2(0.2, 0.33), Vector2(0.8, 0.33), Vector2(0.72, 0.38), Vector2(0.28, 0.38)], dark)  # 帽子のつば
	_poly([Vector2(0.32, 0.34), Vector2(0.68, 0.34), Vector2(0.58, 0.12), Vector2(0.66, 0.02), Vector2(0.48, 0.1)], dark)  # とんがり帽子
	if facing == Facing.FRONT:
		_eyes(0.5, 0.44, 0.06)
	else:
		_line([Vector2(0.5, 0.56), Vector2(0.5, 0.95)], dark, 0.03)  # 背中の縫い目


func _draw_beast() -> void:
	var c := body_color
	var dark := c.darkened(0.35)
	for x: float in [0.28, 0.42, 0.58, 0.72]:
		_poly([Vector2(x - 0.05, 0.78), Vector2(x + 0.05, 0.78), Vector2(x + 0.05, 1.0), Vector2(x - 0.05, 1.0)], dark)  # 足
	_ellipse(0.5, 0.74, 0.36, 0.16, c)  # 胴
	if facing == Facing.BACK:
		_line([Vector2(0.5, 0.82), Vector2(0.62, 0.92), Vector2(0.7, 0.86)], dark, 0.05)  # しっぽ
	_poly([Vector2(0.3, 0.46), Vector2(0.34, 0.26), Vector2(0.44, 0.42)], c)  # 耳
	_poly([Vector2(0.7, 0.46), Vector2(0.66, 0.26), Vector2(0.56, 0.42)], c)
	draw_circle(_p(0.5, 0.52), _w(0.2), c.lightened(0.1) if facing == Facing.FRONT else dark)  # 頭
	if facing == Facing.FRONT:
		_eyes(0.5, 0.5, 0.08)
		_ellipse(0.5, 0.6, 0.07, 0.045, c.lightened(0.4))  # 鼻先


func _draw_spirit() -> void:
	var c := body_color
	_ellipse(0.5, 0.97, 0.22, 0.03, Color(0, 0, 0, 0.3))  # 浮いている影
	draw_arc(_p(0.5, 0.55), _w(0.36), 0.0, TAU, 40, Color(c.lightened(0.4), 0.45), _w(0.03), true)  # 光の輪
	_poly([Vector2(0.5, 0.18), Vector2(0.66, 0.46), Vector2(0.72, 0.62), Vector2(0.66, 0.78), Vector2(0.5, 0.86),
		Vector2(0.34, 0.78), Vector2(0.28, 0.62), Vector2(0.34, 0.46)], c)  # しずくの体
	if facing == Facing.FRONT:
		_eyes(0.5, 0.62, 0.07)
	else:
		_ellipse(0.5, 0.64, 0.1, 0.12, c.lightened(0.3))  # 背中の光


func _draw_monster() -> void:
	var c := body_color
	var dark := c.darkened(0.35)
	_poly([Vector2(0.3, 0.42), Vector2(0.7, 0.42), Vector2(0.94, 0.62), Vector2(0.84, 1.0), Vector2(0.16, 1.0), Vector2(0.06, 0.62)], c)  # 大きな体
	_poly([Vector2(0.36, 0.3), Vector2(0.22, 0.08), Vector2(0.44, 0.24)], dark.lightened(0.2))  # 角
	_poly([Vector2(0.64, 0.3), Vector2(0.78, 0.08), Vector2(0.56, 0.24)], dark.lightened(0.2))
	draw_circle(_p(0.5, 0.34), _w(0.16), c.lightened(0.1) if facing == Facing.FRONT else dark)  # 頭
	if is_boss:
		_poly([Vector2(0.36, 0.2), Vector2(0.4, 0.06), Vector2(0.46, 0.16), Vector2(0.5, 0.02), Vector2(0.54, 0.16),
			Vector2(0.6, 0.06), Vector2(0.64, 0.2)], UiPalette.ART_GOLD)  # 冠
	if facing == Facing.FRONT:
		_eyes(0.5, 0.35, 0.065)
		_line([Vector2(0.4, 0.44), Vector2(0.6, 0.44)], dark, 0.025)  # 口
	else:
		for y: float in [0.5, 0.62, 0.74]:
			_poly([Vector2(0.46, y + 0.06), Vector2(0.5, y - 0.02), Vector2(0.54, y + 0.06)], dark)  # 背中のとげ


# ---------- 描く道具 ----------

func _p(x: float, y: float) -> Vector2:
	return _box.position + Vector2(x, y) * _box.size


## 枠の幅に対する長さ
func _w(ratio: float) -> float:
	return _box.size.x * ratio


func _poly(points: Array, fill: Color) -> void:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		result.append(_p(point.x, point.y))
	draw_colored_polygon(result, fill)


func _line(points: Array, line_color: Color, width: float) -> void:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		result.append(_p(point.x, point.y))
	draw_polyline(result, line_color, maxf(_w(width), 1.5), true)


## 楕円（中心と、横・縦の半径。どれも枠に対する割合）
func _ellipse(cx: float, cy: float, rx: float, ry: float, fill: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var angle := TAU * i / 32.0
		points.append(_box.position + Vector2(cx + cos(angle) * rx, cy + sin(angle) * ry) * _box.size)
	draw_colored_polygon(points, fill)


## 白い両目（中心の位置と、目の間隔）
func _eyes(cx: float, cy: float, gap: float) -> void:
	var radius := maxf(_w(0.03), 2.0)
	draw_circle(_p(cx - gap, cy), radius, Color.WHITE)
	draw_circle(_p(cx + gap, cy), radius, Color.WHITE)
