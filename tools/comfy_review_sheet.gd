extends SceneTree
## 生成した候補を見比べるための一覧の画像を作るツール。
## 1行に1素材（名前と、候補の 1〜4 番）を並べ、おすすめの候補を金色の枠で囲む。
## カードはゲームと同じ範囲（約5:4の横長）に切り取って見せる。背景を消した絵は緑の地に重ねる。
## 文字を描くため、画面ありで実行する（--headless を付けない）。
## 実行：godot -s tools/comfy_review_sheet.gd -- ids=card_spark,card_meteor seed=6000 picks=card_spark:3,card_meteor:1 out=res://art_trials/_review_cards_1.png
##   ids   … 素材（prompts/*.csv の id。カンマ区切り）
##   seed  … 候補の最初の seed（comfy_generate.gd で指定したもの）。候補は seed, seed+1, … の順に 1, 2, … 番
##   picks … おすすめ（素材:番号。省略可）。x は「全部失敗」、番号の後ろの x は「描き直し推奨（その番号は仮の候補）」の印
##           （例：card_spark:3,card_meteor:x,card_curse:2x）
##   count … 候補の数（省略時 4）
##   style … 画風（省略時 A）
##   tag   … ファイル名のモデルの印（省略時 azovya。LoRA を使った時は icon_icon06 など）

const OUT_DIR := "res://art_trials"
const MODEL_KEY := "azovya"
const THUMB_HEIGHT := 200.0
const LABEL_WIDTH := 230.0
const GAP := 10.0
## カードの絵の表示範囲（横:縦）。ui/card_view.gd の絵の枠に合わせる
const CARD_ASPECT := 1.25


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var options := {}
	for arg: String in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	var ids: PackedStringArray = String(options.get("ids", "")).split(",", false)
	if ids.is_empty() or not options.has("seed") or not options.has("out"):
		printerr("ids=、seed=、out= を指定してください")
		quit(1)
		return
	var seed := int(options["seed"])
	var count := int(options.get("count", "4"))
	var style := String(options.get("style", "A"))
	var tag := String(options.get("tag", MODEL_KEY))
	var picks := {}
	for pick: String in String(options.get("picks", "")).split(",", false):
		var pair := pick.split(":")
		if pair.size() == 2:
			picks[pair[0]] = pair[1]

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", int(GAP))
	var width := 0.0
	for id: String in ids:
		var row := _make_row(id, seed, count, style, tag, String(picks.get(id, "")))
		rows.add_child(row)
		width = maxf(width, row.get_combined_minimum_size().x)
	var viewport := SubViewport.new()
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var page := PanelContainer.new()
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.12, 0.12, 0.14)
	style_box.set_content_margin_all(GAP)
	page.add_theme_stylebox_override("panel", style_box)
	page.add_child(rows)
	viewport.add_child(page)
	root.add_child(viewport)
	await process_frame
	var size := page.get_combined_minimum_size()
	viewport.size = Vector2i(ceili(size.x), ceili(size.y))
	page.size = size
	for i in 3:
		await process_frame
	var image := viewport.get_texture().get_image()
	var out_path := ProjectSettings.globalize_path(options["out"])
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	image.save_png(out_path)
	print("一覧を作りました：%s（%dx%d）" % [options["out"], image.get_width(), image.get_height()])
	quit()


func _make_row(id: String, seed: int, count: int, style: String, tag: String, pick: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(GAP))
	var label := Label.new()
	label.custom_minimum_size = Vector2(LABEL_WIDTH, THUMB_HEIGHT)
	label.text = id
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.add_theme_font_size_override("font_size", 22)
	row.add_child(label)
	var failed := pick.ends_with("x")
	var pick_number := int(pick.trim_suffix("x")) if pick.trim_suffix("x").is_valid_int() else -1
	for i in count:
		var path := _find_candidate(id, style, tag, seed + i)
		var cell := PanelContainer.new()
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(0.2, 0.55, 0.3)  # 背景を消した絵の透明な部分はこの緑
		frame.set_content_margin_all(5)
		frame.set_border_width_all(5)
		frame.border_color = Color("E8B84A") if i + 1 == pick_number else Color(0.25, 0.25, 0.28)
		cell.add_theme_stylebox_override("panel", frame)
		var holder := Control.new()
		var thumb := TextureRect.new()
		thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var aspect := 1.0
		if path != "":
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			if image != null:
				thumb.texture = ImageTexture.create_from_image(image)
				aspect = float(image.get_width()) / image.get_height()
		if id.begins_with("card_"):
			aspect = CARD_ASPECT  # ゲームで見える範囲に切り取る
		holder.custom_minimum_size = Vector2(THUMB_HEIGHT * aspect, THUMB_HEIGHT)
		holder.add_child(thumb)
		var number := Label.new()
		number.text = str(i + 1) if path != "" else "%d（なし）" % (i + 1)
		number.position = Vector2(6, 2)
		number.add_theme_font_size_override("font_size", 30)
		number.add_theme_color_override("font_outline_color", Color.BLACK)
		number.add_theme_constant_override("outline_size", 8)
		holder.add_child(number)
		cell.add_child(holder)
		row.add_child(cell)
	if failed:
		var mark := Label.new()
		mark.text = "描き直し推奨\n（金枠は仮の候補）" if pick_number > 0 else "全部失敗\n→描き直し"
		mark.add_theme_font_size_override("font_size", 22)
		mark.add_theme_color_override("font_color", Color(1, 0.45, 0.45))
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.custom_minimum_size.y = THUMB_HEIGHT
		row.add_child(mark)
	return row


## 候補の画像の場所（背景を消した絵は名前の最後が _bg）。無ければ空
static func _find_candidate(id: String, style: String, tag: String, seed: int) -> String:
	for suffix: String in ["", "_bg"]:
		var path := OUT_DIR.path_join(id).path_join("%s_%s_s%d%s.png" % [style, tag, seed, suffix])
		if FileAccess.file_exists(path):
			return path
	return ""
