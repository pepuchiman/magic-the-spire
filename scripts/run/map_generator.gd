class_name MapGenerator
extends RefCounted
## マップのランダム生成（Game_Rule.md「進路選択」）
## ・各階に2〜3ノード。最上階はボス1つ
## ・1階は通常戦のみ／ボスの直前の階は休憩のみ／中盤に休憩を最低1つ／エリートは中盤以降のみ
## ・隣の階との線は交差させない
## ・どのノードも、前の階・次の階のどれかとつながる（行き止まりなし）

const MIN_NODES := 2
const MAX_NODES := 3


static func generate(dungeon: DungeonData, rng: RandomNumberGenerator) -> MapData:
	var map := MapData.new()
	var floor_count := dungeon.floor_count
	for floor_index in floor_count:
		var nodes: Array[MapNode] = []
		var count := 1 if floor_index == floor_count - 1 else rng.randi_range(MIN_NODES, MAX_NODES)
		for i in count:
			nodes.append(MapNode.new(_node_type(dungeon, floor_index, floor_count, rng), floor_index, i))
		map.floors.append(nodes)
	_ensure_middle_rest(map, rng)
	for floor_index in floor_count - 1:
		_connect(map.floors[floor_index], map.floors[floor_index + 1], rng)
	_assign_contents(map, dungeon, rng)
	return map


## 中盤（全体の 3〜7 割あたりの階）にあたる階の番号の一覧
static func middle_floors(floor_count: int) -> Array[int]:
	var result: Array[int] = []
	var first := maxi(1, int(floor_count * 0.3))
	var last := mini(floor_count - 3, int(floor_count * 0.7))
	for floor_index in range(first, last + 1):
		result.append(floor_index)
	return result


static func _node_type(dungeon: DungeonData, floor_index: int, floor_count: int, rng: RandomNumberGenerator) -> GameEnums.MapNodeType:
	if floor_index == floor_count - 1:
		return GameEnums.MapNodeType.BOSS
	if floor_index == floor_count - 2:
		return GameEnums.MapNodeType.REST  # ボスの直前は必ず休憩
	if floor_index == 0:
		return GameEnums.MapNodeType.BATTLE  # 1階は通常戦のみ
	var event_weight := dungeon.event_weight if not dungeon.events.is_empty() else 0
	# エリートは中盤以降だけ（エリートの敵が登録されている時だけ）
	var elite_weight := dungeon.elite_weight if floor_index >= elite_start_floor(floor_count) and not dungeon.elite_enemies.is_empty() else 0
	var types: Array = [GameEnums.MapNodeType.BATTLE, GameEnums.MapNodeType.EVENT, GameEnums.MapNodeType.REST,
		GameEnums.MapNodeType.ELITE, GameEnums.MapNodeType.TREASURE]
	var weights: Array[int] = [dungeon.battle_weight, event_weight, dungeon.rest_weight, elite_weight, dungeon.treasure_weight]
	return RunRandom.pick_weighted(types, weights, rng)


## エリートが出始める階（中盤の最初の階）
static func elite_start_floor(floor_count: int) -> int:
	return maxi(1, int(floor_count * 0.3))


## 中盤に休憩が1つもなければ、中盤のノードを1つ休憩にする
static func _ensure_middle_rest(map: MapData, rng: RandomNumberGenerator) -> void:
	var candidates: Array[MapNode] = []
	for floor_index: int in middle_floors(map.floor_count()):
		for node: MapNode in map.floors[floor_index]:
			if node.type == GameEnums.MapNodeType.REST:
				return
			candidates.append(node)
	var chosen: MapNode = RunRandom.pick(candidates, rng)
	if chosen != null:
		chosen.type = GameEnums.MapNodeType.REST


## 隣り合う階をつなぐ。左端どうしから始めて、右へ1歩ずつ進みながら線を引くので、線は交差しない。
## 下の階・上の階のどのノードにも、少なくとも1本の線がつながる
static func _connect(lower: Array, upper: Array, rng: RandomNumberGenerator) -> void:
	var i := 0
	var j := 0
	_link(lower[i], upper[j])
	while i < lower.size() - 1 or j < upper.size() - 1:
		if i == lower.size() - 1:
			j += 1
		elif j == upper.size() - 1:
			i += 1
		else:
			match rng.randi_range(0, 2):
				0:
					i += 1
				1:
					j += 1
				_:
					i += 1
					j += 1
		_link(lower[i], upper[j])


static func _link(from: MapNode, to: MapNode) -> void:
	if not from.next.has(to):
		from.next.append(to)


## 戦闘の敵・イベントの中身を決める（イベントは、なるべく同じものが重ならないようにする）
static func _assign_contents(map: MapData, dungeon: DungeonData, rng: RandomNumberGenerator) -> void:
	var unused_events: Array = []
	for node: MapNode in map.all_nodes():
		match node.type:
			GameEnums.MapNodeType.BATTLE:
				node.enemy = RunRandom.pick(dungeon.normal_enemies, rng)
			GameEnums.MapNodeType.ELITE:
				node.enemy = RunRandom.pick(dungeon.elite_enemies, rng)
			GameEnums.MapNodeType.BOSS:
				node.enemy = dungeon.boss
			GameEnums.MapNodeType.EVENT:
				if unused_events.is_empty():
					unused_events = RunRandom.shuffled(dungeon.events, rng)
				node.event = unused_events.pop_back()
