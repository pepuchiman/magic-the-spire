class_name DataIndex
extends Resource
## 全データの一覧（索引）。data/data_index.tres は tools/rebuild_data_index.gd が自動生成する。
## 手で編集しないこと（再生成すると上書きされる）。

@export var cards: Array[CardData] = []
@export var heroes: Array[HeroData] = []
@export var allies: Array[AllyData] = []
@export var enemies: Array[EnemyData] = []
@export var equipment: Array[EquipmentData] = []
@export var events: Array[EventData] = []
@export var dungeons: Array[DungeonData] = []
## ゲーム全体の数値の設定
@export var config: GameConfig
