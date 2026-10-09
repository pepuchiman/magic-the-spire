extends SceneTree
## サンプルデータ（.tres）を生成するツール。
## 実行：godot --headless -s tools/generate_sample_data.gd
## すでにあるファイルは上書きしない（インスペクターで調整した値を守るため）。
## サンプルの数値はすべて「仮置き」。後から差し替える。

const HERO_ID := &"flame_mage"
const FROST_HERO_ID := &"frost_mage"
## 両方の主人公が使えるカード（無色・緑・複数色など）
const BOTH: Array[StringName] = [&"flame_mage", &"frost_mage"]
const FROST_ONLY: Array[StringName] = [&"frost_mage"]
## 2つ目のダンジョン・2人目の主人公・解放カードの解放条件（このダンジョンのクリア）
const FIRST_DUNGEON_ID := &"lost_forest"


func _init() -> void:
	var results: Array = []

	# --- 仲間 ---
	var sprite := _ally(&"fire_sprite", "ALLY_FIRE_SPRITE_NAME", 10, 3, 5, GameEnums.Race.SPIRIT, GameEnums.AttackEffect.FIRE)
	var wolf := _ally(&"forest_wolf", "ALLY_FOREST_WOLF_NAME", 16, 4, 6, GameEnums.Race.BEAST, GameEnums.AttackEffect.PIERCE)
	results.append(_save_new(sprite, "res://data/allies/fire_sprite.tres"))
	results.append(_save_new(wolf, "res://data/allies/forest_wolf.tres"))
	sprite = results[0]
	wolf = results[1]

	# --- カード ---
	# 単体が対象のカードは「敵と自分とクリーチャーのいずれか1体」（ANY）にする
	# 赤のカードは炎の魔法使いだけ、青だけのカードは氷の魔法使いだけ、それ以外は両方が使える
	var spark := _card(&"spark", "SPARK", GameEnums.CardType.ATTACK, GameEnums.Rarity.COMMON, [GameEnums.Target.ANY], 1, 0, 0, 0, [_damage(6)], BOTH)
	var guard := _card(&"guard", "GUARD", GameEnums.CardType.BUFF, GameEnums.Rarity.COMMON, [GameEnums.Target.ANY], 1, 0, 0, 0, [_armor(5)], BOTH)
	var fireball := _card(&"fireball", "FIREBALL", GameEnums.CardType.ATTACK, GameEnums.Rarity.COMMON, [GameEnums.Target.ANY], 2, 1, 0, 0, [_damage(12)])
	var frost_lance := _card(&"frost_lance", "FROST_LANCE", GameEnums.CardType.ATTACK, GameEnums.Rarity.COMMON, [GameEnums.Target.ANY], 2, 0, 1, 0, [_damage(10)], BOTH)
	var meditation := _card(&"meditation", "MEDITATION", GameEnums.CardType.BUFF, GameEnums.Rarity.UNCOMMON, [GameEnums.Target.SELF], 1, 0, 0, 0, [_draw(2)], BOTH)
	var heal := _card(&"heal", "HEAL", GameEnums.CardType.BUFF, GameEnums.Rarity.COMMON, [GameEnums.Target.ANY], 2, 0, 0, 1, [_heal(6)], BOTH)
	var steam_blast := _card(&"steam_blast", "STEAM_BLAST", GameEnums.CardType.ATTACK, GameEnums.Rarity.UNCOMMON, [GameEnums.Target.ANY], 3, 1, 1, 0, [_damage(18)], BOTH)
	var summon_sprite := _card(&"summon_sprite", "SUMMON_SPRITE", GameEnums.CardType.SUMMON, GameEnums.Rarity.COMMON, [GameEnums.Target.SPACE], 2, 1, 0, 0, [_summon(sprite)])
	var summon_wolf := _card(&"summon_wolf", "SUMMON_WOLF", GameEnums.CardType.SUMMON, GameEnums.Rarity.UNCOMMON, [GameEnums.Target.SPACE], 3, 0, 0, 1, [_summon(wolf)], BOTH)
	var mana_surge := _card(&"mana_surge", "MANA_SURGE", GameEnums.CardType.BUFF, GameEnums.Rarity.RARE, [GameEnums.Target.SELF], 1, 0, 0, 0, [_modify(GameEnums.Param.MANA_BASE, 1)], BOTH)
	mana_surge.duration = GameEnums.Duration.BATTLE
	# フェーズ5で追加したカード（レア・レジェンドと青のカード）
	var ice_wall := _card(&"ice_wall", "ICE_WALL", GameEnums.CardType.BUFF, GameEnums.Rarity.UNCOMMON, [GameEnums.Target.ANY], 1, 0, 1, 0, [_armor(10)], FROST_ONLY)
	var arcane_burst := _card(&"arcane_burst", "ARCANE_BURST", GameEnums.CardType.ATTACK, GameEnums.Rarity.UNCOMMON, [GameEnums.Target.ANY], 1, 0, 0, 0, [_damage(9)], BOTH)
	var inferno := _card(&"inferno", "INFERNO", GameEnums.CardType.ATTACK, GameEnums.Rarity.RARE, [GameEnums.Target.ANY], 3, 3, 0, 0, [_damage(24)])
	var blizzard := _card(&"blizzard", "BLIZZARD", GameEnums.CardType.ATTACK, GameEnums.Rarity.RARE, [GameEnums.Target.ANY], 3, 0, 3, 0, [_damage(20)], FROST_ONLY)
	var elixir := _card(&"elixir", "ELIXIR", GameEnums.CardType.BUFF, GameEnums.Rarity.LEGEND, [GameEnums.Target.ANY], 1, 0, 0, 0, [_heal(15)], BOTH)
	var meteor := _card(&"meteor", "METEOR", GameEnums.CardType.ATTACK, GameEnums.Rarity.LEGEND, [GameEnums.Target.ANY], 4, 2, 2, 0, [_damage(40)], BOTH)
	meteor.unlocked_by_clearing = FIRST_DUNGEON_ID  # 迷いの森をクリアすると報酬に出る
	# 1戦闘あたりの使用回数（仮の値。0 は制限なし）
	steam_blast.uses_per_battle = 2
	summon_wolf.uses_per_battle = 1
	mana_surge.uses_per_battle = 1
	elixir.uses_per_battle = 1
	meteor.uses_per_battle = 1

	# 状態効果のカード（docs/Game_Elements.md）
	var S := GameEnums.StatusType
	var poison_mist := _card(&"poison_mist", "POISON_MIST", GameEnums.CardType.BUFF, GameEnums.Rarity.COMMON, [GameEnums.Target.ANY], 1, 0, 0, 1, [_status(S.POISON, 4)], BOTH)
	var thunderbolt := _card(&"thunderbolt", "THUNDERBOLT", GameEnums.CardType.ATTACK, GameEnums.Rarity.UNCOMMON, [GameEnums.Target.ANY], 2, 0, 1, 0, [_damage(5), _status(S.PARALYSIS, 1)], BOTH)
	var curse := _card(&"curse", "CURSE", GameEnums.CardType.BUFF, GameEnums.Rarity.COMMON, [GameEnums.Target.ANY], 1, 0, 0, 0, [_status(S.WEAK, 1)], BOTH)
	curse.duration = GameEnums.Duration.TURNS
	curse.duration_turns = 2
	var shatter_mark := _card(&"shatter_mark", "SHATTER_MARK", GameEnums.CardType.BUFF, GameEnums.Rarity.UNCOMMON, [GameEnums.Target.ANY], 1, 1, 0, 0, [_status(S.VULNERABLE, 1)])
	shatter_mark.duration = GameEnums.Duration.TURNS
	shatter_mark.duration_turns = 2
	var power_chant := _card(&"power_chant", "POWER_CHANT", GameEnums.CardType.BUFF, GameEnums.Rarity.UNCOMMON, [GameEnums.Target.ANY], 1, 0, 0, 0, [_status(S.STRENGTH, 2)], BOTH)
	power_chant.duration = GameEnums.Duration.BATTLE
	var thorn_armor := _card(&"thorn_armor", "THORN_ARMOR", GameEnums.CardType.BUFF, GameEnums.Rarity.UNCOMMON, [GameEnums.Target.ANY], 1, 0, 0, 1, [_status(S.THORNS, 3)], BOTH)
	thorn_armor.duration = GameEnums.Duration.BATTLE

	var cards: Array = [spark, guard, fireball, frost_lance, meditation, heal, steam_blast, summon_sprite, summon_wolf, mana_surge,
		ice_wall, arcane_burst, inferno, blizzard, elixir, meteor,
		poison_mist, thunderbolt, curse, shatter_mark, power_chant, thorn_armor]
	for i in cards.size():
		var card: CardData = cards[i]
		cards[i] = _save_new(card, "res://data/cards/%s.tres" % card.id)
	spark = cards[0]
	guard = cards[1]
	fireball = cards[2]
	frost_lance = cards[3]
	summon_sprite = cards[7]
	ice_wall = cards[10]

	# --- 主人公（初期デッキは仮：火花4、魔力の盾3、火球2、火の精霊1） ---
	var hero := HeroData.new()
	hero.id = HERO_ID
	hero.name_key = &"HERO_FLAME_MAGE_NAME"
	hero.catalyst_red = 1
	hero.catalyst_power_red = 1
	var deck: Array[CardData] = []
	for i in 4:
		deck.append(spark)
	for i in 3:
		deck.append(guard)
	for i in 2:
		deck.append(fireball)
	deck.append(summon_sprite)
	hero.starting_deck = deck
	_save_new(hero, "res://data/heroes/flame_mage.tres")

	# --- 2人目の主人公（迷いの森のクリアで解放。初期デッキは仮：火花4、魔力の盾2、氷の壁2、氷の槍2） ---
	var frost := HeroData.new()
	frost.id = FROST_HERO_ID
	frost.name_key = &"HERO_FROST_MAGE_NAME"
	frost.unlocked_by_clearing = FIRST_DUNGEON_ID
	frost.hp = 22
	frost.max_hp = 22
	frost.catalyst_blue = 1
	frost.catalyst_power_blue = 1
	var frost_deck: Array[CardData] = []
	for i in 4:
		frost_deck.append(spark)
	for i in 2:
		frost_deck.append(guard)
	for i in 2:
		frost_deck.append(ice_wall)
	for i in 2:
		frost_deck.append(frost_lance)
	frost.starting_deck = frost_deck
	_save_new(frost, "res://data/heroes/frost_mage.tres")

	# --- 敵 ---
	var slime := _enemy(&"slime", "ENEMY_SLIME_NAME", 20, 3, 5, [_action(GameEnums.EnemyActionType.ATTACK), _action(GameEnums.EnemyActionType.ATTACK), _action(GameEnums.EnemyActionType.DEFEND, 4)])
	var goblin := _enemy(&"goblin", "ENEMY_GOBLIN_NAME", 26, 4, 7, [_action(GameEnums.EnemyActionType.ATTACK), _action(GameEnums.EnemyActionType.DEFEND, 5)])
	var bat := _enemy(&"bat", "ENEMY_BAT_NAME", 14, 2, 4, [_action(GameEnums.EnemyActionType.ATTACK), _action(GameEnums.EnemyActionType.ATTACK), _action(GameEnums.EnemyActionType.ATTACK)])
	slime = _save_new(slime, "res://data/enemies/slime.tres")
	goblin = _save_new(goblin, "res://data/enemies/goblin.tres")
	bat = _save_new(bat, "res://data/enemies/bat.tres")

	# ボス：攻撃、攻撃、スライムを呼ぶ、のループ
	var summon_action := _action(GameEnums.EnemyActionType.SUMMON)
	summon_action.summon_enemy = slime
	var boss := _enemy(&"boss_witch", "ENEMY_BOSS_WITCH_NAME", 80, 6, 10, [_action(GameEnums.EnemyActionType.ATTACK), _action(GameEnums.EnemyActionType.ATTACK), summon_action])
	boss.defense = 1
	boss = _save_new(boss, "res://data/enemies/boss_witch.tres")

	# エリート（強敵）とボス2体目
	var ogre := _enemy(&"ogre", "ENEMY_OGRE_NAME", 45, 7, 10, [_action(GameEnums.EnemyActionType.ATTACK), _action(GameEnums.EnemyActionType.ATTACK), _action(GameEnums.EnemyActionType.DEFEND, 6)])
	var call_bat := _action(GameEnums.EnemyActionType.SUMMON)
	call_bat.summon_enemy = bat
	var wraith := _enemy(&"wraith", "ENEMY_WRAITH_NAME", 36, 5, 8, [_action(GameEnums.EnemyActionType.ATTACK), call_bat, _action(GameEnums.EnemyActionType.ATTACK)])
	wraith.defense = 1
	var call_goblin := _action(GameEnums.EnemyActionType.SUMMON)
	call_goblin.summon_enemy = goblin
	var frost_giant := _enemy(&"frost_giant", "ENEMY_FROST_GIANT_NAME", 95, 7, 11, [_action(GameEnums.EnemyActionType.ATTACK), _action(GameEnums.EnemyActionType.DEFEND, 8), _action(GameEnums.EnemyActionType.ATTACK), call_goblin])
	frost_giant.defense = 1
	ogre = _save_new(ogre, "res://data/enemies/ogre.tres")
	wraith = _save_new(wraith, "res://data/enemies/wraith.tres")
	frost_giant = _save_new(frost_giant, "res://data/enemies/frost_giant.tres")
	var elites: Array[EnemyData] = [ogre, wraith]

	# 状態効果を使う敵（毒を吐く・麻痺させる）
	var spit := _action(GameEnums.EnemyActionType.APPLY_STATUS, 3)
	spit.status = GameEnums.StatusType.POISON
	var venom_spider := _enemy(&"venom_spider", "ENEMY_VENOM_SPIDER_NAME", 18, 2, 4, [spit, _action(GameEnums.EnemyActionType.ATTACK), _action(GameEnums.EnemyActionType.ATTACK)])
	var shock := _action(GameEnums.EnemyActionType.APPLY_STATUS, 1)
	shock.status = GameEnums.StatusType.PARALYSIS
	var thunder_wisp := _enemy(&"thunder_wisp", "ENEMY_THUNDER_WISP_NAME", 16, 3, 5, [_action(GameEnums.EnemyActionType.ATTACK), shock, _action(GameEnums.EnemyActionType.ATTACK)])
	venom_spider = _save_new(venom_spider, "res://data/enemies/venom_spider.tres")
	thunder_wisp = _save_new(thunder_wisp, "res://data/enemies/thunder_wisp.tres")

	# --- 装備（数値は仮。マナ基準値・触媒力・ドロー数はレア以上だけ） ---
	var P := GameEnums.Param
	var R := GameEnums.Rarity
	var ring := GameEnums.EquipmentType.RING
	var weapon := GameEnums.EquipmentType.WEAPON
	var armor := GameEnums.EquipmentType.ARMOR
	for item: EquipmentData in [
		_equipment(&"ring_small", ring, R.COMMON, [_modify(P.MAX_HP, 4)]),
		_equipment(&"ring_guard", ring, R.UNCOMMON, [_modify(P.DEFENSE, 1)]),
		_equipment(&"ring_mana", ring, R.RARE, [_modify(P.MANA_BASE, 1)]),
		_equipment(&"ring_sage", ring, R.LEGEND, [_modify(P.DRAW_COUNT, 1), _modify(P.MAX_HP, 5)]),
		_equipment(&"staff_oak", weapon, R.COMMON, [_modify(P.MAX_HAND, 1)]),
		_equipment(&"staff_silver", weapon, R.UNCOMMON, [_modify(P.MAX_HP, 3), _modify(P.MAX_HAND, 1)]),
		_equipment(&"staff_ruby", weapon, R.RARE, [_modify(P.CATALYST_POWER_RED, 1)]),
		_equipment(&"staff_sapphire", weapon, R.RARE, [_modify(P.CATALYST_POWER_BLUE, 1)]),
		_equipment(&"robe_cloth", armor, R.COMMON, [_modify(P.MAX_HP, 6)]),
		_equipment(&"armor_leather", armor, R.UNCOMMON, [_modify(P.DEFENSE, 1), _modify(P.MAX_HP, 2)]),
		_equipment(&"robe_mage", armor, R.RARE, [_modify(P.DEFENSE, 2), _modify(P.MAX_HP, 8)]),
	]:
		_save_new(item, "res://data/equipment/%s.tres" % item.id)

	# --- イベント（Game_Rule.md「イベントの例」。数値は仮） ---
	var rare_card := GainCardOutcome.new()
	rare_card.min_rarity = GameEnums.Rarity.RARE
	var altar := _event(&"altar", "ALTAR", [
		_choice("EVENT_ALTAR_ACCEPT", -6, [rare_card]),
		_choice("EVENT_LEAVE", 0, []),
	])
	var summon_card := GainCardOutcome.new()
	summon_card.filter_by_type = true
	summon_card.card_type = GameEnums.CardType.SUMMON
	var lost_spirit := _event(&"lost_spirit", "LOST_SPIRIT", [
		_choice("EVENT_LOST_SPIRIT_ACCEPT", 0, [summon_card]),
		_choice("EVENT_LEAVE", 0, []),
	])
	var traveling_mage := _event(&"traveling_mage", "TRAVELING_MAGE", [
		_choice("EVENT_TRAVELING_MAGE_ACCEPT", 0, [TradeCardOutcome.new()]),
		_choice("EVENT_DECLINE", 0, []),
	])
	var events: Array[EventData] = []
	for event: EventData in [altar, lost_spirit, traveling_mage]:
		events.append(_save_new(event, "res://data/events/%s.tres" % event.id))

	# --- ゲーム全体の設定（数値は仮） ---
	_save_new(GameConfig.new(), "res://data/config/game_config.tres")

	# --- ダンジョン（階数は仮の値） ---
	var dungeon := DungeonData.new()
	dungeon.id = &"lost_forest"
	dungeon.name_key = &"DUNGEON_LOST_FOREST_NAME"
	dungeon.floor_count = 10
	var normal: Array[EnemyData] = [slime, goblin, bat, venom_spider, thunder_wisp]
	dungeon.normal_enemies = normal
	dungeon.boss = boss
	dungeon.events = events
	dungeon.elite_enemies = elites
	_save_new(dungeon, "res://data/dungeons/lost_forest.tres")

	# --- 2つ目のダンジョン（迷いの森のクリアで解放。階数は仮） ---
	var cave := DungeonData.new()
	cave.id = &"frozen_cave"
	cave.name_key = &"DUNGEON_FROZEN_CAVE_NAME"
	cave.unlocked_by_clearing = FIRST_DUNGEON_ID
	cave.floor_count = 11
	var cave_normal: Array[EnemyData] = [bat, goblin, slime, venom_spider, thunder_wisp]
	cave.normal_enemies = cave_normal
	cave.elite_enemies = elites
	cave.boss = frost_giant
	cave.events = events
	_save_new(cave, "res://data/dungeons/frozen_cave.tres")

	print("サンプルデータの生成が終わりました")
	quit()


func _save_new(res: Resource, path: String) -> Resource:
	if ResourceLoader.exists(path):
		print("既存のため変更しません：%s" % path)
		return load(path)
	res.take_over_path(path)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("保存に失敗しました：%s（%d）" % [path, err])
	else:
		print("作成しました：%s" % path)
	return res


func _ally(id: StringName, name_key: String, max_hp: int, atk_min: int, atk_max: int, race: GameEnums.Race, effect: GameEnums.AttackEffect) -> AllyData:
	var ally := AllyData.new()
	ally.id = id
	ally.name_key = StringName(name_key)
	ally.max_hp = max_hp
	ally.attack_min = atk_min
	ally.attack_max = atk_max
	ally.race = race
	ally.attack_effect = effect
	return ally


## heroes：利用できる主人公のID（省略すると炎の魔法使いだけ）
func _card(id: StringName, key: String, type: GameEnums.CardType, rarity: GameEnums.Rarity, targets: Array, cost: int, red: int, blue: int, green: int, effects: Array, heroes: Array[StringName] = [HERO_ID]) -> CardData:
	var card := CardData.new()
	card.id = id
	card.name_key = StringName("CARD_%s_NAME" % key)
	card.description_key = StringName("CARD_%s_DESC" % key)
	card.card_type = type
	card.rarity = rarity
	card.usable_heroes = heroes.duplicate()
	card.targets.assign(targets)
	card.cost_mana = cost
	card.required_red = red
	card.required_blue = blue
	card.required_green = green
	card.effects.assign(effects)
	return card


func _damage(amount: int) -> DamageEffect:
	var effect := DamageEffect.new()
	effect.amount = amount
	return effect


func _armor(amount: int) -> ArmorEffect:
	var effect := ArmorEffect.new()
	effect.amount = amount
	return effect


func _heal(amount: int) -> HealEffect:
	var effect := HealEffect.new()
	effect.amount = amount
	return effect


func _draw(count: int) -> DrawEffect:
	var effect := DrawEffect.new()
	effect.count = count
	return effect


func _modify(param: GameEnums.Param, amount: int) -> ModifyParamEffect:
	var effect := ModifyParamEffect.new()
	effect.param = param
	effect.amount = amount
	return effect


func _status(type: GameEnums.StatusType, amount: int) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.status = type
	effect.amount = amount
	return effect


func _summon(ally: AllyData) -> SummonEffect:
	var effect := SummonEffect.new()
	effect.ally = ally
	return effect


func _enemy(id: StringName, name_key: String, max_hp: int, atk_min: int, atk_max: int, pattern: Array) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.id = id
	enemy.name_key = StringName(name_key)
	enemy.max_hp = max_hp
	enemy.attack_min = atk_min
	enemy.attack_max = atk_max
	enemy.pattern.assign(pattern)
	return enemy


func _equipment(id: StringName, type: GameEnums.EquipmentType, rarity: GameEnums.Rarity, modifiers: Array) -> EquipmentData:
	var item := EquipmentData.new()
	item.id = id
	item.name_key = StringName("EQUIP_%s_NAME" % String(id).to_upper())
	item.equipment_type = type
	item.rarity = rarity
	item.modifiers.assign(modifiers)
	return item


func _event(id: StringName, key: String, choices: Array) -> EventData:
	var event := EventData.new()
	event.id = id
	event.name_key = StringName("EVENT_%s_NAME" % key)
	event.description_key = StringName("EVENT_%s_DESC" % key)
	event.choices.assign(choices)
	return event


## 選択肢。文章のキーは「key」、結果の文章のキーは「key_RESULT」
func _choice(key: String, hp_change: int, outcomes: Array) -> EventChoiceData:
	var choice := EventChoiceData.new()
	choice.text_key = StringName(key)
	choice.result_key = StringName(key + "_RESULT")
	choice.hp_change = hp_change
	choice.outcomes.assign(outcomes)
	return choice


func _action(type: GameEnums.EnemyActionType, amount: int = 0) -> EnemyActionData:
	var action := EnemyActionData.new()
	action.action_type = type
	action.amount = amount
	return action
