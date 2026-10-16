extends SceneTree
## このパソコンで起動中の ComfyUI に頼んで、prompts/ のプロンプトから絵を生成するツール。
## 画像は「直接受け取る機能」（SaveImageWebsocket）で受け取り、art_trials/<素材名>/ に保存する
## （ComfyUI のフォルダには保存させない）。素材ごとに、候補を横に並べた一覧（_sheet_*.png）も作る。
## 生成の設定は docs/art_style.md 5章に合わせた tools/comfy/txt2img_hires.json を使う。
## 実行：godot --headless -s tools/comfy_generate.gd -- ids=card_fireball,enemy_slime count=4 style=A
##   ids    … prompts/*.csv の id（カンマ区切り）
##   count  … 1つの素材あたりの枚数（seed を1ずつ変える。省略時 4）
##   style  … 画風。A＝厚塗り（プロンプトのまま）、B＝フラット、C＝ドット絵風（省略時 A）
##   seed   … 最初の seed（省略時はランダム）
##   model  … 使うモデル（省略時 azovya。ライセンスを確認したモデルだけを MODELS に登録する）
##   lora   … 足す LoRA と強さ（例：lora=icon:0.6。省略時は使わない。ライセンスを確認したものだけを LORAS に登録する）
##            LoRA の発動の言葉はプロンプトの先頭に自動で足す。ファイル名の印は「モデル_LoRA強さ」（例：icon_icon06）
##   bg     … 背景を消すか。auto＝敵・主人公・クリーチャーだけ消す（省略時）、remove＝消す、keep＝消さない
##            消す時は ComfyUI の Remove Background（BiRefNet）で透明つきの画像にし、名前の最後に _bg を付ける

const SERVER := "127.0.0.1:8188"
const WORKFLOW_PATH := "res://tools/comfy/txt2img_hires.json"
## 背景を消す時の生成の手順（最後に背景を消して、透明つきの画像にする）
const WORKFLOW_BG_PATH := "res://tools/comfy/txt2img_hires_bg.json"
## bg=auto の時に背景を消す素材（id の始まり）
const BG_REMOVE_PREFIXES: Array[String] = ["enemy_", "hero_", "creature_"]
const PROMPTS_DIR := "res://prompts"
const OUT_DIR := "res://art_trials"
const LOG_PATH := "res://art_trials/generation_log.csv"
## 画像を受け取るノードの番号（txt2img_hires.json の中の番号）
const SAVE_NODE := "11"
## LoRA を足す時のノードの番号（手順のファイルで使っていない番号）
const LORA_NODE := "90"
## 1枚あたりの待ち時間の上限（秒）
const TIMEOUT := 600.0
## ライセンスを確認したモデル（docs/art_style.md に記録したもの）
const MODELS := {
	"azovya": "aZovyaRPGArtistTools_v4VAE.safetensors",
	"icon": "gameIconInstitute_v30.safetensors",  # アイコン用（游戏图标研究所 3.0）
}
## ライセンスを確認した LoRA（docs/art_style.md に記録したもの）。file：ファイル名、triggers：発動の言葉
const LORAS := {
	"icon": {"file": "game Icon Institute_anfg_v3-000018.safetensors", "triggers": "game icon institute, game icon, ahfg"},
}
## a-Zovya RPG の発動の言葉（他のモデルでは外す）
const AZOVYA_TRIGGER := "zrpgstyle, "
## 画風の言葉。A はプロンプトのまま、B・C は A の言葉を置き換える
const STYLE_A_WORDS := "painterly style, thick outlines, high contrast lighting"
const STYLES := {
	"A": STYLE_A_WORDS,
	"B": "flat vector illustration, clean flat shapes, simple cel shading",
	"C": "pixel art, 16-bit retro game sprite, limited color palette, crisp pixels",
}

var _ws := WebSocketPeer.new()
var _http := HTTPRequest.new()
var _client_id := ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var options := _options()
	var ids: PackedStringArray = String(options.get("ids", "")).split(",", false)
	var count := int(options.get("count", "4"))
	var style := String(options.get("style", "A")).to_upper()
	var model_key := String(options.get("model", "azovya"))
	var bg_mode := String(options.get("bg", "auto"))
	var lora := String(options.get("lora", "")).split(":")
	var lora_key := lora[0]
	var lora_weight := float(lora[1]) if lora.size() > 1 else 0.6
	if lora_key != "" and not LORAS.has(lora_key):
		printerr("lora は %s のどれか" % ", ".join(LORAS.keys()))
		quit(1)
		return
	# ファイル名に付ける印（モデルと LoRA の組み合わせが分かるように）
	var tag := model_key if lora_key == "" else "%s_%s%02d" % [model_key, lora_key, roundi(lora_weight * 10)]
	if ids.is_empty() or not STYLES.has(style) or not MODELS.has(model_key) or not bg_mode in ["auto", "remove", "keep"]:
		printerr("ids= を指定してください。style は A・B・C、model は %s、bg は auto・remove・keep のどれか" % ", ".join(MODELS.keys()))
		quit(1)
		return
	var rows := _load_prompts()
	for id: String in ids:
		if not rows.has(id):
			printerr("prompts/ に id がありません：%s" % id)
			quit(1)
			return
	var workflow_text := FileAccess.get_file_as_string(WORKFLOW_PATH)
	var workflow_bg_text := FileAccess.get_file_as_string(WORKFLOW_BG_PATH)
	if workflow_text == "" or workflow_bg_text == "":
		printerr("生成の手順が読めません：%s、%s" % [WORKFLOW_PATH, WORKFLOW_BG_PATH])
		quit(1)
		return
	root.add_child(_http)
	if not await _connect():
		printerr("ComfyUI につながりません（起動しているか確認してください）：%s" % SERVER)
		quit(1)
		return
	var first_seed := int(options["seed"]) if options.has("seed") else randi() % 1000000000
	var failed := false
	for id: String in ids:
		var row: Dictionary = rows[id]
		var size: PackedStringArray = String(row["size"]).split("x")
		var prompt := String(row["prompt"]).replace(STYLE_A_WORDS, STYLES[style])
		if model_key != "azovya":
			prompt = prompt.replace(AZOVYA_TRIGGER, "")
		if lora_key != "":
			prompt = "%s, %s" % [LORAS[lora_key]["triggers"], prompt]
		var saved: Array[String] = []
		var remove_bg := should_remove_background(id, bg_mode)
		var suffix := "_bg" if remove_bg else ""
		for i in count:
			var seed := first_seed + i
			var workflow: Dictionary = _whole_numbers(JSON.parse_string(workflow_bg_text if remove_bg else workflow_text))
			workflow["1"]["inputs"]["ckpt_name"] = MODELS[model_key]
			workflow["2"]["inputs"]["text"] = prompt
			workflow["3"]["inputs"]["text"] = row["negative"]
			workflow["4"]["inputs"]["width"] = int(size[0])
			workflow["4"]["inputs"]["height"] = int(size[1])
			workflow["5"]["inputs"]["seed"] = seed
			workflow["9"]["inputs"]["seed"] = seed
			if lora_key != "":
				add_lora(workflow, LORAS[lora_key]["file"], lora_weight)
			print("生成中：%s（画風%s・seed %d）%d/%d" % [id, style, seed, i + 1, count])
			var png := await _generate(workflow)
			if png.is_empty():
				printerr("生成に失敗しました：%s seed %d" % [id, seed])
				failed = true
				continue
			var path := OUT_DIR.path_join(id).path_join("%s_%s_s%d%s.png" % [style, tag, seed, suffix])
			_save(path, png)
			_log(path, MODELS[model_key] + ("" if lora_key == "" else " + %s:%s" % [LORAS[lora_key]["file"], lora_weight]), seed, style, workflow)
			saved.append(path)
			print("保存しました：%s" % path)
		if not saved.is_empty():
			_make_sheet(OUT_DIR.path_join(id).path_join("_sheet_%s_%s_s%d%s.png" % [style, tag, first_seed, suffix]), saved)
	_ws.close()
	print("生成が終わりました")
	quit(1 if failed else 0)


## 1枚生成して、PNG のデータを返す（失敗したら空）
func _generate(workflow: Dictionary) -> PackedByteArray:
	var body := JSON.stringify({"prompt": workflow, "client_id": _client_id})
	_http.request("http://%s/prompt" % SERVER, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	var response: Array = await _http.request_completed
	if response[1] != 200:
		printerr("ComfyUI が受け付けませんでした（%d）：%s" % [response[1], (response[3] as PackedByteArray).get_string_from_utf8()])
		return PackedByteArray()
	var prompt_id := String((JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8()) as Dictionary).get("prompt_id", ""))
	var current_node := ""
	var image := PackedByteArray()
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < TIMEOUT * 1000.0:
		_ws.poll()
		if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
			printerr("ComfyUI との接続が切れました")
			return PackedByteArray()
		while _ws.get_available_packet_count() > 0:
			var packet := _ws.get_packet()
			if not _ws.was_string_packet():
				# 受け取り用ノードの実行中に届いた画像だけを使う（途中経過のプレビューは無視する）
				if current_node == SAVE_NODE and packet.size() > 8:
					image = packet.slice(8)  # 先頭8バイトは種類の情報
				continue
			var message: Variant = JSON.parse_string(packet.get_string_from_utf8())
			if not message is Dictionary:
				continue
			var data: Dictionary = message.get("data", {})
			if data.get("prompt_id", "") != prompt_id:
				continue
			match message.get("type", ""):
				"executing":
					var node: Variant = data.get("node")
					if node == null:
						return image  # 全部終わった
					current_node = String(node)
				"execution_error":
					printerr("生成中にエラー：%s" % data.get("exception_message", ""))
					return PackedByteArray()
		await process_frame
	printerr("時間切れです")
	return PackedByteArray()


func _connect() -> bool:
	_client_id = "magic_the_spire_%d" % randi()
	if _ws.connect_to_url("ws://%s/ws?clientId=%s" % [SERVER, _client_id]) != OK:
		return false
	_ws.inbound_buffer_size = 64 * 1024 * 1024  # 大きな画像を受け取れるように
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 5000:
		_ws.poll()
		if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			return true
		await process_frame
	return false


## prompts/ の CSV をすべて読み込む（id → {prompt, negative, size}）
func _load_prompts() -> Dictionary:
	var rows := {}
	for file_name: String in DirAccess.get_files_at(PROMPTS_DIR):
		if not file_name.ends_with(".csv"):
			continue
		var file := FileAccess.open(PROMPTS_DIR.path_join(file_name), FileAccess.READ)
		var header := file.get_csv_line()
		while not file.eof_reached():
			var line := file.get_csv_line()
			if line.size() < header.size():
				continue
			var row := {}
			for i in header.size():
				row[header[i]] = line[i]
			rows[row["id"]] = row
	return rows


func _save(path: String, data: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()


## 生成の記録（docs/art_style.md の生成ログに使う）
func _log(path: String, model_text: String, seed: int, style: String, workflow: Dictionary) -> void:
	var is_new := not FileAccess.file_exists(LOG_PATH)
	var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if not is_new else FileAccess.WRITE)
	file.seek_end()
	if is_new:
		file.store_csv_line(PackedStringArray(["file", "model", "seed", "style", "size", "steps", "cfg", "hires_denoise", "date"]))
	var size := "%dx%d" % [workflow["4"]["inputs"]["width"], workflow["4"]["inputs"]["height"]]
	file.store_csv_line(PackedStringArray([path.trim_prefix(OUT_DIR + "/"), model_text, str(seed), style, size,
		str(workflow["5"]["inputs"]["steps"]), str(workflow["5"]["inputs"]["cfg"]),
		str(workflow["9"]["inputs"]["denoise"]), Time.get_date_string_from_system()]))
	file.close()


## 候補を横に並べた一覧の画像を作る（左から 1, 2, 3, …）
func _make_sheet(path: String, files: Array[String]) -> void:
	const HEIGHT := 512
	var images: Array[Image] = []
	var width := 0
	for file: String in files:
		var image := Image.load_from_file(ProjectSettings.globalize_path(file))
		if image == null:
			continue
		image.convert(Image.FORMAT_RGBA8)
		image.resize(int(image.get_width() * float(HEIGHT) / image.get_height()), HEIGHT, Image.INTERPOLATE_LANCZOS)
		images.append(image)
		width += image.get_width() + 8
	var sheet := Image.create(maxi(width - 8, 1), HEIGHT, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.2, 0.55, 0.3))  # 背景を消した絵の切り抜きが分かりやすい緑
	var x := 0
	for image: Image in images:
		sheet.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(x, 0))  # 透明な部分は一覧の地の色になる
		x += image.get_width() + 8
	sheet.save_png(ProjectSettings.globalize_path(path))
	print("一覧を作りました：%s" % path)


func _options() -> Dictionary:
	var options := {}
	for arg: String in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	return options


## JSON を読むと数字はすべて小数になるので、整数の値を整数に戻す（ComfyUI はつなぎ先の番号に整数を求めるため）
func _whole_numbers(value: Variant) -> Variant:
	if value is Dictionary:
		for key: Variant in value:
			value[key] = _whole_numbers(value[key])
	elif value is Array:
		for i in value.size():
			value[i] = _whole_numbers(value[i])
	elif value is float and value == floorf(value) and absf(value) < 1e15:
		return int(value)
	return value


## その素材の背景を消すか（bg_mode：auto・remove・keep）
static func should_remove_background(id: String, bg_mode: String) -> bool:
	match bg_mode:
		"remove":
			return true
		"keep":
			return false
	for prefix: String in BG_REMOVE_PREFIXES:
		if id.begins_with(prefix):
			return true
	return false


## 生成の手順に LoRA を足す（モデルと文字の読み取りの間に挟み、それを使うようにつなぎ替える）
static func add_lora(workflow: Dictionary, file: String, weight: float) -> void:
	workflow[LORA_NODE] = {"class_type": "LoraLoader", "inputs": {
		"model": ["1", 0], "clip": ["1", 1], "lora_name": file, "strength_model": weight, "strength_clip": weight}}
	for node_id: String in workflow:
		if node_id == LORA_NODE:
			continue
		var inputs: Dictionary = workflow[node_id]["inputs"]
		for key: String in inputs:
			var link: Variant = inputs[key]
			if link is Array and link.size() == 2 and str(link[0]) == "1" and int(link[1]) in [0, 1]:
				inputs[key] = [LORA_NODE, int(link[1])]  # 0＝絵を描く部分、1＝文字を読む部分
