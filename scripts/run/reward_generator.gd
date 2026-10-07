class_name RewardGenerator
extends RefCounted
## 報酬（カード・装備・宝箱）を作る（Game_Rule.md「報酬選択」「カード報酬のルール」「装備報酬」）
## ・カードは、主人公が使え、解放済みのものだけ（RunState.card_pool）
## ・レアリティを抽選する。戦闘に勝つほどレア・レジェンドが出やすく、エリート戦はさらに出やすい。ボスはレア以上だけ
## ・3枚の種別がなるべく重ならないようにする
## ・デッキに多い触媒色のカードが出やすい。ただし、その色以外のカードも最低1枚は混ぜる
## ・装備：通常戦は低確率（コモン・アンコモンのみ）、エリート戦は確定（レア以上も出る）、ボスはレア以上が確定
## 数値はすべて GameConfig（data/config/game_config.tres）で設定する

const NodeType := GameEnums.MapNodeType
const Rarity := GameEnums.Rarity
const COLORS: Array[String] = ["red", "blue", "green"]


# ---------- カード ----------

## カード報酬の選択肢（node_type：どの戦闘の報酬か）
static func card_choices(run: RunState, node_type: GameEnums.MapNodeType = NodeType.BATTLE) -> Array[CardData]:
	var weights := rarity_weights(run, node_type)
	var color_counts := deck_color_counts(run.deck)
	var main_color := main_color_of(color_counts)
	var result: Array[CardData] = []
	var count := run.config.reward_card_count
	for slot in count:
		var candidates: Array = []
		for card: CardData in run.card_pool:
			if not result.has(card):
				candidates.append(card)
		if candidates.is_empty():
			break
		# ボスはレア以上だけ（他の条件より優先する）
		if node_type == NodeType.BOSS:
			candidates = _prefer(candidates, func(c: CardData) -> bool: return c.rarity >= Rarity.RARE)
		# 最後の1枚で、まだ他の色のカードがなければ、他の色のカードにする
		if slot == count - 1 and main_color != "" and not result.any(func(c: CardData) -> bool: return has_other_color(c, main_color)):
			candidates = _prefer(candidates, func(c: CardData) -> bool: return has_other_color(c, main_color))
		# 種別がなるべく重ならないようにする
		candidates = _prefer(candidates, func(c: CardData) -> bool:
			return not result.any(func(chosen: CardData) -> bool: return chosen.card_type == c.card_type))
		candidates = _nearest_rarity(candidates, _roll_rarity(weights, run.rng))
		result.append(_pick_by_color(candidates, color_counts, run.deck.size(), run.config.color_weight_strength, run.rng))
	return result


## レアリティの重み [コモン, アンコモン, レア, レジェンド]
static func rarity_weights(run: RunState, node_type: GameEnums.MapNodeType) -> Array[int]:
	var config := run.config
	var rare := config.rare_weight + config.rare_bonus_per_battle * run.battles_won
	var legend := config.legend_weight + config.legend_bonus_per_battle * run.battles_won
	if node_type == NodeType.ELITE:
		rare *= config.elite_rarity_multiplier
		legend *= config.elite_rarity_multiplier
	if node_type == NodeType.BOSS:
		return [0, 0, maxi(1, rare), maxi(1, legend)]  # ボスはレア以上だけ
	return [config.common_weight, config.uncommon_weight, rare, legend]


## カードを取る
static func take(run: RunState, card: CardData) -> void:
	run.add_card(card)


## カードを取らない（設定で回復量があれば回復する）
static func skip(run: RunState) -> int:
	return run.heal(run.config.skip_heal_amount)


# ---------- 装備 ----------

## 戦闘後の装備の報酬（出なければ null）
static func equipment_reward(run: RunState, node_type: GameEnums.MapNodeType) -> EquipmentData:
	match node_type:
		NodeType.BATTLE:
			if run.rng.randi_range(1, 100) > run.config.battle_equipment_chance:
				return null
			return pick_equipment(run, rarity_weights(run, NodeType.BATTLE), Rarity.COMMON, Rarity.UNCOMMON)
		NodeType.ELITE:
			return pick_equipment(run, rarity_weights(run, NodeType.ELITE), Rarity.COMMON, Rarity.LEGEND)
		NodeType.BOSS:
			return pick_equipment(run, rarity_weights(run, NodeType.BOSS), Rarity.RARE, Rarity.LEGEND)
	return null


## 装備を1つ選ぶ（レアリティを min〜max の範囲で抽選。今と同じ装備はなるべく選ばない）
static func pick_equipment(run: RunState, weights: Array[int], min_rarity: GameEnums.Rarity, max_rarity: GameEnums.Rarity) -> EquipmentData:
	var candidates: Array = []
	for item: EquipmentData in run.equipment_pool:
		if item.rarity >= min_rarity and item.rarity <= max_rarity:
			candidates.append(item)
	candidates = _prefer(candidates, func(item: EquipmentData) -> bool: return run.get_equipped(item.equipment_type) != item)
	if candidates.is_empty():
		return null
	var limited: Array[int] = []
	for rarity: int in Rarity.values():
		limited.append(weights[rarity] if rarity >= min_rarity and rarity <= max_rarity else 0)
	candidates = _nearest_rarity(candidates, _roll_rarity(limited, run.rng))
	return RunRandom.pick(candidates, run.rng)


## 装備する（同じ種類の装備は入れ替わる）。外した装備を返す
static func equip(run: RunState, item: EquipmentData) -> EquipmentData:
	return run.equip(item)


# ---------- 宝箱・ボス ----------

## 宝箱の中身：{"equipment": 装備} または {"card": レア以上のカード}
static func treasure(run: RunState) -> Dictionary:
	if not run.equipment_pool.is_empty() and run.rng.randi_range(1, 100) <= run.config.treasure_equipment_chance:
		var item := pick_equipment(run, rarity_weights(run, NodeType.ELITE), Rarity.COMMON, Rarity.LEGEND)
		if item != null:
			return {"equipment": item}
	var cards: Array[CardData] = []
	for card: CardData in run.card_pool:
		if card.rarity >= Rarity.RARE:
			cards.append(card)
	if cards.is_empty():
		cards = run.card_pool.duplicate()
	var color_counts := deck_color_counts(run.deck)
	return {"card": _pick_by_color(cards, color_counts, run.deck.size(), run.config.color_weight_strength, run.rng)}


## ボスの報酬：カード3択（レア以上）＋上級装備（レア以上）。
## ※今はボスに勝つとランが終わるため、画面には出していない（ルールだけ用意している）
static func boss_rewards(run: RunState) -> Dictionary:
	return {"cards": card_choices(run, NodeType.BOSS), "equipment": equipment_reward(run, NodeType.BOSS)}


# ---------- 触媒色 ----------

## カードの触媒色（必要触媒が1以上の色）。無色なら空
static func card_colors(card: CardData) -> Array[String]:
	var result: Array[String] = []
	if card.required_red > 0:
		result.append("red")
	if card.required_blue > 0:
		result.append("blue")
	if card.required_green > 0:
		result.append("green")
	return result


## デッキの色ごとの枚数
static func deck_color_counts(deck: Array[CardData]) -> Dictionary:
	var counts := {"red": 0, "blue": 0, "green": 0}
	for card: CardData in deck:
		for color: String in card_colors(card):
			counts[color] += 1
	return counts


## デッキでいちばん多い色（色のカードが1枚もなければ空）
static func main_color_of(counts: Dictionary) -> String:
	var best := ""
	var best_count := 0
	for color: String in COLORS:
		if counts[color] > best_count:
			best = color
			best_count = counts[color]
	return best


## そのカードが、main_color 以外の色を持っているか
static func has_other_color(card: CardData, main_color: String) -> bool:
	return card_colors(card).any(func(color: String) -> bool: return color != main_color)


# ---------- 内部の処理 ----------

## 条件に合うものがあれば、それだけに絞る（無ければ元のまま）
static func _prefer(list: Array, condition: Callable) -> Array:
	var filtered := list.filter(condition)
	return filtered if not filtered.is_empty() else list


static func _roll_rarity(weights: Array[int], rng: RandomNumberGenerator) -> GameEnums.Rarity:
	return RunRandom.pick_weighted(Rarity.values(), weights, rng)


## 抽選したレアリティのものに絞る。無ければ近いレアリティ（同じ近さなら低い方）にする
static func _nearest_rarity(list: Array, rarity: GameEnums.Rarity) -> Array:
	for distance in Rarity.size():
		for candidate_rarity: int in [rarity - distance, rarity + distance]:
			var filtered := list.filter(func(item: Resource) -> bool: return item.get("rarity") == candidate_rarity)
			if not filtered.is_empty():
				return filtered
	return list


## デッキに多い色のカードほど出やすくして、1枚選ぶ
static func _pick_by_color(list: Array, color_counts: Dictionary, deck_size: int, strength: int, rng: RandomNumberGenerator) -> CardData:
	var weights: Array[int] = []
	for card: CardData in list:
		var share := 0
		for color: String in card_colors(card):
			share += color_counts[color]
		weights.append(100 + int(strength * share / float(maxi(1, deck_size))))
	return RunRandom.pick_weighted(list, weights, rng)
