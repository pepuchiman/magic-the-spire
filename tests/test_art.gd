extends GutTest
## 絵の差し替え口（画像の結び付け・図形の仮表示・検証）のテスト。
## 画像のファイルは user:// の一時フォルダに作り、終わったら消す（assets/ と data/ は変更しない）

const H := preload("res://tests/battle_test_helper.gd")
const TEMP_DIR := "user://test_art_assets"
const CARD_SCENE := preload("res://ui/card_view.tscn")
const SPRITE_SCENE := preload("res://ui/unit_sprite.tscn")


func before_each() -> void:
	TranslationServer.set_locale("ja")
	_remove_temp()


func after_each() -> void:
	_remove_temp()


# ---------- 画像の結び付け ----------

func test_find_links_matches_file_names() -> void:
	var index := _index()
	_touch("cards/card_strike.png")
	_touch("enemies/enemy_slime.webp")
	_touch("player/hero_mage_back.png")
	_touch("icons/status_poison.png")
	_touch("icons/map_rest.png")
	_touch("cards/card_unknown.png")  # どのカードにも当てはまらない
	var links := ArtLinker.find_links(index, TEMP_DIR)
	var found := {}
	for link: Dictionary in links:
		found["%s.%s" % [link["resource"].get("id") if link["key"] == null else "icons", link["field"]]] = link["path"]
	assert_eq(found.get("strike.art"), TEMP_DIR + "/cards/card_strike.png", "カードの絵はIDの名前の画像")
	assert_eq(found.get("slime.art_front"), TEMP_DIR + "/enemies/enemy_slime.webp", "webp の画像も使える")
	assert_eq(found.get("mage.art_back"), TEMP_DIR + "/player/hero_mage_back.png", "主人公の背中の絵")
	assert_false(found.has("mage.art_front"), "画像がなければ結び付けない")
	assert_false(found.has("guard.art"), "画像がないカードは結び付けない")
	assert_true(found.has("icons.status_icons"), "状態効果のアイコン")
	assert_true(found.has("icons.map_node_icons"), "マップのマスのアイコン")
	assert_eq(links.size(), 5, "当てはまらない画像は無視する")


func test_apply_sets_only_the_art_field() -> void:
	var index := _index()
	var card: CardData = index.cards[0]
	card.cost_mana = 3
	var path := _save_texture("tex.tres")
	var links: Array[Dictionary] = [
		{"resource": card, "field": "art", "key": null, "path": path},
		{"resource": index.icons, "field": "status_icons", "key": GameEnums.StatusType.POISON, "path": path},
	]
	var changed := ArtLinker.apply(links)
	assert_eq(changed.size(), 2, "変わったデータを返す")
	assert_eq(card.art.resource_path, path, "絵の項目に画像が入る")
	assert_eq(card.cost_mana, 3, "ほかの項目は変わらない")
	assert_eq(index.icons.status_icons[GameEnums.StatusType.POISON].resource_path, path, "アイコンの一覧にも入る")
	_touch("cards/card_strike.tres")
	assert_eq(ArtLinker.find_links(index, TEMP_DIR).size(), 0, "画像の形式でないファイルは使わない")


func test_same_image_is_not_linked_again() -> void:
	var index := _index()
	var card: CardData = index.cards[0]
	_touch("cards/card_strike.png")
	card.art = ImageTexture.new()
	card.art.resource_path = TEMP_DIR + "/cards/card_strike.png"
	assert_eq(ArtLinker.find_links(index, TEMP_DIR).size(), 0, "すでに同じ画像なら何もしない")


# ---------- 検証 ----------

func test_missing_icon_type_is_reported() -> void:
	var icons := IconSet.create_default()
	icons.status_icons.erase(GameEnums.StatusType.THORNS)
	var errors := DataValidator._check_icons(icons)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "THORNS")
	assert_eq(DataValidator._check_icons(IconSet.create_default()).size(), 0, "全種類があれば問題なし（画像は空でよい）")


func test_missing_art_file_is_reported() -> void:
	var index := _index()
	var texture := ImageTexture.new()
	texture.resource_path = "res://assets/cards/card_not_exist.png"
	index.cards[0].art = texture
	var errors := DataValidator._check_art(index)
	assert_eq(errors.size(), 1, "画像のファイルがない絵は検証エラー")


# ---------- 表示 ----------

func test_card_view_shows_symbol_until_art_is_set() -> void:
	var card := H.damage_card(&"strike", 3)
	var view: CardView = CARD_SCENE.instantiate()
	add_child_autofree(view)
	view.set_card(card)
	assert_true(view.get_node("%Symbol").visible, "絵がなければ種別の記号を出す")
	assert_eq(view.get_node("%Symbol").shape, &"flame", "攻撃魔法の記号は炎")
	card.art = ImageTexture.new()
	view.refresh()
	assert_false(view.get_node("%Symbol").visible, "絵があれば記号は出さない")
	assert_eq(view.get_node("%Art").texture, card.art)


func test_unit_sprite_uses_art_for_its_facing() -> void:
	var hero_data := H.hero([])
	hero_data.art_back = ImageTexture.new()
	var battle := H.battle(hero_data, H.enemy())
	var sprite: UnitSprite = SPRITE_SCENE.instantiate()
	add_child_autofree(sprite)
	sprite.setup(battle.hero, UnitFigure.Facing.BACK, false)
	assert_eq(sprite.get_node("%Art").texture, hero_data.art_back, "背中向きなら背中の絵")
	assert_false(sprite.get_node("%Figure").draw_shape, "絵があれば図形は描かない")
	sprite.setup(battle.hero, UnitFigure.Facing.FRONT, false)
	assert_null(sprite.get_node("%Art").texture, "正面の絵がなければ図形")
	assert_true(sprite.get_node("%Figure").draw_shape)
	assert_eq(sprite.get_node("%Figure").kind, UnitFigure.Kind.WIZARD, "主人公は魔法使いの形")


func test_status_row_lists_statuses_with_marks() -> void:
	var battle := H.battle(H.hero([]), H.enemy())
	var enemy := battle.main_enemy
	enemy.add_status(GameEnums.StatusType.POISON, 5, 0, false)
	var row := StatusRow.new()
	add_child_autofree(row)
	row.show_combatant(enemy, 3)
	assert_eq(row.texts, PackedStringArray(["アーマー 3", "毒 5"]), "アーマーと状態効果を並べる")
	assert_eq(row.get_child_count(), 2)
	var icon: ShapeIcon = row.get_child(1).get_child(0)
	assert_eq(icon.shape, &"drop", "毒の印はしずく")
	row.show_combatant(enemy)
	assert_eq(row.texts, PackedStringArray(["毒 5"]), "アーマーを渡さなければ状態効果だけ")


# ---------- 準備 ----------

func _index() -> DataIndex:
	var index := DataIndex.new()
	var strike := H.damage_card(&"strike", 3)
	var guard := H.armor_card(&"guard", 3)
	index.cards.assign([strike, guard])
	var hero := H.hero([])
	hero.id = &"mage"
	index.heroes.assign([hero])
	var slime := H.enemy()
	slime.id = &"slime"
	index.enemies.assign([slime])
	index.icons = IconSet.create_default()
	return index


## 一時フォルダに空のファイルを作る（名前で探すテストに使う）
func _touch(relative: String) -> void:
	var path := TEMP_DIR.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).close()


## 一時フォルダに、読み込める画像（小さなテクスチャ）を保存して、その場所を返す
func _save_texture(file_name: String) -> String:
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	var path := TEMP_DIR.path_join(file_name)
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	ResourceSaver.save(ImageTexture.create_from_image(image), path)
	return path


func _remove_temp() -> void:
	_remove_dir(TEMP_DIR)


func _remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub: String in DirAccess.get_directories_at(path):
		_remove_dir(path.path_join(sub))
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
