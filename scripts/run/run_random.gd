class_name RunRandom
extends RefCounted
## シード付き乱数を使った、よく使う選び方をまとめたもの。
## （Array.shuffle() や pick_random() は使わない。同じシードで同じ結果にするため）


## リストから1つ選ぶ（空なら null）
static func pick(list: Array, rng: RandomNumberGenerator) -> Variant:
	if list.is_empty():
		return null
	return list[rng.randi_range(0, list.size() - 1)]


## リストを並べ替えたコピーを返す
static func shuffled(list: Array, rng: RandomNumberGenerator) -> Array:
	var copy := list.duplicate()
	for i in range(copy.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp: Variant = copy[i]
		copy[i] = copy[j]
		copy[j] = temp
	return copy


## 重みに応じて、keys の中から1つ選ぶ（weights[i] が keys[i] の出やすさ）
static func pick_weighted(keys: Array, weights: Array[int], rng: RandomNumberGenerator) -> Variant:
	var total := 0
	for weight: int in weights:
		total += maxi(0, weight)
	if total <= 0:
		return pick(keys, rng)
	var roll := rng.randi_range(1, total)
	for i in keys.size():
		roll -= maxi(0, weights[i])
		if roll <= 0:
			return keys[i]
	return keys[keys.size() - 1]
