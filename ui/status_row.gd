class_name StatusRow
extends HFlowContainer
## 状態効果の一覧を「印＋文字」で横に並べる表示（枠の幅で折り返す）。
## 印は、アイコンの一覧（data/config/icon_set.tres）に画像があれば画像、なければ図形の記号。
## アーマーも並べられる（クリーチャーの足元の表示で使う）

## 文字の大きさ（印の大きさも合わせて変わる）
@export var font_size: int = 14

## 今並んでいる文字（テストや確認用）
var texts: PackedStringArray = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("h_separation", 8)
	add_theme_constant_override("v_separation", 2)


## キャラクターの状態効果を並べ直す。armor が 0 より大きければ、先頭にアーマーも並べる
func show_combatant(combatant: Combatant, armor: int = 0) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	texts.clear()
	if combatant == null:
		return
	if armor > 0:
		_add_chip(&"shield", UiPalette.ARMOR, null, UiText.fmt("UI_ARMOR", {"armor": armor}), UiPalette.ARMOR)
	for type: int in GameEnums.StatusType.values():
		var status: StatusInstance = combatant.statuses.get(type)
		if status != null:
			_add_chip(ShapeIcon.status_shape(type), UiPalette.status_color(type), UiIcons.status(type),
				UiText.status_line(status), UiPalette.TEXT_SUB)
	for modifier: StatModifier in combatant.modifiers:
		var line := UiText.modifier_line(modifier)
		if line != "":
			var up := modifier.amount >= 0
			_add_chip(&"arrow_up" if up else &"arrow_down", UiPalette.HEAL if up else UiPalette.DAMAGE, null, line, UiPalette.TEXT_SUB)


func _add_chip(shape: StringName, color: Color, texture: Texture2D, text: String, text_color: Color) -> void:
	var chip := HBoxContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_constant_override("separation", 2)
	var icon := ShapeIcon.new()
	icon.custom_minimum_size = Vector2(font_size, font_size) * 1.15
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.setup(shape, color, texture)
	chip.add_child(icon)
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", text_color)
	chip.add_child(label)
	add_child(chip)
	texts.append(text)

