class_name HeroCombatant
extends Combatant
## バトル中の主人公

var data: HeroData
var mana: int = 0
var catalyst_red: int = 0
var catalyst_blue: int = 0
var catalyst_green: int = 0


## current_hp：ランから引き継いだHP（-1ならデータの初期HP）
## carried_modifiers：以前のバトルから引き継いだ「永続」の補正
func _init(hero_data: HeroData, current_hp: int = -1, carried_modifiers: Array[StatModifier] = []) -> void:
	data = hero_data
	id = data.id
	name_key = data.name_key
	base_max_hp = data.max_hp
	base_defense = data.defense
	modifiers.append_array(carried_modifiers)
	hp = mini(data.hp if current_hp < 0 else current_hp, get_max_hp())
	# 魔法触媒はバトル開始時に初期値にリセットされる
	catalyst_red = data.catalyst_red
	catalyst_blue = data.catalyst_blue
	catalyst_green = data.catalyst_green


func get_mana_base() -> int:
	return maxi(0, data.mana_base + get_modifier_total(GameEnums.Param.MANA_BASE))


func get_catalyst_power_red() -> int:
	return maxi(0, data.catalyst_power_red + get_modifier_total(GameEnums.Param.CATALYST_POWER_RED))


func get_catalyst_power_blue() -> int:
	return maxi(0, data.catalyst_power_blue + get_modifier_total(GameEnums.Param.CATALYST_POWER_BLUE))


func get_catalyst_power_green() -> int:
	return maxi(0, data.catalyst_power_green + get_modifier_total(GameEnums.Param.CATALYST_POWER_GREEN))


func get_max_hand() -> int:
	return maxi(1, data.max_hand + get_modifier_total(GameEnums.Param.MAX_HAND))


func get_draw_count() -> int:
	return maxi(0, data.draw_count + get_modifier_total(GameEnums.Param.DRAW_COUNT))


## 魔法触媒を触媒力の分だけ増やす（上限99）
func grow_catalysts() -> void:
	catalyst_red = mini(99, catalyst_red + get_catalyst_power_red())
	catalyst_blue = mini(99, catalyst_blue + get_catalyst_power_blue())
	catalyst_green = mini(99, catalyst_green + get_catalyst_power_green())


## カードの必要触媒を満たしているか（触媒は消費しない）
func meets_catalyst(card: CardData) -> bool:
	return catalyst_red >= card.required_red \
		and catalyst_blue >= card.required_blue \
		and catalyst_green >= card.required_green


## バトル後に引き継ぐ「永続」の補正
func get_permanent_modifiers() -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	for modifier: StatModifier in modifiers:
		if modifier.duration == GameEnums.Duration.PERMANENT:
			result.append(modifier)
	return result
