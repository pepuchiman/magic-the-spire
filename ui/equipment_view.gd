class_name EquipmentView
extends PanelContainer
## 装備1つの表示：名前、種類とレアリティ、効果（レアリティで枠の色が変わる）。
## 比較を出す時は、今の装備との差分も表示する。
## 中身はこのスクリプトが作る（new() して add_child するだけで使える）

var item: EquipmentData
var _name_label: Label
var _sub_label: Label
var _effect_label: Label
var _diff_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(0, 120)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	_name_label = _make_label(box, 30, UiPalette.TEXT)
	_sub_label = _make_label(box, 20, UiPalette.TEXT_SUB)
	_effect_label = _make_label(box, 24, UiPalette.HEAL)
	_diff_label = _make_label(box, 22, UiPalette.HIGHLIGHT)
	_diff_label.hide()
	_refresh_frame(GameEnums.Rarity.COMMON)


## 装備を表示する
func show_item(equipment: EquipmentData) -> void:
	item = equipment
	_name_label.text = UiText.t(equipment.name_key)
	_sub_label.text = UiText.fmt("UI_EQUIP_TYPE_RARITY", {
		"type": UiText.t(TextKeys.equipment_type(equipment.equipment_type)),
		"rarity": UiText.t(TextKeys.rarity(equipment.rarity))})
	var lines := UiText.equipment_effect_lines(equipment)
	if equipment.description_key != &"":
		lines.append(UiText.t(equipment.description_key))
	_effect_label.text = "\n".join(lines)
	_refresh_frame(equipment.rarity)


## 何も装備していない枠を表示する
func show_empty(type: GameEnums.EquipmentType) -> void:
	item = null
	_name_label.text = UiText.t("UI_EQUIP_EMPTY")
	_sub_label.text = UiText.t(TextKeys.equipment_type(type))
	_effect_label.text = ""
	_refresh_frame(GameEnums.Rarity.COMMON)


## 今の装備（current）との比較を表示する
func show_diff(current: EquipmentData) -> void:
	var lines := PackedStringArray()
	if current != null:
		lines.append(UiText.fmt("UI_EQUIP_COMPARE", {"name": UiText.t(current.name_key)}))
	else:
		lines.append(UiText.t("UI_EQUIP_COMPARE_NONE"))
	lines.append_array(UiText.equipment_diff_lines(current, item))
	_diff_label.text = "\n".join(lines)
	_diff_label.show()


func _refresh_frame(rarity: GameEnums.Rarity) -> void:
	add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL, UiPalette.rarity_color(rarity), 4, 14))


func _make_label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
