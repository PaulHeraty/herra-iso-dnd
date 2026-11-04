class_name SpellFx
extends Node2D
## Spell visuals in the project's pixel style: small square particles, sprite sheets from the
## concept session (fireball_sheet: 6 x 16 px, explosion_sheet: 7 x 32 px) and real PointLight2Ds
## so spells light the room like the torches. Not darkened by the ambient light.
##
## Each effect is a SpellFx node that frees itself. Awaitable helpers (`await SpellFx.bolt(...)`)
## return when the visual reaches the moment the rules should resolve (arrival, flare).

signal arrived

enum Kind { BOLT, DART, COLUMN, SPARKLES, BURST, CHARGE }

const FIRE_SHEET := preload("res://assets/effects/fireball_sheet.png")
const BOOM_SHEET := preload("res://assets/effects/explosion_sheet.png")

const FIRE := [Color8(110, 20, 10), Color8(200, 50, 20), Color8(255, 130, 30), Color8(255, 210, 80), Color8(255, 250, 200)]

var kind := Kind.BOLT
var from := Vector2.ZERO
var to := Vector2.ZERO
var color := Color.WHITE
var duration := 0.3
var scale_k := 1.0
var _t := 0.0
var _parts: Array[Dictionary] = []     ## {p: Vector2, v: Vector2, life, age, col}
var _ctrl := Vector2.ZERO              ## curve control point (darts)
var _arrived := false
var _light: PointLight2D
var _light_base := 0.0
var _rng := RandomNumberGenerator.new()

static var _light_tex: Texture2D


# --- public helpers --------------------------------------------------------------------------

## A fiery mote flying from `a` to `b` (Fire Bolt). Awaits arrival.
static func bolt(parent: Node, a: Vector2, b: Vector2) -> void:
	var fx := _make(parent, Kind.BOLT, a, b, Color8(255, 150, 50))
	fx.duration = clampf(a.distance_to(b) / 260.0, 0.18, 0.5)
	fx._add_light(Color(1.0, 0.6, 0.3), 1.1, 0.5)
	Sfx.play("cast_whoosh", -4.0, 1.2)
	await fx.arrived


## One Magic Missile dart on a curving path. Awaits arrival.
static func dart(parent: Node, a: Vector2, b: Vector2, bend: float) -> void:
	var fx := _make(parent, Kind.DART, a, b, Color8(150, 160, 255))
	fx.duration = clampf(a.distance_to(b) / 300.0, 0.16, 0.42)
	var mid := (a + b) / 2.0
	var n := (b - a).orthogonal().normalized()
	fx._ctrl = mid + n * bend + Vector2(0, -18)
	fx._add_light(Color(0.6, 0.65, 1.0), 0.8, 0.35)
	Sfx.play("mm_zip", 0.0, fx._rng.randf_range(0.92, 1.1))
	await fx.arrived


## A column of radiant light dropping onto `target_pos` (Sacred Flame). Awaits the flare.
static func column(parent: Node, target_pos: Vector2) -> void:
	var fx := _make(parent, Kind.COLUMN, target_pos + Vector2(0, -90), target_pos, Color8(255, 236, 150))
	fx.duration = 0.55
	fx._add_light(Color(1.0, 0.92, 0.6), 1.2, 0.6)
	Sfx.play("radiant")
	await fx.arrived


## Rising sparkles around a figure (healing: green-gold, bless: gold).
static func sparkles(parent: Node, at: Vector2, col: Color, light := true) -> SpellFx:
	var fx := _make(parent, Kind.SPARKLES, at, at, col)
	fx.duration = 0.9
	if light:
		fx._add_light(Color(col.r, col.g, col.b), 0.7, 0.45)
	return fx


## An impact burst at a point (explosion sheet, scaled). Returns at once.
static func burst(parent: Node, at: Vector2, k := 1.0, light_energy := 1.4) -> SpellFx:
	var fx := _make(parent, Kind.BURST, at, at, Color8(255, 180, 70))
	fx.scale_k = k
	fx.duration = 0.42
	fx._add_light(Color(1.0, 0.62, 0.3), light_energy, 0.7 * k)
	return fx


## A quick swirl of sparks at the caster's hands before a spell. Awaitable (short).
static func charge(parent: Node, at: Vector2, col: Color) -> void:
	var fx := _make(parent, Kind.CHARGE, at, at, col)
	fx.duration = 0.3
	fx._add_light(Color(col.r, col.g, col.b), 0.6, 0.3)
	await fx.arrived


# --- implementation --------------------------------------------------------------------------

static func _make(parent: Node, k: Kind, a: Vector2, b: Vector2, col: Color) -> SpellFx:
	var fx := SpellFx.new()
	fx.kind = k
	fx.from = a
	fx.to = b
	fx.color = col
	fx.z_index = 40
	fx._rng.randomize()
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	fx.material = mat
	parent.add_child(fx)
	fx.position = a if k in [Kind.BOLT, Kind.DART] else (b if k != Kind.COLUMN else b)
	return fx


func _add_light(col: Color, energy: float, size: float) -> void:
	if _light_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.55, 0.55, 0.55, 1), Color(0.15, 0.15, 0.15, 1), Color(0, 0, 0, 1)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 160
		t.height = 100
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_light_tex = t
	_light = PointLight2D.new()
	_light.texture = _light_tex
	_light.color = col
	_light.energy = energy
	_light_base = energy
	_light.texture_scale = size
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / duration, 0.0, 1.0)
	match kind:
		Kind.BOLT, Kind.DART:
			if not _arrived:
				position = _path(k)
				_trail(delta)
				if k >= 1.0:
					_arrive()
		Kind.COLUMN:
			if not _arrived and k >= 0.6:
				_arrive()
			if _rng.randf() < 0.7:
				_spawn(to + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-30, 0)) - position, Vector2(0, -_rng.randf_range(10, 30)), 0.5, color)
		Kind.SPARKLES:
			if _t < duration * 0.7:
				for i in 2:
					_spawn(Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-4, 2)), Vector2(_rng.randf_range(-4, 4), -_rng.randf_range(18, 34)), _rng.randf_range(0.4, 0.7), color.lightened(_rng.randf_range(0.0, 0.5)))
			if not _arrived and k >= 0.3:
				_arrive()
		Kind.CHARGE:
			for i in 2:
				var ang := _t * 18.0 + i * PI
				var r := 7.0 * (1.0 - k)
				_spawn(Vector2(cos(ang), sin(ang) * 0.6) * r, Vector2.ZERO, 0.18, color.lightened(0.3))
			if not _arrived and k >= 1.0:
				_arrive()
		Kind.BURST:
			if not _arrived:
				_arrive()
	# particles
	for p in _parts:
		p.age += delta
		p.p += p.v * delta
		p.v *= 0.96
	_parts = _parts.filter(func(p): return p.age < p.life)
	# Lights: projectiles fade theirs on arrival (tween in _arrive); the rest fade over the effect.
	if _light and kind in [Kind.BURST, Kind.SPARKLES, Kind.COLUMN, Kind.CHARGE]:
		_light.energy = _light_base * (1.0 - k)
	# Done once the effect has run, the particles are gone and any light has faded.
	var light_done := _light == null or _light.energy <= 0.01
	if _t >= duration and _parts.is_empty() and _arrived and light_done:
		queue_free()
	queue_redraw()


func _path(k: float) -> Vector2:
	if kind == Kind.DART:
		var a := from.lerp(_ctrl, k)
		var b := _ctrl.lerp(to, k)
		return a.lerp(b, k)
	return from.lerp(to, k) + Vector2(0, -sin(k * PI) * minf(10.0, from.distance_to(to) * 0.06))


func _trail(_delta: float) -> void:
	for i in 2:
		_trail_one()


func _trail_one() -> void:
	var back := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
	if kind == Kind.BOLT:
		_spawn(back, Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-10, 2)), _rng.randf_range(0.2, 0.4), FIRE[_rng.randi_range(1, 3)])
	else:
		_spawn(back, Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3)), _rng.randf_range(0.15, 0.3), color.lightened(_rng.randf_range(0.0, 0.6)))


func _arrive() -> void:
	_arrived = true
	if kind in [Kind.BOLT, Kind.DART]:
		# hand the light + trail over: leave the node where it hit, fade particles
		for i in 6:
			var c: Color = FIRE[_rng.randi_range(2, 4)] if kind == Kind.BOLT else color.lightened(0.4)
			_spawn(Vector2.ZERO, Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-30, 10)), _rng.randf_range(0.15, 0.3), c)
		if _light:
			var tw := create_tween()
			tw.tween_property(_light, "energy", 0.0, 0.25)
	arrived.emit()


## Particles are stored relative to the node's position at spawn time (world coords).
func _spawn(offset: Vector2, vel: Vector2, life: float, col: Color) -> void:
	_parts.append({p = position + offset, v = vel, life = life, age = 0.0, col = col})


func _draw() -> void:
	for p in _parts:
		var a: float = 1.0 - p.age / p.life
		var c: Color = p.col
		draw_rect(Rect2((p.p - position).round(), Vector2(1, 1)), Color(c.r, c.g, c.b, a))
	var k := clampf(_t / duration, 0.0, 1.0)
	match kind:
		Kind.BOLT:
			if not _arrived:
				var f := int(_t * 20.0) % 6
				var src := Rect2(f * 16, 0, 16, 16)
				draw_texture_rect_region(FIRE_SHEET, Rect2(-7, -7, 14, 14), src)
		Kind.DART:
			if not _arrived:
				draw_rect(Rect2(-2, -2, 5, 5), Color(color.r, color.g, color.b, 0.3))
				draw_rect(Rect2(-1, -1, 3, 3), Color(color.r, color.g, color.b, 0.8))
				draw_rect(Rect2(0, 0, 1, 1), Color.WHITE)
				draw_rect(Rect2(-1, 0, 3, 1), color.lightened(0.5))
				draw_rect(Rect2(0, -1, 1, 3), color.lightened(0.5))
		Kind.COLUMN:
			var top := (from - position)
			var h := (to - from).y
			var reach := clampf(k / 0.55, 0.0, 1.0)
			var bottom_y := top.y + h * reach
			var fade := 1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.3
			var w := 5.0 + 2.0 * sin(_t * 40.0)
			draw_rect(Rect2(-w / 2.0 - 2, top.y, w + 4, bottom_y - top.y), Color(color.r, color.g, color.b, 0.25 * fade))
			draw_rect(Rect2(-w / 2.0, top.y, w, bottom_y - top.y), Color(color.r, color.g, color.b, 0.7 * fade))
			draw_rect(Rect2(-1, top.y, 2, bottom_y - top.y), Color(1, 1, 1, 0.9 * fade))
			if reach >= 1.0:
				var r := 6.0 + 6.0 * (k - 0.55) / 0.45
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 16, Color(color.r, color.g, color.b, 0.8 * fade), 1.0)
				draw_set_transform(Vector2.ZERO)
		Kind.BURST:
			var f := mini(int(k * 7.0), 6)
			var s := 32.0 * scale_k
			draw_texture_rect_region(BOOM_SHEET, Rect2(-s / 2.0, -s * 0.75, s, s), Rect2(f * 32, 0, 32, 32))
