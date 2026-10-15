extends SceneTree
## 画像を縮小して保存するツール（生成した絵を、ゲームで使う大きさにして assets/ に置く時に使う）。
## 縦横の比率は保つ。trim=true にすると、透明な余白を切り落としてから縮小する（背景を消した絵に使う）。
## 実行：godot --headless -s tools/resize_image.gd -- in=res://art_trials/card_fireball/A_azovya_s3000.png out=res://assets/cards/card_fireball.png height=512
##        godot --headless -s tools/resize_image.gd -- in=res://art_trials/enemy_slime/A_azovya_s4003_bg.png out=res://assets/enemies/enemy_slime.png height=640 trim=true


func _init() -> void:
	var options := {}
	for arg: String in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	if not options.has("in") or not options.has("out") or not options.has("height"):
		printerr("in=、out=、height= を指定してください")
		quit(1)
		return
	var image := Image.load_from_file(ProjectSettings.globalize_path(options["in"]))
	if image == null:
		printerr("画像を読み込めません：%s" % options["in"])
		quit(1)
		return
	if String(options.get("trim", "false")) == "true":
		image = trim_transparent(image)
	var height := int(options["height"])
	image.resize(int(image.get_width() * float(height) / image.get_height()), height, Image.INTERPOLATE_LANCZOS)
	var out_path := ProjectSettings.globalize_path(options["out"])
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	if image.save_png(out_path) != OK:
		printerr("保存できません：%s" % options["out"])
		quit(1)
		return
	print("保存しました：%s（%dx%d）" % [options["out"], image.get_width(), image.get_height()])
	quit()


## 透明な余白を切り落とす（少しだけ余白を残す）。全部透明なら、そのまま返す
static func trim_transparent(image: Image, padding: int = 8) -> Image:
	image.convert(Image.FORMAT_RGBA8)
	var used := image.get_used_rect()
	if not used.has_area():
		return image
	return image.get_region(used.grow(padding).intersection(Rect2i(Vector2i.ZERO, image.get_size())))
