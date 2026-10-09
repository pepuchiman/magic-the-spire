class_name GameEnums
extends RefCounted
## ゲーム全体で使う選択肢（列挙型）をまとめたファイル。
## 注意：値を追加する時は必ず「末尾」に追加すること。
## 途中に入れたり並び順を変えたりすると、作成済みのデータの値がずれてしまう。

## カードの種別（魔法の種類）
enum CardType { SUMMON, ATTACK, BUFF, SPACE }  # 召喚・攻撃・付与・空間

## レアリティ
enum Rarity { COMMON, UNCOMMON, RARE, LEGEND }  # コモン・アンコモン・レア・レジェンド

## カードのターゲット（魔法の対象）
## ※プログラム内の ALLY（味方）は、仕様書の「自分のクリーチャー」のこと
enum Target {
	ENEMY,  ## 敵（敵本体または敵のクリーチャーから1体）
	ALLY,  ## 自分のクリーチャーから1体
	SELF,  ## 自分
	ALL_ALLIES,  ## 自分のクリーチャー全員
	SELF_AND_ALL_ALLIES,  ## 自分と自分のクリーチャー全員
	SPACE,  ## 空間
	ANY,  ## 敵と自分とクリーチャーのいずれか1体（敵側・自分側を問わない）
	EVERYONE,  ## 敵と自分とクリーチャー全員（場にいる全員）
}

## 効果ターン数の種類
enum Duration { INSTANT, TURNS, BATTLE, PERMANENT }  # 瞬間・〇〇ターン・バトル中・永続

## 種族
enum Race { BEAST, SPIRIT, MONSTER }  # 獣・精霊・魔獣

## 攻撃エフェクト
enum AttackEffect { BLOW, SLASH, PIERCE, FIRE, WATER, WIND }  # 打撃・斬撃・刺突・炎・水・風

## 装備の種類
enum EquipmentType { RING, WEAPON, ARMOR }  # 指輪・武器・鎧

## 「パラメーター変更」効果で変えられるパラメーター
## （ターゲット率は仕様変更で廃止。最後の値だったため、削除しても他の値はずれない）
enum Param { MAX_HP, MANA_BASE, CATALYST_POWER_RED, CATALYST_POWER_BLUE, CATALYST_POWER_GREEN, DRAW_COUNT, MAX_HAND, DEFENSE }

## 敵の行動の種類
enum EnemyActionType { ATTACK, DEFEND, SUMMON, APPLY_STATUS }  # 攻撃・防御・クリーチャーを呼ぶ・状態効果を与える

## 敵の行動の実行条件
enum EnemyActionCondition { ALWAYS, HP_PERCENT_BELOW }  # いつでも・残りHPが〇％以下

## 状態効果の種類（動きは docs/Game_Elements.md を参照。今後も追加していく）
enum StatusType { POISON, PARALYSIS, WEAK, VULNERABLE, STRENGTH, THORNS }  # 毒・麻痺・弱体・脆弱・筋力・棘

## マップのノードの種類（エリート戦・宝箱はフェーズ5で使う）
enum MapNodeType { BATTLE, ELITE, EVENT, REST, TREASURE, BOSS }  # 通常戦・エリート戦・イベント・休憩・宝箱・ボス
