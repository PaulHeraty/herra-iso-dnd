class_name DiceScene
extends CanvasLayer
## The dice-roll scene from the mock-ups (docs/previews/dice_*_still.png, tools/python/make_iso_dice.py):
## time freezes, the room dims with a spotlight on the target, and a panel on the left shows the
## real rolls - a purple d20 bouncing in for a save or attack, then the damage dice dropping in
## with clacks and a running total. Awaitable; it runs on its own timer (no input needed). Click /
## Space / Enter speeds it up.

const FONT := preload("res://assets/fonts/herra_pixel.fnt")
const SCREEN := Vector2(640, 360)
const PANEL := Rect2(14, 44, 204, 218)
const PX := 116.0                     ## panel centre x
const PURPLE := {dark = Color8(58, 34, 96), mid = Color8(96, 62, 150), light = Color8(140, 104, 196),
		edge = Color8(28, 16, 48), num = Color8(250, 246, 255), hi = Color8(200, 170, 240)}
const FIREC := {face = Color8(214, 70, 40), side = Color8(160, 44, 28), edge = Color8(70, 18, 12),
		hi = Color8(255, 150, 100), pip = Color8(255, 236, 200)}
const PIPS := {1: [Vector2(0, 0)], 2: [Vector2(-1, -1), Vector2(1, 1)], 3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
		4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
		5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
		6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]}

var _dim: ColorRect
var _view: Control
var _speed := 1.0
var _rng := RandomNumberGenerator.new()
## What the view draws (set by the sequences below).
var st := {}


func _ready() -> void:
	layer = 9                       # above the world, below the HUD (10)
	_rng.randomize()
	_dim = ColorRect.new()
	_dim.size = SCREEN
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/ui/spotlight.gdshader")
	_dim.material = mat
	add_child(_dim)
	var top := CanvasLayer.new()    # the panel draws above the HUD
	top.layer = 11
	add_child(top)
	_view = Control.new()
	_view.size = SCREEN
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_view)
	top.add_child(_view)
	visible = false
	top.visible = false
	_top = top


var _top: CanvasLayer


# --- public ----------------------------------------------------------------------------------

## Dim the room around `spot` (screen position) and show the panel.
func open(spot: Vector2) -> void:
	_speed = 1.0
	st = {}
	(_dim.material as ShaderMaterial).set_shader_parameter("spot", spot)
	visible = true
	_top.visible = true
	await _fade_dim(0.0, 1.0, 0.18)


func close() -> void:
	st = {}
	_view.queue_redraw()
	await _fade_dim(1.0, 0.0, 0.15)
	visible = false
	_top.visible = false


## A d20 roll: saving throw (`vs` = DC) or attack (`vs` = AC). `outcome` e.g. "FAILED!".
func show_d20(title: String, sub: String, roll: DiceRoll, outcome: String, outcome_good: bool, note: String) -> void:
	st = {mode = "d20", title = title, title_col = Color8(210, 170, 255), sub = sub}
	var start := Vector2(PX - 64, 128)
	var end := Vector2(PX, 128)
	var t := 0.0
	var dur := 0.75
	var prev_y := 0.0
	while t < dur:
		var k := t / dur
		var p := _bounce(k, start.x, end.x, end.y, 16.0)
		st.d20 = {pos = p, ang = pow(1.0 - k, 1.5) * 9.0, num = roll.natural if k > 0.9 else _rng.randi_range(1, 20), seed = int(t * 30.0)}
		if p.y >= end.y - 1.0 and prev_y < end.y - 1.0 and t > 0.05:
			Sfx.play("clack_big", -2.0 if k < 0.5 else -6.0)
		prev_y = p.y
		_view.queue_redraw()
		t += await _tick()
	Sfx.play("clack_big", -8.0)
	st.d20 = {pos = end, ang = 0.0, num = roll.natural, seed = 99}
	for k in 4:                         # settle flash
		st.flash = 1.0 - k / 4.0
		_view.queue_redraw()
		await _wait(0.06)
	st.flash = 0.0
	st.sum = "%d %s %d = %d" % [roll.natural, "+" if roll.modifier >= 0 else "-", absi(roll.modifier), roll.total] if roll.modifier != 0 else "%d" % roll.total
	_view.queue_redraw()
	await _wait(0.2)
	Sfx.play("total_sting" if outcome_good else "fail_sting", -2.0)
	st.outcome = outcome
	st.outcome_col = Color8(120, 230, 130) if outcome_good else Color8(255, 90, 80)
	_view.queue_redraw()
	await _wait(0.45)
	st.note = note
	_view.queue_redraw()
	await _wait(0.75)


## Damage dice dropping in one by one with a running total, then the total.
func show_damage(title: String, roll: DiceRoll, dtype: String, col: Color) -> void:
	var n := roll.dice.size()
	st = {mode = "dmg", title = title, title_col = col, sub = "roll %d %s" % [n, _dice_words(roll)]}
	var per_row := mini(n, 5) if n > 8 else mini(n, 4)
	var rows := ceili(float(n) / per_row)
	var slots: Array[Vector2] = []
	for i in n:
		var r := i / per_row
		var in_row := mini(per_row, n - r * per_row)
		var x := PX + (i % per_row - (in_row - 1) / 2.0) * 34.0
		var y := 108.0 + r * 32.0 - (rows - 2) * 8.0
		slots.append(Vector2(x, y))
	st.dice = []
	var stagger := 0.1
	var fall := 0.45
	var t := 0.0
	var landed := {}
	var total_time := stagger * (n - 1) + fall + 0.05
	while t < total_time:
		var dice := []
		var running := 0
		for j in n:
			var lt := t - j * stagger
			if lt < 0.0:
				continue
			var k := minf(1.0, lt / fall)
			var p := _bounce(k, slots[j].x - 20.0, slots[j].x, slots[j].y, 14.0) - Vector2(0, pow(1.0 - k, 2) * 8.0)
			var settled := k >= 1.0
			var face: int = roll.dice[j] if k > 0.8 else _rng.randi_range(1, roll.sides[j])
			dice.append({pos = p, ang = 0.0 if settled else pow(1.0 - k, 1.3) * 7.0 + j, val = face, sides = roll.sides[j]})
			if settled:
				running += roll.dice[j]
				if not landed.has(j):
					landed[j] = true
					Sfx.play("clack_small", -3.0, _rng.randf_range(0.95, 1.1))
		st.dice = dice
		st.running = running
		_view.queue_redraw()
		t += await _tick()
	var final := []
	for j in n:
		final.append({pos = slots[j], ang = 0.0, val = roll.dice[j], sides = roll.sides[j]})
	st.dice = final
	st.running = 0
	var parts: PackedStringArray = []
	for v in roll.dice:
		parts.append(str(v))
	st.sum = "+".join(parts) + (("%+d" % roll.modifier) if roll.modifier != 0 else "")
	Sfx.play("total_sting", -2.0)
	st.total = roll.total
	_view.queue_redraw()
	await _wait(0.35)
	st.note = "%s DAMAGE" % dtype.to_upper()
	st.note_col = col
	_view.queue_redraw()
	await _wait(0.9)


func _dice_words(roll: DiceRoll) -> String:
	var s: int = roll.sides[0] if not roll.sides.is_empty() else 6
	var names := {4: "four", 6: "six", 8: "eight", 10: "ten", 12: "twelve", 20: "twenty"}
	return "%s-sided %s" % [names.get(s, str(s)), "die" if roll.dice.size() == 1 else "dice"]


# --- timing ----------------------------------------------------------------------------------

func _tick() -> float:
	await get_tree().process_frame
	return get_process_delta_time() * _speed


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		t += await _tick()


func _fade_dim(a: float, b: float, sec: float) -> void:
	var t := 0.0
	while t < sec:
		t += await _tick()
		(_dim.material as ShaderMaterial).set_shader_parameter("amount", lerpf(a, b, clampf(t / sec, 0.0, 1.0)))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var skip: bool = (event is InputEventMouseButton and event.pressed) or \
			(event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER])
	if skip:
		_speed = 4.0
		get_viewport().set_input_as_handled()


## Ball-like motion: x0 -> x1 while bouncing with decaying height (k 0..1). As the mock-up.
static func _bounce(k: float, x0: float, x1: float, y_floor: float, h0: float) -> Vector2:
	var x := x0 + (x1 - x0) * (1.0 - pow(1.0 - k, 2))
	var segs := [0.0, 0.42, 0.72, 0.9, 1.0]
	for i in 4:
		if k <= segs[i + 1]:
			var u: float = (k - segs[i]) / (segs[i + 1] - segs[i])
			var h := h0 * pow(0.35, i)
			return Vector2(x, y_floor - h * 4.0 * u * (1.0 - u))
	return Vector2(x, y_floor)


# --- drawing -----------------------------------------------------------------------------------

func _draw_view() -> void:
	if st.is_empty():
		return
	var v := _view
	v.draw_rect(PANEL, Color8(18, 14, 24, 220))
	v.draw_rect(PANEL, Color8(120, 96, 70), false, 1.0)
	v.draw_rect(PANEL.grow(-2), Color8(50, 40, 34), false, 1.0)
	_text(st.title, PX, PANEL.position.y + 6, st.title_col, 1)
	_text(st.get("sub", ""), PX, PANEL.position.y + 20, Color8(180, 176, 190), 1)
	if st.mode == "d20":
		if st.has("d20"):
			_draw_d20(st.d20.pos, 24.0, st.d20.ang, st.d20.num, st.d20.seed, st.get("flash", 0.0))
		if st.has("sum"):
			_text(st.sum, PX, 160, Color8(235, 230, 240), 1)
		if st.has("outcome"):
			_text(st.outcome, PX, 174, st.outcome_col, 2)
		if st.has("note"):
			_text(st.note, PX, PANEL.end.y - 20, Color8(200, 150, 150), 1)
	else:
		for d in st.get("dice", []):
			_draw_die(d.pos, 18.0, d.ang, d.val, d.sides)
		if st.get("running", 0) > 0:
			_text("= %d" % st.running, PX, 176, Color8(255, 200, 110), 2)
		if st.has("sum"):
			_text(st.sum, PX, 168, Color8(200, 190, 180), 1)
		if st.has("total"):
			_text(str(st.total), PX, 182, Color8(255, 230, 120), 3)
		if st.has("note"):
			_text(st.note, PX, PANEL.end.y - 20, st.get("note_col", Color.WHITE), 1)


## Centred text at `scale_k`x with a dark outline.
func _text(s: String, cx: float, y: float, col: Color, scale_k: int) -> void:
	if s == "":
		return
	var w := FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x * scale_k
	var p := Vector2(roundf(cx - w / 2.0), y)
	_view.draw_set_transform(p, 0.0, Vector2(scale_k, scale_k))
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]:
		_view.draw_string(FONT, o + Vector2(0, 8), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color8(14, 8, 12))
	_view.draw_string(FONT, Vector2(0, 8), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
	_view.draw_set_transform(Vector2.ZERO)


func _draw_d20(c: Vector2, r: float, ang: float, num: int, shade_seed: int, flash: float) -> void:
	var v := _view
	var hexv := PackedVector2Array()
	for k in 6:
		hexv.append(c + Vector2(sin(ang + k * PI / 3.0), -cos(ang + k * PI / 3.0)) * r)
	var inner := PackedVector2Array()
	for k in 3:
		inner.append(c + Vector2(sin(ang + k * TAU / 3.0), -cos(ang + k * TAU / 3.0)) * r * 0.52)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = shade_seed
	v.draw_colored_polygon(hexv, PURPLE.dark)
	for i in 3:
		var tri := PackedVector2Array([inner[i], hexv[(2 * i + 1) % 6], inner[(i + 1) % 3]])
		v.draw_colored_polygon(tri, PURPLE.mid if rnd.randf() < 0.7 else PURPLE.light)
	v.draw_colored_polygon(inner, PURPLE.light)
	for i in 3:
		v.draw_line(inner[i], hexv[(2 * i) % 6], PURPLE.edge)
		v.draw_line(inner[i], hexv[(2 * i + 1) % 6], PURPLE.edge)
		v.draw_line(inner[i], hexv[posmod(2 * i - 1, 6)], PURPLE.edge)
	var ip := inner.duplicate()
	ip.append(inner[0])
	v.draw_polyline(ip, PURPLE.edge)
	var hp := hexv.duplicate()
	hp.append(hexv[0])
	v.draw_polyline(hp, PURPLE.edge, 2.0)
	v.draw_line(hexv[5], hexv[0], PURPLE.hi)
	_text(str(num), c.x, c.y - 6, PURPLE.num, 1)
	if flash > 0.0:
		var ring := PackedVector2Array()
		for p in hexv:
			ring.append(p + (p - c) * 0.25)
		ring.append(ring[0])
		v.draw_polyline(ring, Color(1, 1, 1, flash), 1.0)


func _draw_die(c: Vector2, s: float, ang: float, val: int, sides: int) -> void:
	var v := _view
	var sq := func(off: Vector2) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for a in [45.0, 135.0, 225.0, 315.0]:
			for da in [-14.0, 14.0]:
				var aa := deg_to_rad(a + da) + ang
				pts.append(c + off + Vector2(cos(aa), sin(aa)) * s * 0.5 * sqrt(2.0) * 0.86)
		return pts
	v.draw_colored_polygon(sq.call(Vector2(1, 3)), FIREC.edge)
	v.draw_colored_polygon(sq.call(Vector2(0, 1.5)), FIREC.side)
	var face: PackedVector2Array = sq.call(Vector2.ZERO)
	v.draw_colored_polygon(face, FIREC.face)
	var fp := face.duplicate()
	fp.append(face[0])
	v.draw_polyline(fp, FIREC.edge)
	v.draw_polyline(face.slice(1, 4), FIREC.hi)
	if sides == 6 and PIPS.has(val):
		for pp: Vector2 in PIPS[val]:
			var u := pp * s * 0.26
			var q := c + u.rotated(ang)
			v.draw_rect(Rect2(q.round() - Vector2(1, 1), Vector2(2, 2)), FIREC.pip)
	else:
		_text(str(val), c.x, c.y - 6, FIREC.pip, 1)
