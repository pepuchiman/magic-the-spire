class_name CardData
extends Resource
## カード（魔法）のデータ

@export var id: StringName
## カード名のキー（例：CARD_FIREBALL_NAME）
@export var name_key: StringName
@export var card_type: GameEnums.CardType = GameEnums.CardType.ATTACK
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
## 利用できる主人公のID
@export var usable_heroes: Array[StringName] = []
@export var targets: Array[GameEnums.Target] = []
## ターゲットが「味方」の時に、対象にできる種族（空なら種族を限定しない）
@export var target_races: Array[GameEnums.Race] = []
@export_range(0, 99) var cost_mana: int = 0

@export_group("必要触媒")
@export_range(0, 99) var required_red: int = 0
@export_range(0, 99) var required_blue: int = 0
@export_range(0, 99) var required_green: int = 0

@export_group("効果")
@export var duration: GameEnums.Duration = GameEnums.Duration.INSTANT
## 効果ターン数が「〇〇ターン」の時のターン数
@export_range(0, 99) var duration_turns: int = 0
## 効果の部品
@export var effects: Array[EffectData] = []
## 効果詳細の文章のキー（例：CARD_FIREBALL_DESC）
@export var description_key: StringName
## 効果エフェクト（フェーズ7で使う）
@export var visual_effect: StringName


## 説明文に差し込む値（効果の部品の値）を集める。効果の数値を変えると説明文も変わる
func get_text_params() -> Dictionary:
	var params: Dictionary = {"turns": duration_turns}
	for effect: EffectData in effects:
		if effect != null:
			params.merge(effect.get_text_params())
	return params


## 翻訳された説明文を、数値を入れて返す
func get_description() -> String:
	return tr(description_key).format(get_text_params())
