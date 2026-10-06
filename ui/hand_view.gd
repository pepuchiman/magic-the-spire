class_name HandView
extends Control
## 手札の並び。カードが多くて横幅に収まらない時は、重ねて表示する。
## カードが押されたら card_pressed で知らせる（タップかドラッグかは画面の進行役が判断する）

signal card_pressed(card_view: CardView)

const CARD_SCENE := preload("res://ui/card_view.tscn")
const GAP := 8.0
## 手札のカードを拡大する上限
const MAX_SCALE := 1.3

var card_views: Array[CardView] = []


func _ready() -> void:
	resized.connect(_layout)


## 手札を表示し直す。playable_flags[i] が false のカードは暗く表示する
func show_cards(cards: Array[CardData], playable_flags: Array[bool], selected_indices: Array[int] = []) -> void:
	for view: CardView in card_views:
		view.queue_free()
	card_views.clear()
	for i in cards.size():
		var view: CardView = CARD_SCENE.instantiate()
		view.hand_index = i
		add_child(view)
		view.set_card(cards[i])
		view.set_playable(playable_flags[i])
		view.set_selected(selected_indices.has(i))
		view.pressed.connect(card_pressed.emit)
		card_views.append(view)
	_layout()


func get_view(hand_index: int) -> CardView:
	if hand_index < 0 or hand_index >= card_views.size():
		return null
	return card_views[hand_index]


func _layout() -> void:
	var count := card_views.size()
	if count == 0:
		return
	var card_size := CardView.BASE_SIZE
	# 手札エリアの高さに合わせて大きさを決める（大きくしすぎない）
	var scale_factor := minf(MAX_SCALE, size.y / card_size.y) if size.y > 0.0 else 1.0
	var width := card_size.x * scale_factor
	var step := width + GAP
	var total := width + step * (count - 1)
	if total > size.x and count > 1:
		step = (size.x - width) / (count - 1)  # 重ねて表示する
		total = size.x
	var start_x := (size.x - total) / 2.0
	for i in count:
		var view := card_views[i]
		view.scale = Vector2(scale_factor, scale_factor)
		view.pivot_offset = Vector2.ZERO
		var lift := -12.0 if view.selected else 0.0
		view.position = Vector2(start_x + step * i, (size.y - card_size.y * scale_factor) / 2.0 + lift)
