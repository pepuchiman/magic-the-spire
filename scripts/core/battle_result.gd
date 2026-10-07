class_name BattleResult
extends RefCounted
## バトルの結果。ランに引き継ぐのは、主人公のHPと「永続」の補正だけ

var won: bool
var hero_hp: int
var permanent_modifiers: Array[StatModifier] = []
var turns: int
## 倒した敵の数（敵本体・敵のクリーチャー）
var enemies_defeated: int


func _init(is_won: bool, final_hp: int, carried: Array[StatModifier], turn_count: int, defeated: int = 0) -> void:
	won = is_won
	hero_hp = maxi(0, final_hp)
	permanent_modifiers = carried
	turns = turn_count
	enemies_defeated = defeated
