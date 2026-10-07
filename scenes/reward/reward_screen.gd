extends Control
## 報酬画面。カード3択から1枚を取るか、スキップする。カードをタップすると拡大表示

const CARD_SCENE := preload("res://ui/card_view.tscn")
const CARD_SCALE := 1.5

var choices: Array[CardData] = []
var _zoom: CardZoomPopup


func _ready() -> void:
	UiPalette.style_button(%SkipButton, UiPalette.BUTTON)
	%SkipButton.pressed.connect(skip)
	_zoom = CardZoomPopup.new()
	add_child(_zoom)
	_zoom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choices = RewardGenerator.card_choices(Game.run)
	for card: CardData in choices:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 12)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		var view: CardView = CARD_SCENE.instantiate()
		view.card_scale = CARD_SCALE
		column.add_child(view)
		view.set_card(card)
		view.pressed.connect(func(v: CardView) -> void: _zoom.open(v.card))
		var take_button := Button.new()
		take_button.text = "UI_TAKE"
		take_button.custom_minimum_size = Vector2(0, 90)
		take_button.add_theme_font_size_override("font_size", 28)
		take_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiPalette.style_button(take_button, UiPalette.BUTTON_ACCENT)
		take_button.pressed.connect(take.bind(card))
		column.add_child(take_button)
		%CardRow.add_child(column)


## カードを取ってマップへ戻る
func take(card: CardData) -> void:
	RewardGenerator.take(Game.run, card)
	Game.finish_node()


## 何も取らずにマップへ戻る
func skip() -> void:
	RewardGenerator.skip(Game.run)
	Game.finish_node()
