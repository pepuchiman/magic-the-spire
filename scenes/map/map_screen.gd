extends Control
## マップ画面。ノードをタップすると説明が出て、「進む」で確定する（誤タップ防止）。
## マップ表示中はデッキと装備の確認だけができる

var selected_node: MapNode
var _deck_popup: CardListPopup
var _equipment_popup: EquipmentListPopup

@onready var _map_view: MapView = %MapView


func _ready() -> void:
	var run := Game.run
	%Header.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL, UiPalette.PANEL_BORDER, 2, 10))
	%InfoPanel.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL, UiPalette.PANEL_BORDER, 2, 10))
	UiPalette.style_button(%ProceedButton, UiPalette.BUTTON_ACCENT)
	UiPalette.style_button(%DeckButton, UiPalette.BUTTON)
	UiPalette.style_button(%EquipmentButton, UiPalette.BUTTON)
	%HpLabel.add_theme_color_override("font_color", UiPalette.HP.lightened(0.55))
	%HpLabel.set_fitted_text(UiText.fmt("UI_MAP_HP", {"hp": run.hp, "max": run.get_max_hp()}))
	%FloorLabel.set_fitted_text(UiText.fmt("UI_MAP_FLOOR", {"floor": run.current_floor_number(), "total": run.map.floor_count()}))
	_map_view.node_tapped.connect(select_node)
	_map_view.setup(run)
	%ProceedButton.pressed.connect(proceed)
	%DeckButton.pressed.connect(_open_deck)
	_deck_popup = CardListPopup.new()
	add_child(_deck_popup)
	_equipment_popup = EquipmentListPopup.new()
	add_child(_equipment_popup)
	%EquipmentButton.pressed.connect(func() -> void: _equipment_popup.open(Game.run))
	select_node(null)
	_scroll_to_current.call_deferred()


## ノードを選ぶ（説明を出す）。null なら案内を出す
func select_node(node: MapNode) -> void:
	selected_node = node
	_map_view.set_selected(node)
	if node == null:
		%NodeNameLabel.set_fitted_text("")
		%NodeDescLabel.set_fitted_text(UiText.t("UI_MAP_SELECT_HINT"))
		%ProceedButton.disabled = true
		return
	%NodeNameLabel.set_fitted_text(UiText.t(TextKeys.map_node(node.type)))
	%NodeDescLabel.set_fitted_text(UiText.t(TextKeys.map_node_desc(node.type)))
	%ProceedButton.disabled = not Game.run.available_nodes().has(node)


## 選んだノードへ進む
func proceed() -> void:
	if selected_node != null:
		Game.enter_node(selected_node)


## 今いる階（出発前は1階）が見えるようにスクロールする
func _scroll_to_current() -> void:
	var scroll: ScrollContainer = %MapScroll
	var nodes := Game.run.available_nodes()
	if nodes.is_empty():
		return
	var center_y := _map_view.node_center(nodes[0]).y
	scroll.scroll_vertical = int(center_y - scroll.size.y * 0.6)


func _open_deck() -> void:
	var deck := Game.run.deck
	_deck_popup.open_view(UiText.fmt("UI_DECK_LIST_TITLE", {"count": deck.size()}), deck)
