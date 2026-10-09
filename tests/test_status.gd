extends GutTest
## 状態効果（毒・麻痺・弱体・脆弱・筋力・棘）のテスト。動きは docs/Game_Elements.md を参照

const H := preload("res://tests/battle_test_helper.gd")
const S := GameEnums.StatusType
const ActionType := GameEnums.EnemyActionType


func _status_card(id: StringName, type: GameEnums.StatusType, amount: int,
		duration: GameEnums.Duration = GameEnums.Duration.INSTANT, turns: int = 0, extra: Array = []) -> CardData:
	var effect := StatusEffect.new()
	effect.status = type
	effect.amount = amount
	var effects: Array = extra.duplicate()
	effects.append(effect)
	var card := H.card(id, 0, effects, [GameEnums.Target.ANY])
	card.duration = duration
	card.duration_turns = turns
	return card


func _status_action(type: GameEnums.StatusType, amount: int, turns: int = 0) -> EnemyActionData:
	var action := H.action(ActionType.APPLY_STATUS, amount)
	action.status = type
	action.status_turns = turns
	return action


## 何もしない敵とのバトルを始める（手札は deck の全部）
func _battle(deck: Array, enemy: EnemyData = null) -> Battle:
	var hero := H.hero(deck)
	hero.draw_count = deck.size()
	var battle := H.battle(hero, enemy if enemy != null else H.enemy(100, 0))
	battle.start()
	return battle


# ---------- 毒 ----------

func test_poison_damages_at_turn_start_ignoring_armor() -> void:
	var battle := _battle([_status_card(&"venom", S.POISON, 5)])
	battle.main_enemy.armor = 10
	battle.main_enemy.base_defense = 3
	battle.play_card(0, battle.main_enemy)
	assert_eq(battle.main_enemy.hp, 100, "付けただけではダメージはない")
	H.end_turn(battle)  # 敵のターン開始時に毒
	assert_eq(battle.main_enemy.hp, 95, "防御力・アーマーを無視して5ダメージ")
	assert_eq(battle.main_enemy.armor, 10)
	assert_eq(battle.main_enemy.get_status_value(S.POISON), 4, "ダメージの後に値が1減る")


func test_poison_wears_off_and_stacks() -> void:
	var battle := _battle([_status_card(&"a", S.POISON, 1), _status_card(&"b", S.POISON, 2)])
	battle.play_card(0, battle.main_enemy)
	battle.play_card(0, battle.main_enemy)
	assert_eq(battle.main_enemy.get_status_value(S.POISON), 3, "重ねがけで値が足される")
	for i in 3:
		H.end_turn(battle)
	assert_eq(battle.main_enemy.hp, 100 - 3 - 2 - 1, "3 → 2 → 1 とダメージ")
	assert_false(battle.main_enemy.has_status(S.POISON), "0で消える")


func test_poison_can_win_the_battle() -> void:
	var battle := _battle([_status_card(&"venom", S.POISON, 9)], H.enemy(5, 0))
	battle.play_card(0, battle.main_enemy)
	H.end_turn(battle)
	assert_eq(battle.phase, Battle.Phase.ENDED)
	assert_true(battle.result.won, "毒で敵本体を倒すと勝利")


func test_enemy_poison_can_defeat_hero() -> void:
	var enemy := H.enemy(100, 0, [_status_action(S.POISON, 30)])
	var battle := _battle([H.filler()], enemy)
	H.end_turn(battle)  # 敵が主人公に毒を与え、次の主人公のターン開始時に毒のダメージ
	assert_eq(battle.phase, Battle.Phase.ENDED)
	assert_false(battle.result.won, "毒で主人公が倒れるとゲームオーバー")
	assert_eq(battle.turn, 2, "主人公のターン開始時に倒れた")


# ---------- 麻痺 ----------

func test_paralyzed_enemy_does_not_attack() -> void:
	var enemy := H.enemy(100, 5, [H.action(ActionType.ATTACK)])
	var battle := _battle([_status_card(&"stun", S.PARALYSIS, 1)], enemy)
	watch_signals(battle)
	battle.play_card(0, battle.main_enemy)
	H.end_turn(battle)
	assert_eq(battle.hero.hp, 20, "麻痺している敵は攻撃しない")
	assert_signal_emitted(battle, "attack_prevented")
	assert_false(battle.main_enemy.has_status(S.PARALYSIS), "敵のターン終了時に値が減って消える")
	H.end_turn(battle)
	assert_eq(battle.hero.hp, 15, "麻痺が解けると攻撃する")


func test_paralyzed_enemy_still_defends() -> void:
	var enemy := H.enemy(100, 5, [H.action(ActionType.DEFEND, 4)])
	var battle := _battle([_status_card(&"stun", S.PARALYSIS, 1)], enemy)
	battle.play_card(0, battle.main_enemy)
	H.end_turn(battle)
	assert_eq(battle.main_enemy.armor, 4, "攻撃以外の行動はできる")


func test_paralyzed_creature_does_not_attack() -> void:
	var battle := _battle([H.summon_card(&"call", H.ally(&"fighter", 4)), _status_card(&"stun", S.PARALYSIS, 1)])
	battle.play_card(H.hand_index(battle, &"call"))
	battle.play_card(H.hand_index(battle, &"stun"), battle.allies[0])
	H.end_turn(battle)
	assert_eq(battle.main_enemy.hp, 100, "麻痺しているクリーチャーは攻撃しない")


func test_paralyzed_hero_cannot_use_attack_magic() -> void:
	var enemy := H.enemy(100, 0, [_status_action(S.PARALYSIS, 1), H.action(ActionType.DEFEND, 0)])
	var strike := H.damage_card(&"strike", 3, 0)
	strike.targets.assign([GameEnums.Target.ANY])
	var guard := H.armor_card(&"guard", 2, 0)
	guard.card_type = GameEnums.CardType.BUFF  # 付与魔法
	var battle := _battle([strike, guard], enemy)
	H.end_turn(battle)  # 敵が主人公を麻痺させる
	assert_true(battle.hero.has_status(S.PARALYSIS), "付いた直後の味方のターン終了時には減らない")
	assert_eq(battle.play_card(H.hand_index(battle, &"strike"), battle.main_enemy), Battle.PlayResult.PARALYZED, "攻撃魔法は使えない")
	assert_eq(battle.play_card(H.hand_index(battle, &"guard")), Battle.PlayResult.OK, "付与魔法は使える")
	H.end_turn(battle)
	assert_false(battle.hero.has_status(S.PARALYSIS), "主人公のターンが終わると消える")


# ---------- 弱体・脆弱・筋力 ----------

func test_strength_weak_vulnerable_order() -> void:
	var battle := _battle([H.filler()])
	var config := GameConfig.new()  # 弱体25%・脆弱50%
	battle.config = config
	var attacker := battle.hero
	var target := battle.main_enemy
	attacker.add_status(S.STRENGTH, 2, StatusInstance.BATTLE_LONG, false)
	assert_eq(battle.modified_damage(attacker, target, 10), 12, "筋力を足す")
	attacker.add_status(S.WEAK, 1, 2, false)
	assert_eq(battle.modified_damage(attacker, target, 10), 9, "(10+2)×0.75 = 9")
	target.add_status(S.VULNERABLE, 1, 2, false)
	assert_eq(battle.modified_damage(attacker, target, 10), 13, "9×1.5 = 13.5 → 切り捨てて13")


func test_vulnerable_then_defense_and_armor() -> void:
	var strike := H.damage_card(&"strike", 10, 0)
	strike.targets.assign([GameEnums.Target.ANY])
	var battle := _battle([_status_card(&"break", S.VULNERABLE, 1, GameEnums.Duration.TURNS, 2), strike])
	battle.main_enemy.base_defense = 3
	battle.main_enemy.armor = 4
	battle.play_card(H.hand_index(battle, &"break"), battle.main_enemy)
	battle.play_card(H.hand_index(battle, &"strike"), battle.main_enemy)
	assert_eq(battle.main_enemy.hp, 100 - (15 - 3 - 4), "10×1.5=15 → 防御3 → アーマー4 → HP-8")


# ---------- 棘 ----------

func test_thorns_reflect_attacks() -> void:
	var enemy := H.enemy(100, 5, [H.action(ActionType.ATTACK)])
	var battle := _battle([_status_card(&"spikes", S.THORNS, 3, GameEnums.Duration.BATTLE)], enemy)
	battle.main_enemy.base_defense = 1
	battle.play_card(0, battle.hero)
	H.end_turn(battle)
	assert_eq(battle.hero.hp, 15, "主人公は攻撃を受ける")
	assert_eq(battle.main_enemy.hp, 98, "棘3が返る（敵の防御力1で減って2）")


func test_thorns_do_not_react_to_poison_or_thorns() -> void:
	var battle := _battle([H.filler()])
	battle.hero.add_status(S.THORNS, 3, StatusInstance.BATTLE_LONG, false)
	battle.main_enemy.add_status(S.THORNS, 3, StatusInstance.BATTLE_LONG, false)
	battle._deal_damage(battle.main_enemy, battle.hero, 4)
	assert_eq(battle.hero.hp, 16, "主人公は攻撃の4だけを受ける（自分の棘の反撃に、敵の棘は反応しない）")
	assert_eq(battle.main_enemy.hp, 97, "敵は主人公の棘の3を受ける")
	battle.hero.add_status(S.POISON, 2, 0, false)
	battle._apply_poison(battle.hero)
	assert_eq(battle.hero.hp, 14, "毒のダメージ")
	assert_eq(battle.main_enemy.hp, 97, "毒のダメージには棘は反応しない")


# ---------- ターン数で続くタイプ ----------

func test_turn_based_status_expires_and_stacks() -> void:
	var curse := _status_card(&"curse", S.WEAK, 1, GameEnums.Duration.TURNS, 2)
	var battle := _battle([curse, curse])
	battle.play_card(0, battle.main_enemy)
	battle.play_card(0, battle.main_enemy)
	assert_eq(battle.main_enemy.statuses[S.WEAK].turns, 4, "重ねがけでターン数が足される")
	for i in 4:
		assert_true(battle.main_enemy.has_status(S.WEAK))
		H.end_turn(battle)
	assert_false(battle.main_enemy.has_status(S.WEAK), "4ターンで消える")


func test_battle_long_status_stays_and_adds_value() -> void:
	var chant := _status_card(&"chant", S.STRENGTH, 2, GameEnums.Duration.BATTLE)
	var battle := _battle([chant, chant])
	battle.play_card(0, battle.hero)
	battle.play_card(0, battle.hero)
	assert_eq(battle.hero.get_status_value(S.STRENGTH), 4, "バトル中の効果は値が足される")
	for i in 5:
		H.end_turn(battle)
	assert_eq(battle.hero.get_status_value(S.STRENGTH), 4, "バトル中は消えない")


func test_self_buff_counts_from_current_turn() -> void:
	var battle := _battle([_status_card(&"chant", S.STRENGTH, 2, GameEnums.Duration.TURNS, 1)])
	battle.play_card(0, battle.hero)
	assert_true(battle.hero.has_status(S.STRENGTH))
	H.end_turn(battle)
	assert_false(battle.hero.has_status(S.STRENGTH), "自分のターン中に付いた効果は、そのターンから数える")


# ---------- 敵の状態効果・表示 ----------

func test_enemy_buff_goes_to_itself() -> void:
	var enemy := H.enemy(100, 0, [_status_action(S.STRENGTH, 3)])
	var battle := _battle([H.filler()], enemy)
	H.end_turn(battle)
	assert_eq(battle.main_enemy.get_status_value(S.STRENGTH), 3, "バフは自分自身に付く")


func test_enemy_debuff_targets_creature_first() -> void:
	var enemy := H.enemy(100, 0, [_status_action(S.POISON, 2)])
	var battle := _battle([H.summon_card(&"call", H.ally(&"shield"))], enemy)
	battle.play_card(0)
	H.end_turn(battle)  # 敵がクリーチャーに毒2 → 次の味方のターン開始時に毒のダメージ2、値は1に
	assert_eq(battle.allies[0].hp, 8, "デバフは攻撃と同じく、クリーチャーに先に付く")
	assert_eq(battle.allies[0].get_status_value(S.POISON), 1)
	assert_false(battle.hero.has_status(S.POISON), "主人公には付かない")


func test_intent_and_status_texts() -> void:
	TranslationServer.set_locale("ja")
	var enemy := EnemyCombatant.new(H.enemy(10, 0, [_status_action(S.POISON, 3)]), true)
	enemy.decide_next_action(true)
	assert_eq(UiText.intent_text(enemy), "毒を与える 3")
	enemy.add_status(S.POISON, 5, 0, false)
	enemy.add_status(S.WEAK, 1, 2, false)
	enemy.add_status(S.STRENGTH, 2, StatusInstance.BATTLE_LONG, false)
	assert_eq(UiText.status_text(enemy), "毒 5　弱体（残り2）　筋力 2（バトル中）")


func test_same_seed_same_battle_with_statuses() -> void:
	var loader := DataLoader.new()
	var hero := loader.get_hero(&"flame_mage")
	var deck: Array[CardData] = hero.starting_deck.duplicate()
	for id: StringName in [&"poison_mist", &"thunderbolt", &"curse", &"power_chant"]:
		deck.append(loader.get_card(id))
	var a := Battle.new(hero, deck, loader.get_enemy(&"venom_spider"), 77)
	var b := Battle.new(hero, deck, loader.get_enemy(&"venom_spider"), 77)
	assert_not_null(AutoPlayer.run(a), "最後まで進む")
	AutoPlayer.run(b)
	assert_eq(a.history, b.history, "同じシードなら同じ経過")
