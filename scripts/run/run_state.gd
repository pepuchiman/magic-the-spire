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
## 報酬・イベントで出てくる可能性のあるカード（主人公が使えるカード）
var card_pool: Array[CardData] = []

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


## all_cards：ゲームにあるすべてのカード（主人公が使えるものだけを報酬に使う）
func _init(hero_data: HeroData, dungeon_data: DungeonData, all_cards: Array[CardData], game_config: GameConfig, seed_value: int) -> void:
	hero = hero_data
	dungeon = dungeon_data
	config = game_config
	run_seed = seed_value
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	for card: CardData in all_cards:
		if card.usable_heroes.has(hero.id):
			card_pool.append(card)
	hp = hero.hp
	deck = hero.starting_deck.duplicate()
	map = MapGenerator.generate(dungeon, rng)


func get_max_hp() -> int:
	var bonus := 0
	for modifier: StatModifier in permanent_modifiers:
		if modifier.param == GameEnums.Param.MAX_HP:
			bonus += modifier.amount
	return maxi(1, hero.max_hp + bonus)


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


## 今いるノードのバトルを作る（主人公のHPと永続の補正を引き継ぐ）
func create_battle() -> Battle:
	return Battle.new(hero, deck, current_node.enemy, rng.randi(), hp, permanent_modifiers)


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
