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

const UNIT_SCENE := preload("res://ui/unit_sprite.tscn")
const CARD_SCENE := preload("res://ui/card_view.tscn")
## これ以上指が動いたらドラッグとみなす（それ未満で離したらタップ）
const DRAG_THRESHOLD := 16.0
## 演出1つ分の基本の長さ（秒）
const STEP_TIME := 0.45
## このダメージ以上（最大HPに対する割合）なら画面を揺らす
const BIG_HIT_RATIO := 0.3

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

var _views: Dictionary = {}  # Combatant → UnitSprite（戦場の姿）
var _info_panels: Dictionary = {}  # Combatant → UnitInfoPanel（主人公と敵本体の情報の枠）
var _events: Array[Dictionary] = []
var _playing_events: bool = false
var _discard_selection: Array[int] = []
## 入れ替え選択中の召喚カード（手札の位置）
var _pending_summon_index: int = -1
## ドラッグ中の情報（view、start、moved）
var _drag: Dictionary = {}
var _drag_ghost: CardView
var _drag_target: UnitSprite
var _toast_tween: Tween
## 演出：最後に使ったカードの手札の位置（カードが飛んでいく出発点）
var _played_hand_index: int = -1
## 演出：キャラクターごとに最後に見せた状態効果の値（新しく付いた状態効果の印を出すため）
var _shown_statuses: Dictionary = {}  # Combatant → {状態効果の種類: 値}
## 演出：種類ごとのエフェクトの一覧
var _effects: EffectSet

@onready var _background: BattleBackground = %Background
@onready var _header: PanelContainer = %Header
@onready var _dungeon_label: FitLabel = %DungeonLabel
@onready var _floor_label: FitLabel = %FloorLabel
@onready var _settings_button: Button = %SettingsButton
## 戦場の立ち位置（エディターで枠を動かすと、キャラクターの位置と大きさが変わる）。
## 後に並んでいる立ち位置ほど手前に描かれる
@onready var _enemy_main_slot: Control = %EnemyMainSlot
@onready var _enemy_creature_slots: Array[Control] = [%EnemyCreatureSlot1, %EnemyCreatureSlot2]
@onready var _hero_slot: Control = %HeroSlot
@onready var _ally_slots: Array[Control] = [%AllySlot1, %AllySlot2]
@onready var _enemy_info: UnitInfoPanel = %EnemyInfo
@onready var _hero_info: UnitInfoPanel = %HeroInfo
@onready var _detail_popup: UnitDetailPopup = %UnitDetailPopup
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
	_effects = Game.data.get_effects() if Game.data != null else EffectSet.create_default()
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
	_background.setup(run.dungeon)
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
	_background.setup(dungeon)
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
	_played_hand_index = hand_index  # カードが飛んでいく演出の出発点
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
	_played_hand_index = index
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
	battle.card_played.connect(func(instance: CardInstance, target: Combatant) -> void:
		_push({"type": "card", "card": instance.data, "targets": battle.effect_targets(instance.data, target),
			"hand_index": _played_hand_index}))
	battle.turn_started.connect(func(turn_number: int) -> void:
		_push({"type": "banner", "text": UiText.fmt("UI_TURN_BANNER", {"turn": turn_number}), "sound": GameEnums.SoundEvent.TURN_START}))
	battle.cards_drawn.connect(func(_cards: Array[CardInstance]) -> void:
		_push({"type": "sound", "sound": GameEnums.SoundEvent.CARD_DRAW}))
	battle.timing_reached.connect(func(timing: Battle.Timing) -> void:
		if timing == Battle.Timing.ENEMY_TURN_START:
			_push({"type": "banner", "text": UiText.t("UI_ENEMY_TURN")}))
	battle.damage_dealt.connect(func(source: Combatant, target: Combatant, detail: Dictionary) -> void:
		_push({"type": "damage", "source": source, "target": target, "hp": target.hp, "armor": target.armor,
			"amount": detail["after_defense"], "poison": detail.get("poison", false), "attack": detail.get("attack", false),
			"hp_damage": detail.get("hp_damage", 0)}))
	battle.status_changed.connect(func(target: Combatant) -> void:
		_push({"type": "status", "target": target, "statuses": _status_values(target)}))
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
			if event.has("sound"):
				_sound(event["sound"], step)
			return step
		"sound":
			_sound(event["sound"], step)
			return 0.0
		"card":
			return _play_card_event(event, step)
		"damage", "heal", "armor":
			var view: UnitSprite = _views.get(event["target"])
			if view == null:
				return 0.0
			_show_values(event["target"], event["hp"], event["armor"])
			var color := UiPalette.DAMAGE
			var text := "-%d" % event["amount"]
			if event["type"] == "damage":
				view.play_hit_flash(step)
				var source: Combatant = event["source"]
				var source_view: UnitSprite = _views.get(source)
				if event["poison"]:
					color = UiPalette.POISON  # 毒のダメージは色を変える
					_spawn_effect(_effects.card_effects.get(GameEnums.CardEffect.POISON), view, step * 1.5)
					if step > 0.0:
						UiSound.card(GameEnums.CardEffect.POISON)
				elif event["attack"] and source_view != null and not source is HeroCombatant:
					# クリーチャー・敵の攻撃：相手へ踏み込み、相手の位置に攻撃エフェクト（主人公のカードはカードの演出で見せる）
					source_view.play_attack_motion(step * 0.6, _center_of(view.effect_anchor()) - _center_of(source_view.effect_anchor()))
					_spawn_effect(_effects.attack_effects.get(_attack_effect_of(source)), view, step * 1.2)
					if step > 0.0:
						UiSound.attack(_attack_effect_of(source))
				else:
					_sound(GameEnums.SoundEvent.DAMAGE, step)  # 主人公のカード・棘のダメージ
				if event["hp_damage"] >= event["target"].get_max_hp() * BIG_HIT_RATIO:
					_shake(step)  # 大きなダメージは画面を揺らす
			elif event["type"] == "heal":
				color = UiPalette.HEAL
				text = "+%d" % event["amount"]
			else:
				color = UiPalette.ARMOR
				text = "+%d" % event["amount"]
			FloatingNumber.spawn(_effect_layer, _center_of(view.effect_anchor()), text, color, step * 2.0)
			return step
		"died":
			var target: Combatant = event["target"]
			if target != battle.hero and target != battle.main_enemy:
				_remove_view(target, step)  # 薄くなって消える
				_sound(GameEnums.SoundEvent.DEATH, step)
			return step
		"summon":
			_ensure_view(event["unit"])
			_place_unit(event["unit"])
			var summoned: UnitSprite = _views[event["unit"]]
			if not summoned.is_inside_tree():
				return step  # すでに倒れて立ち位置がない（演出の時点では、ルール側の処理は全部終わっている）
			summoned.play_appear(step)
			_spawn_effect(_effects.card_effects.get(GameEnums.CardEffect.SUMMON), summoned, step * 1.5)
			if event["replaced"] != null:
				_remove_view(event["replaced"], step)
			return step
		"status":
			var status_target: Combatant = event["target"]
			var status_view: UnitSprite = _views.get(status_target)
			if status_view != null:
				status_view.refresh_statuses()  # 状態効果の一覧を表示し直す
				_float_new_statuses(status_target, event["statuses"], status_view, step)
			var status_info: UnitInfoPanel = _info_panels.get(status_target)
			if status_info != null:
				status_info.refresh_statuses()
			_shown_statuses[status_target] = event["statuses"]
			return step * 0.4
		"prevented":
			var prevented_view: UnitSprite = _views.get(event["target"])
			if prevented_view != null:
				FloatingNumber.spawn(_effect_layer, _center_of(prevented_view.effect_anchor()), UiText.t("UI_PARALYZED_POPUP"), UiPalette.STATUS, step * 2.0)
				_sound(GameEnums.SoundEvent.PARALYZED, step)
			return step
	return 0.0


## カードを使った演出：カードが手札から最初の対象へ飛び、着いたら対象全員の位置に効果エフェクトを出す
func _play_card_event(event: Dictionary, step: float) -> float:
	if step <= 0.0:
		return 0.0
	var card: CardData = event["card"]
	var targets: Array = event["targets"]
	var target_views: Array[UnitSprite] = []
	for target: Combatant in targets:
		if _views.has(target):
			target_views.append(_views[target])
	if target_views.is_empty() and _views.has(battle.hero):
		target_views.append(_views[battle.hero])  # 対象を選ばないカード（ドローなど）は主人公の位置に出す
	UiSound.event(GameEnums.SoundEvent.CARD_PLAY)
	var fly_time := step * 0.5
	var ghost: CardView = CARD_SCENE.instantiate()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_layer.add_child(ghost)
	ghost.set_card(card)
	var origin := _card_origin(event["hand_index"]) - CardView.BASE_SIZE / 2.0
	var hand_card := _hand_view.get_view(event["hand_index"])
	if hand_card != null:
		hand_card.modulate.a = 0.0  # 手札の表示は演出のあとで作り直すので、飛んでいる間は手札のカードを隠す
	var goal := _center_of(target_views[0].effect_anchor()) - CardView.BASE_SIZE / 2.0 if not target_views.is_empty() else origin
	ghost.position = origin
	var effect_scene: PackedScene = _effects.card_effects.get(card.visual_effect)
	var tween := ghost.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "position", goal, fly_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ghost, "scale", Vector2(0.4, 0.4), fly_time)
	tween.tween_property(ghost, "modulate:a", 0.2, fly_time)
	tween.chain().tween_callback(func() -> void:
		ghost.queue_free()
		UiSound.card(card.visual_effect)
		for view: UnitSprite in target_views:
			if is_instance_valid(view):
				_spawn_effect(effect_scene, view, step * 1.4))
	return fly_time + (step * 0.7 if effect_scene != null else 0.0)


## エフェクトのシーンを、キャラクターの姿の中心に出す（シーンが無い・演出なしの時は何もしない）
func _spawn_effect(scene: PackedScene, view: UnitSprite, duration: float) -> void:
	if scene == null or view == null or duration <= 0.0 or not view.is_inside_tree():
		return
	var effect := scene.instantiate()
	_effect_layer.add_child(effect)
	var anchor := view.effect_anchor()
	effect.position = _center_of(anchor)
	effect.play(minf(anchor.size.x, anchor.size.y) * 1.1, duration)


## 新しく付いた（値が増えた）状態効果の印を、キャラクターの上に浮かべる
func _float_new_statuses(target: Combatant, now: Dictionary, view: UnitSprite, step: float) -> void:
	if step <= 0.0:
		return
	var before: Dictionary = _shown_statuses.get(target, {})
	var center := _center_of(view.effect_anchor())
	var index := 0
	for type: int in now:
		if now[type] <= before.get(type, 0):
			continue
		var icon := ShapeIcon.new()
		icon.size = Vector2(56, 56)
		icon.setup(ShapeIcon.status_shape(type), UiPalette.status_color(type), UiIcons.status(type))
		_effect_layer.add_child(icon)
		icon.position = center - icon.size / 2.0 + Vector2(index * 40.0 - 20.0, -20.0)
		var tween := icon.create_tween().set_parallel(true)
		tween.tween_property(icon, "position:y", icon.position.y - 70.0, step * 2.0)
		tween.tween_property(icon, "modulate:a", 0.0, step * 2.0).set_delay(step * 0.8)
		tween.chain().tween_callback(icon.queue_free)
		index += 1


## 状態効果の今の値の一覧（種類 → 値）
static func _status_values(combatant: Combatant) -> Dictionary:
	var values := {}
	for type: int in combatant.statuses:
		var status: StatusInstance = combatant.statuses[type]
		values[type] = maxi(status.value, 1) + maxi(status.turns, 0)
	return values


## クリーチャー・敵の攻撃エフェクトの種類
static func _attack_effect_of(source: Combatant) -> GameEnums.AttackEffect:
	if source is AllyCombatant:
		return (source as AllyCombatant).data.attack_effect
	if source is EnemyCombatant:
		return (source as EnemyCombatant).data.attack_effect
	return GameEnums.AttackEffect.BLOW


## カードが飛んでいく出発点（手札のそのカードの中心。分からなければ手札の場所の中央）
func _card_origin(hand_index: int) -> Vector2:
	var view := _hand_view.get_view(hand_index)
	if view != null:
		return _center_of(view)
	return _center_of(_hand_view)


## 画面を少し揺らす
func _shake(step: float) -> void:
	if step <= 0.0:
		return
	var safe_area: Control = $SafeArea
	var tween := create_tween()
	for i in 4:
		tween.tween_property(safe_area, "position", Vector2(randf_range(-8, 8), randf_range(-6, 6)), step * 0.08)
	tween.tween_property(safe_area, "position", Vector2.ZERO, step * 0.08)


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
			_sound(GameEnums.SoundEvent.VICTORY if battle.result.won else GameEnums.SoundEvent.DEFEAT, _step_time())
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
	for view: UnitSprite in _views.values():
		view.refresh()
	for panel: UnitInfoPanel in _info_panels.values():
		panel.refresh()
	if _detail_popup.visible and _detail_popup.combatant != null:
		if _views.has(_detail_popup.combatant):
			_detail_popup.open(_detail_popup.combatant)
		else:
			_detail_popup.hide()  # 詳しく見ていたクリーチャーが倒れた
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
	# 立ち位置：クリーチャーは呼ばれた順に1番目・2番目の立ち位置へ
	_place(_views[battle.hero], _hero_slot)
	_place(_views[battle.main_enemy], _enemy_main_slot)
	for i in battle.allies.size():
		_place(_views[battle.allies[i]], _ally_slots[i])
	for i in battle.enemy_allies.size():
		_place(_views[battle.enemy_allies[i]], _enemy_creature_slots[i])
	if not _info_panels.has(battle.hero):
		_info_panels = {battle.hero: _hero_info, battle.main_enemy: _enemy_info}
		_hero_info.set_combatant(battle.hero)
		_enemy_info.set_combatant(battle.main_enemy)


func _ensure_view(combatant: Combatant) -> void:
	if _views.has(combatant):
		return
	var view: UnitSprite = UNIT_SCENE.instantiate()
	var is_friend := combatant is HeroCombatant or combatant is AllyCombatant
	var is_creature := combatant is AllyCombatant or (combatant is EnemyCombatant and combatant != battle.main_enemy)
	# 主人公側は背中、敵側は正面を向く。クリーチャーだけ足元にHPなどを出す
	view.setup(combatant, UnitFigure.Facing.BACK if is_friend else UnitFigure.Facing.FRONT, is_creature)
	view.tapped.connect(_on_unit_tapped)
	_views[combatant] = view


## キャラクターの姿を立ち位置に置く（すでにそこにいれば何もしない）
func _place(view: UnitSprite, slot: Control) -> void:
	if view.get_parent() == slot:
		return
	if view.get_parent() != null:
		view.get_parent().remove_child(view)
	slot.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## キャラクターの姿を消す。duration が 0 より大きければ、薄くなって消える演出をする
func _remove_view(combatant: Combatant, duration: float = 0.0) -> void:
	var view: UnitSprite = _views.get(combatant)
	if view == null:
		return
	_views.erase(combatant)
	_shown_statuses.erase(combatant)
	view.play_death(duration)


## 召喚されたキャラクターを、今の並び順の立ち位置に置く（演出の途中で使う）
func _place_unit(combatant: Combatant) -> void:
	var view: UnitSprite = _views.get(combatant)
	if view == null:
		return
	var index := battle.allies.find(combatant) if combatant is AllyCombatant else battle.enemy_allies.find(combatant)
	var slots := _ally_slots if combatant is AllyCombatant else _enemy_creature_slots
	if index >= 0 and index < slots.size():
		_place(view, slots[index])


## 主人公・敵本体は情報の枠、クリーチャーは足元のHPを、その時点の値にする
func _show_values(combatant: Combatant, hp: int, armor: int) -> void:
	var view: UnitSprite = _views.get(combatant)
	if view != null:
		view.show_values(hp, armor)
	var panel: UnitInfoPanel = _info_panels.get(combatant)
	if panel != null:
		panel.show_values(hp, armor)


## 戦場のキャラクターの姿を、手前に描かれているものから順に並べる
## （重なった場所では、手前のキャラクターを選ぶため）
func _views_front_to_back() -> Array[UnitSprite]:
	var slots: Array[Control] = []
	for child: Node in _hero_slot.get_parent().get_children():
		if child is Control and child.get_child_count() > 0:
			slots.append(child as Control)
	var result: Array[UnitSprite] = []
	for i in range(slots.size() - 1, -1, -1):
		for child: Node in slots[i].get_children():
			if child is UnitSprite and _views.values().has(child):
				result.append(child as UnitSprite)
	return result


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


## 指の位置にいる、そのカードの対象にできるキャラクター。
## 重なった場所では、手前に描かれているキャラクターを選ぶ
func _unit_view_at(pos: Vector2, card: CardData) -> UnitSprite:
	if not battle.needs_target(card):
		return null
	for view: UnitSprite in _views_front_to_back():
		if view.get_global_rect().has_point(pos) and battle.is_valid_target(card, view.combatant):
			return view
	return null


## キャラクターをタップした時：入れ替えの選択中なら選ぶ。クリーチャーなら詳しい情報を出す
func _on_unit_tapped(view: UnitSprite) -> void:
	if mode == Mode.REPLACE_SELECT:
		if view.combatant is AllyCombatant:
			choose_replace(view.combatant as AllyCombatant)
		return
	if view.show_plate and _drag.is_empty():
		_detail_popup.open(view.combatant)


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
	for view: UnitSprite in _views.values():
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


## 効果音を鳴らす（演出の速さが0の時＝テストの時は鳴らさない）
func _sound(type: GameEnums.SoundEvent, step: float) -> void:
	if step > 0.0:
		UiSound.event(type)
