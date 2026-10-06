class_name SelectBanner
extends PanelContainer
## 「捨てるカードを選ぶ」「入れ替える仲間を選ぶ」時の案内表示。
## 決定ボタン・やめるボタンは、必要な時だけ表示する

signal confirmed
signal cancelled

@onready var _label: FitLabel = %SelectLabel
@onready var _confirm_button: Button = %SelectConfirmButton
@onready var _cancel_button: Button = %SelectCancelButton


func _ready() -> void:
	add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL, UiPalette.SELECTED, 3, 12))
	_confirm_button.pressed.connect(confirmed.emit)
	_cancel_button.pressed.connect(cancelled.emit)
	hide()


func open(message: String, show_confirm: bool, show_cancel: bool) -> void:
	_label.set_fitted_text(message)
	_confirm_button.visible = show_confirm
	_cancel_button.visible = show_cancel
	show()


func set_message(message: String) -> void:
	_label.set_fitted_text(message)


func set_confirm_enabled(value: bool) -> void:
	_confirm_button.disabled = not value
