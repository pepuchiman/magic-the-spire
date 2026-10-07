extends SceneTree
## ラン1周を自動で最後まで進め、経過を表示するツール（画面なし）。
## 実行：godot --headless -s tools/simulate_run.gd -- seed=1 hero=flame_mage dungeon=lost_forest
## （-- の後ろは省略可）。アンロックの状況は使わず、すべてのカードを解放した状態で進める


func _init() -> void:
	var options := {"seed": "1", "hero": "flame_mage", "dungeon": "lost_forest"}
	for arg: String in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	var loader := DataLoader.new()
	var hero := loader.get_hero(StringName(options["hero"]))
	var dungeon := loader.get_dungeon(StringName(options["dungeon"]))
	if hero == null or dungeon == null:
		printerr("主人公またはダンジョンが見つかりません")
		quit(1)
		return
	var run := RunState.new(hero, dungeon, loader.index.cards, loader.get_config(), int(options["seed"]), loader.index.equipment)
	for line: String in AutoRun.play(run):
		print(line)
	quit()
