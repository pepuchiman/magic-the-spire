class_name SettingsPanel
extends ColorRect
## 設定画面（どの画面の上にも重ねて開ける窓）。BGM・効果音の音量と、戦闘の演出の速さを変える。
## 変えた設定は Game.settings に入れて、その場で保存する。中身はこのスクリプトが作る（new() して add_child するだけで使える）

## 設定を変えた時（戦闘画面が演出の速さをすぐ反映するため）
signal settings_changed
## 閉じた時
signal closed

const SPEED_KEYS: Array[String] = ["UI_SPEED_SLOW", "UI_SPEED_NORMAL", "UI_SPEED_FAST"]

var bgm_slider: HSlider
var se_slider: HSlider
var speed_buttons: Array[Button] = []
var _bgm_value: Label
var _se_value: Label


func _ready() -> void:
	color = Color(0, 0, 0, 0.6)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 3
	var box := PanelContainer.new()
	var box_style := UiPalette.make_box(UiPalette.PANEL, UiPalette.PANEL_BORDER, 3, 18)
	box_style.set_content_margin_all(28)  # 文字が枠に近づきすぎないように
	box.add_theme_stylebox_override("panel", box_style)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.anchor_top = 0.38  # 親指が届く下寄りに置く
	box.anchor_bottom = 0.97
	box.offset_left = 24
	box.offset_right = -24
	add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	box.add_child(column)
	column.add_child(_label("UI_SETTINGS_TITLE", 34, UiPalette.TEXT))
	var bgm := _volume_row(column, "UI_BGM_VOLUME")
	bgm_slider = bgm[0]
	_bgm_value = bgm[1]
	var se := _volume_row(column, "UI_SE_VOLUME")
	se_slider = se[0]
	_se_value = se[1]
	column.add_child(_label("UI_ANIMATION_SPEED", 26, UiPalette.TEXT_SUB))
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 12)
	column.add_child(speed_row)
	for i in SPEED_KEYS.size():
		var button := Button.new()
		button.text = SPEED_KEYS[i]
		button.custom_minimum_size = Vector2(0, 84)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 26)
		button.pressed.connect(set_speed.bind(SettingsStore.SPEEDS[i]))
		speed_row.add_child(button)
		speed_buttons.append(button)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var close := Button.new()
	close.text = "UI_CLOSE"
	close.custom_minimum_size = Vector2(0, 96)
	close.add_theme_font_size_override("font_size", 30)
	UiPalette.style_button(close, UiPalette.BUTTON_ACCENT)
	close.pressed.connect(close_panel)
	column.add_child(close)
	bgm_slider.value_changed.connect(func(value: float) -> void: _set_volume(true, value))
	se_slider.value_changed.connect(func(value: float) -> void: _set_volume(false, value))
	se_slider.drag_ended.connect(func(_changed: bool) -> void: UiSound.event(GameEnums.SoundEvent.BUTTON))  # 確認の音
	hide()


## 今の設定を表示して開く
func open() -> void:
	var settings: SettingsStore = Game.settings
	bgm_slider.set_value_no_signal(roundf(settings.bgm_volume * 100.0))
	se_slider.set_value_no_signal(roundf(settings.se_volume * 100.0))
	_update_labels()
	_update_speed_buttons()
	show()


func close_panel() -> void:
	hide()
	closed.emit()


## 演出の速さを変える（SettingsStore.SPEEDS のどれか）
func set_speed(speed: float) -> void:
	Game.settings.animation_speed = speed
	Game.settings.save_settings()
	_update_speed_buttons()
	settings_changed.emit()


func _set_volume(is_bgm: bool, percent: float) -> void:
	if is_bgm:
		Game.settings.bgm_volume = percent / 100.0
	else:
		Game.settings.se_volume = percent / 100.0
	Game.apply_settings()
	Game.settings.save_settings()
	_update_labels()
	settings_changed.emit()


func _update_labels() -> void:
	_bgm_value.text = UiText.fmt("UI_VOLUME_PERCENT", {"value": int(bgm_slider.value)})
	_se_value.text = UiText.fmt("UI_VOLUME_PERCENT", {"value": int(se_slider.value)})


## 選んでいる速さのボタンを目立たせる
func _update_speed_buttons() -> void:
	for i in speed_buttons.size():
		var chosen := is_equal_approx(SettingsStore.SPEEDS[i], Game.settings.animation_speed)
		UiPalette.style_button(speed_buttons[i], UiPalette.BUTTON_ACCENT if chosen else UiPalette.BUTTON)


## 「名前」「つまみ」「値」の1行を作り、[つまみ, 値の表示] を返す
func _volume_row(parent: Control, key: String) -> Array:
	parent.add_child(_label(key, 26, UiPalette.TEXT_SUB))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.custom_minimum_size = Vector2(0, 64)  # 指で動かしやすい高さ
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.add_theme_stylebox_override("slider", UiPalette.make_box(UiPalette.HP_BACK.lightened(0.2), Color.TRANSPARENT, 0, 8))
	slider.add_theme_stylebox_override("grabber_area", UiPalette.make_box(UiPalette.MANA, Color.TRANSPARENT, 0, 8))
	slider.add_theme_stylebox_override("grabber_area_highlight", UiPalette.make_box(UiPalette.MANA.lightened(0.2), Color.TRANSPARENT, 0, 8))
	slider.add_theme_icon_override("grabber", _grabber_icon(UiPalette.TEXT))
	slider.add_theme_icon_override("grabber_highlight", _grabber_icon(UiPalette.HIGHLIGHT))
	row.add_child(slider)
	var value := Label.new()
	value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	value.custom_minimum_size = Vector2(100, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 26)
	row.add_child(value)
	return [slider, value]


func _label(key: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = key
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label


## つまみの丸（指で押しやすい大きさ）
static func _grabber_icon(fill: Color) -> Texture2D:
	var size := 44
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) / 2.0
	for y in size:
		for x in size:
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
			image.set_pixel(x, y, Color(fill, clampf(size / 2.0 - distance, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)
