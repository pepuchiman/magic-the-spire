class_name EnemyCombatant
extends Combatant
## バトル中の敵（敵本体・敵の仲間）

var data: EnemyData
## 敵本体なら true（倒すとバトル終了）
var is_main: bool
## 次に行う行動（行動予告として画面に出す）
var intent: EnemyActionData
## 通常のループ行動の、次の位置
var _loop_index: int = 0


func _init(enemy_data: EnemyData, main: bool) -> void:
	data = enemy_data
	is_main = main
	id = data.id
	name_key = data.name_key
	base_max_hp = data.max_hp
	hp = data.max_hp
	base_defense = data.defense
	armor = data.armor
	base_target_rate = data.target_rate


## 攻撃のダメージ値（攻撃力最少値〜最大値でランダム）
func roll_attack(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(data.attack_min, data.attack_max)


## 次の行動を決める。
## 条件付きの行動で、条件を満たすものがあれば優先する（ループの位置は進めない）。
## なければ、条件なしの行動を順番にループする。
func decide_next_action() -> void:
	intent = null
	var loop_actions: Array[EnemyActionData] = []
	for action: EnemyActionData in data.pattern:
		if action == null:
			continue
		if action.condition == GameEnums.EnemyActionCondition.ALWAYS:
			loop_actions.append(action)
		elif _is_condition_met(action):
			intent = action
			return
	if loop_actions.is_empty():
		return
	intent = loop_actions[_loop_index % loop_actions.size()]
	_loop_index += 1


func _is_condition_met(action: EnemyActionData) -> bool:
	match action.condition:
		GameEnums.EnemyActionCondition.HP_PERCENT_BELOW:
			return hp * 100 <= get_max_hp() * action.condition_value
	return false
