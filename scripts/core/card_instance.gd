class_name CardInstance
extends RefCounted
## バトル中のカード1枚（実体）。
## 同じカード（CardData）が2枚あれば、CardInstance も2つ作られ、それぞれが残りの使用回数を持つ。
## バトルごとに作り直すので、次のバトルでは使用回数が元に戻る。

var data: CardData
## 残りの使用回数（使用回数の制限がないカードでは使わない）
var uses_left: int


func _init(card_data: CardData) -> void:
	data = card_data
	uses_left = data.uses_per_battle


## 使用回数の制限があるカードか
func has_use_limit() -> bool:
	return data.uses_per_battle > 0


## 1回使ったことにする。使い切ったら true を返す
func use() -> bool:
	if not has_use_limit():
		return false
	uses_left = maxi(0, uses_left - 1)
	return uses_left == 0
