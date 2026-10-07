class_name DataValidator
extends RefCounted
## データの検証。インスペクターの入力制限では防げない誤りを見つけて、エラー文の一覧を返す。
## 画面やノードには依存しない（テストからも呼べる）。

const DATA_DIR := "res://data"
const INDEX_PATH := "res://data/data_index.tres"
const LOCALIZATION_DIR := "res://localization"
## 画面の文章のキーを探すフォルダ
const UI_SOURCE_DIRS := ["res://scenes", "res://ui", "res://scripts"]
## 画面の文章のキーの接頭辞（キーを探す時に使う）
const UI_KEY_PREFIXES := ["UI", "CARD_TYPE", "RARITY", "PARAM", "MAP_NODE", "EQUIPMENT_TYPE"]


## 実際のプロジェクトのデータをすべて検証する（索引・登録漏れ・翻訳キー）
static func validate_project() -> PackedStringArray:
	var errors := PackedStringArray()
	var index := load(INDEX_PATH) as DataIndex
	if index == null:
		errors.append("索引（%s）が読み込めません" % INDEX_PATH)
		return errors
	errors.append_array(validate_index(index))
	errors.append_array(check_unregistered(index, find_tres_paths(DATA_DIR)))
	var texts := load_translation_texts(LOCALIZATION_DIR)
	errors.append_array(check_translation_keys(index, texts))
	errors.append_array(check_description_placeholders(index, texts))
	errors.append_array(check_ui_keys(find_ui_keys(UI_SOURCE_DIRS), texts))
	return errors


## 画面やスクリプトで使っている翻訳キー（UI_～ など）と、列挙型から作るキーが、翻訳ファイルにあるかを調べる
static func check_ui_keys(used_keys: PackedStringArray, texts: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var all_keys := used_keys.duplicate()
	all_keys.append_array(TextKeys.all_enum_keys())
	for key: String in all_keys:
		if not texts.has(key):
			errors.append("翻訳ファイルにないキーが使われています：%s" % key)
	return errors


## フォルダ内の .gd と .tscn から、"UI_～" のように書かれた翻訳キーを集める
static func find_ui_keys(dirs: Array) -> PackedStringArray:
	var regex := RegEx.create_from_string("\"((?:%s)_[A-Z0-9_]*[A-Z0-9])\"" % "|".join(PackedStringArray(UI_KEY_PREFIXES)))
	var found: Dictionary = {}
	for dir_path: String in dirs:
		for path: String in find_files(dir_path, PackedStringArray([".gd", ".tscn"])):
			var content := FileAccess.get_file_as_string(path)
			for match_result: RegExMatch in regex.search_all(content):
				found[match_result.get_string(1)] = true
	return PackedStringArray(found.keys())


## 索引の中身の検証（IDの重複、値の矛盾、参照の抜け）
static func validate_index(index: DataIndex) -> PackedStringArray:
	var errors := PackedStringArray()
	var hero_ids: Dictionary = {}
	for hero: HeroData in index.heroes:
		if hero != null:
			hero_ids[hero.id] = true

	errors.append_array(_check_ids("カード", index.cards))
	errors.append_array(_check_ids("主人公", index.heroes))
	errors.append_array(_check_ids("クリーチャー", index.allies))
	errors.append_array(_check_ids("敵", index.enemies))
	errors.append_array(_check_ids("装備", index.equipment))
	errors.append_array(_check_ids("イベント", index.events))
	errors.append_array(_check_ids("ダンジョン", index.dungeons))

	for card: CardData in index.cards:
		if card != null:
			errors.append_array(_check_card(card, hero_ids))
	for hero: HeroData in index.heroes:
		if hero != null:
			errors.append_array(_check_hero(hero))
	for ally: AllyData in index.allies:
		if ally != null:
			errors.append_array(_check_attack_range("クリーチャー %s" % ally.id, ally.attack_min, ally.attack_max))
	for enemy: EnemyData in index.enemies:
		if enemy != null:
			errors.append_array(_check_enemy(enemy))
	for dungeon: DungeonData in index.dungeons:
		if dungeon != null:
			errors.append_array(_check_dungeon(dungeon))
	for event: EventData in index.events:
		if event != null:
			errors.append_array(_check_event(event))
	for equipment: EquipmentData in index.equipment:
		if equipment != null:
			errors.append_array(_check_equipment(equipment))
	errors.append_array(_check_unlocks(index))
	if index.config == null:
		errors.append("ゲーム全体の設定（data/config/game_config.tres）が索引にありません")
	return errors


static func _check_equipment(equipment: EquipmentData) -> PackedStringArray:
	var errors := PackedStringArray()
	var label := "装備 %s" % equipment.id
	if equipment.modifiers.is_empty():
		errors.append("%s：効果（パラメーターの増減）がありません" % label)
	for modifier: ModifyParamEffect in equipment.modifiers:
		if modifier == null:
			errors.append("%s：空（未設定）の効果があります" % label)
		elif EquipmentData.STRONG_PARAMS.has(modifier.param) and modifier.amount > 0 \
				and equipment.rarity < GameEnums.Rarity.RARE:
			errors.append("%s：%s を上げる効果は、レア以上の装備にしか付けられません" % [label, GameEnums.Param.keys()[modifier.param]])
	return errors


## アンロックの条件（このダンジョンをクリアすると解放）に、存在するダンジョンが指定されているか
static func _check_unlocks(index: DataIndex) -> PackedStringArray:
	var errors := PackedStringArray()
	var dungeon_ids: Dictionary = {}
	for dungeon: DungeonData in index.dungeons:
		if dungeon != null:
			dungeon_ids[dungeon.id] = true
	var items: Array = []
	items.append_array(index.heroes)
	items.append_array(index.dungeons)
	items.append_array(index.cards)
	for item: Resource in items:
		if item == null:
			continue
		var requirement: StringName = item.get("unlocked_by_clearing")
		if requirement != &"" and not dungeon_ids.has(requirement):
			errors.append("%s：解放条件に存在しないダンジョンID（%s）が指定されています" % [item.get("id"), requirement])
		if item is DungeonData and requirement == item.get("id"):
			errors.append("ダンジョン %s：自分自身のクリアが解放条件になっています" % requirement)
	var has_free_hero := index.heroes.any(func(h: HeroData) -> bool: return h != null and h.unlocked_by_clearing == &"")
	var has_free_dungeon := index.dungeons.any(func(d: DungeonData) -> bool: return d != null and d.unlocked_by_clearing == &"")
	if not index.heroes.is_empty() and not has_free_hero:
		errors.append("最初から使える主人公が1人もいません")
	if not index.dungeons.is_empty() and not has_free_dungeon:
		errors.append("最初から選べるダンジョンが1つもありません")
	return errors


## データフォルダにある .tres のうち、索引に載っていないものを見つける
static func check_unregistered(index: DataIndex, tres_paths: PackedStringArray) -> PackedStringArray:
	var errors := PackedStringArray()
	var registered: Dictionary = {}
	if index.config != null:
		registered[index.config.resource_path] = true
	for list: Array in _all_lists(index):
		for item: Resource in list:
			if item != null:
				registered[item.resource_path] = true
	for path: String in tres_paths:
		if path.get_file() == INDEX_PATH.get_file():
			continue
		if not registered.has(path):
			errors.append("索引に登録されていないデータがあります：%s" % path)
	return errors


## データが使っている翻訳キーのうち、翻訳ファイルにないものを見つける
static func check_translation_keys(index: DataIndex, keys: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for entry: Array in _collect_translation_keys(index):
		var key: StringName = entry[1]
		if key == &"":
			errors.append("%s：翻訳キーが空です" % entry[0])
		elif not keys.has(String(key)):
			errors.append("%s：翻訳ファイルにないキー %s" % [entry[0], key])
	return errors


## カードの説明文にある差し込みの目印（{damage} など）が、カードの効果の値で埋まるかを調べる
## texts は「キー → 文章」
static func check_description_placeholders(index: DataIndex, texts: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var regex := RegEx.create_from_string("\\{(\\w+)\\}")
	for card: CardData in index.cards:
		if card == null or not texts.has(String(card.description_key)):
			continue
		var params := card.get_text_params()
		for found: RegExMatch in regex.search_all(str(texts[String(card.description_key)])):
			var placeholder := found.get_string(1)
			if not params.has(placeholder):
				errors.append("カード %s：説明文の {%s} に入れる値がありません（対応する効果がない）" % [card.id, placeholder])
	return errors


## localization/ 内の CSV から、キーと文章（最初の言語の列）を集める（キー → 文章）
static func load_translation_texts(dir_path: String) -> Dictionary:
	var keys: Dictionary = {}
	for file_name: String in DirAccess.get_files_at(dir_path):
		if not file_name.ends_with(".csv"):
			continue
		var file := FileAccess.open(dir_path.path_join(file_name), FileAccess.READ)
		if file == null:
			continue
		var first_line := true
		while not file.eof_reached():
			var row := file.get_csv_line()
			if first_line:
				first_line = false
				continue
			if row.size() > 0 and row[0] != "":
				keys[row[0]] = row[1] if row.size() > 1 else ""
	return keys


## フォルダ内の .tres を再帰的に集める
static func find_tres_paths(dir_path: String) -> PackedStringArray:
	return find_files(dir_path, PackedStringArray([".tres"]))


## フォルダ内の、指定した拡張子のファイルを再帰的に集める
static func find_files(dir_path: String, extensions: PackedStringArray) -> PackedStringArray:
	var paths := PackedStringArray()
	for file_name: String in DirAccess.get_files_at(dir_path):
		for extension: String in extensions:
			if file_name.ends_with(extension):
				paths.append(dir_path.path_join(file_name))
				break
	for sub_dir: String in DirAccess.get_directories_at(dir_path):
		paths.append_array(find_files(dir_path.path_join(sub_dir), extensions))
	return paths


static func _all_lists(index: DataIndex) -> Array[Array]:
	return [index.cards, index.heroes, index.allies, index.enemies, index.equipment, index.events, index.dungeons]


static func _check_ids(label: String, items: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for item: Resource in items:
		if item == null:
			errors.append("%s：空（未設定）の項目があります" % label)
			continue
		var id: StringName = item.get("id")
		if id == &"":
			errors.append("%s：IDが空のデータがあります（%s）" % [label, item.resource_path])
		elif seen.has(id):
			errors.append("%s：IDが重複しています（%s）" % [label, id])
		seen[id] = true
	return errors


static func _check_attack_range(label: String, attack_min: int, attack_max: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if attack_min > attack_max:
		errors.append("%s：攻撃力最少値（%d）が最大値（%d）を上回っています" % [label, attack_min, attack_max])
	return errors


static func _check_card(card: CardData, hero_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var label := "カード %s" % card.id
	if card.usable_heroes.is_empty():
		errors.append("%s：利用キャラクターが1人も指定されていません" % label)
	for hero_id: StringName in card.usable_heroes:
		if not hero_ids.has(hero_id):
			errors.append("%s：存在しない主人公IDが利用キャラクターに指定されています（%s）" % [label, hero_id])
	if card.targets.is_empty():
		errors.append("%s：ターゲットが指定されていません" % label)
	var single_choice_count := 0
	for single_type: GameEnums.Target in [GameEnums.Target.ENEMY, GameEnums.Target.ALLY, GameEnums.Target.ANY]:
		if card.targets.has(single_type):
			single_choice_count += 1
	if single_choice_count > 1:
		errors.append("%s：1体を選ぶターゲット（敵・自分のクリーチャー・いずれか1体）は、1枚のカードに1つまでです" % label)
	if card.duration == GameEnums.Duration.TURNS and card.duration_turns < 1:
		errors.append("%s：効果ターン数が「〇〇ターン」なのに、ターン数が0です" % label)
	var summon_count := 0
	for effect: EffectData in card.effects:
		if effect == null:
			errors.append("%s：空（未設定）の効果があります" % label)
		elif effect is SummonEffect:
			summon_count += 1
			if (effect as SummonEffect).ally == null:
				errors.append("%s：召喚効果に仲間が設定されていません" % label)
		elif effect is ModifyParamEffect and card.duration == GameEnums.Duration.INSTANT:
			errors.append("%s：パラメーター変更の効果は、効果ターン数が「瞬間」のカードには使えません" % label)
	if summon_count > 1:
		errors.append("%s：召喚効果は1枚のカードに1つまでです" % label)
	return errors


static func _check_hero(hero: HeroData) -> PackedStringArray:
	var errors := PackedStringArray()
	var label := "主人公 %s" % hero.id
	if hero.hp > hero.max_hp:
		errors.append("%s：初期HP（%d）が最大HP（%d）を上回っています" % [label, hero.hp, hero.max_hp])
	if hero.starting_deck.is_empty():
		errors.append("%s：初期デッキが空です" % label)
	for card: CardData in hero.starting_deck:
		if card == null:
			errors.append("%s：初期デッキに空（未設定）のカードがあります" % label)
		elif not card.usable_heroes.has(hero.id):
			errors.append("%s：初期デッキに、自分が使えないカード（%s）があります" % [label, card.id])
	return errors


static func _check_enemy(enemy: EnemyData) -> PackedStringArray:
	var errors := _check_attack_range("敵 %s" % enemy.id, enemy.attack_min, enemy.attack_max)
	var label := "敵 %s" % enemy.id
	if enemy.pattern.is_empty():
		errors.append("%s：行動パターンが空です" % label)
	for action: EnemyActionData in enemy.pattern:
		if action == null:
			errors.append("%s：行動パターンに空（未設定）の項目があります" % label)
		elif action.action_type == GameEnums.EnemyActionType.SUMMON and action.summon_enemy == null:
			errors.append("%s：「クリーチャーを呼ぶ」行動に呼ぶ敵が設定されていません" % label)
	return errors


static func _check_dungeon(dungeon: DungeonData) -> PackedStringArray:
	var errors := PackedStringArray()
	var label := "ダンジョン %s" % dungeon.id
	if dungeon.boss == null:
		errors.append("%s：ボスが設定されていません" % label)
	if dungeon.normal_enemies.is_empty():
		errors.append("%s：通常戦の敵が1体も設定されていません" % label)
	if dungeon.battle_weight + dungeon.event_weight + dungeon.rest_weight <= 0:
		errors.append("%s：ノードの出やすさ（重み）がすべて0です" % label)
	if dungeon.event_weight > 0 and dungeon.events.is_empty():
		errors.append("%s：イベントの出やすさが0より大きいのに、イベントが登録されていません" % label)
	if dungeon.elite_weight > 0 and dungeon.elite_enemies.is_empty():
		errors.append("%s：エリートの出やすさが0より大きいのに、エリートの敵が登録されていません" % label)
	for event: EventData in dungeon.events:
		if event == null:
			errors.append("%s：イベントに空（未設定）の項目があります" % label)
	for enemy: EnemyData in dungeon.elite_enemies:
		if enemy == null:
			errors.append("%s：エリートの敵に空（未設定）の項目があります" % label)
	return errors


static func _check_event(event: EventData) -> PackedStringArray:
	var errors := PackedStringArray()
	var label := "イベント %s" % event.id
	if event.choices.is_empty():
		errors.append("%s：選択肢がありません" % label)
	for choice: EventChoiceData in event.choices:
		if choice == null:
			errors.append("%s：空（未設定）の選択肢があります" % label)
			continue
		for outcome: EventOutcome in choice.outcomes:
			if outcome == null:
				errors.append("%s：選択肢の結果に空（未設定）の項目があります" % label)
	return errors


## 翻訳キーを使っている箇所を集める（[説明, キー] の組の一覧）
static func _collect_translation_keys(index: DataIndex) -> Array[Array]:
	var result: Array[Array] = []
	for card: CardData in index.cards:
		if card != null:
			result.append(["カード %s の名前" % card.id, card.name_key])
			result.append(["カード %s の説明" % card.id, card.description_key])
	for hero: HeroData in index.heroes:
		if hero != null:
			result.append(["主人公 %s の名前" % hero.id, hero.name_key])
	for ally: AllyData in index.allies:
		if ally != null:
			result.append(["クリーチャー %s の名前" % ally.id, ally.name_key])
	for enemy: EnemyData in index.enemies:
		if enemy != null:
			result.append(["敵 %s の名前" % enemy.id, enemy.name_key])
	for equipment: EquipmentData in index.equipment:
		if equipment != null:
			result.append(["装備 %s の名前" % equipment.id, equipment.name_key])
			if equipment.description_key != &"":  # 装備の説明文は任意
				result.append(["装備 %s の説明" % equipment.id, equipment.description_key])
	for event: EventData in index.events:
		if event != null:
			result.append(["イベント %s の名前" % event.id, event.name_key])
			result.append(["イベント %s の説明" % event.id, event.description_key])
			for choice: EventChoiceData in event.choices:
				if choice != null:
					result.append(["イベント %s の選択肢" % event.id, choice.text_key])
					result.append(["イベント %s の結果" % event.id, choice.result_key])
	for dungeon: DungeonData in index.dungeons:
		if dungeon != null:
			result.append(["ダンジョン %s の名前" % dungeon.id, dungeon.name_key])
	return result
