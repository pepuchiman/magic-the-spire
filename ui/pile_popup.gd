class_name PilePopup
extends ColorRect
## デッキ／ゴミ箱／破棄されたカードの一覧。カードをタップすると拡大表示する。
## デッキは並び順を見せないため、呼び出す側で並べ替えてから渡す

## カードがタップされた時（拡大表示用。残りの使用回数も渡す）
signal card_tapped(card: CardData, uses_left: int)

const CARD_SCENE := preload("res://ui/card_view.tscn")
const CARD_SCALE := 1.35

@onready var _title: Label = %PileTitle
@onready var _grid: GridContainer = %PileGrid
@onready var _close_button: Button = %PileCloseButton


func _ready() -> void:
	color = Color(0, 0, 0, 0.85)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_close_button.pressed.connect(hide)
	hide()


func open(title_text: String, cards: Array[CardInstance]) -> void:
	_title.text = title_text
	for child: Node in _grid.get_children():
		child.queue_free()
	for card: CardInstance in cards:
		var view: CardView = CARD_SCENE.instantiate()
		view.card_scale = CARD_SCALE
		_grid.add_child(view)
		view.set_instance(card)
		view.pressed.connect(func(v: CardView) -> void: card_tapped.emit(v.card, v.uses_left))
	show()


## デッキ用：並び順が分からないよう、名前順に並べ替える
static func sorted_by_name(cards: Array[CardInstance]) -> Array[CardInstance]:
	var sorted := cards.duplicate()
	sorted.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return UiText.t(a.data.name_key) < UiText.t(b.data.name_key))
	return sorted
