extends SceneTree
## 全データを検証するツール。
## 実行：godot --headless -s tools/validate_data.gd
## エラーがあれば一覧を表示し、終了コード1で終わる。


func _init() -> void:
	var errors := DataValidator.validate_project()
	if errors.is_empty():
		print("検証OK：エラーはありません")
		quit(0)
		return
	for message: String in errors:
		printerr("エラー：%s" % message)
	printerr("検証NG：%d 件のエラー" % errors.size())
	quit(1)
