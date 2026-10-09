class_name RunSerializer
extends RefCounted
## ラン（RunState）と、保存用のデータ（文字と数字だけの辞書）を相互に変換する。画面には依存しない。
## データ（カード・敵など）は ID で保存し、読み込む時に DataLoader から探す。
## 乱数の状態も保存するので、再開すると同じ敵・同じ報酬になる

## 保存の形式の番号。保存する内容を変えたら1つ増やす（古い中断データを見分けるため）
const VERSION := 1


## ランを保存用のデータにする。screen：どの画面で保存したか（Game.Screen の値）
static func to_dict(run: RunState, screen: int) -> Dictionary:
	var floors: Array = []
	for nodes: Array in run.map.floors:
		var floor_data: Array = []
		for node: MapNode in nodes:
			floor_data.append({
				"type": node.type,
				"enemy": String(node.enemy.id) if node.enemy != null else "",
				"event": String(node.event.id) if node.event != null else "",
				"visited": node.visited,
				"next": node.next.map(func(n: MapNode) -> int: return n.index),
			})
		floors.append(floor_data)
	var equipment := {}
	for type: int in run.equipment:
		equipment[str(type)] = String(run.equipment[type].id)
	var modifiers: Array = []
	for modifier: StatModifier in run.permanent_modifiers:
		modifiers.append({"param": modifier.param, "amount": modifier.amount,
			"duration": modifier.duration, "turns": modifier.remaining_turns})
	return {
		"version": VERSION,
		"screen": screen,
		"hero": String(run.hero.id),
		"dungeon": String(run.dungeon.id),
		"seed": str(run.run_seed),
		"rng_state": str(run.rng.state),  # 大きな数なので、文字として保存する（数字のままだと値がずれることがある）
		"hp": run.hp,
		"deck": _ids(run.deck),
		"card_pool": _ids(run.card_pool),
		"equipment": equipment,
		"permanent_modifiers": modifiers,
		"map": floors,
		"current": [run.current_node.floor_index, run.current_node.index] if run.current_node != null else [],
		"battles_won": run.battles_won,
		"enemies_defeated": run.enemies_defeated,
		"play_seconds": run.play_seconds,
	}


## 保存用のデータからランを作り直す。読み込めない時（形式が違う、IDが見つからない など）は null
static func from_dict(data: Dictionary, loader: DataLoader) -> RunState:
	if int(data.get("version", -1)) != VERSION:
		return null
	var hero := loader.get_hero(StringName(str(data.get("hero", ""))))
	var dungeon := loader.get_dungeon(StringName(str(data.get("dungeon", ""))))
	if hero == null or dungeon == null:
		return null
	var pool: Variant = _cards(data.get("card_pool", []), loader)
	var deck: Variant = _cards(data.get("deck", []), loader)
	if pool == null or deck == null:
		return null
	var run := RunState.new(hero, dungeon, pool, loader.get_config(), int(str(data.get("seed", "0"))), loader.index.equipment)
	run.rng.state = int(str(data.get("rng_state", "0")))
	run.deck = deck
	for type_text: String in data.get("equipment", {}):
		var item := loader.get_equipment(StringName(str(data["equipment"][type_text])))
		if item == null:
			return null
		run.equipment[int(type_text)] = item
	for entry: Dictionary in data.get("permanent_modifiers", []):
		run.permanent_modifiers.append(StatModifier.new(int(entry["param"]), int(entry["amount"]),
			int(entry["duration"]), int(entry["turns"])))
	var map := _map(data.get("map", []), loader)
	if map == null:
		return null
	run.map = map
	var current: Array = data.get("current", [])
	if current.size() == 2:
		var floor_index := int(current[0])
		var node_index := int(current[1])
		if floor_index >= map.floor_count() or node_index >= map.get_floor(floor_index).size():
			return null
		run.current_node = map.get_floor(floor_index)[node_index]
	run.hp = int(data.get("hp", hero.hp))
	run.battles_won = int(data.get("battles_won", 0))
	run.enemies_defeated = int(data.get("enemies_defeated", 0))
	run.play_seconds = float(data.get("play_seconds", 0.0))
	return run


static func _ids(cards: Array[CardData]) -> Array:
	return cards.map(func(card: CardData) -> String: return String(card.id))


## IDの一覧をカードの一覧にする（見つからないIDがあれば null）
static func _cards(ids: Array, loader: DataLoader) -> Variant:
	var result: Array[CardData] = []
	for id: Variant in ids:
		var card := loader.get_card(StringName(str(id)))
		if card == null:
			return null
		result.append(card)
	return result


## 保存用のデータからマップを作り直す（壊れていれば null）
static func _map(floors_data: Array, loader: DataLoader) -> MapData:
	if floors_data.is_empty():
		return null
	var map := MapData.new()
	for floor_index in floors_data.size():
		var nodes: Array[MapNode] = []
		var floor_data: Array = floors_data[floor_index]
		for node_index in floor_data.size():
			var entry: Dictionary = floor_data[node_index]
			var node := MapNode.new(int(entry["type"]), floor_index, node_index)
			node.visited = bool(entry.get("visited", false))
			if str(entry.get("enemy", "")) != "":
				node.enemy = loader.get_enemy(StringName(str(entry["enemy"])))
				if node.enemy == null:
					return null
			if str(entry.get("event", "")) != "":
				node.event = loader.get_event(StringName(str(entry["event"])))
				if node.event == null:
					return null
			nodes.append(node)
		map.floors.append(nodes)
	# つながりは、次の階のノードの位置で保存している
	for floor_index in floors_data.size() - 1:
		for node_index in floors_data[floor_index].size():
			for next_index: Variant in floors_data[floor_index][node_index].get("next", []):
				var upper: Array = map.get_floor(floor_index + 1)
				if int(next_index) >= upper.size():
					return null
				map.get_floor(floor_index)[node_index].next.append(upper[int(next_index)])
	return map
