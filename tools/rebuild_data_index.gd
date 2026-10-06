extends SceneTree
## 索引（data/data_index.tres）を再生成するツール。
## 実行：godot --headless -s tools/rebuild_data_index.gd
## data/ の各フォルダにある .tres を集めて、索引に登録する。

const INDEX_PATH := "res://data/data_index.tres"


func _init() -> void:
	var index := DataIndex.new()
	_collect("res://data/cards", index.cards)
	_collect("res://data/heroes", index.heroes)
	_collect("res://data/allies", index.allies)
	_collect("res://data/enemies", index.enemies)
	_collect("res://data/equipment", index.equipment)
	_collect("res://data/events", index.events)
	_collect("res://data/dungeons", index.dungeons)

	var err := ResourceSaver.save(index, INDEX_PATH)
	if err != OK:
		push_error("索引の保存に失敗しました（%d）" % err)
		quit(1)
		return
	print("索引を再生成しました：カード%d、主人公%d、仲間%d、敵%d、装備%d、イベント%d、ダンジョン%d" % [
		index.cards.size(), index.heroes.size(), index.allies.size(), index.enemies.size(),
		index.equipment.size(), index.events.size(), index.dungeons.size()])
	quit()


## フォルダ内の .tres を（ファイル名順に）読み込んで、配列に入れる
func _collect(dir_path: String, target: Array) -> void:
	var file_names := Array(DirAccess.get_files_at(dir_path))
	file_names.sort()
	for file_name: String in file_names:
		if not file_name.ends_with(".tres"):
			continue
		var res := ResourceLoader.load(dir_path.path_join(file_name), "", ResourceLoader.CACHE_MODE_REPLACE)
		if res == null:
			push_error("読み込めません：%s" % file_name)
			continue
		target.append(res)
