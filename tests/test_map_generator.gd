extends GutTest
## マップ生成のテスト（いろいろなシードで、決まりが守られているか確かめる）

const Type := GameEnums.MapNodeType
const SEEDS := [1, 2, 3, 42, 777, 2024, 31337, 99999]


func _dungeon(floor_count: int = 10) -> DungeonData:
	var dungeon: DungeonData = DataLoader.new().get_dungeon(&"lost_forest").duplicate()
	dungeon.floor_count = floor_count
	return dungeon


func _generate(seed_value: int, floor_count: int = 10) -> MapData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return MapGenerator.generate(_dungeon(floor_count), rng)


func test_floor_count_and_node_count() -> void:
	for seed_value: int in SEEDS:
		var map := _generate(seed_value)
		assert_eq(map.floor_count(), 10, "階数はダンジョンの設定どおり")
		for floor_index in 9:
			var size := map.get_floor(floor_index).size()
			assert_between(size, 2, 3, "各階は2〜3ノード")
		assert_eq(map.get_floor(9).size(), 1, "最上階はボス1つ")


func test_floor_rules() -> void:
	for seed_value: int in SEEDS:
		var map := _generate(seed_value)
		for node: MapNode in map.get_floor(0):
			assert_eq(node.type, Type.BATTLE, "1階は通常戦のみ")
		for node: MapNode in map.get_floor(8):
			assert_eq(node.type, Type.REST, "ボスの直前の階は休憩のみ")
		assert_eq(map.get_floor(9)[0].type, Type.BOSS, "最上階はボス")
		var middle_rest := false
		for floor_index: int in MapGenerator.middle_floors(10):
			for node: MapNode in map.get_floor(floor_index):
				middle_rest = middle_rest or node.type == Type.REST
		assert_true(middle_rest, "中盤に休憩が最低1つある（シード%d）" % seed_value)


func test_no_dead_ends() -> void:
	for seed_value: int in SEEDS:
		var map := _generate(seed_value)
		for node: MapNode in map.all_nodes():
			if node.floor_index < 9:
				assert_false(node.next.is_empty(), "次の階につながっている")
			if node.floor_index > 0:
				assert_false(map.previous_nodes(node).is_empty(), "前の階からつながっている")


func test_lines_do_not_cross() -> void:
	for seed_value: int in SEEDS:
		var map := _generate(seed_value)
		for floor_index in 9:
			var edges: Array = []
			for node: MapNode in map.get_floor(floor_index):
				for target: MapNode in node.next:
					edges.append([node.index, target.index])
			for a: Array in edges:
				for b: Array in edges:
					if a[0] < b[0]:
						assert_true(a[1] <= b[1], "線が交差しない（シード%d、%d階）" % [seed_value, floor_index + 1])


func test_contents_are_assigned() -> void:
	var map := _generate(5)
	for node: MapNode in map.all_nodes():
		if node.type == Type.BATTLE or node.type == Type.BOSS:
			assert_not_null(node.enemy, "戦闘のノードには敵がいる")
		if node.type == Type.EVENT:
			assert_not_null(node.event, "イベントのノードにはイベントがある")


func test_same_seed_gives_same_map() -> void:
	var a := _generate(123)
	var b := _generate(123)
	assert_eq(_describe(a), _describe(b), "同じシードなら同じマップ")


func test_all_node_types_appear() -> void:
	var seen := {}
	for seed_value in 30:
		for node: MapNode in _generate(seed_value).all_nodes():
			seen[node.type] = true
	for type: int in Type.values():
		assert_true(seen.has(type), "%s が出現する" % Type.keys()[type])


func test_elite_only_from_middle() -> void:
	var start := MapGenerator.elite_start_floor(10)
	for seed_value in 30:
		for node: MapNode in _generate(seed_value).all_nodes():
			if node.type == Type.ELITE:
				assert_true(node.floor_index >= start, "エリートは中盤以降だけ")
				assert_not_null(node.enemy, "エリートの敵がいる")


func test_small_dungeon() -> void:
	var map := _generate(1, 3)
	assert_eq(map.floor_count(), 3)
	assert_eq(map.get_floor(1)[0].type, Type.REST)
	assert_eq(map.get_floor(2)[0].type, Type.BOSS)


func _describe(map: MapData) -> Array:
	var result: Array = []
	for node: MapNode in map.all_nodes():
		var next_indices: Array = node.next.map(func(n: MapNode) -> int: return n.index)
		result.append([node.floor_index, node.index, node.type, next_indices, node.enemy.id if node.enemy else &""])
	return result
