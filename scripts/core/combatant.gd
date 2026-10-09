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
## 付いている状態効果（種類 → StatusInstance）。動きは docs/Game_Elements.md を参照
var statuses: Dictionary = {}


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


## 状態効果の値（付いていなければ 0）
func get_status_value(type: GameEnums.StatusType) -> int:
	var status: StatusInstance = statuses.get(type)
	return status.value if status != null else 0


func has_status(type: GameEnums.StatusType) -> bool:
	return statuses.has(type)


## 状態効果を付ける。すでに付いていれば重ねがけ（値とターン数を足す。「バトル中」なら値だけ足す）
## turns：ターン数で続くタイプの残りターン数（StatusInstance.BATTLE_LONG ならバトル中）
## fresh：受けた側がまだ自分のターンを迎えていないか（true なら、直後のターン終了時には減らない）
func add_status(type: GameEnums.StatusType, value: int, turns: int, fresh: bool) -> void:
	if not StatusRules.uses_value(type):
		value = 1  # 弱体・脆弱は値を使わない
	var status: StatusInstance = statuses.get(type)
	if status == null:
		statuses[type] = StatusInstance.new(type, value, turns, fresh)
		return
	if StatusRules.uses_value(type):
		status.value += value
	if not StatusRules.is_value_type(type):
		if status.turns == StatusInstance.BATTLE_LONG or turns == StatusInstance.BATTLE_LONG:
			status.turns = StatusInstance.BATTLE_LONG
		else:
			status.turns += turns
	# 前からあった分は今までどおり数える（足した分だけ長く残る）
	status.fresh = status.fresh and fresh


## 状態効果の値を減らす。0以下になったら消す
func reduce_status(type: GameEnums.StatusType, amount: int) -> void:
	var status: StatusInstance = statuses.get(type)
	if status == null:
		return
	status.value -= amount
	if status.value <= 0:
		statuses.erase(type)


## 自分のターンが始まった時に呼ぶ（付いた直後の印を外す）
func mark_statuses_active() -> void:
	for status: StatusInstance in statuses.values():
		status.fresh = false


## 自分のターンが終わった時に呼ぶ。値が減るタイプ（毒を除く）は値を1、ターン数で続くタイプは残りターンを1減らす。
## 付いた直後のもの（fresh）と、毒（ターン開始時に減る）は減らさない。変化があれば true
func tick_statuses_turn_end() -> bool:
	var changed := false
	for status: StatusInstance in statuses.values().duplicate():
		if status.fresh or status.type == GameEnums.StatusType.POISON:
			continue
		if StatusRules.is_value_type(status.type):
			reduce_status(status.type, 1)
			changed = true
		elif status.turns != StatusInstance.BATTLE_LONG:
			status.turns -= 1
			changed = true
			if status.turns <= 0:
				statuses.erase(status.type)
	return changed


## 回復（最大HPまで）。実際に回復した量を返す
func heal(amount: int) -> int:
	var before := hp
	hp = mini(hp + amount, get_max_hp())
	return hp - before


## 最大HPが下がった時に、HPが最大HPを超えないようにする
func _clamp_hp() -> void:
	hp = mini(hp, get_max_hp())
