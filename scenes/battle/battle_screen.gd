class_name BattleScreen
extends Control
## バトル画面の進行役。
## ルール（Battle）の状態を表示し、プレイヤーの操作を Battle に伝える。
## Battle は処理を一瞬で終えるので、起きたこと（シグナル）を「演出の待ち行列」に並べ、1つずつ見せる。
## テストからも操作できるよう、操作は関数（try_play_card、request_end_turn など）にまとめている。

## 演出の待ち行列が空になった時
signal animations_finished

## 画面の操作の状態
enum Mode {
	NORMAL,  ## 通常（カードを使える）
	DISCARD_SELECT,  ## 捨てるカードを選んでいる
	REPLACE_SELECT,  ## 入れ替える仲間を選んでいる
	ENDED,  ## バトル終了
}

const UNIT_SCENE := preload("res://ui/unit_view.tscn")
const CARD_SCENE := preload("res://ui/card_view.tscn")
## これ以上指が動いたらドラッグとみなす（それ未満で離したらタップ）
const DRAG_THRESHOLD := 16.0
const HERO_WIDTH := 170.0
const MAIN_ENEMY_WIDTH := 220.0
const UNIT_WIDTH := 140.0
## 演出1つ分の基本の長さ（秒）
const STEP_TIME := 0.45

@export_group("サンプル戦の設定（この画面だけをエディタで実行した時に使う）")
@export var hero_id: StringName = &"flame_mage"
@export var enemy_id: StringName = &"boss_witch"
@export var dungeon_id: StringName = &"lost_forest"
@export_range(1, 99) var floor_number: int = 1
## 乱数のシード（0 なら毎回ちがうシードにする）
@export var seed_value: int = 0

@export_group("開発用")
## 演出の速さ（1.0 が標準。0 にすると演出を待たずに進む。テスト用）
@export_range(0.0, 3.0, 0.1) var animation_speed: float = 1.0
## オンにすると、文章の代わりに翻訳キーの名前を表示する（長い文章で崩れないかの確認用）
@export var debug_show_keys: bool = false
## オフにすると、画面を開いても自動でバトルを始めない（テスト用）
@export var auto_start: bool = true

var battle: Battle
var mode: Mode = Mode.NORMAL

var _views: Dictionary = {}  # Combatant → UnitView
var _events: Array[Dictionary] = []
var _playing_events: bool = false
var _discard_selection: Array[int] = []
## 入れ替え選択中の召喚カード（手札の位置）
var _pending_summon_index: int = -1
## ドラッグ中の情報（view、start、moved）
var _drag: Dictionary = {}
var _drag_ghost: CardView
var _drag_target: UnitView
var _toast_tween: Tween

@onready var _header: PanelContainer = %Header
@onready var _dungeon_label: FitLabel = %DungeonLabel
@onready var _floor_label: FitLabel = %FloorLabel
@onready var _settings_button: Button = %SettingsButton
@onready var _enemy_area: HBoxContainer = %EnemyArea
@onready var _hero_holder: HBoxContainer = %HeroHolder
@onready var _ally_row: HBoxContainer = %AllyRow
@onready var _status_bar: PanelContainer = %StatusBar
@onready var _catalyst_labels: Array[FitLabel] = [%CatalystRedLabel, %CatalystBlueLabel, %CatalystGreenLabel]
@onready var _deck_button: Button = %DeckButton
@onready var _discard_button: Button = %DiscardButton
@onready var _exhaust_button: Button = %ExhaustButton
@onready var _hand_view: HandView = %HandArea
@onready var _mana_panel: PanelContainer = %ManaPanel
@onready var _mana_label: FitLabel = %ManaLabel
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _select_banner: SelectBanner = %SelectBanner
@onready var _toast_label: Label = %ToastLabel
@onready var _effect_layer: Control = %EffectLayer
@onready var _zoom_popup: CardZoomPopup = %CardZoomPopup
@onready var _pile_popup: PilePopup = %PilePopup
@onready var _result_overlay: ResultOverlay = %ResultOverlay


func _ready() -> void:
	if debug_show_keys:
		DebugKeyLocale.enable()
	_zoom_popup.move_to_front()  # デッキ一覧の上にも拡大表示を出せるように
	_apply_styles()
	_hand_view.card_pressed.connect(_on_card_pressed)
	_end_turn_button.pressed.connect(request_end_turn)
	_deck_button.pressed.connect(_open_deck)
	_discard_button.pressed.connect(_open_discard_pile)
	_exhaust_button.pressed.connect(_open_exhaust_pile)
	_settings_button.pressed.connect(func() -> void: _show_toast(UiText.t("UI_COMING_SOON")))
	_select_banner.confirmed.connect(confirm_discard)
	_select_banner.cancelled.connect(cancel_selection)
	_pile_popup.card_tapped.connect(_zoom_popup.open)
	_result_overlay.back_to_title_pressed.connect(_on_result_closed)
	if auto_start:
		if is_run_battle():
			start_run_battle()
		else:
			start_battle()


# ---------- 操作（テストからも呼べる） ----------

## ラン（1回の挑戦）の中のバトルか。エディタでこの画面だけを実行した時は false（サンプル戦になる）
func is_run_battle() -> bool:
	return Game.run != null and Game.current_screen == Game.Screen.BATTLE


## ランの今いるノードのバトルを始める（主人公のHP・所持カード・永続の補正を引き継ぐ）
func start_run_battle() -> void:
	var run := Game.run
	_dungeon_label.set_fitted_text(UiText.t(run.dungeon.name_key))
	floor_number = run.current_floor_number()
	_begin(run.create_battle())


## サンプル戦を始める（インスペクターの「サンプル戦の設定」を使う）
func start_battle() -> void:
	var loader := DataLoader.new()
	var hero := loader.get_hero(hero_id)
	var enemy := loader.get_enemy(enemy_id)
	if hero == null or enemy == null:
		push_error("主人公または敵が見つかりません：%s / %s" % [hero_id, enemy_id])
		return
	var dungeon := loader.get_dungeon(dungeon_id)
	_dungeon_label.set_fitted_text(UiText.t(dungeon.name_key) if dungeon != null else "")
	var used_seed := seed_value if seed_value != 0 else randi()
	var sample := Battle.new(hero, hero.starting_deck, enemy, used_seed)
	sample.config = loader.get_config()
	_begin(sample)


func _begin(new_battle: Battle) -> void:
	battle = new_battle
	_connect_battle()
	_sync_units()
	battle.start()
	_after_action()


## カードを使う。仲間が上限の召喚カードなら、入れ替える仲間の選択に切り替える
func try_play_card(hand_index: int, target: Combatant = null) -> Battle.PlayResult:
	if not _can_operate():
		return Battle.PlayResult.NOT_PLAYER_TURN
	var result := battle.play_card(hand_index, target)
	if result == Battle.PlayResult.NEEDS_REPLACE:
		_pending_summon_index = hand_index
		_enter_replace_select()
	elif result != Battle.PlayResult.OK:
		_show_toast(UiText.cannot_play_text(result))
	_after_action()
	return result


## 入れ替える仲間を決めて、召喚カードを使う
func choose_replace(ally: AllyCombatant) -> void:
	if mode != Mode.REPLACE_SELECT:
		return
	var index := _pending_summon_index
	_leave_select()
	battle.play_card(index, null, ally)
	_after_action()


## 入れ替えの選択をやめる（カードは手札に戻る）
func cancel_selection() -> void:
	if mode == Mode.REPLACE_SELECT:
		_leave_select()
		_refresh_all()


## ターン終了ボタン
func request_end_turn() -> void:
	if not _can_operate():
		return
	battle.end_player_turn()
	_after_action()


## 捨てるカードの選択を切り替える（選ぶ／選ぶのをやめる）
func toggle_discard(hand_index: int) -> void:
	if mode != Mode.DISCARD_SELECT:
		return
	if _discard_selection.has(hand_index):
		_discard_selection.erase(hand_index)
	elif _discard_selection.size() < battle.pending_discard_count:
		_discard_selection.append(hand_index)
	_update_discard_banner()
	_refresh_hand()


## 選んだカードを捨てて、ターンを進める
func confirm_discard() -> void:
	if mode != Mode.DISCARD_SELECT or _discard_selection.size() != battle.pending_discard_count:
		return
	var indices := _discard_selection.duplicate()
	_discard_selection.clear()
	_leave_select()
	battle.discard_cards(indices)
	_after_action()


## 演出中でなければ true
func is_idle() -> bool:
	return not _playing_events


# ---------- ルールのシグナル → 演出の待ち行列 ----------

func _connect_battle() -> void:
	battle.turn_started.connect(func(turn_number: int) -> void:
		_push({"type": "banner", "text": UiText.fmt("UI_TURN_BANNER", {"turn": turn_number})}))
	battle.timing_reached.connect(func(timing: Battle.Timing) -> void:
		if timing == Battle.Timing.ENEMY_TURN_START:
			_push({"type": "banner", "text": UiText.t("UI_ENEMY_TURN")}))
	battle.damage_dealt.connect(func(source: Combatant, target: Combatant, detail: Dictionary) -> void:
		_push({"type": "damage", "source": source, "target": target, "hp": target.hp, "armor": target.armor,
			"amount": detail["after_defense"], "poison": detail.get("poison", false)}))
	battle.status_changed.connect(func(target: Combatant) -> void:
		_push({"type": "status", "target": target}))
	battle.attack_prevented.connect(func(combatant: Combatant) -> void:
		_push({"type": "prevented", "target": combatant}))
	battle.healed.connect(func(target: Combatant, amount: int) -> void:
		_push({"type": "heal", "target": target, "hp": target.hp, "armor": target.armor, "amount": amount}))
	battle.armor_gained.connect(func(target: Combatant, amount: int) -> void:
		_push({"type": "armor", "target": target, "hp": target.hp, "armor": target.armor, "amount": amount}))
	battle.combatant_died.connect(func(combatant: Combatant) -> void:
		_push({"type": "died", "target": combatant}))
	battle.ally_summoned.connect(func(ally: AllyCombatant, replaced: AllyCombatant) -> void:
		_push({"type": "summon", "unit": ally, "replaced": replaced}))
	battle.enemy_summoned.connect(func(_summoner: EnemyCombatant, summoned: EnemyCombatant) -> void:
		_push({"type": "summon", "unit": summoned, "replaced": null}))


func _push(event: Dictionary) -> void:
	_events.append(event)
	if not _playing_events:
		_play_events()


## 待ち行列の演出を順番に見せる。全部終わったら表示を最新状態に合わせる
func _play_events() -> void:
	_playing_events = true
	_update_buttons()
	while not _events.is_empty():
		var event: Dictionary = _events.pop_front()
		var wait := _play_event(event)
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
	_playing_events = false
	_refresh_all()
	_check_battle_state()
	animations_finished.emit()


## 演出を1つ見せて、待つ時間（秒）を返す
func _play_event(event: Dictionary) -> float:
	var step := _step_time()
	match event["type"]:
		"banner":
			_show_toast(event["text"])
			return step
		"damage", "heal", "armor":
			var view: UnitView = _views.get(event["target"])
			if view == null:
				return 0.0
			view.show_values(event["hp"], event["armor"])
			var color := UiPalette.DAMAGE
			var text := "-%d" % event["amount"]
			if event["type"] == "damage":
				view.play_hit_flash(step)
				var source_view: UnitView = _views.get(event["source"])
				if source_view != null:
					source_view.play_attack_motion(step * 0.6)
				if event["poison"]:
					color = UiPalette.POISON  # 毒のダメージは色を変える
			elif event["type"] == "heal":
				color = UiPalette.HEAL
				text = "+%d" % event["amount"]
			else:
				color = UiPalette.ARMOR
				text = "+%d" % event["amount"]
			FloatingNumber.spawn(_effect_layer, _center_of(view), text, color, step * 2.0)
			return step
		"died":
			var target: Combatant = event["target"]
			if target != battle.hero and target != battle.main_enemy:
				_remove_view(target)
			return step
		"summon":
			_ensure_view(event["unit"])
			if event["replaced"] != null:
				_remove_view(event["replaced"])
			return step
		"status":
			var status_view: UnitView = _views.get(event["target"])
			if status_view != null:
				status_view.refresh_statuses()  # 状態効果の一覧を表示し直す
			return step * 0.4
		"prevented":
			var prevented_view: UnitView = _views.get(event["target"])
			if prevented_view != null:
				FloatingNumber.spawn(_effect_layer, _center_of(prevented_view), UiText.t("UI_PARALYZED_POPUP"), UiPalette.STATUS, step * 2.0)
			return step
	return 0.0


func _step_time() -> float:
	return STEP_TIME / animation_speed if animation_speed > 0.0 else 0.0


## 操作のあとに呼ぶ。演出中でなければ、すぐに表示を合わせる
func _after_action() -> void:
	if not _playing_events:
		_refresh_all()
		_check_battle_state()


## バトル終了・捨てるカードの選択が必要か、を確認して画面を切り替える
func _check_battle_state() -> void:
	if battle == null:
		return
	if battle.phase == Battle.Phase.ENDED:
		if mode != Mode.ENDED:
			mode = Mode.ENDED
			_select_banner.hide()
			_result_overlay.open(battle.result, "UI_NEXT" if is_run_battle() else "UI_BACK_TO_TITLE")
	elif battle.phase == Battle.Phase.DISCARDING and mode != Mode.DISCARD_SELECT:
		mode = Mode.DISCARD_SELECT
		_discard_selection.clear()
		_select_banner.open("", true, false)
		_update_discard_banner()
		_refresh_hand()
	_update_buttons()


# ---------- 表示 ----------

func _refresh_all() -> void:
	if battle == null:
		return
	_sync_units()
	for view: UnitView in _views.values():
		view.refresh()
	_refresh_hand()
	_refresh_status()
	_update_buttons()


func _refresh_hand() -> void:
	var flags: Array[bool] = []
	for card: CardInstance in battle.deck.hand:
		flags.append(mode == Mode.DISCARD_SELECT or battle.get_cost_problem(card.data) == Battle.PlayResult.OK)
	_hand_view.show_cards(battle.deck.hand, flags, _discard_selection)


func _refresh_status() -> void:
	var hero := battle.hero
	var colors := [UiPalette.CATALYST_RED, UiPalette.CATALYST_BLUE, UiPalette.CATALYST_GREEN]
	var names := ["UI_CATALYST_RED", "UI_CATALYST_BLUE", "UI_CATALYST_GREEN"]
	var values := [hero.catalyst_red, hero.catalyst_blue, hero.catalyst_green]
	var powers := [hero.get_catalyst_power_red(), hero.get_catalyst_power_blue(), hero.get_catalyst_power_green()]
	for i in 3:
		_catalyst_labels[i].add_theme_color_override("font_color", colors[i])
		_catalyst_labels[i].set_fitted_text(UiText.fmt("UI_CATALYST", {"color": UiText.t(names[i]), "value": values[i], "power": powers[i]}))
	_deck_button.text = UiText.fmt("UI_DECK", {"count": battle.deck.draw_pile.size()})
	_discard_button.text = UiText.fmt("UI_DISCARD_PILE", {"count": battle.deck.discard_pile.size()})
	_exhaust_button.text = UiText.fmt("UI_EXHAUST_PILE", {"count": battle.deck.exhausted_pile.size()})
	_mana_label.set_fitted_text(UiText.fmt("UI_MANA", {"current": hero.mana, "base": hero.get_mana_base()}))
	_floor_label.set_fitted_text(UiText.fmt("UI_FLOOR", {"floor": floor_number}))


func _update_buttons() -> void:
	_end_turn_button.disabled = not _can_operate()


## キャラクターの表示を、ルール側の一覧（主人公・敵本体・仲間・敵の仲間）に合わせる
func _sync_units() -> void:
	var wanted: Array[Combatant] = [battle.hero, battle.main_enemy]
	wanted.append_array(battle.allies)
	wanted.append_array(battle.enemy_allies)
	for combatant: Combatant in _views.keys():
		if not wanted.has(combatant):
			_remove_view(combatant)
	for combatant: Combatant in wanted:
		_ensure_view(combatant)
	# 並び順：敵エリアは敵本体が先、仲間は呼ばれた順
	_enemy_area.move_child(_views[battle.main_enemy], 0)
	for i in battle.enemy_allies.size():
		_enemy_area.move_child(_views[battle.enemy_allies[i]], i + 1)
	for i in battle.allies.size():
		_ally_row.move_child(_views[battle.allies[i]], i)


func _ensure_view(combatant: Combatant) -> void:
	if _views.has(combatant):
		return
	var view: UnitView = UNIT_SCENE.instantiate()
	var parent: Control = _enemy_area
	var width := UNIT_WIDTH
	if combatant is HeroCombatant:
		parent = _hero_holder
		width = HERO_WIDTH
	elif combatant is AllyCombatant:
		parent = _ally_row
	elif combatant == battle.main_enemy:
		width = MAIN_ENEMY_WIDTH
	view.custom_minimum_size.x = width
	parent.add_child(view)
	view.set_combatant(combatant)
	view.tapped.connect(_on_unit_tapped)
	_views[combatant] = view


func _remove_view(combatant: Combatant) -> void:
	var view: UnitView = _views.get(combatant)
	if view == null:
		return
	_views.erase(combatant)
	view.queue_free()


func _center_of(control: Control) -> Vector2:
	return control.global_position + control.size / 2.0 - _effect_layer.global_position


func _show_toast(text: String) -> void:
	if text == "":
		return
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast_label.show()
	if _toast_tween != null:
		_toast_tween.kill()
	var duration := _step_time() * 2.0
	if duration <= 0.0:
		_toast_label.hide()
		return
	_toast_tween = create_tween()
	_toast_tween.tween_interval(duration * 0.6)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, duration * 0.4)
	_toast_tween.tween_callback(_toast_label.hide)


func _apply_styles() -> void:
	_header.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL, UiPalette.PANEL_BORDER, 2, 10))
	_status_bar.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL, UiPalette.PANEL_BORDER, 2, 10))
	_mana_panel.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL, UiPalette.MANA, 3, 14))
	_mana_label.add_theme_color_override("font_color", UiPalette.MANA)
	UiPalette.style_button(_end_turn_button, UiPalette.BUTTON_ACCENT)
	for button: Button in [_settings_button, _deck_button, _discard_button, _exhaust_button]:
		UiPalette.style_button(button, UiPalette.BUTTON)


# ---------- タップとドラッグ ----------

func _can_operate() -> bool:
	return battle != null and mode == Mode.NORMAL and battle.phase == Battle.Phase.PLAYER_TURN and not _playing_events


func _on_card_pressed(view: CardView) -> void:
	if _playing_events:
		return
	if mode == Mode.DISCARD_SELECT:
		toggle_discard(view.hand_index)
		return
	if not _can_operate():
		return
	_drag = {"view": view, "start": get_global_mouse_position(), "moved": false}


func _input(event: InputEvent) -> void:
	if _drag.is_empty():
		return
	if event is InputEventMouseMotion:
		var pos := get_global_mouse_position()
		if not _drag["moved"] and pos.distance_to(_drag["start"]) > DRAG_THRESHOLD:
			_drag["moved"] = true
			_begin_drag()
		if _drag_ghost != null:
			_move_drag(pos)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag(get_global_mouse_position())


func _begin_drag() -> void:
	var view: CardView = _drag["view"]
	var problem := battle.get_cost_problem(view.card)
	if problem != Battle.PlayResult.OK:
		_show_toast(UiText.cannot_play_text(problem))  # 使えないカードはドラッグできない
		return
	_drag_ghost = CARD_SCENE.instantiate()
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_layer.add_child(_drag_ghost)
	_drag_ghost.set_card(view.card)
	view.modulate.a = 0.3


func _move_drag(pos: Vector2) -> void:
	_drag_ghost.position = pos - _drag_ghost.size / 2.0 - _effect_layer.global_position
	var target := _unit_view_at(pos, _drag_ghost.card)
	if target != _drag_target:
		if _drag_target != null:
			_drag_target.set_highlight(false)
		_drag_target = target
		if _drag_target != null:
			_drag_target.set_highlight(true)


func _end_drag(pos: Vector2) -> void:
	var view: CardView = _drag["view"]
	var moved: bool = _drag["moved"]
	_drag = {}
	if not moved:
		_zoom_popup.open(view.card, view.uses_left)  # タップ → 拡大表示
		return
	if _drag_ghost == null:
		return  # 使えないカードだった
	_drag_ghost.queue_free()
	_drag_ghost = null
	if _drag_target != null:
		_drag_target.set_highlight(false)
		_drag_target = null
	view.modulate.a = 1.0
	var card := view.card
	if battle.needs_target(card):
		var target_view := _unit_view_at(pos, card)
		if target_view != null:
			try_play_card(view.hand_index, target_view.combatant)
			return
	elif pos.y < _hand_view.get_global_rect().position.y:
		try_play_card(view.hand_index)  # 対象を選ばないカードは、手札より上で離すと使う
		return
	_refresh_hand()  # キャンセル：手札に戻す


## 指の位置にいる、そのカードの対象にできるキャラクター
func _unit_view_at(pos: Vector2, card: CardData) -> UnitView:
	if not battle.needs_target(card):
		return null
	for view: UnitView in _views.values():
		if view.get_global_rect().has_point(pos) and battle.is_valid_target(card, view.combatant):
			return view
	return null


func _on_unit_tapped(view: UnitView) -> void:
	if mode == Mode.REPLACE_SELECT and view.combatant is AllyCombatant:
		choose_replace(view.combatant as AllyCombatant)


# ---------- 選択の表示 ----------

func _enter_replace_select() -> void:
	mode = Mode.REPLACE_SELECT
	_select_banner.open(UiText.t("UI_REPLACE_PROMPT"), false, true)
	for ally: AllyCombatant in battle.allies:
		_views[ally].set_highlight(true)


func _leave_select() -> void:
	mode = Mode.NORMAL
	_pending_summon_index = -1
	_select_banner.hide()
	for view: UnitView in _views.values():
		view.set_highlight(false)


func _update_discard_banner() -> void:
	var remaining := battle.pending_discard_count - _discard_selection.size()
	_select_banner.set_message(UiText.fmt("UI_DISCARD_PROMPT", {"count": remaining}))
	_select_banner.set_confirm_enabled(remaining == 0)


func _open_deck() -> void:
	var cards := PilePopup.sorted_by_name(battle.deck.draw_pile)
	_pile_popup.open(UiText.fmt("UI_DECK_TITLE", {"count": cards.size()}), cards)


func _open_discard_pile() -> void:
	_pile_popup.open(UiText.fmt("UI_DISCARD_TITLE", {"count": battle.deck.discard_pile.size()}), battle.deck.discard_pile)


func _open_exhaust_pile() -> void:
	_pile_popup.open(UiText.fmt("UI_EXHAUST_TITLE", {"count": battle.deck.exhausted_pile.size()}), battle.deck.exhausted_pile)


## 勝敗表示のボタン：ランの中なら次の画面（報酬・ゲームオーバー・クリア）へ、サンプル戦ならタイトルへ
func _on_result_closed() -> void:
	if is_run_battle():
		Game.finish_battle(battle.result)
	else:
		Game.go_to_title()
