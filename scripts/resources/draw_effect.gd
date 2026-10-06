class_name DrawEffect
extends EffectData
## カードを引く効果

@export_range(0, 99) var count: int = 1


func get_text_params() -> Dictionary:
	return {"draw": count}
