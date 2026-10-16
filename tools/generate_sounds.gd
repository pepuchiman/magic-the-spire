extends SceneTree
## 効果音と BGM を計算で作り、assets/sounds/ に WAV で保存するツール（仮の音。本物の音に差し替えられる）。
## すでにあるファイルは上書きしない（手で差し替えた音を守るため）。作り直したい時は force=true を付ける。
## 作ったあとは --headless --import → tools/generate_sample_data.gd（音の一覧を作る）→ tools/rebuild_data_index.gd の順に実行する。
## 実行：godot --headless -s tools/generate_sounds.gd （-- force=true で全部作り直す）
## 名前の決まりは scripts/resources/sound_set.gd（se_attack_<種類>、se_card_<種類>、se_<種類>、bgm_<種類>）

const OUT_DIR := "res://assets/sounds"
## 音の細かさ（1秒あたりの数）。ファイルを小さくするため、CD の半分にしている
const RATE := 22050

var _force := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_force = "force=true" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_rng.seed = 12345  # 毎回同じ音になるように
	var made := 0
	for entry: Array in _sound_list():
		if _save(entry[0], entry[1]):
			made += 1
	print("音を %d 個作りました（既存のファイルはそのまま）。次に --import を実行してください" % made)
	quit()


## 作る音の一覧（[名前, 作る関数]）
func _sound_list() -> Array:
	return [
		# 攻撃の音
		["se_attack_blow", func() -> PackedFloat32Array: return _mix([_tone(120, 40, 0.22, "sine", 0.9), _noise(0.06, 0.5, 0.3)])],
		["se_attack_slash", func() -> PackedFloat32Array: return _sweep_noise(0.16, 0.6, 0.15, 0.9)],
		["se_attack_pierce", func() -> PackedFloat32Array: return _mix([_tone(1100, 500, 0.09, "square", 0.35), _noise(0.03, 0.4, 0.9)])],
		["se_attack_fire", func() -> PackedFloat32Array: return _fire(0.4)],
		["se_attack_water", func() -> PackedFloat32Array: return _bubbles(5, 350, 800, 0.4)],
		["se_attack_wind", func() -> PackedFloat32Array: return _swell_noise(0.45, 0.5)],
		# カードの効果の音
		["se_card_fire", func() -> PackedFloat32Array: return _mix([_fire(0.5), _tone(90, 50, 0.4, "sine", 0.5)])],
		["se_card_ice", func() -> PackedFloat32Array: return _chimes([1568, 1976, 2349, 2637], 0.07, 0.4)],
		["se_card_water", func() -> PackedFloat32Array: return _bubbles(7, 300, 900, 0.5)],
		["se_card_wind", func() -> PackedFloat32Array: return _swell_noise(0.6, 0.55)],
		["se_card_lightning", func() -> PackedFloat32Array: return _mix([_noise(0.35, 0.7, 0.95), _tone(70, 40, 0.35, "square", 0.4)])],
		["se_card_arcane", func() -> PackedFloat32Array: return _tone(300, 950, 0.5, "sine", 0.6, 7.0)],
		["se_card_poison", func() -> PackedFloat32Array: return _bubbles(6, 150, 380, 0.55)],
		["se_card_heal", func() -> PackedFloat32Array: return _arpeggio([523, 659, 784, 1047], 0.09, "sine", 0.5)],
		["se_card_armor", func() -> PackedFloat32Array: return _mix([_tone(620, 600, 0.3, "square", 0.25), _tone(930, 900, 0.3, "triangle", 0.35)])],
		["se_card_buff", func() -> PackedFloat32Array: return _arpeggio([392, 523, 659, 784], 0.06, "square", 0.3)],
		["se_card_debuff", func() -> PackedFloat32Array: return _tone(620, 180, 0.45, "triangle", 0.6)],
		["se_card_summon", func() -> PackedFloat32Array: return _mix([_tone(200, 800, 0.7, "sine", 0.5), _chimes([1047, 1319, 1568], 0.15, 0.3)])],
		# その他の効果音
		["se_button", func() -> PackedFloat32Array: return _tone(880, 880, 0.05, "sine", 0.4)],
		["se_card_draw", func() -> PackedFloat32Array: return _sweep_noise(0.08, 0.3, 0.6, 0.8)],
		["se_card_play", func() -> PackedFloat32Array: return _sweep_noise(0.18, 0.45, 0.2, 0.7)],
		["se_damage", func() -> PackedFloat32Array: return _mix([_tone(160, 70, 0.14, "sine", 0.8), _noise(0.04, 0.3, 0.4)])],
		["se_death", func() -> PackedFloat32Array: return _tone(420, 70, 0.6, "triangle", 0.7)],
		["se_paralyzed", func() -> PackedFloat32Array: return _tone(180, 180, 0.35, "square", 0.3, 18.0)],
		["se_turn_start", func() -> PackedFloat32Array: return _arpeggio([659, 988], 0.12, "sine", 0.45)],
		["se_victory", func() -> PackedFloat32Array: return _arpeggio([523, 659, 784, 1047, 1047], 0.16, "square", 0.3, 0.5)],
		["se_defeat", func() -> PackedFloat32Array: return _arpeggio([440, 415, 392, 330], 0.28, "triangle", 0.5, 0.6)],
		["se_reward", func() -> PackedFloat32Array: return _chimes([1319, 1568, 2093], 0.08, 0.4)],
		["se_map_step", func() -> PackedFloat32Array: return _mix([_tone(140, 100, 0.09, "sine", 0.5), _noise(0.03, 0.15, 0.2)])],
		["se_equip", func() -> PackedFloat32Array: return _mix([_tone(1250, 1200, 0.18, "triangle", 0.35), _tone(1870, 1800, 0.12, "sine", 0.2)])],
		# BGM（コード進行は和音の根音、melody はメロディに使う音階）
		["bgm_title", func() -> PackedFloat32Array: return _music(80, [57, 53, 48, 55], [0, 2, 3, 5, 7, 8, 10], 2, 0.8)],
		["bgm_map", func() -> PackedFloat32Array: return _music(100, [48, 55, 57, 53], [0, 2, 4, 5, 7, 9, 11], 2, 0.6)],
		["bgm_battle", func() -> PackedFloat32Array: return _music(138, [50, 46, 48, 45], [0, 2, 3, 5, 7, 8, 10], 4, 0.4, 16)],
		["bgm_boss", func() -> PackedFloat32Array: return _music(150, [40, 36, 38, 35], [0, 1, 3, 5, 7, 8, 10], 4, 0.35, 16)],
	]


## 音を WAV で保存する。作ったら true
func _save(file_name: String, maker: Callable) -> bool:
	var path := OUT_DIR.path_join(file_name + ".wav")
	if FileAccess.file_exists(path) and not _force:
		return false
	var samples: PackedFloat32Array = maker.call()
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	stream.data = data
	stream.save_to_wav(ProjectSettings.globalize_path(path))
	print("作りました：%s（%.1f 秒）" % [path, samples.size() / float(RATE)])
	return true


# ---------- 音の部品 ----------

## 1つの音（高さを from から to へ変える）。vibrato は揺れの速さ（0 なら揺らさない）
func _tone(from_hz: float, to_hz: float, seconds: float, wave: String, volume: float, vibrato: float = 0.0) -> PackedFloat32Array:
	var count := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		var hz := lerpf(from_hz, to_hz, t)
		if vibrato > 0.0:
			hz *= 1.0 + 0.03 * sin(TAU * vibrato * i / RATE)
		phase += hz / RATE
		out[i] = _wave(wave, phase) * volume * _envelope(t, 0.02)
	return out


## 雑音。brightness が大きいほど高い音（0〜1）
func _noise(seconds: float, volume: float, brightness: float) -> PackedFloat32Array:
	var count := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var last := 0.0
	for i in count:
		last = lerpf(last, _rng.randf_range(-1.0, 1.0), brightness)
		out[i] = last * volume * _envelope(float(i) / count, 0.01)
	return out


## 高さが変わる雑音（シュッという音）
func _sweep_noise(seconds: float, volume: float, from_brightness: float, to_brightness: float) -> PackedFloat32Array:
	var count := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var last := 0.0
	for i in count:
		var t := float(i) / count
		last = lerpf(last, _rng.randf_range(-1.0, 1.0), lerpf(from_brightness, to_brightness, t))
		out[i] = last * volume * sin(PI * t)
	return out


## だんだん大きくなって小さくなる雑音（風）
func _swell_noise(seconds: float, volume: float) -> PackedFloat32Array:
	var count := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var last := 0.0
	for i in count:
		var t := float(i) / count
		last = lerpf(last, _rng.randf_range(-1.0, 1.0), 0.08 + 0.1 * sin(PI * t * 3.0))
		out[i] = last * volume * 2.5 * sin(PI * t)
	return out


## パチパチと燃える音
func _fire(seconds: float) -> PackedFloat32Array:
	var out := _noise(seconds, 0.35, 0.15)
	for crackle in int(seconds * 25):
		var at := _rng.randi_range(0, out.size() - 200)
		for j in 120:
			out[at + j] += _rng.randf_range(-0.6, 0.6) * (1.0 - j / 120.0)
	return out


## 泡の音（短く高さが上がる音をいくつも）
func _bubbles(count: int, low_hz: float, high_hz: float, seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	for b in count:
		var hz := _rng.randf_range(low_hz, high_hz)
		var bubble := _tone(hz, hz * 1.8, 0.06, "sine", 0.45)
		var at := int(_rng.randf_range(0.0, seconds - 0.07) * RATE)
		for j in bubble.size():
			out[at + j] += bubble[j]
	return out


## 鈴のような音を少しずつずらして重ねる
func _chimes(frequencies: Array, gap: float, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int((gap * frequencies.size() + 0.35) * RATE))
	for n in frequencies.size():
		var chime := _tone(frequencies[n], frequencies[n], 0.35, "sine", volume)
		var at := int(gap * n * RATE)
		for j in chime.size():
			out[at + j] += chime[j]
	return out


## 音を順番に鳴らす（last_length：最後の音の長さ。0 なら他と同じ）
func _arpeggio(frequencies: Array, note_seconds: float, wave: String, volume: float, last_length: float = 0.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for n in frequencies.size():
		var length := last_length if n == frequencies.size() - 1 and last_length > 0.0 else note_seconds * 1.6
		var note := _tone(frequencies[n], frequencies[n], length, wave, volume)
		var at := int(note_seconds * n * RATE)
		if out.size() < at + note.size():
			out.resize(at + note.size())
		for j in note.size():
			out[at + j] += note[j]
	return out


## いくつかの音を重ねる（長さは一番長いものに合わせる）
func _mix(parts: Array) -> PackedFloat32Array:
	var length := 0
	for part: PackedFloat32Array in parts:
		length = maxi(length, part.size())
	var out := PackedFloat32Array()
	out.resize(length)
	for part: PackedFloat32Array in parts:
		for i in part.size():
			out[i] += part[i]
	return out


## 短い曲。bpm：速さ、roots：和音の根音（MIDI の番号）、scale：メロディの音階、
## notes_per_beat：1拍のメロディの音の数、rest_chance：メロディを休む割合、bars：小節の数
func _music(bpm: float, roots: Array, scale: Array, notes_per_beat: int, rest_chance: float, bars: int = 8) -> PackedFloat32Array:
	var beat := 60.0 / bpm
	var total := int(bars * 4 * beat * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	for bar in bars:
		var root: int = roots[bar % roots.size()]
		var bar_start := bar * 4 * beat
		var minor: bool = scale[2] == 3
		var chord: Array[int] = [root, root + (3 if minor else 4), root + 7]
		# 和音（やわらかい音で1小節のばす）
		for midi: int in chord:
			_add(out, _tone(_hz(midi + 12), _hz(midi + 12), 4 * beat, "sine", 0.07), bar_start)
		# ベース（1拍ごと）
		for b in 4:
			_add(out, _tone(_hz(root - 12), _hz(root - 12), beat * 0.9, "triangle", 0.22), bar_start + b * beat)
		# メロディ
		for n in 4 * notes_per_beat:
			if _rng.randf() < rest_chance:
				continue
			var degree: int = scale[_rng.randi_range(0, scale.size() - 1)]
			var midi: int = root + 12 + degree + (12 if _rng.randf() < 0.3 else 0)
			var length: float = beat / notes_per_beat
			_add(out, _tone(_hz(midi), _hz(midi), length * 0.95, "square", 0.07), bar_start + n * length)
	# 曲の終わりと始まりがつながるよう、最後を少し小さくする
	for i in int(0.05 * RATE):
		out[total - 1 - i] *= float(i) / (0.05 * RATE)
	return out


func _add(out: PackedFloat32Array, part: PackedFloat32Array, start_seconds: float) -> void:
	var at := int(start_seconds * RATE)
	for i in mini(part.size(), out.size() - at):
		out[at + i] += part[i]


static func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


static func _wave(wave: String, phase: float) -> float:
	var p := fposmod(phase, 1.0)
	match wave:
		"square":
			return 1.0 if p < 0.5 else -1.0
		"triangle":
			return 4.0 * absf(p - 0.5) - 1.0
	return sin(TAU * p)


## 音の大きさの変化（すぐ大きくなって、だんだん小さくなる）
static func _envelope(t: float, attack: float) -> float:
	if t < attack:
		return t / attack
	return pow(1.0 - (t - attack) / (1.0 - attack), 1.5)
