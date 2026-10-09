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


## 攻撃のダメージ値（攻撃力最少値〜最大値でランダム）
func roll_attack(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(data.attack_min, data.attack_max)


## 次の行動を決める。実行できない行動（例：敵の仲間が上限の時の「味方を呼ぶ」）は無視する。
## ・条件付きの行動で、条件を満たし、実行できるものがあれば優先する（ループの位置は進めない）
## ・なければ、条件なしの行動を順番にループする。順番が来た行動が実行できなければ、その次の行動にする
## ・実行できる行動が1つもなければ、intent は null（何もしない）
## can_summon：敵の仲間を呼べる状態か（敵の仲間が上限未満か）
func decide_next_action(can_summon: bool) -> void:
	intent = null
	var loop_actions: Array[EnemyActionData] = []
	for action: EnemyActionData in data.pattern:
		if action == null:
			continue
		if action.condition == GameEnums.EnemyActionCondition.ALWAYS:
			loop_actions.append(action)
		elif _is_condition_met(action) and is_executable(action, can_summon):
			intent = action
			return
	for offset in loop_actions.size():
		var index := (_loop_index + offset) % loop_actions.size()
		if is_executable(loop_actions[index], can_summon):
			intent = loop_actions[index]
			_loop_index = index + 1
			return


## その行動を、いま実行できるか（攻撃・防御・状態効果を与える はいつでもできる）
static func is_executable(action: EnemyActionData, can_summon: bool) -> bool:
	if action.action_type == GameEnums.EnemyActionType.SUMMON:
		return can_summon and action.summon_enemy != null
	return true


func _is_condition_met(action: EnemyActionData) -> bool:
	match action.condition:
		GameEnums.EnemyActionCondition.HP_PERCENT_BELOW:
			return hp * 100 <= get_max_hp() * action.condition_value
	return false
