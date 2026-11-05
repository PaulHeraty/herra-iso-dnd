extends SceneTree
## Skeleton sprite sheet -> assets/sprites/monsters/skeleton_sheet.png
## Run: Godot_console --headless --path . -s res://tools/godot/gen_skeleton.gd  (then --import)
##
## 16x24 cells like the heroes (14x22 drawn + 1px outline, feet at the bottom centre; sprite
## offset (-8, -22)). 17 columns x 2 rows (0 = front 3/4 facing screen down-left, 1 = back 3/4
## facing up-left; right-facing = mirrored):
##   0-1 idle (eyes glow / dim) · 2-5 walk · 6-8 attack (wind-up, strike, recover) · 9-10 hurt ·
##   11-16 death (the bones collapse into a heap; the skull lands last and stays on top)
## The poses are made from one hand-drawn pixel grid per view: the sword is redrawn for the
## attack, legs lift for the walk, and the death frames drop every pixel under gravity.

const OUT := "res://assets/sprites/monsters/skeleton_sheet.png"
const CELL := Vector2i(16, 24)
const COLS := 17

const PAL := {
	"B": Color8(226, 218, 196), "b": Color8(184, 174, 150), "d": Color8(120, 110, 98),
	"e": Color8(30, 14, 20), "r": Color8(255, 90, 60),
	"s": Color8(150, 160, 184), "S": Color8(72, 76, 96), "h": Color8(110, 70, 40),
}
const OUTLINE := Color8(20, 16, 24)
const SWORD := ["s", "S", "h"]

const FRONT := [
	"....bBBb......",
	"...bBBBBd...sS",
	"...BBBBBBd..sS",
	"...erBerBd..sS",
	"...BBdBBd...sS",
	"....dBdBd...sS",
	"....bBBb....sS",
	".....dd.....sS",
	"..bBBBBBBb..sS",
	".bd.bBBBb.d.sS",
	".B..d.d.d.B.sS",
	".B..bBBBb.B.sS",
	".b...dBd..dhhh",
	".B..bBBBb..Bh.",
	"....bd.db.....",
	"....bB.Bb.....",
	"....bB.Bb.....",
	"....dd.dd.....",
	"....B..B......",
	"....B..B......",
	"....B..B......",
	"...BB.BB......",
]
const BACK := [
	"......bBBb....",
	"Ss...bBBBBd...",
	"Ss..bBBBBBd...",
	"Ss..BBBBBBd...",
	"Ss..bBBBBBd...",
	"Ss...bBBBd....",
	"Ss....bBb.....",
	"Ss.....dd.....",
	"Ss..bBBBBBBb..",
	"Ss.d.bBdBb.db.",
	"Ss.B..dBd..B..",
	"Ss.B.bBdBb.B..",
	"hhhd...d...b..",
	".hB..bBBBb..B.",
	".....bd.db....",
	".....bB.Bb....",
	".....bB.Bb....",
	".....dd.dd....",
	".....B..B.....",
	".....B..B.....",
	".....B..B.....",
	"....BB.BB.....",
]
## Per view: the sword hand (grid cell), leg columns (left / right ranges), strike direction.
const VIEWS := [
	{"grid": FRONT, "hand": Vector2i(12, 13), "left": [0, 5], "right": [6, 13], "toward": -1},
	{"grid": BACK, "hand": Vector2i(1, 13), "left": [0, 6], "right": [7, 13], "toward": -1},
]
const LEG_TOP := 15
const SKULL_ROWS := 7


func _init() -> void:
	var sheet := Image.create_empty(CELL.x * COLS, CELL.y * 2, false, Image.FORMAT_RGBA8)
	for row in 2:
		var v: Dictionary = VIEWS[row]
		var base := _parse(v.grid)
		var frames: Array = []
		frames.append(base)                                        # idle: eyes glow
		frames.append(_recolor(base, "r", "e"))                    # idle: eyes dim
		frames.append(_lift(base, v.left))                         # walk
		frames.append(base)
		frames.append(_lift(base, v.right))
		frames.append(base)
		frames.append(_attack(base, v, 0))                         # attack
		frames.append(_attack(base, v, 1))
		frames.append(_attack(base, v, 2))
		frames.append(_shift(base, Vector2i(1, -1)))               # hurt
		frames.append(base)
		for i in 6:                                                # death
			frames.append(_collapse(base, i / 5.0, row))
		for c in frames.size():
			var cell := _to_image(frames[c])
			sheet.blit_rect(cell, Rect2i(Vector2i.ZERO, CELL), Vector2i(c * CELL.x, row * CELL.y))
	var err := sheet.save_png(OUT)
	print("gen_skeleton: ", OUT, " ", sheet.get_size(), "" if err == OK else " ERROR %d" % err)
	quit()


# --- frames are dictionaries Vector2i(x, y) -> palette key, on the 14x22 grid -----------------

func _parse(rows: Array) -> Dictionary:
	var f := {}
	for y in rows.size():
		for x in rows[y].length():
			var ch: String = rows[y][x]
			if ch != ".":
				f[Vector2i(x, y)] = ch
	return f


func _recolor(f: Dictionary, from: String, to: String) -> Dictionary:
	var o := {}
	for p in f:
		o[p] = to if f[p] == from else f[p]
	return o


func _shift(f: Dictionary, d: Vector2i) -> Dictionary:
	var o := {}
	for p in f:
		o[p + d] = f[p]
	return o


## Lift one leg (columns [a, b], rows from LEG_TOP+2 down) by a pixel.
func _lift(f: Dictionary, cols: Array) -> Dictionary:
	var o := {}
	for p: Vector2i in f:
		if p.y >= LEG_TOP + 2 and p.x >= cols[0] and p.x <= cols[1]:
			continue
		o[p] = f[p]
	for p: Vector2i in f:
		if p.y >= LEG_TOP + 2 and p.x >= cols[0] and p.x <= cols[1]:
			o[p + Vector2i(0, -1)] = f[p]
	return o


## Attack: 0 = wind-up (body leans back, blade raised over the shoulder), 1 = strike (body leans
## in, blade swept down in front), 2 = recover (blade low, body upright).
func _attack(f: Dictionary, v: Dictionary, phase: int) -> Dictionary:
	var o := {}
	var lean: int = [1, -1, 0][phase] * (-v.toward if v.grid == FRONT else v.toward)
	for p: Vector2i in f:
		if f[p] in SWORD:
			continue
		var q := p + (Vector2i(lean, 0) if p.y < LEG_TOP else Vector2i.ZERO)
		o[q] = f[p]
	var hand: Vector2i = v.hand + Vector2i(lean, 0)
	var dir: Vector2
	var front: bool = v.grid == FRONT
	match phase:
		0: dir = Vector2(0.45 if front else -0.45, -1.0)          # raised, tipped back
		1: dir = Vector2(-1.0 if front else 1.0, 0.55)             # swept across, low
		_: dir = Vector2(-0.4 if front else 0.4, 1.0)              # pointing down
	hand += Vector2i(0, [-3, -1, 0][phase])
	o[hand] = "h"
	for i in range(1, 10):
		var p := Vector2(hand) + dir.normalized() * i
		var c := Vector2i(roundi(p.x), roundi(p.y))
		o[c] = "s" if i < 9 else "S"
		var side := c + (Vector2i(1, 0) if absf(dir.y) > absf(dir.x) else Vector2i(0, 1))
		if not o.has(side):
			o[side] = "S"
	return o


## Death: every pixel falls (gravity) toward a heap on the floor; the skull falls as one piece and
## lands on top of the heap. t = 0..1.
func _collapse(f: Dictionary, t: float, seed_value: int) -> Dictionary:
	if t <= 0.0:
		return f
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + seed_value
	var heap := {}                    # column -> pixels stacked so far
	var bones: Array = []
	var skull: Array = []
	for y in range(21, -1, -1):
		for x in 14:
			var p := Vector2i(x, y)
			if not f.has(p):
				continue
			if y < SKULL_ROWS and not f[p] in SWORD:
				skull.append(p)
			else:
				bones.append(p)
	var o := {}
	var ease := t * t
	for p: Vector2i in bones:
		var tx := clampi(p.x + rng.randi_range(-3, 3), 1, 12)
		var h: int = heap.get(tx, 0)
		var ty := 21 - h / 3                                      # loose heap: 3 pixels per row
		heap[tx] = h + 1
		var q := Vector2(lerpf(p.x, tx, t), lerpf(p.y, ty, ease))
		o[Vector2i(roundi(q.x), roundi(q.y))] = f[p]
	# Skull lands beside the heap's middle, falling a little later than the body.
	var st := clampf((t - 0.2) / 0.8, 0.0, 1.0)
	var top := 21
	for x in range(4, 9):
		top = mini(top, 21 - int(heap.get(x, 0)) / 3)
	var drop := (top - SKULL_ROWS + 1) * st * st
	var slide := -2.0 * st
	for p: Vector2i in skull:
		var q := Vector2i(roundi(p.x + slide), roundi(p.y + drop))
		o[q] = _recolor_one(f[p], st)
	return o


func _recolor_one(ch: String, st: float) -> String:
	return "e" if ch == "r" and st > 0.6 else ch


func _to_image(f: Dictionary) -> Image:
	var img := Image.create_empty(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	for p: Vector2i in f:
		var q := p + Vector2i(1, 1)
		if q.x >= 0 and q.y >= 0 and q.x < CELL.x and q.y < CELL.y - 1:
			img.set_pixelv(q, PAL[f[p]])
	var src := img.duplicate() as Image
	for y in CELL.y:
		for x in CELL.x:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < CELL.x and p.y < CELL.y and src.get_pixelv(p).a > 0.0:
					img.set_pixel(x, y, OUTLINE)
					break
	return img
