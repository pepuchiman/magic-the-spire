extends SceneTree
## 指定したフォルダの .tres を読み込んで、そのまま保存し直すツール。
## データの型から項目を削除した時に、ファイルに残った古い項目を消すために使う。
## 値は変えない（読み込んだ値をそのまま保存する）。
## 実行：godot --headless -s tools/resave_data.gd -- dir=res://data/enemies


func _init() -> void:
	var dir_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("dir="):
			dir_path = arg.substr(4)
	if dir_path == "":
		printerr("dir= の指定がありません")
		quit(1)
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		printerr("フォルダを開けません：%s" % dir_path)
		quit(1)
		return
	var failed := false
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var path := dir_path.path_join(file_name)
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource == null or ResourceSaver.save(resource, path) != OK:
			printerr("保存し直せません：%s" % path)
			failed = true
			continue
		print("保存し直しました：%s" % path)
	quit(1 if failed else 0)
