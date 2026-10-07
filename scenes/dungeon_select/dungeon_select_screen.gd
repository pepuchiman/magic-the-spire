extends Control
## ダンジョン選択画面。ダンジョンを選んで「決定」で主人公選択へ進む。
## 未解放のダンジョンはロック表示（選べない）にして、解放条件を表示する。クリア済みには印を付ける

var selected: DungeonData
var _buttons: Dictionary = {}  # DungeonData → Button


func _ready() -> void:
	UiPalette.style_button(%BackButton, UiPalette.BUTTON)
	UiPalette.style_button(%ConfirmButton, UiPalette.BUTTON_ACCENT)
	%BackButton.pressed.connect(Game.go_to_title)
	%ConfirmButton.pressed.connect(confirm)
	for dungeon: DungeonData in _ordered_dungeons():
		var button := Button.new()
		button.text = _label_for(dungeon)
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(0, 150)
		button.add_theme_font_size_override("font_size", 30)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = not Game.is_unlocked(dungeon)
		button.pressed.connect(select.bind(dungeon))
		%DungeonList.add_child(button)
		_buttons[dungeon] = button
	for dungeon: DungeonData in _ordered_dungeons():
		if Game.is_unlocked(dungeon):
			select(dungeon)
			break


## 表示の順番：最初から選べるダンジョンを先に、解放条件のあるダンジョンを後に
func _ordered_dungeons() -> Array[DungeonData]:
	var first: Array[DungeonData] = []
	var later: Array[DungeonData] = []
	for dungeon: DungeonData in Game.data.index.dungeons:
		if dungeon.unlocked_by_clearing == &"":
			first.append(dungeon)
		else:
			later.append(dungeon)
	first.append_array(later)
	return first


func select(dungeon: DungeonData) -> void:
	if not Game.is_unlocked(dungeon):
		return
	selected = dungeon
	for key: DungeonData in _buttons:
		UiPalette.style_button(_buttons[key], UiPalette.SELECTED.darkened(0.3) if key == dungeon else UiPalette.BUTTON)
	%ConfirmButton.disabled = selected == null


func confirm() -> void:
	if selected != null:
		Game.select_dungeon(selected)


func _label_for(dungeon: DungeonData) -> String:
	var dungeon_name := UiText.t(dungeon.name_key)
	if not Game.is_unlocked(dungeon):
		return "%s %s\n%s" % [dungeon_name, UiText.t("UI_LOCKED"), UiText.unlock_condition(Game.data.get_dungeon(dungeon.unlocked_by_clearing))]
	if Game.progress.is_cleared(dungeon.id):
		return "%s %s" % [dungeon_name, UiText.t("UI_CLEARED_MARK")]
	return dungeon_name
