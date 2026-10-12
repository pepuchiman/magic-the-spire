class_name UnitDetailPopup
extends ColorRect
## クリーチャーの詳しい情報の窓（名前・行動予告・HP・アーマー・状態効果）。
## 画面のどこかをタップすると閉じる

const INFO_SCENE := preload("res://ui/unit_info_panel.tscn")
const PANEL_SIZE := Vector2(420, 240)

var combatant: Combatant
var _panel: UnitInfoPanel


func _ready() -> void:
	color = Color(0, 0, 0, 0.6)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func open(target: Combatant) -> void:
	combatant = target
	if _panel != null:
		_panel.queue_free()
	_panel = INFO_SCENE.instantiate()
	_panel.show_intent = true
	_panel.custom_minimum_size = PANEL_SIZE
	add_child(_panel)
	_panel.set_combatant(target)
	_panel.position = (size - PANEL_SIZE) / 2.0
	show()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide()
		accept_event()
