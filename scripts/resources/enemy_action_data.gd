class_name EnemyActionData
extends Resource
## 敵の行動パターンの1つ分。EnemyData.pattern に並べると、順番にループして実行される
## （条件付きの行動は、条件を満たし実行できれば優先される）

@export var action_type: GameEnums.EnemyActionType = GameEnums.EnemyActionType.ATTACK
## 防御：得るアーマーの量／状態効果を与える：状態効果の値（攻撃のダメージは敵の攻撃力最少値〜最大値を使う）
@export_range(0, 9999) var amount: int = 0
## 「クリーチャーを呼ぶ」時に呼ぶ敵
@export var summon_enemy: EnemyData
@export var condition: GameEnums.EnemyActionCondition = GameEnums.EnemyActionCondition.ALWAYS
## 条件が「残りHPが〇％以下」の時の％
@export_range(0, 100) var condition_value: int = 50

@export_group("状態効果を与える")
## 与える状態効果（デバフは攻撃と同じ相手に、バフは自分自身に付ける）
@export var status: GameEnums.StatusType = GameEnums.StatusType.POISON
## ターン数で続くタイプ（弱体・脆弱・筋力・棘）の残りターン数。0 ならバトル中
@export_range(0, 99) var status_turns: int = 0
