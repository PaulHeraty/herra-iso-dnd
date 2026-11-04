extends SceneTree
## Condition icons -> assets/ui/condition_icons.png: 9x9 cells (7x7 drawn + 1px dark outline),
## one row, in the order of ORDER (Condition.ICON_INDEX must match).
## Run: Godot_console --headless --path . -s res://tools/godot/gen_icons.gd   (then --import)

const OUT := "res://assets/ui/condition_icons.png"
const CELL := 9
const OUTLINE := Color8(20, 16, 24)
const PAL := {
	"y": Color8(230, 180, 60), "Y": Color8(255, 226, 120), "w": Color8(240, 238, 230),
	"g": Color8(170, 166, 176), "G": Color8(110, 106, 118), "b": Color8(64, 96, 176),
	"B": Color8(110, 150, 240), "k": Color8(20, 16, 24), "r": Color8(220, 60, 60),
	"R": Color8(140, 30, 36), "p": Color8(200, 110, 230), "c": Color8(170, 150, 255),
	"e": Color8(110, 210, 120), "E": Color8(60, 150, 80), "o": Color8(240, 150, 80),
}
const ORDER := ["blessed", "prone", "restrained", "hidden", "frightened", "shielded", "concentrating", "dying", "stable"]
const ICONS := {
	"blessed": [
		"...y...",
		"..yYy..",
		".yYwYy.",
		"yYwwwYy",
		".yYwYy.",
		"..yYy..",
		"...y...",
	],
	"prone": [
		"..ggg..",
		"..ggg..",
		"..ggg..",
		"ggggggg",
		".ggggg.",
		"..ggg..",
		"...g...",
	],
	"restrained": [
		"g..g..g",
		".g.g.g.",
		"..www..",
		"gwwwwwg",
		"..www..",
		".g.g.g.",
		"g..g..g",
	],
	"hidden": [
		"......r",
		".bbbbr.",
		"bwwkrwb",
		"bwwrwwb",
		".brbbb.",
		"r......",
		".......",
	],
	"frightened": [
		"..ppp..",
		"..ppp..",
		"..ppp..",
		"..ppp..",
		"...p...",
		".......",
		"..ppp..",
	],
	"shielded": [
		"bbbbbbb",
		"bBBBBBb",
		"bBwBBBb",
		"bBwBBBb",
		".bBBBb.",
		"..bBb..",
		"...b...",
	],
	"concentrating": [
		"..ccc..",
		".c...c.",
		"c..c..c",
		"c.ccc.c",
		"c..c..c",
		".c...c.",
		"..ccc..",
	],
	"dying": [
		".rr.rr.",
		"rrrrrrr",
		"rrwRrrr",
		"rrrwrrr",
		".rrwrr.",
		"..rrr..",
		"...r...",
	],
	"stable": [
		".ee.ee.",
		"eewEeee",
		"eweeeee",
		"eeeeeeE",
		".eeeeE.",
		"..eEE..",
		"...E...",
	],
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui"))
	var img := Image.create_empty(CELL * ORDER.size(), CELL, false, Image.FORMAT_RGBA8)
	for i in ORDER.size():
		var rows: Array = ICONS[ORDER[i]]
		for y in rows.size():
			for x in rows[y].length():
				var ch: String = rows[y][x]
				if ch != ".":
					img.set_pixel(i * CELL + 1 + x, 1 + y, PAL[ch])
	var src := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0:
				continue
			var cell_x := x % CELL
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():
					continue
				if (p.x % CELL) != cell_x + d.x:     # don't bleed into the next icon
					continue
				if src.get_pixelv(p).a > 0:
					img.set_pixel(x, y, OUTLINE)
					break
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("wrote ", OUT, " ", img.get_size())
	quit()
