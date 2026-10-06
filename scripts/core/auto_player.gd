class_name AutoPlayer
extends RefCounted
## 簡単な自動プレイ（動作確認・テスト用。ゲームのAIではない）
## ・使えるカードを手札の先頭から順に使う（敵が対象なら敵本体、味方が対象なら最初に選べる仲間）
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
		var card: CardData = battle.deck.hand[i]
		var target: Combatant = null
		if battle.needs_enemy_target(card):
			target = battle.main_enemy
		elif battle.needs_ally_target(card):
			target = _first_valid_ally(battle, card)
			if target == null:
				continue
		var replace: AllyCombatant = battle.allies[0] if battle.needs_replace(card) else null
		if battle.play_card(i, target, replace) == Battle.PlayResult.OK:
			return true
	return false


static func _first_valid_ally(battle: Battle, card: CardData) -> AllyCombatant:
	for ally: AllyCombatant in battle.allies:
		if battle.is_valid_target(card, ally):
			return ally
	return null
