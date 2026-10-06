extends Control
## タイトル画面。今は「ゲームを始める」でサンプル戦へ進む（フェーズ4でダンジョン選択へ変える）

const BATTLE_SCENE := "res://scenes/battle/battle_screen.tscn"


func _ready() -> void:
	$StartButton.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(BATTLE_SCENE)
