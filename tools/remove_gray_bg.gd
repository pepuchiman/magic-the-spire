extends SceneTree
## 灰色の背景（docs/art_style.md の「plain flat gray background」）を透明にするツール。
## 画像の外周から、背景らしい部分を塗りつぶしの要領でたどって透明にする
## （キャラクターの中にある灰色は、外周とつながっていなければ消えない）。
## 透明になった余白は切り落とす（キャラクターの大きさを、立ち位置の枠に合わせやすくするため）。
## 実行：godot --headless -s tools/remove_gray_bg.gd -- in=res://art_trials/enemy_slime/A_azovya_s2000.png out=res://assets/enemies/enemy_slime.png
##   tolerance … 外周のうち、たどり始める点の色の近さ（0〜1。省略時 0.12）
##   height    … 仕上がりの高さ（px。省略時は元の大きさ。縦横の比率は保つ）
##   trim      … 透明な余白を切り落とすか（省略時 true）

## となりの点との色の差が、これ以下なら背景が続いているとみなす（グラデーションの背景をたどるため）
const STEP_TOLERANCE := 0.035
## これより色みが強い点は背景とみなさない（灰色の背景だけを消すため）
const SATURATION_LIMIT := 0.12


func _init() -> void:
	var options := {}
	for arg: String in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	if not options.has("in") or not options.has("out"):
		printerr("in= と out= を指定してください")
		quit(1)
		return
	var image := Image.load_from_file(ProjectSettings.globalize_path(options["in"]))
	if image == null:
		printerr("画像を読み込めません：%s" % options["in"])
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	var tolerance := float(options.get("tolerance", "0.12"))
	remove_background(image, tolerance)
	if String(options.get("trim", "true")) == "true":
		var used := image.get_used_rect()
		if used.has_area():
			image = image.get_region(used.grow(8).intersection(Rect2i(Vector2i.ZERO, image.get_size())))
	if options.has("height"):
		var height := int(options["height"])
		image.resize(int(image.get_width() * float(height) / image.get_height()), height, Image.INTERPOLATE_LANCZOS)
	var out_path := ProjectSettings.globalize_path(options["out"])
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	if image.save_png(out_path) != OK:
		printerr("保存できません：%s" % options["out"])
		quit(1)
		return
	print("背景を透明にしました：%s（%dx%d）" % [options["out"], image.get_width(), image.get_height()])
	quit()


## 外周から、背景らしい部分（色みが少なく、となりとの色の差が小さい部分）をたどって透明にする。
## 背景が中央ほど明るい（グラデーションになっている）場合でも、少しずつ色が変わる所はたどれる。
## キャラクターの輪郭（色の差が大きい所）や、色のある部分でたどるのが止まる
static func remove_background(image: Image, tolerance: float) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var background := _border_color(image)
	var is_background := PackedByteArray()
	is_background.resize(width * height)
	var queue := PackedInt32Array()
	# 出発点：外周のうち、外周の平均の色に近い所
	for x in width:
		for y: int in [0, height - 1]:
			_seed(image, is_background, queue, x, y, width, background, tolerance)
	for y in height:
		for x: int in [0, width - 1]:
			_seed(image, is_background, queue, x, y, width, background, tolerance)
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var x := index % width
		var y := index / width
		var color := image.get_pixel(x, y)
		for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nx := x + offset.x
			var ny := y + offset.y
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			var next := ny * width + nx
			if is_background[next] == 1:
				continue
			var next_color := image.get_pixel(nx, ny)
			if _distance(next_color, color) <= STEP_TOLERANCE and _saturation(next_color) <= SATURATION_LIMIT:
				is_background[next] = 1
				queue.append(next)
	# 背景を透明に。背景ととなり合うキャラクター側の1列は半透明にして、ギザギザを目立たなくする
	for index in width * height:
		var x := index % width
		var y := index / width
		if is_background[index] == 1:
			image.set_pixel(x, y, Color(0, 0, 0, 0))
		elif _touches_background(is_background, x, y, width, height):
			var color := image.get_pixel(x, y)
			color.a = 0.6
			image.set_pixel(x, y, color)


static func _seed(image: Image, is_background: PackedByteArray, queue: PackedInt32Array, x: int, y: int, width: int, background: Color, tolerance: float) -> void:
	var index := y * width + x
	if is_background[index] == 0 and _distance(image.get_pixel(x, y), background) <= tolerance:
		is_background[index] = 1
		queue.append(index)


static func _touches_background(is_background: PackedByteArray, x: int, y: int, width: int, height: int) -> bool:
	for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var nx := x + offset.x
		var ny := y + offset.y
		if nx >= 0 and ny >= 0 and nx < width and ny < height and is_background[ny * width + nx] == 1:
			return true
	return false


## 色みの強さ（0＝灰色）
static func _saturation(color: Color) -> float:
	return maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b))


## 外周の色の平均（背景の色とみなす）
static func _border_color(image: Image) -> Color:
	var total := Color(0, 0, 0, 0)
	var count := 0
	var width := image.get_width()
	var height := image.get_height()
	for x in range(0, width, 4):
		total += image.get_pixel(x, 0) + image.get_pixel(x, height - 1)
		count += 2
	for y in range(0, height, 4):
		total += image.get_pixel(0, y) + image.get_pixel(width - 1, y)
		count += 2
	return total / count


static func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
