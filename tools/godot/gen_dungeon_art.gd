extends SceneTree
## Dungeon furniture art: stairs (up / down) and props (barrel, crate, sarcophagus, rubble,
## cocoon, urn, brazier bowl) -> assets/sprites/props/*.png
## Run: Godot_console --headless --path . -s res://tools/godot/gen_dungeon_art.gd  (then --import)
##
## Same look as gen_art.gd: limited palettes, light 4x4 Bayer dithering, light from the left
## (lit lower-left faces 0.62, darker lower-right 0.44), 1px dark outline on standing props.
## Boxes are drawn with a tiny iso rasterizer: map point (mx, my) in cells relative to the cell
## centre and z in px up -> image (ox + (mx - my) * 16, oy + (mx + my) * 8 - z).
## Each sprite's cell centre (feet) is at the offset noted next to it; Prop.OFFSETS matches.

const OUT := "res://assets/sprites/props/"
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
const BRICK := [Color8(26, 24, 30), Color8(46, 43, 50), Color8(64, 60, 66), Color8(84, 78, 82), Color8(106, 98, 98), Color8(128, 118, 114)]
const FLOOR := [Color8(22, 20, 26), Color8(38, 36, 44), Color8(54, 52, 60), Color8(72, 69, 76), Color8(92, 88, 94), Color8(114, 108, 112)]
const WOOD := [Color8(34, 22, 18), Color8(56, 36, 24), Color8(80, 50, 28), Color8(104, 66, 34), Color8(134, 90, 48), Color8(166, 120, 68)]
const IRON := [Color8(24, 20, 24), Color8(40, 36, 40), Color8(62, 58, 62), Color8(92, 88, 92), Color8(130, 126, 128)]
const SILK := [Color8(70, 66, 80), Color8(104, 100, 114), Color8(140, 136, 150), Color8(178, 174, 186), Color8(214, 212, 220), Color8(240, 238, 244)]
const CLAY := [Color8(52, 28, 22), Color8(84, 44, 30), Color8(118, 64, 40), Color8(150, 88, 54), Color8(184, 120, 76)]
const OUTLINE := Color8(20, 16, 24)

var img: Image
var ox := 0.0
var oy := 0.0


func _init() -> void:
	_stairs_up()
	_stairs_down()
	_barrel()
	_crate()
	_sarcophagus()
	_rubble()
	_cocoon()
	_urn()
	_brazier()
	print("gen_dungeon_art: done")
	quit()


# --- helpers -----------------------------------------------------------------------------------

func _new(w: int, h: int, origin: Vector2) -> void:
	img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	ox = origin.x
	oy = origin.y


func _save(name: String, outline := true) -> void:
	if outline:
		_outline()
	var err := img.save_png(OUT + name + ".png")
	print("  ", OUT, name, ".png ", img.get_size(), "" if err == OK else " ERROR %d" % err)


## Brightness v (0..1) -> palette colour with ordered dithering.
func _q(v: float, x: int, y: int, pal: Array) -> Color:
	v = v * (pal.size() - 1) + (BAYER[y % 4][x % 4] / 16.0 - 0.5) * 0.6
	return pal[clampi(roundi(v), 0, pal.size() - 1)]


func _scr(mx: float, my: float, z: float) -> Vector2:
	return Vector2(ox + (mx - my) * 16.0, oy + (mx + my) * 8.0 - z)


## Fill a convex polygon; shade(px, py) returns a Color (alpha 0 = skip).
func _fill(poly: PackedVector2Array, shade: Callable, clip: PackedVector2Array = PackedVector2Array()) -> void:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	for py in range(maxi(0, floori(r.position.y)), mini(img.get_height(), ceili(r.end.y) + 1)):
		for px in range(maxi(0, floori(r.position.x)), mini(img.get_width(), ceili(r.end.x) + 1)):
			var c := Vector2(px + 0.5, py + 0.5)
			if not Geometry2D.is_point_in_polygon(c, poly):
				continue
			if not clip.is_empty() and not Geometry2D.is_point_in_polygon(c, clip):
				continue
			var col: Color = shade.call(px, py)
			if col.a > 0.0:
				img.set_pixel(px, py, col)


## Draw an axis-aligned box [x0,x1] x [y0,y1] x [z0,z1] (cells, cells, px). shade(face, u, v, px, py)
## gets face "top" / "left" (the +y face, lit) / "right" (the +x face, dark), u = position along
## the face in px from its left end, v = height above z0 in px (top: u along x, v along y, in px).
func _box(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, shade: Callable,
		clip: PackedVector2Array = PackedVector2Array()) -> void:
	# +y face (lower-left on screen)
	_fill(PackedVector2Array([_scr(x0, y1, z0), _scr(x1, y1, z0), _scr(x1, y1, z1), _scr(x0, y1, z1)]),
		func(px: int, py: int) -> Color:
			var mx := (px + 0.5 - ox) / 16.0 + y1
			var z := (mx + y1) * 8.0 - (py + 0.5 - oy)
			return shade.call("left", (mx - x0) * 16.0, z - z0, px, py), clip)
	# +x face (lower-right on screen)
	_fill(PackedVector2Array([_scr(x1, y1, z0), _scr(x1, y0, z0), _scr(x1, y0, z1), _scr(x1, y1, z1)]),
		func(px: int, py: int) -> Color:
			var my := x1 - (px + 0.5 - ox) / 16.0
			var z := (x1 + my) * 8.0 - (py + 0.5 - oy)
			return shade.call("right", (y1 - my) * 16.0, z - z0, px, py), clip)
	# top
	_fill(PackedVector2Array([_scr(x0, y0, z1), _scr(x1, y0, z1), _scr(x1, y1, z1), _scr(x0, y1, z1)]),
		func(px: int, py: int) -> Color:
			var a := (px + 0.5 - ox) / 16.0
			var b := (py + 0.5 - oy + z1) / 8.0
			var mx := (a + b) / 2.0
			var my := (b - a) / 2.0
			return shade.call("top", (mx - x0) * 16.0, (my - y0) * 16.0, px, py), clip)


## Transparent pixels touching an opaque one become the dark outline.
func _outline() -> void:
	var src := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() and src.get_pixelv(p).a > 0.5:
					img.set_pixel(x, y, OUTLINE)
					break


const FACE_LIGHT := {"top": 0.78, "left": 0.62, "right": 0.44}


# --- stairs ------------------------------------------------------------------------------------

## Stairs up: four stone steps rising toward the back (up-right on screen), 24 px to the top.
## 32x44 image, cell centre at (16, 34).
func _stairs_up() -> void:
	_new(34, 46, Vector2(17, 36))
	const N := 4
	const RISE := 6.0
	# Light worn treads (floor stone), dark risers in shadow, brick sides: reads as steps even
	# against a brick wall.
	for i in range(N - 1, -1, -1):          # back (top) step first
		var y0 := 0.44 - (i + 1) * 0.88 / N
		var y1 := 0.44 - i * 0.88 / N
		var top := (i + 1) * RISE
		_box(-0.4, 0.4, y0, y1, 0.0, top, func(face: String, u: float, v: float, px: int, py: int) -> Color:
			var val := 0.5
			if face == "top":
				val = 0.8
				if v < 1.2:
					val = 1.0                            # worn, lit nosing
				elif v > 0.88 * 16.0 / N - 1.2:
					val = 0.55
				return _q(val, px, py, FLOOR)
			if face == "left":                       # riser, facing the viewer, in shadow
				val = 0.3 if v < top - 1.0 else 0.12     # dark line under the nosing
				return _q(val, px, py, FLOOR)
			if fmod(v, RISE) < 1.0:                  # side of the flight
				val = 0.15
			return _q(val, px, py, BRICK))
	_save("stairs_up")


## Stairs down: a stone-rimmed opening in the floor with steps going down toward the viewer
## into darkness. 34x18 image, cell centre at (17, 9). Lies flat (no outline).
func _stairs_down() -> void:
	_new(34, 18, Vector2(17, 9))
	const IN := 0.4                         # opening half-size (cells)
	const RISE := 3.0
	var hole := PackedVector2Array([_scr(-IN, -IN, 0), _scr(IN, -IN, 0), _scr(IN, IN, 0), _scr(-IN, IN, 0)])
	var dark := func(z: float, base: float) -> float:
		return base * clampf(1.0 + z / 22.0, 0.15, 1.0)
	_fill(hole, func(px: int, py: int) -> Color: return Color8(10, 8, 14))   # the void below
	# Back walls of the shaft (facing the viewer).
	_box(-IN - 0.2, -IN, -IN, IN, -30.0, 0.0, func(face: String, u: float, v: float, px: int, py: int) -> Color:
		var val: float = dark.call(v - 30.0, 0.5)
		if fmod(v, RISE * 2.0) < 1.0:
			val *= 0.5
		return _q(clampf(val, 0, 1), px, py, BRICK), hole)
	_box(-IN, IN, -IN - 0.2, -IN, -30.0, 0.0, func(face: String, u: float, v: float, px: int, py: int) -> Color:
		var val: float = dark.call(v - 30.0, 0.66)
		if fmod(v, RISE * 2.0) < 1.0:
			val *= 0.5
		return _q(clampf(val, 0, 1), px, py, BRICK), hole)
	# Steps, highest at the back, going down toward the viewer.
	const N := 5
	for i in N:
		var y0 := -IN + i * 2.0 * IN / N
		var y1 := y0 + 2.0 * IN / N
		var top := -(i + 1) * RISE
		_box(-IN, IN, y0, y1, -30.0, top, func(face: String, u: float, v: float, px: int, py: int) -> Color:
			var z := top if face == "top" else v - 30.0
			var val: float = dark.call(z, FACE_LIGHT[face] + 0.1)
			if face == "top" and v < 1.0:
				val += 0.15                          # lit nosing of each tread
			if face == "left":
				val *= 0.7                           # risers in shadow
			return _q(clampf(val, 0, 1), px, py, BRICK), hole)
	# Rim: a stone lip round the opening; the back edges catch the light.
	var rim := PackedVector2Array([_scr(-0.5, -0.5, 0), _scr(0.5, -0.5, 0), _scr(0.5, 0.5, 0), _scr(-0.5, 0.5, 0)])
	_fill(rim, func(px: int, py: int) -> Color:
		var c := Vector2(px + 0.5, py + 0.5)
		if Geometry2D.is_point_in_polygon(c, hole):
			return Color(0, 0, 0, 0)
		return _q(0.85 if c.y < oy else 0.55, px, py, FLOOR))
	_save("stairs_down", false)


# --- props -------------------------------------------------------------------------------------

## Barrel: 14x18, feet at (7, 15).
func _barrel() -> void:
	_new(16, 20, Vector2(8, 16))
	const R := 6.0
	const H := 13.0
	for py in img.get_height():
		for px in img.get_width():
			var x := px + 0.5 - ox
			if absf(x) > R:
				continue
			var nx := x / R
			var ell := sqrt(1.0 - nx * nx) * R * 0.45          # ellipse half-height at this x
			var y := py + 0.5 - oy
			if y > ell or y < -H - ell:
				continue
			var top := y < -H + ell
			var val: float
			if top:
				var inner := Vector2(x / (R - 1.5), (y + H) / (R * 0.45 - 0.7)).length()
				val = 0.5 if inner < 1.0 else 0.72
				if inner < 1.0 and int(x + 10) % 4 == 0:
					val = 0.36
				img.set_pixel(px, py, _q(val, px, py, WOOD))
				continue
			val = 0.52 - 0.3 * nx + 0.1 * sqrt(1.0 - nx * nx)
			var h := -y                                         # height above the base
			var bulge := 1.0 - pow((h - H / 2.0) / (H / 2.0), 2)
			val += 0.06 * bulge
			if absf(fmod(x + 8.0 + 0.5, 3.4)) < 0.6:
				val -= 0.18                                     # stave joints
			var hoop := absf(h - 2.5) < 1.0 or absf(h - (H - 2.5)) < 1.0
			if hoop:
				img.set_pixel(px, py, _q(clampf(val * 0.8, 0, 1), px, py, IRON))
			else:
				img.set_pixel(px, py, _q(clampf(val, 0, 1), px, py, WOOD))
	_save("barrel")


## Crate: 0.64-cell wooden box, 12 px tall. 26x26, feet at (13, 18).
func _crate() -> void:
	_new(28, 28, Vector2(14, 19))
	const S := 0.32
	const H := 12.0
	var w := S * 32.0
	_box(-S, S, -S, S, 0.0, H, func(face: String, u: float, v: float, px: int, py: int) -> Color:
		var val: float = FACE_LIGHT[face] - 0.3
		var frame := u < 2.0 or u > w - 2.0
		if face == "top":
			frame = frame or v < 2.0 or v > w - 2.0
			if not frame and fmod(u - 2.0, 4.0) < 1.0:
				val = 0.08                                      # gaps between lid planks
		else:
			frame = frame or v < 2.0 or v > H - 2.0
			if not frame and absf(v - 2.0 - (u - 2.0) * (H - 4.0) / (w - 4.0)) < 1.0:
				val += 0.1                                      # diagonal brace
			elif not frame and fmod(v - 2.0, 4.0) < 1.0:
				val = 0.08                                      # gaps between side planks
		if frame:
			val += 0.1
		return _q(clampf(val, 0, 1), px, py, WOOD))
	_save("crate")


## Sarcophagus: stone coffin along the cell's x axis with a carved lid. 30x26, feet at (15, 16).
func _sarcophagus() -> void:
	_new(32, 28, Vector2(16, 17))
	var stone := func(face: String, u: float, v: float, px: int, py: int) -> Color:
		var val: float = FACE_LIGHT[face]
		if face != "top" and v > 6.0 and v < 7.2:
			val -= 0.2
		return _q(clampf(val, 0, 1), px, py, FLOOR)
	_box(-0.44, 0.44, -0.2, 0.2, 0.0, 8.0, stone)
	_box(-0.47, 0.47, -0.23, 0.23, 8.0, 11.0, func(face: String, u: float, v: float, px: int, py: int) -> Color:
		var val: float = FACE_LIGHT[face] + 0.06
		if face == "top":
			# carved figure: a raised panel with a cross down the middle of the lid
			var cu := u - 0.47 * 16.0
			var cv := v - 0.23 * 16.0
			if absf(cu) < 11.0 and absf(cv) < 2.6:
				val -= 0.12
			if absf(cv) < 0.7 and absf(cu) < 9.0 or absf(cu + 4.0) < 0.8 and absf(cv) < 2.4:
				val += 0.16
		return _q(clampf(val, 0, 1), px, py, FLOOR))
	_save("sarcophagus")


## Rubble: a heap of fallen stones. 30x18, feet at (15, 11).
func _rubble() -> void:
	_new(32, 20, Vector2(16, 12))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var stones := []
	for i in 9:
		var cx := rng.randf_range(-0.3, 0.3)
		var cy := rng.randf_range(-0.3, 0.3)
		var s := rng.randf_range(0.07, 0.15)
		var h := rng.randf_range(3.0, 6.0) + (3.0 if Vector2(cx, cy).length() < 0.15 else 0.0)
		stones.append([cx, cy, s, h])
	stones.sort_custom(func(a, b): return a[0] + a[1] < b[0] + b[1])
	for st in stones:
		var cx: float = st[0]
		var cy: float = st[1]
		var s: float = st[2]
		var h: float = st[3]
		var z0 := 0.0 if Vector2(cx, cy).length() > 0.15 else 1.5
		var tone := rng.randf_range(-0.12, 0.08)
		var w := s * 32.0
		_box(cx - s, cx + s, cy - s, cy + s, z0, z0 + h, func(face: String, u: float, v: float, px: int, py: int) -> Color:
			var val: float = FACE_LIGHT[face] + tone
			if face != "top" and (u < 0.8 or u > w - 0.8):
				val -= 0.3                                  # dark cracks between stones
			elif face == "top" and (u < 0.8 or v < 0.8):
				val += 0.1
			return _q(clampf(val, 0, 1), px, py, BRICK))
	_save("rubble")


## Cocoon: a body wrapped in spider silk, standing. 14x24, feet at (7, 21).
func _cocoon() -> void:
	_new(16, 26, Vector2(8, 22))
	const H := 19.0
	for py in img.get_height():
		for px in img.get_width():
			var x := px + 0.5 - ox
			var h := oy - (py + 0.5)                   # height above the feet
			if h < -1.5 or h > H:
				continue
			var t := clampf(h / H, 0.0, 1.0)
			# body profile: narrow feet, wide shoulders at ~65%, round head on top
			var half := 2.2 + 3.0 * sin(PI * clampf(t * 0.85 + 0.05, 0.0, 1.0))
			if t > 0.74:
				half = 2.8 * sqrt(maxf(0.0, 1.0 - pow((t - 0.86) / 0.15, 2)))
			if absf(x) > half:
				continue
			var nx := x / maxf(half, 0.5)
			var val := 0.42 - 0.26 * nx + 0.12 * sqrt(maxf(0.0, 1.0 - nx * nx))
			if absf(fmod(h + x * 0.9 + 20.0, 3.6)) < 0.6:
				val += 0.22                            # wrapping strands
			elif absf(fmod(h - x * 1.4 + 20.0, 5.5)) < 0.5:
				val += 0.14
			img.set_pixel(px, py, _q(clampf(val, 0, 1), px, py, SILK))
	_save("cocoon")


## Urn: a clay pot. 12x14, feet at (6, 12).
func _urn() -> void:
	_new(14, 16, Vector2(7, 13))
	for py in img.get_height():
		for px in img.get_width():
			var x := px + 0.5 - ox
			var h := oy - (py + 0.5)
			if h < -1.0 or h > 11.0:
				continue
			var half: float
			if h > 9.0:
				half = 2.8                             # rim
			elif h > 7.0:
				half = 2.0                             # neck
			else:
				half = 1.8 + 3.0 * sin(PI * (h + 1.0) / 8.5)
			if absf(x) > half:
				continue
			var nx := x / half
			var val := 0.55 - 0.32 * nx + 0.1 * sqrt(maxf(0.0, 1.0 - nx * nx))
			if absf(h - 4.5) < 0.6:
				val -= 0.25                            # painted band
			img.set_pixel(px, py, _q(clampf(val, 0, 1), px, py, CLAY))
	_save("urn")


## Brazier bowl on three iron legs (the flame is the torch sheet, added at runtime).
## 18x16, feet at (9, 13). Bowl rim at 9 px up.
func _brazier() -> void:
	_new(20, 18, Vector2(10, 14))
	for leg in [-5, 0, 5]:
		for h in 7:
			var px: int = int(ox) + leg + (1 if leg < 0 and h > 4 else (-1 if leg > 0 and h > 4 else 0)) - 1
			var py: int = int(oy) - h + (2 if leg == 0 else 0)
			img.set_pixel(px, py, IRON[2 if leg < 0 else 1])
	for py in img.get_height():
		for px in img.get_width():
			var x := px + 0.5 - ox
			var y := py + 0.5 - oy
			var h := -y
			if h < 6.0 or h > 10.5:
				continue
			var half := 3.0 + (h - 6.0) * 1.2
			if absf(x) > half:
				continue
			var val := 0.6 - 0.35 * x / half
			if h > 9.5:
				val = 0.2                              # dark coals in the bowl
				img.set_pixel(px, py, _q(0.4, px, py, [Color8(60, 20, 14), Color8(110, 34, 18), Color8(170, 60, 24)]))
				continue
			img.set_pixel(px, py, _q(clampf(val, 0, 1), px, py, IRON))
	_save("brazier")
