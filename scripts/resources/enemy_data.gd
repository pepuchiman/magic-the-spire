class_name EnemyData
extends Resource
## 敵（通常の敵・ボス・敵の仲間）のデータ

@export var id: StringName
@export var name_key: StringName
@export_range(0, 9999) var max_hp: int = 10
@export_range(0, 9999) var defense: int = 0
@export_range(0, 9999) var armor: int = 0
@export_range(0, 9999) var attack_min: int = 0
@export_range(0, 9999) var attack_max: int = 0
@export_range(0, 9999) var target_rate: int = 100
@export var race: GameEnums.Race = GameEnums.Race.MONSTER
@export var attack_effect: GameEnums.AttackEffect = GameEnums.AttackEffect.BLOW
## 行動パターン
@export var pattern: Array[EnemyActionData] = []
