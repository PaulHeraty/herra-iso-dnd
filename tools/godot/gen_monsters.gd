extends SceneTree
## Monster sprite sheets + scenes for the campaign's new monsters:
##   assets/sprites/monsters/<id>_sheet.png  and  scenes/actors/monsters/<id>.tscn
## Run: Godot_console --headless --path . -s res://tools/godot/gen_monsters.gd  (then --import)
##      add monster ids after -- to make only those; "-- preview" also writes a contact sheet
##      to the path in HERRA_PREVIEW (for checking the art).
##
## Sheet layout (like the skeleton): 17 columns x 2 rows (0 = front 3/4 facing screen down-left,
## 1 = back 3/4 facing up-left; right-facing = mirrored):
##   0-1 idle · 2-5 walk · 6-8 attack (wind-up, strike, recover) · 9-10 hurt · 11-16 death
## Cells are bigger than the figure (32x32 for man-sized ones) so a weapon swing or a body lying on
## the floor fits. The feet stand at the bottom centre of the cell, 2 px above its bottom edge.
##
## Humanoids are one body template (head, torso, arms, legs by letter) recoloured per monster plus
## an overlay grid (hoods, ears, helmets, wrappings, fur...); the back view is the front mirrored
## with the face covered. Beasts and the floating undead have their own drawings. Every frame gets
## the 1 px dark outline of the project's sprites.

const OUTLINE := Color8(20, 16, 24)
const OUT_DIR := "res://assets/sprites/monsters/"
const SCENE_DIR := "res://scenes/actors/monsters/"
const COLS := 17

# --- the humanoid template (14 x 22; feet on row 21) ------------------------------------------
# H/h head (skin), E eyes, M mouth, T/t torso, A/a arms, K hands, W belt, P/p legs, F feet.
# Lower-case = the shade of the upper-case part.
const MEDIUM := [
	".....hhh......",
	"....hHHHh.....",
	"...hHHHHHh....",
	"...hHHHHHh....",
	"...hEHHEHh....",
	"...hHHHHHh....",
	"....hHMHh.....",
	".....hHh......",
	"...tTTTTTt....",
	"..aTTTTTTTa...",
	"..AtTTTTTtA...",
	"..A.tTTTt.A...",
	"..K.WWWWW.K...",
	"....pPPPp.....",
	"....pP.Pp.....",
	"....pP.Pp.....",
	"....pP.Pp.....",
	"....pP.Pp.....",
	"....pP.Pp.....",
	"....pP.Pp.....",
	"...FFF.FFF....",
	"...FFF.FFF....",
]
const MEDIUM_RIG := {"hand": Vector2i(10, 12), "legs_top": 14, "head_rows": 8}

# Small (goblins): 12 x 16.
const SMALL := [
	"....hHHh....",
	"...hHHHHh...",
	"..hHHHHHHh..",
	"..hHEHHEHh..",
	"...hHMMHh...",
	"....hHHh....",
	"..tTTTTTTt..",
	".AtTTTTTTtA.",
	".A.tTTTTt.A.",
	".K.WWWWWW.K.",
	"...pPPPPp...",
	"...pP..Pp...",
	"...pP..Pp...",
	"...pP..Pp...",
	"..FF...FF...",
	"..FF...FF...",
]
const SMALL_RIG := {"hand": Vector2i(10, 9), "legs_top": 11, "head_rows": 6}

## Part letter -> palette key in a monster's colours (the shade is worked out).
const PARTS := {"H": "skin", "E": "eye", "M": "mouth", "T": "torso", "A": "arm", "K": "hand",
		"W": "belt", "P": "legs", "F": "feet"}

# --- the monsters -------------------------------------------------------------------------------
# kind: "humanoid" (template + overlay), "grid" (own drawing: front/back), "beast" (side view),
# "float" (no legs). weapon: scimitar, sword, club, morningstar, claws.
var SPECS := {
	"goblin": {
		"kind": "humanoid", "template": "small", "cell": Vector2i(24, 24), "weapon": "scimitar",
		"colors": {"skin": Color8(112, 160, 66), "eye": Color8(255, 222, 70), "mouth": Color8(52, 30, 28),
			"torso": Color8(128, 92, 56), "arm": Color8(112, 160, 66), "hand": Color8(112, 160, 66),
			"belt": Color8(70, 50, 36), "legs": Color8(98, 72, 48), "feet": Color8(58, 44, 36)},
		# big ears, a ragged tuft of hair
		"overlay": [
			"....dddd....",
			"G..d....d..G",
			"Gg........gG",
			".g........g.",
			"............",
		],
		"ocolors": {"G": Color8(112, 160, 66), "g": Color8(72, 112, 46), "d": Color8(44, 36, 30)},
	},
	"goblin_boss": {
		"kind": "humanoid", "template": "small", "cell": Vector2i(24, 24), "weapon": "scimitar",
		"colors": {"skin": Color8(96, 148, 58), "eye": Color8(255, 120, 60), "mouth": Color8(52, 30, 28),
			"torso": Color8(150, 156, 168), "arm": Color8(170, 50, 44), "hand": Color8(96, 148, 58),
			"belt": Color8(90, 60, 36), "legs": Color8(110, 38, 36), "feet": Color8(58, 44, 36)},
		# iron helm with a crest, ears out under it, red cape behind the shoulders
		"overlay": [
			"...sSSSSs...",
			"G.sSSSSSSs.G",
			"Gg.s....s.gG",
			".g........g.",
			"............",
			"............",
			".r........r.",
			"r..........r",
			"r..........r",
		],
		"ocolors": {"G": Color8(96, 148, 58), "g": Color8(62, 104, 40), "s": Color8(92, 96, 110),
			"S": Color8(160, 166, 178), "r": Color8(150, 40, 36)},
		"weapon_colors": [Color8(214, 218, 230), Color8(120, 124, 140), Color8(200, 160, 60)],
	},
	"bandit": {
		"kind": "humanoid", "template": "medium", "cell": Vector2i(32, 32), "weapon": "scimitar",
		"colors": {"skin": Color8(214, 170, 130), "eye": Color8(40, 28, 26), "mouth": Color8(120, 70, 60),
			"torso": Color8(132, 92, 58), "arm": Color8(70, 96, 64), "hand": Color8(214, 170, 130),
			"belt": Color8(60, 42, 30), "legs": Color8(84, 70, 60), "feet": Color8(44, 34, 30)},
		# green hood and a scarf over the mouth
		"overlay": [
			".....ccc......",
			"....cCCCc.....",
			"...cCCCCCc....",
			"...cC...Cc....",
			"...c.....c....",
			"...cmmmmmc....",
			"....mmmmm.....",
			".....mm.......",
		],
		"ocolors": {"c": Color8(52, 80, 52), "C": Color8(74, 110, 70), "m": Color8(120, 40, 40)},
		"back_face": "C",
	},
	"hobgoblin": {
		"kind": "humanoid", "template": "medium", "cell": Vector2i(32, 32), "weapon": "sword",
		"colors": {"skin": Color8(206, 104, 56), "eye": Color8(255, 230, 90), "mouth": Color8(70, 30, 24),
			"torso": Color8(140, 150, 170), "arm": Color8(150, 40, 40), "hand": Color8(206, 104, 56),
			"belt": Color8(70, 50, 36), "legs": Color8(60, 56, 72), "feet": Color8(40, 34, 36)},
		# black topknot, pointed ears, shoulder plates
		"overlay": [
			".....kk.......",
			"....kkkk......",
			"...k.....k....",
			"..H.......H...",
			"..h...........",
			"..............",
			"..............",
			"..............",
			"..sS.....Ss...",
			"..s.......s...",
		],
		"ocolors": {"k": Color8(30, 26, 32), "H": Color8(206, 104, 56), "h": Color8(150, 70, 40),
			"s": Color8(100, 108, 128), "S": Color8(176, 184, 200)},
	},
	"bugbear": {
		"kind": "humanoid", "template": "medium", "cell": Vector2i(32, 32), "weapon": "morningstar",
		"scale_y": 1, "colors": {"skin": Color8(150, 104, 60), "eye": Color8(250, 210, 80), "mouth": Color8(60, 30, 26),
			"torso": Color8(112, 78, 48), "arm": Color8(150, 104, 60), "hand": Color8(150, 104, 60),
			"belt": Color8(60, 44, 34), "legs": Color8(98, 72, 48), "feet": Color8(70, 50, 36)},
		# shaggy fur mane, round bear ears, broad shoulders of fur
		"overlay": [
			"..ff....ff....",
			"..fFf..fFf....",
			"..fF.....Ff...",
			"..f.......f...",
			"..f.......f...",
			"...f.....f....",
			"...fFfFfFf....",
			"..fFFfFfFFf...",
			".fFf.....fFf..",
			".fF.......Ff..",
		],
		"ocolors": {"f": Color8(96, 64, 38), "F": Color8(138, 96, 56)},
	},
	"zombie": {
		"kind": "humanoid", "template": "medium", "cell": Vector2i(32, 32), "weapon": "claws",
		"colors": {"skin": Color8(128, 148, 102), "eye": Color8(226, 230, 196), "mouth": Color8(50, 30, 34),
			"torso": Color8(104, 88, 76), "arm": Color8(128, 148, 102), "hand": Color8(128, 148, 102),
			"belt": Color8(70, 58, 50), "legs": Color8(84, 76, 70), "feet": Color8(110, 126, 90)},
		# torn shirt (skin and a wound show through), lank hair
		"overlay": [
			"....dd.d......",
			"...d....d.....",
			"..............",
			"..............",
			"..............",
			"..............",
			"..............",
			"..............",
			"..............",
			"......Hr......",
			"....H..H......",
			"......Hw......",
			"..............",
			".......H......",
			".....p........",
		],
		"ocolors": {"d": Color8(54, 48, 40), "H": Color8(128, 148, 102), "r": Color8(150, 44, 44),
			"w": Color8(96, 30, 34), "p": Color8(128, 148, 102)},
		"death": "collapse",
	},
	"ghoul": {
		"kind": "humanoid", "template": "medium", "cell": Vector2i(32, 32), "weapon": "claws",
		"colors": {"skin": Color8(150, 140, 156), "eye": Color8(255, 70, 50), "mouth": Color8(240, 236, 220),
			"torso": Color8(150, 140, 156), "arm": Color8(150, 140, 156), "hand": Color8(190, 184, 196),
			"belt": Color8(74, 60, 54), "legs": Color8(132, 122, 140), "feet": Color8(150, 140, 156)},
		# bald pointed ears, ribs, a rag loincloth
		"overlay": [
			"..............",
			"..............",
			"..H.......H...",
			"..h.......h...",
			"..............",
			"..............",
			"..............",
			"..............",
			"..............",
			"....r.r.r.....",
			"....r.r.r.....",
			"..............",
			"..............",
			"....WWWWW.....",
			".....WWW......",
		],
		"ocolors": {"H": Color8(150, 140, 156), "h": Color8(104, 96, 112), "r": Color8(104, 96, 112),
			"W": Color8(74, 60, 54)},
	},
	"ghast": {
		"base": "ghoul", "colors_over": {"skin": Color8(110, 130, 100), "torso": Color8(110, 130, 100),
			"arm": Color8(110, 130, 100), "legs": Color8(92, 110, 84), "feet": Color8(110, 130, 100),
			"hand": Color8(160, 176, 140), "eye": Color8(255, 210, 60)},
		"ocolors_over": {"H": Color8(110, 130, 100), "h": Color8(76, 92, 70), "r": Color8(76, 92, 70),
			"W": Color8(48, 40, 44)},
	},
	"wight": {
		"kind": "humanoid", "template": "medium", "cell": Vector2i(32, 32), "weapon": "sword",
		"colors": {"skin": Color8(132, 146, 168), "eye": Color8(255, 60, 60), "mouth": Color8(30, 24, 34),
			"torso": Color8(62, 66, 86), "arm": Color8(48, 52, 70), "hand": Color8(132, 146, 168),
			"belt": Color8(110, 90, 50), "legs": Color8(44, 46, 62), "feet": Color8(32, 32, 44)},
		# a dark iron crown over a gaunt face, a torn cloak at the shoulders
		"overlay": [
			"....y.y.y.....",
			"....yYyYy.....",
			"..............",
			"..............",
			"..............",
			"..............",
			"..............",
			"..............",
			"..cc.....cc...",
			".c.........c..",
			".c.........c..",
			".c.........c..",
			"..............",
			"..............",
			"...c.......c..",
			"...c..........",
		],
		"ocolors": {"y": Color8(110, 96, 70), "Y": Color8(170, 150, 90), "c": Color8(36, 30, 44)},
		"weapon_colors": [Color8(150, 160, 190), Color8(70, 74, 96), Color8(60, 50, 44)],
		"death": "collapse",
	},
	"mummy": {
		"kind": "humanoid", "template": "medium", "cell": Vector2i(32, 32), "weapon": "claws",
		"colors": {"skin": Color8(206, 190, 150), "eye": Color8(150, 255, 120), "mouth": Color8(60, 40, 30),
			"torso": Color8(196, 178, 136), "arm": Color8(196, 178, 136), "hand": Color8(206, 190, 150),
			"belt": Color8(150, 130, 96), "legs": Color8(188, 170, 128), "feet": Color8(170, 150, 110)},
		# bandage stripes all over, a loose trailing strip
		"overlay": [
			"..............",
			"....bbbb......",
			"..............",
			"...bbbbbbb....",
			"..............",
			"....bbbbb.....",
			"..............",
			"..............",
			"...bbbbbbb....",
			"..............",
			"..b.bbbbb.b...",
			"..............",
			"..............",
			"....bbbbb.....",
			"..............",
			"....bb.bb.....",
			"..............",
			"....bb.bb.....",
			"..............",
			"....bb.bb.....",
		],
		"ocolors": {"b": Color8(150, 132, 98)},
		"death": "collapse",
	},
	"ogre": {
		"kind": "grid", "cell": Vector2i(40, 40), "weapon": "club", "hand": Vector2i(17, 17), "legs_top": 20,
		"head_rows": 7,
		"grid": [
			"........hhhh........",
			".......hHHHHh.......",
			"......hHHHHHHh......",
			"......hHeHHeHh......",
			"......hHHnnHHh......",
			".....hHHmMMmHHh.....",
			"......hHHHHHHh......",
			"...ttTTTTTTTTTTtt...",
			"..tTTTTTTTTTTTTTTt..",
			".sTTTTTTTTTTTTTTTTs.",
			".STTTTTTTTTTTTTTTTS.",
			".STtTTTTTTTTTTTTtTS.",
			".SS.tTTTTTTTTTTt.SS.",
			".SS..BBBBBBBBBB..SS.",
			".SS..BBbBBBBbBB..SS.",
			".sS..LLLLLLLLLL..Ss.",
			".KK..LLLLLLLLLL..KK.",
			".KK..lLLLlLLLLl..KK.",
			"......lLLl.lLLl.....",
			"......sSSs.sSSs.....",
			"......SSSs.sSSS.....",
			"......SSSs.sSSS.....",
			"......SSSs.sSSS.....",
			"......SSSs.sSSS.....",
			".....fFFFf.fFFFf....",
			".....fFFFf.fFFFf....",
		],
		"colors": {"H": Color8(196, 168, 112), "h": Color8(150, 124, 82), "e": Color8(30, 24, 24),
			"n": Color8(150, 110, 80), "m": Color8(70, 40, 30), "M": Color8(240, 232, 210),
			"T": Color8(196, 168, 112), "t": Color8(150, 124, 82), "S": Color8(196, 168, 112),
			"s": Color8(150, 124, 82), "K": Color8(176, 148, 100), "B": Color8(96, 70, 44),
			"b": Color8(200, 190, 160), "L": Color8(120, 92, 60), "l": Color8(84, 64, 44),
			"f": Color8(110, 84, 60), "F": Color8(150, 118, 84)},
		"back_face": "H",
	},
	"specter": {
		"kind": "float", "cell": Vector2i(32, 32), "weapon": "claws", "hand": Vector2i(11, 10), "head_rows": 7,
		"grid": [
			".....cccc.....",
			"....cCCCCc....",
			"...cCkkkkCc...",
			"...cCkekekc...",
			"...cCkkkkCc...",
			"....cCkkCc....",
			"...cCCCCCCc...",
			"..cCCCCCCCCc..",
			".cC.cCCCCc.Cc.",
			".C..cCCCCc..C.",
			".w..cCCCCc..w.",
			"....cCCCCc....",
			"....cCCCCCc...",
			"...cCCCCCCc...",
			"...cCC.CCCc...",
			"...cC..cCc....",
			"....c..c.c....",
			"....c.....c...",
		],
		"colors": {"c": Color8(90, 120, 150), "C": Color8(150, 190, 214), "k": Color8(20, 24, 40),
			"e": Color8(220, 250, 255), "w": Color8(200, 230, 245)},
		"back_face": "k", "alpha": 0.82, "unshaded": true,
	},
	"wraith": {
		"kind": "float", "cell": Vector2i(32, 32), "weapon": "claws", "hand": Vector2i(13, 11), "head_rows": 8,
		"grid": [
			"......ccc.......",
			".....cCCCc......",
			"....cCCCCCc.....",
			"...cCkkkkkCc....",
			"...cCkekkekc....",
			"...cCkkkkkCc....",
			"...ccCkkkCcc....",
			"..ccCCCCCCCcc...",
			".cCCCCCCCCCCCc..",
			"cC.cCCCCCCCc.Cc.",
			"C..cCCCCCCCc..C.",
			"w..cCCCCCCCc..w.",
			"w..cCCCCCCCCc.w.",
			"...cCCCCCCCCc...",
			"..cCCCCCCCCCCc..",
			"..cCCC.CCCC.Cc..",
			"..cCC..cCC..Cc..",
			"...cC...cC..c...",
			"...c.....c...c..",
			"....c.........c.",
		],
		"colors": {"c": Color8(40, 34, 56), "C": Color8(74, 62, 98), "k": Color8(10, 8, 16),
			"e": Color8(255, 70, 60), "w": Color8(170, 160, 190)},
		"back_face": "k",
	},
	"wolf": {
		"kind": "beast", "cell": Vector2i(32, 24), "head_cols": 6, "legs_top": 9,
		"grid": [
			"..gG...............",
			".gGGg..............",
			"gGGGGg.............",
			"GeGGGGGgggggggg....",
			"nGGGGGGGGGGGGGGGgt.",
			".wWGGGGGGGGGGGGGGgtt",
			"..wWgGGGGGGGGGGGGg.t",
			"....wGGgwwwwggGGg..t",
			"....gGg......gGg....",
			"....gG.g.....gG.g...",
			"....gG..g....gG..g..",
			"....gG..g....gG..g..",
			"...kkk.kk...kkk.kk..",
		],
		"colors": {"g": Color8(88, 86, 96), "G": Color8(136, 134, 144), "w": Color8(170, 168, 172),
			"W": Color8(206, 204, 206), "e": Color8(250, 210, 70), "n": Color8(30, 26, 30),
			"t": Color8(110, 108, 118), "k": Color8(60, 56, 62)},
	},
	"giant_rat": {
		"kind": "beast", "cell": Vector2i(24, 16), "head_cols": 4, "legs_top": 5,
		"grid": [
			"..rr...........",
			".rRRRrrrrr.....",
			"eRRRRRRRRRRr...",
			"nRRRRRRRRRRRr..",
			".pRRRRRRRRRRrtt",
			"..rR.rr..rR...t",
			"..pp.pp..pp....",
		],
		"colors": {"r": Color8(92, 70, 58), "R": Color8(130, 102, 82), "e": Color8(255, 70, 60),
			"n": Color8(220, 140, 150), "p": Color8(200, 130, 140), "t": Color8(196, 128, 140)},
	},
}

var _preview: Array[Image] = []


func _init() -> void:
	var only := Array(OS.get_cmdline_user_args())
	var want_preview := "preview" in only
	only.erase("preview")
	for id: String in SPECS:
		if not only.is_empty() and not id in only:
			continue
		var spec := _resolve(id)
		var sheet := _build_sheet(spec)
		var path: String = OUT_DIR + id + "_sheet.png"
		sheet.save_png(path)
		_write_scene(id, spec)
		print("gen_monsters: %s %s" % [path, sheet.get_size()])
		_preview.append(sheet)
	if want_preview:
		_write_preview()
	quit()


## A spec with "base" is a recolour of another one.
func _resolve(id: String) -> Dictionary:
	var s: Dictionary = SPECS[id].duplicate(true)
	if s.has("base"):
		var b: Dictionary = SPECS[s.base].duplicate(true)
		for k in s.get("colors_over", {}):
			b.colors[k] = s.colors_over[k]
		for k in s.get("ocolors_over", {}):
			b.ocolors[k] = s.ocolors_over[k]
		s = b
	s.id = id
	return s


# --- building a view (dict Vector2i -> Color) -------------------------------------------------

## The figure for one view (0 front, 1 back) as {pixels: {Vector2i: Color}, size, rig}.
func _figure(spec: Dictionary, row: int) -> Dictionary:
	var px := {}
	var rig := {}
	var size := Vector2i.ZERO
	match spec.kind:
		"humanoid":
			var tpl: Array = MEDIUM if spec.template == "medium" else SMALL
			rig = (MEDIUM_RIG if spec.template == "medium" else SMALL_RIG).duplicate()
			size = Vector2i(tpl[0].length(), tpl.size())
			for y in tpl.size():
				for x in tpl[y].length():
					var ch: String = tpl[y][x]
					if ch == ".":
						continue
					var key: String = PARTS.get(ch.to_upper(), "")
					if key == "":
						continue
					var c: Color = spec.colors[key]
					if ch != ch.to_upper():
						c = c.darkened(0.3)
					px[Vector2i(x, y)] = c
			var ov: Array = spec.get("overlay", [])
			for y in ov.size():
				for x in ov[y].length():
					var ch: String = ov[y][x]
					if ch != "." and spec.ocolors.has(ch):
						px[Vector2i(x, y)] = spec.ocolors[ch]
		_:
			var g: Array = spec.grid
			size = Vector2i(0, g.size())
			for y in g.size():
				size.x = maxi(size.x, g[y].length())
				for x in g[y].length():
					var ch: String = g[y][x]
					if ch != "." and spec.colors.has(ch):
						px[Vector2i(x, y)] = spec.colors[ch]
			rig = {"hand": spec.get("hand", Vector2i(size.x - 3, size.y / 2)), "legs_top": spec.get("legs_top", size.y),
				"head_rows": spec.get("head_rows", 6), "head_cols": spec.get("head_cols", 0)}
	if row == 1 and spec.kind != "beast":
		px = _back_view(px, size, rig, spec)
		rig.hand = Vector2i(size.x - 1 - rig.hand.x, rig.hand.y)
	return {pixels = px, size = size, rig = rig}


## Back 3/4 view: the front mirrored, the face (eyes, mouth) covered with the head's colour.
func _back_view(px: Dictionary, size: Vector2i, rig: Dictionary, spec: Dictionary) -> Dictionary:
	var face_cols: Array[Color] = []
	var cover: Color
	if spec.kind == "humanoid":
		face_cols = [spec.colors.eye, spec.colors.mouth, Color(spec.colors.mouth).darkened(0.3)]
		cover = Color(spec.colors.skin).darkened(0.15)
		if spec.has("back_face"):
			cover = spec.ocolors[spec.back_face]
	else:
		for k in ["e", "n", "m", "M"]:
			if spec.colors.has(k):
				face_cols.append(spec.colors[k])
		cover = spec.colors.get(spec.get("back_face", "H"), Color8(80, 80, 90))
	var o := {}
	for p: Vector2i in px:
		var c: Color = px[p]
		if p.y < rig.head_rows and c in face_cols:
			c = cover
		o[Vector2i(size.x - 1 - p.x, p.y)] = c
	return o


# --- poses ------------------------------------------------------------------------------------

func _frames(spec: Dictionary, fig: Dictionary, row: int) -> Array:
	var base: Dictionary = fig.pixels
	var rig: Dictionary = fig.rig
	var size: Vector2i = fig.size
	var f: Array = []
	match spec.kind:
		"beast":
			f.append(base)
			f.append(_shift_rows(base, 0, rig.legs_top - 1, Vector2i(0, 1)))      # breathe
			for i in 4:
				f.append(_beast_walk(base, rig, size, i))
			f.append(_shift(base, Vector2i(1, 0)))                                # wind-up
			f.append(_beast_bite(base, rig, size))                                # lunge + bite
			f.append(_shift(base, Vector2i(-1, 0)))
			f.append(_shift(base, Vector2i(2, -1)))                               # hurt
			f.append(base)
			for i in 6:
				f.append(_flop(base, size, i / 5.0))
		"float":
			f.append(base)
			f.append(_shift(base, Vector2i(0, -1)))
			for i in 4:
				f.append(_hem(_shift(base, Vector2i(0, [0, -1, -1, 0][i])), size, i))
			for ph in 3:
				f.append(_float_attack(base, rig, size, ph, row))
			f.append(_shift(base, Vector2i(1, -1)))
			f.append(base)
			for i in 6:
				f.append(_dissolve(base, size, i / 5.0, row))
		_:
			var armed := _armed(spec, base, rig, Vector2i.ZERO)
			f.append(armed)
			f.append(_armed(spec, _shift_rows(base, 0, rig.legs_top - 1, Vector2i(0, 1)), rig, Vector2i(0, 1)))  # breathe
			f.append(_armed(spec, _lift(base, rig, size, true), rig, Vector2i.ZERO))
			f.append(armed)
			f.append(_armed(spec, _lift(base, rig, size, false), rig, Vector2i.ZERO))
			f.append(armed)
			for ph in 3:
				f.append(_attack(spec, base, rig, size, ph, row))
			f.append(_shift(armed, Vector2i(1, -1)))
			f.append(armed)
			for i in 6:
				if spec.get("death", "topple") == "collapse":
					f.append(_collapse(base, size, rig, i / 5.0, row))
				else:
					f.append(_topple(armed if i == 0 else base, size, i / 5.0))
	return f


func _shift(f: Dictionary, d: Vector2i) -> Dictionary:
	var o := {}
	for p in f:
		o[p + d] = f[p]
	return o


func _shift_rows(f: Dictionary, y0: int, y1: int, d: Vector2i) -> Dictionary:
	var o := {}
	for p: Vector2i in f:
		if p.y >= y0 and p.y <= y1:
			continue
		o[p] = f[p]
	for p: Vector2i in f:
		if p.y >= y0 and p.y <= y1:
			o[p + d] = f[p]
	return o


## Lift one leg a pixel (the left or right half of the legs).
func _lift(f: Dictionary, rig: Dictionary, size: Vector2i, left: bool) -> Dictionary:
	var mid := size.x / 2
	var o := {}
	var moved := {}
	for p: Vector2i in f:
		var leg: bool = p.y >= rig.legs_top + 1 and ((p.x < mid) == left)
		if leg:
			moved[p + Vector2i(0, -1)] = f[p]
		else:
			o[p] = f[p]
	for p in moved:
		o[p] = moved[p]
	return o


## Attack: 0 = wind-up (lean back, weapon raised), 1 = strike (lean in, weapon swept down in front),
## 2 = recover. Both views face screen-left, so the blow always goes to -x. Claws: an arm reaches out.
func _attack(spec: Dictionary, f: Dictionary, rig: Dictionary, size: Vector2i, ph: int, _row: int) -> Dictionary:
	var lean: int = [1, -1, 0][ph]
	var o := {}
	for p: Vector2i in f:
		o[p + (Vector2i(lean, 0) if p.y < rig.legs_top else Vector2i.ZERO)] = f[p]
	var weapon: String = spec.get("weapon", "claws")
	if weapon == "claws":
		var reach: int = [0, 4, 1][ph]
		var left := size.x
		for p: Vector2i in f:
			if p.y == rig.hand.y - 2:
				left = mini(left, p.x)
		var arm: Color = f.get(rig.hand, Color8(150, 150, 150))
		var start := Vector2i(left + lean, rig.hand.y - 2 - (1 if ph == 1 else 0))
		for i in reach:
			o[start + Vector2i(-(i + 1), 0)] = arm
			o[start + Vector2i(-(i + 1), 1)] = arm.darkened(0.3)
		if reach > 0:
			var tip := start + Vector2i(-(reach + 1), 0)
			o[tip] = Color8(236, 232, 220)
			o[tip + Vector2i(0, 1)] = Color8(236, 232, 220)
			o[tip + Vector2i(-1, 1)] = Color8(236, 232, 220)
		return o
	var wc: Array = spec.get("weapon_colors", [Color8(206, 212, 226), Color8(110, 116, 134), Color8(110, 70, 40)])
	var hand: Vector2i = rig.hand + Vector2i(lean, [-3, -1, 0][ph])
	var dir: Vector2 = [Vector2(0.45, -1.0), Vector2(-1.0, 0.55), Vector2(-0.4, 1.0)][ph]
	_draw_weapon(o, weapon, hand, dir, wc)
	return o


## The weapon from the hand along `dir`: blade (sword, scimitar), club, morningstar.
func _draw_weapon(o: Dictionary, weapon: String, hand: Vector2i, dir: Vector2, wc: Array) -> void:
	var d := dir.normalized()
	var side := Vector2i(1, 0) if absf(d.y) > absf(d.x) else Vector2i(0, 1)
	o[hand] = wc[2]
	match weapon:
		"sword", "scimitar":
			var n := 9 if weapon == "sword" else 8
			for i in range(1, n + 1):
				var bend := 0.0
				if weapon == "scimitar":
					bend = (i / float(n)) * (i / float(n)) * 2.0
				var p := Vector2(hand) + d * i + Vector2(-d.y, d.x) * bend
				var c := Vector2i(roundi(p.x), roundi(p.y))
				o[c] = wc[0] if i < n else wc[1]
				if not o.has(c + side):
					o[c + side] = wc[1]
			var guard := hand + Vector2i(roundi(d.x), roundi(d.y))
			o[guard - side] = wc[2]
			o[guard + side * 2] = wc[2]
		"club":
			for i in range(1, 12):
				var p := Vector2(hand) + d * i
				var c := Vector2i(roundi(p.x), roundi(p.y))
				var w := 1 if i < 5 else 2
				var col := Color8(120, 84, 52) if i < 9 else Color8(150, 108, 70)
				o[c] = col
				for k in w:
					o[c + side * (k + 1)] = Color8(90, 62, 40)
		"morningstar":
			for i in range(1, 7):
				var p := Vector2(hand) + d * i
				o[Vector2i(roundi(p.x), roundi(p.y))] = Color8(110, 76, 48)
			var head := Vector2(hand) + d * 8
			var hc := Vector2i(roundi(head.x), roundi(head.y))
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					o[hc + Vector2i(dx, dy)] = Color8(120, 124, 140) if (dx + dy) % 2 == 0 else Color8(80, 84, 98)
			for sp in [Vector2i(0, -2), Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0)]:
				o[hc + sp] = Color8(200, 204, 216)


## Death (living): sag to the knees, then topple over onto the floor. t = 0..1.
func _topple(f: Dictionary, size: Vector2i, t: float) -> Dictionary:
	if t <= 0.0:
		return f
	var ang := 0.0
	var sink := 0
	if t < 0.4:
		sink = roundi(t / 0.4 * 3.0)
	else:
		sink = 3
		ang = (t - 0.4) / 0.6 * PI * 0.5
	var c := Vector2(size.x / 2.0, size.y * 0.6)
	var src := _shift_rows(f, 0, size.y - 5, Vector2i(0, sink))
	var o := {}
	var r := int(maxf(size.x, size.y)) + 2
	for y in range(-r, size.y + r):
		for x in range(-r, size.x + r):
			var q := Vector2(x, y) - c
			var s := q.rotated(-ang) + c
			var sp := Vector2i(roundi(s.x), roundi(s.y))
			if src.has(sp):
				o[Vector2i(x, y)] = (src[sp] as Color).darkened(0.12 * t)
	# rest it on the floor line
	var low := -999
	for p: Vector2i in o:
		low = maxi(low, p.y)
	return _shift(o, Vector2i(0, size.y - 1 - low))


## Death (undead): the body falls apart into a heap. t = 0..1.
func _collapse(f: Dictionary, size: Vector2i, rig: Dictionary, t: float, seed_value: int) -> Dictionary:
	if t <= 0.0:
		return f
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321 + seed_value
	var heap := {}
	var o := {}
	var keys := f.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i): return a.y > b.y)
	for p: Vector2i in keys:
		var tx := clampi(p.x + rng.randi_range(-3, 3), 1, size.x - 2)
		var h: int = heap.get(tx, 0)
		var ty := size.y - 1 - h / 3
		heap[tx] = h + 1
		var q := Vector2(lerpf(p.x, tx, t), lerpf(p.y, ty, t * t))
		o[Vector2i(roundi(q.x), roundi(q.y))] = (f[p] as Color).darkened(0.15 * t)
	return o


## Floating undead: the tattered hem flutters (walk).
func _hem(f: Dictionary, size: Vector2i, i: int) -> Dictionary:
	var o := {}
	for p: Vector2i in f:
		if p.y >= size.y - 4 and (p.x + i) % 3 == 0:
			o[p + Vector2i(1 if i % 2 == 0 else -1, 0)] = f[p]
		else:
			o[p] = f[p]
	return o


## Floating undead attack: the body swoops forward, the wispy hands reach.
func _float_attack(f: Dictionary, rig: Dictionary, size: Vector2i, ph: int, row: int) -> Dictionary:
	var front := true            # both views face screen-left
	var dx: int = [1, -2, 0][ph]
	var o := _shift(f, Vector2i(dx, [0, -1, 0][ph]))
	if ph == 1:
		var dirx := -1 if front else 1
		var c := Color8(220, 236, 250)
		var start := Vector2i(1 if front else size.x - 2, rig.hand.y - 1) + Vector2i(dx, -1)
		for i in 3:
			o[start + Vector2i(dirx * (i + 1), 0)] = c
	return o


## Floating undead death: the form thins out and drifts upward. t = 0..1.
func _dissolve(f: Dictionary, size: Vector2i, t: float, seed_value: int) -> Dictionary:
	if t <= 0.0:
		return f
	var rng := RandomNumberGenerator.new()
	rng.seed = 999 + seed_value
	var o := {}
	for p: Vector2i in f:
		if rng.randf() < t * 0.9:
			continue
		var up := roundi(rng.randf() * t * 6.0)
		o[p + Vector2i(rng.randi_range(-1, 1) if t > 0.4 else 0, -up)] = (f[p] as Color).lightened(0.3 * t)
	return o


## Beast walk: the legs (below legs_top) alternate front/back pairs.
func _beast_walk(f: Dictionary, rig: Dictionary, size: Vector2i, i: int) -> Dictionary:
	if i % 2 == 1:
		return _shift_rows(f, 0, rig.legs_top - 1, Vector2i(0, -1)) if i == 1 else f
	var o := {}
	var front_legs := i == 0
	for p: Vector2i in f:
		if p.y >= rig.legs_top:
			var is_front := p.x < size.x / 2
			if is_front == front_legs:
				o[p + Vector2i(-1, 0)] = f[p]
				continue
			else:
				o[p + Vector2i(1, 0)] = f[p]
				continue
		o[p] = f[p]
	return o


## Beast attack: lunge forward with the jaws open.
func _beast_bite(f: Dictionary, rig: Dictionary, size: Vector2i) -> Dictionary:
	var o := {}
	for p: Vector2i in f:
		var q := p + Vector2i(-2, 0) if p.y < rig.legs_top else p + Vector2i(-1, 0)
		o[q] = f[p]
	# open jaw: a dark gap and a tooth under the snout
	var hc: int = rig.head_cols
	for x in range(-2, hc - 3):
		var lowest := -1
		for y in rig.legs_top:
			if f.has(Vector2i(x + 2, y)):
				lowest = y
		if lowest > 0:
			o[Vector2i(x, lowest + 1)] = Color8(240, 236, 226) if x == -2 else Color8(60, 20, 24)
	return o


## Beast death: rolls onto its side (squashed, upside down).
func _flop(f: Dictionary, size: Vector2i, t: float) -> Dictionary:
	if t <= 0.0:
		return f
	var o := {}
	var k := 1.0 - 0.45 * t
	for p: Vector2i in f:
		var y := float(p.y)
		if t > 0.5:
			y = size.y - 1 - p.y            # on its back, legs up
		var q := Vector2i(p.x, roundi(size.y - 1 - (size.y - 1 - y) * k))
		o[q] = (f[p] as Color).darkened(0.15 * t)
	return o


# --- sheet ------------------------------------------------------------------------------------

func _build_sheet(spec: Dictionary) -> Image:
	var cell: Vector2i = spec.cell
	var sheet := Image.create_empty(cell.x * COLS, cell.y * 2, false, Image.FORMAT_RGBA8)
	for row in 2:
		var fig := _figure(spec, row)
		var frames := _frames(spec, fig, row)
		var size: Vector2i = fig.size
		# feet at the bottom centre of the cell, 2 px up (room for the outline)
		var origin := Vector2i((cell.x - size.x) / 2, cell.y - 2 - size.y)
		if spec.kind == "float":
			origin.y -= 4                   # hovers above its shadow
		for c in frames.size():
			var img := _to_image(frames[c], origin, cell, spec.get("alpha", 1.0))
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), Vector2i(c * cell.x, row * cell.y))
	return sheet


func _to_image(f: Dictionary, origin: Vector2i, cell: Vector2i, alpha: float) -> Image:
	var img := Image.create_empty(cell.x, cell.y, false, Image.FORMAT_RGBA8)
	for p: Vector2i in f:
		var q := p + origin
		if q.x >= 1 and q.y >= 1 and q.x < cell.x - 1 and q.y < cell.y - 1:
			var c: Color = f[p]
			c.a = alpha
			img.set_pixelv(q, c)
	var src := img.duplicate() as Image
	for y in cell.y:
		for x in cell.x:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < cell.x and p.y < cell.y and src.get_pixelv(p).a > 0.0:
					var oc := OUTLINE
					oc.a = alpha
					img.set_pixel(x, y, oc)
					break
	return img


# --- scenes -----------------------------------------------------------------------------------

func _write_scene(id: String, spec: Dictionary) -> void:
	var cell: Vector2i = spec.cell
	var stats: CreatureStats = load("res://data/monsters/%s.tres" % id)
	var fig := _figure(spec, 0)
	var size: Vector2i = fig.size
	var top := size.y + (4 if spec.kind == "float" else 0)
	var big := cell.x >= 40
	var beast: bool = spec.kind == "beast"
	var undead: bool = stats != null and stats.creature_type == "undead"
	var lines := PackedStringArray()
	lines.append('[gd_scene format=3]')
	lines.append('')
	lines.append('[ext_resource type="Script" path="res://scripts/actors/monster.gd" id="1_m"]')
	lines.append('[ext_resource type="Texture2D" path="res://assets/sprites/monsters/%s_sheet.png" id="2_t"]' % id)
	lines.append('')
	lines.append('[node name="%s" type="Node2D"]' % id.to_pascal_case())
	lines.append('script = ExtResource("1_m")')
	if big:
		lines.append('shadow_radius = 11.0')
		lines.append('shadow_alpha = 0.6')
		lines.append('body_height = 16.0')
	elif beast:
		lines.append('shadow_radius = %.1f' % (8.0 if cell.x >= 32 else 5.0))
		lines.append('body_height = %.1f' % (5.0 if cell.x >= 32 else 3.0))
	elif spec.kind == "float":
		lines.append('shadow_alpha = 0.3')
	lines.append('monster_id = "%s"' % id)
	lines.append('anims = {')
	lines.append('"attack": [0, 6, 3, 9.0, false],')
	lines.append('"death": [0, 11, 6, %s, false],' % ("8.0" if spec.kind == "float" else "10.0"))
	lines.append('"hurt": [0, 9, 2, 10.0, false],')
	lines.append('"idle": [0, 0, 2, %s, true],' % ("3.0" if spec.kind == "float" else "1.5"))
	lines.append('"walk": [0, 2, 4, %s, true]' % ("6.0" if spec.kind == "float" else "10.0"))
	lines.append('}')
	lines.append('back_row_offset = 1')
	if spec.kind == "float":
		lines.append('death_fade_delay = 0.0')
	elif spec.get("death", "topple") == "collapse":
		lines.append('vanish_on_death = false')
	else:
		lines.append('death_fade_delay = 1.5')
	lines.append('hp_bar_y = %.1f' % -(top + 4))
	lines.append('hp_bar_w = %d' % (20 if big else 16))
	if undead and spec.kind != "float":
		lines.append('hurt_sfx = "monster_hurt"')
	lines.append('')
	lines.append('[node name="Sprite" type="Sprite2D" parent="."]')
	if spec.get("unshaded", false):
		lines.append('material = SubResource("mat")')
	lines.append('texture = ExtResource("2_t")')
	lines.append('centered = false')
	lines.append('offset = Vector2(%d, %d)' % [-cell.x / 2, -(cell.y - 2)])
	lines.append('hframes = %d' % COLS)
	lines.append('vframes = 2')
	var text := "\n".join(lines) + "\n"
	if spec.get("unshaded", false):
		# a ghostly glow: the spectre ignores the dark (unshaded) and shows as drawn
		text = text.replace('[node name="%s"' % id.to_pascal_case(),
				'[sub_resource type="CanvasItemMaterial" id="mat"]\nlight_mode = 1\n\n[node name="%s"' % id.to_pascal_case())
	var fa := FileAccess.open(SCENE_DIR + id + ".tscn", FileAccess.WRITE)
	fa.store_string(text)
	fa.close()


func _write_preview() -> void:
	var path := OS.get_environment("HERRA_PREVIEW")
	if path == "":
		return
	var w := 0
	var h := 0
	for s in _preview:
		w = maxi(w, s.get_width())
		h += s.get_height() + 4
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color8(54, 52, 60))
	var y := 0
	for s in _preview:
		img.blit_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), Vector2i(0, y))
		y += s.get_height() + 4
	img.resize(w * 3, h * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	print("preview ", path)


## The figure holding its weapon at rest: hanging down beside it, tip forward a little.
func _armed(spec: Dictionary, f: Dictionary, rig: Dictionary, d: Vector2i) -> Dictionary:
	var weapon: String = spec.get("weapon", "claws")
	if weapon == "claws":
		return f
	var o := f.duplicate()
	var wc: Array = spec.get("weapon_colors", [Color8(206, 212, 226), Color8(110, 116, 134), Color8(110, 70, 40)])
	_draw_weapon(o, weapon, rig.hand + d, Vector2(-0.25, 1.0) if weapon != "club" else Vector2(0.35, 1.0), wc)
	return o
