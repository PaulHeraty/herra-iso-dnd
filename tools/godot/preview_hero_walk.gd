extends SceneTree
## Preview a hero walk sheet as an animated GIF: the four facings laid out like the screen
## directions (up-left, up-right / down-left, down-right), each walking in place on a floor tile.
## Run: HERO=fighter OUT=<path.gif> Godot_console --headless --path . -s res://tools/godot/preview_hero_walk.gd
## Also writes <path>.png (first frame) next to the GIF.

const CELL := Vector2i(16, 24)
const PANEL := Vector2i(44, 40)
const SCALE := 6
const FRAME_CS := 9          ## centiseconds per walk frame (matches the in-game cycle)
const BG := Color8(22, 20, 26)
const TILE := Color8(54, 52, 60)
const TILE_EDGE := Color8(38, 36, 44)


func _init() -> void:
	var hero := OS.get_environment("HERO")
	if hero == "":
		hero = "fighter"
	var out_path := OS.get_environment("OUT")
	var sheet := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/heroes/%s_sheet.png" % hero))
	sheet.convert(Image.FORMAT_RGBA8)
	# [sheet row, flip] per panel: NW, NE, SW, SE
	var panels := [[1, false], [1, true], [0, false], [0, true]]
	var frames: Array[Image] = []
	for f in 4:
		var img := Image.create_empty(PANEL.x * 2, PANEL.y * 2, false, Image.FORMAT_RGBA8)
		img.fill(BG)
		for i in panels.size():
			var origin := Vector2i((i % 2) * PANEL.x, (i / 2) * PANEL.y)
			var feet := origin + Vector2i(PANEL.x / 2, PANEL.y - 9)
			_tile(img, feet)
			_shadow(img, feet)
			var spr := sheet.get_region(Rect2i(Vector2i((1 + f) * CELL.x, panels[i][0] * CELL.y), CELL))
			if panels[i][1]:
				spr.flip_x()
			img.blend_rect(spr, Rect2i(Vector2i.ZERO, CELL), feet + Vector2i(-8, -22))
		img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
		frames.append(img)
	var err := GifWriter.save(out_path, frames, FRAME_CS)
	frames[0].save_png(out_path.get_basename() + ".png")
	print("wrote ", out_path, " err=", err)
	quit()


func _tile(img: Image, c: Vector2i) -> void:
	for y in range(-8, 8):
		for x in range(-16, 16):
			var e := absf(x + 0.5) / 16.0 + absf(y + 0.5) / 8.0
			if e < 1.0:
				img.set_pixel(c.x + x, c.y + y, TILE_EDGE if e > 0.85 else TILE)


func _shadow(img: Image, c: Vector2i) -> void:
	for y in range(-4, 5):
		for x in range(-9, 10):
			var e := pow(x / 8.5, 2) + pow((y - 1) / 3.6, 2)
			if e < 1.0:
				var p := img.get_pixel(c.x + x, c.y + y)
				img.set_pixel(c.x + x, c.y + y, p.lerp(Color.BLACK, 0.5 if e < 0.6 else 0.3))
