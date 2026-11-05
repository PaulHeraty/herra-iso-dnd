extends SceneTree
## Builds the hero ACTION sheets: assets/sprites/heroes/<hero>_actions.png
## Run: Godot_console --headless --path . -s res://tools/godot/gen_hero_actions.gd  (then --import)
## HERO=<name> builds just one.
##
## The figures come from the walk-sheet drawings in gen_hero_sheets.gd (HEROES). Each hero gets a
## small "rig": the weapon pixels are erased from the drawing, and the weapon, the arm holding it
## (a 1px sleeve line from the shoulder) and the hand are redrawn for every pose. So the action
## frames always match the walk sheets.
##
## Sheet layout: 32x32 cells (the 16x24 figure cell sits at (8, 8), feet at (16, 30): sprite offset
## (-16, -30)), 16 columns x 2 rows (0 = front 3/4, 1 = back 3/4; mirror for the right-facing views).
##   cols  0-3  attack  (wind-up, strike + swoosh, follow-through, recover)
##   cols  4-6  shoot   (Rogue: bow nock, draw, release; others: copies of the attack wind-up)
##   cols  7-10 cast    (raise, glow A, glow B, glow C; Hero holds/loops the glow frames)
##   cols 11-12 hurt    (recoil, settle)
##   cols 13-15 down    (kneel, slump, lying)
## Hero.ACTION_ANIMS in scripts/actors/hero.gd must match these columns.

const PY_SOURCE := "res://tools/python/make_iso_party.py"
const WALK_GEN := "res://tools/godot/gen_hero_sheets.gd"
const OUT_DIR := "res://assets/sprites/heroes/"
const CELL := 32
const COLS := 16
const ORIGIN := Vector2i(9, 9)       ## where figure pixel (0, 0) lands in a cell (inside the 1px outline)

## Per hero: weapon type, sleeve colour, attack style, cast style + glow colours, and per view the
## weapon pixels to erase ([x0, y0, x1, y1] inclusive, figure coords 14x22), the shoulder, the grip
## (the point the weapon turns around) and the idle weapon direction.
## hand_side: hand pixels drawn beside the grip (staff) instead of on it.
## offhand (cleric): the free hand that lifts the holy symbol when casting.
const RIG := {
	"fighter": {
		"weapon": "sword", "arm": "n", "cast": "raise", "glow": ["h", "w"],
		"front": {"erase": [[10, 0, 13, 15]], "shoulder": [9, 8], "grip": [11, 13], "dir": [0, -1]},
		"back": {"erase": [[0, 0, 2, 15]], "shoulder": [4, 8], "grip": [2, 13], "dir": [0, -1]},
	},
	"rogue": {
		"weapon": "shortsword", "arm": "L", "cast": "raise", "glow": ["G", "h"], "bow": true,
		"front": {"erase": [[0, 9, 1, 13]], "shoulder": [2, 8], "grip": [1, 9], "dir": [0, 1]},
		"back": {"erase": [[0, 11, 1, 13]], "shoulder": [2, 8], "grip": [1, 11], "dir": [0, 1]},
	},
	"cleric": {
		"weapon": "mace", "arm": "u", "cast": "symbol", "glow": ["y", "F"],
		"front": {"erase": [[10, 0, 13, 8], [11, 9, 13, 11]], "shoulder": [9, 8], "grip": [11, 11], "dir": [0, -1],
				"offhand": {"erase": [[1, 11, 1, 11]], "shoulder": [2, 8]}},
		"back": {"erase": [[0, 0, 3, 6], [0, 7, 2, 11]], "shoulder": [4, 8], "grip": [2, 11], "dir": [0, -1],
				"offhand": {"erase": [[12, 11, 12, 11]], "shoulder": [11, 8]}},
	},
	"mage": {
		"weapon": "staff", "arm": "p", "cast": "staff", "glow": ["f", "F"],
		"front": {"erase": [[11, 0, 13, 15], [12, 16, 13, 21]], "shoulder": [9, 8], "grip": [12, 10], "dir": [0, -1], "hand_side": 1},
		"back": {"erase": [[0, 0, 2, 15], [0, 16, 1, 21]], "shoulder": [4, 8], "grip": [1, 10], "dir": [0, -1], "hand_side": -1},
	},
}

## Poses. g = grip as [forward px from the body's centre column, figure row]; "idle" = the drawn
## grip. d = weapon direction as [forward, up]. lean = [head px, body px] forward (negative = back).
## behind = [front view, back view]: the weapon goes behind the body there.
const SLASH := [
	{"g": [-2, 3], "d": [-1, 1], "lean": [-1, 0], "behind": [true, false]},
	{"g": [5, 9], "d": [1, -0.5], "lean": [1, 1], "behind": [false, true], "swoosh": true},
	{"g": [4, 12], "d": [1, -1], "lean": [1, 1], "behind": [false, true]},
	{"g": "idle", "dtilt": 0.5, "lean": [0, 0]},
]
const STAFF_SWING := [
	{"g": [-2, 7], "d": [-0.5, 1], "lean": [-1, 0], "behind": [true, false]},
	{"g": [3, 10], "d": [1, 0.5], "lean": [1, 1], "behind": [false, true], "swoosh": true},
	{"g": [3, 11], "d": [1, 0], "lean": [1, 1], "behind": [false, true]},
	{"g": "idle", "dtilt": 0.25, "lean": [0, 0]},
]
const HURT := [
	{"g": "idle", "shift": [-1, 1], "lean": [-2, -1], "dtilt": -0.5},
	{"g": "idle", "shift": [-1, 0], "lean": [-1, 0], "dtilt": -0.25},
]

var palette := {}
var walk: Dictionary


func _init() -> void:
	palette = _parse_palette(FileAccess.get_file_as_string(PY_SOURCE))
	walk = (load(WALK_GEN) as Script).get_script_constant_map()["HEROES"]
	var only := OS.get_environment("HERO")
	for hero: String in RIG:
		if only != "" and hero != only:
			continue
		var sheet := Image.create_empty(CELL * COLS, CELL * 2, false, Image.FORMAT_RGBA8)
		var views := ["front", "back"]
		for row in 2:
			var frames := _frames(hero, views[row])
			for col in frames.size():
				var img: Image = frames[col]
				sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(col * CELL, row * CELL))
		var path := OUT_DIR + hero + "_actions.png"
		sheet.save_png(ProjectSettings.globalize_path(path))
		print("wrote ", path)
	quit()


# --- frames ------------------------------------------------------------------------------------

func _frames(hero: String, view: String) -> Array[Image]:
	var rig: Dictionary = RIG[hero]
	var v: Dictionary = rig[view]
	var base := _strip(_idle_rows(walk[hero][view]), v["erase"])
	var cx := _centre_x(base)
	var out: Array[Image] = []
	var style: Array = STAFF_SWING if rig["weapon"] == "staff" else SLASH
	var tips: Array = []
	# attack 0-3
	for i in 4:
		var p: Dictionary = style[i]
		var f := _pose(hero, view, base, cx, p)
		if p.get("swoosh", false):
			_swoosh(f, hero, view, cx, style[0], p)
		out.append(_render(f))
	# shoot 4-6
	if rig.get("bow", false):
		for i in 3:
			out.append(_render(_bow(hero, view, base, cx, i)))
	else:
		for i in 3:
			out.append(out[0])
	# cast 7-10
	for i in 4:
		out.append(_render(_cast(hero, view, base, cx, i)))
	# hurt 11-12
	for p in HURT:
		out.append(_render(_pose(hero, view, base, cx, p)))
	# down 13-15
	out.append(_render(_kneel(hero, view, base, cx, 1)))
	out.append(_render(_kneel(hero, view, base, cx, 2)))
	out.append(_render(_lying(hero, view, base)))
	return out


## A frame in progress: a 32x32 char canvas (palette keys) + overlay effect pixels (no outline).
class Frame:
	var px: Array = []       # [y][x] -> String
	var fx := {}             # Vector2i -> Color

	func _init() -> void:
		for y in 32:
			var r := []
			r.resize(32)
			r.fill(".")
			px.append(r)

	func put(p: Vector2i, c: String, only_empty := false) -> void:
		if p.x < 0 or p.y < 0 or p.x >= 32 or p.y >= 32:
			return
		if only_empty and px[p.y][p.x] != ".":
			return
		px[p.y][p.x] = c

	func get_px(p: Vector2i) -> String:
		if p.x < 0 or p.y < 0 or p.x >= 32 or p.y >= 32:
			return "."
		return px[p.y][p.x]


## Body (with lean / shift / kneel) + arm + weapon + hand for one pose.
func _pose(hero: String, view: String, base: Array, cx: int, p: Dictionary, drop := 0) -> Frame:
	var rig: Dictionary = RIG[hero]
	var v: Dictionary = rig[view]
	var fwd := -1                                   # both views face screen-left; mirrored in game
	var lean: Array = p.get("lean", [0, 0])
	var shift: Array = p.get("shift", [0, 0])       # [x forward, y down] whole figure
	var f := Frame.new()
	var sh := Vector2i(shift[0] * fwd, shift[1])
	_blit_body(f, base, lean, sh, drop)
	var shoulder := _v(v["shoulder"]) + Vector2i(lean[1] * fwd, drop) + sh
	var grip: Vector2i
	var dir: Vector2
	if typeof(p["g"]) == TYPE_STRING:
		grip = _v(v["grip"]) + Vector2i(lean[1] * fwd, 0) + sh
		dir = Vector2(v["dir"][0], v["dir"][1])
		dir.x += p.get("dtilt", 0.0) * fwd
	else:
		grip = Vector2i(cx + int(p["g"][0]) * fwd, int(p["g"][1]) + drop) + sh
		dir = Vector2(p["d"][0] * fwd, -p["d"][1])
	var behind: bool = p.get("behind", [false, false])[0 if view == "front" else 1]
	_arm(f, shoulder, grip + _hand_offset(v, dir), rig["arm"])
	_weapon(f, rig["weapon"], grip, dir, behind)
	_hand(f, v, grip, dir)
	return f


func _blit_body(f: Frame, rows: Array, lean: Array, sh: Vector2i, drop: int) -> void:
	var fwd := -1
	for y in rows.size():
		var yy := y
		if drop > 0:
			# kneel: the knee rows (17, 18) fold away; everything above moves down
			if y == 17 or y == 18:
				if drop >= 2 or y == 17:
					continue
			if y < 17:
				yy = y + (2 if drop >= 2 else 1)
		var dx := 0
		if y <= 6:
			dx = lean[0] * fwd
		elif y <= 15:
			dx = lean[1] * fwd
		for x in rows[y].length():
			var c: String = rows[y][x]
			if c != ".":
				f.put(ORIGIN + Vector2i(x + dx, yy) + sh, c)


func _hand_offset(v: Dictionary, dir: Vector2) -> Vector2i:
	var s: int = v.get("hand_side", 0)
	if s == 0:
		return Vector2i.ZERO
	return _perp(dir) * s


func _hand(f: Frame, v: Dictionary, grip: Vector2i, dir: Vector2) -> void:
	var s: int = v.get("hand_side", 0)
	if s == 0:
		f.put(ORIGIN + grip, "s")
		return
	var h := grip + _perp(dir) * s
	f.put(ORIGIN + h, "s")
	f.put(ORIGIN + h - _step(dir, 1), "s")


## Sleeve from the shoulder to the hand, only where the body isn't (it reads as the arm beside or
## in front of the body without smearing over the drawing).
func _arm(f: Frame, a: Vector2i, b: Vector2i, col: String) -> void:
	for p in _line(a, b):
		if p != b:
			f.put(ORIGIN + p, col, true)


func _weapon(f: Frame, kind: String, g: Vector2i, dir: Vector2, behind: bool) -> void:
	var put := func(t: int, c: String, side := 0) -> void:
		var p := g + _step(dir, t) + _perp(dir) * side
		f.put(ORIGIN + p, c, behind)
	match kind:
		"sword":
			put.call(-1, "b")
			put.call(1, "y")
			put.call(1, "y", 1)
			put.call(1, "y", -1)
			for t in range(2, 11):
				put.call(t, "w")
		"shortsword":
			put.call(-1, "L")
			put.call(1, "m")
			for t in range(2, 6):
				put.call(t, "w")
		"mace":
			for t in range(-1, 5):
				put.call(t, "b")
			put.call(5, "M"); put.call(5, "M", 1); put.call(5, "M", -1)
			put.call(6, "m"); put.call(6, "M", 1); put.call(6, "M", -1)
			put.call(7, "M")
		"staff":
			put.call(-10, "B")
			for t in range(-9, 7):
				put.call(t, "b")
			_gem(f, g + _step(dir, 8), 0)


## The staff's glowing gem: an axis-aligned little cross (doesn't turn with the staff).
func _gem(f: Frame, c: Vector2i, size: int) -> void:
	f.put(ORIGIN + c, "F")
	f.put(ORIGIN + c + Vector2i(0, -1), "F")
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
		f.put(ORIGIN + c + d, "f")
	if size >= 1:
		f.put(ORIGIN + c + Vector2i(0, -2), "f")
		f.put(ORIGIN + c + Vector2i(1, -1), "f")
		f.put(ORIGIN + c + Vector2i(-1, -1), "f")


## Faint arc behind the striking blade, from where the wind-up tip was to the strike tip.
func _swoosh(f: Frame, hero: String, view: String, cx: int, from: Dictionary, to: Dictionary) -> void:
	var fwd := -1
	var g := Vector2(cx + int(to["g"][0]) * fwd, to["g"][1])
	var r := 9.0 if RIG[hero]["weapon"] in ["sword", "staff"] else 6.0
	var a0 := Vector2(from["d"][0] * fwd, -from["d"][1]).angle()
	var a1 := Vector2(to["d"][0] * fwd, -to["d"][1]).angle()
	var da := wrapf(a1 - a0, -PI, PI)
	for i in 14:
		var t := float(i) / 13.0
		var a := a0 + da * t
		for rr in [r, r - 1.0]:
			var p := Vector2i((g + Vector2.from_angle(a) * rr).round())
			if f.get_px(ORIGIN + p) == ".":
				f.fx[ORIGIN + p] = Color(1, 1, 1, 0.25 + 0.45 * t)


## Cast poses. raise: weapon lifted high. staff: staff lifted, gem flares. symbol: the cleric's
## free hand lifts a golden holy symbol.
func _cast(hero: String, view: String, base: Array, cx: int, i: int) -> Frame:
	var rig: Dictionary = RIG[hero]
	var v: Dictionary = rig[view]
	var glow: Array = rig["glow"]
	var f: Frame
	var spark_at: Vector2i
	match rig["cast"]:
		"raise":
			var lift := 2 if i == 0 else 4
			f = _pose(hero, view, base, cx, {"g": [3, 7 - lift], "d": [0, 1], "lean": [0, 0]})
			var g := Vector2i(cx - 3, 7 - lift)
			spark_at = g + Vector2i(0, -(9 if rig["weapon"] == "sword" else 5))
		"staff":
			var lift := 2 if i == 0 else 3
			var gx: int = v["grip"][0] - cx
			var p := {"g": [-gx, int(v["grip"][1]) - lift], "d": [0, 1], "lean": [0, 0]}
			f = _pose(hero, view, base, cx, p)
			var g := Vector2i(int(v["grip"][0]), int(v["grip"][1]) - lift)
			spark_at = g + Vector2i(0, -8)
			if i > 0:
				_gem(f, spark_at, 1)
		"symbol":
			f = _pose(hero, view, base, cx, {"g": "idle"})
			var oh: Dictionary = v["offhand"]
			for r in oh["erase"]:
				for y in range(r[1], r[3] + 1):
					for x in range(r[0], r[2] + 1):
						f.put(ORIGIN + Vector2i(x, y), ".")
			var sh := _v(oh["shoulder"])
			var hand := Vector2i(cx - 4, 3 if i > 0 else 6)
			if view == "back":
				hand = Vector2i(sh.x + 1, 3 if i > 0 else 6)
			_arm(f, sh, hand, rig["arm"])
			f.put(ORIGIN + hand, "s")
			# holy symbol: a small golden cross above the hand
			for d in [Vector2i(0, -1), Vector2i(0, -2), Vector2i(0, -3), Vector2i(-1, -2), Vector2i(1, -2)]:
				f.put(ORIGIN + hand + d, "y")
			spark_at = hand + Vector2i(0, -2)
	if i == 1 and OS.get_environment("CAST_POINTS") != "":
		print("%s %s cast point %s" % [hero, view, spark_at - Vector2i(7, 21)])
	if i > 0:
		_sparkles(f, spark_at, i, glow)
	return f


## Glow around a point: a soft halo + a few sparks that move between frames 1-3.
func _sparkles(f: Frame, c: Vector2i, i: int, glow: Array) -> void:
	var col_a: Color = palette[glow[0]]
	var col_b: Color = palette[glow[1]]
	for y in range(-4, 5):
		for x in range(-4, 5):
			var d := Vector2(x, y).length()
			var p := ORIGIN + c + Vector2i(x, y)
			if d <= 3.6 and d >= 1.5 and f.get_px(p) == ".":
				var bayer := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
				if bayer[posmod(p.y, 4)][posmod(p.x, 4)] < int((1.0 - d / 3.6) * 16.0) + (i % 2) * 2:
					f.fx[p] = Color(col_a, 0.5)
	var sparks := [
		[Vector2i(-4, -2), Vector2i(3, -4), Vector2i(4, 1)],
		[Vector2i(-3, -5), Vector2i(5, -2), Vector2i(-5, 1)],
		[Vector2i(-1, -6), Vector2i(4, -5), Vector2i(-4, -1)],
	]
	for s: Vector2i in sparks[(i - 1) % 3]:
		f.fx[ORIGIN + c + s] = col_b


## Rogue's shortbow: held out in the forward hand, string drawn back to the chest.
func _bow(hero: String, view: String, base: Array, cx: int, i: int) -> Frame:
	var rig: Dictionary = RIG[hero]
	var v: Dictionary = rig[view]
	var fwd := -1
	var f := Frame.new()
	var lean := [1, 0] if i == 1 else [0, 0]
	_blit_body(f, base, lean, Vector2i.ZERO, 0)
	var hand := Vector2i(cx + 6 * fwd, 9)
	_arm(f, _v(v["shoulder"]), hand, rig["arm"])
	# bow limbs: curve away from the archer
	var top := hand + Vector2i(1 * -fwd, -5)
	var bot := hand + Vector2i(1 * -fwd, 5)
	for k in range(-5, 6):
		var bend := 0 if abs(k) >= 4 else 1
		if abs(k) <= 1:
			bend = 1
		f.put(ORIGIN + hand + Vector2i(bend * fwd + (1 if abs(k) >= 4 else 0) * -fwd, k), "b")
	f.put(ORIGIN + hand, "s")
	# string + arrow
	var pull: int = [1, 4, 0][i]
	var nock := hand + Vector2i((1 + pull) * -fwd, 0)
	for p in _line(top, nock) + _line(nock, bot):
		if f.get_px(ORIGIN + p) == ".":
			f.fx[ORIGIN + p] = Color(palette["o"], 0.8)
	if i < 2:
		for p in _line(nock, hand + Vector2i(3 * fwd, 0)):
			f.put(ORIGIN + p, "m")
		f.put(ORIGIN + hand + Vector2i(3 * fwd, 0), "w")
		f.put(ORIGIN + nock, "s")
	return f


## Down: drop to a knee (weapon point on the floor), then slump forward.
func _kneel(hero: String, view: String, base: Array, cx: int, stage: int) -> Frame:
	var lean := [1, 0] if stage == 1 else [2, 1]
	var p := {"g": [3, 15], "d": [1, -1], "lean": lean}
	if RIG[hero]["weapon"] == "staff":
		p = {"g": [2, 12], "d": [0.5, 1], "lean": lean}
	return _pose(hero, view, base, cx, p, stage)


## Lying on the floor: the stripped figure turned 90 degrees (head toward the facing), with the
## weapon dropped beside it.
func _lying(hero: String, view: String, base: Array) -> Frame:
	var f := Frame.new()
	var h := base.size()          # 22
	var w: int = base[0].length() # 14
	# 90 deg counter-clockwise: (x, y) -> (y, w-1-x): head (top) ends on the left.
	var at := Vector2i(5, 31 - w)
	for y in h:
		for x in w:
			var c: String = base[y][x]
			if c != ".":
				f.put(at + Vector2i(y, w - 1 - x), c)
	# dropped weapon along the floor, below/in front of the body
	var kind: String = RIG[hero]["weapon"]
	var g := Vector2i(at.x + 6 - ORIGIN.x, 30 - ORIGIN.y)
	_weapon(f, kind, g, Vector2(1, 0), true)
	return f


# --- image -------------------------------------------------------------------------------------

func _render(f: Frame) -> Image:
	var img := Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var c: String = f.px[y][x]
			if c != ".":
				if not palette.has(c):
					push_error("unknown palette key '%s'" % c)
					continue
				img.set_pixel(x, y, palette[c])
	var src := img.duplicate() as Image
	var outline: Color = palette["K"]
	for y in 32:
		for x in 32:
			if src.get_pixel(x, y).a > 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < 32 and p.y < 32 and src.get_pixelv(p).a > 0:
					img.set_pixel(x, y, outline)
					break
	for p: Vector2i in f.fx:
		if p.x >= 0 and p.y >= 0 and p.x < 32 and p.y < 32 and img.get_pixelv(p).a == 0:
			img.set_pixelv(p, f.fx[p])
	return img


# --- helpers -----------------------------------------------------------------------------------

## The standing idle drawing (legs + upper body) as 22 strings of 14 chars.
func _idle_rows(v: Dictionary) -> Array:
	var rows := []
	for r in 22:
		rows.append("..............")
	var legs: Array = v["legs"]
	for i in legs.size():
		rows[16 + i] = legs[i]
	var upper: Array = v["upper"]
	for i in upper.size():
		var merged := ""
		for x in 14:
			var c: String = upper[i][x]
			merged += c if c != "." else rows[i][x]
		rows[i] = merged
	return rows


func _strip(rows: Array, rects: Array) -> Array:
	var out := rows.duplicate()
	for r in rects:
		for y in range(r[1], r[3] + 1):
			var s: String = out[y]
			for x in range(r[0], r[2] + 1):
				s[x] = "."
			out[y] = s
	return out


## Middle column of the torso (rows 7-15).
func _centre_x(rows: Array) -> int:
	var lo := 99
	var hi := -1
	for y in range(7, 16):
		for x in rows[y].length():
			if rows[y][x] != ".":
				lo = mini(lo, x)
				hi = maxi(hi, x)
	return (lo + hi) / 2


func _v(a: Array) -> Vector2i:
	return Vector2i(a[0], a[1])


## t pixels along dir (dir scaled so its larger component is 1: diagonal lines stay pixel lines).
func _step(dir: Vector2, t: int) -> Vector2i:
	var m := maxf(absf(dir.x), absf(dir.y))
	var u := dir / m
	return Vector2i(roundi(u.x * t), roundi(u.y * t))


func _perp(dir: Vector2) -> Vector2i:
	var m := maxf(absf(dir.x), absf(dir.y))
	var u := dir / m
	return Vector2i(roundi(-u.y), roundi(u.x))


func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var t := 0.0 if n == 0 else float(i) / n
		out.append(Vector2i(Vector2(a).lerp(Vector2(b), t).round()))
	return out


func _parse_palette(src: String) -> Dictionary:
	var block := src.substr(src.find("P = {"))
	block = block.substr(0, block.find("}"))
	var re := RegEx.create_from_string("\"(\\w)\":\\s*\\((\\d+),\\s*(\\d+),\\s*(\\d+)\\)")
	var pal := {}
	for m in re.search_all(block):
		pal[m.get_string(1)] = Color8(int(m.get_string(2)), int(m.get_string(3)), int(m.get_string(4)))
	return pal
