class_name HeroData
extends Resource
## 主人公（魔法使い）のデータ

@export var id: StringName
@export var name_key: StringName

@export_group("基本パラメーター")
## 初期HP（挑戦開始時のHP）
@export_range(0, 9999) var hp: int = 20
@export_range(1, 9999) var max_hp: int = 20
@export_range(0, 99) var mana_base: int = 5
@export_range(0, 9999) var target_rate: int = 100
@export_range(0, 9999) var defense: int = 0
@export_range(1, 99) var max_hand: int = 5
@export_range(1, 99) var draw_count: int = 3

@export_group("魔法触媒（バトル開始時の値）")
@export_range(0, 99) var catalyst_red: int = 0
@export_range(0, 99) var catalyst_blue: int = 0
@export_range(0, 99) var catalyst_green: int = 0

@export_group("触媒力（毎ターンの増加数）")
@export_range(0, 99) var catalyst_power_red: int = 0
@export_range(0, 99) var catalyst_power_blue: int = 0
@export_range(0, 99) var catalyst_power_green: int = 0

@export_group("初期デッキ")
## 初期デッキのカード（同じカードを複数枚入れる場合は、同じカードを並べる）
@export var starting_deck: Array[CardData] = []
