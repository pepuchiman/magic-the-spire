class_name ResultOverlay
extends ColorRect
## バトルの勝敗の表示

signal back_to_title_pressed

@onready var _title: Label = %ResultTitle
@onready var _detail: Label = %ResultDetail
@onready var _button: Button = %BackToTitleButton


func _ready() -> void:
	color = Color(0, 0, 0, 0.75)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_button.pressed.connect(back_to_title_pressed.emit)
	hide()


func open(result: BattleResult) -> void:
	_title.text = UiText.t("UI_VICTORY" if result.won else "UI_DEFEAT")
	_title.add_theme_color_override("font_color", UiPalette.HIGHLIGHT if result.won else UiPalette.DAMAGE)
	_detail.text = UiText.fmt("UI_RESULT_TURNS", {"turns": result.turns})
	show()
