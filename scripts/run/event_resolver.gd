class_name EventResolver
extends RefCounted
## イベントの選択肢を選んだ時の結果を、ランに反映する


## その選択肢で、プレイヤーが所持カードを1枚選ぶ必要があるか（カード交換など）
static func needs_card_choice(choice: EventChoiceData) -> bool:
	for outcome: EventOutcome in choice.outcomes:
		if outcome is TradeCardOutcome:
			return true
	return false


## 選択肢の結果を反映する。
## deck_index：カードを選ぶ必要がある選択肢で、プレイヤーが選んだ所持カードの位置
## 戻り値：{"gained": 手に入れたカード, "lost": 手放したカード, "hp_change": 実際のHPの増減}
static func apply(run: RunState, choice: EventChoiceData, deck_index: int = -1) -> Dictionary:
	var gained: Array[CardData] = []
	var lost: Array[CardData] = []
	var before := run.hp
	# イベントでHPが0になることはない（最低1残る）
	run.hp = clampi(run.hp + choice.hp_change, 1, run.get_max_hp())
	for outcome: EventOutcome in choice.outcomes:
		if outcome is GainCardOutcome:
			gained.append_array(_gain_cards(run, outcome as GainCardOutcome))
		elif outcome is TradeCardOutcome:
			var traded := _trade_card(run, deck_index)
			if not traded.is_empty():
				lost.append(traded[0])
				gained.append(traded[1])
	return {"gained": gained, "lost": lost, "hp_change": run.hp - before}


static func _gain_cards(run: RunState, outcome: GainCardOutcome) -> Array[CardData]:
	var candidates: Array[CardData] = []
	for card: CardData in RestActions.cards_with_rarity(run, outcome.min_rarity, GameEnums.Rarity.LEGEND):
		if not outcome.filter_by_type or card.card_type == outcome.card_type:
			candidates.append(card)
	var result: Array[CardData] = []
	for card: Variant in RunRandom.shuffled(candidates, run.rng):
		if result.size() >= outcome.count:
			break
		result.append(card)
		run.add_card(card)
	return result


## 所持カードを、同じレアリティ以上のカードと交換する。[手放したカード, 手に入れたカード] を返す
static func _trade_card(run: RunState, deck_index: int) -> Array[CardData]:
	var result: Array[CardData] = []
	if deck_index < 0 or deck_index >= run.deck.size():
		return result
	var old_card := run.deck[deck_index]
	var candidates := RestActions.cards_with_rarity(run, old_card.rarity, GameEnums.Rarity.LEGEND, old_card)
	var new_card: CardData = RunRandom.pick(candidates, run.rng)
	if new_card == null:
		return result
	run.deck[deck_index] = new_card
	result.append(old_card)
	result.append(new_card)
	return result
