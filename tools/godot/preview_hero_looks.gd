extends SceneTree
## Preview of HeroLook outfits: one row per outfit (walk idle front + back, attack strike, shoot,
## cast glow, lying), 4x, with the effects sheet drawn over (a still of the overlay: flames etc. at
## full strength). Run: Godot --headless --path . -s res://tools/godot/preview_hero_looks.gd -- <out.png> [set]

const K := 4
const SETS := {
	"fighter": [
		["fighter", {}],
		["fighter", {"main": "longsword", "off": "shield", "armor": "chain_mail", "ranged": "handaxe"}],
		["fighter", {"main": "greatsword", "armor": "plate_armor", "ranged": "longbow"}],
		["fighter", {"main": "battleaxe", "off": "shield_plus1", "armor": "half_plate", "ranged": "heavy_crossbow"}],
		["fighter", {"main": "flame_tongue", "off": "shield_plus2", "armor": "plate_armor_plus1", "worn1": "cloak_protection"}],
		["fighter", {"main": "frost_brand", "armor": "plate_armor_plus2"}],
		["fighter", {"main": "warhammer_plus2", "off": "shield", "armor": "breastplate"}],
		["fighter", {"main": "greataxe", "armor": "scale_mail"}],
	],
	"others": [
		["rogue", {"main": "shortsword", "ranged": "shortbow", "armor": "leather_armor"}],
		["rogue", {"main": "rapier_plus1", "ranged": "longbow_plus2", "armor": "studded_leather_plus2", "worn1": "cloak_protection"}],
		["rogue", {"main": "scimitar", "ranged": "light_crossbow", "armor": "studded_leather"}],
		["cleric", {"main": "mace", "off": "shield", "armor": "chain_mail"}],
		["cleric", {"main": "mace_of_disruption", "off": "shield_plus1", "armor": "half_plate_plus1"}],
		["cleric", {"main": "morningstar", "armor": "breastplate_plus1", "worn1": "cloak_protection"}],
		["mage", {"main": "quarterstaff", "ranged": "light_crossbow"}],
		["mage", {"main": "dagger_plus2", "worn1": "cloak_protection"}],
	],
}
const ACTION_COLS := [1, 5, 9, 15]     # strike, shoot draw, cast glow, lying


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://looks.png"
	var set_name: String = args[1] if args.size() > 1 else "fighter"
	if set_name == "catalog":
		_catalog(out)
		return
	var rows: Array = SETS[set_name]
	var cols := 2 + ACTION_COLS.size()
	var img := Image.create_empty(cols * 32 * K, rows.size() * 32 * K, false, Image.FORMAT_RGBA8)
	img.fill(Color8(40, 38, 48))
	for r in rows.size():
		var s := HeroLook.sheets(rows[r][0], rows[r][1])
		var cells := []
		cells.append(_cell(s.walk, s.fx_walk, 0, 0, s))
		cells.append(_cell(s.walk, s.fx_walk, 0, 1, s))
		for c in ACTION_COLS:
			cells.append(_cell(s.action, s.fx_action, c, 0, s))
		for i in cells.size():
			var c: Image = cells[i]
			c.resize(32 * K, 32 * K, Image.INTERPOLATE_NEAREST)
			img.blend_rect(c, Rect2i(0, 0, 32 * K, 32 * K), Vector2i(i * 32 * K, r * 32 * K))
	img.save_png(out)
	print("wrote ", out)
	quit()


func _cell(tex: Texture2D, fx: Texture2D, col: int, row: int, s: Dictionary) -> Image:
	var src := tex.get_image().get_region(Rect2i(col * 32, row * 32, 32, 32))
	if fx == null:
		return src
	var f := fx.get_image().get_region(Rect2i(col * 32, row * 32, 32, 32))
	for y in 32:
		for x in 32:
			var p := f.get_pixel(x, y)
			if p.a == 0:
				continue
			var add := Color(0, 0, 0, 0)
			if p.r > 0 and s.main_fx.mode > 0:
				add += s.main_fx.color * p.r * 0.8
			if p.b > 0 and s.ranged_fx.mode > 0:
				add += s.ranged_fx.color * p.b * 0.8
			if p.g > 0:
				pass
			var base := src.get_pixel(x, y)
			var a := maxf(base.a, clampf(add.r + add.g + add.b, 0, 1))
			src.set_pixel(x, y, Color(minf(base.r * base.a + add.r, 1), minf(base.g * base.a + add.g, 1), minf(base.b * base.a + add.b, 1), a))
	return src


## Every armour (Fighter, idle) in one row, then every weapon (Fighter, mid-swing / shooting),
## then the magic weapons, each with its effect drawn over.
func _catalog(out: String) -> void:
	var armours := ["", "leather_armor", "studded_leather", "chain_shirt", "scale_mail", "chain_mail", "breastplate", "half_plate", "plate_armor",
		"studded_leather_plus1", "studded_leather_plus2", "chain_mail_plus1", "chain_mail_plus2", "breastplate_plus1", "breastplate_plus2",
		"half_plate_plus1", "half_plate_plus2", "plate_armor_plus1", "plate_armor_plus2"]
	var weapons := ["dagger", "shortsword", "scimitar", "rapier", "longsword", "greatsword", "handaxe", "battleaxe", "greataxe", "mace",
		"morningstar", "warhammer", "quarterstaff"]
	var ranged := ["shortbow", "longbow", "light_crossbow", "heavy_crossbow"]
	var magic := ["longsword_plus1", "longsword_plus2", "flame_tongue", "frost_brand", "mace_of_disruption", "warhammer_plus2", "longbow_plus2"]
	var lines := []
	var row := []
	for a in armours:
		row.append(["fighter", {"armor": a, "main": "longsword"} if a != "" else {"main": "longsword"}, "walk", 0])
	lines.append(row)
	row = []
	for w in weapons:
		row.append(["fighter", {"main": w, "armor": "chain_mail"}, "action", 2])
	for r in ranged:
		row.append(["fighter", {"main": "longsword", "ranged": r, "armor": "chain_mail"}, "action", 5])
	lines.append(row)
	row = []
	for m in magic:
		if m.begins_with("longbow"):
			row.append(["rogue", {"main": "shortsword", "ranged": m, "armor": "leather_armor"}, "action", 5])
		else:
			row.append(["fighter", {"main": m, "armor": "chain_mail"}, "walk", 0])
	for s in ["shield", "shield_plus1", "shield_plus2"]:
		row.append(["cleric", {"main": "mace", "off": s, "armor": "chain_mail"}, "walk", 0])
	row.append(["rogue", {"main": "shortsword", "armor": "leather_armor", "worn1": "cloak_protection"}, "walk", 0])
	row.append(["cleric", {"main": "mace", "armor": "chain_mail", "worn1": "cloak_protection"}, "walk", 1])
	lines.append(row)
	var w := 0
	for l in lines:
		w = maxi(w, l.size())
	var k := 3
	var img := Image.create_empty(w * 32 * k, lines.size() * 32 * k, false, Image.FORMAT_RGBA8)
	img.fill(Color8(40, 38, 48))
	for y in lines.size():
		for x in lines[y].size():
			var e: Array = lines[y][x]
			var s := HeroLook.sheets(e[0], e[1])
			var c: Image
			if e[2] == "walk":
				c = _cell(s.walk, s.fx_walk, 0, e[3], s)
			else:
				c = _cell(s.action, s.fx_action, e[3], 0, s)
			c.resize(32 * k, 32 * k, Image.INTERPOLATE_NEAREST)
			img.blend_rect(c, Rect2i(0, 0, 32 * k, 32 * k), Vector2i(x * 32 * k, y * 32 * k))
	img.save_png(out)
	print("wrote ", out)
	quit()
