class_name EffectData
extends Resource
## 効果の部品の親クラス。種類ごとにサブクラス（DamageEffect など）を作る。
## インスペクターで「効果」を追加する時、サブクラスの種類を選ぶ。

## 説明文の差し込み用の値を返す（例：{"damage": 6}）。サブクラスで上書きする
func get_text_params() -> Dictionary:
	return {}
