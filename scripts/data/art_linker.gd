class_name ArtLinker
extends RefCounted
## assets/ に置いた画像を、ファイル名でデータ（カード・敵など）の絵の項目に結び付ける。
## 名前の決まり（<ID> はデータのID。拡張子は png・webp・jpg のどれか）：
##   カード        assets/cards/card_<ID>.png              → CardData.art
##   主人公        assets/player/hero_<ID>_front.png        → HeroData.art_front
##                 assets/player/hero_<ID>_back.png         → HeroData.art_back
##   クリーチャー  assets/creatures/creature_<ID>_back.png  → AllyData.art_back
##   敵            assets/enemies/enemy_<ID>.png            → EnemyData.art_front
##   装備          assets/icons/equip_<ID>.png              → EquipmentData.icon
##   ダンジョン    assets/backgrounds/bg_<ID>.png           → DungeonData.background
##   アイコン      assets/icons/status_<種類>.png、map_<種類>.png、equip_type_<種類>.png
##                 （<種類> は英小文字。例：status_poison.png、map_rest.png、equip_type_ring.png）
## 画像が無いデータは何もしない（インスペクターで設定した絵も消さない）

const ASSETS_DIR := "res://assets"
const EXTENSIONS: Array[String] = ["png", "webp", "jpg"]


## 結び付ける組み合わせを探す。すでに同じ画像が結び付いているものは含めない。
## 結果の1件：{"resource": データ, "field": 項目名, "key": アイコンの種類（アイコン以外は null）, "path": 画像の場所}
static func find_links(index: DataIndex, assets_dir: String = ASSETS_DIR) -> Array[Dictionary]:
	var links: Array[Dictionary] = []
	for card: CardData in index.cards:
		_add(links, card, "art", null, _find(assets_dir, "cards", "card_%s" % card.id))
	for hero: HeroData in index.heroes:
		_add(links, hero, "art_front", null, _find(assets_dir, "player", "hero_%s_front" % hero.id))
		_add(links, hero, "art_back", null, _find(assets_dir, "player", "hero_%s_back" % hero.id))
	for ally: AllyData in index.allies:
		_add(links, ally, "art_back", null, _find(assets_dir, "creatures", "creature_%s_back" % ally.id))
	for enemy: EnemyData in index.enemies:
		_add(links, enemy, "art_front", null, _find(assets_dir, "enemies", "enemy_%s" % enemy.id))
	for item: EquipmentData in index.equipment:
		_add(links, item, "icon", null, _find(assets_dir, "icons", "equip_%s" % item.id))
	for dungeon: DungeonData in index.dungeons:
		_add(links, dungeon, "background", null, _find(assets_dir, "backgrounds", "bg_%s" % dungeon.id))
	if index.icons != null:
		_add_icons(links, index.icons, "status_icons", GameEnums.StatusType, "status_", assets_dir)
		_add_icons(links, index.icons, "map_node_icons", GameEnums.MapNodeType, "map_", assets_dir)
		_add_icons(links, index.icons, "equipment_type_icons", GameEnums.EquipmentType, "equip_type_", assets_dir)
	return links


## 見つけた組み合わせのとおりに、画像を読み込んで絵の項目に入れる。
## 変わったデータの一覧を返す（保存はしない。保存はツールが行う）
static func apply(links: Array[Dictionary]) -> Array[Resource]:
	var changed: Array[Resource] = []
	for link: Dictionary in links:
		var texture := load(link["path"]) as Texture2D
		if texture == null:
			push_error("画像を読み込めません（先に --import を実行してください）：%s" % link["path"])
			continue
		var resource: Resource = link["resource"]
		if link["key"] == null:
			resource.set(link["field"], texture)
		else:
			var icons: Dictionary = resource.get(link["field"])
			icons[link["key"]] = texture
		if not changed.has(resource):
			changed.append(resource)
	return changed


## アイコンの一覧の、種類ごとの画像を探す
static func _add_icons(links: Array[Dictionary], icons: IconSet, field: String, enum_dict: Dictionary, prefix: String, assets_dir: String) -> void:
	var current: Dictionary = icons.get(field)
	for type_name: String in enum_dict.keys():
		var type: int = enum_dict[type_name]
		var path := _find(assets_dir, "icons", prefix + type_name.to_lower())
		if path != "" and not _is_same(current.get(type), path):
			links.append({"resource": icons, "field": field, "key": type, "path": path})


static func _add(links: Array[Dictionary], resource: Resource, field: String, key: Variant, path: String) -> void:
	if resource == null or path == "" or _is_same(resource.get(field), path):
		return
	links.append({"resource": resource, "field": field, "key": key, "path": path})


## 今の絵が、その画像と同じか
static func _is_same(current: Variant, path: String) -> bool:
	return current is Texture2D and (current as Texture2D).resource_path == path


## フォルダの中から、名前（拡張子なし）の画像を探す。無ければ空
static func _find(assets_dir: String, folder: String, base_name: String) -> String:
	for extension: String in EXTENSIONS:
		var path := assets_dir.path_join(folder).path_join("%s.%s" % [base_name, extension])
		if FileAccess.file_exists(path):
			return path
	return ""
