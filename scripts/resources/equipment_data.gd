class_name EquipmentData
extends Resource
## 装備（指輪・武器・鎧）のデータ

@export var id: StringName
@export var name_key: StringName
@export var equipment_type: GameEnums.EquipmentType = GameEnums.EquipmentType.RING
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
## 装備すると変わるパラメーター
@export var modifiers: Array[ModifyParamEffect] = []
@export var description_key: StringName
