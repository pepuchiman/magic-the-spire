class_name AutoRun
extends RefCounted
## ラン1周の自動プレイ（動作確認・テスト用。ゲームのAIではない）
## ・進めるノードのうち左端を選ぶ
## ・バトルは AutoPlayer で進め、報酬は1枚目を取る。装備・宝箱の中身は必ず取る
## ・イベントは最初の選択肢（カードを選ぶ必要があれば、所持カードの1枚目）
## ・休憩はHP回復

const MAX_STEPS := 200


## 1周を最後まで進める。経過の記録を返す
static func play(run: RunState) -> PackedStringArray:
	var log := PackedStringArray()
	for step in MAX_STEPS:
		if run.finished:
			break
		var nodes := run.available_nodes()
		if nodes.is_empty():
			break
		var node := nodes[0]
		run.move_to(node)
		var label := "%d階 %s" % [run.current_floor_number(), GameEnums.MapNodeType.keys()[node.type]]
		match node.type:
			GameEnums.MapNodeType.BATTLE, GameEnums.MapNodeType.ELITE, GameEnums.MapNodeType.BOSS:
				var battle := run.create_battle()
				var result := AutoPlayer.run(battle)
				if result == null:
					result = BattleResult.new(false, 0, [], battle.turn)
				run.apply_battle_result(result)
				log.append("%s %s：%s（%dターン、HP %d）" % [label, node.enemy.id, "勝利" if result.won else "敗北", result.turns, run.hp])
				if result.won and not run.finished:
					var choices := RewardGenerator.card_choices(run, node.type)
					if not choices.is_empty():
						RewardGenerator.take(run, choices[0])
					var item := RewardGenerator.equipment_reward(run, node.type)
					if item != null:
						RewardGenerator.equip(run, item)
						log.append("　装備：%s" % item.id)
			GameEnums.MapNodeType.TREASURE:
				var content := RewardGenerator.treasure(run)
				if content.has("equipment"):
					RewardGenerator.equip(run, content["equipment"])
					log.append("%s：装備 %s" % [label, content["equipment"].id])
				else:
					RewardGenerator.take(run, content["card"])
					log.append("%s：カード %s" % [label, content["card"].id])
			GameEnums.MapNodeType.EVENT:
				var choice: EventChoiceData = node.event.choices[0]
				var outcome := EventResolver.apply(run, choice, 0 if EventResolver.needs_card_choice(choice) else -1)
				log.append("%s %s：HP%+d、獲得%d枚" % [label, node.event.id, outcome["hp_change"], outcome["gained"].size()])
			GameEnums.MapNodeType.REST:
				log.append("%s：HP %d 回復" % [label, RestActions.heal(run)])
	log.append("結果：%s（%d階、倒した敵%d体、デッキ%d枚、HP %d）" % [
		"クリア" if run.cleared else "ゲームオーバー", run.current_floor_number(), run.enemies_defeated, run.deck.size(), run.hp])
	return log
