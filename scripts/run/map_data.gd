class_name MapData
extends RefCounted
## ダンジョンのマップ。floors[階][左からの位置] にノードが入っている（floors[0] が1階、最後がボスの階）

var floors: Array[Array] = []


func floor_count() -> int:
	return floors.size()


func get_floor(floor_index: int) -> Array:
	return floors[floor_index]


## すべてのノード（1階から順に）
func all_nodes() -> Array[MapNode]:
	var result: Array[MapNode] = []
	for nodes: Array in floors:
		for node: MapNode in nodes:
			result.append(node)
	return result


## 手前の階から、そのノードにつながっているノード
func previous_nodes(node: MapNode) -> Array[MapNode]:
	var result: Array[MapNode] = []
	if node.floor_index == 0:
		return result
	for candidate: MapNode in floors[node.floor_index - 1]:
		if candidate.next.has(node):
			result.append(candidate)
	return result
