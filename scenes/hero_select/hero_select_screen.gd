extends Control
## 主人公選択画面。初期パラメーターと初期デッキを確認して「決定」でランを始める。
## 主人公が複数いる時は「<」「>」で切り替える（スワイプ操作はフェーズ8の調整で検討）

var heroes: Array[HeroData] = []
var index: int = 0
var _deck_popup: CardListPopup


func _ready() -> void:
	heroes = Game.data.index.heroes
	for button: Button in [%PrevButton, %NextButton, %DeckButton, %BackButton]:
		UiPalette.style_button(button, UiPalette.BUTTON)
	UiPalette.style_button(%ConfirmButton, UiPalette.BUTTON_ACCENT)
	%PrevButton.pressed.connect(func() -> void: _show(index - 1))
	%NextButton.pressed.connect(func() -> void: _show(index + 1))
	%DeckButton.pressed.connect(_open_deck)
	%BackButton.pressed.connect(func() -> void: Game.go_to(Game.Screen.DUNGEON_SELECT))
	%ConfirmButton.pressed.connect(confirm)
	_deck_popup = CardListPopup.new()
	add_child(_deck_popup)
	var several := heroes.size() > 1
	%PrevButton.visible = several
	%NextButton.visible = several
	_show(0)


func current_hero() -> HeroData:
	return heroes[index] if not heroes.is_empty() else null


func confirm() -> void:
	if current_hero() != null:
		Game.start_run(current_hero())


func _show(new_index: int) -> void:
	if heroes.is_empty():
		return
	index = wrapi(new_index, 0, heroes.size())
	var hero := heroes[index]
	%HeroNameLabel.set_fitted_text(UiText.t(hero.name_key))
	var lines := PackedStringArray([
		UiText.fmt("UI_HERO_STAT_HP", {"value": hero.max_hp}),
		UiText.fmt("UI_HERO_STAT_MANA", {"value": hero.mana_base}),
		UiText.fmt("UI_HERO_STAT_DRAW", {"value": hero.draw_count}),
		UiText.fmt("UI_HERO_STAT_HAND", {"value": hero.max_hand}),
	])
	var colors := ["UI_CATALYST_RED", "UI_CATALYST_BLUE", "UI_CATALYST_GREEN"]
	var values := [hero.catalyst_red, hero.catalyst_blue, hero.catalyst_green]
	var powers := [hero.catalyst_power_red, hero.catalyst_power_blue, hero.catalyst_power_green]
	for i in 3:
		if values[i] > 0 or powers[i] > 0:
			lines.append(UiText.fmt("UI_HERO_STAT_CATALYST", {"color": UiText.t(colors[i]), "value": values[i], "power": powers[i]}))
	%StatsLabel.text = "\n".join(lines)


func _open_deck() -> void:
	var hero := current_hero()
	_deck_popup.open_view(UiText.fmt("UI_STARTING_DECK_TITLE", {"count": hero.starting_deck.size()}), hero.starting_deck)
