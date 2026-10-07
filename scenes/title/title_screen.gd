extends Control
## タイトル画面。「はじめから」でダンジョン選択へ進む。
## 「続きから」「設定」はフェーズ6で使えるようにする（今は押せない）


func _ready() -> void:
	UiPalette.style_button(%NewGameButton, UiPalette.BUTTON_ACCENT)
	UiPalette.style_button(%ContinueButton, UiPalette.BUTTON)
	UiPalette.style_button(%SettingsButton, UiPalette.BUTTON)
	%NewGameButton.pressed.connect(_on_new_game_pressed)


func _on_new_game_pressed() -> void:
	Game.go_to(Game.Screen.DUNGEON_SELECT)
