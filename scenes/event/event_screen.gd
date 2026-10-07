extends Control
## イベント画面。説明文と選択肢を出し、選んだら結果の文章と「進む」を出す。
## 所持カードを選ぶ必要がある選択肢（カード交換）は、カードの一覧から選ぶ

var event: EventData
var _pending_choice: EventChoiceData
var _card_popup: CardListPopup


func _ready() -> void:
	event = Game.run.current_node.event
	UiPalette.style_button(%ProceedButton, UiPalette.BUTTON_ACCENT)
	%ProceedButton.pressed.connect(Game.finish_node)
	_card_popup = CardListPopup.new()
	add_child(_card_popup)
	_card_popup.card_chosen.connect(func(index: int) -> void: _resolve(_pending_choice, index))
	%TitleLabel.text = UiText.t(event.name_key)
	%MessageLabel.text = UiText.t(event.description_key)
	for choice: EventChoiceData in event.choices:
		var button := Button.new()
		button.text = UiText.fmt(choice.text_key, choice.get_text_params())
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(0, 96)
		button.add_theme_font_size_override("font_size", 26)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiPalette.style_button(button, UiPalette.BUTTON)
		button.pressed.connect(choose.bind(choice))
		%Choices.add_child(button)
	_update_hp()


## 選択肢を選ぶ
func choose(choice: EventChoiceData) -> void:
	if EventResolver.needs_card_choice(choice):
		_pending_choice = choice
		_card_popup.open_select(UiText.t("UI_EVENT_CHOOSE_CARD"), Game.run.deck)
	else:
		_resolve(choice, -1)


func _resolve(choice: EventChoiceData, deck_index: int) -> void:
	var result := EventResolver.apply(Game.run, choice, deck_index)
	var lines := PackedStringArray([UiText.fmt(choice.result_key, choice.get_text_params())])
	for card: CardData in result["lost"]:
		lines.append(UiText.fmt("UI_EVENT_LOST", {"card": UiText.t(card.name_key)}))
	for card: CardData in result["gained"]:
		lines.append(UiText.fmt("UI_EVENT_GAINED", {"card": UiText.t(card.name_key)}))
	%Choices.hide()
	%MessageLabel.text = "\n".join(lines)
	%ProceedButton.show()
	_update_hp()


func _update_hp() -> void:
	%HpLabel.text = UiText.fmt("UI_MAP_HP", {"hp": Game.run.hp, "max": Game.run.get_max_hp()})
