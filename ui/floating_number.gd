class_name FloatingNumber
extends Label
## ダメージや回復の数字が、上にふわっと動いて消える演出


## parent の中の position（中心）に文字を出す
static func spawn(parent: Control, center: Vector2, text_value: String, color: Color, duration: float) -> void:
	if duration <= 0.0:
		return
	var label := FloatingNumber.new()
	label.text = text_value
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	parent.add_child(label)
	label.position = center - label.get_minimum_size() / 2.0
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 70.0, duration)
	tween.tween_property(label, "modulate:a", 0.0, duration).set_delay(duration * 0.4)
	tween.chain().tween_callback(label.queue_free)
