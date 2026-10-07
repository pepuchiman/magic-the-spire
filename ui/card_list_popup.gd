class_name CardListPopup
extends ColorRect
## 所持カードの一覧を表示する画面部品（マップ・主人公選択・休憩・イベントで使う）。
## ・見るだけの表示（open_view）：カードをタップすると拡大表示
## ・1枚選ぶ表示（open_select）：カードをタップして選び、「決定」で card_chosen を知らせる
## 画面に add_child するだけで使える（中身はこのスクリプトが作る）

## 選ぶ表示で、カードが決定された時（cards の何番目か）
signal card_chosen(index: int)
## 閉じた時（選ぶ表示でキャンセルした時も含む）
signal closed

const CARD_SCENE := preload("res://ui/card_view.tscn")
const CARD_SCALE := 1.35

var _title: Label
var _grid: GridContainer
var _confirm_button: Button
var _close_button: Button
var _zoom: CardZoomPopup
var _views: Array[CardView] = []
var _selecting: bool = false
var _selected: int = -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0, 0, 0, 0.88)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	_title = Label.new()
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 30)
	box.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_close_button = _make_button(buttons, "UI_CLOSE", UiPalette.BUTTON)
	_close_button.pressed.connect(_on_close)
	_confirm_button = _make_button(buttons, "UI_CONFIRM", UiPalette.BUTTON_ACCENT)
	_confirm_button.pressed.connect(_on_confirm)
	_zoom = CardZoomPopup.new()
	add_child(_zoom)
	_zoom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()


## 見るだけの一覧（カードをタップすると拡大表示）
func open_view(title_text: String, cards: Array[CardData]) -> void:
	_open(title_text, cards, false)


## 1枚選ぶ一覧（タップで選び、「決定」で確定。「やめる」で閉じる）
func open_select(title_text: String, cards: Array[CardData]) -> void:
	_open(title_text, cards, true)


## 選ぶ表示で、index 番目のカードを選ぶ（テストからも使う）
func select(index: int) -> void:
	if not _selecting or index < 0 or index >= _views.size():
		return
	_selected = index
	for i in _views.size():
		_views[i].set_selected(i == index)
	_confirm_button.disabled = false


func confirm() -> void:
	_on_confirm()


func _open(title_text: String, cards: Array[CardData], selecting: bool) -> void:
	_title.text = title_text
	_selecting = selecting
	_selected = -1
	for view: CardView in _views:
		view.queue_free()
	_views.clear()
	for i in cards.size():
		var view: CardView = CARD_SCENE.instantiate()
		view.card_scale = CARD_SCALE
		view.hand_index = i
		_grid.add_child(view)
		view.set_card(cards[i])
		view.pressed.connect(_on_card_pressed)
		_views.append(view)
	_confirm_button.visible = selecting
	_confirm_button.disabled = true
	_close_button.text = UiText.t("UI_CANCEL" if selecting else "UI_CLOSE")
	show()


func _on_card_pressed(view: CardView) -> void:
	if _selecting:
		select(view.hand_index)
	else:
		_zoom.open(view.card)


func _on_confirm() -> void:
	if not _selecting or _selected < 0:
		return
	var index := _selected
	hide()
	card_chosen.emit(index)


func _on_close() -> void:
	hide()
	closed.emit()


func _make_button(parent: Control, key: String, color: Color) -> Button:
	var button := Button.new()
	button.text = key
	button.custom_minimum_size = Vector2(0, 90)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 28)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiPalette.style_button(button, color)
	parent.add_child(button)
	return button
