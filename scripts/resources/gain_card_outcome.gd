class_name GainCardOutcome
extends EventOutcome
## カードを獲得する（主人公が使えるカードから、条件に合うものをランダムに選ぶ）

## このレアリティ以上のカードから選ぶ
@export var min_rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
## オンにすると、下の種別のカードだけから選ぶ
@export var filter_by_type: bool = false
@export var card_type: GameEnums.CardType = GameEnums.CardType.SUMMON
@export_range(1, 5) var count: int = 1
