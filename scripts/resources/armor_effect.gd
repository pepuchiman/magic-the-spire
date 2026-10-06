class_name ArmorEffect
extends EffectData
## アーマーを付与する効果

@export_range(0, 9999) var amount: int = 0


func get_text_params() -> Dictionary:
	return {"armor": amount}
