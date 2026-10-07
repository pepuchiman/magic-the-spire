extends Control
## タイトル画面。「はじめから」でダンジョン選択へ進む。
## 「続きから」「設定」はフェーズ6で使えるようにする（今は押せない）。
## 開発用の「データをリセット」ボタンは、開発中の実行時（エディタから実行した時）だけ表示する。
## 書き出したアプリ（リリース版）では表示されない


func _ready() -> void:
	UiPalette.style_button(%NewGameButton, UiPalette.BUTTON_ACCENT)
	UiPalette.style_button(%ContinueButton, UiPalette.BUTTON)
	UiPalette.style_button(%SettingsButton, UiPalette.BUTTON)
	UiPalette.style_button(%DebugResetButton, Color(0.5, 0.2, 0.2))
	%NewGameButton.pressed.connect(_on_new_game_pressed)
	%DebugResetButton.visible = OS.is_debug_build()
	%DebugResetButton.pressed.connect(reset_data)


func _on_new_game_pressed() -> void:
	Game.go_to(Game.Screen.DUNGEON_SELECT)


## 開発用：クリアの記録（アンロックの状況）を消して、最初の状態に戻す
func reset_data() -> void:
	Game.reset_progress()
	%DebugResetButton.text = "UI_DEBUG_RESET_DONE"
	%DebugResetButton.disabled = true
