class_name UnitView
extends PanelContainer
## キャラクター1体（主人公・仲間・敵）の表示。
## 図形（Body）、名前、HPバー、アーマー、状態効果、敵は行動予告を出す。
## 絵は Art（TextureRect）に画像を入れれば表示される（今は色付きの四角形）。

## タップされた時（仲間の入れ替え選択などに使う）
signal tapped(view: UnitView)

## 絵（あれば表示する。今は未使用）
@export var art_texture: Texture2D

var combatant: Combatant
var highlighted: bool = false

@onready var _intent_label: FitLabel = %IntentLabel
@onready var _body: ColorRect = %Body
@onready var _art: TextureRect = %Art
@onready var _name_label: FitLabel = %NameLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _armor_label: FitLabel = %ArmorLabel
@onready var _status_label: FitLabel = %StatusLabel


func _ready() -> void:
	_hp_bar.add_theme_stylebox_override("background", UiPalette.make_box(UiPalette.HP_BACK, Color.TRANSPARENT, 0, 6))
	_hp_bar.add_theme_stylebox_override("fill", UiPalette.make_box(UiPalette.HP, Color.TRANSPARENT, 0, 6))
	_armor_label.add_theme_color_override("font_color", UiPalette.ARMOR)
	_intent_label.add_theme_color_override("font_color", UiPalette.INTENT)
	_status_label.add_theme_color_override("font_color", UiPalette.TEXT_SUB)
	_update_frame()
	if combatant != null:
		refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(self)


func set_combatant(value: Combatant) -> void:
	combatant = value
	if is_node_ready():
		refresh()


## 最新の値で表示を作り直す
func refresh() -> void:
	if combatant == null:
		return
	_body.color = _body_color()
	_art.texture = art_texture
	_name_label.set_fitted_text(UiText.t(combatant.name_key))
	_intent_label.visible = combatant is EnemyCombatant
	if combatant is EnemyCombatant:
		_intent_label.set_fitted_text(UiText.intent_text(combatant as EnemyCombatant))
	_status_label.set_fitted_text(UiText.status_text(combatant))
	show_values(combatant.hp, combatant.armor)


## HPとアーマーの表示だけを変える（演出の途中で、その時点の値を見せるために使う）
func show_values(hp: int, armor: int) -> void:
	var max_hp := combatant.get_max_hp()
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = UiText.fmt("UI_HP", {"hp": hp, "max": max_hp})
	_armor_label.set_fitted_text(UiText.fmt("UI_ARMOR", {"armor": armor}) if armor > 0 else "")


func set_highlight(value: bool) -> void:
	highlighted = value
	_update_frame()


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


func _update_frame() -> void:
	var border := UiPalette.HIGHLIGHT if highlighted else UiPalette.PANEL_BORDER
	add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL, border, 4 if highlighted else 2, 10))
