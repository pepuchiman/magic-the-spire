extends Control
## タイトル画面。
## ・「はじめから」：ダンジョン選択へ。中断データがある時は、消してよいか確認してから進む
## ・「続きから」：中断データがある時だけ押せる。保存した画面から再開する
## ・「設定」はフェーズ8で使えるようにする（今は押せない）
## ・開発用の「データをリセット」ボタンは、開発中の実行時（エディタから実行した時）だけ表示する。
##   書き出したアプリ（リリース版）では表示されない


func _ready() -> void:
	UiPalette.style_button(%NewGameButton, UiPalette.BUTTON_ACCENT)
	UiPalette.style_button(%ContinueButton, UiPalette.BUTTON_ACCENT.darkened(0.15))
	UiPalette.style_button(%SettingsButton, UiPalette.BUTTON)
	UiPalette.style_button(%DebugResetButton, Color(0.5, 0.2, 0.2))
	UiPalette.style_button(%ConfirmNoButton, UiPalette.BUTTON)
	UiPalette.style_button(%ConfirmYesButton, UiPalette.BUTTON_ACCENT)
	%ConfirmBox.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL, UiPalette.PANEL_BORDER, 3, 16))
	%NewGameButton.pressed.connect(_on_new_game_pressed)
	%ContinueButton.pressed.connect(_on_continue_pressed)
	%ConfirmNoButton.pressed.connect(%ConfirmPanel.hide)
	%ConfirmYesButton.pressed.connect(_on_confirm_new_game)
	%DebugResetButton.visible = OS.is_debug_build()
	%DebugResetButton.pressed.connect(reset_data)
	%ContinueButton.disabled = not Game.has_saved_run()


func _on_new_game_pressed() -> void:
	if Game.has_saved_run():
		%ConfirmPanel.show()  # 中断データが消えることを確認する
		return
	Game.go_to(Game.Screen.DUNGEON_SELECT)


## 確認で「はい」：中断データを消して、新しく始める
func _on_confirm_new_game() -> void:
	%ConfirmPanel.hide()
	Game.delete_saved_run()
	Game.go_to(Game.Screen.DUNGEON_SELECT)


func _on_continue_pressed() -> void:
	if not Game.continue_run():
		%ContinueButton.disabled = true  # 中断データが読み込めなかった（消えている）


## 開発用：クリアの記録（アンロックの状況）と中断データを消して、最初の状態に戻す
func reset_data() -> void:
	Game.reset_progress()
	Game.delete_saved_run()
	%ContinueButton.disabled = true
	%DebugResetButton.text = "UI_DEBUG_RESET_DONE"
	%DebugResetButton.disabled = true
