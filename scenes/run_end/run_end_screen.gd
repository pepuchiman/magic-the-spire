extends Control
## ランの終わりの画面（ゲームオーバー画面とクリア画面を兼ねる）
## ・ゲームオーバー：到達した階、倒した敵の数
## ・クリア：使用した主人公、最終デッキの枚数、新しく解放された要素
## どちらもプレイ時間を表示する（1周の時間の確認用）


func _ready() -> void:
	UiPalette.style_button(%BackToTitleButton, UiPalette.BUTTON_ACCENT)
	%BackToTitleButton.pressed.connect(Game.go_to_title)
	var run := Game.run
	var lines := PackedStringArray()
	if run.cleared:
		%TitleLabel.text = UiText.t("UI_CLEAR_TITLE")
		%TitleLabel.add_theme_color_override("font_color", UiPalette.HIGHLIGHT)
		lines.append(UiText.fmt("UI_RESULT_HERO", {"hero": UiText.t(run.hero.name_key)}))
		lines.append(UiText.fmt("UI_RESULT_DECK", {"count": run.deck.size()}))
		for item: Resource in Game.newly_unlocked:
			lines.append(UiText.fmt(_unlock_key(item), {"name": UiText.t(item.get("name_key"))}))
	else:
		%TitleLabel.text = UiText.t("UI_GAME_OVER_TITLE")
		%TitleLabel.add_theme_color_override("font_color", UiPalette.DAMAGE)
		lines.append(UiText.fmt("UI_RESULT_FLOOR", {"floor": run.current_floor_number()}))
		lines.append(UiText.fmt("UI_RESULT_DEFEATED", {"count": run.enemies_defeated}))
	var seconds := int(run.play_seconds)
	lines.append(UiText.fmt("UI_PLAY_TIME", {"minutes": floori(seconds / 60.0), "seconds": seconds % 60}))
	%DetailsLabel.text = "\n\n".join(lines)


## 新しく解放されたものの種類ごとの文章のキー
func _unlock_key(item: Resource) -> String:
	if item is HeroData:
		return "UI_NEW_UNLOCK_HERO"
	if item is DungeonData:
		return "UI_NEW_UNLOCK_DUNGEON"
	return "UI_NEW_UNLOCK_CARD"
