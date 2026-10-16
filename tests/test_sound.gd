extends GutTest
## 効果音・BGM のテスト（画面なしでは音は出ないので、鳴らす指示が出たかを Sound の記録で確かめる）

const SCREEN_SCENE := preload("res://scenes/battle/battle_screen.tscn")

var sound: Node


func before_each() -> void:
	TranslationServer.set_locale("ja")
	sound = get_tree().root.get_node("Sound")
	sound.history.clear()


func test_all_sounds_are_registered_and_loadable() -> void:
	var sounds := DataLoader.new().get_sounds()
	assert_eq(DataValidator._check_sounds(sounds).size(), 0, "全種類の音が登録されていて、ファイルがある")
	for stream: AudioStream in sounds.event_sounds.values() + sounds.music.values():
		assert_gt(stream.get_length(), 0.0, "音のファイルが読み込める：%s" % stream.resource_path)


func test_missing_sound_is_reported() -> void:
	var sounds := DataLoader.new().get_sounds().duplicate()
	sounds.music = sounds.music.duplicate()
	sounds.music.erase(GameEnums.Music.BOSS)
	var errors := DataValidator._check_sounds(sounds)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "BOSS")


func test_button_plays_sound() -> void:
	var button := Button.new()
	add_child_autofree(button)
	UiPalette.style_button(button, UiPalette.BUTTON)
	UiPalette.style_button(button, UiPalette.BUTTON)  # 2回整えても、音は1回だけ
	button.pressed.emit()
	assert_eq(Array(sound.history).count("se:BUTTON"), 1, "ボタンを押すとボタンの音が1回鳴る")


func test_music_follows_screen() -> void:
	assert_eq(Game.music_for(Game.Screen.TITLE), GameEnums.Music.TITLE)
	assert_eq(Game.music_for(Game.Screen.REWARD), GameEnums.Music.MAP, "報酬の画面はマップの曲")
	assert_eq(Game.music_for(Game.Screen.BATTLE), GameEnums.Music.BATTLE)
	sound.play_music(GameEnums.Music.MAP)
	sound.play_music(GameEnums.Music.MAP)
	assert_eq(Array(sound.history).count("bgm:MAP"), 1, "同じ曲なら切り替えない")
	assert_eq(sound.current_music, GameEnums.Music.MAP)


func test_volume_can_be_changed() -> void:
	var before: float = sound.get_volume(&"SE")
	sound.set_volume(&"SE", 0.5)
	assert_almost_eq(sound.get_volume(&"SE"), 0.5, 0.01)
	sound.set_volume(&"SE", 0.0)
	assert_eq(sound.get_volume(&"SE"), 0.0, "0 なら消音")
	sound.set_volume(&"SE", before)


func test_card_play_makes_sounds() -> void:
	var screen: BattleScreen = SCREEN_SCENE.instantiate()
	screen.animation_speed = 3.0
	screen.seed_value = 1
	add_child_autofree(screen)
	await wait_frames(2)
	await wait_for_signal(screen.animations_finished, 10.0)
	sound.history.clear()
	var played := _play_first_card(screen)
	await wait_for_signal(screen.animations_finished, 10.0)
	assert_true(sound.history.has("se:CARD_PLAY"), "カードを使うとカードの音が鳴る")
	if played.visual_effect != GameEnums.CardEffect.NONE:
		assert_true(sound.history.has("card:%s" % GameEnums.CardEffect.find_key(played.visual_effect)), "カードの効果の音が鳴る")


func test_no_battle_sounds_when_animation_is_off() -> void:
	var screen: BattleScreen = SCREEN_SCENE.instantiate()
	screen.animation_speed = 0.0
	screen.seed_value = 1
	add_child_autofree(screen)
	sound.history.clear()
	_play_first_card(screen)
	assert_false(sound.history.has("se:CARD_PLAY"), "演出の速さが0なら、バトルの音は鳴らさない")


func _play_first_card(screen: BattleScreen) -> CardData:
	var battle := screen.battle
	for i in battle.deck.hand.size():
		var card: CardData = battle.deck.hand[i].data
		if battle.get_cost_problem(card) == Battle.PlayResult.OK and not battle.needs_replace(card):
			screen.try_play_card(i, AutoPlayer.choose_target(battle, card))
			return card
	fail_test("使えるカードがない")
	return null


func after_all() -> void:
	# 鳴らした BGM を止めて、音のデータを手放す（テストの終わりにデータが残ったままにならないように）
	get_tree().root.get_node("Sound").stop_all()
	await get_tree().create_timer(0.2).timeout
