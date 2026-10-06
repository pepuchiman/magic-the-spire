class_name DamageCalc
extends RefCounted
## ダメージ処理（Game_Rule.md「ダメージ処理の順序」）
## ① ダメージ値（呼び出す側で決める） ② 防御力の分だけ軽減（0未満にしない）
## ③ アーマーから先に減らす ④ 残りの分だけHPを減らす


## ダメージを与え、内訳を返す
static func apply(target: Combatant, raw_damage: int) -> Dictionary:
	var after_defense := maxi(0, raw_damage - target.get_defense())
	var armor_absorbed := mini(target.armor, after_defense)
	target.armor -= armor_absorbed
	var hp_damage := after_defense - armor_absorbed
	target.hp = maxi(0, target.hp - hp_damage)
	return {
		"raw": raw_damage,
		"after_defense": after_defense,
		"armor_absorbed": armor_absorbed,
		"hp_damage": hp_damage,
	}
