extends SceneTree
## assets/ に置いた画像を、ファイル名でデータの絵の項目に結び付けるツール。
## 名前の決まりは scripts/data/art_linker.gd の説明を参照。絵の項目以外は変えない。
## 実行の前に、画像を Godot に読み込ませる（--headless --import）。
## 実行：godot --headless -s tools/link_art.gd


func _init() -> void:
	var index := ResourceLoader.load(DataLoader.INDEX_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as DataIndex
	if index == null:
		printerr("索引が読み込めません：%s" % DataLoader.INDEX_PATH)
		quit(1)
		return
	var links := ArtLinker.find_links(index)
	if links.is_empty():
		print("新しく結び付ける画像はありません")
		quit()
		return
	for link: Dictionary in links:
		var resource: Resource = link["resource"]
		var field: String = link["field"] if link["key"] == null else "%s[%s]" % [link["field"], link["key"]]
		print("%s の %s ← %s" % [resource.resource_path, field, link["path"]])
	var failed := false
	for resource: Resource in ArtLinker.apply(links):
		if ResourceSaver.save(resource, resource.resource_path) != OK:
			printerr("保存に失敗しました：%s" % resource.resource_path)
			failed = true
	print("画像の結び付けが終わりました")
	quit(1 if failed else 0)
