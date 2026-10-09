extends GutTest
## 翻訳の仕組みとタイトル画面のサンプルテスト

func before_each() -> void:
	TranslationServer.set_locale("ja")


func test_title_key_is_translated_to_japanese() -> void:
	assert_eq(tr("UI_NEW_GAME"), "はじめから", "キーが日本語に変換される")


func test_title_screen_shows_translated_text() -> void:
	# 本物の中断データの有無に左右されないよう、存在しないテスト用のファイルを使う
	var real_save: RunSaveStore = Game.run_save
	Game.run_save = RunSaveStore.new("user://test_no_save_here.json")
	var scene: Control = load("res://scenes/title/title_screen.tscn").instantiate()
	add_child_autofree(scene)
	var button: Button = scene.get_node("%NewGameButton")
	assert_eq(button.text, "UI_NEW_GAME", "シーンにはキーだけが入っている")
	assert_eq(button.tr(button.text), "はじめから", "キーから日本語が表示される")
	assert_true(scene.get_node("%ContinueButton").disabled, "中断データが無ければ「続きから」は押せない")
	Game.run_save = real_save
