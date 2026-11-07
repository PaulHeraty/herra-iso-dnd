extends SceneTree
## NPC art for module 1's story ("The Wraith Below", Phase 7), 16x24 cells: idle, idle (breath), talk.
##   assets/sprites/npcs/hanna_sheet.png   Hanna, a miner's wife: the Cleric's drawing without the mace,
##                                         in a rose-brown dress and a green shawl
##   assets/sprites/npcs/pell_sheet.png    Old Pell the farmer: Brannoc's drawing (trader_sheet) in a straw
##                                         hat and a faded brown waistcoat
##   assets/sprites/npcs/aldric_sheet.png  Sir Aldric's ghost: the Fighter's front idle frame turned pale
##                                         blue by brightness, half see-through (Npc.ghostly draws it unshaded)
## Run: Godot_console --headless --path . -s res://tools/godot/gen_story_art.gd  (then --import)

const NPCS := "res://assets/sprites/npcs/"
const OUTLINE := Color8(20, 16, 24)


func _init() -> void:
	_hanna()
	_pell()
	_aldric()
	print("gen_story_art: done")
	quit()


func _load(path: String) -> Image:
	var im := Image.load_from_file(ProjectSettings.globalize_path(path))
	im.convert(Image.FORMAT_RGBA8)
	return im


func _save(im: Image, name: String) -> void:
	im.save_png(ProjectSettings.globalize_path(NPCS + name))
	print("  ", NPCS + name, " ", im.get_size())


## Three frames from one 16x24 drawing: idle, breath (head + shoulders 1px down), talk (the hand at
## `hand` lifted 2px, when given).
func _frames(base: Image, hand := Rect2i()) -> Image:
	var out := Image.create_empty(48, 24, false, Image.FORMAT_RGBA8)
	for f in 3:
		out.blit_rect(base, Rect2i(0, 0, 16, 24), Vector2i(f * 16, 0))
	var b := out.get_region(Rect2i(16, 0, 16, 12))
	out.fill_rect(Rect2i(16, 0, 16, 12), Color(0, 0, 0, 0))
	out.blit_rect(b, Rect2i(0, 0, 16, 11), Vector2i(16, 1))
	if hand.size != Vector2i.ZERO:
		var h := out.get_region(Rect2i(hand.position + Vector2i(32, 0), hand.size))
		out.fill_rect(Rect2i(hand.position + Vector2i(32, 0), hand.size), Color(0, 0, 0, 0))
		out.blend_rect(h, Rect2i(Vector2i.ZERO, hand.size), hand.position + Vector2i(32, -2))
		# the sleeve follows the hand up
		for y in range(hand.position.y - 2, hand.position.y):
			for x in range(hand.position.x, hand.end.x):
				if out.get_pixel(32 + x, y + 2).a > 0.0 and out.get_pixel(32 + x, y).a == 0.0:
					out.set_pixel(32 + x, y, OUTLINE)
	return out


func _remap(im: Image, map: Dictionary) -> void:
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var k := Color8(c.r8, c.g8, c.b8)
			if map.has(k):
				var n: Color = map[k]
				im.set_pixel(x, y, Color(n.r, n.g, n.b, c.a))


func _hanna() -> void:
	var src := _load("res://assets/sprites/heroes/cleric_sheet.png").get_region(Rect2i(0, 0, 16, 24))
	# take the mace away: its head (rows 4-7) and handle (rows 8-11, x 12-13); close the empty hand
	for y in range(3, 12):
		for x in range(11 if y < 8 else 12, 16):
			src.set_pixel(x, y, Color(0, 0, 0, 0))
	src.set_pixel(12, 11, OUTLINE)
	# the gold cross on the chest goes; the belt (row 15) stays a plain leather belt
	for y in 15:
		for x in 16:
			if src.get_pixel(x, y).is_equal_approx(Color8(230, 190, 70)):
				src.set_pixel(x, y, Color8(232, 226, 210))
	_remap(src, {
		Color8(232, 226, 210): Color8(168, 104, 92), Color8(168, 162, 160): Color8(118, 70, 64),   # robe -> rose-brown dress
		Color8(230, 190, 70): Color8(96, 62, 40),                                                   # belt
		Color8(64, 96, 176): Color8(78, 104, 70), Color8(38, 56, 112): Color8(50, 68, 48),         # blue trim -> green shawl
		Color8(104, 62, 30): Color8(86, 56, 34),                                                    # hair a little darker
	})
	_save(_frames(src, Rect2i(11, 11, 3, 2)), "hanna_sheet.png")


func _pell() -> void:
	var src := _load(NPCS + "trader_sheet.png")
	_remap(src, {
		Color8(104, 70, 42): Color8(206, 176, 96), Color8(70, 46, 30): Color8(150, 122, 62),       # hat -> straw
		Color8(214, 70, 52): Color8(206, 176, 96), Color8(150, 40, 36): Color8(150, 122, 62),      # feather -> straw
		Color8(150, 58, 46): Color8(112, 94, 72), Color8(104, 38, 32): Color8(80, 66, 50),         # waistcoat -> faded brown
		Color8(78, 98, 66): Color8(92, 78, 60), Color8(52, 68, 46): Color8(64, 54, 42),            # trousers
	})
	_save(src, "pell_sheet.png")


func _aldric() -> void:
	var src := _load("res://assets/sprites/heroes/fighter_sheet.png").get_region(Rect2i(0, 0, 16, 24))
	var dark := Color8(46, 74, 120)
	var light := Color8(222, 244, 255)
	for y in 24:
		for x in 16:
			var c := src.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var v := clampf(c.get_luminance() * 1.25 + 0.08, 0.0, 1.0)
			var n := dark.lerp(light, v)
			n.a = 0.55 if c.is_equal_approx(OUTLINE) else 0.82
			src.set_pixel(x, y, n)
	var out := Image.create_empty(48, 24, false, Image.FORMAT_RGBA8)
	# idle, floating 1px higher, idle again (a ghost doesn't wave)
	out.blit_rect(src, Rect2i(0, 0, 16, 24), Vector2i(0, 0))
	out.blit_rect(src, Rect2i(0, 1, 16, 23), Vector2i(16, 0))
	out.blit_rect(src, Rect2i(0, 0, 16, 24), Vector2i(32, 0))
	_save(out, "aldric_sheet.png")
