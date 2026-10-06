class_name HealEffect
extends EffectData
## HPを回復する効果（最大HPまで）

@export_range(0, 9999) var amount: int = 0


func get_text_params() -> Dictionary:
	return {"heal": amount}
