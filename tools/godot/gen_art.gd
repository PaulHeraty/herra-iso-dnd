extends SceneTree
## Generates the pixel-art tiles, hero/prop sprites and torch frames used in the game.
## Port of the drawing code in tools/python/make_iso_party.py (concept mock-ups), so the look matches.
## Hero/prop pixel grids and the palette are read straight from that Python file (single source).
##
## Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/godot/gen_art.gd
## Then re-import (open the editor, or run with --headless --import).

const PY_SOURCE := "res://tools/python/make_iso_party.py"
const WALL := 40
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
const FLOOR_PAL := [Color8(22, 20, 26), Color8(38, 36, 44), Color8(54, 52, 60), Color8(72, 69, 76), Color8(92, 88, 94), Color8(114, 108, 112)]
const BRICK_PAL := [Color8(26, 24, 30), Color8(46, 43, 50), Color8(64, 60, 66), Color8(84, 78, 82), Color8(106, 98, 98), Color8(128, 118, 114)]
const FLOOR_VARIANTS := 8
const WALL_VARIANTS := 4
## Wall atlas rows: which faces are drawn. L = lower-left face (lit), R = lower-right face (darker).
const WALL_ROWS := ["L", "R", "LR", ""]

var palette := {}


func _init() -> void:
	var src := FileAccess.get_file_as_string(PY_SOURCE)
	if src.is_empty():
		push_error("Cannot read " + PY_SOURCE)
		quit(1)
		return
	palette = _parse_palette(src)
	_ensure_dirs()
	_make_floor_atlas()
	_make_wall_atlas()
	for hero in ["FIGHTER", "ROGUE", "CLERIC", "MAGE"]:
		_save(_grid_sprite(_parse_grid(src, hero)), "res://assets/sprites/heroes/%s.png" % hero.to_lower())
	_save(_grid_sprite(_parse_grid(src, "CHEST")), "res://assets/sprites/props/chest.png")
	_save(_grid_sprite(_parse_grid(src, "BONES")), "res://assets/sprites/props/bones.png")
	_make_torch_sheet()
	_make_web()
	print("gen_art: done")
	quit()


# ------------------------------------------------------------------ helpers

func _ensure_dirs() -> void:
	for d in ["res://assets/tiles", "res://assets/sprites/heroes", "res://assets/sprites/props"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))


func _save(img: Image, path: String) -> void:
	var err := img.save_png(path)
	print("  ", path, " ", img.get_size(), "" if err == OK else " ERROR %d" % err)


func _q(v: float, x: int, y: int, pal: Array) -> Color:
	## Quantize brightness v (0..1) to the palette with 4x4 ordered (Bayer) dithering.
	v = v * (pal.size() - 1) + (BAYER[y % 4][x % 4] / 16.0 - 0.5) * 0.6
	return pal[clampi(roundi(v), 0, pal.size() - 1)]


func _diamond_pixels() -> Array:
	## Pixels of a 32x16 diamond as [x, y, dx, dy] (dx, dy relative to the centre).
	var out := []
	for py in 16:
		var yy := py + 0.5 - 8.0
		var hw := 16.0 * (1.0 - absf(yy) / 8.0)
		for px in range(int(16 - hw + 0.5), int(16 + hw + 0.5)):
			out.append([px, py, px + 0.5 - 16.0, yy])
	return out


func _parse_palette(src: String) -> Dictionary:
	var block := src.substr(src.find("P = {"))
	block = block.substr(0, block.find("}"))
	var re := RegEx.create_from_string("\"(\\w)\":\\s*\\((\\d+),\\s*(\\d+),\\s*(\\d+)\\)")
	var pal := {}
	for m in re.search_all(block):
		pal[m.get_string(1)] = Color8(int(m.get_string(2)), int(m.get_string(3)), int(m.get_string(4)))
	return pal


func _parse_grid(src: String, name: String) -> PackedStringArray:
	var re := RegEx.create_from_string("(?ms)^" + name + " = \\[(.*?)^\\]")
	var m := re.search(src)
	var rows := PackedStringArray()
	if m == null:
		push_error("grid not found: " + name)
		return rows
	for r in RegEx.create_from_string("\"([^\"]*)\"").search_all(m.get_string(1)):
		rows.append(r.get_string(1))
	return rows


func _grid_sprite(rows: PackedStringArray) -> Image:
	## Pixel grid -> image with a 1px transparent margin filled by a dark outline.
	var w := 0
	for r in rows:
		w = maxi(w, r.length())
	var img := Image.create_empty(w + 2, rows.size() + 2, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			var ch: String = rows[y][x]
			if ch != ".":
				img.set_pixel(x + 1, y + 1, palette[ch])
	var src := img.duplicate() as Image
	var outline: Color = palette["K"]
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() and src.get_pixelv(p).a > 0:
					img.set_pixel(x, y, outline)
					break
	return img


# ------------------------------------------------------------------ tiles

func _draw_floor(img: Image, ox: int, oy: int, seed_value: int, dark: bool) -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = seed_value
	var base := rnd.randf_range(0.38, 0.6) * (0.5 if dark else 1.0)
	var crack := rnd.randf() < 0.3
	var crack_off := rnd.randf_range(-4.0, 4.0)
	for p in _diamond_pixels():
		var dx: float = p[2]
		var dy: float = p[3]
		var e := absf(dx) / 16.0 + absf(dy) / 8.0
		var v := base + rnd.randf_range(-0.06, 0.06)
		if e > 0.88:
			v = 0.02                                   # dark grout line
		elif e > 0.74:
			v += 0.14 if dy < 0 else -0.16             # bevel: lit top edges, shaded bottom edges
		if crack and absf(dx - dy * 1.6 - crack_off) < 0.6 and e < 0.6:
			v = 0.1
		img.set_pixel(ox + p[0], oy + p[1], _q(clampf(v, 0, 1), p[0], p[1], FLOOR_PAL))


func _make_floor_atlas() -> void:
	## Row 0: normal floor variants. Row 1: dark floor (doorways, unlit alcoves).
	var img := Image.create_empty(32 * FLOOR_VARIANTS, 16 * 2, false, Image.FORMAT_RGBA8)
	for row in 2:
		for i in FLOOR_VARIANTS:
			_draw_floor(img, i * 32, row * 16, 1000 + i * 131 + row * 17, row == 1)
	_save(img, "res://assets/tiles/floor_atlas.png")


func _draw_wall(img: Image, ox: int, oy: int, faces: String, seed_value: int) -> void:
	## A 32x56 wall block: top cap diamond at y 0..16, faces down to the base diamond at y 40..56.
	var rnd := RandomNumberGenerator.new()
	rnd.seed = seed_value
	var tone := []
	for r in 8:
		var row_t := []
		for c in 4:
			row_t.append(rnd.randf_range(-0.12, 0.12))
		tone.append(row_t)
	for face in faces:
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
					light = 0.44
				var row := v / 8
				var bu := u + (4 if row % 2 else 0)
				var val: float = light + tone[row % 8][(bu / 8) % 4]
				if v % 8 == 0 or bu % 8 == 0:
					val = 0.08                         # mortar
				elif v % 8 == 1:
					val += 0.08                        # top bevel of each brick
				img.set_pixel(ox + x, oy + y, _q(clampf(val, 0, 1), x, y, BRICK_PAL))
	for p in _diamond_pixels():                         # top cap
		var e: float = absf(p[2]) / 16.0 + absf(p[3]) / 8.0
		img.set_pixel(ox + p[0], oy + p[1], _q(0.25 if e < 0.8 else 0.12, p[0], p[1], BRICK_PAL))


func _make_wall_atlas() -> void:
	var img := Image.create_empty(32 * WALL_VARIANTS, 56 * WALL_ROWS.size(), false, Image.FORMAT_RGBA8)
	for r in WALL_ROWS.size():
		for i in WALL_VARIANTS:
			_draw_wall(img, i * 32, r * 56, WALL_ROWS[r], 500 + i * 77 + r * 991)
	_save(img, "res://assets/tiles/wall_atlas.png")


# ------------------------------------------------------------------ props

func _make_torch_sheet() -> void:
	## 8 frames, 8x18 each: iron bracket with a flickering flame. Flame base at (3, 9).
	const FW := 8
	const FH := 18
	const FRAMES := 8
	var img := Image.create_empty(FW * FRAMES, FH, false, Image.FORMAT_RGBA8)
	for f in FRAMES:
		var ox := f * FW
		img.fill_rect(Rect2i(ox + 2, 11, 3, 6), Color8(40, 30, 26))   # bracket stem
		img.fill_rect(Rect2i(ox + 1, 10, 5, 2), Color8(70, 50, 36))   # bracket cup
		var rnd := RandomNumberGenerator.new()
		rnd.seed = f * 7 + 3
		var hgt := 7 + rnd.randi_range(0, 2)
		for j in hgt:
			var t := float(j) / hgt
			var half := (1.0 - t) * 2.4 + rnd.randf_range(-0.4, 0.4)
			var sway := sin(f * 1.7 + j * 0.6) * t * 1.2
			for i in range(-3, 4):
				if absf(i - sway) <= half:
					var c := Color8(220, 70, 30)
					if absf(i - sway) < half * 0.4 and t < 0.6:
						c = Color8(255, 245, 190)
					elif t < 0.75:
						c = Color8(255, 180, 60)
					var px := 3 + i
					var py := 9 - j
					if px >= 0 and px < FW and py >= 0:
						img.set_pixel(ox + px, py, c)
	_save(img, "res://assets/sprites/props/torch_sheet.png")


func _make_web() -> void:
	## Corner spider web decal. Hub at (27, 1).
	var img := Image.create_empty(52, 24, false, Image.FORMAT_RGBA8)
	var cx := 27.0
	var cy := 1.0
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 4
	var angs := []
	var lens := []
	for a in [100, 125, 150, 175, 30, 55, 80]:
		angs.append(deg_to_rad(a))
		lens.append(rnd.randf_range(18, 26))
	var put := func(x: float, y: float, a: float) -> void:
		var p := Vector2i(roundi(x), roundi(y))
		if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
			var old: float = img.get_pixelv(p).a
			img.set_pixelv(p, Color8(220, 220, 220, int(255 * maxf(old, a))))
	for k in angs.size():
		var L: float = lens[k]
		for i in int(L * 1.5):
			var t := i / (L * 1.5)
			put.call(cx + cos(angs[k]) * L * t, cy + sin(angs[k]) * L * t * 0.8, 0.5)
	var order := range(angs.size())
	order.sort_custom(func(i, j): return angs[i] < angs[j])
	for k in range(1, 5):
		var f := k / 5.0
		for n in order.size() - 1:
			var i: int = order[n]
			var j: int = order[n + 1]
			for s in 12:
				var t := s / 11.0
				var ang: float = angs[i] + (angs[j] - angs[i]) * t
				var L: float = (lens[i] + (lens[j] - lens[i]) * t) * f * (1 - 0.08 * sin(PI * t))
				put.call(cx + cos(ang) * L, cy + sin(ang) * L * 0.8, 0.4)
	_save(img, "res://assets/sprites/props/web.png")
