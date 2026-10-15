extends GutTest
## カードの表示のテスト。全カードの文章が枠に収まるか（カードを追加した時のはみ出しに気づくため）

const CARD_SCENE := preload("res://ui/card_view.tscn")


func before_each() -> void:
	TranslationServer.set_locale("ja")


func test_all_card_texts_fit_in_hand_size() -> void:
	var loader := DataLoader.new()
	var views: Array[CardView] = []
	for card: CardData in loader.index.cards:
		var view: CardView = CARD_SCENE.instantiate()
		view.uses_left = 1  # 残り回数の文字も出した状態で確かめる
		add_child_autofree(view)
		view.set_card(card)
		views.append(view)
	await wait_frames(3)  # 文字の大きさの調整（次のフレームで行う）を待つ
	for view: CardView in views:
		var id := view.card.id
		assert_eq(view.size, CardView.BASE_SIZE, "%s：カードの大きさが変わらない（中身がはみ出していない）" % id)
		for label_name: String in ["%NameLabel", "%DescLabel"]:
			var label: FitLabel = view.get_node(label_name)
			assert_true(label._fits(label.get_theme_font("font"), label.atr(label.text), label.get_theme_font_size("font_size")),
				"%s：%s の文章が枠に収まる（%s）" % [id, label_name, label.atr(label.text)])


func test_art_area_is_large() -> void:
	var view: CardView = CARD_SCENE.instantiate()
	add_child_autofree(view)
	view.set_card(DataLoader.new().get_card(&"fireball"))
	await wait_frames(2)
	var art: Control = view.get_node("%ArtBackground")
	assert_gte(art.size.y, CardView.ART_HEIGHT, "絵の枠は決めた高さ以上")
	assert_gte(art.size.y * art.size.x, view.size.x * view.size.y * 0.4, "絵の枠はカードの面積の4割以上")


func test_catalysts_and_uses_are_on_the_art() -> void:
	var view: CardView = CARD_SCENE.instantiate()
	view.uses_left = 2
	add_child_autofree(view)
	var card := DataLoader.new().get_card(&"fireball")
	view.set_card(card)
	await wait_frames(2)
	var art: Control = view.get_node("%ArtBackground")
	assert_eq(view.get_node("%Catalysts").get_parent(), art, "必要触媒の印は絵に重ねる")
	assert_eq(view.get_node("%Catalysts").get_child_count(), int(card.required_red > 0) + int(card.required_blue > 0) + int(card.required_green > 0))
	assert_true(view.get_node("%UsesLabel").visible, "使用回数のあるカードは残り回数を出す")
	view.uses_left = -1
	view.refresh()
	assert_false(view.get_node("%UsesLabel").visible, "制限のないカードは出さない")
