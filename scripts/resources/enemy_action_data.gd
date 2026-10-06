class_name EnemyActionData
extends Resource
## 敵の行動パターンの1つ分。EnemyData.pattern に並べると、順番にループして実行される
## （条件が付いた行動の選び方は、フェーズ2で実装する）

@export var action_type: GameEnums.EnemyActionType = GameEnums.EnemyActionType.ATTACK
## 防御の時に得るアーマーの量（攻撃のダメージは敵の攻撃力最少値〜最大値を使う）
@export_range(0, 9999) var amount: int = 0
## 「味方を呼ぶ」時に呼ぶ敵
@export var summon_enemy: EnemyData
@export var condition: GameEnums.EnemyActionCondition = GameEnums.EnemyActionCondition.ALWAYS
## 条件が「残りHPが〇％以下」の時の％
@export_range(0, 100) var condition_value: int = 50
