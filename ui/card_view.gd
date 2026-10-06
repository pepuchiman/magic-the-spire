class_name CardView
extends PanelContainer
## カード1枚の表示。名前・種別・消費マナ・必要触媒・レアリティ（枠の色）・説明文を出す。
## 絵は Art（TextureRect）に画像を入れれば表示される（今は種別の色の四角形）。

## 押された時（画面の進行役が、タップかドラッグかを判断する）
signal pressed(card_view: CardView)

const BASE_SIZE := Vector2(140, 200)

## 表示の大きさ（1.0 が手札の大きさ。拡大表示などで大きくする）
@export var card_scale: float = 1.0
## 絵（あれば表示する。今は未使用）
@export var art_texture: Texture2D

var card: CardData
## 手札の何番目か（手札以外では -1）
var hand_index: int = -1
var playable: bool = true
var selected: bool = false

@onready var _cost_badge: PanelContainer = %CostBadge
@onready var _cost_label: Label = %CostLabel
@onready var _name_label: FitLabel = %NameLabel
@onready var _type_label: FitLabel = %TypeLabel
@onready var _art_background: ColorRect = %ArtBackground
@onready var _art: TextureRect = %Art
@onready var _catalysts: HBoxContainer = %Catalysts
@onready var _desc_label: FitLabel = %DescLabel


func _ready() -> void:
	_apply_scale()
	if card != null:
		refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()


func set_card(value: CardData) -> void:
	card = value
	if is_node_ready():
		refresh()


func set_playable(value: bool) -> void:
	playable = value
	_update_look()


func set_selected(value: bool) -> void:
	selected = value
	_update_look()


## 文章と見た目を作り直す（言語を切り替えた時にも呼ぶ）
func refresh() -> void:
	if card == null:
		return
	_cost_label.text = str(card.cost_mana)
	_name_label.set_fitted_text(UiText.t(card.name_key))
	_type_label.set_fitted_text("%s / %s" % [UiText.t(TextKeys.card_type(card.card_type)), UiText.t(TextKeys.rarity(card.rarity))])
	_desc_label.set_fitted_text(card.get_description())
	_art_background.color = UiPalette.card_type_color(card.card_type)
	_art.texture = art_texture
	_rebuild_catalysts()
	_update_look()


func _rebuild_catalysts() -> void:
	for child: Node in _catalysts.get_children():
		child.queue_free()
	var colors := [UiPalette.CATALYST_RED, UiPalette.CATALYST_BLUE, UiPalette.CATALYST_GREEN]
	var values := [card.required_red, card.required_blue, card.required_green]
	for i in 3:
		if values[i] <= 0:
			continue
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("panel", UiPalette.make_box(colors[i], Color.TRANSPARENT, 0, int(10 * card_scale)))
		badge.custom_minimum_size = Vector2(22, 20) * card_scale
		var label := Label.new()
		label.text = str(values[i])
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", int(13 * card_scale))
		badge.add_child(label)
		_catalysts.add_child(badge)


func _update_look() -> void:
	if card == null or not is_node_ready():
		return
	var border := UiPalette.rarity_color(card.rarity)
	var border_width := int(3 * card_scale)
	if selected:
		border = UiPalette.SELECTED
		border_width = int(5 * card_scale)
	add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL, border, border_width, int(10 * card_scale)))
	_cost_badge.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.MANA, Color.TRANSPARENT, 0, int(15 * card_scale)))
	# 使えないカードは暗く表示する
	modulate = Color(1, 1, 1) if playable else Color(0.5, 0.5, 0.55)


func _apply_scale() -> void:
	custom_minimum_size = BASE_SIZE * card_scale
	size = custom_minimum_size
	pivot_offset = custom_minimum_size / 2.0
	var margin: MarginContainer = $Margin
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(6 * card_scale))
	($Margin/VBox/Top as Control).custom_minimum_size.y = 30 * card_scale
	_cost_badge.custom_minimum_size = Vector2(30, 30) * card_scale
	_cost_label.add_theme_font_size_override("font_size", int(20 * card_scale))
	_name_label.max_font_size = int(18 * card_scale)
	_type_label.custom_minimum_size.y = 18 * card_scale
	_type_label.max_font_size = int(13 * card_scale)
	_art_background.custom_minimum_size.y = 24 * card_scale
	_catalysts.custom_minimum_size.y = 20 * card_scale
	_desc_label.max_font_size = int(14 * card_scale)
