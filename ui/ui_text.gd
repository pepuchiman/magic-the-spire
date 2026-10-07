class_name UiText
extends RefCounted
## 画面に出す文章を、翻訳キーと数値から作る関数をまとめたもの


## 翻訳キーを、現在の言語の文章にする
static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


## 翻訳した文章に数値などを差し込む（例：fmt("UI_MANA", {"current": 3, "base": 5})）
static func fmt(key: String, params: Dictionary) -> String:
	return t(key).format(params)


## 敵の行動予告の文章（例：「攻撃 3〜5」「防御 4」）
static func intent_text(enemy: EnemyCombatant) -> String:
	var action := enemy.intent
	if action == null:
		return t("UI_INTENT_NONE")
	match action.action_type:
		GameEnums.EnemyActionType.ATTACK:
			if enemy.data.attack_min == enemy.data.attack_max:
				return t("UI_INTENT_ATTACK_FIXED").format({"amount": enemy.data.attack_min})
			return t("UI_INTENT_ATTACK").format({"min": enemy.data.attack_min, "max": enemy.data.attack_max})
		GameEnums.EnemyActionType.DEFEND:
			return t("UI_INTENT_DEFEND").format({"amount": action.amount})
		GameEnums.EnemyActionType.SUMMON:
			return t("UI_INTENT_SUMMON")
	return ""


## 状態効果（補正）の一覧の文章。「永続」は基本パラメーターに反映されるため表示しない
static func status_text(combatant: Combatant) -> String:
	var lines := PackedStringArray()
	for modifier: StatModifier in combatant.modifiers:
		var params := {
			"param": t(TextKeys.param(modifier.param)),
			"amount": "%+d" % modifier.amount,
			"turns": modifier.remaining_turns,
		}
		match modifier.duration:
			GameEnums.Duration.TURNS:
				lines.append(t("UI_STATUS_TURNS").format(params))
			GameEnums.Duration.BATTLE:
				lines.append(t("UI_STATUS_BATTLE").format(params))
	return "\n".join(lines)


## 装備の効果の一覧（例：「最大HP +4」）
static func equipment_effect_lines(item: EquipmentData) -> PackedStringArray:
	var lines := PackedStringArray()
	for modifier: ModifyParamEffect in item.modifiers:
		if modifier != null:
			lines.append(fmt("UI_EQUIP_EFFECT", {"param": t(TextKeys.param(modifier.param)), "amount": "%+d" % modifier.amount}))
	return lines


## 今の装備（current、無ければ null）から新しい装備に替えた時の、パラメーターの変化の一覧
static func equipment_diff_lines(current: EquipmentData, new_item: EquipmentData) -> PackedStringArray:
	var params: Array[int] = []
	for item: EquipmentData in [current, new_item]:
		if item == null:
			continue
		for modifier: ModifyParamEffect in item.modifiers:
			if modifier != null and not params.has(modifier.param):
				params.append(modifier.param)
	var lines := PackedStringArray()
	for param: int in params:
		var before := current.get_amount(param) if current != null else 0
		var after := new_item.get_amount(param)
		if before == after:
			continue
		lines.append(fmt("UI_EQUIP_DIFF", {"param": t(TextKeys.param(param)),
			"before": "%+d" % before, "after": "%+d" % after, "change": "%+d" % (after - before)}))
	if lines.is_empty():
		lines.append(t("UI_EQUIP_SAME"))
	return lines


## 解放条件の文章（例：「迷いの森」をクリアすると解放）
static func unlock_condition(dungeon: DungeonData) -> String:
	return fmt("UI_UNLOCK_CONDITION", {"dungeon": t(dungeon.name_key) if dungeon != null else "?"})


## カードを使えない理由の文章（使える時は空）
static func cannot_play_text(result: Battle.PlayResult) -> String:
	match result:
		Battle.PlayResult.NOT_ENOUGH_MANA:
			return t("UI_CANNOT_PLAY_MANA")
		Battle.PlayResult.CATALYST_NOT_MET:
			return t("UI_CANNOT_PLAY_CATALYST")
	return ""
