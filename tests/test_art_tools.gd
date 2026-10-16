extends GutTest
## 絵の生成・仕上げのツールのテスト（ComfyUI は使わない。手順のファイルと、画像の処理だけを確かめる）

const Generate := preload("res://tools/comfy_generate.gd")
const Resize := preload("res://tools/resize_image.gd")


func test_workflows_are_valid_json() -> void:
	for path: String in [Generate.WORKFLOW_PATH, Generate.WORKFLOW_BG_PATH]:
		var workflow: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_true(workflow is Dictionary, "生成の手順が読める：%s" % path)
		assert_eq(workflow[Generate.SAVE_NODE]["class_type"], "SaveImageWebsocket", "画像を受け取るノードの番号が合っている：%s" % path)


func test_background_workflow_removes_background_before_saving() -> void:
	var workflow: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Generate.WORKFLOW_BG_PATH))
	var types := {}
	for node_id: String in workflow:
		types[workflow[node_id]["class_type"]] = node_id
	for type: String in ["LoadBackgroundRemovalModel", "RemoveBackground", "InvertMask", "JoinImageWithAlpha"]:
		assert_true(types.has(type), "背景を消す手順に %s がある" % type)
	var save_input: Array = workflow[Generate.SAVE_NODE]["inputs"]["images"]
	assert_eq(save_input[0], types["JoinImageWithAlpha"], "受け取るのは透明つきの画像")


func test_background_is_removed_only_for_characters_by_default() -> void:
	assert_true(Generate.should_remove_background("enemy_slime", "auto"), "敵は背景を消す")
	assert_true(Generate.should_remove_background("hero_flame_mage_back", "auto"), "主人公は背景を消す")
	assert_true(Generate.should_remove_background("creature_forest_wolf_back", "auto"), "クリーチャーは背景を消す")
	assert_false(Generate.should_remove_background("card_fireball", "auto"), "カードは消さない")
	assert_false(Generate.should_remove_background("bg_lost_forest", "auto"), "戦闘背景は消さない")
	assert_true(Generate.should_remove_background("card_fireball", "remove"), "remove なら必ず消す")
	assert_false(Generate.should_remove_background("enemy_slime", "keep"), "keep なら消さない")


func test_trim_transparent_cuts_empty_margins() -> void:
	var image := Image.create(100, 80, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(40, 30, 20, 10), Color.RED)
	var trimmed: Image = Resize.trim_transparent(image, 4)
	assert_eq(trimmed.get_size(), Vector2i(28, 18), "絵のある部分＋余白4だけが残る")
	var empty := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	assert_eq(Resize.trim_transparent(empty).get_size(), Vector2i(10, 10), "全部透明なら、そのまま")


func test_adopt_targets_follow_naming_rules() -> void:
	var Adopt := load("res://tools/adopt_art.gd")
	var card: Dictionary = Adopt.target_for("card_spark")
	assert_eq(card["path"], "res://assets/cards/card_spark.png")
	assert_false(card["trim"], "カードは余白を切り落とさない")
	var enemy: Dictionary = Adopt.target_for("enemy_bat")
	assert_eq(enemy["path"], "res://assets/enemies/enemy_bat.png")
	assert_true(enemy["trim"], "背景を消した敵は余白を切り落とす")
	assert_eq(Adopt.target_for("creature_forest_wolf_back")["path"], "res://assets/creatures/creature_forest_wolf_back.png")
	assert_eq(Adopt.target_for("hero_frost_mage_front")["path"], "res://assets/player/hero_frost_mage_front.png")
	assert_eq(Adopt.target_for("bg_lost_forest")["path"], "res://assets/backgrounds/bg_lost_forest.png")
	assert_eq(Adopt.target_for("equip_type_ring")["path"], "res://assets/icons/equip_type_ring.png")
	assert_eq(Adopt.target_for("map_rest")["path"], "res://assets/icons/map_rest.png")
	assert_true(Adopt.target_for("unknown_x").is_empty(), "決まりにない名前は置かない")
