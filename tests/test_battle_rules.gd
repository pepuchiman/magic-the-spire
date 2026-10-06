extends GutTest
## マナ・触媒・ダメージ・効果ターン数・勝敗などのテスト

const H := preload("res://tests/battle_test_helper.gd")
const Param := GameEnums.Param
const Duration := GameEnums.Duration


# ---------- マナと触媒 ----------

func test_catalyst_does_not_grow_on_first_turn() -> void:
	var hero := H.hero([H.filler()])
	hero.catalyst_red = 1
	hero.catalyst_power_red = 2
	var battle := H.battle(hero, H.enemy())
	battle.start()
	assert_eq(battle.hero.catalyst_red, 1, "1ターン目は初期値のまま")
	H.end_turn(battle)
	assert_eq(battle.hero.catalyst_red, 3, "2ターン目から触媒力の分増える")


func test_card_needs_catalyst_and_does_not_consume_it() -> void:
	var red_card := H.damage_card(&"red", 1)
	red_card.required_red = 2
	var hero := H.hero([red_card])
	hero.catalyst_red = 1
	hero.catalyst_power_red = 1
	var battle := H.battle(hero, H.enemy())
	battle.start()
	assert_eq(battle.play_card(0, battle.main_enemy), Battle.PlayResult.CATALYST_NOT_MET, "触媒が足りないと使えない")
	H.end_turn(battle)
	assert_eq(battle.play_card(0, battle.main_enemy), Battle.PlayResult.OK, "触媒が足りれば使える")
	assert_eq(battle.hero.catalyst_red, 2, "使っても触媒は減らない")


func test_card_needs_mana() -> void:
	var hero := H.hero([H.damage_card(&"a", 1, 3), H.damage_card(&"b", 1, 3)])
	var battle := H.battle(hero, H.enemy())
	battle.start()
	assert_eq(battle.play_card(0, battle.main_enemy), Battle.PlayResult.OK)
	assert_eq(battle.hero.mana, 2, "消費マナの分減る")
	assert_eq(battle.play_card(0, battle.main_enemy), Battle.PlayResult.NOT_ENOUGH_MANA, "マナが足りないと使えない")


func test_mana_base_bonus_applies_from_next_turn() -> void:
	var surge := H.modify_card(&"surge", Param.MANA_BASE, 1, Duration.BATTLE)
	surge.cost_mana = 1
	var battle := H.battle(H.hero([surge]), H.enemy())
	battle.start()
	assert_eq(battle.hero.mana, 5)
	battle.play_card(0)
	assert_eq(battle.hero.mana, 4, "使ったターンのマナは増えない")
	H.end_turn(battle)
	assert_eq(battle.hero.mana, 6, "次のターン開始時のマナに、マナ基準値+1が反映される")


# ---------- ダメージ ----------

func test_damage_order_defense_then_armor_then_hp() -> void:
	var target := Combatant.new()
	target.hp = 10
	target.base_max_hp = 10
	target.base_defense = 2
	target.armor = 3
	var detail := DamageCalc.apply(target, 7)
	assert_eq(detail["after_defense"], 5, "防御力の分軽減")
	assert_eq(detail["armor_absorbed"], 3, "アーマーから先に減る")
	assert_eq(target.armor, 0)
	assert_eq(target.hp, 8, "残りの2だけHPが減る")


func test_defense_does_not_make_damage_negative() -> void:
	var target := Combatant.new()
	target.hp = 10
	target.base_max_hp = 10
	target.base_defense = 5
	target.armor = 3
	DamageCalc.apply(target, 2)
	assert_eq(target.hp, 10, "HPは増えない")
	assert_eq(target.armor, 3, "アーマーも減らない")


func test_armor_carries_over_to_next_turn() -> void:
	var battle := H.battle(H.hero([H.armor_card(&"guard", 5)]), H.enemy())
	battle.start()
	battle.play_card(0)
	H.end_turn(battle)
	assert_eq(battle.hero.armor, 5, "アーマーはターンをまたいで残る")


# ---------- 効果ターン数 ----------

func test_turn_effect_counts_down_and_expires() -> void:
	var card := H.modify_card(&"shield", Param.DEFENSE, 3, Duration.TURNS, 2)
	var battle := H.battle(H.hero([card]), H.enemy())
	battle.start()
	battle.play_card(0)
	assert_eq(battle.hero.get_defense(), 3)
	H.end_turn(battle)
	assert_eq(battle.hero.get_defense(), 3, "1ターン目の終了時に残り1")
	H.end_turn(battle)
	assert_eq(battle.hero.get_defense(), 0, "2ターン目の終了時に0になり、効果が終わる")


func test_permanent_modifier_is_carried_to_result() -> void:
	var grow := H.modify_card(&"grow", Param.MAX_HP, 5, Duration.PERMANENT)
	var battle_card := H.modify_card(&"temp", Param.DEFENSE, 1, Duration.BATTLE)
	var hero := H.hero([grow, battle_card, H.damage_card(&"kill", 999, 0)])
	var battle := H.battle(hero, H.enemy(10))
	battle.start()
	battle.play_card(H.hand_index(battle, &"grow"))
	battle.play_card(H.hand_index(battle, &"temp"))
	battle.play_card(H.hand_index(battle, &"kill"), battle.main_enemy)
	assert_true(battle.result.won)
	assert_eq(battle.result.permanent_modifiers.size(), 1, "「永続」だけを引き継ぐ（「バトル中」は引き継がない）")
	assert_eq(battle.result.permanent_modifiers[0].param, Param.MAX_HP)


# ---------- 勝敗 ----------

func test_battle_ends_when_card_kills_main_enemy() -> void:
	var hero := H.hero([H.damage_card(&"big", 100), H.filler(), H.filler()])
	var battle := H.battle(hero, H.enemy(50))
	watch_signals(battle)
	battle.start()
	battle.play_card(H.hand_index(battle, &"big"), battle.main_enemy)
	assert_eq(battle.phase, Battle.Phase.ENDED, "その時点でバトル終了")
	assert_true(battle.result.won)
	assert_signal_emitted(battle, "battle_ended")
	assert_eq(battle.play_card(0), Battle.PlayResult.NOT_PLAYER_TURN, "終了後はカードを使えない")


func test_hero_death_is_game_over_even_with_allies() -> void:
	var protector := H.ally(&"protector", 0, 0)  # ターゲット率0 → 主人公だけが狙われる
	var hero := H.hero([H.summon_card(&"call", protector)], 3)
	var enemy := H.enemy(100, 10, [H.action(GameEnums.EnemyActionType.ATTACK)])
	var battle := H.battle(hero, enemy)
	battle.start()
	battle.play_card(0)
	assert_eq(battle.allies.size(), 1)
	H.end_turn(battle)
	assert_eq(battle.phase, Battle.Phase.ENDED)
	assert_false(battle.result.won, "仲間が残っていてもゲームオーバー")
	assert_eq(battle.allies.size(), 1, "仲間は生きている")
	assert_eq(battle.result.hero_hp, 0)


# ---------- 同じシード ----------

func test_same_seed_gives_same_battle() -> void:
	var loader := DataLoader.new()
	var hero := loader.get_hero(&"flame_mage")
	var enemy := loader.get_enemy(&"boss_witch")
	var first := Battle.new(hero, hero.starting_deck, enemy, 123)
	var second := Battle.new(hero, hero.starting_deck, enemy, 123)
	var result_a := AutoPlayer.run(first)
	var result_b := AutoPlayer.run(second)
	assert_not_null(result_a, "サンプルの1バトルが最後まで進む")
	assert_eq(first.history, second.history, "同じシードなら経過がすべて同じ")
	assert_eq(result_a.hero_hp, result_b.hero_hp)
