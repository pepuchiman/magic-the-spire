class_name RunSaveStore
extends RefCounted
## ラン（1回の挑戦）の中断データのファイルを扱う（保存・読み込み・有無の確認・削除）。
## 保存先は user://run_save.json（Windows では %APPDATA%\MagicTheSpire\run_save.json）。
## 中身は人が読める形式（JSON）で保存する

const DEFAULT_PATH := "user://run_save.json"

## 保存先のファイル（テストでは別のファイルを使う）
var path: String


func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path


func exists() -> bool:
	return FileAccess.file_exists(path)


## 保存する。うまくいけば true
func write(data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


## 読み込む。ファイルが無い・壊れている時は空の辞書
func read() -> Dictionary:
	if not exists():
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}  # 壊れている
	return json.data if json.data is Dictionary else {}


func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
