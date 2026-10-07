class_name Combatant
extends RefCounted
## バトルに参加するキャラクターの共通部分（主人公・仲間・敵）。
## 「基本値」に補正（StatModifier）を足したものが、実際に使われる値になる。

var id: StringName
var name_key: StringName
var hp: int = 1
var armor: int = 0
var base_max_hp: int = 1
var base_defense: int = 0
var modifiers: Array[StatModifier] = []


func is_alive() -> bool:
	return hp > 0


func get_max_hp() -> int:
	return maxi(1, base_max_hp + get_modifier_total(GameEnums.Param.MAX_HP))


func get_defense() -> int:
	return maxi(0, base_defense + get_modifier_total(GameEnums.Param.DEFENSE))


## 指定したパラメーターに掛かっている補正の合計
func get_modifier_total(param: GameEnums.Param) -> int:
	var total := 0
	for modifier: StatModifier in modifiers:
		if modifier.param == param:
			total += modifier.amount
	return total


func add_modifier(modifier: StatModifier) -> void:
	modifiers.append(modifier)
	_clamp_hp()


## ターン終了時の処理。補正の残りターンを減らし、終わった補正の一覧を返す
func tick_modifiers() -> Array[StatModifier]:
	var expired: Array[StatModifier] = []
	for modifier: StatModifier in modifiers.duplicate():
		if modifier.tick():
			modifiers.erase(modifier)
			expired.append(modifier)
	_clamp_hp()
	return expired


## 回復（最大HPまで）。実際に回復した量を返す
func heal(amount: int) -> int:
	var before := hp
	hp = mini(hp + amount, get_max_hp())
	return hp - before


## 最大HPが下がった時に、HPが最大HPを超えないようにする
func _clamp_hp() -> void:
	hp = mini(hp, get_max_hp())
