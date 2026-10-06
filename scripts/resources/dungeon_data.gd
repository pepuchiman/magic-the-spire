class_name DungeonData
extends Resource
## ダンジョンのデータ

@export var id: StringName
@export var name_key: StringName
## 全N戦のN（マップ上の戦闘ノードの数）
@export_range(1, 99) var battle_count: int = 8
## 通常戦で出現する敵
@export var normal_enemies: Array[EnemyData] = []
## 最奥のボス
@export var boss: EnemyData
## このダンジョンで起きるイベント
@export var events: Array[EventData] = []
