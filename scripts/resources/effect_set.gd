class_name EffectSet
extends Resource
## 種類ごとのエフェクト（演出）のシーンの一覧（data/config/effect_set.tres）。
## シーンの決まり：一番上のノードが Node2D で、play(size: float, duration: float) を持ち、終わったら自分を消す。
## 今は ui/effects/ の図形のエフェクト（procedural_effect.gd）を使っている。
## 絵や光の粒のエフェクトに差し替える時は、同じ決まりのシーンを作り、インスペクターで入れ替える

## クリーチャー・敵の攻撃エフェクト（打撃・斬撃・刺突・炎・水・風）
@export var attack_effects: Dictionary[GameEnums.AttackEffect, PackedScene] = {}
## カードの効果エフェクト（「なし」には登録しない）
@export var card_effects: Dictionary[GameEnums.CardEffect, PackedScene] = {}

## 初期の一覧で使うシーンの場所（ui/effects/<名前>.tscn。名前は種類の英小文字）
const EFFECTS_DIR := "res://ui/effects"


## すべての種類に、ui/effects/ の同じ名前のシーンを登録した一覧を作る
static func create_default() -> EffectSet:
	var effect_set := EffectSet.new()
	for type_name: String in GameEnums.AttackEffect.keys():
		effect_set.attack_effects[GameEnums.AttackEffect[type_name]] = load(scene_path(type_name))
	for type_name: String in GameEnums.CardEffect.keys():
		if type_name != "NONE":
			effect_set.card_effects[GameEnums.CardEffect[type_name]] = load(scene_path(type_name))
	return effect_set


static func scene_path(type_name: String) -> String:
	return EFFECTS_DIR.path_join(type_name.to_lower() + ".tscn")
