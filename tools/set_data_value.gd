extends SceneTree
## 既存のデータ（.tres）の、指定した項目だけを書き換えるツール。
## 他の項目（インスペクターで調整した値など）はそのまま残る。
## 実行：godot --headless -s tools/set_data_value.gd -- file=res://data/cards/fireball.tres key=uses_per_battle value=1
## 対応している項目の種類：
##   整数、小数、真偽値（true/false）、文字列、StringName
##   選択肢（列挙型）：名前で指定できる（例：key=rarity value=RARE）
##   選択肢のリスト：カンマ区切りで指定する（例：key=targets value=ANY または value=ENEMY,SELF）
##   他のデータへの参照・その一覧：res:// から始まる場所で指定する
##     （例：key=events value=res://data/events/altar.tres,res://data/events/lost_spirit.tres）
##   IDの一覧：カンマ区切りで指定する（例：key=usable_heroes value=flame_mage,frost_mage）


func _init() -> void:
	var options := {}
	for arg: String in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	for required: String in ["file", "key", "value"]:
		if not options.has(required):
			printerr("%s= の指定がありません" % required)
			quit(1)
			return
	var path: String = options["file"]
	var key: String = options["key"]
	var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null:
		printerr("読み込めません：%s" % path)
		quit(1)
		return
	var property := _find_property(resource, key)
	if property.is_empty():
		printerr("項目がありません：%s" % key)
		quit(1)
		return
	var before := str(resource.get(key))
	if not _apply(resource, property, options["value"]):
		quit(1)
		return
	var err := ResourceSaver.save(resource, path)
	if err != OK:
		printerr("保存に失敗しました（%d）" % err)
		quit(1)
		return
	print("%s の %s を %s → %s に変更しました" % [path, key, before, str(resource.get(key))])
	quit()


func _find_property(resource: Resource, key: String) -> Dictionary:
	for property: Dictionary in resource.get_property_list():
		if property["name"] == key and property["usage"] & PROPERTY_USAGE_STORAGE:
			return property
	return {}


## 値を変換して設定する。できなければ false
func _apply(resource: Resource, property: Dictionary, text: String) -> bool:
	var key: String = property["name"]
	match property["type"]:
		TYPE_INT:
			var number: Variant = _to_int(text, property["hint_string"])
			if number == null:
				return false
			resource.set(key, number)
		TYPE_FLOAT:
			resource.set(key, float(text))
		TYPE_BOOL:
			resource.set(key, text.to_lower() == "true")
		TYPE_STRING:
			resource.set(key, text)
		TYPE_STRING_NAME:
			resource.set(key, StringName(text))
		TYPE_OBJECT:
			var single := _load_resource(text)
			if single == null:
				return false
			resource.set(key, single)
		TYPE_ARRAY:
			# 型付きのリストは、元のリストを空にしてから入れ直す（リストの型を保つため）
			var list: Array = resource.get(key)
			var hint := str(property["hint_string"])
			var element_type := list.get_typed_builtin()
			var values: Array = []
			for part: String in text.split(",", false):
				var element: Variant
				match element_type:
					TYPE_OBJECT:
						element = _load_resource(part.strip_edges())  # 他のデータの一覧
					TYPE_STRING_NAME:
						element = StringName(part.strip_edges())  # IDの一覧（例：利用キャラクター）
					TYPE_STRING:
						element = part.strip_edges()
					_:
						element = _to_int(part.strip_edges(), _element_hint(hint))  # 選択肢の一覧
				if element == null:
					return false
				values.append(element)
			list.clear()
			list.append_array(values)
		_:
			printerr("この種類の項目には対応していません：%s（%s）" % [key, type_string(property["type"])])
			return false
	return true


## 数字、または選択肢の名前（例：RARE）を整数にする
func _to_int(text: String, hint_string: String) -> Variant:
	if text.is_valid_int():
		return int(text)
	# 選択肢の一覧（"Common:0,Self And All Allies:4,..." の形）から名前を探す。
	# 大文字・小文字や、空白と _ の違いは区別しない（SELF_AND_ALL_ALLIES でも Self And All Allies でもよい）
	for entry: String in hint_string.split(","):
		var pair := entry.split(":")
		if pair.size() == 2 and _normalize(pair[0]) == _normalize(text):
			return int(pair[1])
	printerr("選択肢の名前が見つかりません：%s（選べる値：%s）" % [text, hint_string])
	return null


## 他のデータ（res://～.tres）を読み込む
func _load_resource(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		printerr("データが見つかりません：%s" % path)
		return null
	return load(path)


func _normalize(name: String) -> String:
	return name.strip_edges().to_upper().replace(" ", "_")


## 型付きリストの説明（"2/2:ENEMY:0,ALLY:1,..."）から、要素の選択肢の部分を取り出す
func _element_hint(hint_string: String) -> String:
	var colon := hint_string.find(":")
	return hint_string.substr(colon + 1) if colon >= 0 else ""
