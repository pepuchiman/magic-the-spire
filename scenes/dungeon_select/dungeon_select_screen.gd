extends Control
## ダンジョン選択画面。ダンジョンを選んで「決定」で主人公選択へ進む。
## （未アンロックのダンジョンのロック表示はフェーズ5で追加する）

var selected: DungeonData
var _buttons: Dictionary = {}  # DungeonData → Button


func _ready() -> void:
	UiPalette.style_button(%BackButton, UiPalette.BUTTON)
	UiPalette.style_button(%ConfirmButton, UiPalette.BUTTON_ACCENT)
	%BackButton.pressed.connect(Game.go_to_title)
	%ConfirmButton.pressed.connect(confirm)
	for dungeon: DungeonData in Game.data.index.dungeons:
		var button := Button.new()
		button.text = UiText.t(dungeon.name_key)
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(0, 140)
		button.add_theme_font_size_override("font_size", 34)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(select.bind(dungeon))
		%DungeonList.add_child(button)
		_buttons[dungeon] = button
	if not Game.data.index.dungeons.is_empty():
		select(Game.data.index.dungeons[0])


func select(dungeon: DungeonData) -> void:
	selected = dungeon
	for key: DungeonData in _buttons:
		UiPalette.style_button(_buttons[key], UiPalette.SELECTED.darkened(0.3) if key == dungeon else UiPalette.BUTTON)
	%ConfirmButton.disabled = selected == null


func confirm() -> void:
	if selected != null:
		Game.select_dungeon(selected)
