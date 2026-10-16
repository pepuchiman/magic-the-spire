extends SceneTree
## 選んだ候補を、ゲームで使う大きさにして assets/ に置くツール。
## 選択は art_trials/selection.csv に書く（列：id, file。file は art_trials/ からの場所）。
##   例：card_spark,card_spark/A_azovya_s6002.png
## 置き場所と大きさは、素材の名前（id の始まり）で決まる（下の target_for）。背景を消した絵は透明な余白を切り落とす。
## このあと、--headless --import → tools/link_art.gd → tools/validate_data.gd の順に実行する。
## 実行：godot --headless -s tools/adopt_art.gd （-- file=res://art_trials/selection.csv で一覧を変えられる）

const Resize := preload("res://tools/resize_image.gd")
const TRIALS_DIR := "res://art_trials"
const DEFAULT_SELECTION := "res://art_trials/selection.csv"


func _init() -> void:
	var selection := DEFAULT_SELECTION
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("file="):
			selection = arg.substr(5)
	var file := FileAccess.open(selection, FileAccess.READ)
	if file == null:
		printerr("選択の一覧が読めません：%s" % selection)
		quit(1)
		return
	var header := file.get_csv_line()
	var failed := false
	var count := 0
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 2 or line[0] == "" or line[0] == header[0]:
			continue
		if not adopt(line[0], TRIALS_DIR.path_join(line[1])):
			failed = true
		else:
			count += 1
	print("%d 件を assets/ に置きました。次に --import → tools/link_art.gd → 検証 を実行してください" % count)
	quit(1 if failed else 0)


## 1つの素材を置く。できなければ false
static func adopt(id: String, source: String) -> bool:
	var target := target_for(id)
	if target.is_empty():
		printerr("置き場所の決まりがない素材です：%s" % id)
		return false
	var image := Image.load_from_file(ProjectSettings.globalize_path(source))
	if image == null:
		printerr("画像を読み込めません：%s" % source)
		return false
	if target["trim"]:
		image = Resize.trim_transparent(image)
	var height: int = target["height"]
	if image.get_height() > height:
		image.resize(int(image.get_width() * float(height) / image.get_height()), height, Image.INTERPOLATE_LANCZOS)
	var out_path := ProjectSettings.globalize_path(target["path"])
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	if image.save_png(out_path) != OK:
		printerr("保存できません：%s" % target["path"])
		return false
	print("%s ← %s（%dx%d）" % [target["path"], source, image.get_width(), image.get_height()])
	return true


## 素材の名前から、置き場所・仕上がりの高さ・余白を切り落とすかを決める（docs/art_style.md 3章の名前の決まり）
static func target_for(id: String) -> Dictionary:
	var rules := [
		["card_", "res://assets/cards", 512, false],
		["enemy_", "res://assets/enemies", 640, true],
		["hero_", "res://assets/player", 768, true],
		["creature_", "res://assets/creatures", 640, true],
		["bg_", "res://assets/backgrounds", 1280, false],
		["status_", "res://assets/icons", 256, true],
		["map_", "res://assets/icons", 256, true],
		["equip_", "res://assets/icons", 256, true],
	]
	for rule: Array in rules:
		if id.begins_with(rule[0]):
			return {"path": String(rule[1]).path_join(id + ".png"), "height": rule[2], "trim": rule[3]}
	return {}
