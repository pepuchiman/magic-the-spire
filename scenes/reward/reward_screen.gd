extends Control
## 報酬画面。
## 1. カード3択から1枚を取るか、スキップする（カードをタップすると拡大表示）
## 2. 装備が出た時は、今の装備との比較を見て「装備する」か「捨てる」を選ぶ
## 終わったらマップへ戻る

const CARD_SCENE := preload("res://ui/card_view.tscn")
const CARD_SCALE := 1.5

var choices: Array[CardData] = []
## このバトルで出た装備（出なければ null）
var found_equipment: EquipmentData
var _zoom: CardZoomPopup
var _equipment_box: VBoxContainer


func _ready() -> void:
	var run := Game.run
	var node_type := run.current_node.type if run.current_node != null else GameEnums.MapNodeType.BATTLE
	UiPalette.style_button(%SkipButton, UiPalette.BUTTON)
	%SkipButton.pressed.connect(skip)
	_zoom = CardZoomPopup.new()
	add_child(_zoom)
	_zoom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choices = RewardGenerator.card_choices(run, node_type)
	found_equipment = RewardGenerator.equipment_reward(run, node_type)
	for card: CardData in choices:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 12)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		var view: CardView = CARD_SCENE.instantiate()
		view.card_scale = CARD_SCALE
		column.add_child(view)
		view.set_card(card)
		view.pressed.connect(func(v: CardView) -> void: _zoom.open(v.card))
		column.add_child(_make_button("UI_TAKE", UiPalette.BUTTON_ACCENT, take.bind(card)))
		%CardRow.add_child(column)


## カードを取る
func take(card: CardData) -> void:
	RewardGenerator.take(Game.run, card)
	_after_cards()


## カードを取らない
func skip() -> void:
	RewardGenerator.skip(Game.run)
	_after_cards()


## 見つけた装備を装備する（同じ種類の装備は入れ替わる）
func equip_found() -> void:
	RewardGenerator.equip(Game.run, found_equipment)
	Game.finish_node()


## 見つけた装備を捨てる
func discard_found() -> void:
	Game.finish_node()


## カードを選び終わったら、装備が出ていれば装備の段階へ、なければマップへ
func _after_cards() -> void:
	if found_equipment == null:
		Game.finish_node()
		return
	%CardRow.hide()
	%SkipButton.hide()
	%HintLabel.text = "UI_EQUIP_FOUND"
	_equipment_box = VBoxContainer.new()
	_equipment_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equipment_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_equipment_box.add_theme_constant_override("separation", 20)
	%HintLabel.add_sibling(_equipment_box)
	var view := EquipmentView.new()
	_equipment_box.add_child(view)
	view.show_item(found_equipment)
	view.show_diff(Game.run.get_equipped(found_equipment.equipment_type))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.add_child(_make_button("UI_EQUIP_DISCARD", UiPalette.BUTTON, discard_found))
	buttons.add_child(_make_button("UI_EQUIP_TAKE", UiPalette.BUTTON_ACCENT, equip_found))
	_equipment_box.add_child(buttons)


func _make_button(key: String, color: Color, action: Callable) -> Button:
	var button := Button.new()
	button.text = key
	button.custom_minimum_size = Vector2(0, 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 28)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiPalette.style_button(button, color)
	button.pressed.connect(action)
	return button
