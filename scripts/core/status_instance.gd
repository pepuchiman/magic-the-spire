class_name StatusInstance
extends RefCounted
## キャラクターに付いている状態効果1つ分

## 「バトル中」続く時の残りターン数
const BATTLE_LONG := -1

var type: GameEnums.StatusType
## 値（毒の強さ・麻痺の残りターン数・筋力や棘の強さ。弱体・脆弱では 1）
var value: int
## 「ターン数で続くタイプ」の残りターン数（BATTLE_LONG ならバトル中ずっと）。「値が減るタイプ」では使わない
var turns: int
## 付いてから、受けた側がまだ自分のターンを迎えていないか（true の間は、ターン終了時に減らない）
var fresh: bool


func _init(status_type: GameEnums.StatusType, status_value: int, status_turns: int, is_fresh: bool) -> void:
	type = status_type
	value = status_value
	turns = status_turns
	fresh = is_fresh
