class_name DeckState
extends RefCounted
## デッキ・ゴミ箱・手札・破棄されたカードの管理。
## デッキの並び順はシャッフルした時点で決まり、先頭（0番）から引く。
## 破棄されたカード（使用回数を使い切ったカード）は、そのバトル中はデッキにもゴミ箱にも戻らない。

## ゴミ箱をシャッフルしてデッキに戻した時
signal reshuffled

var draw_pile: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var exhausted_pile: Array[CardInstance] = []
var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


## バトル開始時：所持カードからカードの実体を作り、すべてシャッフルしてデッキにする
func setup(cards: Array[CardData]) -> void:
	draw_pile.clear()
	discard_pile.clear()
	hand.clear()
	exhausted_pile.clear()
	for card: CardData in cards:
		draw_pile.append(CardInstance.new(card))
	_shuffle(draw_pile)


## 指定枚数を引いて手札に加え、引いたカードを返す。
## デッキが空ならゴミ箱をシャッフルしてデッキにする。両方空なら、それ以上引かない
func draw(count: int) -> Array[CardInstance]:
	var drawn: Array[CardInstance] = []
	for i in count:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			_shuffle(draw_pile)
			reshuffled.emit()
		var card: CardInstance = draw_pile.pop_front()
		hand.append(card)
		drawn.append(card)
	return drawn


## 手札の指定位置のカードを取り出す（ゴミ箱には入れない）
func take_from_hand(index: int) -> CardInstance:
	var card: CardInstance = hand[index]
	hand.remove_at(index)
	return card


## 手札の指定位置のカードをゴミ箱へ捨てる。位置は大きい順に処理する
func discard_from_hand(indices: Array[int]) -> Array[CardInstance]:
	var sorted := indices.duplicate()
	sorted.sort()
	sorted.reverse()
	var discarded: Array[CardInstance] = []
	for index: int in sorted:
		var card := take_from_hand(index)
		discard_pile.append(card)
		discarded.append(card)
	return discarded


## 使ったカードを片付ける。使用回数を使い切ったら破棄、そうでなければゴミ箱へ。破棄したら true
func put_used_card(card: CardInstance) -> bool:
	if card.use():
		exhausted_pile.append(card)
		return true
	discard_pile.append(card)
	return false


## シード付き乱数でシャッフルする（Array.shuffle() は使わない。同じシードで同じ結果にするため）
func _shuffle(cards: Array[CardInstance]) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp := cards[i]
		cards[i] = cards[j]
		cards[j] = temp
