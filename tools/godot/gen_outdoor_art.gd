extends SceneTree
## Outdoor art (the woods above the dungeon), in the style of gen_art.gd: limited palettes, 4x4
## Bayer dithering, 1 px dark outlines on sprites.
##   assets/tiles/outdoor_floor_atlas.png  32x16 diamonds: row 0 grass x8, row 1 dirt path x8,
##                                          row 2 forest floor (leaf litter) x8
##   assets/tiles/cliff_atlas.png          32x56 rock blocks, rows like the wall atlas
##                                          (0 lower-left face, 1 lower-right face, 2 both, 3 cap)
##   assets/sprites/props/                 tree_oak, tree_pine, bush, boulder, stump, log, tent,
##                                          grave, cave_entrance, campfire
## Run: Godot_console --headless --path . -s res://tools/godot/gen_outdoor_art.gd  (then --import),
## then tools/godot/build_outdoor_tileset.gd.

const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
const GRASS := [Color8(22, 32, 26), Color8(32, 48, 32), Color8(44, 66, 38), Color8(60, 86, 46), Color8(80, 108, 56), Color8(104, 130, 68)]
const DIRT := [Color8(36, 28, 26), Color8(56, 42, 34), Color8(78, 58, 42), Color8(100, 76, 52), Color8(124, 96, 64), Color8(148, 118, 80)]
const LEAF := [Color8(30, 26, 22), Color8(46, 40, 30), Color8(66, 54, 36), Color8(88, 68, 40), Color8(112, 86, 46), Color8(138, 106, 54)]
const ROCK := [Color8(28, 26, 30), Color8(46, 42, 44), Color8(64, 58, 58), Color8(86, 78, 74), Color8(108, 98, 90), Color8(132, 122, 110)]
const FOLIAGE := [Color8(16, 28, 22), Color8(24, 44, 28), Color8(36, 62, 34), Color8(52, 84, 42), Color8(74, 108, 52), Color8(100, 134, 64)]
const PINE := [Color8(14, 26, 24), Color8(20, 40, 32), Color8(28, 56, 40), Color8(40, 74, 48), Color8(56, 96, 58)]
const BARK := [Color8(32, 22, 18), Color8(52, 36, 26), Color8(74, 52, 34), Color8(98, 70, 44), Color8(122, 90, 56)]
const CANVAS := [Color8(54, 46, 36), Color8(86, 74, 56), Color8(120, 104, 78), Color8(156, 138, 104), Color8(190, 172, 132)]
const OUTLINE := Color8(20, 16, 24)
const WALL := 40
const WALL_ROWS := ["L", "R", "LR", ""]

var img: Image


func _init() -> void:
	_floor_atlas()
	_cliff_atlas()
	_forest_atlas()
	_tree_oak()
	_tree_pine()
	_bush()
	_boulder()
	_stump()
	_log()
	_tent()
	_grave()
	_cave_entrance()
	_campfire()
	print("gen_outdoor_art: done")
	quit()


func _q(v: float, x: int, y: int, pal: Array) -> Color:
	v = v * (pal.size() - 1) + (BAYER[y % 4][x % 4] / 16.0 - 0.5) * 0.6
	return pal[clampi(roundi(v), 0, pal.size() - 1)]


func _diamond() -> Array:
	var out := []
	for py in 16:
		var yy := py + 0.5 - 8.0
		var hw := 16.0 * (1.0 - absf(yy) / 8.0)
		for px in range(int(16 - hw + 0.5), int(16 + hw + 0.5)):
			out.append([px, py, px + 0.5 - 16.0, yy])
	return out


func _save(path: String, outline := true) -> void:
	if outline:
		_outline()
	var err := img.save_png(path)
	print("  ", path, " ", img.get_size(), "" if err == OK else " ERROR %d" % err)


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


# --- tiles ------------------------------------------------------------------------------------

func _floor_atlas() -> void:
	img = Image.create_empty(32 * 8, 16 * 3, false, Image.FORMAT_RGBA8)
	for row in 3:
		for i in 8:
			var rnd := RandomNumberGenerator.new()
			rnd.seed = 3000 + i * 97 + row * 1013
			var pal: Array = [GRASS, DIRT, LEAF][row]
			var base: float = [0.5, 0.5, 0.42][row] + rnd.randf_range(-0.03, 0.03)
			var tufts := {}
			for k in 9:
				tufts[Vector2i(rnd.randi_range(2, 29), rnd.randi_range(2, 13))] = rnd.randf_range(-0.25, 0.3)
			for p in _diamond():
				var x: int = p[0]
				var y: int = p[1]
				var v: float = base + rnd.randf_range(-0.07, 0.07)
				match row:
					0:  # grass: blades (short vertical light / dark strokes)
						for t: Vector2i in tufts:
							if x == t.x and y in [t.y, t.y - 1]:
								v += tufts[t]
					1:  # dirt: pebbles
						for t: Vector2i in tufts:
							if Vector2i(x, y) == t:
								v += 0.3 if tufts[t] > 0 else -0.25
					2:  # leaf litter: blotches
						for t: Vector2i in tufts:
							if absi(x - t.x) + absi(y - t.y) <= 1:
								v += tufts[t] * 0.8
				img.set_pixel(i * 32 + x, row * 16 + y, _q(clampf(v, 0.0, 1.0), x, y, pal))
			# a few flowers on some grass tiles
			if row == 0 and i in [2, 5, 7]:
				for k in 3:
					var fx := rnd.randi_range(8, 24)
					var fy := rnd.randi_range(5, 11)
					img.set_pixel(i * 32 + fx, fy, [Color8(230, 220, 120), Color8(220, 220, 236), Color8(200, 120, 170)][(i + k) % 3])
	_save("res://assets/tiles/outdoor_floor_atlas.png", false)


## Rock blocks like the wall atlas (32x56: cap diamond on top, faces down to the base): uneven
## strata and cracks instead of bricks, and a grassy cap.
func _cliff_atlas() -> void:
	img = Image.create_empty(32 * 4, 56 * 4, false, Image.FORMAT_RGBA8)
	for r in 4:
		for i in 4:
			var rnd := RandomNumberGenerator.new()
			rnd.seed = 7000 + i * 59 + r * 811
			var ox := i * 32
			var oy := r * 56
			var bands := []
			for b in 8:
				bands.append(rnd.randf_range(-0.12, 0.12))
			var cracks := []
			for k in 5:
				cracks.append([rnd.randi_range(0, 31), rnd.randi_range(4, 36), rnd.randi_range(3, 8)])
			for face in WALL_ROWS[r]:
				for u in 16:
					for v in WALL:
						var x: int
						var y: int
						var light: float
						if face == "L":
							x = u
							y = 8 + int(u * 0.5) + v
							light = 0.62
						else:
							x = 16 + u
							y = 16 - int(u * 0.5) + v
							light = 0.42
						var band := (v + int(sin((x + i * 5) * 0.7) * 1.5)) / 6
						var val: float = light + bands[band % 8] + rnd.randf_range(-0.05, 0.05)
						if (v + int(sin((x + i * 5) * 0.7) * 1.5)) % 6 == 0:
							val -= 0.22                          # strata line
						for c in cracks:
							if x == c[0] and v >= c[1] and v < c[1] + c[2]:
								val = 0.08
						if v < 3:
							val += 0.1                           # lit lip under the grass
						img.set_pixel(ox + x, oy + y, _q(clampf(val, 0, 1), x, y, ROCK))
			for p in _diamond():
				var e: float = absf(p[2]) / 16.0 + absf(p[3]) / 8.0
				var g := 0.55 if e < 0.75 else 0.35
				g += rnd.randf_range(-0.08, 0.08)
				img.set_pixel(ox + p[0], oy + p[1], _q(g, p[0], p[1], GRASS))
	_save("res://assets/tiles/cliff_atlas.png", false)


# --- sprites ----------------------------------------------------------------------------------

## A lit blob (canopy clump, rock): ellipse, brightness from a light up-left plus noise.
func _blob(cx: float, cy: float, rx: float, ry: float, pal: Array, bright := 0.0, rnd: RandomNumberGenerator = null) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			var d := dx * dx + dy * dy
			if d > 1.0 or x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var nz := sqrt(maxf(0.0, 1.0 - d))
			var l := (-dx * 0.5 - dy * 0.7 + nz * 0.6) * 0.5 + 0.35 + bright
			if rnd:
				l += rnd.randf_range(-0.08, 0.08)
			img.set_pixel(x, y, _q(clampf(l, 0, 1), x, y, pal))


func _rect(x0: int, y0: int, w: int, h: int, pal: Array, light: float, rnd: RandomNumberGenerator = null) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			var l := light + (0.18 if x == x0 else 0.0) - (0.18 if x == x0 + w - 1 else 0.0)
			if rnd:
				l += rnd.randf_range(-0.06, 0.06)
			img.set_pixel(x, y, _q(clampf(l, 0, 1), x, y, pal))


func _tree_oak() -> void:
	img = Image.create_empty(40, 56, false, Image.FORMAT_RGBA8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 11
	_rect(17, 34, 6, 20, BARK, 0.45, rnd)                 # trunk
	img.set_pixel(16, 53, BARK[1])
	img.set_pixel(23, 53, BARK[1])
	for c in [[20, 22, 14, 11, 0.0], [12, 26, 9, 8, -0.05], [28, 27, 9, 8, -0.1], [15, 16, 9, 8, 0.08],
			[26, 15, 9, 8, 0.05], [20, 11, 9, 7, 0.12], [20, 30, 11, 6, -0.12]]:
		_blob(c[0], c[1], c[2], c[3], FOLIAGE, c[4], rnd)
	_save("res://assets/sprites/props/tree_oak.png")


func _tree_pine() -> void:
	img = Image.create_empty(32, 60, false, Image.FORMAT_RGBA8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 23
	_rect(14, 46, 4, 12, BARK, 0.4, rnd)
	# stacked tiers, widest at the bottom
	for t in 5:
		var top := 2 + t * 9
		var h := 14
		var w := 5.0 + t * 2.6
		for y in range(top, top + h):
			var k := float(y - top) / h
			var half := w * k + 1.0
			for x in range(int(16 - half), int(16 + half) + 1):
				var side := (x - 16) / maxf(half, 1.0)
				var l := 0.55 - side * 0.3 - k * 0.15 + rnd.randf_range(-0.07, 0.07)
				if y == top + h - 1 and (x + t) % 3 == 0:
					continue                                  # ragged lower edge
				img.set_pixel(x, y, _q(clampf(l, 0, 1), x, y, PINE))
	_save("res://assets/sprites/props/tree_pine.png")


func _bush() -> void:
	img = Image.create_empty(22, 16, false, Image.FORMAT_RGBA8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 31
	for c in [[7, 9, 6, 5, 0.0], [14, 9, 6, 5, -0.05], [11, 6, 6, 5, 0.1]]:
		_blob(c[0], c[1], c[2], c[3], FOLIAGE, c[4], rnd)
	for k in 3:
		img.set_pixel(rnd.randi_range(4, 17), rnd.randi_range(3, 11), Color8(190, 50, 60))   # berries
	_save("res://assets/sprites/props/bush.png")


func _boulder() -> void:
	img = Image.create_empty(28, 22, false, Image.FORMAT_RGBA8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 41
	_blob(14, 12, 12, 9, ROCK, 0.05, rnd)
	_blob(9, 15, 7, 5, ROCK, -0.05, rnd)
	for k in 6:                                            # moss on top
		var x := rnd.randi_range(8, 18)
		var y := rnd.randi_range(4, 7)
		if img.get_pixel(x, y).a > 0:
			img.set_pixel(x, y, GRASS[3 + k % 2])
	_save("res://assets/sprites/props/boulder.png")


func _stump() -> void:
	img = Image.create_empty(16, 12, false, Image.FORMAT_RGBA8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 51
	_rect(3, 4, 10, 7, BARK, 0.42, rnd)
	_blob(8, 4, 5, 2.5, [Color8(70, 50, 34), Color8(110, 82, 52), Color8(150, 116, 76), Color8(176, 140, 96)], 0.15)
	img.set_pixel(8, 4, Color8(90, 64, 42))
	_save("res://assets/sprites/props/stump.png")


func _log() -> void:
	img = Image.create_empty(30, 12, false, Image.FORMAT_RGBA8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 61
	for x in range(3, 25):
		var y0 := 2 + (x - 3) / 6
		for y in range(y0, y0 + 6):
			var l := 0.6 - (y - y0) * 0.08 + rnd.randf_range(-0.06, 0.06)
			img.set_pixel(x, y, _q(clampf(l, 0, 1), x, y, BARK))
	_blob(25, 8.5, 3, 3, [Color8(70, 50, 34), Color8(110, 82, 52), Color8(150, 116, 76), Color8(176, 140, 96)], 0.15)
	_save("res://assets/sprites/props/log.png")


func _tent() -> void:
	img = Image.create_empty(36, 30, false, Image.FORMAT_RGBA8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 71
	# A ridge tent seen from the front-left: a lit sloped side and a shaded triangular end
	for y in range(4, 28):
		var k := float(y - 4) / 24.0
		for x in range(0, 36):
			var end_l := 18.0 - k * 16.0
			var end_r := 18.0 + k * 3.0
			var side_r := 34.0 - (1.0 - k) * 12.0
			if x >= end_l and x <= end_r:
				var dark := absf(x - 15.5 - k * 1.5) < k * 3.5 and y > 15
				img.set_pixel(x, y, Color8(30, 22, 20) if dark else _q(0.35 + rnd.randf_range(-0.05, 0.05), x, y, CANVAS))
			elif x > end_r and x <= side_r and y >= 4 + int((x - end_r) * 0.0):
				var l := 0.7 - (x - end_r) / 30.0 + rnd.randf_range(-0.05, 0.05)
				if (x + y) % 9 == 0:
					l -= 0.12
				img.set_pixel(x, y, _q(clampf(l, 0, 1), x, y, CANVAS))
	for y in range(1, 5):
		img.set_pixel(18, y, BARK[2])                        # pole
	_save("res://assets/sprites/props/tent.png")


func _grave() -> void:
	img = Image.create_empty(14, 18, false, Image.FORMAT_RGBA8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 81
	_rect(2, 4, 10, 13, ROCK, 0.55, rnd)
	_blob(7, 4, 5, 3, ROCK, 0.1)
	for x in range(5, 10):
		img.set_pixel(x, 8, ROCK[1])                         # carved cross
	for y in range(6, 12):
		img.set_pixel(7, y, ROCK[1])
	_save("res://assets/sprites/props/grave.png")


## A mine entrance cut into the hillside: rocky mound, a black opening, a timber frame.
func _cave_entrance() -> void:
	img = Image.create_empty(48, 46, false, Image.FORMAT_RGBA8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 91
	_blob(24, 22, 23, 20, ROCK, 0.0, rnd)
	_blob(12, 30, 11, 12, ROCK, -0.05, rnd)
	_blob(36, 30, 11, 12, ROCK, -0.12, rnd)
	for k in 30:                                         # grass on the top of the mound
		var x := rnd.randi_range(6, 42)
		for y in range(0, 46):
			if img.get_pixel(x, y).a > 0:
				for d in rnd.randi_range(1, 3):
					if y + d < 46:
						img.set_pixel(x, y + d, GRASS[2 + (k % 3)])
				break
	# the opening: dark, a little lighter at the edge
	for y in range(18, 44):
		for x in range(14, 34):
			var dx := (x + 0.5 - 24.0) / 9.0
			var dy := (y + 0.5 - 44.0) / 25.0
			if dx * dx + dy * dy <= 1.0:
				var e := dx * dx + dy * dy
				img.set_pixel(x, y, Color8(8, 6, 10) if e < 0.7 else Color8(26, 22, 26))
	# timber frame: two posts and a lintel
	for y in range(21, 45):
		for x in [13, 14, 33, 34]:
			img.set_pixel(x, y, BARK[3] if x in [13, 33] else BARK[1])
	for x in range(11, 37):
		img.set_pixel(x, 19, BARK[4])
		img.set_pixel(x, 20, BARK[2])
		img.set_pixel(x, 21, BARK[1])
	_save("res://assets/sprites/props/cave_entrance.png")


func _campfire() -> void:
	img = Image.create_empty(20, 10, false, Image.FORMAT_RGBA8)
	# a ring of stones around crossed logs (the flame is the Torch flame, drawn by Brazier)
	for a in 10:
		var ang := a / 10.0 * TAU
		var x := 9 + roundi(cos(ang) * 7.5)
		var y := 6 + roundi(sin(ang) * 3.2)
		img.set_pixel(x, y, ROCK[3])
		img.set_pixel(x + 1, y, ROCK[2])
	for x in range(4, 14):
		img.set_pixel(x, 5 + (x - 4) / 5, BARK[3])
		img.set_pixel(17 - x, 5 + (x - 4) / 5, BARK[2])
	for x in range(6, 12):
		img.set_pixel(x, 6, Color8(200, 70, 30))
	_save("res://assets/sprites/props/campfire.png")


## Deep forest as wall blocks (32x56 like the wall atlas): a canopy cap of leaf clumps, faces of
## shaded foliage that open at the bottom onto dark trunks. The edge of the woods.
func _forest_atlas() -> void:
	img = Image.create_empty(32 * 4, 56 * 4, false, Image.FORMAT_RGBA8)
	for r in 4:
		for i in 4:
			var rnd := RandomNumberGenerator.new()
			rnd.seed = 9100 + i * 37 + r * 613
			var ox := i * 32
			var oy := r * 56
			var clumps := []
			for k in 14:
				clumps.append(Vector3(rnd.randf_range(0, 32), rnd.randf_range(0, 30), rnd.randf_range(-0.12, 0.14)))
			var trunks := [rnd.randi_range(2, 6), rnd.randi_range(9, 13), rnd.randi_range(18, 22), rnd.randi_range(25, 29)]
			for face in WALL_ROWS[r]:
				for u in 16:
					for v in WALL:
						var x: int
						var y: int
						var light: float
						if face == "L":
							x = u
							y = 8 + int(u * 0.5) + v
							light = 0.5
						else:
							x = 16 + u
							y = 16 - int(u * 0.5) + v
							light = 0.34
						var col: Color
						var edge := 26 + int(sin((x + i * 3) * 0.9) * 2.0 + rnd.randf_range(-1, 1))
						if v < edge:
							var val := light - v * 0.006
							for c: Vector3 in clumps:
								var d := Vector2(x - c.x, (v - c.y) * 1.4).length()
								if d < 4.0:
									val += c.z * (1.0 - d / 4.0) + (0.08 if d < 1.5 else 0.0)
							col = _q(clampf(val + rnd.randf_range(-0.05, 0.05), 0, 1), x, y, FOLIAGE)
						else:
							col = Color8(12, 16, 14)
							if x in trunks or x - 1 in trunks:
								col = BARK[1] if x in trunks else BARK[0]
						img.set_pixel(ox + x, oy + y, col)
			for p in _diamond():
				var e: float = absf(p[2]) / 16.0 + absf(p[3]) / 8.0
				var val := 0.6 - e * 0.25
				for c: Vector3 in clumps:
					var d := Vector2(p[0] - c.x, (p[1] - c.y * 0.5) * 2.0).length()
					if d < 4.5:
						val += c.z * (1.0 - d / 4.5) + (0.1 if d < 1.5 else 0.0)
				img.set_pixel(ox + p[0], oy + p[1], _q(clampf(val + rnd.randf_range(-0.05, 0.05), 0, 1), p[0], p[1], FOLIAGE))
	_save("res://assets/tiles/forest_atlas.png", false)
