extends GutTest
## バトル画面のテスト（画面なしで動かす。演出は待たずに進める設定にする）

const SCREEN_SCENE := preload("res://scenes/battle/battle_screen.tscn")
const H := preload("res://tests/battle_test_helper.gd")

var screen: BattleScreen


func before_each() -> void:
	TranslationServer.set_locale("ja")
	screen = SCREEN_SCENE.instantiate()
	screen.animation_speed = 0.0
	screen.seed_value = 1
	add_child_autofree(screen)


func test_can_play_battle_to_the_end_through_screen() -> void:
	for step in 500:
		if screen.mode == BattleScreen.Mode.ENDED:
			break
		if screen.mode == BattleScreen.Mode.DISCARD_SELECT:
			for i in screen.battle.pending_discard_count:
				screen.toggle_discard(i)
			screen.confirm_discard()
			continue
		if not _play_any_card():
			screen.request_end_turn()
	assert_eq(screen.mode, BattleScreen.Mode.ENDED, "画面の操作だけでバトルが最後まで進む")
	assert_true(screen.get_node("%ResultOverlay").visible, "勝敗が表示される")


func test_unplayable_cards_are_dimmed() -> void:
	screen.battle.hero.mana = 0
	screen._refresh_all()
	for view: CardView in screen.get_node("%HandArea").card_views:
		assert_eq(view.playable, view.card.cost_mana == 0, "マナが足りないカードは暗く表示される")


func test_discard_selection_flow() -> void:
	var extra := screen.battle.deck.hand[0].data
	for i in 3:
		screen.battle.deck.hand.append(CardInstance.new(extra))  # 手札を6枚にする（最大5枚）
	screen.request_end_turn()
	assert_eq(screen.mode, BattleScreen.Mode.DISCARD_SELECT, "捨てるカードの選択に切り替わる")
	screen.confirm_discard()
	assert_eq(screen.mode, BattleScreen.Mode.DISCARD_SELECT, "必要な枚数を選ぶまで決定できない")
	screen.toggle_discard(0)
	screen.toggle_discard(1)
	assert_eq(screen._discard_selection.size(), 1, "必要な枚数より多くは選べない")
	screen.confirm_discard()
	assert_ne(screen.mode, BattleScreen.Mode.DISCARD_SELECT, "決定するとターンが進む")
	assert_eq(screen.battle.turn, 2)


func test_replace_selection_flow() -> void:
	var battle := screen.battle
	for i in Battle.MAX_ALLIES:
		battle.allies.append(AllyCombatant.new(H.ally(StringName("a%d" % i)), 1))
	var sprite_card := DataLoader.new().get_card(&"summon_sprite")
	battle.deck.hand.append(CardInstance.new(sprite_card))
	battle.hero.catalyst_red = 5
	screen._refresh_all()
	var index := battle.deck.hand.size() - 1
	assert_eq(screen.try_play_card(index), Battle.PlayResult.NEEDS_REPLACE)
	assert_eq(screen.mode, BattleScreen.Mode.REPLACE_SELECT, "入れ替える仲間の選択に切り替わる")
	screen.cancel_selection()
	assert_eq(screen.mode, BattleScreen.Mode.NORMAL, "選ぶ前ならキャンセルできる")
	assert_eq(battle.deck.hand.size(), index + 1, "カードは手札に残る")
	screen.try_play_card(index)
	var oldest := battle.allies[0]
	screen.choose_replace(oldest)
	assert_eq(battle.allies.size(), Battle.MAX_ALLIES)
	assert_false(battle.allies.has(oldest), "選んだ仲間と入れ替わる")
	assert_eq(screen.mode, BattleScreen.Mode.NORMAL)


func test_intent_text() -> void:
	var boss := EnemyCombatant.new(DataLoader.new().get_enemy(&"boss_witch"), true)
	boss.decide_next_action(true)
	assert_eq(UiText.intent_text(boss), "攻撃 6〜10", "攻撃の予告は攻撃力の範囲を出す")


func test_deck_list_does_not_reveal_order() -> void:
	var loader := DataLoader.new()
	var cards: Array[CardInstance] = []
	for id: StringName in [&"spark", &"fireball", &"guard"]:
		cards.append(CardInstance.new(loader.get_card(id)))
	var sorted := PilePopup.sorted_by_name(cards)
	var names: Array = sorted.map(func(c: CardInstance) -> String: return UiText.t(c.data.name_key))
	var expected := names.duplicate()
	expected.sort()
	assert_eq(names, expected, "デッキの一覧は名前順（実際の並び順を見せない）")


func test_uses_left_and_exhaust_pile_are_shown() -> void:
	var battle := screen.battle
	var once := DataLoader.new().get_card(&"mana_surge")  # 使用回数1のサンプルカード
	battle.deck.hand.append(CardInstance.new(once))
	screen._refresh_all()
	var hand: HandView = screen.get_node("%HandArea")
	var view := hand.get_view(battle.deck.hand.size() - 1)
	assert_eq(view.uses_left, 1, "使用回数のあるカードは残り回数を表示する")
	assert_eq(hand.get_view(0).uses_left, -1, "制限なしのカードは表示しない")
	screen.try_play_card(battle.deck.hand.size() - 1)
	assert_eq(battle.deck.exhausted_pile.size(), 1)
	assert_eq(screen.get_node("%ExhaustButton").text, "破棄 1", "破棄されたカードの枚数を表示する")


func test_ui_keys_are_registered() -> void:
	var texts := DataValidator.load_translation_texts(DataValidator.LOCALIZATION_DIR)
	var used := DataValidator.find_ui_keys(DataValidator.UI_SOURCE_DIRS)
	assert_true(used.has("UI_TURN_END"), "画面で使っているキーを見つけられる")
	assert_eq(DataValidator.check_ui_keys(used, texts).size(), 0, "画面で使っているキーはすべて翻訳ファイルにある")
	var missing := DataValidator.check_ui_keys(PackedStringArray(["UI_NOT_REGISTERED"]), texts)
	assert_eq(missing.size(), 1, "翻訳ファイルにないキーを見つけられる")


## 使えるカードを1枚使う。使えたら true
func _play_any_card() -> bool:
	var battle := screen.battle
	for i in battle.deck.hand.size():
		var card: CardData = battle.deck.hand[i].data
		if battle.get_cost_problem(card) != Battle.PlayResult.OK:
			continue
		var target := AutoPlayer.choose_target(battle, card)
		var result := screen.try_play_card(i, target)
		if result == Battle.PlayResult.NEEDS_REPLACE:
			screen.choose_replace(battle.allies[0])
			return true
		if result == Battle.PlayResult.OK:
			return true
	return false
