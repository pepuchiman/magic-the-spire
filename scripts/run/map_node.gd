class_name MapNode
extends RefCounted
## マップのノード（マス）1つ分

var type: GameEnums.MapNodeType
## 何階か（0 が1階）
var floor_index: int
## その階の左から何番目か（0 から）
var index: int
## 次の階でつながっているノード
var next: Array[MapNode] = []
## 戦闘・ボスのノードで出てくる敵
var enemy: EnemyData
## イベントのノードで起きるイベント
var event: EventData
## 通過したか
var visited: bool = false


func _init(node_type: GameEnums.MapNodeType, floor_number: int, position: int) -> void:
	type = node_type
	floor_index = floor_number
	index = position


func is_battle() -> bool:
	return type == GameEnums.MapNodeType.BATTLE or type == GameEnums.MapNodeType.ELITE \
		or type == GameEnums.MapNodeType.BOSS
