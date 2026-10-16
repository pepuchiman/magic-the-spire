class_name ScreenFader
extends CanvasLayer
## 画面を切り替える時の暗転（すべての画面の上に重ねる）。
## fade(切り替える処理) で、暗くなる → 切り替える → 明るくなる、の順に進める。暗い間はタップを受け付けない

## 暗くなる時間・明るくなる時間（秒）
const FADE_OUT := 0.2
const FADE_IN := 0.25

var _cover: ColorRect
var _tween: Tween


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cover = ColorRect.new()
	_cover.color = Color(0, 0, 0, 0)
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cover)


## 暗くしてから switcher を呼び、次の画面ができたら明るくする
func fade(switcher: Callable) -> void:
	if _tween != null:
		_tween.kill()
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP  # 暗転中の連打で、2回切り替わらないように
	_tween = create_tween()
	_tween.tween_property(_cover, "color:a", 1.0, FADE_OUT * (1.0 - _cover.color.a))
	_tween.tween_callback(switcher)
	_tween.tween_interval(0.05)  # 次の画面が作られるのを待つ
	_tween.tween_property(_cover, "color:a", 0.0, FADE_IN)
	_tween.tween_callback(func() -> void: _cover.mouse_filter = Control.MOUSE_FILTER_IGNORE)


## 暗転の途中か
func is_fading() -> bool:
	return _tween != null and _tween.is_running()
