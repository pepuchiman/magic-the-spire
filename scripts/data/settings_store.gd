class_name SettingsStore
extends RefCounted
## 設定（音量・演出の速さ）の保存と読み込み。
## 保存先は user://settings.cfg（Windows では %APPDATA%\MagicTheSpire\settings.cfg）

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "settings"
## 演出の速さの選択肢（ゆっくり・ふつう・はやい）
const SPEED_SLOW := 0.6
const SPEED_NORMAL := 1.0
const SPEED_FAST := 1.6
const SPEEDS: Array[float] = [SPEED_SLOW, SPEED_NORMAL, SPEED_FAST]

## 保存先のファイル（テストでは別のファイルを使う）
var path: String
## BGM の音量（0〜1）
var bgm_volume: float = 0.7
## 効果音の音量（0〜1）
var se_volume: float = 0.8
## 戦闘の演出の速さ（SPEEDS のどれか）
var animation_speed: float = SPEED_NORMAL


func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path


## ファイルから読み込む（ファイルが無い・おかしな値の時は初期値）
func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	bgm_volume = clampf(float(file.get_value(SECTION, "bgm_volume", bgm_volume)), 0.0, 1.0)
	se_volume = clampf(float(file.get_value(SECTION, "se_volume", se_volume)), 0.0, 1.0)
	var speed := float(file.get_value(SECTION, "animation_speed", animation_speed))
	animation_speed = speed if SPEEDS.has(speed) else SPEED_NORMAL


func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "bgm_volume", bgm_volume)
	file.set_value(SECTION, "se_volume", se_volume)
	file.set_value(SECTION, "animation_speed", animation_speed)
	file.save(path)
