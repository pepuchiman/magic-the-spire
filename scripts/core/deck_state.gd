class_name DeckState
extends RefCounted
## デッキ・ゴミ箱・手札の管理。
## デッキの並び順はシャッフルした時点で決まり、先頭（0番）から引く。

## ゴミ箱をシャッフルしてデッキに戻した時
signal reshuffled

var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var hand: Array[CardData] = []
var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


## バトル開始時：所持カードをすべてシャッフルしてデッキを作る
func setup(cards: Array[CardData]) -> void:
	draw_pile = cards.duplicate()
	discard_pile.clear()
	hand.clear()
	_shuffle(draw_pile)


## 指定枚数を引いて手札に加え、引いたカードを返す。
## デッキが空ならゴミ箱をシャッフルしてデッキにする。両方空なら、それ以上引かない
func draw(count: int) -> Array[CardData]:
	var drawn: Array[CardData] = []
	for i in count:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			_shuffle(draw_pile)
			reshuffled.emit()
		var card: CardData = draw_pile.pop_front()
		hand.append(card)
		drawn.append(card)
	return drawn


## 手札の指定位置のカードを取り出す（ゴミ箱には入れない）
func take_from_hand(index: int) -> CardData:
	var card: CardData = hand[index]
	hand.remove_at(index)
	return card


## 手札の指定位置のカードをゴミ箱へ捨てる。位置は大きい順に処理する
func discard_from_hand(indices: Array[int]) -> Array[CardData]:
	var sorted := indices.duplicate()
	sorted.sort()
	sorted.reverse()
	var discarded: Array[CardData] = []
	for index: int in sorted:
		var card := take_from_hand(index)
		discard_pile.append(card)
		discarded.append(card)
	return discarded


## シード付き乱数でシャッフルする（Array.shuffle() は使わない。同じシードで同じ結果にするため）
func _shuffle(cards: Array[CardData]) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp := cards[i]
		cards[i] = cards[j]
		cards[j] = temp
