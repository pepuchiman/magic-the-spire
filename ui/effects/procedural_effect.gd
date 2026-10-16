class_name ProceduralEffect
extends Node2D
## 図形と光の粒で描くエフェクト（絵の素材がない間の演出）。
## ui/effects/ の各シーンは、このスクリプトの kind を変えたもの。
## 決まり（data/config/effect_set.tres に登録するシーンはすべて同じ）：
##   置く場所（position）が演出の中心。play(size, duration) で始まり、終わったら自分を消す。
##   size は対象の大きさ（px）。演出はこの大きさに合わせて描く

enum Kind {
	BLOW, SLASH, PIERCE, FIRE, WATER, WIND,  # 攻撃エフェクト（打撃・斬撃・刺突・炎・水・風）
	ICE, LIGHTNING, ARCANE, POISON, HEAL, ARMOR, BUFF, DEBUFF, SUMMON,  # カードの効果エフェクト
}

## 演出の種類
@export var kind: Kind = Kind.BLOW
## 主な色
@export var color: Color = Color.WHITE
## 光の粒の数（多いほど華やかだが重くなる）
@export_range(0, 40) var particle_count: int = 14

## 演出の進み具合（0〜1）
var progress: float = 0.0:
	set(value):
		progress = value
		queue_redraw()
var _size: float = 100.0
## 光の粒（向き・速さ・大きさ・位置のずれ）。見た目だけなので、ゲームの乱数は使わない
var _particles: Array[Dictionary] = []


## 演出を始める。終わったら自分を消す
func play(size: float, duration: float) -> void:
	_size = size
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in particle_count:
		_particles.append({
			"angle": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(0.5, 1.0),
			"radius": rng.randf_range(0.6, 1.0),
			"offset": Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)),
		})
	var tween := create_tween()
	tween.tween_property(self, "progress", 1.0, maxf(duration, 0.01))
	tween.tween_callback(queue_free)


func _draw() -> void:
	var t := progress
	var s := _size
	var fade := 1.0 - t
	match kind:
		Kind.BLOW:
			var radius := s * (0.15 + 0.45 * _ease_out(t))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, _alpha(color, fade), s * 0.07 * fade + 1.0, true)
			draw_circle(Vector2.ZERO, s * 0.18 * fade, _alpha(color.lightened(0.5), fade * 0.8))
			_draw_particles(0.5, 0.05, fade, false)
		Kind.SLASH:
			var start := Vector2(-s * 0.45, -s * 0.45)
			var finish := Vector2(s * 0.45, s * 0.45)
			var head := start.lerp(finish, minf(1.0, t * 2.0))
			var tail := start.lerp(finish, maxf(0.0, t * 2.0 - 1.0))
			draw_line(tail, head, _alpha(color.lightened(0.6), fade), s * 0.06 + 1.0, true)
			draw_line(tail, head, _alpha(color, fade * 0.6), s * 0.14 + 2.0, true)
		Kind.PIERCE:
			# 右上から中心へ突き刺さる槍の線。刺さったら火花
			var direction := Vector2(1.0, 0.6).normalized()
			var reach := _ease_out(minf(1.0, t * 2.5))
			var tip := -direction * s * 0.5 * (1.0 - reach)
			var back := tip - direction * s * 0.55
			draw_line(back, tip, _alpha(color, fade * 0.5), s * 0.09 + 2.0, true)
			draw_line(back, tip, _alpha(color.lightened(0.6), fade), s * 0.035 + 1.0, true)
			var side := direction.orthogonal() * s * 0.06
			draw_colored_polygon(PackedVector2Array([tip + direction * s * 0.12, tip + side, tip - side]), _alpha(color.lightened(0.6), fade))
			if t > 0.3:
				_draw_particles(0.4, 0.035, fade, false, (t - 0.3) / 0.7)
		Kind.FIRE:
			for p: Dictionary in _particles:
				var sway := sin((t * 3.0 + p["angle"]) * TAU * 0.5) * s * 0.05  # ゆらゆら揺れながら上がる
				var position_now := Vector2(p["offset"].x * s * 0.3 + sway, s * 0.2 + p["offset"].y * s * 0.15 - t * s * 0.7 * p["speed"])
				var radius: float = s * 0.09 * p["radius"] * (1.0 - t * 0.7)
				draw_circle(position_now, radius, _alpha(color.lerp(Color("FFD24A"), p["radius"] - 0.5), fade))
		Kind.WATER:
			for p: Dictionary in _particles:
				var direction := Vector2.from_angle(-PI * (0.15 + 0.7 * fposmod(p["angle"], 1.0)))
				var flight: Vector2 = direction * s * 0.55 * p["speed"] * t + Vector2(0.0, s * 0.6 * t * t)
				draw_circle(flight, s * 0.05 * p["radius"], _alpha(color, fade))
			draw_arc(Vector2.ZERO, s * 0.4 * _ease_out(t), PI * 0.1, PI * 0.9, 20, _alpha(color.lightened(0.4), fade), 3.0, true)
		Kind.WIND:
			for ring in 3:
				var points := PackedVector2Array()
				for i in 24:
					var a := t * TAU * 1.5 + ring * TAU / 3.0 + i * 0.12
					var r := s * (0.12 + 0.3 * (float(i) / 24.0)) * (0.6 + 0.4 * t)
					points.append(Vector2.from_angle(a) * r)
				draw_polyline(points, _alpha(color, fade * 0.9), 2.5, true)
		Kind.ICE:
			for p: Dictionary in _particles:
				var direction := Vector2.from_angle(p["angle"])
				var center: Vector2 = direction * s * 0.5 * p["speed"] * _ease_out(t)
				var length: float = s * 0.1 * p["radius"]
				var shard := PackedVector2Array([center + direction * length, center + direction.orthogonal() * length * 0.3,
					center - direction * length * 0.6, center - direction.orthogonal() * length * 0.3])
				draw_colored_polygon(shard, _alpha(color.lightened(0.3 * p["radius"]), fade))
		Kind.LIGHTNING:
			var bolt := PackedVector2Array()
			var top := Vector2(0.0, -s * 1.2)
			var segments := 7
			for i in segments + 1:
				var y := lerpf(top.y, 0.0, float(i) / segments)
				var x: float = 0.0 if i == 0 or i == segments else _particles[i % _particles.size()]["offset"].x * s * 0.15
				bolt.append(Vector2(x, y))
			var flash := 1.0 if t < 0.5 else fade * 2.0
			draw_polyline(bolt, _alpha(color, flash * 0.5), s * 0.09 + 2.0, true)
			draw_polyline(bolt, _alpha(Color.WHITE, flash), s * 0.03 + 1.0, true)
			draw_circle(Vector2.ZERO, s * 0.2 * flash, _alpha(color, flash * 0.5))
		Kind.ARCANE:
			if t < 0.5:
				var gather := 1.0 - t * 2.0
				draw_arc(Vector2.ZERO, s * (0.1 + 0.5 * gather), 0.0, TAU, 40, _alpha(color, 1.0 - gather * 0.5), 3.0, true)
				draw_arc(Vector2.ZERO, s * (0.05 + 0.3 * gather), 0.0, TAU, 32, _alpha(color.lightened(0.4), 1.0 - gather * 0.5), 2.0, true)
			else:
				var burst := (t - 0.5) * 2.0
				draw_circle(Vector2.ZERO, s * 0.35 * _ease_out(burst), _alpha(color.lightened(0.3), (1.0 - burst) * 0.7))
				_draw_particles(0.6, 0.04, 1.0 - burst, false, burst)
		Kind.POISON:
			for p: Dictionary in _particles:
				var bubble := Vector2(p["offset"].x * s * 0.35, s * 0.25 - t * s * 0.6 * p["speed"] + p["offset"].y * s * 0.1)
				var radius: float = s * 0.06 * p["radius"]
				draw_arc(bubble, radius, 0.0, TAU, 16, _alpha(color, fade), 2.0, true)
				draw_circle(bubble, radius * 0.7, _alpha(color, fade * 0.35))
		Kind.HEAL:
			for p: Dictionary in _particles:
				var spark := Vector2(p["offset"].x * s * 0.35, s * 0.3 - t * s * 0.7 * p["speed"])
				var arm: float = s * 0.05 * p["radius"]
				draw_line(spark - Vector2(arm, 0.0), spark + Vector2(arm, 0.0), _alpha(color, fade), 3.0, true)
				draw_line(spark - Vector2(0.0, arm), spark + Vector2(0.0, arm), _alpha(color, fade), 3.0, true)
			draw_circle(Vector2.ZERO, s * 0.4 * _ease_out(t), _alpha(color, fade * 0.25))
		Kind.ARMOR:
			var hexagon := PackedVector2Array()
			var radius := s * (0.3 + 0.1 * _ease_out(t))
			for i in 7:
				hexagon.append(Vector2.from_angle(TAU * i / 6.0 - PI / 2.0) * radius)
			var glow := sin(t * PI)
			draw_colored_polygon(hexagon.slice(0, 6), _alpha(color, glow * 0.3))
			draw_polyline(hexagon, _alpha(color.lightened(0.4), glow), 4.0, true)
		Kind.BUFF, Kind.DEBUFF:
			var up := kind == Kind.BUFF
			var shift := (-1.0 if up else 1.0) * s * 0.4 * t
			for column in 3:
				var x := (column - 1) * s * 0.22
				var y := shift + (column % 2) * s * 0.1
				var tip := Vector2(x, y + (-1.0 if up else 1.0) * s * 0.12)
				var arrow := PackedVector2Array([tip, Vector2(x - s * 0.08, y), Vector2(x + s * 0.08, y)])
				draw_colored_polygon(arrow, _alpha(color, fade))
				draw_line(Vector2(x, y), Vector2(x, y + (1.0 if up else -1.0) * s * 0.12), _alpha(color, fade), 4.0, true)
		Kind.SUMMON:
			var open := _ease_out(minf(1.0, t * 2.0))
			var base := Vector2(0.0, s * 0.35)
			var ellipse := PackedVector2Array()
			for i in 41:
				var a := TAU * i / 40.0
				ellipse.append(base + Vector2(cos(a) * s * 0.45 * open, sin(a) * s * 0.12 * open))
			draw_polyline(ellipse, _alpha(color, fade + 0.2), 3.0, true)
			var pillar := maxf(0.0, t * 2.0 - 0.4)
			if pillar > 0.0:
				draw_rect(Rect2(base.x - s * 0.15, base.y - s * 1.0 * minf(pillar, 1.0), s * 0.3, s * 1.0 * minf(pillar, 1.0)),
					_alpha(color.lightened(0.4), fade * 0.5))


## 中心から広がる光の粒
func _draw_particles(reach: float, radius_ratio: float, alpha: float, from_top: bool, t_override: float = -1.0) -> void:
	var t := progress if t_override < 0.0 else t_override
	for p: Dictionary in _particles:
		var direction := Vector2.from_angle(p["angle"])
		if from_top:
			direction.y = -absf(direction.y)
		var point: Vector2 = direction * _size * reach * p["speed"] * _ease_out(t)
		draw_circle(point, _size * radius_ratio * p["radius"], _alpha(color.lightened(0.4), alpha))


static func _alpha(base: Color, alpha: float) -> Color:
	return Color(base, clampf(alpha, 0.0, 1.0) * base.a)


static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)
