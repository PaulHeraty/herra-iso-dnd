extends SceneTree
## Art for Brannoc the trader and the Rune of Return:
##   assets/sprites/npcs/trader_sheet.png   16x24 cells: idle A, idle B (breath), talk (hand up)
##   assets/sprites/props/stall.png         his market stall (one cell; feet offset Prop.KINDS)
##   assets/sprites/props/portal_sheet.png  the Rune of Return's portal, 8 frames of 24x40
## Run: Godot_console --headless --path . -s res://tools/godot/gen_trader_art.gd  (then --import)
##
## Same look as the other generators: limited palettes, light 4x4 Bayer dithering, light from the
## left, 1px dark outline on figures and props (not on the glowing portal).

const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
const OUTLINE := Color8(20, 16, 24)
const WOOD := [Color8(34, 22, 18), Color8(56, 36, 24), Color8(80, 50, 28), Color8(104, 66, 34), Color8(134, 90, 48), Color8(166, 120, 68)]
const CLOTH_RED := [Color8(70, 20, 22), Color8(110, 34, 32), Color8(150, 50, 42), Color8(186, 74, 56)]
const CLOTH_CREAM := [Color8(110, 98, 80), Color8(156, 142, 112), Color8(196, 182, 146), Color8(226, 214, 180)]
const PORTAL := [Color8(16, 14, 46), Color8(30, 36, 100), Color8(52, 72, 170), Color8(90, 126, 230),
		Color8(150, 186, 255), Color8(226, 238, 255)]

# --- the trader (14 x 22 drawn, feet on the bottom row) -----------------------------------------
# K/k hat, F/f feather, S/s skin, E eyes, B/b beard, W/w shirt, V/v waistcoat, L belt, G gold,
# P/p trousers, T boots.
const PAL := {
	"K": Color8(104, 70, 42), "k": Color8(70, 46, 30), "F": Color8(214, 70, 52), "f": Color8(150, 40, 36),
	"S": Color8(222, 176, 136), "s": Color8(176, 128, 96), "E": Color8(40, 28, 26),
	"B": Color8(204, 200, 194), "b": Color8(150, 146, 142),
	"W": Color8(222, 210, 178), "w": Color8(170, 156, 126),
	"V": Color8(150, 58, 46), "v": Color8(104, 38, 32),
	"L": Color8(60, 40, 28), "G": Color8(232, 184, 64),
	"P": Color8(78, 98, 66), "p": Color8(52, 68, 46), "T": Color8(64, 44, 32),
}
const TRADER := [
	"....kKKKKk....",
	"...kKKKKKKk.F.",
	"...kKKKKKKkFf.",
	".kkKKKKKKKKkk.",
	"kkkkkkkkkkkkkk",
	"...sSSSSSSs...",
	"...SESSSSES...",
	"...sSSSsSSs...",
	"...BSSSSSSB...",
	"...BBbSSbBB...",
	"....BBBBBB....",
	"..WVVBBBBVVW..",
	".WWVVVBBVVVWW.",
	".WwVVvWWvVVwW.",
	".WwVVvWWvVVwW.",
	".Ss.LLGLLL.sS.",
	"....PPPPPP....",
	"...GPPp.PPp...",
	"....PPp.PPp...",
	"....PPp.PPp...",
	"...TTTT.TTTT..",
	"...TTTT.TTTT..",
]
## Talking: his right hand (screen left) raised in greeting.
const TALK_ARM := {
	8: "S..BSSSSSSB...",
	9: "Ss.BBbSSbBB...",
	10: "Ww..BBBBBB....",
	11: ".WWVVBBBBVVW..",
	12: "..WVVVBBVVVWW.",
	13: "..wVVvWWvVVwW.",
	14: "...VVvWWvVVwW.",
	15: "....LLGLLL.sS.",
}

var img: Image
var ox := 0.0
var oy := 0.0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/npcs"))
	_trader()
	_stall()
	_portal()
	print("gen_trader_art: done")
	quit()


func _q(v: float, x: int, y: int, pal: Array) -> Color:
	v = v * (pal.size() - 1) + (BAYER[y % 4][x % 4] / 16.0 - 0.5) * 0.6
	return pal[clampi(roundi(v), 0, pal.size() - 1)]


func _outline(im: Image) -> void:
	var src := im.duplicate() as Image
	for y in im.get_height():
		for x in im.get_width():
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < im.get_width() and p.y < im.get_height() and src.get_pixelv(p).a > 0.5:
					im.set_pixel(x, y, OUTLINE)
					break


func _save(im: Image, path: String) -> void:
	var err := im.save_png(ProjectSettings.globalize_path(path))
	print("  %s %s %s" % [path, im.get_size(), "" if err == OK else "ERROR %d" % err])


# --- trader ------------------------------------------------------------------------------------

func _trader() -> void:
	var frames: Array = []
	frames.append(TRADER)
	var b: Array = ["".lpad(14, ".")]               # breath: head and beard bob down 1px
	for i in range(0, 10):
		b.append(TRADER[i])
	for i in range(11, TRADER.size()):
		b.append(TRADER[i])
	frames.append(b)
	var t: Array = TRADER.duplicate()
	for r: int in TALK_ARM:
		t[r] = TALK_ARM[r]
	frames.append(t)
	var sheet := Image.create_empty(16 * frames.size(), 24, false, Image.FORMAT_RGBA8)
	for k in frames.size():
		var cell := Image.create_empty(16, 24, false, Image.FORMAT_RGBA8)
		var rows: Array = frames[k]
		assert(rows.size() == 22)
		for y in rows.size():
			var line: String = rows[y]
			assert(line.length() == 14, "row %d of frame %d is %d wide" % [y, k, line.length()])
			for x in line.length():
				if PAL.has(line[x]):
					cell.set_pixel(x + 1, y + 1, PAL[line[x]])
		_outline(cell)
		sheet.blit_rect(cell, Rect2i(0, 0, 16, 24), Vector2i(16 * k, 0))
	_save(sheet, "res://assets/sprites/npcs/trader_sheet.png")


# --- the stall (iso box rasterizer as in gen_dungeon_art.gd) ------------------------------------

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


const FACE_LIGHT := {"top": 0.78, "left": 0.62, "right": 0.44}


## Box [x0,x1] x [y0,y1] x [z0,z1]; shade(face, px, py) -> Color.
func _box(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, shade: Callable) -> void:
	_fill(PackedVector2Array([_scr(x0, y1, z0), _scr(x1, y1, z0), _scr(x1, y1, z1), _scr(x0, y1, z1)]),
		func(px: int, py: int) -> Color: return shade.call("left", px, py))
	_fill(PackedVector2Array([_scr(x1, y1, z0), _scr(x1, y0, z0), _scr(x1, y0, z1), _scr(x1, y1, z1)]),
		func(px: int, py: int) -> Color: return shade.call("right", px, py))
	_fill(PackedVector2Array([_scr(x0, y0, z1), _scr(x1, y0, z1), _scr(x1, y1, z1), _scr(x0, y1, z1)]),
		func(px: int, py: int) -> Color: return shade.call("top", px, py))


func _wood(extra := 0.0) -> Callable:
	return func(face: String, px: int, py: int) -> Color:
		return _q(clampf(FACE_LIGHT[face] - 0.25 + extra, 0, 1), px, py, WOOD)


## A trader's stall: a plank counter with goods on it, four posts and a red-and-cream striped
## awning sloping down to the front. 48x64, cell centre (feet) at (24, 48).
func _stall() -> void:
	img = Image.create_empty(48, 64, false, Image.FORMAT_RGBA8)
	ox = 24.0
	oy = 48.0
	const X := 0.46
	const YB := -0.42        # back edge
	const YF := 0.40         # front edge
	# back posts (behind the counter)
	for x in [-X, X - 0.08]:
		_box(x, x + 0.08, YB, YB + 0.08, 0.0, 44.0, _wood(-0.05))
	# counter
	_box(-X + 0.04, X - 0.04, -0.12, YF - 0.06, 0.0, 12.0, func(face: String, px: int, py: int) -> Color:
		var v: float = FACE_LIGHT[face] - 0.2
		if face != "top" and py % 4 == 0:
			v -= 0.18                                  # plank seams
		return _q(clampf(v, 0, 1), px, py, WOOD))
	# goods on the counter: a red and a blue bottle, a small chest, a bundle of cloth
	var goods := [[Vector2(-0.25, 0.05), Color8(200, 50, 50), 5], [Vector2(-0.1, 0.12), Color8(70, 110, 230), 6],
			[Vector2(0.18, 0.02), Color8(214, 176, 70), 3]]
	for g in goods:
		var p := _scr(g[0].x, g[0].y, 12.0)
		for k in g[2]:
			img.set_pixel(int(p.x), int(p.y) - k, g[1] if k < g[2] - 1 else Color8(120, 90, 60))
			img.set_pixel(int(p.x) + 1, int(p.y) - k, (g[1] as Color).darkened(0.3) if k < g[2] - 1 else Color8(90, 64, 44))
	_box(0.02, 0.2, 0.12, 0.28, 12.0, 16.0, _wood(0.15))        # little coffer
	# front posts
	for x in [-X, X - 0.08]:
		_box(x, x + 0.08, YF - 0.08, YF, 0.0, 34.0, _wood(0.0))
	# the awning: sampled densely over its plane, stripes along the map's y axis
	for i in 200:
		for j in 160:
			var mx := lerpf(-X - 0.1, X + 0.1, i / 199.0)
			var my := lerpf(YB - 0.08, YF + 0.12, j / 159.0)
			var z := lerpf(46.0, 33.0, (my - (YB - 0.08)) / ((YF + 0.12) - (YB - 0.08)))
			var p := _scr(mx, my, z)
			var px := int(p.x)
			var py := int(p.y)
			if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
				continue
			var stripe := int(floor((mx + X + 0.1) * 7.0)) % 2 == 0
			var v := 0.75 - 0.2 * (my - YB)                     # a little darker toward the front
			if j > 150:
				v = 0.3                                          # the hem's shaded lip
			img.set_pixel(px, py, _q(clampf(v, 0, 1), px, py, CLOTH_RED if stripe else CLOTH_CREAM))
	# scalloped hem hanging off the front edge
	for i in 90:
		var mx := lerpf(-X - 0.1, X + 0.1, i / 89.0)
		var p := _scr(mx, YF + 0.12, 33.0)
		var drop := 2 + (1 if int(floor((mx + X + 0.1) * 7.0 * 2.0)) % 2 == 0 else 0)
		var stripe := int(floor((mx + X + 0.1) * 7.0)) % 2 == 0
		for k in drop:
			var px := int(p.x)
			var py := int(p.y) + 1 + k
			if py < img.get_height():
				img.set_pixel(px, py, (CLOTH_RED if stripe else CLOTH_CREAM)[1])
	_outline(img)
	_save(img, "res://assets/sprites/props/stall.png")


# --- portal ------------------------------------------------------------------------------------

const PW := 24
const PH := 40
const FRAMES := 8


## The Rune of Return's portal: an upright oval of swirling blue light with a bright rim and
## sparks orbiting it. 8 frames (one full turn of the swirl), 24x40 each, feet at (12, 38).
func _portal() -> void:
	var sheet := Image.create_empty(PW * FRAMES, PH, false, Image.FORMAT_RGBA8)
	var c := Vector2(12.0, 20.0)
	const RX := 9.5
	const RY := 17.5
	for f in FRAMES:
		var t := float(f) / FRAMES
		for y in PH:
			for x in PW:
				var d := Vector2((x + 0.5 - c.x) / RX, (y + 0.5 - c.y) / RY)
				var r := d.length()
				if r > 1.0:
					continue
				var a := atan2(d.y, d.x)
				# three swirl arms turning inward over time
				var swirl := 0.5 + 0.5 * sin(a * 3.0 + r * 9.0 - t * TAU)
				var v := 0.15 + 0.45 * swirl * r + 0.2 * (1.0 - r)
				if r > 0.84:
					v = 0.82 + 0.18 * sin(a * 4.0 + t * TAU * 2.0)          # bright rim
				elif r < 0.25:
					v = 0.55 + 0.2 * swirl                                   # glowing heart
				sheet.set_pixel(f * PW + x, y, _q(clampf(v, 0, 1), x, y, PORTAL))
		# sparks orbiting the rim
		for k in 4:
			var ang := t * TAU + k * TAU / 4.0
			var p := c + Vector2(cos(ang) * (RX + 1.0), sin(ang) * (RY + 0.5))
			var px := int(p.x)
			var py := int(p.y)
			if px >= 0 and px < PW and py >= 0 and py < PH:
				sheet.set_pixel(f * PW + px, py, PORTAL[5])
				for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(px, py) + dd
					if q.x >= 0 and q.x < PW and q.y >= 0 and q.y < PH and sheet.get_pixel(f * PW + q.x, q.y).a == 0.0:
						sheet.set_pixel(f * PW + q.x, q.y, Color(PORTAL[4], 0.7))
	_save(sheet, "res://assets/sprites/props/portal_sheet.png")
