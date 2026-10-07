class_name RunState
extends RefCounted
## 1回の挑戦（ラン）の状態。画面には依存しない。
## 主人公・HP・所持カード・永続の補正・マップ・現在地・シード付き乱数などを持つ

var hero: HeroData
var dungeon: DungeonData
var config: GameConfig
## このランのシード（同じシードなら同じマップ・同じ展開になる）
var run_seed: int
var rng: RandomNumberGenerator
## 報酬・イベントで出てくる可能性のあるカード（主人公が使え、解放済みのカード）
var card_pool: Array[CardData] = []
## 報酬・宝箱で出てくる可能性のある装備
var equipment_pool: Array[EquipmentData] = []
## 装備中の装備（種類 → 装備。種類ごとに1つまで）
var equipment: Dictionary = {}

var hp: int
var deck: Array[CardData] = []
## バトルをまたいで引き継ぐ「永続」の補正
var permanent_modifiers: Array[StatModifier] = []
var map: MapData
## 今いるノード（出発前は null）
var current_node: MapNode
var battles_won: int = 0
var enemies_defeated: int = 0
## プレイ時間（秒）
var play_seconds: float = 0.0
var finished: bool = false
var cleared: bool = false


## all_cards：報酬に出してよいカード（解放済みのもの。この中から主人公が使えるものだけを使う）
## all_equipment：報酬・宝箱に出してよい装備
func _init(hero_data: HeroData, dungeon_data: DungeonData, all_cards: Array[CardData], game_config: GameConfig,
		seed_value: int, all_equipment: Array[EquipmentData] = []) -> void:
	hero = hero_data
	dungeon = dungeon_data
	config = game_config
	run_seed = seed_value
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	for card: CardData in all_cards:
		if card.usable_heroes.has(hero.id):
			card_pool.append(card)
	equipment_pool = all_equipment.duplicate()
	hp = hero.hp
	deck = hero.starting_deck.duplicate()
	map = MapGenerator.generate(dungeon, rng)


func get_max_hp() -> int:
	var bonus := 0
	for modifier: StatModifier in permanent_modifiers:
		if modifier.param == GameEnums.Param.MAX_HP:
			bonus += modifier.amount
	for item: EquipmentData in equipment.values():
		bonus += item.get_amount(GameEnums.Param.MAX_HP)
	return maxi(1, hero.max_hp + bonus)


## その種類で装備している装備（無ければ null）
func get_equipped(type: GameEnums.EquipmentType) -> EquipmentData:
	return equipment.get(type)


## 装備する。同じ種類の装備をしていたら入れ替え、外した装備を返す（無ければ null）
func equip(item: EquipmentData) -> EquipmentData:
	var replaced: EquipmentData = equipment.get(item.equipment_type)
	equipment[item.equipment_type] = item
	hp = mini(hp, get_max_hp())  # 最大HPが下がった時は、HPを最大HPまでに収める
	return replaced


## 装備による補正。「バトル中」の補正としてバトルに渡すので、バトル後に引き継がれない（装備している間だけ有効）
func get_equipment_modifiers() -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	for item: EquipmentData in equipment.values():
		for modifier: ModifyParamEffect in item.modifiers:
			if modifier != null:
				result.append(StatModifier.new(modifier.param, modifier.amount, GameEnums.Duration.BATTLE))
	return result


## 今いる階（1階から数える。出発前は 0）
func current_floor_number() -> int:
	return current_node.floor_index + 1 if current_node != null else 0


## 次に進めるノード
func available_nodes() -> Array[MapNode]:
	var result: Array[MapNode] = []
	if current_node == null:
		result.assign(map.get_floor(0))
	else:
		result.assign(current_node.next)
	return result


## ノードへ進む。進めないノードなら false
func move_to(node: MapNode) -> bool:
	if not available_nodes().has(node):
		return false
	node.visited = true
	current_node = node
	return true


## 今いるノードのバトルを作る（主人公のHP・永続の補正・装備の補正を渡す）
func create_battle() -> Battle:
	var modifiers := permanent_modifiers.duplicate()
	modifiers.append_array(get_equipment_modifiers())
	return Battle.new(hero, deck, current_node.enemy, rng.randi(), hp, modifiers)


## バトルの結果を反映する。引き継ぐのは主人公のHPと「永続」の補正だけ
func apply_battle_result(result: BattleResult) -> void:
	hp = mini(result.hero_hp, get_max_hp())
	permanent_modifiers = result.permanent_modifiers.duplicate()
	enemies_defeated += result.enemies_defeated
	if result.won:
		battles_won += 1
		if current_node.type == GameEnums.MapNodeType.BOSS:
			finished = true
			cleared = true
	else:
		finished = true


## 回復（最大HPまで）。実際に回復した量を返す
func heal(amount: int) -> int:
	var before := hp
	hp = clampi(hp + amount, 0, get_max_hp())
	return hp - before


func add_card(card: CardData) -> void:
	deck.append(card)
