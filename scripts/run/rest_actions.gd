class_name RestActions
extends RefCounted
## 休憩ノードでできること（どれか1つだけ選ぶ）
## ・HP回復（最大HPに対する割合は GameConfig で設定）
## ・カード削除
## ・カードランダム交換（同じレアリティの、主人公が使えるカードと交換）


## HP回復。回復した量を返す
static func heal(run: RunState) -> int:
	var amount := ceili(run.get_max_hp() * run.config.rest_heal_percent / 100.0)
	return run.heal(amount)


## カード削除ができるか（デッキが空にならないよう、1枚しかない時はできない）
static func can_remove(run: RunState) -> bool:
	return run.deck.size() > 1


## 所持カードの指定位置のカードを削除する
static func remove_card(run: RunState, deck_index: int) -> CardData:
	if not can_remove(run) or deck_index < 0 or deck_index >= run.deck.size():
		return null
	var removed := run.deck[deck_index]
	run.deck.remove_at(deck_index)
	return removed


## 所持カードの指定位置のカードを、同じレアリティのランダムなカードと交換する。
## なるべく別のカードにする（同じレアリティのカードが他に無ければ、同じカードのまま）。交換後のカードを返す
static func exchange_card(run: RunState, deck_index: int) -> CardData:
	if deck_index < 0 or deck_index >= run.deck.size():
		return null
	var old_card := run.deck[deck_index]
	var candidates := cards_with_rarity(run, old_card.rarity, old_card.rarity, old_card)
	var new_card: CardData = RunRandom.pick(candidates, run.rng)
	if new_card == null:
		new_card = old_card
	run.deck[deck_index] = new_card
	return new_card


## 報酬に出せるカードのうち、レアリティが min〜max のもの（except と同じカードは除く）
static func cards_with_rarity(run: RunState, min_rarity: GameEnums.Rarity, max_rarity: GameEnums.Rarity, except: CardData = null) -> Array[CardData]:
	var result: Array[CardData] = []
	for card: CardData in run.card_pool:
		if card.rarity >= min_rarity and card.rarity <= max_rarity and card != except:
			result.append(card)
	return result
