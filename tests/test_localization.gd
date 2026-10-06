extends GutTest
## 翻訳の仕組みとタイトル画面のサンプルテスト

func before_each() -> void:
	TranslationServer.set_locale("ja")


func test_title_key_is_translated_to_japanese() -> void:
	assert_eq(tr("UI_START"), "ゲームを始める", "キーが日本語に変換される")


func test_title_screen_shows_translated_text() -> void:
	var scene: Control = load("res://scenes/title/title_screen.tscn").instantiate()
	add_child_autofree(scene)
	var button: Button = scene.get_node("StartButton")
	assert_eq(button.text, "UI_START", "シーンにはキーだけが入っている")
	assert_eq(button.tr(button.text), "ゲームを始める", "キーから日本語が表示される")
