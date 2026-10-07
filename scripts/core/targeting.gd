class_name Targeting
extends RefCounted
## 自動の攻撃（仲間の攻撃・敵の攻撃）の対象を決める（Game_Rule.md「攻撃対象の決定」）
## ・相手側に仲間がいれば、後から召喚された仲間を狙う
## ・仲間がいなければ、相手の本体（主人公・敵本体）を狙う
## ※プレイヤーのカードはこの制限を受けない（ターゲットを自由に選べる）


## body：相手の本体。summoned：相手側の仲間（召喚された順に並んでいる）
static func pick_attack_target(body: Combatant, summoned: Array) -> Combatant:
	for i in range(summoned.size() - 1, -1, -1):
		var candidate: Combatant = summoned[i]
		if candidate.is_alive():
			return candidate
	if body != null and body.is_alive():
		return body
	return null
