class_name StatusEffect
extends EffectData
## 状態効果を与える効果（毒・麻痺・弱体・脆弱・筋力・棘）。動きは docs/Game_Elements.md を参照。
## ・毒・麻痺（値が減るタイプ）：amount が値（毒の強さ、麻痺のターン数）。カードの効果ターン数は使わない
## ・弱体・脆弱：amount は使わない。カードの効果ターン数（〇〇ターン／バトル中）の間続く
## ・筋力・棘：amount が値。カードの効果ターン数（〇〇ターン／バトル中）の間続く

@export var status: GameEnums.StatusType = GameEnums.StatusType.POISON
@export_range(0, 99) var amount: int = 1


## 説明文の {poison} などに値を入れる
func get_text_params() -> Dictionary:
	return {StatusRules.text_param(status): amount}
