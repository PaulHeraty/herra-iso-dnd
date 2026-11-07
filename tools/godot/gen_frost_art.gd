extends SceneTree
## Art for module 2, "The Frost Spire" (the Frostfell and the Rimecaller's tower):
##   assets/tiles/snow_floor_atlas.png, ice_cliff_atlas.png, snow_forest_atlas.png -> snow_tileset.tres
##       (the woods' art recoloured: grass -> snow, dirt -> packed snow, rock -> ice rock, pines snowy)
##   assets/tiles/tower_floor_atlas.png, tower_wall_atlas.png -> tower_tileset.tres
##       (the dungeon's art recoloured: blue slate floors, blue-violet arcane stone walls)
##   assets/sprites/props/: tree_pine_snow, tree_oak_snow, bush_snow, boulder_snow, stump_snow,
##       ice_wall (the Rimecaller's ward, a 32x56 block), tower_entrance (the spire, the way in),
##       bookshelf, alchemy_table, frost_crystal
##   assets/sprites/npcs/: hilde_sheet (Brannoc's drawing in furs), tamsin_sheet (the Mage hero's
##       idle frame in an apprentice's robe)
## Run: Godot_console --headless --path . -s res://tools/godot/gen_frost_art.gd  (then --import)
## Recolouring maps each pixel that is (nearly) a colour of a source palette to the same shade of
## the target palette, so the dithering and lighting of the originals carry over.

const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
const OUTLINE := Color8(20, 16, 24)

# source palettes (gen_outdoor_art.gd, gen_art.gd)
const GRASS := [Color8(22, 32, 26), Color8(32, 48, 32), Color8(44, 66, 38), Color8(60, 86, 46), Color8(80, 108, 56), Color8(104, 130, 68)]
const DIRT := [Color8(36, 28, 26), Color8(56, 42, 34), Color8(78, 58, 42), Color8(100, 76, 52), Color8(124, 96, 64), Color8(148, 118, 80)]
const LEAF := [Color8(30, 26, 22), Color8(46, 40, 30), Color8(66, 54, 36), Color8(88, 68, 40), Color8(112, 86, 46), Color8(138, 106, 54)]
const ROCK := [Color8(28, 26, 30), Color8(46, 42, 44), Color8(64, 58, 58), Color8(86, 78, 74), Color8(108, 98, 90), Color8(132, 122, 110)]
const FOLIAGE := [Color8(16, 28, 22), Color8(24, 44, 28), Color8(36, 62, 34), Color8(52, 84, 42), Color8(74, 108, 52), Color8(100, 134, 64)]
const PINE := [Color8(14, 26, 24), Color8(20, 40, 32), Color8(28, 56, 40), Color8(40, 74, 48), Color8(56, 96, 58)]
const FLOOR := [Color8(22, 20, 26), Color8(38, 36, 44), Color8(54, 52, 60), Color8(72, 69, 76), Color8(92, 88, 94), Color8(114, 108, 112)]
const BRICK := [Color8(26, 24, 30), Color8(46, 43, 50), Color8(64, 60, 66), Color8(84, 78, 82), Color8(106, 98, 98), Color8(128, 118, 114)]

# target palettes
const SNOW := [Color8(58, 68, 92), Color8(90, 104, 132), Color8(128, 144, 172), Color8(168, 182, 206), Color8(204, 214, 232), Color8(234, 240, 250)]
const PACKED := [Color8(46, 50, 66), Color8(70, 74, 92), Color8(96, 102, 120), Color8(124, 130, 148), Color8(152, 158, 174), Color8(180, 186, 200)]
const FROZEN := [Color8(34, 38, 50), Color8(52, 58, 74), Color8(76, 84, 102), Color8(104, 114, 134), Color8(140, 152, 174), Color8(184, 196, 214)]
const ICE_ROCK := [Color8(26, 30, 44), Color8(40, 50, 70), Color8(60, 76, 100), Color8(88, 110, 138), Color8(126, 150, 178), Color8(176, 198, 222)]
const SNOW_FOLIAGE := [Color8(14, 26, 28), Color8(22, 42, 40), Color8(34, 60, 52), Color8(116, 136, 158), Color8(186, 200, 218), Color8(232, 240, 250)]
const SNOW_PINE := [Color8(12, 24, 28), Color8(18, 38, 38), Color8(28, 54, 48), Color8(148, 168, 190), Color8(222, 232, 244)]
const TOWER_FLOOR := [Color8(18, 18, 30), Color8(30, 32, 52), Color8(44, 48, 74), Color8(60, 66, 98), Color8(80, 88, 124), Color8(104, 112, 150)]
const ARCANE := [Color8(22, 20, 34), Color8(38, 36, 60), Color8(54, 52, 84), Color8(72, 70, 108), Color8(94, 92, 134), Color8(118, 116, 160)]
const ICE := [Color8(40, 70, 110), Color8(70, 120, 170), Color8(110, 170, 220), Color8(160, 214, 246), Color8(224, 246, 255)]
const WOOD := [Color8(34, 22, 18), Color8(56, 36, 24), Color8(80, 50, 28), Color8(104, 66, 34), Color8(134, 90, 48), Color8(166, 120, 68)]
const FACE_LIGHT := {"top": 0.78, "left": 0.62, "right": 0.44}

var img: Image
var ox := 0.0
var oy := 0.0


func _init() -> void:
	var T := "res://assets/tiles/"
	var P := "res://assets/sprites/props/"
	var outdoor := [[GRASS, SNOW], [DIRT, PACKED], [LEAF, FROZEN], [ROCK, ICE_ROCK], [FOLIAGE, SNOW_FOLIAGE], [PINE, SNOW_PINE]]
	_recolor_file(T + "outdoor_floor_atlas.png", T + "snow_floor_atlas.png", outdoor)
	_recolor_file(T + "cliff_atlas.png", T + "ice_cliff_atlas.png", outdoor)
	_recolor_file(T + "forest_atlas.png", T + "snow_forest_atlas.png", outdoor)
	var tower := [[FLOOR, TOWER_FLOOR], [BRICK, ARCANE]]
	_recolor_file(T + "floor_atlas.png", T + "tower_floor_atlas.png", tower)
	_recolor_file(T + "wall_atlas.png", T + "tower_wall_atlas.png", tower)
	for n in ["tree_pine", "tree_oak", "bush", "boulder", "stump"]:
		_recolor_file(P + n + ".png", P + n + "_snow.png", outdoor)
	_tileset("res://assets/tiles/outdoor_tileset.tres", "res://assets/tiles/snow_tileset.tres",
			{0: T + "snow_floor_atlas.png", 1: T + "ice_cliff_atlas.png", 2: T + "snow_forest_atlas.png"})
	_tileset("res://assets/tiles/dungeon_tileset.tres", "res://assets/tiles/tower_tileset.tres",
			{0: T + "tower_floor_atlas.png", 1: T + "tower_wall_atlas.png"})
	_ice_wall()
	_tower_entrance()
	_bookshelf()
	_alchemy_table()
	_frost_crystal()
	_hilde()
	_tamsin()
	print("gen_frost_art: done")
	quit()


# --- recolouring -------------------------------------------------------------------------------

func _recolor_file(src: String, dst: String, pairs: Array) -> void:
	var im := Image.load_from_file(ProjectSettings.globalize_path(src))
	im.convert(Image.FORMAT_RGBA8)
	var map := {}
	for pr in pairs:
		var a: Array = pr[0]
		var b: Array = pr[1]
		for i in a.size():
			map[a[i].to_rgba32()] = b[mini(i, b.size() - 1)]
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var key := Color(c.r, c.g, c.b, 1.0).to_rgba32()
			if map.has(key):
				var n: Color = map[key]
				im.set_pixel(x, y, Color(n.r, n.g, n.b, c.a))
	var err := im.save_png(ProjectSettings.globalize_path(dst))
	print("  ", dst, " ", "ok" if err == OK else "ERROR %d" % err)


## A copy of a TileSet with its atlas textures swapped (source id -> texture path).
func _tileset(src: String, dst: String, textures: Dictionary) -> void:
	var ts: TileSet = (load(src) as TileSet).duplicate(true)
	for sid in textures:
		var s := ts.get_source(sid) as TileSetAtlasSource
		if not ResourceLoader.exists(textures[sid]):
			print("  %s: run --import, then this again (the atlas isn't imported yet)" % dst)
			return
		s.texture = load(textures[sid])
	var err := ResourceSaver.save(ts, dst)
	print("  ", dst, " ", "ok" if err == OK else "ERROR %d" % err)


# --- drawing helpers (as gen_puzzle_art.gd) -----------------------------------------------------

func _new(w: int, h: int, origin: Vector2) -> void:
	img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	ox = origin.x
	oy = origin.y


func _save(path: String, outline := true) -> void:
	if outline:
		_outline()
	var err := img.save_png(ProjectSettings.globalize_path(path))
	print("  ", path, " ", img.get_size(), "" if err == OK else " ERROR %d" % err)


func _q(v: float, x: int, y: int, pal: Array) -> Color:
	v = v * (pal.size() - 1) + (BAYER[y % 4][x % 4] / 16.0 - 0.5) * 0.6
	return pal[clampi(roundi(v), 0, pal.size() - 1)]


func _scr(mx: float, my: float, z: float) -> Vector2:
	return Vector2(ox + (mx - my) * 16.0, oy + (mx + my) * 8.0 - z)


func _fill(poly: PackedVector2Array, shade: Callable) -> void:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	for py in range(maxi(0, floori(r.position.y)), mini(img.get_height(), ceili(r.end.y) + 1)):
		for px in range(maxi(0, floori(r.position.x)), mini(img.get_width(), ceili(r.end.x) + 1)):
			if Geometry2D.is_point_in_polygon(Vector2(px + 0.5, py + 0.5), poly):
				var col: Color = shade.call(px, py)
				if col.a > 0.0:
					img.set_pixel(px, py, col)


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
			return shade.call("top", ((a + b) / 2.0 - x0) * 16.0, ((b - a) / 2.0 - y0) * 16.0, px, py))


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


func _px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


# --- the ward: a block of magic ice (32x56, like a wall block: drawn at (-16, -48)) ------------

func _ice_wall() -> void:
	_new(32, 56, Vector2(16, 48))
	_box(-0.5, 0.5, -0.5, 0.5, 0.0, 40.0, func(face: String, u: float, v: float, px: int, py: int) -> Color:
		var val: float = FACE_LIGHT[face] * 0.9
		if face == "top":
			val = 0.85
		# frozen streaks and a few cracks
		if fmod(u * 0.7 + v * 0.35, 9.0) < 1.0:
			val += 0.18
		if face != "top" and absf(fmod(u + v * 0.5, 13.0) - 6.0) < 0.5 and v > 8 and v < 32:
			val -= 0.3
		var c := _q(clampf(val, 0.0, 1.0), px, py, ICE)
		return Color(c.r, c.g, c.b, 0.88))
	_save("res://assets/sprites/props/ice_wall.png", false)


# --- the spire (the way into the tower): 64x170, the cell centre at (32, 162) ------------------

func _tower_entrance() -> void:
	_new(64, 180, Vector2(32, 162))
	const R := 26.0
	const H := 118.0
	var base_y := oy + 2.0
	# the round body: stone courses, lit from the left; narrow glowing windows; a door at the foot
	for py in range(int(base_y - H), int(base_y + R * 0.4)):
		for px in range(int(ox - R), int(ox + R)):
			var dx := (px + 0.5 - ox) / R
			if absf(dx) > 1.0:
				continue
			var ell := sqrt(1.0 - dx * dx) * R * 0.4      # the bottom curve of the cylinder
			if py + 0.5 > base_y + ell:
				continue
			var h := base_y + ell - (py + 0.5)             # height above the ground at this column
			if h > H + ell * 0.0 and py < base_y - H:
				continue
			var light := 0.72 - dx * 0.38 - 0.05 * sqrt(1.0 - dx * dx)
			var course := int((base_y + ell - py) / 6.0)
			var mortar := fmod(base_y + ell - py, 6.0) < 1.0
			var joint := fmod((dx * R * 1.4) + course * 5.0, 10.0) < 1.0
			if mortar or joint:
				light -= 0.2
			img.set_pixel(px, py, _q(clampf(light, 0.0, 1.0), px, py, ARCANE))
	# windows (cold blue glow) up the side
	for wy in [40, 72, 100]:
		for k in range(-1, 2):
			var wx := int(ox) - 8 + k * 9
			for yy in range(int(base_y - wy - 6), int(base_y - wy)):
				for xx in [wx, wx + 1]:
					_px(xx, yy, ICE[3] if yy > base_y - wy - 5 else ICE[4])
	# the door: a dark arch with an icy rim
	for yy in range(int(base_y - 22), int(base_y + 6)):
		for xx in range(int(ox) - 6, int(ox) + 6):
			var dxx := xx + 0.5 - ox
			var top := base_y - 16 - sqrt(maxf(0.0, 36.0 - dxx * dxx))
			if yy >= top:
				img.set_pixel(xx, yy, Color8(10, 10, 20) if absf(dxx) < 5.0 and yy > top + 1 else ICE[2])
	# a pointed roof of blue ice-slate
	var roof_base := base_y - H
	for py in range(int(roof_base - 42), int(roof_base + 6)):
		var t := (roof_base + 6 - py) / 48.0
		var half := (R + 4.0) * (1.0 - t)
		for px in range(int(ox - half), int(ox + half) + 1):
			var dx := (px + 0.5 - ox) / maxf(half, 0.5)
			var light := 0.75 - dx * 0.35
			if fmod(py, 5.0) < 1.0:
				light -= 0.15
			img.set_pixel(px, py, _q(clampf(light, 0.0, 1.0), px, py, ICE))
	# a spire tip
	for py in range(int(roof_base - 50), int(roof_base - 42)):
		_px(int(ox), py, ICE[4])
	_save("res://assets/sprites/props/tower_entrance.png")


# --- tower furniture (one cell each; feet offsets in Prop.KINDS) ---------------------------------

## A tall bookshelf full of coloured spines: 34x44, cell centre (17, 34).
func _bookshelf() -> void:
	_new(34, 44, Vector2(17, 34))
	var spines := [Color8(140, 40, 40), Color8(50, 80, 140), Color8(60, 110, 60), Color8(150, 120, 50), Color8(100, 60, 120)]
	_box(-0.42, 0.42, -0.14, 0.14, 0.0, 28.0, func(face: String, u: float, v: float, px: int, py: int) -> Color:
		var val: float = FACE_LIGHT[face]
		if face == "left":
			var shelf := fmod(v, 7.0) < 1.2
			if shelf or u < 1.2 or u > 12.2 or v > 26.5:
				return _q(val, px, py, WOOD)
			var book := int(u / 1.6) + int(v / 7.0) * 3
			var c: Color = spines[book % spines.size()]
			return c.darkened(0.15 if int(u / 1.6) % 2 == 0 else 0.35)
		return _q(val * 0.9, px, py, WOOD))
	_save("res://assets/sprites/props/bookshelf.png")


## A workbench with flasks and a bubbling retort: 34x30, cell centre (17, 21).
func _alchemy_table() -> void:
	_new(34, 30, Vector2(17, 21))
	_box(-0.4, 0.4, -0.26, 0.26, 7.0, 10.0, func(face: String, u: float, v: float, px: int, py: int) -> Color:
		return _q(FACE_LIGHT[face], px, py, WOOD))
	for leg in [Vector2(-0.34, 0.2), Vector2(0.34, 0.2), Vector2(0.34, -0.2)]:
		var p := _scr(leg.x, leg.y, 0.0)
		for z in 8:
			_px(int(p.x), int(p.y) - z, WOOD[1])
	var flasks := [[Vector2(-0.2, 0.0), Color8(80, 220, 120)], [Vector2(0.05, -0.1), Color8(110, 170, 255)], [Vector2(0.25, 0.05), Color8(230, 90, 200)]]
	for fl in flasks:
		var p := _scr(fl[0].x, fl[0].y, 10.0)
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, -2), Vector2i(1, -2)]:
			_px(int(p.x) + d.x, int(p.y) + d.y, fl[1])
		_px(int(p.x), int(p.y) - 3, Color8(200, 210, 220))
		_px(int(p.x), int(p.y) - 4, Color8(200, 210, 220))
	_save("res://assets/sprites/props/alchemy_table.png")


## A cluster of glowing frost crystals: 24x34, cell centre (12, 28).
func _frost_crystal() -> void:
	_new(24, 34, Vector2(12, 28))
	for sp in [[0.0, 26.0, 3.5], [-6.0, 16.0, 2.5], [6.0, 19.0, 2.5], [-2.0, 11.0, 2.0], [3.0, 9.0, 1.8]]:
		var cx: float = ox + sp[0]
		var h: float = sp[1]
		var w: float = sp[2]
		for py in range(int(oy - h), int(oy + 2)):
			var t := (oy + 2 - py) / (h + 2)
			var half := w * (1.0 - maxf(0.0, t - 0.7) / 0.3) if t > 0.7 else w
			for px in range(int(cx - half), int(cx + half) + 1):
				var dx := (px + 0.5 - cx) / maxf(half, 0.5)
				img.set_pixel(px, py, _q(clampf(0.85 - dx * 0.35 - t * 0.1, 0.0, 1.0), px, py, ICE))
	_save("res://assets/sprites/props/frost_crystal.png")


# --- NPCs (16x24 cells: idle, idle (breath), talk) ------------------------------------------------

## Hilde Ironbrook, the jarl's quartermaster: Brannoc's drawing (gen_trader_art.gd) in a white fur
## hood, a copper braided beard, a blue coat.
func _hilde() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/npcs/trader_sheet.png"))
	src.convert(Image.FORMAT_RGBA8)
	var map := {
		Color8(104, 70, 42): Color8(222, 226, 232), Color8(70, 46, 30): Color8(160, 168, 180),     # hat -> fur hood
		Color8(214, 70, 52): Color8(222, 226, 232), Color8(150, 40, 36): Color8(160, 168, 180),     # feather -> fur
		Color8(204, 200, 194): Color8(206, 110, 50), Color8(150, 146, 142): Color8(150, 72, 34),    # beard -> copper
		Color8(150, 58, 46): Color8(56, 86, 150), Color8(104, 38, 32): Color8(38, 58, 104),         # waistcoat -> blue
		Color8(222, 210, 178): Color8(200, 190, 170), Color8(170, 156, 126): Color8(150, 140, 120),
		Color8(78, 98, 66): Color8(80, 70, 66), Color8(52, 68, 46): Color8(56, 48, 46),            # trousers
	}
	_remap(src, map)
	src.save_png(ProjectSettings.globalize_path("res://assets/sprites/npcs/hilde_sheet.png"))
	print("  res://assets/sprites/npcs/hilde_sheet.png ", src.get_size())


## Tamsin, the Rimecaller's runaway apprentice: the Mage hero's front idle frame in a teal robe,
## fair hair; frame 2 lifts a hand (a few pixels up the arm).
func _tamsin() -> void:
	var walk := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/heroes/mage_sheet.png"))
	walk.convert(Image.FORMAT_RGBA8)
	var out := Image.create_empty(48, 24, false, Image.FORMAT_RGBA8)
	for f in 3:
		out.blit_rect(walk, Rect2i(0, 0, 16, 24), Vector2i(f * 16, 0))
	# recolour the robe (purples) to teal, the beard/hair (greys/whites) to straw
	for y in 24:
		for x in 48:
			var c := out.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var h := c.h
			if c.s > 0.25 and h > 0.62 and h < 0.85:          # purple robe
				out.set_pixel(x, y, Color.from_hsv(0.48, c.s * 0.8, c.v, c.a))
			elif c.s < 0.12 and c.v > 0.6:                     # white beard / hair
				out.set_pixel(x, y, Color.from_hsv(0.13, 0.45, c.v * 0.95, c.a))
	# breath frame: the head and shoulders 1px down
	var b := out.get_region(Rect2i(16, 0, 16, 12))
	out.fill_rect(Rect2i(16, 0, 16, 12), Color(0, 0, 0, 0))
	out.blit_rect(b, Rect2i(0, 0, 16, 11), Vector2i(16, 1))
	out.save_png(ProjectSettings.globalize_path("res://assets/sprites/npcs/tamsin_sheet.png"))
	print("  res://assets/sprites/npcs/tamsin_sheet.png ", out.get_size())


func _remap(im: Image, map: Dictionary) -> void:
	var keys := {}
	for k: Color in map:
		keys[k.to_rgba32()] = map[k]
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var key := Color(c.r, c.g, c.b, 1.0).to_rgba32()
			if keys.has(key):
				var n: Color = keys[key]
				im.set_pixel(x, y, Color(n.r, n.g, n.b, c.a))
