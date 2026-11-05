extends SceneTree
## Item / loot art: the open chest (assets/sprites/props/chest_open.png). Item icons come here
## in Phase 4 step 3.
## Run: Godot_console --headless --path . -s res://tools/godot/gen_item_art.gd   (then --import)
##
## Same palette as the closed chest (gen_art.gd, CHEST grid in tools/python/make_iso_party.py).

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


func _init() -> void:
	_save(_grid(CHEST_OPEN), "res://assets/sprites/props/chest_open.png")
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
