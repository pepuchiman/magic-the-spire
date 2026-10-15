class_name UiIcons
extends RefCounted
## 画面で使うアイコンの一覧（data/config/icon_set.tres）を取り出す係。
## 画像が設定されていない種類は null になる（その時は図形の記号で表示する）

static var _icon_set: IconSet


## アイコンの一覧（全体の管理役 Game が読み込んだデータから取り出す。
## Game がいない時（ツールから画面の部品だけを動かす時など）は、索引を直接読み込む）
static func get_set() -> IconSet:
	if _icon_set == null:
		var tree := Engine.get_main_loop() as SceneTree
		var game: Node = tree.root.get_node_or_null("Game") if tree != null else null
		var loader: DataLoader = game.get("data") if game != null else null
		if loader == null:
			loader = DataLoader.new()
		_icon_set = loader.get_icons()
	return _icon_set


static func status(type: GameEnums.StatusType) -> Texture2D:
	return get_set().status_icons.get(type)


static func map_node(type: GameEnums.MapNodeType) -> Texture2D:
	return get_set().map_node_icons.get(type)


## 装備のアイコン（装備に個別のアイコンがなければ、種類のアイコン）
static func equipment(item: EquipmentData) -> Texture2D:
	if item.icon != null:
		return item.icon
	return equipment_type(item.equipment_type)


static func equipment_type(type: GameEnums.EquipmentType) -> Texture2D:
	return get_set().equipment_type_icons.get(type)
