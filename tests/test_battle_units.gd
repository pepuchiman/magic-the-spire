extends GutTest
## 仲間・敵・攻撃対象の抽選のテスト

const H := preload("res://tests/battle_test_helper.gd")
const ActionType := GameEnums.EnemyActionType


# ---------- 仲間 ----------

func test_fourth_summon_requires_replacement() -> void:
	var deck: Array = []
	for i in 4:
		deck.append(H.summon_card(StringName("call%d" % i), H.ally(StringName("ally%d" % i))))
	var hero := H.hero(deck)
	hero.draw_count = 4
	var battle := H.battle(hero, H.enemy())
	battle.start()
	for i in 3:
		assert_eq(battle.play_card(0), Battle.PlayResult.OK)
	assert_eq(battle.allies.size(), 3, "仲間は3体まで")
	var mana_before := battle.hero.mana
	assert_eq(battle.play_card(0), Battle.PlayResult.NEEDS_REPLACE, "4体目は入れ替えの指定が必要")
	assert_eq(battle.deck.hand.size(), 1, "指定がなければカードは手札に残る")
	assert_eq(battle.hero.mana, mana_before)
	var oldest := battle.allies[0]
	assert_eq(battle.play_card(0, null, oldest), Battle.PlayResult.OK)
	assert_eq(battle.allies.size(), 3, "入れ替えても3体のまま")
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
	for i in 4:
		H.end_turn(battle)
	assert_eq(battle.enemy_allies.size(), 3, "敵の仲間は3体まで")
	assert_null(battle.main_enemy.intent, "実行できる行動がない")
	assert_signal_emitted(battle, "enemy_action_skipped", "実行できる行動がない時だけ、何もしない")


func test_enemy_chooses_other_action_when_three_allies() -> void:
	var boss := H.enemy(100, 0, [_summon_action(H.enemy(10, 0)), H.action(ActionType.DEFEND, 5)])
	var battle := H.battle(H.hero([H.filler()]), boss)
	watch_signals(battle)
	battle.start()
	for i in 5:
		H.end_turn(battle)  # 呼ぶ→防御→呼ぶ→防御→呼ぶ（3体）
	assert_eq(battle.enemy_allies.size(), 3)
	var armor_before := battle.main_enemy.armor
	for i in 3:
		assert_eq(battle.main_enemy.intent.action_type, ActionType.DEFEND, "3体いる時は「味方を呼ぶ」の代わりに別の行動をする")
		H.end_turn(battle)
	assert_eq(battle.main_enemy.armor, armor_before + 15, "防御を3回行った")
	assert_signal_not_emitted(battle, "enemy_action_skipped", "何もしないターンはない")


func test_enemy_reselects_when_summon_becomes_impossible() -> void:
	# 敵の仲間Aは「味方を呼ぶ→防御」。予告した後に、別の敵が先に呼んで3体になった場合
	var minion_b := H.enemy(10, 0)
	var minion_a := H.enemy(10, 0, [_summon_action(minion_b), H.action(ActionType.DEFEND, 3)])
	var boss := H.enemy(100, 0, [_summon_action(minion_a)])
	var battle := H.battle(H.hero([H.filler()]), boss)
	battle.start()
	H.end_turn(battle)  # ボスがA1を呼ぶ（1体）
	H.end_turn(battle)  # ボスがA2を呼ぶ（2体。A2は「呼ぶ」を予告）→ A1がBを呼ぶ（3体）
	var a2 := battle.enemy_allies[1]
	assert_eq(a2.intent.action_type, ActionType.SUMMON, "A2は呼べる時に「味方を呼ぶ」を予告していた")
	H.end_turn(battle)
	assert_eq(battle.enemy_allies.size(), 3, "4体目は呼ばない")
	assert_eq(a2.armor, 3, "実行の瞬間に呼べなくなっていたので、防御に変更した")


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


# ---------- 攻撃対象の抽選 ----------

func test_target_rate_probability() -> void:
	var a := Combatant.new()
	a.base_target_rate = 100
	var b := Combatant.new()
	b.base_target_rate = 100
	var c := Combatant.new()
	c.base_target_rate = 200
	var candidates: Array[Combatant] = [a, b, c]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var counts := {a: 0, b: 0, c: 0}
	for i in 4000:
		counts[Targeting.pick(candidates, rng)] += 1
	assert_almost_eq(counts[a] / 4000.0, 0.25, 0.03, "100 / 400 = 25%")
	assert_almost_eq(counts[c] / 4000.0, 0.5, 0.03, "200 / 400 = 50%")


func test_zero_target_rate_is_never_picked() -> void:
	var a := Combatant.new()
	a.base_target_rate = 0
	var b := Combatant.new()
	b.base_target_rate = 50
	var candidates: Array[Combatant] = [a, b]
	var rng := RandomNumberGenerator.new()
	for i in 200:
		assert_eq(Targeting.pick(candidates, rng), b)
