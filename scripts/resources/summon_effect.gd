class_name SummonEffect
extends EffectData
## 仲間を召喚する効果

## 召喚する仲間（直接参照する）
@export var ally: AllyData


## 説明文の {ally} に、召喚する仲間の名前（翻訳済み）を入れる
func get_text_params() -> Dictionary:
	return {"ally": tr(ally.name_key) if ally != null else ""}
