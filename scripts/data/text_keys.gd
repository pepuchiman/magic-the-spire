class_name TextKeys
extends RefCounted
## 列挙型（種別・レアリティ・パラメーター）の値から、翻訳キーを作る。
## 例：CardType.ATTACK → "CARD_TYPE_ATTACK"
## 列挙型に値を追加したら、翻訳ファイル（localization/ui.csv）にもキーを追加すること（検証で確認される）


static func card_type(value: GameEnums.CardType) -> String:
	return "CARD_TYPE_" + GameEnums.CardType.keys()[value]


static func rarity(value: GameEnums.Rarity) -> String:
	return "RARITY_" + GameEnums.Rarity.keys()[value]


static func param(value: GameEnums.Param) -> String:
	return "PARAM_" + GameEnums.Param.keys()[value]


## マップのノードの種類の名前（例：MAP_NODE_REST）
static func map_node(value: GameEnums.MapNodeType) -> String:
	return "MAP_NODE_" + GameEnums.MapNodeType.keys()[value]


## マップのノードの種類の説明（例：MAP_NODE_REST_DESC）
static func map_node_desc(value: GameEnums.MapNodeType) -> String:
	return map_node(value) + "_DESC"


## 装備の種類の名前（例：EQUIPMENT_TYPE_RING）
static func equipment_type(value: GameEnums.EquipmentType) -> String:
	return "EQUIPMENT_TYPE_" + GameEnums.EquipmentType.keys()[value]


## 上の関数で作られる、すべてのキー（翻訳ファイルの登録漏れの確認に使う）
static func all_enum_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for value: int in GameEnums.EquipmentType.values():
		keys.append(equipment_type(value))
	for value: int in GameEnums.MapNodeType.values():
		keys.append(map_node(value))
		keys.append(map_node_desc(value))
	for value: int in GameEnums.CardType.values():
		keys.append(card_type(value))
	for value: int in GameEnums.Rarity.values():
		keys.append(rarity(value))
	for value: int in GameEnums.Param.values():
		keys.append(param(value))
	return keys
