class_name DungeonData
extends Resource
## ダンジョンのデータ

@export var id: StringName
@export var name_key: StringName
## このダンジョン（ID）をクリアすると選べるようになる。空なら最初から選べる
@export var unlocked_by_clearing: StringName
## 階数（最上階はボス）。1回の挑戦では、各階のノードを1つずつ通る
@export_range(3, 30) var floor_count: int = 10
## 通常戦で出現する敵
@export var normal_enemies: Array[EnemyData] = []
## エリート戦（強敵）で出現する敵
@export var elite_enemies: Array[EnemyData] = []
## 最奥のボス
@export var boss: EnemyData
## このダンジョンで起きるイベント
@export var events: Array[EventData] = []

@export_group("ノードの出やすさ（重み）")
## 数字が大きいほど出やすい（1階は通常戦のみ、ボス直前は休憩のみ、エリートは中盤以降のみ、などの決まりは別にある）
@export_range(0, 100) var battle_weight: int = 55
@export_range(0, 100) var event_weight: int = 25
@export_range(0, 100) var rest_weight: int = 20
@export_range(0, 100) var elite_weight: int = 12
@export_range(0, 100) var treasure_weight: int = 8
