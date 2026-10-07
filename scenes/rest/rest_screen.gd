extends Control
## 休憩画面。「HP回復」「カード削除」「カードランダム交換」から1つだけ選ぶ。
## 削除・交換は所持カードの一覧から対象を選ぶ。終わったら「進む」でマップへ

enum Action { NONE, REMOVE, EXCHANGE }

var _pending: Action = Action.NONE
var _card_popup: CardListPopup


func _ready() -> void:
	for button: Button in [%HealButton, %RemoveButton, %ExchangeButton]:
		UiPalette.style_button(button, UiPalette.BUTTON)
	UiPalette.style_button(%ProceedButton, UiPalette.BUTTON_ACCENT)
	var run := Game.run
	var heal_amount := ceili(run.get_max_hp() * run.config.rest_heal_percent / 100.0)
	%HealButton.text = UiText.fmt("UI_REST_HEAL", {"amount": heal_amount})
	%MessageLabel.text = UiText.t("UI_REST_DESC")
	%RemoveButton.disabled = not RestActions.can_remove(run)
	%HealButton.pressed.connect(heal)
	%RemoveButton.pressed.connect(func() -> void: _choose_card(Action.REMOVE, "UI_REST_REMOVE_TITLE"))
	%ExchangeButton.pressed.connect(func() -> void: _choose_card(Action.EXCHANGE, "UI_REST_EXCHANGE_TITLE"))
	%ProceedButton.pressed.connect(Game.finish_node)
	_card_popup = CardListPopup.new()
	add_child(_card_popup)
	_card_popup.card_chosen.connect(_on_card_chosen)
	_update_hp()


func heal() -> void:
	var amount := RestActions.heal(Game.run)
	_finish(UiText.fmt("UI_REST_HEAL_RESULT", {"amount": amount}))


## 削除・交換で、所持カードの deck_index 番目を選んだ時
func choose_card(action: Action, deck_index: int) -> void:
	var run := Game.run
	if action == Action.REMOVE:
		var removed := RestActions.remove_card(run, deck_index)
		_finish(UiText.fmt("UI_REST_REMOVE_RESULT", {"card": UiText.t(removed.name_key)}))
	elif action == Action.EXCHANGE:
		var old_card := run.deck[deck_index]
		var new_card := RestActions.exchange_card(run, deck_index)
		_finish(UiText.fmt("UI_REST_EXCHANGE_RESULT", {"old": UiText.t(old_card.name_key), "new": UiText.t(new_card.name_key)}))


func _choose_card(action: Action, title_key: String) -> void:
	_pending = action
	_card_popup.open_select(UiText.t(title_key), Game.run.deck)


func _on_card_chosen(index: int) -> void:
	choose_card(_pending, index)


## 1つ選んだら、選択肢を隠して結果と「進む」を出す
func _finish(message: String) -> void:
	%Choices.hide()
	%MessageLabel.text = message
	%ProceedButton.show()
	_update_hp()


func _update_hp() -> void:
	%HpLabel.text = UiText.fmt("UI_MAP_HP", {"hp": Game.run.hp, "max": Game.run.get_max_hp()})
