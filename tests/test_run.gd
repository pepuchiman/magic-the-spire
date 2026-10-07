extends GutTest
## ランの進行（報酬・休憩・イベント・バトルの結果）のテスト

var loader: DataLoader


func before_each() -> void:
	TranslationServer.set_locale("ja")
	loader = DataLoader.new()


func _run(seed_value: int = 1) -> RunState:
	return RunState.new(loader.get_hero(&"flame_mage"), loader.get_dungeon(&"lost_forest"),
		loader.index.cards, loader.get_config(), seed_value)


# ---------- 開始・移動 ----------

func test_new_run_starts_with_hero_values() -> void:
	var run := _run()
	assert_eq(run.hp, run.hero.hp)
	assert_eq(run.deck.size(), run.hero.starting_deck.size(), "初期デッキで始まる")
	assert_eq(run.available_nodes(), run.map.get_floor(0), "最初は1階のノードから選ぶ")


func test_can_only_move_to_connected_nodes() -> void:
	var run := _run()
	var first: MapNode = run.map.get_floor(0)[0]
	assert_false(run.move_to(run.map.get_floor(2)[0]), "つながっていないノードには進めない")
	assert_true(run.move_to(first))
	assert_true(first.visited)
	assert_eq(run.current_floor_number(), 1)
	assert_eq(run.available_nodes(), first.next)


# ---------- バトルの結果 ----------

func test_hp_is_carried_after_battle() -> void:
	var run := _run()
	run.move_to(run.map.get_floor(0)[0])
	var result := BattleResult.new(true, 13, [], 4, 2)
	run.apply_battle_result(result)
	assert_eq(run.hp, 13, "バトル後のHPを引き継ぐ")
	assert_eq(run.battles_won, 1)
	assert_eq(run.enemies_defeated, 2)
	assert_false(run.finished)


func test_defeat_ends_run() -> void:
	var run := _run()
	run.move_to(run.map.get_floor(0)[0])
	run.apply_battle_result(BattleResult.new(false, 0, [], 3))
	assert_true(run.finished, "敗北でランが終わる")
	assert_false(run.cleared)


func test_boss_victory_clears_run() -> void:
	var run := _run()
	run.current_node = run.map.get_floor(run.map.floor_count() - 1)[0]
	run.apply_battle_result(BattleResult.new(true, 10, [], 5, 1))
	assert_true(run.cleared, "ボスに勝つとクリア")


func test_permanent_max_hp_is_carried() -> void:
	var run := _run()
	run.move_to(run.map.get_floor(0)[0])
	var modifiers: Array[StatModifier] = [StatModifier.new(GameEnums.Param.MAX_HP, 5, GameEnums.Duration.PERMANENT)]
	run.apply_battle_result(BattleResult.new(true, 20, modifiers, 3))
	assert_eq(run.get_max_hp(), 25, "永続の最大HP上昇を引き継ぐ")


# ---------- 報酬 ----------

func test_reward_has_three_distinct_usable_cards() -> void:
	var run := _run()
	var choices := RewardGenerator.card_choices(run)
	assert_eq(choices.size(), 3)
	var ids := {}
	for card: CardData in choices:
		assert_true(card.usable_heroes.has(run.hero.id), "主人公が使えるカードだけ")
		ids[card.id] = true
	assert_eq(ids.size(), 3, "3枚とも違うカード")


func test_take_reward_adds_card() -> void:
	var run := _run()
	var before := run.deck.size()
	RewardGenerator.take(run, RewardGenerator.card_choices(run)[0])
	assert_eq(run.deck.size(), before + 1)


# ---------- 休憩 ----------

func test_rest_heal_is_capped() -> void:
	var run := _run()
	run.hp = 10
	assert_eq(RestActions.heal(run), 6, "最大HP20の30%（仮の値）＝6回復")
	run.hp = 19
	RestActions.heal(run)
	assert_eq(run.hp, 20, "最大HPを超えない")


func test_rest_remove_card() -> void:
	var run := _run()
	var before := run.deck.size()
	var removed := RestActions.remove_card(run, 0)
	assert_not_null(removed)
	assert_eq(run.deck.size(), before - 1)


func test_rest_cannot_remove_last_card() -> void:
	var run := _run()
	run.deck = [run.deck[0]]
	assert_null(RestActions.remove_card(run, 0), "デッキが空にならないよう、最後の1枚は削除できない")


func test_rest_exchange_keeps_rarity() -> void:
	var run := _run()
	for i in run.deck.size():
		var old := run.deck[i]
		var new_card := RestActions.exchange_card(run, i)
		assert_eq(new_card.rarity, old.rarity, "同じレアリティのカードと交換")
		assert_true(new_card.usable_heroes.has(run.hero.id))


# ---------- イベント ----------

func _event(id: StringName) -> EventData:
	return loader.get_event(id)


func test_altar_costs_hp_and_gives_rare_card() -> void:
	var run := _run()
	var choice: EventChoiceData = _event(&"altar").choices[0]
	var result := EventResolver.apply(run, choice)
	assert_eq(result["hp_change"], choice.hp_change, "HPを失う")
	assert_eq(result["gained"].size(), 1)
	assert_true(result["gained"][0].rarity >= GameEnums.Rarity.RARE, "レア以上のカードを得る")


func test_event_hp_loss_leaves_at_least_one() -> void:
	var run := _run()
	run.hp = 2
	EventResolver.apply(run, _event(&"altar").choices[0])
	assert_eq(run.hp, 1, "イベントでHPが0にはならない")


func test_lost_spirit_gives_summon_card() -> void:
	var run := _run()
	var result := EventResolver.apply(run, _event(&"lost_spirit").choices[0])
	assert_eq(result["gained"][0].card_type, GameEnums.CardType.SUMMON, "召喚カードを得る")


func test_traveling_mage_trades_for_same_or_higher_rarity() -> void:
	var run := _run()
	var choice: EventChoiceData = _event(&"traveling_mage").choices[0]
	assert_true(EventResolver.needs_card_choice(choice), "渡すカードを選ぶ必要がある")
	var old := run.deck[0]
	var result := EventResolver.apply(run, choice, 0)
	assert_eq(result["lost"][0], old)
	assert_true(result["gained"][0].rarity >= old.rarity, "同じレアリティ以上のカードになる")
	assert_eq(run.deck[0], result["gained"][0])


func test_leave_choice_changes_nothing() -> void:
	var run := _run()
	var before := run.deck.size()
	var result := EventResolver.apply(run, _event(&"altar").choices[1])
	assert_eq(result["hp_change"], 0)
	assert_eq(run.deck.size(), before)


# ---------- 1周の自動プレイ ----------

func test_full_run_reaches_the_end() -> void:
	var run := _run(7)
	var log := AutoRun.play(run)
	assert_true(run.finished, "クリアかゲームオーバーまで進む：%s" % log[log.size() - 1])


func test_same_seed_gives_same_run() -> void:
	var a := AutoRun.play(_run(11))
	var b := AutoRun.play(_run(11))
	assert_eq(a, b, "同じシードなら同じ展開")
