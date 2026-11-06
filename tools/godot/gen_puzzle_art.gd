extends SceneTree
## Phase 6 art: traps, pressure plates, levers, the pushable stone block and the riddle stone face
## -> assets/sprites/props/*.png
## Run: Godot_console --headless --path . -s res://tools/godot/gen_puzzle_art.gd  (then --import)
##
## Same look and helpers as gen_dungeon_art.gd: limited palettes, light 4x4 Bayer dithering, light
## from the left (lit lower-left faces, darker lower-right), 1px dark outline on standing things.
## Map point (mx, my) in cells relative to the cell centre, z in px up ->
## image (ox + (mx - my) * 16, oy + (mx + my) * 8 - z).
## Flat floor pieces (traps, plates) are 34x18 with the cell centre at (17, 9) (offset (-17, -9)),
## like stairs_down. The other origins are listed with each sprite (Trap / Lever / Prop / StoneFace
## use the same numbers).

const OUT := "res://assets/sprites/props/"
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
const BRICK := [Color8(26, 24, 30), Color8(46, 43, 50), Color8(64, 60, 66), Color8(84, 78, 82), Color8(106, 98, 98), Color8(128, 118, 114)]
const FLOOR := [Color8(22, 20, 26), Color8(38, 36, 44), Color8(54, 52, 60), Color8(72, 69, 76), Color8(92, 88, 94), Color8(114, 108, 112)]
const WOOD := [Color8(34, 22, 18), Color8(56, 36, 24), Color8(80, 50, 28), Color8(104, 66, 34), Color8(134, 90, 48), Color8(166, 120, 68)]
const IRON := [Color8(24, 20, 24), Color8(40, 36, 40), Color8(62, 58, 62), Color8(92, 88, 92), Color8(130, 126, 128), Color8(176, 172, 172)]
const FIRE := [Color8(110, 20, 10), Color8(200, 50, 20), Color8(255, 130, 30), Color8(255, 210, 80)]
const RUST := [Color8(48, 24, 20), Color8(78, 38, 28), Color8(110, 56, 36), Color8(140, 78, 48)]
const SILK := [Color8(104, 100, 114), Color8(140, 136, 150), Color8(178, 174, 186), Color8(214, 212, 220)]
const BRASS := [Color8(96, 64, 24), Color8(150, 106, 40), Color8(206, 160, 64), Color8(246, 214, 120)]
const OUTLINE := Color8(20, 16, 24)
const FACE_LIGHT := {"top": 0.78, "left": 0.62, "right": 0.44}

var img: Image
var ox := 0.0
var oy := 0.0


func _init() -> void:
	_trap_spikes()
	_trap_darts()
	_trap_fire()
	_trap_pit()
	_trap_wire()
	_plates()
	_levers()
	_block()
	_stone_face()
	print("gen_puzzle_art: done")
	quit()


# --- helpers (as gen_dungeon_art.gd) ---------------------------------------------------------

func _new(w: int, h: int, origin: Vector2) -> void:
	img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	ox = origin.x
	oy = origin.y


func _save(name: String, outline := true) -> void:
	if outline:
		_outline()
	var err := img.save_png(OUT + name + ".png")
	print("  ", OUT, name, ".png ", img.get_size(), "" if err == OK else " ERROR %d" % err)


func _q(v: float, x: int, y: int, pal: Array) -> Color:
	v = v * (pal.size() - 1) + (BAYER[y % 4][x % 4] / 16.0 - 0.5) * 0.6
	return pal[clampi(roundi(v), 0, pal.size() - 1)]


func _scr(mx: float, my: float, z: float) -> Vector2:
	return Vector2(ox + (mx - my) * 16.0, oy + (mx + my) * 8.0 - z)


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


## Box [x0,x1] x [y0,y1] x [z0,z1]; shade(face, u, v, px, py) as in gen_dungeon_art.gd
## (top: u along x, v along y, both in px from the x0 / y0 edges).
func _box(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, shade: Callable) -> void:
	_fill(PackedVector2Array([_scr(x0, y1, z0), _scr(x1, y1, z0), _scr(x1, y1, z1), _scr(x0, y1, z1)]),
		func(px: int, py: int) -> Color:
			var mx := (px + 0.5 - ox) / 16.0 + y1
			var z := (mx + y1) * 8.0 - (py + 0.5 - oy)
			return shade.call("left", (mx - x0) * 16.0, z - z0, px, py))
	_fill(PackedVector2Array([_scr(x1, y1, z0), _scr(x1, y0, z0), _scr(x1, y0, z1), _scr(x1, y1, z1)]),
		func(px: int, py: int) -> Color:
			var my := x1 - (px + 0.5 - ox) / 16.0
			var z := (x1 + my) * 8.0 - (py + 0.5 - oy)
			return shade.call("right", (y1 - my) * 16.0, z - z0, px, py))
	_fill(PackedVector2Array([_scr(x0, y0, z1), _scr(x1, y0, z1), _scr(x1, y1, z1), _scr(x0, y1, z1)]),
		func(px: int, py: int) -> Color:
			var a := (px + 0.5 - ox) / 16.0
			var b := (py + 0.5 - oy + z1) / 8.0
			var mx := (a + b) / 2.0
			var my := (b - a) / 2.0
			return shade.call("top", (mx - x0) * 16.0, (my - y0) * 16.0, px, py))


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


func _px(p: Vector2, col: Color) -> void:
	var x := floori(p.x)
	var y := floori(p.y)
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)


func _line(a: Vector2, b: Vector2, col: Color) -> void:
	var n := maxi(1, ceili(a.distance_to(b)))
	for i in n + 1:
		_px(a.lerp(b, float(i) / n), col)


## A floor plate: a square slab, `h` px proud of the floor. `top(u, v, px, py)` shades its top
## (u, v in px across the slab, 0..size); the sides are plain stone.
func _slab(half: float, h: float, pal: Array, top: Callable) -> void:
	_box(-half, half, -half, half, 0.0, h, func(face: String, u: float, v: float, px: int, py: int) -> Color:
		if face == "top":
			return top.call(u, v, px, py)
		return _q(FACE_LIGHT[face] * 0.8, px, py, pal))


# --- traps (flat, 34x18, centre (17, 9)) ------------------------------------------------------

## Spike plate: a square stone plate pocked with a 3x3 grid of dark holes.
func _spike_plate(sprung: bool) -> void:
	_slab(0.36, 1.0, FLOOR, func(u: float, v: float, px: int, py: int) -> Color:
		var edge := u < 1.2 or v < 1.2 or u > 10.3 or v > 10.3
		var hu := fmod(u - 1.9, 3.6)
		var hv := fmod(v - 1.9, 3.6)
		if not edge and hu > 0.0 and hu < 1.3 and hv > 0.0 and hv < 1.3:
			return OUTLINE
		return _q(0.85 if edge else 0.58, px, py, FLOOR))
	if not sprung:
		return
	# Steel spikes shot up out of the holes (back rows first).
	for j in 3:
		for i in 3:
			var mx := -0.36 + (2.5 + i * 3.6) / 16.0
			var my := -0.36 + (2.5 + j * 3.6) / 16.0
			var base := _scr(mx, my, 1.0)
			var h := 7 + (i + j) % 2
			for z in h:
				var col: Color = IRON[clampi(2 + z * 4 / h, 2, 5)]
				_px(base + Vector2(0, -z), col)
				if z < h - 3:
					_px(base + Vector2(-1, -z), IRON[1])


func _trap_spikes() -> void:
	_new(34, 18, Vector2(17, 9))
	_spike_plate(false)
	_save("trap_spikes", false)
	_new(34, 26, Vector2(17, 17))
	_spike_plate(true)
	_save("trap_spikes_sprung", true)


## Dart plate: a plate with a cross seam; sprung = pressed flush, three darts lie about.
func _trap_darts() -> void:
	for sprung in [false, true]:
		_new(34, 18, Vector2(17, 9))
		_slab(0.34, 0.0 if sprung else 1.0, FLOOR, func(u: float, v: float, px: int, py: int) -> Color:
			var edge := u < 1.2 or v < 1.2 or u > 9.7 or v > 9.7
			if not edge and (absf(u - 5.45) < 0.6 or absf(v - 5.45) < 0.6):
				return _q(0.3, px, py, FLOOR)
			return _q(0.8 if edge else 0.55, px, py, RUST if (u + v) < 6.0 and not edge else FLOOR))
		if sprung:
			for d in [[Vector2(-0.3, 0.45), Vector2(4, 1)], [Vector2(0.42, -0.1), Vector2(3, -2)], [Vector2(0.1, 0.5), Vector2(-4, 1)]]:
				var a: Vector2 = _scr(d[0].x, d[0].y, 0.0)
				var b: Vector2 = a + d[1]
				_line(a, b, IRON[4])
				_px(a, Color8(200, 50, 40))
		_save("trap_darts_sprung" if sprung else "trap_darts", false)


## Fire vent: an iron grate with embers glowing between the bars; sprung = burnt out, sooty.
func _trap_fire() -> void:
	for sprung in [false, true]:
		_new(34, 18, Vector2(17, 9))
		_slab(0.36, 1.0, IRON, func(u: float, v: float, px: int, py: int) -> Color:
			var edge := u < 1.2 or v < 1.2 or u > 10.3 or v > 10.3
			if edge:
				return _q(0.7, px, py, IRON)
			if fmod(u, 2.6) < 1.1:
				return _q(0.55 if not sprung else 0.25, px, py, IRON)
			if sprung:
				return _q(0.05, px, py, FLOOR)
			var glow := 1.0 - absf(v - 5.7) / 5.0
			return _q(clampf(glow * 0.9, 0.0, 1.0), px, py, FIRE))
		if sprung:                         # soot round the grate
			for y in img.get_height():
				for x in img.get_width():
					if img.get_pixel(x, y).a == 0.0 and (BAYER[y % 4][x % 4] < 5) and absf(x - ox) / 17.0 + absf(y - oy) / 8.5 < 0.95:
						img.set_pixel(x, y, Color8(16, 12, 14, 200))
		_save("trap_fire_sprung" if sprung else "trap_fire", false)


## Pit: a trapdoor of two wooden leaves in a stone rim; sprung = the leaves hang open over a dark
## shaft with spikes at the bottom.
func _trap_pit() -> void:
	_new(34, 18, Vector2(17, 9))
	_slab(0.42, 0.0, FLOOR, func(u: float, v: float, px: int, py: int) -> Color:
		var edge := u < 1.3 or v < 1.3 or u > 12.1 or v > 12.1
		if edge:
			return _q(0.75, px, py, FLOOR)
		if absf(u - 6.7) < 0.55:
			return OUTLINE                                     # the seam between the leaves
		var plank := fmod(v, 3.4) < 0.6
		return _q(0.32 if plank else 0.52, px, py, WOOD))
	_save("trap_pit", false)
	_new(34, 18, Vector2(17, 9))
	const IN := 0.36
	var hole := PackedVector2Array([_scr(-IN, -IN, 0), _scr(IN, -IN, 0), _scr(IN, IN, 0), _scr(-IN, IN, 0)])
	_fill(PackedVector2Array([_scr(-0.46, -0.46, 0), _scr(0.46, -0.46, 0), _scr(0.46, 0.46, 0), _scr(-0.46, 0.46, 0)]),
		func(px: int, py: int) -> Color:
			var c := Vector2(px + 0.5, py + 0.5)
			if Geometry2D.is_point_in_polygon(c, hole):
				# the shaft: back walls lit a little near the top, black below; spike tips deep down
				var depth := (c.y - (oy - IN * 8.0)) / (IN * 16.0)
				if int(px) % 3 == 0 and depth > 0.75 and depth < 0.95:
					return IRON[2]                             # spike tips far below
				if depth < 0.22:
					return _q(0.3, px, py, BRICK)              # the far wall of the shaft, just lit
				return Color8(8, 6, 12)
			return _q(0.85 if c.y < oy else 0.55, px, py, FLOOR))
	_save("trap_pit_open", false)


## Tripwire: a pale cord between two pegs with a little bell; sprung = cut, the ends lie slack.
func _trap_wire() -> void:
	for sprung in [false, true]:
		_new(34, 18, Vector2(17, 9))
		var a := _scr(-0.42, 0.3, 0.0)
		var b := _scr(0.3, -0.42, 0.0)
		for p in [a, b]:
			for z in 4:
				_px(p + Vector2(0, -z), WOOD[3 if z < 3 else 5])
				_px(p + Vector2(1, -z), WOOD[1])
		if sprung:
			_line(a + Vector2(1, -3), a.lerp(b, 0.35) + Vector2(0, 1), SILK[1])
			_line(b + Vector2(0, -3), b.lerp(a, 0.3) + Vector2(0, 1), SILK[1])
		else:
			_line(a + Vector2(1, -3), b + Vector2(0, -3), SILK[3])
			var bell := a.lerp(b, 0.62) + Vector2(0, -2)
			for d in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(-1, 1)]:
				_px(bell + d, BRASS[2])
			_px(bell + Vector2(0, 2), BRASS[0])
		_save("trap_wire_cut" if sprung else "trap_wire", true)


# --- pressure plate (flat, 34x18, centre (17, 9)) -------------------------------------------

## A square stone raised 2 px with a ring rune; pressed = flush, the rune cut deeper.
func _plates() -> void:
	for down in [false, true]:
		_new(34, 20, Vector2(17, 11))
		_slab(0.38, 0.0 if down else 2.0, BRICK, func(u: float, v: float, px: int, py: int) -> Color:
			var edge := u < 1.2 or v < 1.2 or u > 11.0 or v > 11.0
			var r := Vector2(u - 6.1, v - 6.1).length()
			if absf(r - 3.6) < 0.7 or r < 0.9:
				return _q(0.12 if down else 0.25, px, py, BRICK)
			return _q(0.9 if edge else 0.68, px, py, BRICK))
		_save("plate_down" if down else "plate", false)


# --- lever (24x34, cell centre (12, 27)) ------------------------------------------------------

## A stone pedestal with an iron lever: up = leaning back-left, down = pulled forward-right.
## The symbol plaque on its lit (left) face is blank: Lever draws the symbol in code.
func _levers() -> void:
	for down in [false, true]:
		_new(24, 34, Vector2(12, 27))
		var shadow := func(px: int, py: int) -> Color:
			return Color(0, 0, 0, 0)
		_box(-0.24, 0.24, -0.24, 0.24, 0.0, 10.0, func(face: String, u: float, v: float, px: int, py: int) -> Color:
			var val: float = FACE_LIGHT[face]
			if face == "top" and (u < 1.0 or v < 1.0):
				val = 0.95
			if face != "top" and v > 8.5:
				val += 0.12                                    # a lip round the top
			if face == "left" and u > 1.4 and u < 6.4 and v > 2.0 and v < 7.6:
				val = 0.3                                      # the plaque (symbol goes here)
			return _q(val, px, py, BRICK))
		var pivot := _scr(0, 0, 10.0) + Vector2(0, -1)
		var tip := pivot + (Vector2(5, -6) if down else Vector2(-4, -9))
		for d in [Vector2(0, 0), Vector2(1, 0)]:
			_line(pivot + d, tip + d, IRON[3] if d.x == 0 else IRON[1])
		for d in [Vector2(-1, -1), Vector2(0, -1), Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)]:
			_px(tip + d, Color8(176, 44, 36) if d.y >= 0 else Color8(226, 92, 70))
		for d in [Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 1), Vector2(1, 1)]:
			_px(pivot + d, IRON[2])
		_save("lever_down" if down else "lever_up", true)


# --- pushable stone block (28x34, cell centre (14, 27)) -------------------------------------

## A heavy carved block with a square rune on each face, scuff marks at the base (it slides).
func _block() -> void:
	_new(28, 34, Vector2(14, 27))
	_box(-0.38, 0.38, -0.38, 0.38, 0.0, 17.0, func(face: String, u: float, v: float, px: int, py: int) -> Color:
		var val: float = FACE_LIGHT[face]
		var w := 12.2 if face != "top" else 12.2
		if face == "top":
			if u < 1.0 or v < 1.0:
				val = 0.95
			elif absf(u - 6.1) < 3.4 and absf(v - 6.1) < 3.4 and (absf(u - 6.1) > 2.4 or absf(v - 6.1) > 2.4):
				val -= 0.25
			return _q(val, px, py, FLOOR)
		var cu := absf(u - w * 0.5)
		var cv := absf(v - 9.0)
		if cu < 3.6 and cv < 4.0 and (cu > 2.4 or cv > 2.8):
			val -= 0.25                                        # carved square
		if cu < 0.8 and cv < 1.0:
			val -= 0.25
		if v < 1.2:
			val -= 0.15                                        # dark foot
		if v > 15.8:
			val += 0.12                                        # worn top edge
		return _q(clampf(val, 0, 1), px, py, FLOOR))
	_save("block", true)


# --- stone face (riddle) (28x44, cell centre (14, 36)) --------------------------------------

## A squat pedestal with a carved stone head on top, its face on the lit (left) side: heavy brow,
## hollow eyes (StoneFace makes them glow), flat nose, a mouth slit.
func _stone_face() -> void:
	_new(28, 44, Vector2(14, 36))
	_box(-0.34, 0.34, -0.34, 0.34, 0.0, 7.0, func(face: String, u: float, v: float, px: int, py: int) -> Color:
		var val: float = FACE_LIGHT[face] - 0.05
		if v > 5.5 and face != "top":
			val += 0.12
		return _q(val, px, py, BRICK))
	_box(-0.27, 0.27, -0.27, 0.27, 7.0, 24.0, func(face: String, u: float, v: float, px: int, py: int) -> Color:
		var val: float = FACE_LIGHT[face]
		if face == "top":
			return _q(0.8 if u > 1.0 and v > 1.0 else 0.95, px, py, FLOOR)
		if face == "left":
			# features, u across the face (0..8.6), v up from the chin (0..17)
			if v > 11.2 and v < 12.6:
				val = 0.95                                     # brow ridge (lit)
			elif v > 8.6 and v < 11.2 and (absf(u - 2.3) < 1.2 or absf(u - 6.3) < 1.2):
				val = 0.05                                     # eye sockets
			elif v > 5.0 and v < 9.0 and absf(u - 4.3) < 0.9:
				val = 0.82                                     # nose
			elif v > 4.2 and v < 5.0 and absf(u - 4.3) < 0.9:
				val = 0.2                                      # nose shadow
			elif v > 2.2 and v < 3.4 and absf(u - 4.3) < 2.6:
				val = 0.1                                      # mouth slit
			elif v > 14.5:
				val = 0.5                                      # brow of the head
		elif face == "right":
			if v > 11.2 and v < 12.6:
				val = 0.6
			if v > 3.0 and v < 9.0 and u > 6.0 and u < 7.6:
				val = 0.25                                     # ear
		return _q(clampf(val, 0, 1), px, py, FLOOR))
	_save("stone_face", true)
