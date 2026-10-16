extends GutTest
## 設定（音量・演出の速さ）と設定画面、画面切り替えの暗転のテスト。
## 設定のファイルは一時ファイルを使う（本物の settings.cfg は変更しない）

const TEST_PATH := "user://test_settings.cfg"
const SCREEN_SCENE := preload("res://scenes/battle/battle_screen.tscn")

var _real_settings: SettingsStore


func before_each() -> void:
	TranslationServer.set_locale("ja")
	DirAccess.remove_absolute(TEST_PATH)
	_real_settings = Game.settings
	Game.settings = SettingsStore.new(TEST_PATH)  # テスト中は一時ファイルの設定にする


func after_each() -> void:
	Game.settings = _real_settings
	Game.apply_settings()
	DirAccess.remove_absolute(TEST_PATH)


func test_settings_save_and_load() -> void:
	var store := SettingsStore.new(TEST_PATH)
	store.load_settings()
	assert_eq(store.bgm_volume, 0.7, "ファイルが無ければ初期値")
	assert_eq(store.animation_speed, SettingsStore.SPEED_NORMAL)
	store.bgm_volume = 0.25
	store.se_volume = 0.5
	store.animation_speed = SettingsStore.SPEED_FAST
	store.save_settings()
	var loaded := SettingsStore.new(TEST_PATH)
	loaded.load_settings()
	assert_eq(loaded.bgm_volume, 0.25)
	assert_eq(loaded.se_volume, 0.5)
	assert_eq(loaded.animation_speed, SettingsStore.SPEED_FAST)


func test_strange_values_fall_back() -> void:
	var file := ConfigFile.new()
	file.set_value(SettingsStore.SECTION, "bgm_volume", 5.0)
	file.set_value(SettingsStore.SECTION, "animation_speed", 2.3)
	file.save(TEST_PATH)
	var store := SettingsStore.new(TEST_PATH)
	store.load_settings()
	assert_eq(store.bgm_volume, 1.0, "音量は 0〜1 に収める")
	assert_eq(store.animation_speed, SettingsStore.SPEED_NORMAL, "選択肢にない速さは「ふつう」")


func test_apply_settings_changes_bus_volume() -> void:
	var sound: Node = get_tree().root.get_node("Sound")
	Game.settings.bgm_volume = 0.3
	Game.settings.se_volume = 0.0
	Game.apply_settings()
	assert_almost_eq(sound.get_volume(&"BGM"), 0.3, 0.01, "BGM の音量が変わる")
	assert_eq(sound.get_volume(&"SE"), 0.0, "0 なら効果音は消音")


func test_battle_uses_settings_speed() -> void:
	var screen: BattleScreen = SCREEN_SCENE.instantiate()
	screen.auto_start = false
	add_child_autofree(screen)
	Game.settings.animation_speed = SettingsStore.SPEED_FAST
	assert_eq(screen.effective_speed(), SettingsStore.SPEED_FAST, "初期値（-1）なら設定の速さを使う")
	screen.animation_speed = 0.0
	assert_eq(screen.effective_speed(), 0.0, "直接指定した時はその値（テスト用の 0 など）")


func test_settings_panel_changes_and_saves() -> void:
	var panel := SettingsPanel.new()
	add_child_autofree(panel)
	panel.open()
	assert_true(panel.visible)
	assert_eq(panel.bgm_slider.value, 70.0, "今の設定が表示される")
	panel.set_speed(SettingsStore.SPEED_SLOW)
	panel.bgm_slider.value = 40.0
	var saved := SettingsStore.new(TEST_PATH)
	saved.load_settings()
	assert_eq(saved.animation_speed, SettingsStore.SPEED_SLOW, "演出の速さを変えると保存される")
	assert_almost_eq(saved.bgm_volume, 0.4, 0.001, "音量を変えると保存される")
	panel.close_panel()
	assert_false(panel.visible, "閉じるボタンで閉じる")


func test_no_fade_when_screens_are_not_changed() -> void:
	var before := Game.change_scenes
	Game.change_scenes = false
	Game.go_to(Game.Screen.TITLE)
	assert_false(Game._fader.is_fading(), "画面を切り替えない時（テスト）は暗転しない")
	Game.change_scenes = before
