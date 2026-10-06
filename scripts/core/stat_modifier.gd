class_name StatModifier
extends RefCounted
## パラメーターの補正1件（例：マナ基準値+1を2ターン）。
## 補正が付いている間は、パラメーターの値に増減量が足される。

var param: GameEnums.Param
var amount: int
var duration: GameEnums.Duration
## 効果ターン数が「〇〇ターン」の時の残りターン数
var remaining_turns: int


func _init(target_param: GameEnums.Param, change: int, duration_type: GameEnums.Duration, turns: int = 0) -> void:
	param = target_param
	amount = change
	duration = duration_type
	remaining_turns = turns


## 効果を受けた側のターン終了時に呼ぶ。残りターンを1減らし、終わったら true を返す
func tick() -> bool:
	if duration != GameEnums.Duration.TURNS:
		return false
	remaining_turns -= 1
	return remaining_turns <= 0
