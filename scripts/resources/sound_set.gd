class_name SoundSet
extends Resource
## 種類ごとの音の一覧（data/config/sound_set.tres）。
## 今は tools/generate_sounds.gd で合成した音（assets/sounds/）を使っている。
## 本物の音に替える時は、assets/sounds/ のファイルを同じ名前で差し替えるか、インスペクターで入れ替える

## クリーチャー・敵の攻撃の音（攻撃エフェクトと同じ種類）
@export var attack_sounds: Dictionary[GameEnums.AttackEffect, AudioStream] = {}
## カードの効果の音（効果エフェクトと同じ種類。「なし」には登録しない）
@export var card_sounds: Dictionary[GameEnums.CardEffect, AudioStream] = {}
## その他の効果音
@export var event_sounds: Dictionary[GameEnums.SoundEvent, AudioStream] = {}
## BGM
@export var music: Dictionary[GameEnums.Music, AudioStream] = {}

const SOUNDS_DIR := "res://assets/sounds"


## すべての種類に、assets/sounds/ の決まった名前の音を登録した一覧を作る（先に音を作って --import しておく）
static func create_default() -> SoundSet:
	var sound_set := SoundSet.new()
	for type_name: String in GameEnums.AttackEffect.keys():
		sound_set.attack_sounds[GameEnums.AttackEffect[type_name]] = load(path_for("se_attack_", type_name))
	for type_name: String in GameEnums.CardEffect.keys():
		if type_name != "NONE":
			sound_set.card_sounds[GameEnums.CardEffect[type_name]] = load(path_for("se_card_", type_name))
	for type_name: String in GameEnums.SoundEvent.keys():
		sound_set.event_sounds[GameEnums.SoundEvent[type_name]] = load(path_for("se_", type_name))
	for type_name: String in GameEnums.Music.keys():
		sound_set.music[GameEnums.Music[type_name]] = load(path_for("bgm_", type_name))
	return sound_set


## 音のファイルの場所（例：se_attack_ + BLOW → res://assets/sounds/se_attack_blow.wav）
static func path_for(prefix: String, type_name: String) -> String:
	return SOUNDS_DIR.path_join(prefix + type_name.to_lower() + ".wav")
