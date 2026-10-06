class_name EventChoiceData
extends Resource
## イベントの選択肢1つ分

## 選択肢ボタンの文章のキー
@export var text_key: StringName
## 選んだ後に表示する結果の文章のキー
@export var result_key: StringName
## HPの増減（失う場合はマイナス）
@export_range(-9999, 9999) var hp_change: int = 0
## 選んだ時に起きる効果（カード獲得などは、フェーズ4で増やす）
@export var effects: Array[EffectData] = []
