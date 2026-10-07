extends GutTest
## 画面の切り替え（Game）と、各画面を通した1周のテスト。
## 実際には画面を切り替えず（change_scenes = false）、進むべき画面を確かめて、その画面を読み込んで操作する

const Screen := preload("res://scripts/autoload/game.gd").Screen


func before_each() -> void:
	TranslationServer.set_locale("ja")
	Game.change_scenes = false
	Game.run = null
	Game.current_screen = Screen.TITLE
	Game.selected_dungeon = Game.data.get_dungeon(&"lost_forest")


func after_each() -> void:
	Game.run = null
	Game.current_screen = Screen.TITLE
	Game.change_scenes = true


func _start(seed_value: int = 3) -> void:
	Game.start_run(Game.data.get_hero(&"flame_mage"), seed_value)


# ---------- 画面の切り替え ----------

func test_title_to_hero_select() -> void:
	var title: Control = _open("res://scenes/title/title_screen.tscn")
	title.get_node("%NewGameButton").pressed.emit()
	assert_eq(Game.current_screen, Screen.DUNGEON_SELECT, "はじめから → ダンジョン選択")
	var dungeon_select: Control = _open(Game.SCENE_PATHS[Screen.DUNGEON_SELECT])
	dungeon_select.confirm()
	assert_eq(Game.current_screen, Screen.HERO_SELECT, "決定 → 主人公選択")
	var hero_select: Control = _open(Game.SCENE_PATHS[Screen.HERO_SELECT])
	hero_select.confirm()
	assert_eq(Game.current_screen, Screen.MAP, "決定 → マップ")
	assert_not_null(Game.run, "ランが始まる")


func test_node_types_lead_to_screens() -> void:
	_start()
	var first: MapNode = Game.run.available_nodes()[0]
	assert_true(Game.enter_node(first))
	assert_eq(Game.current_screen, Screen.BATTLE, "1階は通常戦 → バトル画面")
	var rest := MapNode.new(GameEnums.MapNodeType.REST, 1, 0)
	first.next.append(rest)
	Game.enter_node(rest)
	assert_eq(Game.current_screen, Screen.REST, "休憩 → 休憩画面")


func test_cannot_enter_unconnected_node() -> void:
	_start()
	assert_false(Game.enter_node(Game.run.map.get_floor(3)[0]), "つながっていないノードには進めない")
	assert_eq(Game.current_screen, Screen.MAP)


func test_battle_results_lead_to_screens() -> void:
	_start()
	Game.enter_node(Game.run.available_nodes()[0])
	Game.finish_battle(BattleResult.new(true, 15, [], 3, 1))
	assert_eq(Game.current_screen, Screen.REWARD, "勝利 → 報酬")
	Game.finish_battle(BattleResult.new(false, 0, [], 3))
	assert_eq(Game.current_screen, Screen.GAME_OVER, "敗北 → ゲームオーバー")


func test_boss_victory_leads_to_clear() -> void:
	_start()
	Game.run.current_node = Game.run.map.get_floor(Game.run.map.floor_count() - 1)[0]
	Game.finish_battle(BattleResult.new(true, 10, [], 5, 1))
	assert_eq(Game.current_screen, Screen.CLEAR, "ボスに勝利 → クリア")


# ---------- 各画面を通した1周 ----------

func test_full_run_through_screens() -> void:
	_start(5)
	var visited_screens := {}
	for step in 400:
		var screen := Game.current_screen
		visited_screens[screen] = true
		if screen == Screen.GAME_OVER or screen == Screen.CLEAR:
			break
		var node: Control = _open(Game.SCENE_PATHS[screen], screen == Screen.BATTLE)
		_assert_no_raw_keys(node)
		match screen:
			Screen.MAP:
				node.select_node(Game.run.available_nodes()[0])
				node.proceed()
			Screen.BATTLE:
				_play_battle(node as BattleScreen)
			Screen.REWARD:
				if node.choices.is_empty():
					node.skip()
				else:
					node.take(node.choices[0])
			Screen.REST:
				node.heal()
				Game.finish_node()
			Screen.EVENT:
				var choice: EventChoiceData = node.event.choices[0]
				node.choose(choice)
				if EventResolver.needs_card_choice(choice):
					node._card_popup.select(0)
					node._card_popup.confirm()
				Game.finish_node()
		node.free()
	assert_true(Game.current_screen == Screen.GAME_OVER or Game.current_screen == Screen.CLEAR, "クリアかゲームオーバーまで進む")
	assert_true(visited_screens.has(Screen.REWARD), "報酬画面を通った")
	var end_screen: Control = _open(Game.SCENE_PATHS[Game.current_screen])
	assert_ne(end_screen.get_node("%DetailsLabel").text, "", "結果が表示される")
	end_screen.free()


## 画面の中に、翻訳されずにキーのまま表示されている文字（例：UI_REST_DESC）がないか調べる
func _assert_no_raw_keys(root: Node) -> void:
	var key_pattern := RegEx.create_from_string("^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$")
	var nodes: Array[Node] = [root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		nodes.append_array(node.get_children())
		if not (node is Label or node is Button):
			continue
		var shown: String = node.atr(node.text)
		assert_null(key_pattern.search(shown), "キーのまま表示されている：%s（%s）" % [shown, node.get_path()])
func _open(path: String, is_battle: bool = false) -> Control:
	var node: Control = load(path).instantiate()
	if is_battle:
		node.animation_speed = 0.0
	add_child_autofree(node)
	return node


## バトル画面で、使えるカードを使い、なくなったらターン終了、を勝敗がつくまで繰り返す
func _play_battle(screen: BattleScreen) -> void:
	for step in 500:
		if screen.mode == BattleScreen.Mode.ENDED:
			break
		if screen.mode == BattleScreen.Mode.DISCARD_SELECT:
			for i in screen.battle.pending_discard_count:
				screen.toggle_discard(i)
			screen.confirm_discard()
			continue
		if not _play_any_card(screen):
			screen.request_end_turn()
	screen._on_result_closed()


func _play_any_card(screen: BattleScreen) -> bool:
	var battle := screen.battle
	for i in battle.deck.hand.size():
		var card: CardData = battle.deck.hand[i].data
		if battle.get_cost_problem(card) != Battle.PlayResult.OK:
			continue
		var result := screen.try_play_card(i, AutoPlayer.choose_target(battle, card))
		if result == Battle.PlayResult.NEEDS_REPLACE:
			screen.choose_replace(battle.allies[0])
			return true
		if result == Battle.PlayResult.OK:
			return true
	return false
