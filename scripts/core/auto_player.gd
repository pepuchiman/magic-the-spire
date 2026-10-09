class_name AutoPlayer
extends RefCounted
## 簡単な自動プレイ（動作確認・テスト用。ゲームのAIではない）
## ・使えるカードを手札の先頭から順に使う（相手の選び方は choose_target を参照）
## ・仲間の入れ替えは、いちばん古い仲間
## ・手札が多すぎる時は、先頭から捨てる

const MAX_TURNS := 200
## 1ターンに使うカードの上限（無限ループ防止）
const MAX_PLAYS_PER_TURN := 100


## バトルを最後まで進めて結果を返す。MAX_TURNS で終わらなければ null
static func run(battle: Battle) -> BattleResult:
	if battle.phase == Battle.Phase.NOT_STARTED:
		battle.start()
	while battle.phase != Battle.Phase.ENDED and battle.turn <= MAX_TURNS:
		_play_cards(battle)
		if battle.phase == Battle.Phase.ENDED:
			break
		battle.end_player_turn()
		if battle.phase == Battle.Phase.DISCARDING:
			var indices: Array[int] = []
			for i in battle.pending_discard_count:
				indices.append(i)
			battle.discard_cards(indices)
	return battle.result


static func _play_cards(battle: Battle) -> void:
	for count in MAX_PLAYS_PER_TURN:
		if not _play_one(battle):
			return


## 使えるカードを1枚使う。使えたら true
static func _play_one(battle: Battle) -> bool:
	for i in battle.deck.hand.size():
		if battle.can_play(i) != Battle.PlayResult.OK:
			continue
		var card: CardData = battle.deck.hand[i].data
		var target := choose_target(battle, card)
		if battle.needs_target(card) and target == null:
			continue
		var replace: AllyCombatant = battle.allies[0] if battle.needs_replace(card) else null
		if battle.play_card(i, target, replace) == Battle.PlayResult.OK:
			return true
	return false


## カードの相手を選ぶ（選ぶ必要がないカードは null）。
## 「いずれか1体」のカードは、ダメージやデバフ（毒・麻痺など）を与えるなら敵本体、
## それ以外（回復・アーマー・筋力などのバフ）なら主人公を選ぶ
static func choose_target(battle: Battle, card: CardData) -> Combatant:
	if battle.needs_enemy_target(card):
		return battle.main_enemy
	if battle.needs_any_target(card):
		for effect: EffectData in card.effects:
			if effect is DamageEffect:
				return battle.main_enemy
			if effect is StatusEffect and StatusRules.is_debuff((effect as StatusEffect).status):
				return battle.main_enemy
		return battle.hero
	if battle.needs_ally_target(card):
		return _first_valid_ally(battle, card)
	return null


static func _first_valid_ally(battle: Battle, card: CardData) -> AllyCombatant:
	for ally: AllyCombatant in battle.allies:
		if battle.is_valid_target(card, ally):
			return ally
	return null
