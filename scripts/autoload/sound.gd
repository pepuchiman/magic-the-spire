extends Node
## 音を鳴らす係（全体の管理役。名前は Sound）。
## 効果音は同時に PLAYER_COUNT 個まで重ねて鳴らせる。BGM は曲を変える時に前の曲を小さくしながら切り替え、終わったら最初から繰り返す。
## 音量は音の通り道（default_bus_layout.tres の BGM・SE）ごとに変える（設定画面から使う）。
## 画面から鳴らす時は UiSound を使う（Sound がいない時も止まらないように）

const PLAYER_COUNT := 8
## BGM を切り替える時に、前の曲を小さくしていく時間（秒）
const FADE_TIME := 0.6
## 最近鳴らした音の記録の上限（テストで、鳴らす指示が出たかを確かめるため）
const HISTORY_LIMIT := 50
const BUS_BGM := &"BGM"
const BUS_SE := &"SE"

## 最近鳴らした音（"se:BUTTON"、"bgm:BATTLE" のような文字）
var history: PackedStringArray = []
## 今の BGM（鳴っていなければ -1）
var current_music: int = -1

var _sounds: SoundSet
var _se_players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _bgm_player: AudioStreamPlayer
var _fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sounds = DataLoader.new().get_sounds()
	for i in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SE
		add_child(player)
		_se_players.append(player)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = BUS_BGM
	_bgm_player.finished.connect(func() -> void: _bgm_player.play())  # 曲の終わりで最初に戻る
	add_child(_bgm_player)


## その他の効果音を鳴らす
func play_event(type: GameEnums.SoundEvent) -> void:
	_play_se(_sounds.event_sounds.get(type), "se:%s" % GameEnums.SoundEvent.find_key(type))


## 攻撃の音を鳴らす
func play_attack(type: GameEnums.AttackEffect) -> void:
	_play_se(_sounds.attack_sounds.get(type), "attack:%s" % GameEnums.AttackEffect.find_key(type))


## カードの効果の音を鳴らす（「なし」なら鳴らさない）
func play_card(type: GameEnums.CardEffect) -> void:
	if type != GameEnums.CardEffect.NONE:
		_play_se(_sounds.card_sounds.get(type), "card:%s" % GameEnums.CardEffect.find_key(type))


## BGM を変える（同じ曲なら何もしない）
func play_music(type: GameEnums.Music) -> void:
	if type == current_music:
		return
	current_music = type
	_record("bgm:%s" % GameEnums.Music.find_key(type))
	var stream: AudioStream = _sounds.music.get(type)
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	if _bgm_player.playing:
		_fade_tween.tween_property(_bgm_player, "volume_db", -40.0, FADE_TIME)
	_fade_tween.tween_callback(_start_music.bind(stream))


## BGM を止める
func stop_music() -> void:
	current_music = -1
	_bgm_player.stop()


## 音量を変える（bus は BUS_BGM か BUS_SE。volume は 0〜1）
func set_volume(bus: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, volume <= 0.0)


## 今の音量（0〜1）
func get_volume(bus: StringName) -> float:
	var index := AudioServer.get_bus_index(bus)
	if index < 0 or AudioServer.is_bus_mute(index):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))


func _play_se(stream: AudioStream, label: String) -> void:
	_record(label)
	if stream == null:
		return
	var player := _se_players[_next_player]
	_next_player = (_next_player + 1) % _se_players.size()
	player.stream = stream
	player.play()


func _record(label: String) -> void:
	history.append(label)
	if history.size() > HISTORY_LIMIT:
		history.remove_at(0)


func _start_music(stream: AudioStream) -> void:
	_bgm_player.stream = stream
	_bgm_player.volume_db = 0.0
	if stream != null:
		_bgm_player.play()


## 終わる時に、切り替え途中の BGM と鳴っている音を片付ける（音のデータが残ったままにならないように）
func _exit_tree() -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	for player: AudioStreamPlayer in _se_players + [_bgm_player]:
		player.stop()
		player.stream = null
	_sounds = null
