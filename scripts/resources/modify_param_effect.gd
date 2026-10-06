class_name ModifyParamEffect
extends EffectData
## パラメーターを増減させる効果（例：マナ基準値+1）。装備の効果にも使う

@export var param: GameEnums.Param = GameEnums.Param.MANA_BASE
## 増減する量（減らす場合はマイナス）
@export_range(-9999, 9999) var amount: int = 0


func get_text_params() -> Dictionary:
	return {"amount": amount}
