class_name RewardGenerator
extends RefCounted
## バトル後のカード報酬（3択）を作る。
## 今は「主人公が使えるカードから、重ならないように選ぶ」だけ。レアリティの確率などはフェーズ5で追加する


static func card_choices(run: RunState) -> Array[CardData]:
	var result: Array[CardData] = []
	for card: Variant in RunRandom.shuffled(run.card_pool, run.rng):
		if result.size() >= run.config.reward_card_count:
			break
		result.append(card)
	return result


## カードを選んで所持カードに加える
static func take(run: RunState, card: CardData) -> void:
	run.add_card(card)


## スキップする（設定で回復量があれば回復する）
static func skip(run: RunState) -> int:
	return run.heal(run.config.skip_heal_amount)
