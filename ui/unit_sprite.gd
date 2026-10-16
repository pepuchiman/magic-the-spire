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
## 踏み込みの動き（途中で次の動きが来た時に止めるため）と、動く前の姿の位置
var _motion_tween: Tween
var _body_home: Vector2 = Vector2.ZERO

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


## 攻撃した時の動き：相手の方向（direction）へ少し踏み込んで戻る。
## 姿（_body）は行動予告の下に並んでいるので、元の位置は 0 ではない。動く前の位置を覚えておき、そこへ戻す
func play_attack_motion(duration: float, direction: Vector2 = Vector2.ZERO) -> void:
	if duration <= 0.0:
		return
	var home := _stop_motion()
	var step := direction.normalized() * minf(direction.length() * 0.25, 60.0)
	_motion_tween = create_tween()
	_motion_tween.tween_property(_body, "position", home + step, duration * 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_motion_tween.tween_property(_body, "position", home, duration * 0.65).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)


## 倒れた時の動き：薄くなりながら沈んで消える（終わったら自分を消す）
func play_death(duration: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if duration <= 0.0:
		queue_free()
		return
	var home := _stop_motion()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.tween_property(_body, "position:y", home.y + _body.size.y * 0.25, duration).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


## 動きの途中なら止めて元の位置に戻し、元の位置を返す（続けて攻撃した時に、位置がずれていかないように）
func _stop_motion() -> Vector2:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
		_body.position = _body_home
	else:
		_body_home = _body.position
	return _body_home


## 召喚された時の動き：下から伸びるように現れる
func play_appear(duration: float) -> void:
	if duration <= 0.0:
		return
	_body.pivot_offset = Vector2(_body.size.x / 2.0, _body.size.y)
	_body.scale = Vector2(0.6, 0.0)
	modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_body, "scale", Vector2.ONE, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, duration * 0.5)


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
