class_name AllyData
extends Resource
## 自分側のクリーチャー（召喚される味方）のデータ。
## ※仕様書の「クリーチャー」のこと。プログラム内では以前の呼び名に合わせて ally（仲間）と呼んでいる

@export var id: StringName
@export var name_key: StringName
## 召喚時のHP（最大HPと同じ）
@export_range(1, 9999) var max_hp: int = 10
@export_range(0, 9999) var defense: int = 0
@export_range(0, 9999) var armor: int = 0
@export_range(0, 9999) var attack_min: int = 0
@export_range(0, 9999) var attack_max: int = 0
@export var race: GameEnums.Race = GameEnums.Race.BEAST
@export var attack_effect: GameEnums.AttackEffect = GameEnums.AttackEffect.BLOW
