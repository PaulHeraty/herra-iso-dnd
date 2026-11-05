class_name FireballFx
extends Node2D
## The Fireball showcase, after the concept mock-up (tools/python/make_iso_fireball.py):
##   charge   sparks spiral into the staff gem, which glows brighter           (~0.4 s)
##   flight   the fireball arcs (34 px high) with an ember trail, lighting the room (~0.55 s)
##   explode  main blast (64 px) on the centre + 8 delayed bursts on the 3x3, floor flash, big
##            light flash, screen shake; then smoke wisps; the scorch mark is left on the map
## Usage: await FireballFx.charge(...); await FireballFx.fly(...); FireballFx.explode(...) (returns at
## once - resolve the damage while the blast plays).

const FIRE_SHEET := preload("res://assets/effects/fireball_sheet.png")
const BOOM_SHEET := preload("res://assets/effects/explosion_sheet.png")
const FIRE := [Color8(110, 20, 10), Color8(200, 50, 20), Color8(255, 130, 30), Color8(255, 210, 80), Color8(255, 250, 200)]
const ARC := 0.0           ## straight flight (the mock-up arced 34 px; user prefers straight)
const FLY_TIME := 0.55
const CHARGE_TIME := 0.42

signal done

enum Mode { CHARGE, FLY, BLAST, SMOKE }

var mode := Mode.CHARGE
var a := Vector2.ZERO
var b := Vector2.ZERO
var _t := 0.0
var _dur := 0.5
var _parts: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _light: PointLight2D
var _light_base := 1.0
var _bursts: Array[Dictionary] = []     ## {pos, delay, size}
var _cells: Array[Vector2] = []
var _done := false

static var _light_tex: Texture2D


static func _make(parent: Node, m: Mode, p: Vector2, q: Vector2, dur: float) -> FireballFx:
	var fx := FireballFx.new()
	fx.mode = m
	fx.a = p
	fx.b = q
	fx._dur = dur
	fx.z_index = 42
	fx._rng.randomize()
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	fx.material = mat
	parent.add_child(fx)
	fx.position = p
	return fx


func _add_light(energy: float, size: float) -> void:
	if _light_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1), Color(0.63, 0.63, 0.63), Color(0.33, 0.33, 0.33), Color(0.11, 0.11, 0.11), Color(0, 0, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 240
		t.height = 150
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_light_tex = t
	_light = PointLight2D.new()
	_light.texture = _light_tex
	_light.color = Color(1.0, 0.68, 0.36)
	_light.energy = energy
	_light_base = energy
	_light.texture_scale = size
	add_child(_light)


# --- the sequence ------------------------------------------------------------------------------

static func charge(parent: Node, gem: Vector2) -> void:
	var fx := _make(parent, Mode.CHARGE, gem, gem, CHARGE_TIME)
	fx._add_light(0.4, 0.35)
	Sfx.play("charge")
	await fx.done


static func fly(parent: Node, gem: Vector2, target: Vector2) -> void:
	var fx := _make(parent, Mode.FLY, gem, target, FLY_TIME)
	fx._add_light(1.7, 0.8)
	Sfx.play("fireball_flight")
	await fx.done


## Blast over `cells_world` (cell centres; index 4 = the centre of a 3x3). Returns at once.
static func explode(parent: Node, centre: Vector2, cells_world: Array[Vector2]) -> FireballFx:
	var fx := _make(parent, Mode.BLAST, centre, centre, 1.0)
	fx._add_light(3.2, 1.45)
	# One big ball of fire over the whole 3x3 (96 px wide = 3 cells); the cells are still used for
	# sparks and smoke.
	fx._bursts.append({pos = centre, delay = 0.0, size = 96.0})   # exactly 3x the 32 px sheet: crisp pixels
	fx._cells = cells_world
	Sfx.play("fireball_boom")
	# smoke wisps afterwards
	var smoke := _make(parent, Mode.SMOKE, centre, centre, 1.8)
	for p in cells_world:
		smoke._bursts.append({pos = p, delay = 0.0, size = 0.0})
	smoke.visible = false
	smoke._t = -0.55               # starts as the blast fades
	return fx


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / _dur, 0.0, 1.0)
	match mode:
		Mode.CHARGE:
			for i in 2:
				var ang := _rng.randf() * TAU
				var r := 16.0 * (1.0 - k) + 2.0
				_spawn(Vector2(cos(ang), sin(ang) * 0.7) * r, -Vector2(cos(ang), sin(ang) * 0.7) * 30.0, 0.18, FIRE[_rng.randi_range(2, 4)])
			_light.energy = 0.3 + 1.0 * k
			if k >= 1.0:
				_finish()
		Mode.FLY:
			if not _done:
				position = a.lerp(b, k) + Vector2(0, -ARC * sin(PI * k))
				for i in 3:
					_spawn(Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-2, 2)), Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-6, 10)), _rng.randf_range(0.2, 0.45), FIRE[_rng.randi_range(1, 3)])
				if k >= 1.0:
					_finish()
					var tw := create_tween()
					tw.tween_property(_light, "energy", 0.0, 0.12)
		Mode.BLAST:
			_light.energy = _light_base * pow(1.0 - k, 1.5)
			if _t > 0.05 and _t < 0.45 and not _cells.is_empty():
				for i in 3:
					var cp: Vector2 = _cells[_rng.randi_range(0, _cells.size() - 1)]
					_spawn(cp - position + Vector2(_rng.randf_range(-8, 8), -_rng.randf_range(0, 14)),
							Vector2(_rng.randf_range(-40, 40), -_rng.randf_range(10, 60)), _rng.randf_range(0.25, 0.5), FIRE[_rng.randi_range(2, 4)])
			if k >= 1.0:
				_finish()
		Mode.SMOKE:
			if _t >= 0.0:
				visible = true
				if _t < _dur * 0.75 and _rng.randf() < 0.6:
					var bp: Dictionary = _bursts[_rng.randi_range(0, _bursts.size() - 1)]
					_spawn(bp.pos - position + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-4, 4)),
							Vector2(_rng.randf_range(-3, 3), -_rng.randf_range(6, 14)), _rng.randf_range(0.8, 1.4),
							Color8(90, 84, 82) if _rng.randf() < 0.5 else Color8(64, 60, 60))
			if _t >= _dur:
				_finish()
	for p in _parts:
		p.age += delta
		p.p += p.v * delta
		p.v *= 0.95
	_parts = _parts.filter(func(p): return p.age < p.life)
	if _done and _parts.is_empty() and (mode != Mode.FLY or _light.energy <= 0.01):
		queue_free()
	queue_redraw()


func _finish() -> void:
	if not _done:
		_done = true
		done.emit()


func _spawn(offset: Vector2, vel: Vector2, life: float, col: Color) -> void:
	_parts.append({p = position + offset, v = vel, life = life, age = 0.0, col = col})


func _draw() -> void:
	for p in _parts:
		var al: float = 1.0 - p.age / p.life
		var c: Color = p.col
		draw_rect(Rect2((p.p - position).round(), Vector2(1, 1)), Color(c.r, c.g, c.b, al))
	match mode:
		Mode.CHARGE:
			var k := clampf(_t / _dur, 0.0, 1.0)
			var r := 1.0 + 2.5 * k
			draw_circle(Vector2.ZERO, r + 1.5, Color(1.0, 0.55, 0.2, 0.35))
			draw_circle(Vector2.ZERO, r, Color(1.0, 0.85, 0.4, 0.9))
		Mode.FLY:
			if not _done:
				var f := int(_t * 20.0) % 6
				draw_texture_rect_region(FIRE_SHEET, Rect2(-8, -8, 16, 16), Rect2(f * 16, 0, 16, 16))
		Mode.BLAST:
			for bp in _bursts:
				var lt: float = _t - bp.delay
				if lt < 0.0:
					continue
				var f := int(lt / 0.1)            # a big blast: a touch slower than the small bursts
				if f > 6:
					continue
				var s: float = bp.size
				var at: Vector2 = bp.pos - position
				draw_texture_rect_region(BOOM_SHEET, Rect2(at.x - s / 2.0, at.y - s * 0.72, s, s), Rect2(f * 32, 0, 32, 32))
