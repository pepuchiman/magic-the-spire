class_name GameConfig
extends Resource
## ゲーム全体の数値の設定（data/config/game_config.tres）。
## 未確定の数値（休憩の回復量など）はここに置き、コードに直接書かない

@export_group("休憩")
## 休憩の「HP回復」で回復する量（最大HPに対する％）
@export_range(0, 100) var rest_heal_percent: int = 30

@export_group("報酬")
## バトル後のカード報酬の選択肢の数
@export_range(1, 5) var reward_card_count: int = 3
## カード報酬をスキップした時に回復するHP（0 なら回復しない）
@export_range(0, 999) var skip_heal_amount: int = 0
