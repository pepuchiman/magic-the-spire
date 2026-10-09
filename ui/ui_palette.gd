class_name UiPalette
extends RefCounted
## 画面で使う色を1か所にまとめたもの。色を変えたい時はここを直す。
## （後で絵の素材に差し替える時も、ここを見れば何に色を使っているか分かる）

const BACKGROUND := Color(0.10, 0.08, 0.19)
const PANEL := Color(0.17, 0.14, 0.28)
const PANEL_BORDER := Color(0.35, 0.30, 0.50)
const TEXT := Color(1, 1, 1)
const TEXT_SUB := Color(0.80, 0.78, 0.90)
const DIMMED := Color(0.45, 0.45, 0.50)

const HP := Color(0.85, 0.27, 0.30)
const HP_BACK := Color(0.25, 0.10, 0.12)
const ARMOR := Color(0.45, 0.68, 0.90)
const HEAL := Color(0.45, 0.85, 0.45)
const DAMAGE := Color(1.0, 0.42, 0.42)
const MANA := Color(0.30, 0.62, 1.0)
const HIGHLIGHT := Color(1.0, 0.85, 0.30)
const SELECTED := Color(1.0, 0.55, 0.20)
const INTENT := Color(1.0, 0.90, 0.60)
## 毒のダメージ・状態効果の演出の色
const POISON := Color(0.60, 0.90, 0.30)
const STATUS := Color(0.85, 0.70, 1.0)
const BUTTON := Color(0.30, 0.26, 0.48)
## 目立たせたいボタン（ターン終了など）
const BUTTON_ACCENT := Color(0.85, 0.45, 0.20)

const CATALYST_RED := Color(0.90, 0.32, 0.32)
const CATALYST_BLUE := Color(0.33, 0.52, 0.92)
const CATALYST_GREEN := Color(0.33, 0.78, 0.42)

## キャラクターの図形の色（絵に差し替えるまでの仮）
const BODY_HERO := Color(0.55, 0.40, 0.85)
const BODY_ALLY := Color(0.35, 0.65, 0.55)
const BODY_ENEMY := Color(0.60, 0.30, 0.30)
const BODY_BOSS := Color(0.45, 0.15, 0.35)


## レアリティごとのカードの枠の色
static func rarity_color(rarity: GameEnums.Rarity) -> Color:
	match rarity:
		GameEnums.Rarity.UNCOMMON:
			return Color(0.35, 0.75, 0.95)
		GameEnums.Rarity.RARE:
			return Color(0.95, 0.80, 0.30)
		GameEnums.Rarity.LEGEND:
			return Color(0.95, 0.45, 0.85)
	return Color(0.70, 0.70, 0.72)


## カードの種別ごとの色（カードの絵の場所の仮の色）
static func card_type_color(card_type: GameEnums.CardType) -> Color:
	match card_type:
		GameEnums.CardType.SUMMON:
			return Color(0.30, 0.55, 0.45)
		GameEnums.CardType.ATTACK:
			return Color(0.60, 0.28, 0.25)
		GameEnums.CardType.BUFF:
			return Color(0.28, 0.40, 0.65)
	return Color(0.45, 0.35, 0.60)


## 角の丸い四角形の見た目を作る
static func make_box(color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0, radius: int = 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border_color
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(maxf(6.0, border_width + 4.0))
	return box


## ボタンの見た目を、指定した色で整える（押せない時は暗く）
static func style_button(button: Button, color: Color) -> void:
	button.add_theme_stylebox_override("normal", make_box(color, color.lightened(0.3), 2, 14))
	button.add_theme_stylebox_override("hover", make_box(color.lightened(0.12), color.lightened(0.4), 2, 14))
	button.add_theme_stylebox_override("pressed", make_box(color.darkened(0.2), color.lightened(0.3), 2, 14))
	button.add_theme_stylebox_override("disabled", make_box(color.darkened(0.6), color.darkened(0.3), 2, 14))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
