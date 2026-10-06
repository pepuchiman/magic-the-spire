class_name DamageEffect
extends EffectData
## ダメージを与える効果

@export_range(0, 9999) var amount: int = 0


func get_text_params() -> Dictionary:
	return {"damage": amount}
