class_name IconSet
extends Resource
## 種類ごとのアイコンの一覧（data/config/icon_set.tres）。
## 画像を入れた種類はその画像を、空（未設定）の種類は図形の記号を表示する。
## tools/link_art.gd で assets/icons/ の画像（status_poison.png など）を結び付けられる。
## 種類を増やした時は、検証で「一覧にない種類」がエラーになるので、ここに追加する

## 状態効果のアイコン（assets/icons/status_<種類>.png）
@export var status_icons: Dictionary[GameEnums.StatusType, Texture2D] = {}
## マップのマスのアイコン（assets/icons/map_<種類>.png）
@export var map_node_icons: Dictionary[GameEnums.MapNodeType, Texture2D] = {}
## 装備の種類のアイコン（装備に個別のアイコンがない時に使う。assets/icons/equip_type_<種類>.png）
@export var equipment_type_icons: Dictionary[GameEnums.EquipmentType, Texture2D] = {}


## すべての種類を、空（図形で表示）で登録した一覧を作る
static func create_default() -> IconSet:
	var icon_set := IconSet.new()
	for type: int in GameEnums.StatusType.values():
		icon_set.status_icons[type] = null
	for type: int in GameEnums.MapNodeType.values():
		icon_set.map_node_icons[type] = null
	for type: int in GameEnums.EquipmentType.values():
		icon_set.equipment_type_icons[type] = null
	return icon_set
