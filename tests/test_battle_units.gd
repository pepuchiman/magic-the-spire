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

func test_enemy_does_not_summon_when_three_allies() -> void:
	var minion := H.enemy(10, 0)
	minion.id = &"minion"
	var summon := H.action(ActionType.SUMMON)
	summon.summon_enemy = minion
	var boss := H.enemy(100, 0, [summon])
	var battle := H.battle(H.hero([H.filler()]), boss)
	watch_signals(battle)
	battle.start()
	for i in 4:
		H.end_turn(battle)
	assert_eq(battle.enemy_allies.size(), 3, "敵の仲間は3体まで")
	assert_signal_emitted(battle, "enemy_action_skipped", "3体いる時は呼ばない")


func test_enemy_loops_pattern() -> void:
	var enemy := EnemyCombatant.new(H.enemy(10, 0, [H.action(ActionType.ATTACK), H.action(ActionType.DEFEND, 3)]), true)
	var order: Array = []
	for i in 4:
		enemy.decide_next_action()
		order.append(enemy.intent.action_type)
	assert_eq(order, [ActionType.ATTACK, ActionType.DEFEND, ActionType.ATTACK, ActionType.DEFEND])


func test_conditional_action_has_priority() -> void:
	var rage := H.action(ActionType.DEFEND, 9)
	rage.condition = GameEnums.EnemyActionCondition.HP_PERCENT_BELOW
	rage.condition_value = 50
	var enemy := EnemyCombatant.new(H.enemy(10, 0, [H.action(ActionType.ATTACK), rage, H.action(ActionType.DEFEND, 1)]), true)
	enemy.decide_next_action()
	assert_eq(enemy.intent.action_type, ActionType.ATTACK, "条件を満たさなければループ通り")
	enemy.hp = 5
	enemy.decide_next_action()
	assert_eq(enemy.intent, rage, "残りHPが50%以下なら条件付き行動を優先")
	enemy.hp = 10
	enemy.decide_next_action()
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
