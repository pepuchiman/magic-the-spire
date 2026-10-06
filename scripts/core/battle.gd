class_name Battle
extends RefCounted
## バトル1回分の進行（Game_Rule.md「バトル中、ターンの流れ」の13手順）。
## 画面には依存しない。変化はシグナルで知らせる。
## 画面・テスト・自動プレイは、このクラスのメソッド（start / play_card / end_player_turn / discard_cards）を呼んで操作する。

## バトルの状態
enum Phase {
	NOT_STARTED,  ## 開始前
	PLAYER_TURN,  ## プレイヤーがカードを使える
	DISCARDING,  ## 手札が多すぎるため、捨てるカードの選択待ち
	ENEMY_TURN,  ## 味方の攻撃〜敵の攻撃〜ターン終了の処理中
	ENDED,  ## バトル終了
}

## カードを使おうとした結果
enum PlayResult {
	OK,
	NOT_PLAYER_TURN,  ## プレイヤーの手番ではない
	INVALID_CARD,  ## 手札にないカード
	NOT_ENOUGH_MANA,  ## マナが足りない
	CATALYST_NOT_MET,  ## 必要触媒を満たしていない
	INVALID_TARGET,  ## 対象が正しくない
	NEEDS_REPLACE,  ## 仲間が上限のため、入れ替える仲間の指定が必要
}

## 効果の発動時期（今は通知だけ。発動時期を持つ効果ができたら、ここで処理する）
enum Timing {
	ALLY_BATTLE_START,  ## 1. 味方のバトル開始時
	ENEMY_BATTLE_START,  ## 2. 敵のバトル開始時
	ALLY_TURN_START,  ## 3. 自分および味方のターン開始時
	ENEMY_TURN_START,  ## 9. 敵のターン開始時
	ALLY_TURN_END,  ## 11. 味方のターン終了時
	ENEMY_TURN_END,  ## 12. 敵のターン終了時
}

const MAX_ALLIES := 3
const MAX_ENEMY_ALLIES := 3

signal timing_reached(timing: Timing)
signal turn_started(turn_number: int)
signal cards_drawn(cards: Array[CardData])
signal deck_reshuffled
signal card_played(card: CardData, target: Combatant)
signal damage_dealt(source: Combatant, target: Combatant, detail: Dictionary)
signal armor_gained(target: Combatant, amount: int)
signal healed(target: Combatant, amount: int)
signal modifier_added(target: Combatant, modifier: StatModifier)
signal modifier_expired(target: Combatant, modifier: StatModifier)
signal ally_summoned(ally: AllyCombatant, replaced: AllyCombatant)
signal enemy_summoned(summoner: EnemyCombatant, summoned: EnemyCombatant)
signal enemy_action_skipped(enemy: EnemyCombatant, action: EnemyActionData)
signal enemy_intent_changed(enemy: EnemyCombatant)
signal combatant_died(combatant: Combatant)
signal discard_required(count: int)
signal cards_discarded(cards: Array[CardData])
signal battle_ended(result: BattleResult)

var hero: HeroCombatant
var allies: Array[AllyCombatant] = []
var main_enemy: EnemyCombatant
var enemy_allies: Array[EnemyCombatant] = []
var deck: DeckState
var rng: RandomNumberGenerator
var turn: int = 0
var phase: Phase = Phase.NOT_STARTED
var result: BattleResult
## 捨てる必要がある枚数（DISCARDING の時）
var pending_discard_count: int = 0
## 起きたことの記録（同じシードで同じ結果になるかの確認や、不具合調査に使う）
var history: PackedStringArray = []

var _cards: Array[CardData] = []


## cards：このバトルで使う所持カード
## hero_hp：ランから引き継いだHP（-1なら主人公データの初期HP）
## permanent_modifiers：以前のバトルから引き継いだ「永続」の補正
func _init(hero_data: HeroData, cards: Array[CardData], enemy_data: EnemyData, seed_value: int,
		hero_hp: int = -1, permanent_modifiers: Array[StatModifier] = []) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	hero = HeroCombatant.new(hero_data, hero_hp, permanent_modifiers)
	main_enemy = EnemyCombatant.new(enemy_data, true)
	deck = DeckState.new(rng)
	deck.reshuffled.connect(_on_deck_reshuffled)
	_cards = cards.duplicate()


# ---------- 外から呼ぶ操作 ----------

## バトルを開始し、1ターン目のプレイヤーの手番まで進める
func start() -> void:
	if phase != Phase.NOT_STARTED:
		return
	_log("バトル開始 敵:%s" % main_enemy.id)
	_reach(Timing.ALLY_BATTLE_START)  # 1
	_reach(Timing.ENEMY_BATTLE_START)  # 2
	deck.setup(_cards)
	_decide_intent(main_enemy)
	_start_player_turn()


## そのカードを今使えるか（マナと必要触媒の判定）
func can_play(hand_index: int) -> PlayResult:
	if phase != Phase.PLAYER_TURN:
		return PlayResult.NOT_PLAYER_TURN
	if hand_index < 0 or hand_index >= deck.hand.size():
		return PlayResult.INVALID_CARD
	var card: CardData = deck.hand[hand_index]
	if hero.mana < card.cost_mana:
		return PlayResult.NOT_ENOUGH_MANA
	if not hero.meets_catalyst(card):
		return PlayResult.CATALYST_NOT_MET
	return PlayResult.OK


## 6. カードを使う。
## target：ターゲットが「敵」なら敵、「味方」なら仲間を指定する（それ以外は null でよい）
## replace_ally：仲間が上限の時に召喚する場合、入れ替える仲間
func play_card(hand_index: int, target: Combatant = null, replace_ally: AllyCombatant = null) -> PlayResult:
	var check := can_play(hand_index)
	if check != PlayResult.OK:
		return check
	var card: CardData = deck.hand[hand_index]
	if not is_valid_target(card, target):
		return PlayResult.INVALID_TARGET
	if needs_replace(card) and (replace_ally == null or not allies.has(replace_ally)):
		return PlayResult.NEEDS_REPLACE

	hero.mana -= card.cost_mana  # 触媒は消費しない
	deck.take_from_hand(hand_index)
	_log("カード使用 %s 対象:%s" % [card.id, target.id if target != null else "-"])
	card_played.emit(card, target)
	var targets := _resolve_targets(card, target)
	for effect: EffectData in card.effects:
		_apply_effect(card, effect, targets, replace_ally)
		if phase == Phase.ENDED:
			break
	deck.discard_pile.append(card)
	return PlayResult.OK


## 7. 手番を終える。手札が最大手札数を超えていたら、捨てるカードの選択待ちになる
func end_player_turn() -> void:
	if phase != Phase.PLAYER_TURN:
		return
	var excess := deck.hand.size() - hero.get_max_hand()
	if excess > 0:
		phase = Phase.DISCARDING
		pending_discard_count = excess
		discard_required.emit(excess)
		return
	_finish_turn()


## 7. 捨てるカード（手札の位置）を指定する。枚数がちょうど合っていれば true
func discard_cards(hand_indices: Array[int]) -> bool:
	if phase != Phase.DISCARDING or hand_indices.size() != pending_discard_count:
		return false
	var unique: Dictionary = {}
	for index: int in hand_indices:
		if index < 0 or index >= deck.hand.size() or unique.has(index):
			return false
		unique[index] = true
	var discarded := deck.discard_from_hand(hand_indices)
	pending_discard_count = 0
	_log("手札を捨てる %d枚" % discarded.size())
	cards_discarded.emit(discarded)
	_finish_turn()
	return true


# ---------- 画面やAIが使う判定 ----------

func needs_enemy_target(card: CardData) -> bool:
	return card.targets.has(GameEnums.Target.ENEMY)


func needs_ally_target(card: CardData) -> bool:
	return card.targets.has(GameEnums.Target.ALLY)


## 仲間が上限で、入れ替えが必要な召喚カードか
func needs_replace(card: CardData) -> bool:
	if allies.size() < MAX_ALLIES:
		return false
	for effect: EffectData in card.effects:
		if effect is SummonEffect:
			return true
	return false


func is_valid_target(card: CardData, target: Combatant) -> bool:
	if needs_enemy_target(card):
		return target is EnemyCombatant and target.is_alive() and get_living_enemies().has(target)
	if needs_ally_target(card):
		if not (target is AllyCombatant and allies.has(target)):
			return false
		return card.target_races.is_empty() or card.target_races.has((target as AllyCombatant).data.race)
	return true


func get_living_enemies() -> Array[Combatant]:
	var result_list: Array[Combatant] = []
	if main_enemy.is_alive():
		result_list.append(main_enemy)
	for enemy: EnemyCombatant in enemy_allies:
		if enemy.is_alive():
			result_list.append(enemy)
	return result_list


func get_living_friends() -> Array[Combatant]:
	var result_list: Array[Combatant] = []
	if hero.is_alive():
		result_list.append(hero)
	for ally: AllyCombatant in allies:
		if ally.is_alive():
			result_list.append(ally)
	return result_list


# ---------- ターンの流れ ----------

func _start_player_turn() -> void:
	turn += 1
	_log("ターン%d開始" % turn)
	turn_started.emit(turn)
	_reach(Timing.ALLY_TURN_START)  # 3
	# 4. マナを基準値に戻す。触媒を増やす（1ターン目は増やさない）
	hero.mana = hero.get_mana_base()
	if turn > 1:
		hero.grow_catalysts()
	# 5. ドロー
	_draw(hero.get_draw_count())
	phase = Phase.PLAYER_TURN


## 8〜13
func _finish_turn() -> void:
	phase = Phase.ENEMY_TURN
	# 8. 味方の攻撃（召喚したターンから参加）
	for ally: AllyCombatant in allies.duplicate():
		if not ally.is_alive():
			continue
		var target := Targeting.pick(get_living_enemies(), rng)
		if target == null:
			break
		_deal_damage(ally, target, ally.roll_attack(rng))
		if phase == Phase.ENDED:
			return
	# 9. 敵のターン開始時効果
	_reach(Timing.ENEMY_TURN_START)
	# 10. 敵の攻撃（敵本体 → 敵の仲間の順。このターンに呼ばれた敵は行動しない）
	var acting: Array[EnemyCombatant] = [main_enemy]
	acting.append_array(enemy_allies)
	for enemy: EnemyCombatant in acting:
		if enemy.is_alive():
			_do_enemy_action(enemy)
			if phase == Phase.ENDED:
				return
	# 11. 味方のターン終了時（効果を受けた側のターン終了時に、残りターンを減らす）
	_reach(Timing.ALLY_TURN_END)
	for friend: Combatant in get_living_friends():
		_tick(friend)
	# 12. 敵のターン終了時
	_reach(Timing.ENEMY_TURN_END)
	for enemy: Combatant in get_living_enemies():
		_tick(enemy)
	# 13. 次のターンへ
	_start_player_turn()


func _do_enemy_action(enemy: EnemyCombatant) -> void:
	var action := enemy.intent
	if action != null:
		match action.action_type:
			GameEnums.EnemyActionType.ATTACK:
				# 攻撃対象は、攻撃の瞬間にターゲット率で抽選する
				var target := Targeting.pick(get_living_friends(), rng)
				if target != null:
					_deal_damage(enemy, target, enemy.roll_attack(rng))
			GameEnums.EnemyActionType.DEFEND:
				_gain_armor(enemy, action.amount)
			GameEnums.EnemyActionType.SUMMON:
				_enemy_summon(enemy, action)
	if phase == Phase.ENDED:
		return
	_decide_intent(enemy)


func _enemy_summon(summoner: EnemyCombatant, action: EnemyActionData) -> void:
	# 敵の仲間が3体いる時は、追加で呼ばない（この行動は何もせず、ループは進む）
	if enemy_allies.size() >= MAX_ENEMY_ALLIES or action.summon_enemy == null:
		_log("%s 味方を呼べない" % summoner.id)
		enemy_action_skipped.emit(summoner, action)
		return
	var summoned := EnemyCombatant.new(action.summon_enemy, false)
	enemy_allies.append(summoned)
	_log("%s が %s を呼んだ" % [summoner.id, summoned.id])
	enemy_summoned.emit(summoner, summoned)
	_decide_intent(summoned)


func _decide_intent(enemy: EnemyCombatant) -> void:
	enemy.decide_next_action()
	enemy_intent_changed.emit(enemy)


# ---------- カードの効果 ----------

## カードのターゲット種別から、効果を与える相手の一覧を作る
func _resolve_targets(card: CardData, chosen: Combatant) -> Array[Combatant]:
	var list: Array[Combatant] = []
	for target_type: GameEnums.Target in card.targets:
		match target_type:
			GameEnums.Target.ENEMY, GameEnums.Target.ALLY:
				if chosen != null:
					list.append(chosen)
			GameEnums.Target.SELF:
				list.append(hero)
			GameEnums.Target.ALL_ALLIES:
				list.append_array(allies)
			GameEnums.Target.SELF_AND_ALL_ALLIES:
				list.append(hero)
				list.append_array(allies)
			GameEnums.Target.SPACE:
				pass  # 空間に作用する効果は、まだ無い
	# 同じ相手が2回入らないようにする
	var unique: Array[Combatant] = []
	for target: Combatant in list:
		if not unique.has(target):
			unique.append(target)
	return unique


func _apply_effect(card: CardData, effect: EffectData, targets: Array[Combatant], replace_ally: AllyCombatant) -> void:
	if effect is DamageEffect:
		for target: Combatant in targets:
			if target is EnemyCombatant and target.is_alive():
				_deal_damage(hero, target, (effect as DamageEffect).amount)
				if phase == Phase.ENDED:
					return
	elif effect is ArmorEffect:
		for target: Combatant in targets:
			if target.is_alive():
				_gain_armor(target, (effect as ArmorEffect).amount)
	elif effect is HealEffect:
		for target: Combatant in targets:
			if target.is_alive():
				var amount := target.heal((effect as HealEffect).amount)
				_log("%s 回復 %d" % [target.id, amount])
				healed.emit(target, amount)
	elif effect is DrawEffect:
		_draw((effect as DrawEffect).count)
	elif effect is ModifyParamEffect:
		if card.duration == GameEnums.Duration.INSTANT:
			return  # 検証でエラーになる組み合わせ。念のため何もしない
		var modify := effect as ModifyParamEffect
		for target: Combatant in targets:
			if target.is_alive():
				var modifier := StatModifier.new(modify.param, modify.amount, card.duration, card.duration_turns)
				target.add_modifier(modifier)
				_log("%s 補正 %s %+d" % [target.id, GameEnums.Param.keys()[modify.param], modify.amount])
				modifier_added.emit(target, modifier)
	elif effect is SummonEffect:
		_summon_ally((effect as SummonEffect).ally, replace_ally)


func _summon_ally(ally_data: AllyData, replace_ally: AllyCombatant) -> void:
	if ally_data == null:
		return
	var replaced: AllyCombatant = null
	if allies.size() >= MAX_ALLIES:
		replaced = replace_ally
		allies.erase(replaced)  # 入れ替えられた仲間は場から消える
	var ally := AllyCombatant.new(ally_data, turn)
	allies.append(ally)
	_log("召喚 %s%s" % [ally.id, " 入れ替え:%s" % replaced.id if replaced != null else ""])
	ally_summoned.emit(ally, replaced)


# ---------- 共通の処理 ----------

func _deal_damage(source: Combatant, target: Combatant, raw_damage: int) -> void:
	var detail := DamageCalc.apply(target, raw_damage)
	_log("%s → %s ダメージ%d（アーマー-%d HP-%d 残りHP%d）" % [
		source.id, target.id, raw_damage, detail["armor_absorbed"], detail["hp_damage"], target.hp])
	damage_dealt.emit(source, target, detail)
	if not target.is_alive():
		_on_died(target)


func _gain_armor(target: Combatant, amount: int) -> void:
	target.armor = mini(9999, target.armor + amount)
	_log("%s アーマー+%d" % [target.id, amount])
	armor_gained.emit(target, amount)


func _on_died(combatant: Combatant) -> void:
	_log("%s 死亡" % combatant.id)
	combatant_died.emit(combatant)
	if combatant == hero:
		_end(false)  # 仲間が残っていてもゲームオーバー
	elif combatant == main_enemy:
		_end(true)  # 敵の仲間が残っていてもバトル終了
	elif combatant is AllyCombatant:
		allies.erase(combatant)
	elif combatant is EnemyCombatant:
		enemy_allies.erase(combatant)


func _tick(combatant: Combatant) -> void:
	for modifier: StatModifier in combatant.tick_modifiers():
		_log("%s 補正終了 %s" % [combatant.id, GameEnums.Param.keys()[modifier.param]])
		modifier_expired.emit(combatant, modifier)


func _draw(count: int) -> void:
	var drawn := deck.draw(count)
	if not drawn.is_empty():
		var ids := PackedStringArray()
		for card: CardData in drawn:
			ids.append(String(card.id))
		_log("ドロー %s" % ", ".join(ids))
		cards_drawn.emit(drawn)


func _end(won: bool) -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	result = BattleResult.new(won, hero.hp, hero.get_permanent_modifiers(), turn)
	_log("バトル終了 %s（%dターン、主人公HP%d）" % ["勝利" if won else "敗北", turn, result.hero_hp])
	battle_ended.emit(result)


func _reach(timing: Timing) -> void:
	timing_reached.emit(timing)


func _on_deck_reshuffled() -> void:
	_log("ゴミ箱をシャッフルしてデッキに戻した")
	deck_reshuffled.emit()


func _log(text: String) -> void:
	history.append("T%d %s" % [turn, text])
