extends GutTest
## 中断データ（ランの保存と読み込み）のテスト。
## ファイルはテスト用の一時ファイルを使い、終わったら消す

const TEST_PATH := "user://test_run_save_unit.json"

var loader: DataLoader


func before_each() -> void:
	loader = DataLoader.new()


func after_each() -> void:
	RunSaveStore.new(TEST_PATH).delete()


func _run(seed_value: int = 4) -> RunState:
	return RunState.new(loader.get_hero(&"flame_mage"), loader.get_dungeon(&"lost_forest"),
		loader.index.cards, loader.get_config(), seed_value, loader.index.equipment)


## ファイルに書いて読み戻したのと同じ形（JSON を通す）にしてから、ランに戻す
func _round_trip(run: RunState, screen: int = 3) -> RunState:
	var text := JSON.stringify(RunSerializer.to_dict(run, screen))
	return RunSerializer.from_dict(JSON.parse_string(text), loader)


## 少し進めたラン（HP・カード・装備・永続の補正・現在地が初期状態と違う）
func _progressed_run() -> RunState:
	var run := _run()
	run.move_to(run.available_nodes()[0])
	run.move_to(run.available_nodes()[0])
	run.hp = 13
	run.add_card(loader.get_card(&"meteor"))
	run.equip(loader.get_equipment(&"ring_guard"))
	run.equip(loader.get_equipment(&"robe_cloth"))
	run.permanent_modifiers.append(StatModifier.new(GameEnums.Param.MAX_HP, 3, GameEnums.Duration.PERMANENT))
	run.battles_won = 2
	run.enemies_defeated = 3
	run.play_seconds = 123.5
	run.rng.randi()  # 乱数を少し進めておく
	return run


func test_round_trip_keeps_run_state() -> void:
	var run := _progressed_run()
	var restored := _round_trip(run)
	assert_not_null(restored, "読み込める")
	assert_eq(restored.hero, run.hero)
	assert_eq(restored.dungeon, run.dungeon)
	assert_eq(restored.hp, 13)
	assert_eq(restored.deck, run.deck, "所持カードが元どおり")
	assert_eq(restored.card_pool, run.card_pool, "報酬に出せるカードが元どおり")
	assert_eq(restored.equipment, run.equipment, "装備が元どおり")
	assert_eq(restored.get_max_hp(), run.get_max_hp(), "装備・永続の補正を含めた最大HPが元どおり")
	assert_eq(restored.battles_won, 2)
	assert_eq(restored.enemies_defeated, 3)
	assert_almost_eq(restored.play_seconds, 123.5, 0.01)


func test_round_trip_keeps_map_and_position() -> void:
	var run := _progressed_run()
	var restored := _round_trip(run)
	assert_eq(restored.map.floor_count(), run.map.floor_count())
	for floor_index in run.map.floor_count():
		var original: Array = run.map.get_floor(floor_index)
		var copy: Array = restored.map.get_floor(floor_index)
		assert_eq(copy.size(), original.size())
		for i in original.size():
			assert_eq(copy[i].type, original[i].type, "ノードの種類")
			assert_eq(copy[i].enemy, original[i].enemy, "敵")
			assert_eq(copy[i].event, original[i].event, "イベント")
			assert_eq(copy[i].visited, original[i].visited, "通過済みか")
			assert_eq(copy[i].next.map(func(n: MapNode) -> int: return n.index),
				original[i].next.map(func(n: MapNode) -> int: return n.index), "つながり")
	assert_eq(restored.current_floor_number(), run.current_floor_number(), "現在地")
	assert_eq(restored.current_node.index, run.current_node.index)
	assert_eq(restored.available_nodes().size(), run.available_nodes().size(), "同じノードへ進める")


func test_random_state_is_restored() -> void:
	var run := _progressed_run()
	var restored := _round_trip(run)
	for i in 5:
		assert_eq(restored.rng.randi(), run.rng.randi(), "再開後も同じ乱数が出る")


func test_rewards_are_the_same_after_resume() -> void:
	var run := _progressed_run()
	var restored := _round_trip(run)
	assert_eq(RewardGenerator.card_choices(restored), RewardGenerator.card_choices(run), "同じ報酬が出る")
	assert_eq(RewardGenerator.treasure(restored), RewardGenerator.treasure(run), "同じ宝箱の中身")


func test_battle_is_the_same_after_resume() -> void:
	var run := _run(9)
	run.move_to(run.available_nodes()[0])
	var restored := _round_trip(run)
	var original_battle := run.create_battle()
	var resumed_battle := restored.create_battle()
	AutoPlayer.run(original_battle)
	AutoPlayer.run(resumed_battle)
	assert_eq(resumed_battle.history, original_battle.history, "再開すると、同じバトルを最初から")


func test_screen_is_saved() -> void:
	var data := RunSerializer.to_dict(_run(), 5)
	assert_eq(int(data["screen"]), 5)


# ---------- 読み込めないデータ ----------

func test_unknown_id_is_rejected() -> void:
	var data := RunSerializer.to_dict(_progressed_run(), 3)
	data["deck"].append("no_such_card")
	assert_null(RunSerializer.from_dict(data, loader), "存在しないカードIDがあれば読み込まない")


func test_wrong_version_is_rejected() -> void:
	var data := RunSerializer.to_dict(_run(), 3)
	data["version"] = 999
	assert_null(RunSerializer.from_dict(data, loader), "形式の番号が違えば読み込まない")


func test_empty_data_is_rejected() -> void:
	assert_null(RunSerializer.from_dict({}, loader))


# ---------- ファイル ----------

func test_store_write_read_delete() -> void:
	var store := RunSaveStore.new(TEST_PATH)
	assert_false(store.exists())
	assert_true(store.write({"a": 1}))
	assert_true(store.exists())
	assert_eq(int(store.read()["a"]), 1)
	store.delete()
	assert_false(store.exists(), "消せる")


func test_broken_file_reads_as_empty() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ これは壊れたデータ")
	file.close()
	assert_eq(RunSaveStore.new(TEST_PATH).read(), {}, "壊れたファイルは空として扱う（止まらない）")
