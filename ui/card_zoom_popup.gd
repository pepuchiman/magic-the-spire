class_name CardZoomPopup
extends ColorRect
## カードの拡大表示。画面のどこかをタップすると閉じる

const CARD_SCENE := preload("res://ui/card_view.tscn")
const ZOOM := 2.4

var _view: CardView


func _ready() -> void:
	color = Color(0, 0, 0, 0.7)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


## uses_left：残りの使用回数（-1 なら表示しない）
func open(card: CardData, uses_left: int = -1) -> void:
	if _view != null:
		_view.queue_free()
	_view = CARD_SCENE.instantiate()
	_view.card_scale = ZOOM
	_view.uses_left = uses_left
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_view.set_card(card)
	_view.position = (size - CardView.BASE_SIZE * ZOOM) / 2.0
	show()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide()
		accept_event()
