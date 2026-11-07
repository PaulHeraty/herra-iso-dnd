extends SceneTree
## Hero face portraits, 32x32: assets/sprites/heroes/<hero>_portrait.png (HUD cards 1:1, the
## character sheet 2x). Drawn as text pixel grids in the mock-up's palette (make_iso_party.py `P`)
## plus a few skin / hair / metal shades.
##
## A grid row of 16 characters is the left half: it is mirrored for the right half, which is then
## shaded (highlights -> base colour, a 1px darker rim against the outline) so the light comes from
## the upper left like the sprites. A row of 32 characters is used as it is.
## Optional: `-- <preview_dir>` also writes an 8x preview sheet there.
##
## Run: Godot --headless --path . -s res://tools/godot/gen_portraits.gd

const OUT := "res://assets/sprites/heroes/%s_portrait.png"

const PAL := {
	"K": Color8(20, 16, 24),
	# skin: highlight, base, shade, deep shade; lips
	"a": Color8(248, 208, 172), "s": Color8(232, 180, 140), "S": Color8(190, 130, 100), "T": Color8(132, 82, 66),
	"l": Color8(166, 82, 72),
	# eyes
	"w": Color8(240, 240, 250), "i": Color8(70, 110, 180), "j": Color8(110, 70, 40),
	# hair brown
	"d": Color8(150, 98, 54), "c": Color8(104, 62, 30), "C": Color8(70, 40, 20),
	# steel
	"x": Color8(236, 238, 246), "m": Color8(200, 205, 215), "M": Color8(140, 145, 160), "n": Color8(90, 92, 110),
	# red, gold
	"r": Color8(180, 40, 40), "R": Color8(120, 24, 30), "y": Color8(230, 190, 70), "Y": Color8(170, 120, 40),
	# hood green
	"h": Color8(92, 128, 82), "g": Color8(60, 92, 62), "G": Color8(36, 56, 40), "H": Color8(24, 34, 28),
	# leather
	"b": Color8(120, 78, 44), "B": Color8(70, 44, 26),
	# robe white, blue
	"o": Color8(232, 226, 210), "O": Color8(168, 162, 160), "u": Color8(64, 96, 176), "U": Color8(38, 56, 112),
	# purple
	"q": Color8(154, 114, 214), "p": Color8(112, 70, 172), "P": Color8(66, 40, 110),
	# white beard
	"v": Color8(236, 236, 242), "V": Color8(176, 176, 192), "z": Color8(128, 128, 146),
}

## Right half: highlight -> base, then base -> shade where the outline is next to it.
const UNLIGHT := {"a": "s", "x": "m", "h": "g", "q": "p", "d": "c"}
const SHADE := {"s": "S", "m": "M", "g": "G", "p": "P", "c": "C", "v": "V", "o": "O", "u": "U",
	"b": "B", "r": "R", "y": "Y", "S": "T", "M": "n"}

const FIGHTER := [
	"................",
	"...........KKKKK",
	".........KKmmmmm",
	"........Kmxxmmmm",
	".......Kmxxmmmmm",
	"......Kmxmmmmmmm",
	"......Kmmmmmmmmm",
	".....KMmmmmmmmmm",
	".....KMmmmmmmmmm",
	".....KMMmmmmmmmm",
	".....KnMMMMMMMMM",
	".....KnMMnMMMnMM",
	".....KnmmKTTTTKm",
	".....KnmmKwiKSKm",
	".....KnmmKssssKm",
	".....KnmmKassSKm",
	".....KnmmKasssKm",
	".....KnmmKasssSK",
	".....KnmmKassssT",
	".....KnMmKsssccc",
	".....KnMMKcccsTT",
	".....KKnnKcccccc",
	"......KKnKCccccc",
	".......KKKCCcccc",
	"........KKCCCccc",
	".........KKKCCCC",
	"........KnMnMnMn",
	"....KKKKKnMnMnMn",
	"..KxxmmmmMKrrrrr",
	".KxmmmmmMMKrrrrr",
	"KxmmmmmMMnKrrrrr",
	"KmmmmmmMMnKrrrrr",
]

const ROGUE := [
	"................",
	"............KKKK",
	"..........KKhhhg",
	".........Khhgggg",
	"........Khhggggg",
	".......Khhgggggg",
	"......Khhggggggg",
	"......KhggggggGG",
	".....KhgggggGGHH",
	".....KhggggGHHHH",
	".....KhgggGHHTTT",
	"....KhgggGHTTTTT",
	"....KhggGHTTTTTS",
	"....KhggGHTSwwKS",
	"....KhggGHTSSSSS",
	"....KhggGHTSSSSS",
	"....KhggGKKKKKKK",
	"....KhggGKgGGGGG",
	"....KhggGKgGGGHG",
	"....KhgggKgGGHGG",
	"....KhgggGKgGGGG",
	"....KhgggGKgGGGH",
	"....KhggggGKgGGG",
	"....KhggggGKKgGG",
	"....KhgggggGKKKK",
	"...KhggggggGKbbb",
	"..KhgggggggGKbbb",
	"..KhggggggGGKbby",
	".KhggggggGGKbbbb",
	".KhgggggGGKbbbbb",
	"KhgggggGGKbbbbbb",
	"KhggggGGKbbbbbbb",
]

const CLERIC := [
	"................",
	"................",
	"..........KKKKKK",
	"........KKcddddd",
	".......Kcddddddc",
	"......Kcddcccccc",
	"......KcdcccCccc",
	".....KccccCcccCc",
	".....KcccCcsacCc",
	".....KccCsaassss",
	".....KcCsaasssss",
	".....KcSasCCCsss",
	".....KCSasssssss",
	"....KsSsasKKKKss",
	"....KTSsaswjKwss",
	"....KTSsasssssss",
	"....KsSsasssssSs",
	"....KKSsasssssST",
	".....KSsasssssss",
	"......KSssssssss",
	"......KSssssssll",
	".......KSssssssS",
	"........KSssssss",
	".........KKSssss",
	"...........KKKSs",
	"...........KTTTT",
	"...........KSSSS",
	".......KKKKuuKSS",
	"....KKKuuuuuuoKS",
	"..KKuuuuuuooooOy",
	".Kuuuuuuooooooyy",
	"KuuuuuuoooooooOy",
]

const MAGE := [
	"...............K",
	"..............Kq",
	".............Kqp",
	".............Kqp",
	"............Kqpp",
	"............Kqpp",
	"...........Kqppp",
	"...........Kqppp",
	"..........Kyyyyy",
	"..........KYYYYY",
	"..KKKKKKKqqqpppp",
	".KqqppppppppPPPP",
	".KKKPPPPPPPPPPPP",
	".....KvvTTTTTTTT",
	".....KvVSsvvvsss",
	".....KvVSswiKsss",
	".....KvVSsasssss",
	".....KvVSsasssSs",
	".....KvVSsasssSa",
	".....KvVvsssvvST",
	".....KvVvvvvvvvv",
	".....KvVvvVvvvvK",
	"....KvVvvvvvvvvv",
	"....KvVvvvvVvvvv",
	"....KvVvvvvvVvvv",
	".....KvVvvvvvVvv",
	".....KvVvvvvvvVv",
	"...KKKKvVvvvvvvv",
	".KKqqqpKvVvvvvvv",
	".KqqppppKvVvvvvv",
	"KqqpppppKKvVvvvv",
	"KqppppppPKKvVvvv",
]

const HEROES := {"fighter": FIGHTER, "rogue": ROGUE, "cleric": CLERIC, "mage": MAGE}


func _init() -> void:
	var preview_dir := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		preview_dir = args[0]
	var sheet := Image.create(4 * 34 * 8, 34 * 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(28, 26, 34))
	var n := 0
	for id in HEROES:
		var img := _build(id, HEROES[id])
		img.save_png(OUT % id)
		print("wrote ", OUT % id)
		var big := img.duplicate()
		big.resize(256, 256, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(big, Rect2i(0, 0, 256, 256), Vector2i(n * 272 + 8, 8))
		n += 1
	if preview_dir != "":
		sheet.save_png(preview_dir.path_join("portraits_preview.png"))
		print("preview in ", preview_dir)
	quit()


func _build(id: String, rows: Array) -> Image:
	var grid: Array = []          # 32 strings of 32 letters
	for y in 32:
		var r: String = rows[y] if y < rows.size() else ""
		if r.length() == 16:
			var right := ""
			for x in range(15, -1, -1):
				right += r[x]
			grid.append(_shade_right(r + right))
		elif r.length() == 32:
			grid.append(r)
		else:
			push_error("%s row %d: %d characters (need 16 or 32)" % [id, y, r.length()])
			grid.append(".".repeat(32))
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var ch: String = grid[y][x]
			if ch == ".":
				continue
			if not PAL.has(ch):
				push_error("%s (%d,%d): unknown colour '%s'" % [id, x, y, ch])
				continue
			img.set_pixel(x, y, PAL[ch])
	return img


func _shade_right(row: String) -> String:
	var out := row
	for x in range(16, 32):
		if UNLIGHT.has(out[x]):
			out[x] = UNLIGHT[out[x]]
	for x in range(16, 32):
		var nxt := "." if x == 31 else out[x + 1]
		if (nxt == "K" or nxt == ".") and SHADE.has(out[x]) and out[x] != "S" and out[x] != "M":
			out[x] = SHADE[out[x]]
	return out
