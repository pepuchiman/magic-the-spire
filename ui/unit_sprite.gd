class_name UnitSprite
extends Control
## 戦場に立つキャラクター1体（主人公・クリーチャー・敵）の姿。
## 敵は頭の上に行動予告を出す。クリーチャーは足元に小さなHPバーと状態効果を出す。
## 主人公と敵本体の名前・HPなどは、別の「情報の枠」（UnitInfoPanel）に出す。
## 絵は各データ（主人公・クリーチャー・敵）の絵の項目に画像があれば、図形の代わりに表示される。

## タップされた時（クリーチャーの入れ替え選択・詳しい情報の表示に使う）
signal tapped(sprite: UnitSprite)

var combatant: Combatant
## 向き（主人公側は背中、敵側は正面）
var facing: UnitFigure.Facing = UnitFigure.Facing.FRONT
## 足元に小さなHPなどを出すか（クリーチャーだけ）
var show_plate: bool = false
var highlighted: bool = false
## 今表示しているアーマーの値（演出の途中の値）
var _shown_armor: int = 0

@onready var _intent_label: FitLabel = %IntentLabel
@onready var _body: Control = %Body
@onready var _figure: UnitFigure = %Figure
@onready var _art: TextureRect = %Art
@onready var _plate: VBoxContainer = %Plate
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _status_row: StatusRow = %StatusRow


func _ready() -> void:
	_hp_bar.add_theme_stylebox_override("background", UiPalette.make_box(UiPalette.HP_BACK, Color.TRANSPARENT, 0, 4))
	_hp_bar.add_theme_stylebox_override("fill", UiPalette.make_box(UiPalette.HP, Color.TRANSPARENT, 0, 4))
	_intent_label.add_theme_color_override("font_color", UiPalette.INTENT)
	_intent_label.add_theme_stylebox_override("normal", UiPalette.make_box(UiPalette.PANEL, UiPalette.INTENT.darkened(0.4), 2, 10))
	if combatant != null:
		refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(self)


## 表示するキャラクターと、向き・足元の表示の有無を決める
func setup(value: Combatant, new_facing: UnitFigure.Facing, with_plate: bool) -> void:
	combatant = value
	facing = new_facing
	show_plate = with_plate
	if is_node_ready():
		refresh()


## 最新の値で表示を作り直す
func refresh() -> void:
	if combatant == null:
		return
	var texture := _art_texture()
	_art.texture = texture
	_figure.facing = facing
	_figure.kind = _figure_kind()
	_figure.is_boss = combatant is EnemyCombatant and (combatant as EnemyCombatant).is_main
	_figure.body_color = _body_color()
	_figure.draw_shape = texture == null
	_figure.highlighted = highlighted
	_intent_label.visible = combatant is EnemyCombatant
	if combatant is EnemyCombatant:
		_intent_label.set_fitted_text(UiText.intent_text(combatant as EnemyCombatant))
	_plate.visible = show_plate
	show_values(combatant.hp, combatant.armor)


## 状態効果の一覧だけを表示し直す（演出の途中で使う）
func refresh_statuses() -> void:
	if combatant != null and show_plate:
		_update_sub_line(_shown_armor)


## HPとアーマーの表示だけを変える（演出の途中で、その時点の値を見せるために使う）
func show_values(hp: int, armor: int) -> void:
	if combatant == null or not show_plate:
		return
	var max_hp := combatant.get_max_hp()
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = UiText.fmt("UI_HP", {"hp": hp, "max": max_hp})
	_shown_armor = armor
	_update_sub_line(armor)


## HPバーの下の行：アーマー（あれば）と状態効果を、印つきで横に並べる
func _update_sub_line(armor: int) -> void:
	_status_row.show_combatant(combatant, armor)


## データにある絵（向きに合わせる）。無ければ null（図形で表示する）
func _art_texture() -> Texture2D:
	if combatant is HeroCombatant:
		var hero: HeroData = (combatant as HeroCombatant).data
		return hero.art_front if facing == UnitFigure.Facing.FRONT else hero.art_back
	if combatant is AllyCombatant:
		return (combatant as AllyCombatant).data.art_back
	if combatant is EnemyCombatant:
		return (combatant as EnemyCombatant).data.art_front
	return null


## 図形の形（主人公は魔法使い、クリーチャー・敵は種族ごと）
func _figure_kind() -> UnitFigure.Kind:
	var race := -1
	if combatant is AllyCombatant:
		race = (combatant as AllyCombatant).data.race
	elif combatant is EnemyCombatant:
		race = (combatant as EnemyCombatant).data.race
	match race:
		GameEnums.Race.BEAST:
			return UnitFigure.Kind.BEAST
		GameEnums.Race.SPIRIT:
			return UnitFigure.Kind.SPIRIT
		GameEnums.Race.MONSTER:
			return UnitFigure.Kind.MONSTER
	return UnitFigure.Kind.WIZARD


func set_highlight(value: bool) -> void:
	highlighted = value
	if is_node_ready():
		_figure.highlighted = value


## 演出（ダメージの数字など）を出す場所にする部品（姿の部分）
func effect_anchor() -> Control:
	return _body


## 攻撃した時の小さな動き
func play_attack_motion(duration: float) -> void:
	if duration <= 0.0:
		return
	_body.pivot_offset = _body.size / 2.0
	var tween := create_tween()
	tween.tween_property(_body, "scale", Vector2(1.15, 1.15), duration * 0.4)
	tween.tween_property(_body, "scale", Vector2.ONE, duration * 0.6)


## ダメージを受けた時の点滅
func play_hit_flash(duration: float) -> void:
	if duration <= 0.0:
		return
	var tween := create_tween()
	_body.modulate = UiPalette.DAMAGE
	tween.tween_property(_body, "modulate", Color.WHITE, duration)


func _body_color() -> Color:
	if combatant is HeroCombatant:
		return UiPalette.BODY_HERO
	if combatant is AllyCombatant:
		return UiPalette.BODY_ALLY
	if combatant is EnemyCombatant and (combatant as EnemyCombatant).is_main:
		return UiPalette.BODY_BOSS
	return UiPalette.BODY_ENEMY
