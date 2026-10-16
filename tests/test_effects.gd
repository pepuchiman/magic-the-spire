extends GutTest
## エフェクト（演出）のテスト

const SCREEN_SCENE := preload("res://scenes/battle/battle_screen.tscn")
const H := preload("res://tests/battle_test_helper.gd")


func before_each() -> void:
	TranslationServer.set_locale("ja")


func test_every_effect_plays_and_removes_itself() -> void:
	var effects := EffectSet.create_default()
	var nodes: Array[Node] = []
	for scene: PackedScene in effects.attack_effects.values() + effects.card_effects.values():
		var effect: Node2D = scene.instantiate()
		add_child(effect)
		effect.play(100.0, 0.05)
		nodes.append(effect)
	await wait_seconds(0.3)
	for node: Node in nodes:
		assert_false(is_instance_valid(node), "エフェクトは終わったら自分を消す")


func test_missing_effect_scene_is_reported() -> void:
	var effects := EffectSet.create_default()
	effects.card_effects.erase(GameEnums.CardEffect.LIGHTNING)
	var errors := DataValidator._check_effects(effects)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "LIGHTNING")
	assert_eq(DataValidator._check_effects(EffectSet.create_default()).size(), 0, "全種類そろっていれば問題なし")


func test_effect_targets_include_everyone() -> void:
	var everyone := H.damage_card(&"wave", 3)
	everyone.targets.assign([GameEnums.Target.EVERYONE])
	var battle := H.battle(H.hero([everyone]), H.enemy())
	battle.start()
	var targets := battle.effect_targets(everyone, null)
	assert_true(targets.has(battle.hero) and targets.has(battle.main_enemy), "「全員」のカードは全員に演出を出す")


func test_no_effects_are_created_when_animation_is_off() -> void:
	var screen: BattleScreen = SCREEN_SCENE.instantiate()
	screen.animation_speed = 0.0
	screen.seed_value = 1
	add_child_autofree(screen)
	var layer: Control = screen.get_node("%EffectLayer")
	var before := layer.get_child_count()
	_play_first_card(screen)
	assert_eq(layer.get_child_count(), before, "演出の速さが0なら、エフェクトを作らない")


func test_effects_are_cleaned_up_after_animation() -> void:
	var screen: BattleScreen = SCREEN_SCENE.instantiate()
	screen.animation_speed = 3.0
	screen.seed_value = 1
	add_child_autofree(screen)
	await wait_frames(2)
	var layer: Control = screen.get_node("%EffectLayer")
	var before := layer.get_child_count()
	_play_first_card(screen)
	assert_false(screen.is_idle(), "カードを使うと演出が始まる")
	await wait_for_signal(screen.animations_finished, 10.0)
	await wait_seconds(1.5)  # 数字やエフェクトが消えるのを待つ
	assert_eq(layer.get_child_count(), before, "演出が終わると、エフェクトはすべて消えている")


## 使えるカードを1枚使う
func _play_first_card(screen: BattleScreen) -> void:
	var battle := screen.battle
	for i in battle.deck.hand.size():
		var card: CardData = battle.deck.hand[i].data
		if battle.get_cost_problem(card) == Battle.PlayResult.OK and not battle.needs_replace(card):
			screen.try_play_card(i, AutoPlayer.choose_target(battle, card))
			return
	fail_test("使えるカードがない")


func test_enemy_returns_to_its_place_after_attacking() -> void:
	var screen: BattleScreen = SCREEN_SCENE.instantiate()
	screen.animation_speed = 0.0
	screen.seed_value = 1
	add_child_autofree(screen)
	await wait_frames(3)
	var enemy_view: UnitSprite = screen._views[screen.battle.main_enemy]
	var body: Control = enemy_view.effect_anchor()
	var home := body.position
	assert_gt(home.y, 0.0, "敵の姿は行動予告の下にある（元の位置は 0 ではない）")
	enemy_view.play_attack_motion(0.1, Vector2(-200, 300))
	await wait_seconds(0.03)
	enemy_view.play_attack_motion(0.1, Vector2(-200, 300))  # 動きの途中で、続けて攻撃
	await wait_seconds(0.3)
	assert_eq(body.position, home, "攻撃のあと、敵の姿は元の位置に戻る（上にずれない）")
