extends GutTest
## 装備と、アンロック（進み具合の保存）のテスト

const TEST_PATH := "user://test_progress_unit.cfg"

var loader: DataLoader


func before_each() -> void:
	loader = DataLoader.new()


func after_each() -> void:
	ProgressStore.new(TEST_PATH).reset()  # テスト用のファイルを消す


func _run() -> RunState:
	return RunState.new(loader.get_hero(&"flame_mage"), loader.get_dungeon(&"lost_forest"),
		loader.index.cards, loader.get_config(), 1, loader.index.equipment)


func _item(id: StringName) -> EquipmentData:
	return loader.get_equipment(id)


# ---------- 装備 ----------

func test_one_equipment_per_type() -> void:
	var run := _run()
	assert_null(run.equip(_item(&"ring_small")))
	var replaced := run.equip(_item(&"ring_guard"))
	assert_eq(replaced, _item(&"ring_small"), "同じ種類の装備は入れ替わる")
	assert_eq(run.get_equipped(GameEnums.EquipmentType.RING), _item(&"ring_guard"))
	run.equip(_item(&"staff_oak"))
	assert_eq(run.equipment.size(), 2, "種類が違えば両方装備できる")


func test_equipment_changes_max_hp_only_while_equipped() -> void:
	var run := _run()
	run.equip(_item(&"robe_cloth"))  # 最大HP+6
	assert_eq(run.get_max_hp(), 26)
	run.heal(99)
	assert_eq(run.hp, 26)
	run.equip(_item(&"robe_mage"))  # 鎧を入れ替え：最大HP+8
	assert_eq(run.get_max_hp(), 28)
	var plain := RunState.new(run.hero, run.dungeon, [], run.config, 1)
	assert_eq(plain.get_max_hp(), 20, "装備していなければ元の値")


func test_hp_is_clamped_when_max_hp_drops() -> void:
	var run := _run()
	run.equip(_item(&"robe_mage"))  # 最大HP+8
	run.heal(99)
	assert_eq(run.hp, 28)
	run.equip(_item(&"robe_cloth"))  # 最大HP+6 に下がる
	assert_eq(run.hp, 26, "最大HPが下がったら、HPも最大HPまでに収まる")


func test_equipment_applies_in_battle_and_is_not_carried() -> void:
	var run := _run()
	run.equip(_item(&"ring_guard"))  # 防御力+1
	run.equip(_item(&"staff_oak"))  # 最大手札数+1
	run.move_to(run.available_nodes()[0])
	var battle := run.create_battle()
	assert_eq(battle.hero.get_defense(), 1, "バトルで装備の補正がかかる")
	assert_eq(battle.hero.get_max_hand(), 6)
	battle.start()
	var result := AutoPlayer.run(battle)
	assert_eq(result.permanent_modifiers.size(), 0, "装備の補正は「永続」として引き継がれない")


# ---------- アンロック ----------

func test_record_clear_unlocks_items() -> void:
	var store := ProgressStore.new(TEST_PATH)
	var frost := loader.get_hero(&"frost_mage")
	assert_false(store.is_unlocked(frost.unlocked_by_clearing), "最初は未解放")
	assert_true(store.record_clear(&"lost_forest"), "初めてのクリア")
	assert_false(store.record_clear(&"lost_forest"), "2回目は初めてではない")
	assert_true(store.is_unlocked(frost.unlocked_by_clearing), "迷いの森のクリアで解放")


func test_save_and_load() -> void:
	var store := ProgressStore.new(TEST_PATH)
	store.record_clear(&"lost_forest")
	store.save_progress()
	var loaded := ProgressStore.new(TEST_PATH)
	loaded.load_progress()
	assert_true(loaded.is_cleared(&"lost_forest"), "保存した内容を読み込める")


func test_reset_clears_progress() -> void:
	var store := ProgressStore.new(TEST_PATH)
	store.record_clear(&"lost_forest")
	store.save_progress()
	store.reset()
	assert_false(store.is_cleared(&"lost_forest"))
	assert_false(FileAccess.file_exists(TEST_PATH), "保存ファイルも消える")
	var loaded := ProgressStore.new(TEST_PATH)
	loaded.load_progress()
	assert_eq(loaded.cleared_dungeons.size(), 0)


func test_filter_unlocked() -> void:
	var heroes := ProgressStore.filter_unlocked(loader.index.heroes, null)
	assert_eq(heroes.size(), 1, "最初は1人だけ")
	var store := ProgressStore.new(TEST_PATH)
	store.record_clear(&"lost_forest")
	assert_eq(ProgressStore.filter_unlocked(loader.index.heroes, store).size(), 2, "クリア後は2人")
