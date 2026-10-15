class_name UnitInfoPanel
extends PanelContainer
## キャラクターの情報の枠（名前・HP・アーマー・状態効果）。
## 主人公と敵本体は戦場に常に出す。クリーチャーはタップした時の詳しい情報の窓で使う。

var combatant: Combatant
## 行動予告も出すか（クリーチャーの詳しい情報の窓で使う。敵本体は頭の上に出すので出さない）
var show_intent: bool = false

@onready var _name_label: FitLabel = %NameLabel
@onready var _intent_label: FitLabel = %IntentLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _armor_label: FitLabel = %ArmorLabel
@onready var _status_row: StatusRow = %StatusRow


func _ready() -> void:
	add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL, UiPalette.PANEL_BORDER, 2, 10))
	_hp_bar.add_theme_stylebox_override("background", UiPalette.make_box(UiPalette.HP_BACK, Color.TRANSPARENT, 0, 6))
	_hp_bar.add_theme_stylebox_override("fill", UiPalette.make_box(UiPalette.HP, Color.TRANSPARENT, 0, 6))
	_armor_label.add_theme_color_override("font_color", UiPalette.ARMOR)
	_intent_label.add_theme_color_override("font_color", UiPalette.INTENT)
	if combatant != null:
		refresh()


func set_combatant(value: Combatant) -> void:
	combatant = value
	if is_node_ready():
		refresh()


## 最新の値で表示を作り直す
func refresh() -> void:
	if combatant == null:
		return
	_name_label.set_fitted_text(UiText.t(combatant.name_key))
	_intent_label.visible = show_intent and combatant is EnemyCombatant
	if _intent_label.visible:
		_intent_label.set_fitted_text(UiText.intent_text(combatant as EnemyCombatant))
	refresh_statuses()
	show_values(combatant.hp, combatant.armor)


## 状態効果の一覧だけを表示し直す（演出の途中で使う。HPの表示は変えない）
func refresh_statuses() -> void:
	if combatant != null:
		_status_row.show_combatant(combatant)


## HPとアーマーの表示だけを変える（演出の途中で、その時点の値を見せるために使う）
func show_values(hp: int, armor: int) -> void:
	if combatant == null:
		return
	var max_hp := combatant.get_max_hp()
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = UiText.fmt("UI_HP", {"hp": hp, "max": max_hp})
	_armor_label.set_fitted_text(UiText.fmt("UI_ARMOR", {"armor": armor}) if armor > 0 else "")
