extends Control
## 宝箱画面。「開ける」と中身（装備 または レア以上のカード）が出る。「取る」「取らない」を選んでマップへ戻る。
## 装備なら、今の装備との比較（差分）も表示する

const CARD_SCENE := preload("res://ui/card_view.tscn")

## 宝箱の中身：{"equipment": 装備} または {"card": カード}
var content: Dictionary = {}
var opened: bool = false


func _ready() -> void:
	UiPalette.style_button(%OpenButton, UiPalette.BUTTON_ACCENT)
	UiPalette.style_button(%LeaveButton, UiPalette.BUTTON)
	UiPalette.style_button(%TakeButton, UiPalette.BUTTON_ACCENT)
	%OpenButton.pressed.connect(open)
	%LeaveButton.pressed.connect(leave)
	%TakeButton.pressed.connect(take)
	content = RewardGenerator.treasure(Game.run)


## 宝箱を開けて中身を見せる
func open() -> void:
	if opened:
		return
	opened = true
	%OpenButton.hide()
	%Chest.hide()
	if content.has("equipment"):
		var view := EquipmentView.new()
		view.custom_minimum_size.x = 560
		%ContentArea.add_child(view)
		view.show_item(content["equipment"])
		view.show_diff(Game.run.get_equipped(content["equipment"].equipment_type))
	else:
		var card_view: CardView = CARD_SCENE.instantiate()
		card_view.card_scale = 2.0
		%ContentArea.add_child(card_view)
		card_view.set_card(content["card"])
	%Buttons.show()
	# 開けた時の小さな演出（図形のみ）
	var shown: Control = %ContentArea.get_child(%ContentArea.get_child_count() - 1)
	shown.modulate.a = 0.0
	create_tween().tween_property(shown, "modulate:a", 1.0, 0.4)


## 中身を取る（装備なら装備する。同じ種類の装備は入れ替わる）
func take() -> void:
	if content.has("equipment"):
		RewardGenerator.equip(Game.run, content["equipment"])
	else:
		RewardGenerator.take(Game.run, content["card"])
	Game.finish_node()


func leave() -> void:
	Game.finish_node()
