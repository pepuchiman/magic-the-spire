extends SceneTree
## サンプルデータで1バトルを自動で最後まで進め、経過を表示するツール。
## 実行：godot --headless -s tools/simulate_battle.gd -- seed=1 enemy=boss_witch hero=flame_mage
## （-- の後ろは省略可。省略時は seed=1、enemy=boss_witch、hero=flame_mage）


func _init() -> void:
	var options := {"seed": "1", "enemy": "boss_witch", "hero": "flame_mage"}
	for arg: String in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]

	var loader := DataLoader.new()
	var hero := loader.get_hero(StringName(options["hero"]))
	var enemy := loader.get_enemy(StringName(options["enemy"]))
	if hero == null or enemy == null:
		printerr("主人公または敵が見つかりません：%s / %s" % [options["hero"], options["enemy"]])
		quit(1)
		return

	var battle := Battle.new(hero, hero.starting_deck, enemy, int(options["seed"]))
	var result := AutoPlayer.run(battle)
	for line: String in battle.history:
		print(line)
	if result == null:
		printerr("規定のターン数で終わりませんでした")
		quit(1)
		return
	print("結果：%s（%dターン、主人公の残りHP %d）シード=%s" % ["勝利" if result.won else "敗北", result.turns, result.hero_hp, options["seed"]])
	quit()
