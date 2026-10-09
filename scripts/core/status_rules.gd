class_name StatusRules
extends RefCounted
## 状態効果の種類ごとの決まり（docs/Game_Elements.md「状態効果」）。
## 状態効果を追加する時は、ここと Game_Elements.md と翻訳ファイルを更新する

const Status := GameEnums.StatusType


## 「値が減るタイプ」か（毎ターン値が1ずつ減り、0で消える）。そうでなければ「ターン数で続くタイプ」
static func is_value_type(type: GameEnums.StatusType) -> bool:
	return type == Status.POISON or type == Status.PARALYSIS


## 悪い状態効果（デバフ）か
static func is_debuff(type: GameEnums.StatusType) -> bool:
	return type == Status.POISON or type == Status.PARALYSIS or type == Status.WEAK or type == Status.VULNERABLE


## 値に意味がある状態効果か（弱体・脆弱は「付いているかどうか」だけで、値は使わない）
static func uses_value(type: GameEnums.StatusType) -> bool:
	return type != Status.WEAK and type != Status.VULNERABLE


## 説明文の差し込みの名前（例：{poison}）
static func text_param(type: GameEnums.StatusType) -> String:
	return GameEnums.StatusType.keys()[type].to_lower()
