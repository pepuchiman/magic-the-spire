class_name UiSound
extends RefCounted
## 画面から音を鳴らす時の窓口。全体の管理役 Sound を探して頼む。
## Sound がいない時（ツールから画面の部品だけを動かす時など）は何もしない

static func event(type: GameEnums.SoundEvent) -> void:
	var sound := _sound()
	if sound != null:
		sound.play_event(type)


static func attack(type: GameEnums.AttackEffect) -> void:
	var sound := _sound()
	if sound != null:
		sound.play_attack(type)


static func card(type: GameEnums.CardEffect) -> void:
	var sound := _sound()
	if sound != null:
		sound.play_card(type)


static func music(type: GameEnums.Music) -> void:
	var sound := _sound()
	if sound != null:
		sound.play_music(type)


static func _sound() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Sound") if tree != null else null
