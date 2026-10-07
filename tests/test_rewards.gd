extends GutTest
## 報酬のルール（カード・装備・宝箱・ボス）のテスト。
## 抽選は乱数なので、たくさん引いて傾向を確かめる

const NodeType := GameEnums.MapNodeType
const Rarity := GameEnums.Rarity

var loader: DataLoader


func before_each() -> void:
	loader = DataLoader.new()


## start_cards_only：最初から解放されているカードだけにする
func _run(seed_value: int = 1, hero_id: StringName = &"flame_mage", start_cards_only: bool = true) -> RunState:
	var cards: Array[CardData] = []
	cards.assign(ProgressStore.filter_unlocked(loader.index.cards, null) if start_cards_only else loader.index.cards)
	return RunState.new(loader.get_hero(hero_id), loader.get_dungeon(&"lost_forest"), cards,
		loader.get_config(), seed_value, loader.index.equipment)


func _count_rare_or_better(run: RunState, node_type: GameEnums.MapNodeType, rounds: int) -> int:
	var count := 0
	for i in rounds:
		for card: CardData in RewardGenerator.card_choices(run, node_type):
			if card.rarity >= Rarity.RARE:
				count += 1
	return count


# ---------- カード ----------

func test_only_usable_and_unlocked_cards() -> void:
	var run := _run()
	for i in 100:
		for card: CardData in RewardGenerator.card_choices(run):
			assert_true(card.usable_heroes.has(&"flame_mage"), "主人公が使えるカードだけ")
			assert_eq(card.unlocked_by_clearing, &"", "未解放のカード（%s）は出ない" % card.id)


func test_unlocked_card_appears_after_unlock() -> void:
	var run := _run(1, &"flame_mage", false)  # すべて解放済み
	assert_true(run.card_pool.any(func(c: CardData) -> bool: return c.id == &"meteor"), "解放されると報酬の候補に入る")


func test_three_distinct_cards_with_varied_types() -> void:
	var run := _run(3)
	var all_same_type := 0
	for i in 200:
		var choices := RewardGenerator.card_choices(run)
		assert_eq(choices.size(), 3)
		var ids := {}
		var types := {}
		for card: CardData in choices:
			ids[card.id] = true
			types[card.card_type] = true
		assert_eq(ids.size(), 3, "3枚とも違うカード")
		if types.size() == 1:
			all_same_type += 1
	assert_eq(all_same_type, 0, "3枚とも同じ種別になることはない（候補に別の種別がある限り）")


func test_other_color_is_always_included() -> void:
	var run := _run(5)
	var main_color := RewardGenerator.main_color_of(RewardGenerator.deck_color_counts(run.deck))
	assert_eq(main_color, "red", "炎の魔法使いの初期デッキは赤が多い")
	for i in 200:
		var choices := RewardGenerator.card_choices(run)
		assert_true(choices.any(func(c: CardData) -> bool: return RewardGenerator.has_other_color(c, main_color)),
			"デッキに多い色以外のカードが最低1枚ある")


func test_main_color_appears_more_often() -> void:
	var run := _run(7)
	var red := 0
	var blue := 0
	for i in 400:
		for card: CardData in RewardGenerator.card_choices(run):
			if card.required_red > 0:
				red += 1
			if card.required_blue > 0:
				blue += 1
	assert_gt(red, blue, "デッキに多い色（赤）のカードが出やすい")


func test_rare_rate_increases_with_battles() -> void:
	var early := _run(11)
	var late := _run(11)
	late.battles_won = 15
	assert_gt(_count_rare_or_better(late, NodeType.BATTLE, 300), _count_rare_or_better(early, NodeType.BATTLE, 300),
		"戦闘を重ねるほどレア以上が出やすい")


func test_elite_has_higher_rare_rate() -> void:
	var normal := _run(13)
	var elite := _run(13)
	assert_gt(_count_rare_or_better(elite, NodeType.ELITE, 300), _count_rare_or_better(normal, NodeType.BATTLE, 300),
		"エリート戦はレア以上が出やすい")


func test_boss_cards_are_rare_or_better() -> void:
	var run := _run(17)
	for i in 50:
		var rewards := RewardGenerator.boss_rewards(run)
		for card: CardData in rewards["cards"]:
			assert_true(card.rarity >= Rarity.RARE, "ボスの報酬はレア以上")
		assert_true(rewards["equipment"].rarity >= Rarity.RARE, "ボスは上級装備（レア以上）")


# ---------- 装備 ----------

func test_normal_battle_equipment_is_low_rarity_and_rare() -> void:
	var run := _run(19)
	var given := 0
	for i in 400:
		var item := RewardGenerator.equipment_reward(run, NodeType.BATTLE)
		if item != null:
			given += 1
			assert_true(item.rarity <= Rarity.UNCOMMON, "通常戦の装備はコモン・アンコモンだけ")
	assert_between(given, 20, 110, "通常戦の装備は低確率（設定15%）")


func test_elite_always_gives_equipment() -> void:
	var run := _run(23)
	var rare_seen := false
	for i in 100:
		var item := RewardGenerator.equipment_reward(run, NodeType.ELITE)
		assert_not_null(item, "エリート戦は装備が確定")
		rare_seen = rare_seen or item.rarity >= Rarity.RARE
	assert_true(rare_seen, "エリート戦ではレア以上の装備も出る")


func test_treasure_gives_equipment_or_rare_card() -> void:
	var run := _run(29)
	var kinds := {}
	for i in 100:
		var content := RewardGenerator.treasure(run)
		if content.has("card"):
			kinds["card"] = true
			assert_true(content["card"].rarity >= Rarity.RARE, "宝箱のカードはレア以上")
		else:
			kinds["equipment"] = true
	assert_eq(kinds.size(), 2, "装備もカードも出る")
