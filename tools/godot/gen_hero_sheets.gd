extends SceneTree
## Builds the hero walk sheets: assets/sprites/heroes/<hero>_sheet.png
## Run: Godot_console --headless --path . -s res://tools/godot/gen_hero_sheets.gd  (then --import)
## HERO=<name> builds just one.
##
## Sheet layout: 16x24 cells (14x22 drawn + 1px outline), 5 columns x 2 rows.
##   row 0 = FRONT 3/4 view, facing screen down-left  (mirror for down-right)
##   row 1 = BACK  3/4 view, facing screen up-left    (mirror for up-right)
##   col 0 = idle, cols 1-4 = walk: right foot up, both down, left foot up, both down
## Each view = an upper body (rows 0-15) + the standing legs (rows 16-21). Walk frames keep the
## legs' shape and only lift one leg 1px (classic small-sprite walk):
##   "left" / "right" = inclusive column ranges of each leg (other columns never move, e.g. a staff)
##   "lift_from"      = first leg row that lifts (robes: only the feet row lifts = foot tucks under)
##   "sway_row"       = optional leg row (robe hem) shifted 1px toward the stepping side
## Palette: the P dict in tools/python/make_iso_party.py (same as gen_art.gd). "." = empty.

const PY_SOURCE := "res://tools/python/make_iso_party.py"
const OUT_DIR := "res://assets/sprites/heroes/"
const CELL := Vector2i(16, 24)
const UPPER_ROWS := 16

const HEROES := HeroDrawings.HEROES

## Walk frames: [lift left leg px, lift right leg px]
const WALK := [[0, 1], [0, 0], [1, 0], [0, 0]]

var palette := {}


func _init() -> void:
	palette = _parse_palette(FileAccess.get_file_as_string(PY_SOURCE))
	var only := OS.get_environment("HERO")
	for hero: String in HEROES:
		if only != "" and hero != only:
			continue
		var sheet := Image.create_empty(CELL.x * 5, CELL.y * 2, false, Image.FORMAT_RGBA8)
		var views := ["front", "back"]
		for view in views:
			for part in ["upper", "legs"]:
				var grid: Array = HEROES[hero][view][part]
				for i in grid.size():
					if grid[i].length() != 14:
						push_error("%s %s %s row %d is %d wide (want 14)" % [hero, view, part, i, grid[i].length()])
		for row in views.size():
			var v: Dictionary = HEROES[hero][views[row]]
			var frames := [_frame(v, 0, 0)]
			for w in WALK:
				frames.append(_frame(v, w[0], w[1]))
			for col in frames.size():
				var img: Image = frames[col]
				sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(col * CELL.x, row * CELL.y))
		var path := OUT_DIR + hero + "_sheet.png"
		sheet.save_png(ProjectSettings.globalize_path(path))
		print("wrote ", path)
	quit()


## One 16x24 frame: legs (each leg lifted by its amount) + upper body on top, then the outline.
func _frame(v: Dictionary, lift_l: int, lift_r: int) -> Image:
	var rows: Array[String] = []
	for r in 22:
		rows.append("..............")
	var legs: Array = v["legs"]
	var lr: Array = v["left"]
	var rr: Array = v["right"]
	var lift_from: int = v.get("lift_from", 0)
	var sway_row: int = v.get("sway_row", -1)
	for i in legs.size():
		var row := ""
		for x in 14:
			var lift := 0
			if i >= lift_from:
				if x >= lr[0] and x <= lr[1]:
					lift = lift_l
				elif x >= rr[0] and x <= rr[1]:
					lift = lift_r
			var src := i + lift
			row += _px(legs, src, x)
		if i == sway_row and lift_l != lift_r:
			var s := 1 if lift_r > lift_l else -1    # hem swings toward the stepping (lifted) side
			var swayed := ""
			for x in 14:
				var inside: bool = x >= lr[0] and x <= rr[1]    # only the hem moves, not a staff
				var from: int = x - s
				swayed += (_px(legs, i, from) if from >= lr[0] and from <= rr[1] else ".") if inside else row[x]
			row = swayed
		rows[UPPER_ROWS + i] = row
	var upper: Array = v["upper"]
	for i in upper.size():
		# upper body overwrites only where it has pixels
		var merged := ""
		for x in 14:
			var c: String = upper[i][x] if x < upper[i].length() else "."
			merged += c if c != "." else rows[i][x]
		rows[i] = merged
	return _grid_sprite(rows)


func _px(grid: Array, y: int, x: int) -> String:
	if y < 0 or y >= grid.size() or x < 0 or x >= grid[y].length():
		return "."
	return grid[y][x]


func _parse_palette(src: String) -> Dictionary:
	var block := src.substr(src.find("P = {"))
	block = block.substr(0, block.find("}"))
	var re := RegEx.create_from_string("\"(\\w)\":\\s*\\((\\d+),\\s*(\\d+),\\s*(\\d+)\\)")
	var pal := {}
	for m in re.search_all(block):
		pal[m.get_string(1)] = Color8(int(m.get_string(2)), int(m.get_string(3)), int(m.get_string(4)))
	return pal


## Pixel grid -> 16x24 image with a 1px margin filled by the dark outline (as gen_art.gd).
func _grid_sprite(rows: Array[String]) -> Image:
	var img := Image.create_empty(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			var ch: String = rows[y][x]
			if ch != ".":
				if not palette.has(ch):
					push_error("unknown palette key '%s'" % ch)
					continue
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
