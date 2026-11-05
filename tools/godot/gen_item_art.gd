extends SceneTree
## Item / loot art:
##   assets/sprites/props/chest_open.png  the open chest
##   assets/ui/item_icons.png             16x16 item icons (14x14 drawn + 1px dark outline), one
##                                        row in the order of ItemData.ICON_ORDER
## Run: Godot_console --headless --path . -s res://tools/godot/gen_item_art.gd   (then --import)
##
## Chest: same palette as the closed chest (gen_art.gd, CHEST grid in make_iso_party.py).
## Icons: weapons lie along the diagonal (tip top-right, pommel bottom-left), drawn from code in
## "axis" coordinates: along = y - x (-13 top-right .. 13 bottom-left), across = x + y (12/13 =
## the 2-pixel centre line). Armour, shield and rings are shaped by code too; potions, scroll,
## key, gem and coins are pixel grids.

const PAL := {
	"A": Color8(20, 16, 24),      # outline
	"B": Color8(70, 44, 26),      # dark wood
	"C": Color8(120, 78, 44),     # wood
	"D": Color8(230, 190, 70),    # gold bands
	"E": Color8(44, 28, 18),      # inside of the lid
	"F": Color8(24, 16, 14),      # deep shadow inside the box
	"G": Color8(36, 24, 18),      # inside floor
}

## 16 x 15: the lid stands up behind the box (we see its inside), the box is empty.
## Same width and bottom edge as the closed chest (16 x 12), so it swaps in place.
const CHEST_OPEN := [
	"..AAAAAAAAAAAA..",
	".ABBBBBBBBBBBBA.",
	".ABEEEEEEEEEEBA.",
	".ABEEEEEEEEEEBA.",
	".ADDDDDDDDDDDDA.",
	"ABFFFFFFFFFFFFBA",
	"ABGGFGGGGGFGGGBA",
	"ADDDDDDDDDDDDDDA",
	"ABCCCCCDDCCCCCBA",
	"ABCCCCCDACCCCCBA",
	"ABCCCCCDDCCCCCBA",
	"ABCCCCCCCCCCCCBA",
	"ADDDDDDDDDDDDDDA",
	".ABBBBBBBBBBBBA.",
	"..AAAAAAAAAAAA..",
]

# --- icon palette ------------------------------------------------------------------------------
const OUTLINE := Color8(20, 16, 24)
const ICON_PAL := {
	"w": Color8(236, 238, 244), "S": Color8(192, 198, 212), "s": Color8(138, 144, 162),
	"m": Color8(86, 90, 108), "Y": Color8(255, 216, 100), "y": Color8(206, 152, 50),
	"o": Color8(132, 88, 32), "C": Color8(178, 124, 72), "c": Color8(130, 86, 48),
	"b": Color8(84, 52, 30), "L": Color8(152, 98, 60), "l": Color8(106, 66, 40),
	"d": Color8(70, 42, 28), "R": Color8(238, 84, 84), "r": Color8(184, 36, 44),
	"q": Color8(112, 20, 32), "p": Color8(255, 178, 178), "g": Color8(176, 196, 214),
	"G": Color8(112, 128, 152), "B": Color8(110, 150, 240), "v": Color8(60, 80, 160),
	"P": Color8(234, 222, 184), "Q": Color8(190, 170, 126), "e": Color8(110, 210, 120),
	"E": Color8(50, 140, 80), "n": Color8(222, 214, 196),
}

const POTION := [
	"..............",
	".....bccb.....",
	".....GggG.....",
	"......gG......",
	"......gG......",
	"....GgrrrG....",
	"...GrRprrrG...",
	"..GrRRprrrrG..",
	"..GrRRrrrrrG..",
	"..GrRrrrrrqG..",
	"..GrrrrrrqqG..",
	"...GrrrrqqG...",
	"....GGGGGG....",
	"..............",
]
## Greater healing: a taller bottle with a gold collar, deeper red.
const POTION_GREATER := [
	"......bc......",
	".....bccb.....",
	".....yYyy.....",
	"......gG......",
	".....GgrG.....",
	"....GrRrrG....",
	"...GrRprrqG...",
	"...GRRprrqG...",
	"...GrRrrrqG...",
	"...GrRrrrqG...",
	"...GrrrrqqG...",
	"...GrrrrqqG...",
	"....GGGGGG....",
	"..............",
]
const SCROLL := [
	"..............",
	"..............",
	"...QPPPPPPPQ..",
	"..QPPPPPPPPPQ.",
	"..QQPPPPPPPQQ.",
	"...QPmmmPmPQ..",
	"...QPPPPPPPQ..",
	"...QPmmPmmPQ..",
	"...QPPPPPPPQ..",
	"...QPmPmmmPQ..",
	"...QPPPPPrrQ..",
	"..QQPPPPPrRQQ.",
	"..QPPPPPPPPPQ.",
	"...QPPPPPPPQ..",
]
const KEY := [
	"..............",
	"..............",
	"..............",
	"...yYYy.......",
	"..yY..oy......",
	"..Y....o......",
	"..Y....yYYYYYy",
	"..yo..oy...yo.",
	"...yooy....y.o",
	"...........o..",
	"..............",
	"..............",
	"..............",
	"..............",
]
const GEM := [
	"..............",
	"..............",
	"..............",
	"....vBBBBv....",
	"...vBwwBBBv...",
	"..vBwBBBBBBv..",
	"..vvvvvvvvvv..",
	"...vBBBBBBv...",
	"....vBBBBv....",
	".....vBBv.....",
	"......vv......",
	"..............",
	"..............",
	"..............",
]
const COINS := [
	"..............",
	"..............",
	"..............",
	".......oyyo...",
	"......oYYYyo..",
	"......oyyyyo..",
	"...oyyo.ooo...",
	"..oYYYyo......",
	"..oyyyyo.oyyo.",
	"...oooo.oYYYyo",
	"..oyyo..oyyyyo",
	".oYYYyo..oooo.",
	".oyyyyo.......",
	"..oooo........",
]


func _init() -> void:
	_save(_grid(CHEST_OPEN), "res://assets/sprites/props/chest_open.png")
	_save(_icons(), "res://assets/ui/item_icons.png")
	quit()


func _grid(rows: Array) -> Image:
	var img := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			if PAL.has(r[x]):
				img.set_pixel(x, y, PAL[r[x]])
	return img


func _save(img: Image, path: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	print("wrote %s %s err=%d" % [path, img.get_size(), err])


# --- icons -------------------------------------------------------------------------------------

## 14x14 canvas: Vector2i -> palette char (later pixels win).
class Canvas:
	var px := {}

	func put(x: int, y: int, ch: String) -> void:
		if x >= 0 and x < 14 and y >= 0 and y < 14 and ch != "." and ch != "":
			px[Vector2i(x, y)] = ch

	## Paint every pixel for which f(along, across) returns a palette char ("" = leave it).
	func axis(f: Callable) -> void:
		for y in 14:
			for x in 14:
				put(x, y, f.call(y - x, x + y))

	func rows(r: Array, ox := 0, oy := 0) -> void:
		for y in r.size():
			var line: String = r[y]
			for x in line.length():
				put(x + ox, y + oy, line[x])


func _icons() -> Image:
	var order: Array = ItemData.ICON_ORDER
	var img := Image.create(16 * order.size(), 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in order.size():
		var cv := Canvas.new()
		var fn := "_icon_" + str(order[i])
		if has_method(fn):
			call(fn, cv)
		else:
			push_warning("no icon drawing for %s" % order[i])
		_blit(img, cv, i * 16 + 1, 1)
		_blit(img, cv, i * 16 + 1, 17, MAGIC_OUTLINE)
		_glimmer(img, i * 16, 16)
	return img


## Row 1 (magic items): the outline turns deep blue, a soft blue glow rings it where the cell has
## room, and two tiny sparkles sit in the corners.
const MAGIC_OUTLINE := Color8(40, 40, 120)
const GLOW := Color(0.45, 0.58, 1.0, 0.45)
const SPARKLE := Color8(220, 232, 255)

func _glimmer(img: Image, x0: int, y0: int) -> void:
	var glow: Array[Vector2i] = []
	for y in 16:
		for x in 16:
			if img.get_pixel(x0 + x, y0 + y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if q.x >= 0 and q.x < 16 and q.y >= 0 and q.y < 16 \
						and img.get_pixelv(Vector2i(x0, y0) + q) == MAGIC_OUTLINE:
					glow.append(Vector2i(x, y))
					break
	for p in glow:
		img.set_pixel(x0 + p.x, y0 + p.y, GLOW)
	for s: Vector2i in [Vector2i(1, 1), Vector2i(14, 13)]:
		if img.get_pixel(x0 + s.x, y0 + s.y).a < 0.9:
			for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := s + d
				if q.x >= 0 and q.x < 16 and q.y >= 0 and q.y < 16 and img.get_pixelv(Vector2i(x0, y0) + q).a < 0.9:
					img.set_pixelv(Vector2i(x0, y0) + q, SPARKLE if d == Vector2i.ZERO else GLOW)


## Copy a canvas into the sheet and add the 1px outline (4-neighbours of drawn pixels).
func _blit(img: Image, cv: Canvas, ox: int, oy: int, outline := OUTLINE) -> void:
	for p: Vector2i in cv.px:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if not cv.px.has(q):
				img.set_pixel(ox + q.x, oy + q.y, outline)
	for p: Vector2i in cv.px:
		img.set_pixel(ox + p.x, oy + p.y, ICON_PAL[cv.px[p]])


# --- blades: tip at along = tip, guard at along g (half-length h), grip up to pommel p -------

func _sword(cv: Canvas, tip: int, g: int, h: int, p: int, wide := false, thin := false) -> void:
	cv.axis(func(a: int, c: int) -> String:
		if a >= tip and a < g:
			if thin:
				return "S" if c == 13 or (c == 12 and a > tip + 1) else ""
			if c == 12:
				return "w"
			if c == 13:
				return "s" if a > tip + 1 else "S"
			if wide and c == 14 and a > tip + 2:
				return "m"
			if wide and c == 11 and a > tip + 2:
				return "S"
		if a == g or a == g + 1:
			if absi(c * 2 - 25) <= h * 2 + 1:
				return "Y" if c < 13 else "y"
		if a > g + 1 and a < p and (c == 12 or c == 13):
			return "L" if c == 12 else "l"
		if a >= p and a <= p + 1 and (c == 12 or c == 13):
			return "Y" if c == 12 else "y"
		return "")


func _icon_dagger(cv: Canvas) -> void:
	_sword(cv, -7, 3, 1, 7)


func _icon_shortsword(cv: Canvas) -> void:
	_sword(cv, -10, 3, 2, 8)


func _icon_longsword(cv: Canvas) -> void:
	_sword(cv, -13, 5, 2, 10)


func _icon_greatsword(cv: Canvas) -> void:
	_sword(cv, -13, 5, 3, 11, true)


func _icon_rapier(cv: Canvas) -> void:
	_sword(cv, -13, 5, 1, 10, false, true)
	# a swept hilt: a gold loop round the knuckles
	cv.axis(func(a: int, c: int) -> String:
		if a >= 6 and a <= 9 and c == 15:
			return "y"
		if a == 9 and c == 14:
			return "y"
		return "")


## A haft on the centre line from along a0 to a1 (wood, leather grip near the end).
func _haft(cv: Canvas, a0: int, grip := true, a1 := 13) -> void:
	cv.axis(func(a: int, c: int) -> String:
		if a < a0 or a > a1 or (c != 12 and c != 13):
			return ""
		if grip and a >= 6 and a <= 10:
			return "L" if c == 12 else "l"
		if a >= a1 - 1:
			return "b"
		return "C" if c == 12 else "c")


func _icon_quarterstaff(cv: Canvas) -> void:
	cv.axis(func(a: int, c: int) -> String:
		if c != 12 and c != 13:
			return ""
		if a <= -12 or a >= 12:
			return "s" if c == 12 else "m"      # iron caps
		if a >= -2 and a <= 3:
			return "L" if c == 12 else "l"
		return "C" if c == 12 else "c")


func _icon_mace(cv: Canvas) -> void:
	_haft(cv, -5)
	# a flanged ball centred on along -9 (r2 = 8 x distance squared in pixels)
	cv.axis(func(a: int, c: int) -> String:
		var da := a + 9
		var dc := c * 2 - 25
		var r2 := da * da * 4 + dc * dc
		if r2 <= 50:
			if da <= -1 and dc <= -1:
				return "w"
			return "S" if r2 <= 26 else ("s" if da < 2 else "m")
		if r2 <= 100 and (absi(da) <= 1 or absi(dc) <= 1):
			return "m"
		return "")


func _icon_warhammer(cv: Canvas) -> void:
	_haft(cv, -6)
	# a heavy block across the haft and a short top spike
	cv.axis(func(a: int, c: int) -> String:
		if a >= -11 and a <= -6 and c >= 8 and c <= 17:
			if c >= 16 or a == -6:
				return "m"
			if c <= 9:
				return "w"
			return "S" if a <= -9 else "s"
		if a >= -13 and a < -11 and (c == 12 or c == 13):
			return "s"
		return "")


func _icon_handaxe(cv: Canvas) -> void:
	_haft(cv, -10)
	# the blade on the lower-right of the haft, fanning out to a bright edge
	cv.axis(func(a: int, c: int) -> String:
		var spread := c - 13
		if spread < 1 or spread > 6:
			return ""
		var w := 1.0 + spread * 0.75
		if absf(a + 9.5) <= w:
			if spread == 6:
				return "w"
			return "S" if spread >= 3 else "s"
		return "")


## A bow: the limb curves round towards the top-left, the string runs straight between the tips.
func _bow(cv: Canvas, half: int, bulge: float, wood := "c", dark := "b") -> void:
	var tips: Array[Vector2] = []
	for i in 81:
		var t := i / 80.0
		var a := lerpf(-half, half, t)
		var c := 12.5 - bulge * sin(PI * t) * 2.0
		# axis -> pixel: x = (c - a) / 2, y = (c + a) / 2
		var x := roundi((c - a) / 2.0)
		var y := roundi((c + a) / 2.0)
		var ch := wood
		if t > 0.42 and t < 0.58:
			ch = "L"
		elif t < 0.07 or t > 0.93:
			ch = dark
		cv.put(x, y, ch)
		if i == 0 or i == 80:
			tips.append(Vector2((c - a) / 2.0, (c + a) / 2.0))
	for i in 41:
		var q := tips[0].lerp(tips[1], i / 40.0)
		var v := Vector2i(roundi(q.x), roundi(q.y))
		if not cv.px.has(v):
			cv.put(v.x, v.y, "n")


func _icon_shortbow(cv: Canvas) -> void:
	_bow(cv, 9, 2.4)


func _icon_longbow(cv: Canvas) -> void:
	_bow(cv, 13, 3.0, "C", "c")


func _icon_light_crossbow(cv: Canvas) -> void:
	# axis -> pixel: x = (c - a) / 2, y = (c + a) / 2. The bow sits across the stock at along
	# -8, its arms (6.5 across units each way) swept back to along -4.
	var to_px := func(a: float, c: float) -> Vector2i:
		return Vector2i(roundi((c - a) / 2.0), roundi((c + a) / 2.0))
	# the string, from the bow tips back to the nut at along 0
	for side: int in [-1, 1]:
		for i in 31:
			var t := i / 30.0
			cv.put.callv(_v(to_px.call(lerpf(-4.0, 0.0, t), 12.5 + side * lerpf(6.5, 0.0, t)), "n"))
	# the stock (wider at the butt)
	cv.axis(func(a: int, c: int) -> String:
		if a >= -10 and a <= 12 and (c == 12 or c == 13):
			if a >= 6:
				return "b" if c == 13 else "c"
			return "C" if c == 12 else "c"
		if a >= 7 and a <= 12 and c == 14:
			return "b"
		return "")
	# the steel bow, two pixels thick
	for i in 61:
		var t := i / 60.0
		var d := lerpf(-6.5, 6.5, t)
		var a := -8.0 + 4.0 * pow(absf(d) / 6.5, 2.0)
		cv.put.callv(_v(to_px.call(a, 12.5 + d), "S"))
		cv.put.callv(_v(to_px.call(a + 1.0, 12.5 + d), "s"))
	cv.put(6, 6, "y")       # the nut that holds the string


func _v(p: Vector2i, ch: String) -> Array:
	return [p.x, p.y, ch]


# --- armour: a torso shape, coloured and patterned per armour kind ---------------------------

const SHIRT := [
	"..............",
	"...BBB..BBB...",
	".BBAAABBAAABB.",
	"BBAAAAAAAAAABB",
	"BBAAAAAAAAAABB",
	"BB.BAAAAAAB.BB",
	"...BAAAAAAB...",
	"...BAAAAAAB...",
	"...BAAAAAAB...",
	"...DDDDDDDD...",
	"...BAAAAAAB...",
	"...BAAAAAAB...",
	"...BBBBBBBB...",
	"..............",
]
## Longer: to the knees, sleeves to the elbows.
const COAT := [
	"..............",
	"...BBB..BBB...",
	".BBAAABBAAABB.",
	"BBAAAAAAAAAABB",
	"BAAAAAAAAAAAAB",
	"BAABAAAAAABAAB",
	"BBBBAAAAAABBBB",
	"...BAAAAAAB...",
	"...BAAAAAAB...",
	"...DDDDDDDD...",
	"..BAAAAAAAAB..",
	"..BAAAAAAAAB..",
	"..BAAAAAAAAB..",
	"..BBBBBBBBBB..",
]


## pal: [edge, light, mid, dark, belt]; pattern: plain / studs / chain / scale / plate.
func _armour(cv: Canvas, shape: Array, pal: Array, pattern: String) -> void:
	for y in 14:
		var line: String = shape[y]
		for x in 14:
			var m := line[x]
			if m == ".":
				continue
			var ch: String = pal[0]
			if m == "D":
				ch = "Y" if (x == 6 or x == 7) else pal[4]       # belt + buckle
			elif m == "A":
				ch = pal[1] if x <= 4 else (pal[3] if x >= 10 else pal[2])
				match pattern:
					"studs":
						if (x + y) % 3 == 0 and y % 2 == 1 and y > 2:
							ch = "y"
					"chain":
						if (x + y) % 2 == 0:
							ch = pal[3] if x > 4 else pal[2]
					"scale":
						if y % 2 == 0 and (x + (y / 2) % 2) % 2 == 0:
							ch = pal[3]
					"plate":
						if y in [5, 8, 11]:
							ch = pal[3]
						elif x == 5 and y > 2:
							ch = "w"
			cv.put(x, y, ch)


func _icon_leather_armor(cv: Canvas) -> void:
	_armour(cv, SHIRT, ["d", "L", "l", "d", "b"], "plain")


func _icon_studded_leather(cv: Canvas) -> void:
	_armour(cv, SHIRT, ["d", "L", "l", "d", "b"], "studs")


func _icon_chain_shirt(cv: Canvas) -> void:
	_armour(cv, SHIRT, ["m", "S", "s", "m", "l"], "chain")


func _icon_scale_mail(cv: Canvas) -> void:
	_armour(cv, COAT, ["o", "Y", "y", "o", "l"], "scale")


func _icon_chain_mail(cv: Canvas) -> void:
	_armour(cv, COAT, ["m", "S", "s", "m", "l"], "chain")


func _icon_plate_armor(cv: Canvas) -> void:
	_armour(cv, COAT, ["m", "w", "S", "s", "m"], "plate")


func _icon_shield(cv: Canvas) -> void:
	# heater shield: half-width per row, iron rim, wooden planks, gold boss
	var half := [0, 6, 6, 6, 6, 6, 6, 6, 5, 5, 4, 3, 2, 1]
	for y in range(1, 14):
		var hw: int = half[y]
		var next_hw: int = half[y + 1] if y < 13 else 0
		for x in range(7 - hw, 7 + hw):
			var rim := y == 1 or y == 13 or x == 7 - hw or x == 6 + hw or x < 7 - next_hw or x > 6 + next_hw
			var ch := ""
			if rim:
				ch = "S" if (x < 7 and y < 8) else "s"
				if y == 1 and x < 7:
					ch = "w"
			else:
				var plank := (x - 1) / 3
				ch = "C" if plank % 2 == 0 else "c"
				if x >= 9:
					ch = "c" if ch == "C" else "b"
			cv.put(x, y, ch)
	cv.rows(["Yy", "yo"], 6, 5)


func _ring(cv: Canvas, light: String, mid: String, dark: String) -> void:
	var cx := 6.5
	var cy := 7.5
	for y in 14:
		for x in 14:
			var dx := x - cx
			var dy := y - cy
			var outer := (dx * dx) / 30.0 + (dy * dy) / 16.0
			var inner := (dx * dx) / 9.0 + (dy * dy) / 3.5
			if outer <= 1.0 and inner > 1.0:
				var ch := mid
				if dy < -1.0 and dx < 1.0:
					ch = light
				elif dy > 1.0 or dx > 3.5:
					ch = dark
				cv.put(x, y, ch)


func _icon_ring_protection(cv: Canvas) -> void:
	_ring(cv, "w", "S", "s")
	cv.put(9, 4, "B")        # a faint blue glint: it's magic


func _icon_ring(cv: Canvas) -> void:
	_ring(cv, "Y", "y", "o")
	cv.rows([".B.", "BwB", ".v."], 5, 2)


func _icon_potion_healing(cv: Canvas) -> void:
	cv.rows(POTION)


func _icon_potion_greater_healing(cv: Canvas) -> void:
	cv.rows(POTION_GREATER)


func _icon_scroll(cv: Canvas) -> void:
	cv.rows(SCROLL)


func _icon_key(cv: Canvas) -> void:
	cv.rows(KEY)


func _icon_gem(cv: Canvas) -> void:
	cv.rows(GEM)


func _icon_gold(cv: Canvas) -> void:
	cv.rows(COINS)


## Woven silver wire (alternating light / dark pixels round the band) with a small pearl.
func _icon_ring_free_action(cv: Canvas) -> void:
	_ring(cv, "w", "g", "G")
	for p: Vector2i in cv.px.keys():
		if (p.x + p.y) % 2 == 0 and cv.px[p] == "g":
			cv.px[p] = "s"
	cv.rows([".w.", "wnw", ".P."], 5, 2)


## Gold band with a green stone.
func _icon_ring_resistance(cv: Canvas) -> void:
	_ring(cv, "Y", "y", "o")
	cv.rows([".e.", "eeE", ".E."], 5, 2)
