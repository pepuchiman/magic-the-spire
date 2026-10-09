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
	PARALYZED,  ## 麻痺しているため、攻撃魔法を使えない
}

## 自分のターンを迎えている側（状態効果の「付いた直後は減らない」の判定に使う）
enum TurnSide { NONE, FRIENDS, ENEMIES }

## 効果の発動時期（今は通知だけ。発動時期を持つ効果ができたら、ここで処理する）
enum Timing {
	ALLY_BATTLE_START,  ## 1. 味方のバトル開始時
	ENEMY_BATTLE_START,  ## 2. 敵のバトル開始時
	ALLY_TURN_START,  ## 3. 自分および味方のターン開始時
	ENEMY_TURN_START,  ## 9. 敵のターン開始時
	ALLY_TURN_END,  ## 11. 味方のターン終了時
	ENEMY_TURN_END,  ## 12. 敵のターン終了時
}

## 仲間の上限（自分側・敵側とも）
const MAX_ALLIES := 2
const MAX_ENEMY_ALLIES := 2

signal timing_reached(timing: Timing)
signal turn_started(turn_number: int)
signal cards_drawn(cards: Array[CardInstance])
signal deck_reshuffled
signal card_played(card: CardInstance, target: Combatant)
## 使用回数を使い切ったカードが破棄された時
signal card_exhausted(card: CardInstance)
signal damage_dealt(source: Combatant, target: Combatant, detail: Dictionary)
signal armor_gained(target: Combatant, amount: int)
signal healed(target: Combatant, amount: int)
signal modifier_added(target: Combatant, modifier: StatModifier)
signal modifier_expired(target: Combatant, modifier: StatModifier)
signal ally_summoned(ally: AllyCombatant, replaced: AllyCombatant)
signal enemy_summoned(summoner: EnemyCombatant, summoned: EnemyCombatant)
## 実行できる行動が1つもなく、何もしなかった時
signal enemy_action_skipped(enemy: EnemyCombatant)
signal enemy_intent_changed(enemy: EnemyCombatant)
signal combatant_died(combatant: Combatant)
## 状態効果が付いた・変わった・消えた時
signal status_changed(target: Combatant)
## 麻痺のため攻撃できなかった時
signal attack_prevented(combatant: Combatant)
signal discard_required(count: int)
signal cards_discarded(cards: Array[CardInstance])
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
## 倒した敵の数（敵本体・敵のクリーチャー）
var enemies_defeated: int = 0
## 起きたことの記録（同じシードで同じ結果になるかの確認や、不具合調査に使う）
var history: PackedStringArray = []
## ゲーム全体の数値の設定（弱体・脆弱の割合など）
var config: GameConfig = GameConfig.new()

var _cards: Array[CardData] = []
## 今、自分のターンを迎えている側
var _acting_side: TurnSide = TurnSide.NONE


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
	return get_cost_problem(deck.hand[hand_index].data)


## マナ・必要触媒・麻痺だけを見て、そのカードが使えるかを返す（手番かどうかは見ない。画面でカードを暗くする判定に使う）
func get_cost_problem(card: CardData) -> PlayResult:
	if hero.mana < card.cost_mana:
		return PlayResult.NOT_ENOUGH_MANA
	if not hero.meets_catalyst(card):
		return PlayResult.CATALYST_NOT_MET
	if card.card_type == GameEnums.CardType.ATTACK and hero.has_status(GameEnums.StatusType.PARALYSIS):
		return PlayResult.PARALYZED  # 麻痺している間は攻撃魔法を使えない
	return PlayResult.OK


## 筋力・弱体・脆弱を反映したダメージ（Game_Rule.md「ダメージ処理の順序」の2〜4）。端数は切り捨て
func modified_damage(source: Combatant, target: Combatant, base: int) -> int:
	var amount := base
	if source != null:
		amount += source.get_status_value(GameEnums.StatusType.STRENGTH)
		if source.has_status(GameEnums.StatusType.WEAK):
			amount = floori(amount * (100 - config.weak_percent) / 100.0)
	if target.has_status(GameEnums.StatusType.VULNERABLE):
		amount = floori(amount * (100 + config.vulnerable_percent) / 100.0)
	return maxi(0, amount)


## 6. カードを使う。
## target：ターゲットが「敵」なら敵、「味方」なら仲間を指定する（それ以外は null でよい）
## replace_ally：仲間が上限の時に召喚する場合、入れ替える仲間
func play_card(hand_index: int, target: Combatant = null, replace_ally: AllyCombatant = null) -> PlayResult:
	var check := can_play(hand_index)
	if check != PlayResult.OK:
		return check
	var instance: CardInstance = deck.hand[hand_index]
	var card := instance.data
	if not is_valid_target(card, target):
		return PlayResult.INVALID_TARGET
	if needs_replace(card) and (replace_ally == null or not allies.has(replace_ally)):
		return PlayResult.NEEDS_REPLACE

	hero.mana -= card.cost_mana  # 触媒は消費しない
	deck.take_from_hand(hand_index)
	_log("カード使用 %s 対象:%s" % [card.id, target.id if target != null else "-"])
	card_played.emit(instance, target)
	var targets := _resolve_targets(card, target)
	var damage_targets := _resolve_targets(card, target, true)
	for effect: EffectData in card.effects:
		_apply_effect(card, effect, targets, damage_targets, replace_ally)
		if phase == Phase.ENDED:
			break
	# 使ったカードはゴミ箱へ。使用回数を使い切ったら破棄（そのバトル中は戻らない）
	if deck.put_used_card(instance):
		_log("カード破棄 %s（使用回数を使い切った）" % card.id)
		card_exhausted.emit(instance)
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


## 「敵と自分とクリーチャーのいずれか1体」を選ぶカードか
func needs_any_target(card: CardData) -> bool:
	return card.targets.has(GameEnums.Target.ANY)


## 使う時に相手を1体選ぶ必要があるカードか（敵／自分のクリーチャー／いずれか1体）
func needs_target(card: CardData) -> bool:
	return needs_enemy_target(card) or needs_ally_target(card) or needs_any_target(card)


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
	if needs_any_target(card):
		return target != null and get_all_living_units().has(target)
	return true


## 場にいる全員（自分側も敵側も）
func get_all_living_units() -> Array[Combatant]:
	var result_list := get_living_friends()
	result_list.append_array(get_living_enemies())
	return result_list


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
	_begin_side_turn(TurnSide.FRIENDS, get_living_friends())
	_reach(Timing.ALLY_TURN_START)  # 3
	# 3. 自分側の毒のダメージ
	for friend: Combatant in get_living_friends():
		_apply_poison(friend)
		if phase == Phase.ENDED:
			return  # 主人公が毒で倒れた
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
	# 8. 味方の攻撃（召喚したターンから参加。敵の仲間がいれば、後から呼ばれた敵の仲間を狙う）
	for ally: AllyCombatant in allies.duplicate():
		if not ally.is_alive():
			continue
		if ally.has_status(GameEnums.StatusType.PARALYSIS):
			_log("%s 麻痺で攻撃できない" % ally.id)
			attack_prevented.emit(ally)
			continue
		var target := Targeting.pick_attack_target(main_enemy, enemy_allies)
		if target == null:
			break
		_deal_damage(ally, target, ally.roll_attack(rng))
		if phase == Phase.ENDED:
			return
	# 9. 敵のターン開始時効果（敵側の毒のダメージ）
	_begin_side_turn(TurnSide.ENEMIES, get_living_enemies())
	_reach(Timing.ENEMY_TURN_START)
	for enemy: Combatant in get_living_enemies():
		_apply_poison(enemy)
		if phase == Phase.ENDED:
			return  # 敵本体が毒で倒れた
	# 10. 敵の攻撃（敵本体 → 敵の仲間の順。このターンに呼ばれた敵は行動しない）
	var acting: Array[EnemyCombatant] = [main_enemy]
	acting.append_array(enemy_allies)
	for enemy: EnemyCombatant in acting:
		if enemy.is_alive():
			_do_enemy_action(enemy)
			if phase == Phase.ENDED:
				return
	_acting_side = TurnSide.NONE
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
	# 予告した後に状況が変わり、実行できなくなっていたら（例：別の敵が先に仲間を呼んで上限になった）、別の行動を選び直す
	if enemy.intent != null and not EnemyCombatant.is_executable(enemy.intent, _can_enemy_summon()):
		_log("%s 行動を変更" % enemy.id)
		_decide_intent(enemy)
	var action := enemy.intent
	if action == null:
		_log("%s 実行できる行動がない" % enemy.id)
		enemy_action_skipped.emit(enemy)
	else:
		match action.action_type:
			GameEnums.EnemyActionType.ATTACK:
				if enemy.has_status(GameEnums.StatusType.PARALYSIS):
					_log("%s 麻痺で攻撃できない" % enemy.id)
					attack_prevented.emit(enemy)
				else:
					# 攻撃対象は攻撃の瞬間に決める（仲間がいれば後から召喚された仲間、いなければ主人公）
					var target := Targeting.pick_attack_target(hero, allies)
					if target != null:
						_deal_damage(enemy, target, enemy.roll_attack(rng))
			GameEnums.EnemyActionType.DEFEND:
				_gain_armor(enemy, action.amount)
			GameEnums.EnemyActionType.SUMMON:
				_enemy_summon(enemy, action)
			GameEnums.EnemyActionType.APPLY_STATUS:
				# デバフは攻撃と同じ決まりで相手を選び、バフは自分に付ける
				var status_target: Combatant = enemy
				if StatusRules.is_debuff(action.status):
					status_target = Targeting.pick_attack_target(hero, allies)
				if status_target != null:
					var turns := action.status_turns if action.status_turns > 0 else StatusInstance.BATTLE_LONG
					_add_status(status_target, action.status, action.amount, turns)
	if phase == Phase.ENDED:
		return
	_decide_intent(enemy)


## 敵の仲間を呼べるか（敵の仲間が上限の時は、追加で呼ばない）
func _can_enemy_summon() -> bool:
	return enemy_allies.size() < MAX_ENEMY_ALLIES


func _enemy_summon(summoner: EnemyCombatant, action: EnemyActionData) -> void:
	# 実行前に選び直しているので、ここに来る時は必ず呼べる
	var summoned := EnemyCombatant.new(action.summon_enemy, false)
	enemy_allies.append(summoned)
	_log("%s が %s を呼んだ" % [summoner.id, summoned.id])
	enemy_summoned.emit(summoner, summoned)
	_decide_intent(summoned)


func _decide_intent(enemy: EnemyCombatant) -> void:
	enemy.decide_next_action(_can_enemy_summon())
	enemy_intent_changed.emit(enemy)


# ---------- カードの効果 ----------

## カードのターゲット種別から、効果を与える相手の一覧を作る。
## for_damage が true の時は、ダメージを与える相手の一覧を作る：
## 自分側だけを指すターゲット種別（自分・自分のクリーチャーなど）は除く。
## 「敵」「いずれか1体」「全員」は、選んだ相手・含まれる相手にそのままダメージを与える（自分側でも）
func _resolve_targets(card: CardData, chosen: Combatant, for_damage: bool = false) -> Array[Combatant]:
	var list: Array[Combatant] = []
	for target_type: GameEnums.Target in card.targets:
		match target_type:
			GameEnums.Target.ENEMY, GameEnums.Target.ANY:
				if chosen != null:
					list.append(chosen)
			GameEnums.Target.EVERYONE:
				list.append_array(get_all_living_units())
			GameEnums.Target.ALLY:
				if chosen != null and not for_damage:
					list.append(chosen)
			GameEnums.Target.SELF:
				if not for_damage:
					list.append(hero)
			GameEnums.Target.ALL_ALLIES:
				if not for_damage:
					list.append_array(allies)
			GameEnums.Target.SELF_AND_ALL_ALLIES:
				if not for_damage:
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


func _apply_effect(card: CardData, effect: EffectData, targets: Array[Combatant],
		damage_targets: Array[Combatant], replace_ally: AllyCombatant) -> void:
	if effect is DamageEffect:
		for target: Combatant in damage_targets:
			if target.is_alive():
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
	elif effect is StatusEffect:
		var status_effect := effect as StatusEffect
		# ターン数で続くタイプは、カードの効果ターン数（〇〇ターン／バトル中）の間続く
		var turns := card.duration_turns if card.duration == GameEnums.Duration.TURNS else StatusInstance.BATTLE_LONG
		for target: Combatant in targets:
			if target.is_alive():
				_add_status(target, status_effect.status, status_effect.amount, turns)


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

## ダメージを与える（Game_Rule.md「ダメージ処理の順序」）。
## is_attack：攻撃（攻撃魔法・クリーチャーと敵の攻撃）なら true。筋力・弱体・脆弱を反映し、受けた側の棘が反撃する。
## 棘の反撃のダメージは false（筋力などは反映せず、防御力・アーマーだけで減る。棘には反応しない）
func _deal_damage(source: Combatant, target: Combatant, base_damage: int, is_attack: bool = true) -> void:
	var amount := modified_damage(source, target, base_damage) if is_attack else base_damage
	var detail := DamageCalc.apply(target, amount)
	_log("%s → %s ダメージ%d（アーマー-%d HP-%d 残りHP%d）" % [
		source.id if source != null else "-", target.id, amount, detail["armor_absorbed"], detail["hp_damage"], target.hp])
	damage_dealt.emit(source, target, detail)
	if not target.is_alive():
		_on_died(target)
	if phase == Phase.ENDED:
		return
	# 8. 棘：攻撃を受けたら、攻撃してきた相手にダメージを返す
	var thorns := target.get_status_value(GameEnums.StatusType.THORNS)
	if is_attack and thorns > 0 and source != null and source != target and source.is_alive():
		_log("%s の棘" % target.id)
		_deal_damage(target, source, thorns, false)


## 毒：値の分だけHPを減らし（防御力・アーマーは無視）、値を1減らす
func _apply_poison(combatant: Combatant) -> void:
	var poison := combatant.get_status_value(GameEnums.StatusType.POISON)
	if poison <= 0:
		return
	combatant.hp = maxi(0, combatant.hp - poison)
	_log("%s 毒のダメージ%d（残りHP%d）" % [combatant.id, poison, combatant.hp])
	damage_dealt.emit(null, combatant, {"raw": poison, "after_defense": poison, "armor_absorbed": 0, "hp_damage": poison, "poison": true})
	combatant.reduce_status(GameEnums.StatusType.POISON, 1)
	status_changed.emit(combatant)
	if not combatant.is_alive():
		_on_died(combatant)


## 状態効果を付ける。受けた側がまだ自分のターンを迎えていなければ「付いた直後」とする
func _add_status(target: Combatant, type: GameEnums.StatusType, value: int, turns: int) -> void:
	var fresh := _side_of(target) != _acting_side
	target.add_status(type, value, turns, fresh)
	_log("%s 状態効果 %s %d（%s）" % [target.id, GameEnums.StatusType.keys()[type], value,
		"バトル中" if turns == StatusInstance.BATTLE_LONG else "%dターン" % turns])
	status_changed.emit(target)


## 自分のターンの始まり：その側の状態効果の「付いた直後」の印を外す
func _begin_side_turn(side: TurnSide, members: Array[Combatant]) -> void:
	_acting_side = side
	for member: Combatant in members:
		member.mark_statuses_active()


func _side_of(combatant: Combatant) -> TurnSide:
	return TurnSide.ENEMIES if combatant is EnemyCombatant else TurnSide.FRIENDS


func _gain_armor(target: Combatant, amount: int) -> void:
	target.armor = mini(9999, target.armor + amount)
	_log("%s アーマー+%d" % [target.id, amount])
	armor_gained.emit(target, amount)


func _on_died(combatant: Combatant) -> void:
	_log("%s 死亡" % combatant.id)
	if combatant is EnemyCombatant:
		enemies_defeated += 1
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
	if combatant.tick_statuses_turn_end():
		status_changed.emit(combatant)


func _draw(count: int) -> void:
	var drawn := deck.draw(count)
	if not drawn.is_empty():
		var ids := PackedStringArray()
		for card: CardInstance in drawn:
			ids.append(String(card.data.id))
		_log("ドロー %s" % ", ".join(ids))
		cards_drawn.emit(drawn)


func _end(won: bool) -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	result = BattleResult.new(won, hero.hp, hero.get_permanent_modifiers(), turn, enemies_defeated)
	_log("バトル終了 %s（%dターン、主人公HP%d）" % ["勝利" if won else "敗北", turn, result.hero_hp])
	battle_ended.emit(result)


func _reach(timing: Timing) -> void:
	timing_reached.emit(timing)


func _on_deck_reshuffled() -> void:
	_log("ゴミ箱をシャッフルしてデッキに戻した")
	deck_reshuffled.emit()


func _log(text: String) -> void:
	history.append("T%d %s" % [turn, text])
