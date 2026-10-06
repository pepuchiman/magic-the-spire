class_name EventData
extends Resource
## イベントのデータ（フェーズ4でサンプルを用意する）

@export var id: StringName
@export var name_key: StringName
@export var description_key: StringName
@export var choices: Array[EventChoiceData] = []
