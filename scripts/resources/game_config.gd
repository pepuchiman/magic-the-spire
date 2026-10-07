class_name GameConfig
extends Resource
## ゲーム全体の数値の設定（data/config/game_config.tres）。
## 未確定の数値（休憩の回復量・出現確率など）はここに置き、コードに直接書かない

@export_group("休憩")
## 休憩の「HP回復」で回復する量（最大HPに対する％）
@export_range(0, 100) var rest_heal_percent: int = 30

@export_group("報酬")
## バトル後のカード報酬の選択肢の数
@export_range(1, 5) var reward_card_count: int = 3
## カード報酬をスキップした時に回復するHP（0 なら回復しない）
@export_range(0, 999) var skip_heal_amount: int = 0
## 通常戦のあとに装備が出る確率（％）
@export_range(0, 100) var battle_equipment_chance: int = 15
## 宝箱の中身が装備になる確率（％）。それ以外はレア以上のカード
@export_range(0, 100) var treasure_equipment_chance: int = 50
## デッキに多い触媒色のカードを出やすくする強さ（％。0 なら色で重み付けしない）
@export_range(0, 1000) var color_weight_strength: int = 200

@export_group("レアリティの出やすさ（重み）")
@export_range(0, 1000) var common_weight: int = 60
@export_range(0, 1000) var uncommon_weight: int = 30
@export_range(0, 1000) var rare_weight: int = 8
@export_range(0, 1000) var legend_weight: int = 2
## 戦闘に1回勝つごとに、レアの重みに足す数
@export_range(0, 100) var rare_bonus_per_battle: int = 2
## 戦闘に1回勝つごとに、レジェンドの重みに足す数
@export_range(0, 100) var legend_bonus_per_battle: int = 1
## エリート戦の報酬で、レア・レジェンドの重みを何倍にするか
@export_range(1, 10) var elite_rarity_multiplier: int = 3
