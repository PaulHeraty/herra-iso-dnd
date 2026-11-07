class_name Projectile
extends Node2D
## Simple ranged-attack visuals.
##   ARROW: a short shaft flying from a to b along a slight arc.
##   BEAM:  a crackling ray drawn from a to b for a moment (Eye Tyrant's Gaze Ray).
##   THROWN: a handaxe tumbling end over end along a higher arc.
## `await Projectile.fire(...).done` to wait for the impact.

signal done

enum Style { ARROW, BEAM, THROWN }

var style := Style.ARROW
var from := Vector2.ZERO
var to := Vector2.ZERO
var duration := 0.25
var color := Color8(220, 200, 160)
var _t := 0.0
var _seed := 0


static func fire(parent: Node, a: Vector2, b: Vector2, s := Style.ARROW, col := Color8(220, 200, 160)) -> Projectile:
	var p := Projectile.new()
	p.style = s
	p.from = a
	p.to = b
	p.color = col
	p.duration = 0.35 if s == Style.BEAM else clampf(a.distance_to(b) / (320.0 if s == Style.ARROW else 240.0), 0.14, 0.5)
	p.z_index = 40
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	parent.add_child(p)
	return p


func _process(delta: float) -> void:
	_t += delta
	_seed += 1
	if _t >= duration:
		done.emit()
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / duration
	if style == Style.THROWN:
		_draw_axe(k)
		return
	if style == Style.ARROW:
		var lift := -sin(k * PI) * minf(16.0, from.distance_to(to) * 0.12)
		var p := from.lerp(to, k) + Vector2(0, lift)
		var k2 := maxf(0.0, k - 0.06)
		var q := from.lerp(to, k2) + Vector2(0, -sin(k2 * PI) * minf(16.0, from.distance_to(to) * 0.12))
		var dir := (p - q).normalized() if p != q else (to - from).normalized()
		var tail := p - dir * 6.0
		draw_line(tail.round(), p.round(), Color8(20, 16, 24), 3.0)
		draw_line(tail.round(), p.round(), color, 1.0)
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed
		var a := 1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.3
		var pts := PackedVector2Array()
		var n := 10
		for i in n + 1:
			var t := float(i) / n
			var jitter := Vector2.ZERO if i == 0 or i == n else Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
			pts.append(from.lerp(to, t) + jitter)
		draw_polyline(pts, Color(color, 0.45 * a), 4.0)
		draw_polyline(pts, Color(color.lightened(0.5), a), 2.0)
		draw_polyline(pts, Color(1, 1, 1, a), 1.0)


## The handaxe: a 7px haft with a 3px blade, turning (snapped to 8 steps: it stays pixel art).
func _draw_axe(k: float) -> void:
	var lift := -sin(k * PI) * minf(24.0, from.distance_to(to) * 0.2)
	var p := (from.lerp(to, k) + Vector2(0, lift)).round()
	var spin := -1.0 if to.x < from.x else 1.0
	var ang := floorf(k * 3.0 * 8.0) / 8.0 * TAU * spin
	var d := Vector2.from_angle(ang)
	var n := Vector2(-d.y, d.x)
	var a := (p - d * 3.0).round()
	var b := (p + d * 3.0).round()
	draw_line(a, b, Color8(20, 16, 24), 3.0)
	draw_line(a, b, Color8(122, 84, 52), 1.0)
	for i in 3:
		var q := (b + n * (i - 1)).round()
		draw_rect(Rect2(q - Vector2(1, 1), Vector2(3, 3)), Color8(20, 16, 24))
	for i in 3:
		var q := (b + n * (i - 1)).round()
		draw_rect(Rect2(q, Vector2(1, 1)), Color8(224, 226, 236) if i == 0 else Color8(160, 164, 178))
