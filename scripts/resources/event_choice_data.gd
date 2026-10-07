class_name EventChoiceData
extends Resource
## イベントの選択肢1つ分

## 選択肢ボタンの文章のキー（{hp} にHPの増減量が入る）
@export var text_key: StringName
## 選んだ後に表示する結果の文章のキー（{hp} にHPの増減量が入る）
@export var result_key: StringName
## HPの増減（失う場合はマイナス）。イベントでHPが0になることはない（最低1残る）
@export_range(-9999, 9999) var hp_change: int = 0
## 選んだ時に起きる結果（カード獲得・カード交換など）
@export var outcomes: Array[EventOutcome] = []


## 文章に差し込む値
func get_text_params() -> Dictionary:
	return {"hp": absi(hp_change)}
