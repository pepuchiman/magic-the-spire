class_name EquipmentData
extends Resource
## 装備（指輪・武器・鎧）のデータ。
## 装備している間だけ、modifiers のパラメーターが変わる（外すと元に戻る）。
## 効果の文章は modifiers から自動で作る。説明文（description_key）は、雰囲気の文章を足したい時だけ使う（空でもよい）

## マナ基準値・触媒力・ドロー数を上げる効果は強いので、レア以上の装備にしか持たせない（検証で確認する）
const STRONG_PARAMS: Array[GameEnums.Param] = [
	GameEnums.Param.MANA_BASE,
	GameEnums.Param.CATALYST_POWER_RED,
	GameEnums.Param.CATALYST_POWER_BLUE,
	GameEnums.Param.CATALYST_POWER_GREEN,
	GameEnums.Param.DRAW_COUNT,
]

@export var id: StringName
@export var name_key: StringName
@export var equipment_type: GameEnums.EquipmentType = GameEnums.EquipmentType.RING
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
## 装備すると変わるパラメーター（効果ターン数は使わない。装備している間ずっと有効）
@export var modifiers: Array[ModifyParamEffect] = []
## 雰囲気の説明文のキー（空でもよい）
@export var description_key: StringName


## このパラメーターが装備でいくつ変わるか（同じパラメーターの効果が複数あれば合計）
func get_amount(param: GameEnums.Param) -> int:
	var total := 0
	for modifier: ModifyParamEffect in modifiers:
		if modifier != null and modifier.param == param:
			total += modifier.amount
	return total
