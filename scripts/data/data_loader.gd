class_name DataLoader
extends RefCounted
## 索引（data_index.tres）から全データを読み込み、IDで引けるようにする

const INDEX_PATH := "res://data/data_index.tres"

var index: DataIndex

var _cards: Dictionary = {}
var _heroes: Dictionary = {}
var _allies: Dictionary = {}
var _enemies: Dictionary = {}
var _equipment: Dictionary = {}
var _events: Dictionary = {}
var _dungeons: Dictionary = {}


## 索引を指定しなければ、プロジェクトの索引を読み込む
func _init(source_index: DataIndex = null) -> void:
	index = source_index if source_index != null else load(INDEX_PATH) as DataIndex
	if index == null:
		push_error("索引が読み込めません：%s" % INDEX_PATH)
		return
	_fill(_cards, index.cards)
	_fill(_heroes, index.heroes)
	_fill(_allies, index.allies)
	_fill(_enemies, index.enemies)
	_fill(_equipment, index.equipment)
	_fill(_events, index.events)
	_fill(_dungeons, index.dungeons)


func get_card(id: StringName) -> CardData:
	return _cards.get(id)


func get_hero(id: StringName) -> HeroData:
	return _heroes.get(id)


func get_ally(id: StringName) -> AllyData:
	return _allies.get(id)


func get_enemy(id: StringName) -> EnemyData:
	return _enemies.get(id)


func get_equipment(id: StringName) -> EquipmentData:
	return _equipment.get(id)


func get_event(id: StringName) -> EventData:
	return _events.get(id)


func get_dungeon(id: StringName) -> DungeonData:
	return _dungeons.get(id)


func _fill(target: Dictionary, items: Array) -> void:
	for item: Resource in items:
		if item != null:
			target[item.get("id")] = item
