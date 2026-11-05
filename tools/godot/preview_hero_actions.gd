extends SceneTree
## Preview the hero action sheets as an animated GIF: the four heroes side by side, top row front
## view (facing down-left), bottom row back view mirrored (facing up-right), playing idle -> attack
## -> ranged -> cast -> hurt -> down at roughly in-game speed.
## Run: OUT=<path.gif> Godot_console --headless --path . -s res://tools/godot/preview_hero_actions.gd

const HEROES := ["fighter", "rogue", "cleric", "mage"]
const PANEL := Vector2i(40, 44)
const SCALE := 4
const FRAME_CS := 8
const BG := Color8(22, 20, 26)
const TILE := Color8(54, 52, 60)
const TILE_EDGE := Color8(38, 36, 44)

## Ranged animation per hero (as CombatManager._ranged_anim).
const RANGED := {"fighter": "attack", "rogue": "shoot", "cleric": "attack", "mage": "cast"}


func _init() -> void:
	var out_path := OS.get_environment("OUT")
	var walk := {}
	var act := {}
	for h in HEROES:
		walk[h] = _load("res://assets/sprites/heroes/%s_sheet.png" % h)
		act[h] = _load("res://assets/sprites/heroes/%s_actions.png" % h)
	var seqs := {}
	var n := 0
	for h in HEROES:
		seqs[h] = _sequence(h)
		n = maxi(n, seqs[h].size())
	var frames: Array[Image] = []
	for f in n:
		var img := Image.create_empty(PANEL.x * 4, PANEL.y * 2, false, Image.FORMAT_RGBA8)
		img.fill(BG)
		for i in HEROES.size():
			var h: String = HEROES[i]
			var s: Array = seqs[h]
			var col: int = s[mini(f, s.size() - 1)]
			for row in 2:
				var feet := Vector2i(i * PANEL.x + PANEL.x / 2, row * PANEL.y + PANEL.y - 9)
				_tile(img, feet)
				_shadow(img, feet)
				var spr: Image
				var at: Vector2i
				if col < 0:
					spr = walk[h].get_region(Rect2i(0, row * 24, 16, 24))
					at = feet + Vector2i(-8, -22)
				else:
					spr = act[h].get_region(Rect2i(col * 32, row * 32, 32, 32))
					at = feet + Vector2i(-16, -30)
				if row == 1:
					spr.flip_x()
				img.blend_rect(spr, Rect2i(Vector2i.ZERO, spr.get_size()), at)
		img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
		frames.append(img)
	var err := GifWriter.save(out_path, frames, FRAME_CS)
	print("wrote ", out_path, " (", n, " frames) err=", err)
	quit()


## Sheet column per GIF frame (-1 = walk-sheet idle).
func _sequence(h: String) -> Array:
	var s := []
	var idle := func(k: int) -> void:
		for i in k:
			s.append(-1)
	idle.call(5)
	s.append_array([0, 1, 2, 3])                        # attack (13 fps ~ 8 cs)
	idle.call(5)
	match RANGED[h]:
		"shoot":
			s.append_array([4, 4, 5, 5, 5, 6, 6])
		"cast":
			s.append_array([7, 8, 9, 10, 8, 9, 10])
		_:
			s.append_array([0, 1, 2, 3, -1, -1, -1])
	idle.call(5)
	s.append(7)                                          # cast: raise, then the glow loops
	for i in 3:
		s.append_array([8, 9, 10])
	idle.call(5)
	s.append_array([11, 11, 12, 12])                     # hurt
	idle.call(5)
	s.append_array([13, 14, 15])                         # down, then lying
	for i in 10:
		s.append(15)
	idle.call(4)
	return s


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img


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
