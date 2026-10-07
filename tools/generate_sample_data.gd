extends SceneTree
## サンプルデータ（.tres）を生成するツール。
## 実行：godot --headless -s tools/generate_sample_data.gd
## すでにあるファイルは上書きしない（インスペクターで調整した値を守るため）。
## サンプルの数値はすべて「仮置き」。後から差し替える。

const HERO_ID := &"flame_mage"


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
	var spark := _card(&"spark", "SPARK", GameEnums.CardType.ATTACK, GameEnums.Rarity.COMMON, [GameEnums.Target.ANY], 1, 0, 0, 0, [_damage(6)])
	var guard := _card(&"guard", "GUARD", GameEnums.CardType.BUFF, GameEnums.Rarity.COMMON, [GameEnums.Target.ANY], 1, 0, 0, 0, [_armor(5)])
	var fireball := _card(&"fireball", "FIREBALL", GameEnums.CardType.ATTACK, GameEnums.Rarity.COMMON, [GameEnums.Target.ANY], 2, 1, 0, 0, [_damage(12)])
	var frost_lance := _card(&"frost_lance", "FROST_LANCE", GameEnums.CardType.ATTACK, GameEnums.Rarity.COMMON, [GameEnums.Target.ANY], 2, 0, 1, 0, [_damage(10)])
	var meditation := _card(&"meditation", "MEDITATION", GameEnums.CardType.BUFF, GameEnums.Rarity.UNCOMMON, [GameEnums.Target.SELF], 1, 0, 0, 0, [_draw(2)])
	var heal := _card(&"heal", "HEAL", GameEnums.CardType.BUFF, GameEnums.Rarity.COMMON, [GameEnums.Target.ANY], 2, 0, 0, 1, [_heal(6)])
	var steam_blast := _card(&"steam_blast", "STEAM_BLAST", GameEnums.CardType.ATTACK, GameEnums.Rarity.UNCOMMON, [GameEnums.Target.ANY], 3, 1, 1, 0, [_damage(18)])
	var summon_sprite := _card(&"summon_sprite", "SUMMON_SPRITE", GameEnums.CardType.SUMMON, GameEnums.Rarity.COMMON, [GameEnums.Target.SPACE], 2, 1, 0, 0, [_summon(sprite)])
	var summon_wolf := _card(&"summon_wolf", "SUMMON_WOLF", GameEnums.CardType.SUMMON, GameEnums.Rarity.UNCOMMON, [GameEnums.Target.SPACE], 3, 0, 0, 1, [_summon(wolf)])
	var mana_surge := _card(&"mana_surge", "MANA_SURGE", GameEnums.CardType.BUFF, GameEnums.Rarity.RARE, [GameEnums.Target.SELF], 1, 0, 0, 0, [_modify(GameEnums.Param.MANA_BASE, 1)])
	mana_surge.duration = GameEnums.Duration.BATTLE
	# 1戦闘あたりの使用回数（仮の値。0 は制限なし）
	steam_blast.uses_per_battle = 2
	summon_wolf.uses_per_battle = 1
	mana_surge.uses_per_battle = 1

	var cards: Array = [spark, guard, fireball, frost_lance, meditation, heal, steam_blast, summon_sprite, summon_wolf, mana_surge]
	for i in cards.size():
		var card: CardData = cards[i]
		cards[i] = _save_new(card, "res://data/cards/%s.tres" % card.id)
	spark = cards[0]
	guard = cards[1]
	fireball = cards[2]
	summon_sprite = cards[7]

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

	# --- ダンジョン（戦闘数Nは仮の値） ---
	var dungeon := DungeonData.new()
	dungeon.id = &"lost_forest"
	dungeon.name_key = &"DUNGEON_LOST_FOREST_NAME"
	dungeon.battle_count = 8
	var normal: Array[EnemyData] = [slime, goblin, bat]
	dungeon.normal_enemies = normal
	dungeon.boss = boss
	_save_new(dungeon, "res://data/dungeons/lost_forest.tres")

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


func _card(id: StringName, key: String, type: GameEnums.CardType, rarity: GameEnums.Rarity, targets: Array, cost: int, red: int, blue: int, green: int, effects: Array) -> CardData:
	var card := CardData.new()
	card.id = id
	card.name_key = StringName("CARD_%s_NAME" % key)
	card.description_key = StringName("CARD_%s_DESC" % key)
	card.card_type = type
	card.rarity = rarity
	card.usable_heroes = [HERO_ID]
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


func _action(type: GameEnums.EnemyActionType, amount: int = 0) -> EnemyActionData:
	var action := EnemyActionData.new()
	action.action_type = type
	action.amount = amount
	return action
