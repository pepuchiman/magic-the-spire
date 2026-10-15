@tool
class_name BattleBackground
extends Control
## 戦闘画面の背景。ダンジョンのデータに背景の絵があれば絵を、なければ2色のグラデーションを表示する。
## グラデーションは、キャラクターが立つ中央を少し暗くして、キャラクターを見やすくする。

@export var top_color: Color = UiPalette.ART_NIGHT_PURPLE:
	set(value):
		top_color = value
		queue_redraw()
@export var bottom_color: Color = UiPalette.ART_INDIGO:
	set(value):
		bottom_color = value
		queue_redraw()
## 背景の絵（あれば、画面いっぱいに表示する。縦横の比率は保ち、はみ出た分は切る）
@export var texture: Texture2D:
	set(value):
		texture = value
		if _art != null:
			_art.texture = value
		queue_redraw()

var _art: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art = TextureRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.texture = texture
	add_child(_art)
	resized.connect(queue_redraw)


## ダンジョンの見た目にする（null ならそのまま）
func setup(dungeon: DungeonData) -> void:
	if dungeon == null:
		return
	top_color = dungeon.background_top
	bottom_color = dungeon.background_bottom
	texture = dungeon.background


func _draw() -> void:
	if texture != null:
		return
	var middle := top_color.lerp(bottom_color, 0.5).darkened(0.3)
	var half := size.y * 0.45
	_gradient(0.0, half, top_color, middle)
	_gradient(half, size.y, middle, bottom_color)


## 上から下へ色が変わる帯
func _gradient(from_y: float, to_y: float, from_color: Color, to_color: Color) -> void:
	var points := PackedVector2Array([Vector2(0, from_y), Vector2(size.x, from_y), Vector2(size.x, to_y), Vector2(0, to_y)])
	draw_polygon(points, PackedColorArray([from_color, from_color, to_color, to_color]))
