extends RefCounted
## バトルのテスト用に、小さなデータをメモリ上で作る補助（data/ の実ファイルは使わない・変更しない）
## ファイル名が test_ で始まらないので、GUT はこれをテストとしては実行しない

const HERO_ID := &"test_hero"


static func card(id: StringName, cost: int, effects: Array, targets: Array = [GameEnums.Target.ENEMY]) -> CardData:
	var result := CardData.new()
	result.id = id
	result.usable_heroes = [HERO_ID]
	result.cost_mana = cost
	result.targets.assign(targets)
	result.effects.assign(effects)
	return result


static func damage_card(id: StringName, amount: int, cost: int = 1) -> CardData:
	var effect := DamageEffect.new()
	effect.amount = amount
	return card(id, cost, [effect])


static func armor_card(id: StringName, amount: int, cost: int = 1) -> CardData:
	var effect := ArmorEffect.new()
	effect.amount = amount
	return card(id, cost, [effect], [GameEnums.Target.SELF])


static func modify_card(id: StringName, param: GameEnums.Param, amount: int, duration: GameEnums.Duration, turns: int = 0) -> CardData:
	var effect := ModifyParamEffect.new()
	effect.param = param
	effect.amount = amount
	var result := card(id, 0, [effect], [GameEnums.Target.SELF])
	result.duration = duration
	result.duration_turns = turns
	return result


static func summon_card(id: StringName, ally: AllyData) -> CardData:
	var effect := SummonEffect.new()
	effect.ally = ally
	return card(id, 0, [effect], [GameEnums.Target.SPACE])


## 何もしない（0マナ・効果なし）カード。デッキの枚数合わせに使う
static func filler(id: StringName = &"filler") -> CardData:
	return card(id, 0, [], [GameEnums.Target.SELF])


static func hero(deck: Array, hp: int = 20) -> HeroData:
	var result := HeroData.new()
	result.id = HERO_ID
	result.hp = hp
	result.max_hp = maxi(hp, 20)
	result.max_hand = 99
	result.starting_deck.assign(deck)
	return result


static func ally(id: StringName = &"test_ally", attack: int = 0, target_rate: int = 100) -> AllyData:
	var result := AllyData.new()
	result.id = id
	result.max_hp = 10
	result.attack_min = attack
	result.attack_max = attack
	result.target_rate = target_rate
	return result


static func action(type: GameEnums.EnemyActionType, amount: int = 0) -> EnemyActionData:
	var result := EnemyActionData.new()
	result.action_type = type
	result.amount = amount
	return result


## 敵。pattern を省略すると「アーマー0の防御」を繰り返す（＝何もしない敵）
static func enemy(hp: int = 100, attack: int = 0, pattern: Array = []) -> EnemyData:
	var result := EnemyData.new()
	result.id = &"test_enemy"
	result.max_hp = hp
	result.attack_min = attack
	result.attack_max = attack
	if pattern.is_empty():
		pattern = [action(GameEnums.EnemyActionType.DEFEND, 0)]
	result.pattern.assign(pattern)
	return result


static func battle(hero_data: HeroData, enemy_data: EnemyData, seed_value: int = 1) -> Battle:
	var deck: Array[CardData] = hero_data.starting_deck
	return Battle.new(hero_data, deck, enemy_data, seed_value)


## 手札から指定IDのカードの位置を探す（無ければ -1）
static func hand_index(battle_obj: Battle, id: StringName) -> int:
	for i in battle_obj.deck.hand.size():
		if battle_obj.deck.hand[i].id == id:
			return i
	return -1


## 手番を終える（捨てる必要があれば先頭から捨てる）
static func end_turn(battle_obj: Battle) -> void:
	battle_obj.end_player_turn()
	if battle_obj.phase == Battle.Phase.DISCARDING:
		var indices: Array[int] = []
		for i in battle_obj.pending_discard_count:
			indices.append(i)
		battle_obj.discard_cards(indices)
