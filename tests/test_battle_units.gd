extends GutTest
## 仲間・敵・攻撃対象の決定のテスト

const H := preload("res://tests/battle_test_helper.gd")
const ActionType := GameEnums.EnemyActionType


# ---------- 仲間 ----------

func test_third_summon_requires_replacement() -> void:
	var deck: Array = []
	for i in 3:
		deck.append(H.summon_card(StringName("call%d" % i), H.ally(StringName("ally%d" % i))))
	var hero := H.hero(deck)
	var battle := H.battle(hero, H.enemy())
	battle.start()
	for i in 2:
		assert_eq(battle.play_card(0), Battle.PlayResult.OK)
	assert_eq(battle.allies.size(), 2, "仲間は2体まで")
	var mana_before := battle.hero.mana
	assert_eq(battle.play_card(0), Battle.PlayResult.NEEDS_REPLACE, "3体目は入れ替えの指定が必要")
	assert_eq(battle.deck.hand.size(), 1, "指定がなければカードは手札に残る")
	assert_eq(battle.hero.mana, mana_before)
	var oldest := battle.allies[0]
	assert_eq(battle.play_card(0, null, oldest), Battle.PlayResult.OK)
	assert_eq(battle.allies.size(), 2, "入れ替えても2体のまま")
	assert_false(battle.allies.has(oldest), "入れ替えられた仲間は場から消える")


func test_ally_attacks_from_summoned_turn() -> void:
	var hero := H.hero([H.summon_card(&"call", H.ally(&"fighter", 4))])
	var battle := H.battle(hero, H.enemy(50))
	battle.start()
	battle.play_card(0)
	H.end_turn(battle)
	assert_eq(battle.main_enemy.hp, 46, "召喚したターンの「味方の攻撃」から参加する")


func test_ally_target_respects_race() -> void:
	var beast := H.ally(&"beast")
	beast.race = GameEnums.Race.BEAST
	var effect := ArmorEffect.new()
	effect.amount = 3
	var spirit_only := H.card(&"bless", 0, [effect], [GameEnums.Target.ALLY])
	spirit_only.target_races.assign([GameEnums.Race.SPIRIT])
	var hero := H.hero([H.summon_card(&"call", beast), spirit_only])
	var battle := H.battle(hero, H.enemy())
	battle.start()
	battle.play_card(H.hand_index(battle, &"call"))
	var ally := battle.allies[0]
	assert_eq(battle.play_card(H.hand_index(battle, &"bless"), ally), Battle.PlayResult.INVALID_TARGET, "種族が違う仲間は選べない")


# ---------- 敵 ----------

func _summon_action(minion: EnemyData) -> EnemyActionData:
	var summon := H.action(ActionType.SUMMON)
	summon.summon_enemy = minion
	return summon


func test_enemy_does_nothing_when_no_action_is_executable() -> void:
	var boss := H.enemy(100, 0, [_summon_action(H.enemy(10, 0))])  # 「味方を呼ぶ」しか持たない
	var battle := H.battle(H.hero([H.filler()]), boss)
	watch_signals(battle)
	battle.start()
	for i in 3:
		H.end_turn(battle)
	assert_eq(battle.enemy_allies.size(), 2, "敵の仲間は2体まで")
	assert_null(battle.main_enemy.intent, "実行できる行動がない")
	assert_signal_emitted(battle, "enemy_action_skipped", "実行できる行動がない時だけ、何もしない")


func test_enemy_chooses_other_action_when_allies_are_full() -> void:
	var boss := H.enemy(100, 0, [_summon_action(H.enemy(10, 0)), H.action(ActionType.DEFEND, 5)])
	var battle := H.battle(H.hero([H.filler()]), boss)
	watch_signals(battle)
	battle.start()
	for i in 3:
		H.end_turn(battle)  # 呼ぶ→防御→呼ぶ（2体）
	assert_eq(battle.enemy_allies.size(), 2)
	var armor_before := battle.main_enemy.armor
	for i in 3:
		assert_eq(battle.main_enemy.intent.action_type, ActionType.DEFEND, "2体いる時は「味方を呼ぶ」の代わりに別の行動をする")
		H.end_turn(battle)
	assert_eq(battle.main_enemy.armor, armor_before + 15, "防御を3回行った")
	assert_signal_not_emitted(battle, "enemy_action_skipped", "何もしないターンはない")


func test_enemy_reselects_when_summon_becomes_impossible() -> void:
	# 敵の仲間Aは「味方を呼ぶ→防御」。予告した後に、ボスが先に呼んで上限（2体）になった場合
	var minion_a := H.enemy(10, 0, [_summon_action(H.enemy(10, 0)), H.action(ActionType.DEFEND, 3)])
	var boss := H.enemy(100, 0, [_summon_action(minion_a)])
	var battle := H.battle(H.hero([H.filler()]), boss)
	battle.start()
	H.end_turn(battle)  # ボスがA1を呼ぶ（1体。A1は「呼ぶ」を予告）
	var a1 := battle.enemy_allies[0]
	assert_eq(a1.intent.action_type, ActionType.SUMMON, "A1は呼べる時に「味方を呼ぶ」を予告していた")
	H.end_turn(battle)  # ボスがA2を呼ぶ（2体）→ A1は呼べなくなった
	assert_eq(battle.enemy_allies.size(), 2, "3体目は呼ばない")
	assert_eq(a1.armor, 3, "実行の瞬間に呼べなくなっていたので、防御に変更した")


func test_loop_skips_unexecutable_action() -> void:
	var pattern := [H.action(ActionType.ATTACK), _summon_action(H.enemy()), H.action(ActionType.DEFEND, 3)]
	var enemy := EnemyCombatant.new(H.enemy(10, 0, pattern), true)
	var order: Array = []
	for i in 4:
		enemy.decide_next_action(false)  # 呼べない状態
		order.append(enemy.intent.action_type)
	assert_eq(order, [ActionType.ATTACK, ActionType.DEFEND, ActionType.ATTACK, ActionType.DEFEND], "「味方を呼ぶ」を飛ばして次の行動にする")


func test_unexecutable_conditional_action_is_ignored() -> void:
	var call_help := _summon_action(H.enemy())
	call_help.condition = GameEnums.EnemyActionCondition.HP_PERCENT_BELOW
	call_help.condition_value = 50
	var enemy := EnemyCombatant.new(H.enemy(10, 0, [H.action(ActionType.ATTACK), call_help]), true)
	enemy.hp = 3
	enemy.decide_next_action(true)
	assert_eq(enemy.intent, call_help, "条件を満たし、実行できれば優先する")
	enemy.decide_next_action(false)
	assert_eq(enemy.intent.action_type, ActionType.ATTACK, "条件を満たしても、実行できなければ無視して他の行動をする")


func test_enemy_loops_pattern() -> void:
	var enemy := EnemyCombatant.new(H.enemy(10, 0, [H.action(ActionType.ATTACK), H.action(ActionType.DEFEND, 3)]), true)
	var order: Array = []
	for i in 4:
		enemy.decide_next_action(true)
		order.append(enemy.intent.action_type)
	assert_eq(order, [ActionType.ATTACK, ActionType.DEFEND, ActionType.ATTACK, ActionType.DEFEND])


func test_conditional_action_has_priority() -> void:
	var rage := H.action(ActionType.DEFEND, 9)
	rage.condition = GameEnums.EnemyActionCondition.HP_PERCENT_BELOW
	rage.condition_value = 50
	var enemy := EnemyCombatant.new(H.enemy(10, 0, [H.action(ActionType.ATTACK), rage, H.action(ActionType.DEFEND, 1)]), true)
	enemy.decide_next_action(true)
	assert_eq(enemy.intent.action_type, ActionType.ATTACK, "条件を満たさなければループ通り")
	enemy.hp = 5
	enemy.decide_next_action(true)
	assert_eq(enemy.intent, rage, "残りHPが50%以下なら条件付き行動を優先")
	enemy.hp = 10
	enemy.decide_next_action(true)
	assert_eq(enemy.intent.amount, 1, "条件付き行動ではループの位置は進まない（次はループの2番目）")


func test_enemy_defend_gives_armor() -> void:
	var battle := H.battle(H.hero([H.filler()]), H.enemy(10, 0, [H.action(ActionType.DEFEND, 4)]))
	battle.start()
	H.end_turn(battle)
	assert_eq(battle.main_enemy.armor, 4)


# ---------- 攻撃対象の決定 ----------

func _unit(hp: int = 10) -> Combatant:
	var unit := Combatant.new()
	unit.base_max_hp = hp
	unit.hp = hp
	return unit


func test_attack_targets_last_summoned_ally() -> void:
	var body := _unit()
	var first := _unit()
	var second := _unit()
	assert_eq(Targeting.pick_attack_target(body, [first, second]), second, "後から召喚された仲間が狙われる")
	second.hp = 0
	assert_eq(Targeting.pick_attack_target(body, [first, second]), first, "倒れた仲間は飛ばす")
	first.hp = 0
	assert_eq(Targeting.pick_attack_target(body, [first, second]), body, "仲間がいなければ本体が狙われる")


func test_enemy_attacks_ally_before_hero() -> void:
	var hero := H.hero([H.summon_card(&"a", H.ally(&"first")), H.summon_card(&"b", H.ally(&"second"))])
	var enemy := H.enemy(100, 3, [H.action(ActionType.ATTACK)])
	var battle := H.battle(hero, enemy)
	battle.start()
	battle.play_card(H.hand_index(battle, &"a"))
	battle.play_card(H.hand_index(battle, &"b"))
	H.end_turn(battle)
	assert_eq(battle.hero.hp, 20, "仲間がいる間、主人公は攻撃されない")
	assert_eq(battle.allies[1].hp, 7, "後から召喚された仲間が攻撃を受ける")
	assert_eq(battle.allies[0].hp, 10)


func test_ally_attacks_enemy_ally_before_main() -> void:
	var minion := H.enemy(30, 0)
	var boss := H.enemy(100, 0, [_summon_action(minion), H.action(ActionType.DEFEND, 0)])
	var hero := H.hero([H.summon_card(&"call", H.ally(&"fighter", 4))])
	var battle := H.battle(hero, boss)
	battle.start()
	H.end_turn(battle)  # ボスが手下を呼ぶ
	battle.play_card(H.hand_index(battle, &"call"))
	H.end_turn(battle)
	assert_eq(battle.enemy_allies[0].hp, 26, "仲間は敵の仲間を先に攻撃する")
	assert_eq(battle.main_enemy.hp, 100, "敵の仲間がいる間、敵本体は攻撃されない")


# ---------- 新しいターゲット（いずれか1体・全員） ----------

## 主人公＋自分のクリーチャー1体、敵本体＋敵のクリーチャー1体 のバトルを作る
func _full_field_battle(cards: Array) -> Battle:
	var deck: Array = [H.summon_card(&"call", H.ally(&"mine"))]
	deck.append_array(cards)
	var hero := H.hero(deck)
	hero.draw_count = deck.size()
	var boss := H.enemy(100, 0, [_summon_action(H.enemy(30, 0)), H.action(ActionType.DEFEND, 0)])
	var battle := H.battle(hero, boss)
	battle.start()
	battle.play_card(H.hand_index(battle, &"call"))
	H.end_turn(battle)  # ボスが敵のクリーチャーを呼ぶ
	return battle


func test_any_target_can_choose_every_unit() -> void:
	var bolt := H.card(&"bolt", 0, [], [GameEnums.Target.ANY])
	var battle := _full_field_battle([bolt])
	var units: Array[Combatant] = [battle.hero, battle.allies[0], battle.main_enemy, battle.enemy_allies[0]]
	for unit: Combatant in units:
		assert_true(battle.is_valid_target(bolt, unit), "%s を選べる" % unit.id)
	assert_false(battle.is_valid_target(bolt, null), "何も選ばないと使えない")


func test_any_target_damage_hits_own_side() -> void:
	var bolt := H.damage_card(&"bolt", 4, 0)
	bolt.targets.assign([GameEnums.Target.ANY])
	var battle := _full_field_battle([bolt, bolt])
	battle.play_card(H.hand_index(battle, &"bolt"), battle.hero)
	assert_eq(battle.hero.hp, 16, "自分を選べば自分にダメージ")
	var mine := battle.allies[0]
	battle.play_card(H.hand_index(battle, &"bolt"), mine)
	assert_eq(mine.hp, 6, "自分のクリーチャーにもダメージ")


func test_any_target_heal_works_on_enemy() -> void:
	var effect := HealEffect.new()
	effect.amount = 5
	var mend := H.card(&"mend", 0, [effect], [GameEnums.Target.ANY])
	var battle := _full_field_battle([mend])
	battle.enemy_allies[0].hp = 10
	battle.play_card(H.hand_index(battle, &"mend"), battle.enemy_allies[0])
	assert_eq(battle.enemy_allies[0].hp, 15, "敵のクリーチャーも回復できる")


func test_everyone_target_hits_all_units() -> void:
	var nova := H.damage_card(&"nova", 3, 0)
	nova.targets.assign([GameEnums.Target.EVERYONE])
	var battle := _full_field_battle([nova])
	assert_eq(battle.play_card(H.hand_index(battle, &"nova")), Battle.PlayResult.OK, "全員が対象のカードは相手を選ばない")
	assert_eq(battle.hero.hp, 17)
	assert_eq(battle.allies[0].hp, 7)
	assert_eq(battle.main_enemy.hp, 97)
	assert_eq(battle.enemy_allies[0].hp, 27)


func test_self_target_is_not_damaged() -> void:
	var strike := H.damage_card(&"strike", 5, 0)
	strike.targets.assign([GameEnums.Target.ENEMY, GameEnums.Target.SELF])
	var battle := _full_field_battle([strike])
	battle.play_card(H.hand_index(battle, &"strike"), battle.main_enemy)
	assert_eq(battle.main_enemy.hp, 95)
	assert_eq(battle.hero.hp, 20, "「自分」は回復・アーマーなどの対象で、ダメージは受けない")


func test_card_can_target_main_enemy_even_with_enemy_allies() -> void:
	var boss := H.enemy(100, 0, [_summon_action(H.enemy(30, 0)), H.action(ActionType.DEFEND, 0)])
	var battle := H.battle(H.hero([H.damage_card(&"bolt", 5)]), boss)
	battle.start()
	H.end_turn(battle)  # ボスが手下を呼ぶ
	assert_eq(battle.enemy_allies.size(), 1)
	assert_eq(battle.play_card(H.hand_index(battle, &"bolt"), battle.main_enemy), Battle.PlayResult.OK, "カードは敵本体を選べる")
	assert_eq(battle.main_enemy.hp, 95)
