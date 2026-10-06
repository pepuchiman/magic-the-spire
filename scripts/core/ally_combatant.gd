class_name AllyCombatant
extends Combatant
## バトル中の仲間（召喚された味方）

var data: AllyData
## 召喚されたターン
var summoned_turn: int


func _init(ally_data: AllyData, turn: int) -> void:
	data = ally_data
	id = data.id
	name_key = data.name_key
	base_max_hp = data.max_hp
	hp = data.max_hp
	base_defense = data.defense
	armor = data.armor
	base_target_rate = data.target_rate
	summoned_turn = turn


## 攻撃のダメージ値（攻撃力最少値〜最大値でランダム）
func roll_attack(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(data.attack_min, data.attack_max)
