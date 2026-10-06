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
enum Target { ENEMY, ALLY, SELF, ALL_ALLIES, SELF_AND_ALL_ALLIES, SPACE }  # 敵・味方・自分・味方全員・自分を含む味方全員・空間

## 効果ターン数の種類
enum Duration { INSTANT, TURNS, BATTLE, PERMANENT }  # 瞬間・〇〇ターン・バトル中・永続

## 種族
enum Race { BEAST, SPIRIT, MONSTER }  # 獣・精霊・魔獣

## 攻撃エフェクト
enum AttackEffect { BLOW, SLASH, PIERCE, FIRE, WATER, WIND }  # 打撃・斬撃・刺突・炎・水・風

## 装備の種類
enum EquipmentType { RING, WEAPON, ARMOR }  # 指輪・武器・鎧

## 「パラメーター変更」効果で変えられるパラメーター
enum Param { MAX_HP, MANA_BASE, CATALYST_POWER_RED, CATALYST_POWER_BLUE, CATALYST_POWER_GREEN, DRAW_COUNT, MAX_HAND, DEFENSE, TARGET_RATE }

## 敵の行動の種類
enum EnemyActionType { ATTACK, DEFEND, SUMMON }  # 攻撃・防御・味方を呼ぶ

## 敵の行動の実行条件
enum EnemyActionCondition { ALWAYS, HP_PERCENT_BELOW }  # いつでも・残りHPが〇％以下
