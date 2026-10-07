class_name ProgressStore
extends RefCounted
## ゲームの進み具合（クリアしたダンジョン＝アンロックの状況）の保存と読み込み。
## 保存先は user://progress.cfg（Windows では %APPDATA%\MagicTheSpire\progress.cfg）

const DEFAULT_PATH := "user://progress.cfg"
const SECTION := "progress"

## 保存先のファイル（テストでは別のファイルを使う）
var path: String
## クリアしたダンジョンのID
var cleared_dungeons: Array[StringName] = []


func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path


## ファイルから読み込む（ファイルが無ければ、何もクリアしていない状態）
func load_progress() -> void:
	cleared_dungeons.clear()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for id: Variant in file.get_value(SECTION, "cleared_dungeons", []):
		cleared_dungeons.append(StringName(str(id)))


func save_progress() -> void:
	var file := ConfigFile.new()
	var ids: Array[String] = []
	for id: StringName in cleared_dungeons:
		ids.append(String(id))
	file.set_value(SECTION, "cleared_dungeons", ids)
	var err := file.save(path)
	if err != OK:
		push_error("進み具合の保存に失敗しました（%d）：%s" % [err, path])


## すべて消して、最初の状態に戻す（開発用のリセットボタンで使う）
func reset() -> void:
	cleared_dungeons.clear()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func is_cleared(dungeon_id: StringName) -> bool:
	return cleared_dungeons.has(dungeon_id)


## クリアを記録する。初めてのクリアなら true
func record_clear(dungeon_id: StringName) -> bool:
	if is_cleared(dungeon_id):
		return false
	cleared_dungeons.append(dungeon_id)
	return true


## 解放されているか（requirement は「このダンジョンをクリアすると解放」のID。空なら最初から解放）
func is_unlocked(requirement: StringName) -> bool:
	return requirement == &"" or is_cleared(requirement)


## 主人公・ダンジョン・カードの一覧から、解放されているものだけを返す。
## progress が null なら、最初から解放されているものだけを返す
static func filter_unlocked(items: Array, progress: ProgressStore) -> Array:
	var result: Array = []
	for item: Resource in items:
		var requirement: StringName = item.get("unlocked_by_clearing")
		if requirement == &"" or (progress != null and progress.is_unlocked(requirement)):
			result.append(item)
	return result
