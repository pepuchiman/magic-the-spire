class_name BattleResult
extends RefCounted
## バトルの結果。ランに引き継ぐのは、主人公のHPと「永続」の補正だけ

var won: bool
var hero_hp: int
var permanent_modifiers: Array[StatModifier] = []
var turns: int


func _init(is_won: bool, final_hp: int, carried: Array[StatModifier], turn_count: int) -> void:
	won = is_won
	hero_hp = maxi(0, final_hp)
	permanent_modifiers = carried
	turns = turn_count
