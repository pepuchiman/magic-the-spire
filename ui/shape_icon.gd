@tool
class_name ShapeIcon
extends Control
## 記号のアイコン（絵がない間の仮表示）。図形で記号を描く。
## texture に画像を入れると、記号の代わりにその画像を表示する。
## 種類（カード種別・状態効果・マップのマス・装備の種類）から記号を選ぶ関数もここにまとめる。

## 描く記号の名前（下の _draw_shape を参照）
@export var shape: StringName = &"ring":
	set(value):
		shape = value
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()
## 画像（あれば記号の代わりに表示する）
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(queue_redraw)


## 記号と色と画像をまとめて決める
func setup(new_shape: StringName, new_color: Color, new_texture: Texture2D = null) -> void:
	shape = new_shape
	color = new_color
	texture = new_texture


# ---------- 種類から記号を選ぶ ----------

static func card_type_shape(type: GameEnums.CardType) -> StringName:
	match type:
		GameEnums.CardType.ATTACK:
			return &"flame"
		GameEnums.CardType.BUFF:
			return &"shield"
		GameEnums.CardType.SUMMON:
			return &"ring"
	return &"vortex"


static func status_shape(type: GameEnums.StatusType) -> StringName:
	match type:
		GameEnums.StatusType.POISON:
			return &"drop"
		GameEnums.StatusType.PARALYSIS:
			return &"bolt"
		GameEnums.StatusType.WEAK:
			return &"arrow_down"
		GameEnums.StatusType.VULNERABLE:
			return &"crack"
		GameEnums.StatusType.STRENGTH:
			return &"arrow_up"
	return &"thorns"


static func map_node_shape(type: GameEnums.MapNodeType) -> StringName:
	match type:
		GameEnums.MapNodeType.BATTLE:
			return &"swords"
		GameEnums.MapNodeType.ELITE:
			return &"horns"
		GameEnums.MapNodeType.EVENT:
			return &"question"
		GameEnums.MapNodeType.REST:
			return &"campfire"
		GameEnums.MapNodeType.TREASURE:
			return &"chest"
	return &"crown"


static func equipment_shape(type: GameEnums.EquipmentType) -> StringName:
	match type:
		GameEnums.EquipmentType.WEAPON:
			return &"staff"
		GameEnums.EquipmentType.ARMOR:
			return &"robe"
	return &"ring_item"


# ---------- 描画 ----------

func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 0.0:
		return
	var origin := (size - Vector2(side, side)) / 2.0
	if texture != null:
		draw_texture_rect(texture, Rect2(origin, Vector2(side, side)), false)
		return
	_draw_shape(origin, side)


## 0〜1 の座標を、実際の位置にする
func _p(origin: Vector2, side: float, x: float, y: float) -> Vector2:
	return origin + Vector2(x, y) * side


func _poly(origin: Vector2, side: float, points: Array, fill: Color) -> void:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		result.append(_p(origin, side, point.x, point.y))
	draw_colored_polygon(result, fill)


func _line(origin: Vector2, side: float, points: Array, line_color: Color, width: float) -> void:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		result.append(_p(origin, side, point.x, point.y))
	draw_polyline(result, line_color, maxf(width * side, 1.5), true)


func _draw_shape(o: Vector2, s: float) -> void:
	var c := color
	var dark := color.darkened(0.45)
	var V := func(x: float, y: float) -> Vector2: return Vector2(x, y)
	match shape:
		&"flame":
			_poly(o, s, [V.call(0.5, 0.05), V.call(0.72, 0.35), V.call(0.8, 0.62), V.call(0.68, 0.88), V.call(0.5, 0.95), V.call(0.32, 0.88), V.call(0.2, 0.62), V.call(0.3, 0.42), V.call(0.4, 0.55)], c)
			_poly(o, s, [V.call(0.5, 0.45), V.call(0.62, 0.65), V.call(0.58, 0.85), V.call(0.5, 0.9), V.call(0.42, 0.85), V.call(0.38, 0.68)], c.lightened(0.45))
		&"shield":
			_poly(o, s, [V.call(0.5, 0.06), V.call(0.86, 0.18), V.call(0.82, 0.55), V.call(0.5, 0.94), V.call(0.18, 0.55), V.call(0.14, 0.18)], c)
			_poly(o, s, [V.call(0.5, 0.18), V.call(0.74, 0.26), V.call(0.71, 0.53), V.call(0.5, 0.8)], c.lightened(0.3))
		&"ring":
			draw_arc(_p(o, s, 0.5, 0.5), s * 0.38, 0.0, TAU, 40, c, s * 0.08, true)
			draw_arc(_p(o, s, 0.5, 0.5), s * 0.22, 0.0, TAU, 32, c.lightened(0.3), s * 0.05, true)
			for i in 6:
				var angle := TAU * i / 6.0
				draw_circle(_p(o, s, 0.5, 0.5) + Vector2(cos(angle), sin(angle)) * s * 0.38, s * 0.06, c.lightened(0.4))
		&"vortex":
			var points := PackedVector2Array()
			for i in 60:
				var t := i / 59.0
				var angle := t * TAU * 2.2
				points.append(_p(o, s, 0.5, 0.5) + Vector2(cos(angle), sin(angle)) * s * (0.05 + 0.38 * t))
			draw_polyline(points, c, s * 0.07, true)
		&"drop":
			_poly(o, s, [V.call(0.5, 0.06), V.call(0.72, 0.45), V.call(0.78, 0.65), V.call(0.7, 0.84), V.call(0.5, 0.94), V.call(0.3, 0.84), V.call(0.22, 0.65), V.call(0.28, 0.45)], c)
			draw_circle(_p(o, s, 0.4, 0.68), s * 0.07, c.lightened(0.5))
		&"bolt":
			_poly(o, s, [V.call(0.6, 0.04), V.call(0.22, 0.56), V.call(0.48, 0.56), V.call(0.38, 0.96), V.call(0.8, 0.4), V.call(0.54, 0.4)], c)
		&"arrow_down":
			_poly(o, s, [V.call(0.36, 0.08), V.call(0.64, 0.08), V.call(0.64, 0.52), V.call(0.86, 0.52), V.call(0.5, 0.94), V.call(0.14, 0.52), V.call(0.36, 0.52)], c)
		&"arrow_up":
			_poly(o, s, [V.call(0.5, 0.06), V.call(0.86, 0.48), V.call(0.64, 0.48), V.call(0.64, 0.92), V.call(0.36, 0.92), V.call(0.36, 0.48), V.call(0.14, 0.48)], c)
		&"crack":
			_poly(o, s, [V.call(0.5, 0.06), V.call(0.86, 0.18), V.call(0.82, 0.55), V.call(0.5, 0.94), V.call(0.18, 0.55), V.call(0.14, 0.18)], c)
			_line(o, s, [V.call(0.52, 0.1), V.call(0.42, 0.38), V.call(0.6, 0.52), V.call(0.46, 0.88)], dark, 0.08)
		&"thorns":
			var spikes := []
			for i in 16:
				var angle := TAU * i / 16.0 - PI / 2.0
				var radius := 0.46 if i % 2 == 0 else 0.24
				spikes.append(V.call(0.5 + cos(angle) * radius, 0.5 + sin(angle) * radius))
			_poly(o, s, spikes, c)
		&"swords":
			_line(o, s, [V.call(0.18, 0.18), V.call(0.82, 0.82)], c, 0.1)
			_line(o, s, [V.call(0.82, 0.18), V.call(0.18, 0.82)], c, 0.1)
			_line(o, s, [V.call(0.12, 0.68), V.call(0.32, 0.88)], dark.lightened(0.3), 0.1)
			_line(o, s, [V.call(0.88, 0.68), V.call(0.68, 0.88)], dark.lightened(0.3), 0.1)
		&"horns":
			draw_circle(_p(o, s, 0.5, 0.58), s * 0.3, c)
			_poly(o, s, [V.call(0.26, 0.42), V.call(0.08, 0.06), V.call(0.4, 0.32)], c)
			_poly(o, s, [V.call(0.74, 0.42), V.call(0.92, 0.06), V.call(0.6, 0.32)], c)
			draw_circle(_p(o, s, 0.4, 0.56), s * 0.06, dark)
			draw_circle(_p(o, s, 0.6, 0.56), s * 0.06, dark)
		&"question":
			draw_arc(_p(o, s, 0.5, 0.34), s * 0.2, PI, TAU + PI * 0.5, 24, c, s * 0.11, true)
			_line(o, s, [V.call(0.5, 0.53), V.call(0.5, 0.68)], c, 0.11)
			draw_circle(_p(o, s, 0.5, 0.86), s * 0.07, c)
		&"campfire":
			_line(o, s, [V.call(0.18, 0.9), V.call(0.82, 0.74)], dark.lightened(0.2), 0.09)
			_line(o, s, [V.call(0.18, 0.74), V.call(0.82, 0.9)], dark.lightened(0.2), 0.09)
			_poly(o, s, [V.call(0.5, 0.08), V.call(0.7, 0.42), V.call(0.68, 0.68), V.call(0.5, 0.78), V.call(0.32, 0.68), V.call(0.3, 0.42)], c)
			_poly(o, s, [V.call(0.5, 0.38), V.call(0.6, 0.58), V.call(0.5, 0.72), V.call(0.4, 0.58)], c.lightened(0.45))
		&"chest":
			_poly(o, s, [V.call(0.12, 0.42), V.call(0.88, 0.42), V.call(0.88, 0.86), V.call(0.12, 0.86)], c)
			_poly(o, s, [V.call(0.12, 0.42), V.call(0.2, 0.2), V.call(0.8, 0.2), V.call(0.88, 0.42)], c.lightened(0.2))
			_line(o, s, [V.call(0.12, 0.44), V.call(0.88, 0.44)], dark, 0.05)
			draw_rect(Rect2(_p(o, s, 0.44, 0.4), Vector2(0.12, 0.16) * s), dark)
		&"crown":
			_poly(o, s, [V.call(0.1, 0.8), V.call(0.1, 0.3), V.call(0.3, 0.55), V.call(0.5, 0.18), V.call(0.7, 0.55), V.call(0.9, 0.3), V.call(0.9, 0.8)], c)
			for x: float in [0.1, 0.5, 0.9]:
				draw_circle(_p(o, s, x, 0.24 if x == 0.5 else 0.3), s * 0.06, c.lightened(0.4))
		&"ring_item":
			draw_arc(_p(o, s, 0.5, 0.6), s * 0.28, 0.0, TAU, 36, c, s * 0.1, true)
			_poly(o, s, [V.call(0.5, 0.08), V.call(0.64, 0.24), V.call(0.5, 0.38), V.call(0.36, 0.24)], c.lightened(0.4))
		&"staff":
			_line(o, s, [V.call(0.3, 0.92), V.call(0.66, 0.3)], dark.lightened(0.35), 0.09)
			draw_circle(_p(o, s, 0.7, 0.22), s * 0.15, c)
			draw_circle(_p(o, s, 0.66, 0.18), s * 0.05, c.lightened(0.5))
		&"robe":
			_poly(o, s, [V.call(0.36, 0.08), V.call(0.64, 0.08), V.call(0.9, 0.36), V.call(0.78, 0.46), V.call(0.72, 0.4), V.call(0.8, 0.92), V.call(0.2, 0.92), V.call(0.28, 0.4), V.call(0.22, 0.46), V.call(0.1, 0.36)], c)
			_line(o, s, [V.call(0.5, 0.12), V.call(0.5, 0.88)], dark, 0.04)
		_:
			draw_circle(_p(o, s, 0.5, 0.5), s * 0.4, c)
