extends GutTest
## デッキ・手札のテスト

const H := preload("res://tests/battle_test_helper.gd")


func _cards(count: int) -> Array[CardData]:
	var result: Array[CardData] = []
	for i in count:
		result.append(H.filler(StringName("c%d" % i)))
	return result


func test_deck_reshuffles_discard_when_empty() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var deck := DeckState.new(rng)
	watch_signals(deck)
	deck.setup(_cards(3))
	deck.draw(3)
	assert_eq(deck.draw_pile.size(), 0, "デッキが空になった")
	deck.discard_from_hand([0, 1])
	var drawn := deck.draw(1)
	assert_eq(drawn.size(), 1, "ゴミ箱から引けた")
	assert_signal_emitted(deck, "reshuffled", "ゴミ箱をシャッフルした")
	assert_eq(deck.discard_pile.size(), 0, "ゴミ箱は空になった")
	assert_eq(deck.draw_pile.size(), 1, "残り1枚がデッキにある")


func test_no_draw_when_deck_and_discard_are_empty() -> void:
	var rng := RandomNumberGenerator.new()
	var deck := DeckState.new(rng)
	deck.setup(_cards(2))
	deck.draw(2)
	var drawn := deck.draw(3)
	assert_eq(drawn.size(), 0, "デッキもゴミ箱も空なら引かない")
	assert_eq(deck.hand.size(), 2)


func test_same_seed_gives_same_shuffle() -> void:
	var orders: Array = []
	for i in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var deck := DeckState.new(rng)
		deck.setup(_cards(10))
		orders.append(deck.draw_pile.map(func(c: CardInstance) -> StringName: return c.data.id))
	assert_eq(orders[0], orders[1], "同じシードなら同じ並び順")


func test_hand_is_kept_to_next_turn() -> void:
	var battle := H.battle(H.hero(_cards(10)), H.enemy())
	battle.start()
	assert_eq(battle.deck.hand.size(), 3, "1ターン目に3枚引く")
	H.end_turn(battle)
	assert_eq(battle.deck.hand.size(), 6, "手札は捨てられず、次のターンに残る")


func test_excess_cards_are_discarded_at_turn_end() -> void:
	var hero := H.hero(_cards(10))
	hero.max_hand = 5
	var battle := H.battle(hero, H.enemy())
	battle.start()
	battle.end_player_turn()  # 3枚 → 超えていない
	assert_eq(battle.turn, 2)
	assert_eq(battle.deck.hand.size(), 6, "ドローで最大手札数を超えても、その時点ではチェックしない")
	battle.end_player_turn()
	assert_eq(battle.phase, Battle.Phase.DISCARDING, "手番終了時に超過していれば、捨てる選択待ちになる")
	assert_eq(battle.pending_discard_count, 1)
	assert_false(battle.discard_cards([0, 1]), "枚数が違うと捨てられない")
	assert_true(battle.discard_cards([0]))
	assert_eq(battle.turn, 3, "捨てたら次のターンへ進む")
	assert_eq(battle.deck.discard_pile.size(), 1)


# ---------- 使用回数と破棄 ----------

func _limited(id: StringName, uses: int) -> CardData:
	var card := H.filler(id)
	card.uses_per_battle = uses
	return card


func test_card_is_exhausted_when_uses_run_out() -> void:
	var battle := H.battle(H.hero([_limited(&"once", 1)]), H.enemy())
	watch_signals(battle)
	battle.start()
	battle.play_card(0)
	assert_eq(battle.deck.exhausted_pile.size(), 1, "使用回数を使い切ったカードは破棄される")
	assert_eq(battle.deck.discard_pile.size(), 0, "ゴミ箱には置かれない")
	assert_signal_emitted(battle, "card_exhausted")


func test_card_goes_to_discard_until_uses_run_out() -> void:
	var battle := H.battle(H.hero([_limited(&"twice", 2)]), H.enemy())
	battle.start()
	battle.play_card(0)
	assert_eq(battle.deck.discard_pile.size(), 1, "残りがあればゴミ箱へ")
	assert_eq(battle.deck.discard_pile[0].uses_left, 1, "残りの使用回数が1減る")
	H.end_turn(battle)  # ゴミ箱から引き直す
	battle.play_card(0)
	assert_eq(battle.deck.exhausted_pile.size(), 1, "2回目で破棄")


func test_unlimited_card_is_never_exhausted() -> void:
	var battle := H.battle(H.hero([H.filler(&"free")]), H.enemy())
	battle.start()
	for i in 3:
		battle.play_card(0)
		H.end_turn(battle)
	assert_eq(battle.deck.exhausted_pile.size(), 0, "使用回数0（制限なし）のカードは破棄されない")


func test_exhausted_card_does_not_return_in_battle() -> void:
	var battle := H.battle(H.hero([_limited(&"once", 1), H.filler(&"other")]), H.enemy())
	battle.start()
	battle.play_card(H.hand_index(battle, &"once"))
	for i in 3:
		H.end_turn(battle)
	assert_eq(H.hand_index(battle, &"once"), -1, "破棄されたカードは手札に戻らない")
	assert_false(battle.deck.draw_pile.any(func(c: CardInstance) -> bool: return c.data.id == &"once"), "デッキにも戻らない")
	assert_false(battle.deck.discard_pile.any(func(c: CardInstance) -> bool: return c.data.id == &"once"), "ゴミ箱にも戻らない")


func test_uses_are_counted_per_copy() -> void:
	var card := _limited(&"once", 1)
	var battle := H.battle(H.hero([card, card]), H.enemy())
	battle.start()
	assert_eq(battle.play_card(0), Battle.PlayResult.OK)
	assert_eq(battle.play_card(0), Battle.PlayResult.OK, "同じカードの2枚目は、別に使用回数を持つ")
	assert_eq(battle.deck.exhausted_pile.size(), 2)


func test_uses_reset_in_next_battle() -> void:
	var hero := H.hero([_limited(&"once", 1)])
	var first := H.battle(hero, H.enemy())
	first.start()
	first.play_card(0)
	var second := H.battle(hero, H.enemy())
	second.start()
	assert_eq(second.deck.hand.size(), 1, "次のバトルでは破棄されたカードもデッキに戻る")
	assert_eq(second.deck.hand[0].uses_left, 1, "使用回数も元に戻る")
