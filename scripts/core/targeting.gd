class_name Targeting
extends RefCounted
## ターゲット率による攻撃対象の抽選
## 確率 ＝ そのキャラクターのターゲット率 ÷ 全候補のターゲット率の合計
## （全員のターゲット率が0の時は、均等に選ぶ。仕様に記載がないための仮の扱い）


static func pick(candidates: Array[Combatant], rng: RandomNumberGenerator) -> Combatant:
	if candidates.is_empty():
		return null
	var total := 0
	for candidate: Combatant in candidates:
		total += candidate.get_target_rate()
	if total <= 0:
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	var roll := rng.randi_range(1, total)
	for candidate: Combatant in candidates:
		roll -= candidate.get_target_rate()
		if roll <= 0:
			return candidate
	return candidates[candidates.size() - 1]
