class_name EquipmentListPopup
extends ColorRect
## 装備中の装備（指輪・武器・鎧）の一覧。マップ画面の「装備」ボタンで開く。
## 中身はこのスクリプトが作る（new() して add_child するだけで使える）

var _list: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0, 0, 0, 0.88)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	var title := Label.new()
	title.text = "UI_EQUIPMENT_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_list)
	var close := Button.new()
	close.text = "UI_CLOSE"
	close.custom_minimum_size = Vector2(0, 90)
	close.add_theme_font_size_override("font_size", 28)
	UiPalette.style_button(close, UiPalette.BUTTON)
	close.pressed.connect(hide)
	box.add_child(close)
	hide()


func open(run: RunState) -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	for type: int in GameEnums.EquipmentType.values():
		var view := EquipmentView.new()
		_list.add_child(view)
		var item := run.get_equipped(type)
		if item != null:
			view.show_item(item)
		else:
			view.show_empty(type)
	show()
