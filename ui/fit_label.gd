class_name FitLabel
extends Label
## 文字が枠に収まらない時に、自動で文字を小さくするラベル。
## 言語によって文章の長さが変わっても、はみ出さないようにするために使う。
## 枠の大きさは親（コンテナ）が決める。文字の大きさで枠が広がらないよう clip_text を使う。

@export var max_font_size: int = 24:
	set(value):
		max_font_size = value
		_queue_fit()
@export var min_font_size: int = 10:
	set(value):
		min_font_size = value
		_queue_fit()

var _fit_queued := false


func _ready() -> void:
	clip_text = true
	resized.connect(_queue_fit)
	_queue_fit()


## 文章を変えて、大きさを合わせ直す
func set_fitted_text(value: String) -> void:
	text = value
	_queue_fit()


## 枠に収まる、いちばん大きな文字の大きさにする
func fit() -> void:
	_fit_queued = false
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var font := get_theme_font("font")
	var shown := atr(text)
	var font_size := max_font_size
	while font_size > min_font_size and not _fits(font, shown, font_size):
		font_size -= 1
	add_theme_font_size_override("font_size", font_size)


func _fits(font: Font, shown: String, font_size: int) -> bool:
	if autowrap_mode == TextServer.AUTOWRAP_OFF:
		return font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= size.x
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var text_size := font.get_multiline_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, size.x, font_size, -1, flags)
	return text_size.y <= size.y and text_size.x <= size.x


func _queue_fit() -> void:
	if _fit_queued or not is_inside_tree():
		return
	_fit_queued = true
	fit.call_deferred()
