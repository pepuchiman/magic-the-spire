extends Node
## 全体の管理（自動で読み込まれ、どこからでも Game.～ で使える）
## ・現在のラン（RunState）を持つ
## ・画面の切り替えをまとめて行う（「次にどの画面へ進むか」は、ここだけで決める）

## 画面の切り替えを頼まれた時（テストで、どの画面に進んだかを確かめるのに使う）
signal screen_requested(screen: Screen)

enum Screen { TITLE, DUNGEON_SELECT, HERO_SELECT, MAP, BATTLE, REWARD, REST, EVENT, GAME_OVER, CLEAR }

const SCENE_PATHS := {
	Screen.TITLE: "res://scenes/title/title_screen.tscn",
	Screen.DUNGEON_SELECT: "res://scenes/dungeon_select/dungeon_select_screen.tscn",
	Screen.HERO_SELECT: "res://scenes/hero_select/hero_select_screen.tscn",
	Screen.MAP: "res://scenes/map/map_screen.tscn",
	Screen.BATTLE: "res://scenes/battle/battle_screen.tscn",
	Screen.REWARD: "res://scenes/reward/reward_screen.tscn",
	Screen.REST: "res://scenes/rest/rest_screen.tscn",
	Screen.EVENT: "res://scenes/event/event_screen.tscn",
	Screen.GAME_OVER: "res://scenes/run_end/run_end_screen.tscn",
	Screen.CLEAR: "res://scenes/run_end/run_end_screen.tscn",
}

## すべてのデータ
var data: DataLoader
## 現在のラン（タイトル画面などでは null）
var run: RunState
## ダンジョン選択画面で選んだダンジョン
var selected_dungeon: DungeonData
## 今の画面
var current_screen: Screen = Screen.TITLE
## false にすると、画面を実際には切り替えない（テスト用）
var change_scenes: bool = true


func _ready() -> void:
	data = DataLoader.new()


func _process(delta: float) -> void:
	if run != null and not run.finished:
		run.play_seconds += delta


func go_to(screen: Screen) -> void:
	current_screen = screen
	screen_requested.emit(screen)
	if change_scenes:
		get_tree().change_scene_to_file(SCENE_PATHS[screen])


func go_to_title() -> void:
	run = null
	go_to(Screen.TITLE)


func select_dungeon(dungeon: DungeonData) -> void:
	selected_dungeon = dungeon
	go_to(Screen.HERO_SELECT)


## 新しいランを始める（seed_value が 0 なら毎回ちがうシードにする）
func start_run(hero: HeroData, seed_value: int = 0) -> void:
	var used_seed := seed_value if seed_value != 0 else randi()
	run = RunState.new(hero, selected_dungeon, data.index.cards, data.get_config(), used_seed)
	go_to(Screen.MAP)


## マップのノードへ進み、その種類に合った画面へ切り替える。進めなければ false
func enter_node(node: MapNode) -> bool:
	if run == null or not run.move_to(node):
		return false
	match node.type:
		GameEnums.MapNodeType.EVENT:
			go_to(Screen.EVENT)
		GameEnums.MapNodeType.REST:
			go_to(Screen.REST)
		_:
			go_to(Screen.BATTLE)
	return true


## バトルが終わった時。敗北 → ゲームオーバー、ボスに勝利 → クリア、それ以外 → 報酬
func finish_battle(result: BattleResult) -> void:
	run.apply_battle_result(result)
	if not run.finished:
		go_to(Screen.REWARD)
	elif run.cleared:
		go_to(Screen.CLEAR)
	else:
		go_to(Screen.GAME_OVER)


## 報酬・休憩・イベントが終わった時（マップへ戻る）
func finish_node() -> void:
	go_to(Screen.MAP)
