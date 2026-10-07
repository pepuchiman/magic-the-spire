extends GutTest
## データの読み込みと検証のテスト。
## 異常系は、メモリ上で作ったデータを使う（data/ の実ファイルは変更しない）

const HERO_ID := &"test_hero"


func before_each() -> void:
	TranslationServer.set_locale("ja")


# ---------- 正常系（実データ） ----------

func test_project_data_has_no_validation_errors() -> void:
	var errors := DataValidator.validate_project()
	assert_eq(errors.size(), 0, "実データに検証エラーがない：%s" % str(errors))


func test_loader_reads_sample_data() -> void:
	var loader := DataLoader.new()
	assert_not_null(loader.get_hero(&"flame_mage"), "主人公を読み込める")
	assert_not_null(loader.get_card(&"fireball"), "カードを読み込める")
	assert_not_null(loader.get_enemy(&"boss_witch"), "ボスを読み込める")
	assert_false(loader.index.cards.is_empty(), "カードがある")
	assert_eq(loader.get_dungeon(&"lost_forest").normal_enemies.size(), 3, "サンプルダンジョンの通常の敵は3種")


func test_sample_data_covers_required_card_kinds() -> void:
	var loader := DataLoader.new()
	var colorless := 0
	var multi_color := 0
	var summon := 0
	for card: CardData in loader.index.cards:
		var colors := int(card.required_red > 0) + int(card.required_blue > 0) + int(card.required_green > 0)
		if colors == 0:
			colorless += 1
		elif colors >= 2:
			multi_color += 1
		if card.card_type == GameEnums.CardType.SUMMON:
			summon += 1
	assert_gt(colorless, 0, "無色カードがある")
	assert_gt(multi_color, 0, "複数色カードがある")
	assert_gt(summon, 0, "召喚魔法がある")


func test_boss_has_summon_action() -> void:
	var boss := DataLoader.new().get_enemy(&"boss_witch")
	var has_summon := false
	for action: EnemyActionData in boss.pattern:
		if action.action_type == GameEnums.EnemyActionType.SUMMON:
			has_summon = true
	assert_true(has_summon, "ボスは味方を呼ぶ行動を持つ")


func test_card_description_uses_effect_values() -> void:
	# 読み込み済みデータを書き換えないよう、複製して使う
	var card := DataLoader.new().get_card(&"fireball").duplicate(true) as CardData
	assert_eq(card.get_description(), "12のダメージを与える")
	(card.effects[0] as DamageEffect).amount = 20
	assert_eq(card.get_description(), "20のダメージを与える", "効果の数値を変えると説明文も変わる")


# ---------- 異常系（メモリ上のデータ） ----------

func test_duplicate_card_id_is_reported() -> void:
	var index := _valid_index()
	index.cards.append(_card(&"strike"))
	assert_true(_has_error(DataValidator.validate_index(index), "重複"))


func test_attack_min_over_max_is_reported() -> void:
	var index := _valid_index()
	index.enemies[0].attack_min = 9
	index.enemies[0].attack_max = 3
	assert_true(_has_error(DataValidator.validate_index(index), "攻撃力最少値"))


func test_summon_effect_without_ally_is_reported() -> void:
	var index := _valid_index()
	var card := _card(&"summon_none")
	card.effects.append(SummonEffect.new())
	index.cards.append(card)
	assert_true(_has_error(DataValidator.validate_index(index), "召喚効果に仲間が設定されていません"))


func test_unknown_hero_id_is_reported() -> void:
	var index := _valid_index()
	var card := _card(&"ghost_card")
	card.usable_heroes = [&"no_such_hero"]
	index.cards.append(card)
	assert_true(_has_error(DataValidator.validate_index(index), "存在しない主人公ID"))


func test_summon_action_without_enemy_is_reported() -> void:
	var index := _valid_index()
	var action := EnemyActionData.new()
	action.action_type = GameEnums.EnemyActionType.SUMMON
	index.enemies[0].pattern.append(action)
	assert_true(_has_error(DataValidator.validate_index(index), "呼ぶ敵が設定されていません"))


func test_unregistered_data_is_reported() -> void:
	var index := _valid_index()
	var paths := PackedStringArray(["res://data/cards/not_in_index.tres"])
	assert_true(_has_error(DataValidator.check_unregistered(index, paths), "not_in_index"))


func test_missing_translation_key_is_reported() -> void:
	var index := _valid_index()
	var keys: Dictionary = {"CARD_STRIKE_NAME": true}  # 説明のキーが無い
	var errors := DataValidator.check_translation_keys(index, keys)
	assert_true(_has_error(errors, "CARD_STRIKE_DESC"))


func test_placeholder_without_effect_is_reported() -> void:
	var index := _valid_index()
	var texts: Dictionary = {"CARD_STRIKE_DESC": "{damage}のダメージを与える"}  # 効果が無いのに {damage}
	assert_true(_has_error(DataValidator.check_description_placeholders(index, texts), "{damage}"))
	index.cards[0].effects.append(DamageEffect.new())
	assert_eq(DataValidator.check_description_placeholders(index, texts).size(), 0, "効果があればエラーにならない")


func test_summon_description_uses_ally_name() -> void:
	var card := DataLoader.new().get_card(&"summon_sprite")
	assert_eq(card.get_description(), "火の精霊を召喚する", "仲間の名前が説明文に入る")


func test_modify_param_on_instant_card_is_reported() -> void:
	var index := _valid_index()
	index.cards[0].effects.append(ModifyParamEffect.new())
	assert_true(_has_error(DataValidator.validate_index(index), "瞬間"))


func test_enemy_and_ally_targets_together_is_reported() -> void:
	var index := _valid_index()
	index.cards[0].targets.append(GameEnums.Target.ALLY)
	assert_true(_has_error(DataValidator.validate_index(index), "1つまで"))
	index.cards[0].targets.assign([GameEnums.Target.ANY, GameEnums.Target.SELF])
	assert_false(_has_error(DataValidator.validate_index(index), "1つまで"), "選ぶターゲットが1つなら、他と組み合わせてよい")


func test_two_summon_effects_is_reported() -> void:
	var index := _valid_index()
	var ally := AllyData.new()
	for i in 2:
		var effect := SummonEffect.new()
		effect.ally = ally
		index.cards[0].effects.append(effect)
	assert_true(_has_error(DataValidator.validate_index(index), "1つまで"))


func test_missing_config_is_reported() -> void:
	var index := _valid_index()
	index.config = null
	assert_true(_has_error(DataValidator.validate_index(index), "ゲーム全体の設定"))


func test_event_without_choices_is_reported() -> void:
	var index := _valid_index()
	var event := EventData.new()
	event.id = &"empty_event"
	index.events.append(event)
	assert_true(_has_error(DataValidator.validate_index(index), "選択肢がありません"))


func test_valid_data_has_no_errors() -> void:
	var index := _valid_index()
	assert_eq(DataValidator.validate_index(index).size(), 0)


# ---------- 補助 ----------

func _has_error(errors: PackedStringArray, text: String) -> bool:
	for message: String in errors:
		if text in message:
			return true
	return false


func _card(id: StringName) -> CardData:
	var card := CardData.new()
	card.id = id
	card.name_key = StringName("CARD_%s_NAME" % String(id).to_upper())
	card.description_key = StringName("CARD_%s_DESC" % String(id).to_upper())
	card.usable_heroes = [HERO_ID]
	card.targets.assign([GameEnums.Target.ENEMY])
	return card


## 検証エラーが出ない、最小のデータ一式
func _valid_index() -> DataIndex:
	var index := DataIndex.new()
	var card := _card(&"strike")
	index.cards.append(card)

	var hero := HeroData.new()
	hero.id = HERO_ID
	hero.name_key = &"HERO_TEST_NAME"
	hero.starting_deck.append(card)
	index.heroes.append(hero)

	var enemy := EnemyData.new()
	enemy.id = &"dummy"
	enemy.name_key = &"ENEMY_DUMMY_NAME"
	enemy.attack_min = 1
	enemy.attack_max = 2
	enemy.pattern.append(EnemyActionData.new())
	index.enemies.append(enemy)
	index.config = GameConfig.new()
	return index
