class_name HeroLook
extends RefCounted
## A hero's sprite sheets built at runtime from what they wear and wield: the body drawing
## (HeroDrawings) with its armour restyled, a cloak, a shield, the main weapon (walk + action
## frames) and the ranged weapon (shoot frames). Plus an effects sheet in the same layout for the
## glow / flame / frost overlay (Hero draws it with hero_fx.gdshader). Cached per outfit.
##
## Same rig + poses as tools/godot/gen_hero_actions.gd (the static sheets the intro uses), but both
## sheets have 32x32 cells here (figure pixel (0,0) at ORIGIN, feet at (16, 30), offset (-16, -30)):
##   walk:   5 cols (idle, walk A, pass, walk B, pass) x 2 rows (front 3/4, back 3/4)
##   action: 16 cols = Hero.ACTION_ANIMS (attack 0-3, shoot 4-6, cast 7-10, hurt 11-12, down 13-15)
## Effects sheet channels: R = main weapon (strength: blade = 1, falling off around it), G = magic
## armour / shield (glint), B = ranged weapon.

const CELL := 32
const ORIGIN := Vector2i(9, 9)
const PAD := 3                     ## body grids are 20 wide: figure x -3..16 (a shield sticks out)
const GW := 20
const GH := 22
const WALK := [[0, 1], [0, 0], [1, 0], [0, 0]]

## Tag bits per pixel (-> the effects sheet).
const T_MAIN := 1
const T_GLINT := 2
const T_RANGED := 4

## Effect modes (hero_fx.gdshader): none, shimmer (+1), glow (+2), fire, frost, radiant.
enum Fx { NONE, SHIMMER, GLOW, FIRE, FROST, RADIANT }

## The mock-up palette (make_iso_party.py `P`).
const PAL := {
	"K": Color8(20, 16, 24), "w": Color8(240, 240, 250),
	"m": Color8(200, 205, 215), "M": Color8(140, 145, 160), "n": Color8(90, 92, 110),
	"r": Color8(180, 40, 40), "R": Color8(120, 24, 30),
	"s": Color8(232, 180, 140), "S": Color8(190, 130, 100),
	"b": Color8(120, 78, 44), "B": Color8(70, 44, 26), "y": Color8(230, 190, 70),
	"g": Color8(60, 92, 62), "G": Color8(36, 56, 40), "h": Color8(92, 128, 82),
	"l": Color8(122, 84, 52), "L": Color8(80, 54, 34),
	"o": Color8(232, 226, 210), "O": Color8(168, 162, 160), "u": Color8(64, 96, 176), "U": Color8(38, 56, 112),
	"c": Color8(104, 62, 30),
	"p": Color8(112, 70, 172), "P": Color8(66, 40, 110), "q": Color8(154, 114, 214),
	"e": Color8(226, 226, 232), "E": Color8(168, 168, 180), "f": Color8(255, 170, 60), "F": Color8(255, 242, 190),
	"x": Color8(236, 238, 246),
}

## Per hero: arm (sleeve) colour, cast style + glow, the armour pixels (palette key -> tier 1-3
## (light, mid, dark), rows), and per view the drawing's weapon / shield pixels to erase, shoulder,
## grip + idle direction, the free arm drawn where a shield was, and where a shield goes.
const RIG := {
	"fighter": {
		"arm": "n", "cast": "raise", "glow": ["h", "w"], "cloth": "gambeson",
		"armor": [{"keys": {"m": 1, "M": 2, "n": 3}, "rows": [7, 19]},
				{"keys": {"r": 1, "R": 2}, "rows": [8, 13], "part": "torso", "plate_only": true}],
		"front": {"erase": [[10, 0, 13, 15], [0, 8, 4, 14]], "shoulder": [9, 8], "grip": [11, 13], "dir": [0, -1],
				"offarm": {"col": "M", "x": 4, "rows": [8, 12]}, "shield_at": [0, 8]},
		"back": {"erase": [[0, 0, 2, 15], [9, 8, 13, 14]], "shoulder": [4, 8], "grip": [2, 13], "dir": [0, -1],
				"offarm": {"col": "M", "x": 9, "rows": [8, 12]}, "shield_at": [9, 8]},
	},
	"rogue": {
		"arm": "L", "cast": "raise", "glow": ["G", "h"], "cloth": "dark",
		"armor": [{"keys": {"l": 1, "L": 2, "n": 3}, "rows": [7, 19]}],
		"front": {"erase": [[0, 9, 1, 13]], "shoulder": [2, 8], "grip": [1, 9], "dir": [0, 1], "shield_at": [-2, 8]},
		"back": {"erase": [[0, 11, 1, 13]], "shoulder": [2, 8], "grip": [1, 11], "dir": [0, 1], "shield_at": [9, 8]},
	},
	"cleric": {
		"arm": "u", "cast": "symbol", "glow": ["y", "F"], "cloth": "keep",
		# sleeves + robe edges; the robe skirt shows the armour only when it covers the legs
		"armor": [{"keys": {"u": 1, "U": 2}, "rows": [7, 13], "part": "arms"},
				{"keys": {"o": 1, "O": 2}, "rows": [7, 10], "part": "torso", "plate_only": true},
				{"keys": {"o": 1, "O": 2}, "rows": [15, 19], "part": "legs", "metal_only": true}],
		"front": {"erase": [[10, 0, 13, 8], [11, 9, 13, 11]], "shoulder": [9, 8], "grip": [11, 11], "dir": [0, -1],
				"offhand": {"erase": [[1, 11, 1, 11]], "shoulder": [2, 8]}, "shield_at": [-1, 8]},
		"back": {"erase": [[0, 0, 3, 6], [0, 7, 2, 11]], "shoulder": [4, 8], "grip": [2, 11], "dir": [0, -1],
				"offhand": {"erase": [[12, 11, 12, 11]], "shoulder": [11, 8]}, "shield_at": [9, 8]},
	},
	"mage": {
		"arm": "p", "cast": "staff", "glow": ["f", "F"], "cloth": "keep",
		"armor": [],
		"front": {"erase": [[11, 0, 13, 15], [12, 16, 13, 21]], "shoulder": [9, 8], "grip": [12, 10], "dir": [0, -1], "hand_side": 1, "shield_at": [-2, 8]},
		"back": {"erase": [[0, 0, 2, 15], [0, 16, 1, 21]], "shoulder": [4, 8], "grip": [1, 10], "dir": [0, -1], "hand_side": -1, "shield_at": [9, 8]},
	},
}

## Poses (as gen_hero_actions.gd). g = grip [forward px from the body's centre column, row] or
## "idle"; d = weapon direction [forward, up]; lean = [head, body] px forward.
const SLASH := [
	{"g": [-2, 3], "d": [-1, 1], "lean": [-1, 0], "behind": [true, false]},
	{"g": [5, 9], "d": [1, -0.5], "lean": [1, 1], "behind": [false, true], "swoosh": true},
	{"g": [4, 12], "d": [1, -1], "lean": [1, 1], "behind": [false, true]},
	{"g": "idle", "dtilt": 0.5, "lean": [0, 0]},
]
const STAFF_SWING := [
	{"g": [-2, 7], "d": [-0.5, 1], "lean": [-1, 0], "behind": [true, false]},
	{"g": [3, 10], "d": [1, 0.5], "lean": [1, 1], "behind": [false, true], "swoosh": true},
	{"g": [3, 11], "d": [1, 0], "lean": [1, 1], "behind": [false, true]},
	{"g": "idle", "dtilt": 0.25, "lean": [0, 0]},
]
const HURT := [
	{"g": "idle", "shift": [-1, 1], "lean": [-2, -1], "dtilt": -0.5},
	{"g": "idle", "shift": [-1, 0], "lean": [-1, 0], "dtilt": -0.25},
]
## Throwing the ranged weapon (a handaxe): wind-up behind the head, release (it has flown), follow-through.
const THROW := [
	{"g": [-4, 1], "d": [-0.6, 1], "lean": [-1, 0], "behind": [true, false], "w": "ranged"},
	{"g": [7, 6], "d": [1, 0.3], "lean": [1, 1], "w": ""},
	{"g": [6, 10], "d": [1, -1], "lean": [1, 0], "w": ""},
]
## Action sheet columns: attack 0-3, shoot 4-6, cast 7-10, hurt 11-12, down 13-15, throw 16-18 (Hero.ACTION_ANIMS).
const COLS := 19

## Item base id -> how it is drawn. Swords may share a look, but each kind has its own shape.
const WEAPON_KIND := {
	"dagger": "dagger", "shortsword": "shortsword", "longsword": "longsword", "greatsword": "greatsword",
	"rapier": "rapier", "scimitar": "scimitar", "mace": "mace", "morningstar": "morningstar",
	"warhammer": "warhammer", "battleaxe": "battleaxe", "greataxe": "greataxe", "handaxe": "handaxe",
	"quarterstaff": "staff",
	"shortbow": "shortbow", "longbow": "longbow", "light_crossbow": "crossbow", "heavy_crossbow": "heavy_crossbow",
}
## Ranged kinds that are thrown (the throw frames) rather than shot.
static func is_thrown(kind: String) -> bool:
	return kind != "" and not kind in ["shortbow", "longbow", "crossbow", "heavy_crossbow"]


## How far the weapon reaches past the grip (spark point when raised, swoosh radius).
const REACH := {
	"dagger": 4, "shortsword": 6, "longsword": 10, "greatsword": 13, "rapier": 10, "scimitar": 8,
	"mace": 7, "morningstar": 8, "warhammer": 7, "battleaxe": 7, "greataxe": 9, "handaxe": 5, "staff": 8,
}

## Armour colour ramps [highlight, light, mid, dark].
const R_STEEL := [Color8(240, 242, 250), Color8(200, 205, 215), Color8(140, 145, 160), Color8(90, 92, 110)]
const R_CHAIN := [Color8(206, 210, 220), Color8(164, 168, 182), Color8(112, 116, 132), Color8(72, 74, 90)]
const R_LEATHER := [Color8(150, 104, 64), Color8(122, 84, 52), Color8(80, 54, 34), Color8(56, 36, 22)]
const R_BRONZE := [Color8(232, 198, 120), Color8(190, 150, 84), Color8(136, 102, 56), Color8(88, 62, 34)]
const R_GAMBESON := [Color8(190, 172, 140), Color8(156, 136, 108), Color8(116, 100, 80), Color8(80, 68, 56)]
const R_DARK := [Color8(112, 102, 112), Color8(86, 78, 88), Color8(62, 56, 66), Color8(42, 38, 46)]
const R_MITHRAL := [Color8(252, 254, 255), Color8(216, 226, 244), Color8(156, 172, 204), Color8(98, 110, 142)]
const R_ELVEN := [Color8(246, 255, 250), Color8(200, 232, 216), Color8(136, 178, 164), Color8(84, 118, 110)]
const R_DARK_LEATHER := [Color8(104, 80, 72), Color8(74, 56, 52), Color8(50, 38, 38), Color8(32, 24, 26)]
const R_SHADOW_LEATHER := [Color8(76, 70, 94), Color8(52, 48, 66), Color8(36, 32, 46), Color8(24, 22, 32)]
const R_BURNISHED := [Color8(255, 238, 196), Color8(226, 198, 148), Color8(168, 140, 100), Color8(110, 90, 64)]
const R_SILVERED := [Color8(255, 255, 255), Color8(224, 230, 242), Color8(170, 178, 200), Color8(112, 118, 142)]
const R_ROYAL := [Color8(150, 180, 246), Color8(84, 116, 206), Color8(50, 72, 154), Color8(30, 42, 98)]
const R_FUR := [Color8(255, 255, 255), Color8(232, 232, 236), Color8(186, 186, 196), Color8(132, 132, 144)]
const R_BLACK := [Color8(128, 126, 146), Color8(70, 68, 84), Color8(44, 42, 54), Color8(26, 24, 32)]
const R_WHITE := [Color8(255, 255, 255), Color8(238, 240, 248), Color8(192, 198, 216), Color8(132, 140, 162)]
const R_CLOAK := [Color8(110, 140, 210), Color8(64, 96, 176), Color8(44, 66, 136), Color8(28, 40, 90)]
const STUD_STEEL := Color8(176, 178, 190)

## Armour id -> parts (torso / arms / legs: [pattern, ramp]; "cloth" = the hero's own clothes),
## studs, glint (magic: the effects overlay sweeps a gleam over it) + its colour.
const ARMOR := {
	"leather_armor": {"torso": ["smooth", R_LEATHER], "arms": ["smooth", R_LEATHER], "legs": ["smooth", R_LEATHER]},
	"studded_leather": {"torso": ["studded", R_LEATHER], "arms": ["studded", R_LEATHER], "legs": ["smooth", R_LEATHER]},
	"chain_shirt": {"torso": ["chain", R_CHAIN], "arms": ["chain", R_CHAIN], "legs": ["cloth"]},
	"scale_mail": {"torso": ["scale", R_BRONZE], "arms": ["scale", R_BRONZE], "legs": ["chain", R_CHAIN]},
	"chain_mail": {"torso": ["chain", R_CHAIN], "arms": ["chain", R_CHAIN], "legs": ["chain", R_CHAIN]},
	"breastplate": {"torso": ["plate", R_STEEL], "arms": ["smooth", R_LEATHER], "legs": ["smooth", R_LEATHER]},
	"half_plate": {"torso": ["plate", R_STEEL], "arms": ["lames", R_STEEL], "legs": ["chain", R_CHAIN]},
	"plate_armor": {"torso": ["plate", R_STEEL], "arms": ["lames", R_STEEL], "legs": ["lames", R_STEEL]},
	# magic: the plain armour recoloured as its description says
	"chain_mail_plus1": {"base": "chain_mail", "ramp": R_MITHRAL, "glint": 0.6, "glint_col": Color(0.75, 0.88, 1.0)},
	"chain_mail_plus2": {"base": "chain_mail", "ramp": R_ELVEN, "glint": 0.9, "glint_col": Color(0.8, 1.0, 0.9)},
	"studded_leather_plus1": {"base": "studded_leather", "ramp": R_DARK_LEATHER, "stud": Color8(226, 230, 240), "glint": 0.5, "glint_col": Color(0.85, 0.85, 1.0)},
	"studded_leather_plus2": {"base": "studded_leather", "ramp": R_SHADOW_LEATHER, "stud": Color8(170, 220, 255), "glint": 0.8, "glint_col": Color(0.6, 0.85, 1.0)},
	"breastplate_plus1": {"base": "breastplate", "metal": R_BURNISHED, "glint": 0.6, "glint_col": Color(1.0, 0.85, 0.55)},
	"breastplate_plus2": {"base": "breastplate", "metal": R_SILVERED, "glint": 0.9, "glint_col": Color(0.8, 0.9, 1.0)},
	"half_plate_plus1": {"base": "half_plate", "metal": R_ROYAL, "glint": 0.6, "glint_col": Color(0.6, 0.75, 1.0)},
	"half_plate_plus2": {"base": "half_plate", "legs": ["smooth", R_FUR], "glint": 0.9, "glint_col": Color(0.85, 0.92, 1.0)},
	"plate_armor_plus1": {"base": "plate_armor", "metal": R_BLACK, "glint": 0.6, "glint_col": Color(1.0, 0.55, 0.4)},
	"plate_armor_plus2": {"base": "plate_armor", "metal": R_WHITE, "glint": 0.9, "glint_col": Color(0.7, 0.9, 1.0)},
}

## Shields, front face (5 wide; M/m/x = rim/steel). The back view shows the wooden inside.
const SHIELDS := {
	"shield": ["MMMMn", "MbbbM", "MbybM", "MyyyM", "MbybM", "MbbbM", ".MbM.", "..M.."],
	"shield_plus1": ["mmmmn", "mMyMn", "myFyn", "mMyMn", "mMMMn", "mMMMn", ".mMn.", "..n.."],
	"shield_plus2": ["MMMMn", "McocM", "MocoM", "MoooM", "MoOoM", "MoOOM", ".MOM.", ".MOM.", "..M.."],
}

static var _cache := {}


# --- what to draw -------------------------------------------------------------------------------

## The look of `hero` ("fighter"...) in `equipment` (slot -> item id): plain values only.
static func look_for(hero: String, equipment: Dictionary) -> Dictionary:
	var look := {"hero": hero, "main": "", "main_id": "", "ranged": "", "ranged_id": "",
			"armor": "", "shield": "", "cloak": false}
	var m := _item(equipment, "main")
	if m:
		look.main = WEAPON_KIND.get(m.base_id(), "")
		look.main_id = m.id
	var r := _item(equipment, "ranged")
	if r:
		look.ranged = WEAPON_KIND.get(r.base_id(), "")
		look.ranged_id = r.id
	var a := _item(equipment, "armor")
	if a:
		look.armor = a.id
	var s := _item(equipment, "off")
	if s and s.kind == ItemData.Kind.SHIELD:
		look.shield = s.id if SHIELDS.has(s.id) else "shield"
	for slot in ["worn1", "worn2"]:
		var w := _item(equipment, slot)
		if w and w.base_id().begins_with("cloak"):
			look.cloak = true
	return look


static func key_of(look: Dictionary) -> String:
	return "%s|%s|%s|%s|%s|%s" % [look.hero, look.main_id, look.ranged_id, look.armor, look.shield, look.cloak]


## Effect for a weapon id: {mode, color (overlay), blade (tint for the steel, or null), light}.
static func weapon_fx(item_id: String) -> Dictionary:
	match item_id:
		"flame_tongue":
			return {"mode": Fx.FIRE, "color": Color(1.0, 0.55, 0.15), "blade": Color8(236, 128, 56), "light": Color(1.0, 0.6, 0.3)}
		"frost_brand":
			return {"mode": Fx.FROST, "color": Color(0.6, 0.88, 1.0), "blade": Color8(204, 242, 255), "light": Color(0.55, 0.8, 1.0)}
		"mace_of_disruption":
			return {"mode": Fx.RADIANT, "color": Color(1.0, 0.88, 0.45), "blade": Color8(250, 232, 170), "light": Color(1.0, 0.85, 0.5)}
	if item_id.ends_with("_plus2"):
		return {"mode": Fx.GLOW, "color": Color(0.45, 0.7, 1.0), "blade": Color8(186, 218, 255), "light": null}
	if item_id.ends_with("_plus1"):
		return {"mode": Fx.SHIMMER, "color": Color(0.7, 0.85, 1.0), "blade": Color8(212, 228, 255), "light": null}
	return {"mode": Fx.NONE, "color": Color.BLACK, "blade": null, "light": null}


## Glint strength + colour of the armour and shield (0 = not magic).
static func glint_of(look: Dictionary) -> Dictionary:
	var g := 0.0
	var col := Color(0.8, 0.9, 1.0)
	if look.armor != "" and ARMOR.has(look.armor):
		g = ARMOR[look.armor].get("glint", 0.0)
		col = ARMOR[look.armor].get("glint_col", col)
	if look.shield.ends_with("_plus1") or look.shield.ends_with("_plus2"):
		g = maxf(g, 0.6 if look.shield.ends_with("_plus1") else 0.9)
	return {"strength": g, "color": col}


## The sheets for this hero + equipment (cached): {walk, action, fx_walk, fx_action (null when
## nothing glows), main_fx, ranged_fx, glint}.
static func sheets(hero: String, equipment: Dictionary) -> Dictionary:
	var look := look_for(hero, equipment)
	var key := key_of(look)
	if _cache.has(key):
		return _cache[key]
	var b := _Builder.new(look)
	var out := b.build()
	_cache[key] = out
	return out


static func _item(eq: Dictionary, slot: String) -> ItemData:
	return ItemData.get_item(eq[slot]) if eq.has(slot) else null


# --- the builder --------------------------------------------------------------------------------

## A frame in progress: 32x32 colours + tags + soft effect pixels (no outline).
class Frame:
	var col: Array = []      # [y][x] -> Color (a = 0: empty)
	var tag: Array = []      # [y][x] -> int
	var fx := {}             # Vector2i -> Color

	func _init() -> void:
		for y in 32:
			var r := []
			r.resize(32)
			r.fill(Color(0, 0, 0, 0))
			col.append(r)
			var t := []
			t.resize(32)
			t.fill(0)
			tag.append(t)

	func put(p: Vector2i, c: Color, only_empty := false, t := 0) -> void:
		if p.x < 0 or p.y < 0 or p.x >= 32 or p.y >= 32:
			return
		if only_empty and col[p.y][p.x].a > 0:
			return
		col[p.y][p.x] = c
		tag[p.y][p.x] = t

	func empty(p: Vector2i) -> bool:
		if p.x < 0 or p.y < 0 or p.x >= 32 or p.y >= 32:
			return true
		return col[p.y][p.x].a == 0


class _Builder:
	var look: Dictionary
	var hero: String
	var rig: Dictionary
	var draw: Dictionary
	var main_fx: Dictionary
	var ranged_fx: Dictionary
	var glint: Dictionary
	## the weapon being drawn: its effect (blade tint) and tag (T_MAIN, or T_RANGED for a thrown one)
	var _wfx: Dictionary
	var _wtag := T_MAIN

	func _init(l: Dictionary) -> void:
		look = l
		hero = l.hero
		rig = RIG[hero]
		draw = HeroDrawings.HEROES[hero]
		main_fx = HeroLook.weapon_fx(l.main_id)
		ranged_fx = HeroLook.weapon_fx(l.ranged_id)
		glint = HeroLook.glint_of(l)
		_wfx = main_fx

	func build() -> Dictionary:
		var walk := Image.create_empty(CELL * 5, CELL * 2, false, Image.FORMAT_RGBA8)
		var action := Image.create_empty(CELL * COLS, CELL * 2, false, Image.FORMAT_RGBA8)
		var any_fx: bool = main_fx.mode != Fx.NONE or ranged_fx.mode != Fx.NONE or glint.strength > 0.0
		var fx_walk := Image.create_empty(CELL * 5, CELL * 2, false, Image.FORMAT_RGBA8) if any_fx else null
		var fx_action := Image.create_empty(CELL * COLS, CELL * 2, false, Image.FORMAT_RGBA8) if any_fx else null
		var views := ["front", "back"]
		for row in 2:
			var view: String = views[row]
			var still := _body(view, 0, 0)
			var cx := _centre_x(still)
			# walk: idle + 4 steps, weapon at rest
			var lifts := [[0, 0]] + WALK
			for col in 5:
				var body := still if col == 0 else _body(view, lifts[col][0], lifts[col][1])
				var f := _pose(view, body, cx, {"g": "idle"})
				_put_frame(f, walk, fx_walk, col, row)
			# actions
			var frames := _actions(view, still, cx)
			for col in frames.size():
				_put_frame(frames[col], action, fx_action, col, row)
		return {
			"walk": ImageTexture.create_from_image(walk),
			"action": ImageTexture.create_from_image(action),
			"fx_walk": ImageTexture.create_from_image(fx_walk) if fx_walk else null,
			"fx_action": ImageTexture.create_from_image(fx_action) if fx_action else null,
			"main_fx": main_fx, "ranged_fx": ranged_fx, "glint": glint,
		}

	func _put_frame(f: Frame, sheet: Image, fx_sheet: Image, col: int, row: int) -> void:
		var at := Vector2i(col * CELL, row * CELL)
		sheet.blit_rect(_render(f), Rect2i(0, 0, CELL, CELL), at)
		if fx_sheet:
			fx_sheet.blit_rect(_render_fx(f), Rect2i(0, 0, CELL, CELL), at)

	func _actions(view: String, base: Dictionary, cx: int) -> Array[Frame]:
		var out: Array[Frame] = []
		var style: Array = STAFF_SWING if look.main == "staff" else SLASH
		for i in 4:
			var p: Dictionary = style[i]
			var f := _pose(view, base, cx, p)
			if p.get("swoosh", false):
				_swoosh(f, cx, style[0], p)
			out.append(f)
		for i in 3:
			match look.ranged:
				"shortbow", "longbow":
					out.append(_bow(view, base, cx, i))
				"crossbow", "heavy_crossbow":
					out.append(_crossbow(view, base, cx, i))
				_:
					out.append(out[0])
		for i in 4:
			out.append(_cast(view, base, cx, i))
		for p in HURT:
			out.append(_pose(view, base, cx, p))
		out.append(_kneel(view, base, cx, 1))
		out.append(_kneel(view, base, cx, 2))
		out.append(_lying(base))
		# throw (a handaxe in the ranged slot); others: the attack frames
		for i in 3:
			out.append(_pose(view, base, cx, THROW[i]) if HeroLook.is_thrown(look.ranged) else out[i])
		return out

	# --- the body ---------------------------------------------------------------------------

	## The body for one view with the legs lifted (walk): {col: [y][gx] Color, tag: [y][gx] int}
	## (gx = figure x + PAD), weapon and drawn shield erased, armour restyled, cloak and shield on.
	func _body(view: String, lift_l: int, lift_r: int) -> Dictionary:
		var v: Dictionary = draw[view]
		var rv: Dictionary = rig[view]
		var rows := _rows(v, lift_l, lift_r)
		for r in rv["erase"]:
			for y in range(r[1], r[3] + 1):
				var s: String = rows[y]
				for x in range(r[0], r[2] + 1):
					s[x] = "."
				rows[y] = s
		if rv.has("offarm") and look.shield == "":
			var oa: Dictionary = rv["offarm"]
			for y in range(oa["rows"][0], oa["rows"][1] + 1):
				var s: String = rows[y]
				s[oa["x"]] = oa["col"]
				rows[y] = s
			var hs: String = rows[oa["rows"][1] + 1]
			hs[oa["x"]] = "s"
			rows[oa["rows"][1] + 1] = hs
		var col := []
		var tag := []
		for y in GH:
			var cr := []
			cr.resize(GW)
			cr.fill(Color(0, 0, 0, 0))
			col.append(cr)
			var tr := []
			tr.resize(GW)
			tr.fill(0)
			tag.append(tr)
		var spec := _armor_spec()
		var metal_legs := _metal(spec.get("legs", ["cloth"]))
		# armour pixels per row (for the arm / torso split)
		var parts := {}             # Vector2i(x, y) -> [part, tier]
		var lo := {}
		var hi := {}
		for grp in rig["armor"]:
			if grp.get("metal_only", false) and not metal_legs:
				continue
			if grp.get("plate_only", false) and spec.get("torso", ["cloth"])[0] != "plate":
				continue
			var keys: Dictionary = grp["keys"]
			for y in range(grp["rows"][0], grp["rows"][1] + 1):
				for x in 14:
					var c: String = rows[y][x]
					if keys.has(c):
						parts[Vector2i(x, y)] = [grp.get("part", ""), keys[c]]
						lo[y] = mini(lo.get(y, 99), x)
						hi[y] = maxi(hi.get(y, -1), x)
		for y in GH:
			for x in 14:
				var c: String = rows[y][x]
				if c == ".":
					continue
				var p := Vector2i(x, y)
				var colour: Color = PAL[c]
				var t := 0
				if parts.has(p):
					var part: String = parts[p][0]
					if part == "":
						if y >= 16:
							part = "legs"
						elif y >= 8 and y <= 14 and (x <= lo[y] or x >= hi[y]):
							part = "arms"
						else:
							part = "torso"
					var top := not parts.has(p + Vector2i(0, -1))
					var left := not parts.has(p + Vector2i(-1, 0))
					var res := _armor_px(spec, part, parts[p][1], c, x, y, top, left)
					colour = res[0]
					if res[1] and glint.strength > 0.0:
						t = T_GLINT
				col[y][x + PAD] = colour
				tag[y][x + PAD] = t
		var body := {"col": col, "tag": tag}
		if look.cloak:
			_cloak(body, view, rows)
		if look.shield != "":
			_shield(body, view)
		return body

	## 22 strings of 14: the legs (each leg lifted by its amount, robe hem sway) + the upper body.
	func _rows(v: Dictionary, lift_l: int, lift_r: int) -> Array:
		var rows := []
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
				row += _px(legs, i + lift, x)
			if i == sway_row and lift_l != lift_r:
				var s := 1 if lift_r > lift_l else -1
				var swayed := ""
				for x in 14:
					var inside: bool = x >= lr[0] and x <= rr[1]
					var from: int = x - s
					swayed += (_px(legs, i, from) if from >= lr[0] and from <= rr[1] else ".") if inside else row[x]
				row = swayed
			rows[16 + i] = row
		var upper: Array = v["upper"]
		for i in upper.size():
			var merged := ""
			for x in 14:
				var c: String = upper[i][x] if x < upper[i].length() else "."
				merged += c if c != "." else rows[i][x]
			rows[i] = merged
		return rows

	func _px(grid: Array, y: int, x: int) -> String:
		if y < 0 or y >= grid.size() or x < 0 or x >= grid[y].length():
			return "."
		return grid[y][x]

	## The armour's parts with magic recolouring resolved.
	func _armor_spec() -> Dictionary:
		var id: String = look.armor
		if id == "" or not ARMOR.has(id):
			return {"torso": ["cloth"], "arms": ["cloth"], "legs": ["cloth"]}
		var a: Dictionary = ARMOR[id]
		if not a.has("base"):
			return a
		var out: Dictionary = (ARMOR[a["base"]] as Dictionary).duplicate(true)
		for part in ["torso", "arms", "legs"]:
			var pr: Array = out[part]
			if pr[0] == "cloth":
				continue
			if a.has("ramp"):
				pr[1] = a["ramp"]
			elif a.has("metal") and _metal(pr):
				pr[1] = a["metal"]
		if a.has("legs"):
			out["legs"] = a["legs"]
		if a.has("stud"):
			out["stud"] = a["stud"]
		return out

	func _metal(pr: Array) -> bool:
		return pr[0] in ["chain", "scale", "plate", "lames"]

	## One armour pixel: [colour, glints].
	func _armor_px(spec: Dictionary, part: String, tier: int, key: String, x: int, y: int, top: bool, left: bool) -> Array:
		var pr: Array = spec.get(part, ["cloth"])
		var pattern: String = pr[0]
		if pattern == "cloth":
			match rig["cloth"]:
				"gambeson":
					return [_ramp(R_GAMBESON, tier - (1 if top and tier == 1 else 0)), false]
				"dark":
					return [_ramp(R_DARK, tier), false]
			return [PAL[key], false]
		var ramp: Array = pr[1]
		var t := tier
		match pattern:
			"smooth":
				if top and t == 1:
					t = 0
			"studded":
				if x % 3 == 1 and y % 3 == 1 and t <= 2:
					return [spec.get("stud", STUD_STEEL), true]
			"chain":
				if t < 3:
					t += (x + y) & 1
			"scale":
				if y % 2 == 0 and (x + (y >> 1)) % 2 == 0 and t < 3:
					t += 1
				elif top and t == 1:
					t = 0
			"plate":
				if t == 1 and (top or left):
					t = 0
			"lames":
				if y % 3 == 0 and t < 3:
					t += 1
				elif t == 1 and (top or left):
					t = 0
		return [_ramp(ramp, t), true]

	func _ramp(r: Array, t: int) -> Color:
		return r[clampi(t, 0, 3)]

	## Cloak of Protection: blue wool. The Rogue's own cloak + hood turn blue; the others get one:
	## a drape at the sides behind the body (front view), over the back (back view), silver clasp.
	func _cloak(body: Dictionary, view: String, rows: Array) -> void:
		var col: Array = body["col"]
		if hero == "rogue":
			var map := {"h": 0, "g": 1, "G": 2}
			for y in GH:
				for x in 14:
					var c: String = rows[y][x]
					if map.has(c):
						col[y][x + PAD] = R_CLOAK[map[c]]
			return
		for y in range(7, 20):
			var lo := 99
			var hi := -1
			for gx in GW:
				if col[y][gx].a > 0:
					lo = mini(lo, gx)
					hi = maxi(hi, gx)
			if hi < 0:
				continue
			if view == "front":
				var flare := 2 if y >= 15 else 1
				for k in range(1, flare + 1):
					for gx in [lo - k, hi + k]:
						if gx >= 0 and gx < GW and col[y][gx].a == 0:
							col[y][gx] = R_CLOAK[2 if k == 1 else 3]
			else:
				for gx in range(lo + 1, hi):
					if col[y][gx].a == 0:
						continue
					var shade := 1 if (gx - lo) % 3 != 0 else 2
					if y >= 17:
						shade += 1
					col[y][gx] = R_CLOAK[shade]
					body["tag"][y][gx] = 0
				if y >= 15:
					for gx in [lo - 1, hi + 1]:
						if gx >= 0 and gx < GW and col[y][gx].a == 0:
							col[y][gx] = R_CLOAK[3]
		# clasp at the collar
		var cx := _centre_x(body)
		var clasp := Vector2i(cx - 2 + PAD, 7) if view == "front" else Vector2i(cx + PAD, 7)
		if col[clasp.y][clasp.x].a > 0:
			col[clasp.y][clasp.x] = PAL["x"]

	## The shield on the free arm (front face in the front view, the wooden inside from the back).
	func _shield(body: Dictionary, view: String) -> void:
		var grid: Array = SHIELDS.get(look.shield, SHIELDS["shield"])
		var at: Array = rig[view]["shield_at"]
		var magic: bool = look.shield != "shield"
		for y in grid.size():
			var row: String = grid[y]
			for x in row.length():
				var c := row[x]
				if c == ".":
					continue
				if view == "back" and not c in ["M", "m", "x", "n"]:
					c = "B" if x == 2 and y in [2, 3] else "b"
				var gx: int = at[0] + x + PAD
				var gy: int = at[1] + y
				if gx < 0 or gx >= GW or gy >= GH:
					continue
				body["col"][gy][gx] = PAL[c] if PAL.has(c) else PAL["M"]
				body["tag"][gy][gx] = T_GLINT if magic and glint.strength > 0.0 and view == "front" else 0

	# --- poses ------------------------------------------------------------------------------

	func _pose(view: String, base: Dictionary, cx: int, p: Dictionary, drop := 0) -> Frame:
		var v: Dictionary = rig[view]
		var fwd := -1
		var lean: Array = p.get("lean", [0, 0])
		var shift: Array = p.get("shift", [0, 0])
		var f := Frame.new()
		var sh := Vector2i(shift[0] * fwd, shift[1])
		_blit_body(f, base, lean, sh, drop)
		var shoulder := _v(v["shoulder"]) + Vector2i(lean[1] * fwd, drop) + sh
		var grip: Vector2i
		var dir: Vector2
		if typeof(p["g"]) == TYPE_STRING:
			grip = _v(v["grip"]) + Vector2i(lean[1] * fwd, 0) + sh
			dir = Vector2(v["dir"][0], v["dir"][1])
			dir.x += p.get("dtilt", 0.0) * fwd
		else:
			grip = Vector2i(cx + int(p["g"][0]) * fwd, int(p["g"][1]) + drop) + sh
			dir = Vector2(p["d"][0] * fwd, -p["d"][1])
		var behind: bool = p.get("behind", [false, false])[0 if view == "front" else 1]
		_arm(f, shoulder, grip + _hand_offset(v, dir), PAL[rig["arm"]])
		var w: String = p.get("w", "main")
		if w == "ranged":
			_wfx = ranged_fx
			_wtag = T_RANGED
		_weapon(f, look.main if w == "main" else (look.ranged if w == "ranged" else ""), grip, dir, behind)
		_wfx = main_fx
		_wtag = T_MAIN
		_hand(f, v, grip, dir)
		return f

	func _blit_body(f: Frame, body: Dictionary, lean: Array, sh: Vector2i, drop: int) -> void:
		var fwd := -1
		var col: Array = body["col"]
		var tag: Array = body["tag"]
		for y in GH:
			var yy := y
			if drop > 0:
				if y == 17 or y == 18:
					if drop >= 2 or y == 17:
						continue
				if y < 17:
					yy = y + (2 if drop >= 2 else 1)
			var dx := 0
			if y <= 6:
				dx = lean[0] * fwd
			elif y <= 15:
				dx = lean[1] * fwd
			for gx in GW:
				var c: Color = col[y][gx]
				if c.a > 0:
					f.put(ORIGIN + Vector2i(gx - PAD + dx, yy) + sh, c, false, tag[y][gx])

	func _hand_offset(v: Dictionary, dir: Vector2) -> Vector2i:
		var s: int = v.get("hand_side", 0)
		return Vector2i.ZERO if s == 0 else _perp(dir) * s

	func _hand(f: Frame, v: Dictionary, grip: Vector2i, dir: Vector2) -> void:
		var s: int = v.get("hand_side", 0)
		if s == 0 or look.main != "staff":
			f.put(ORIGIN + grip, PAL["s"])
			return
		var h := grip + _perp(dir) * s
		f.put(ORIGIN + h, PAL["s"])
		f.put(ORIGIN + h - _step(dir, 1), PAL["s"])

	func _arm(f: Frame, a: Vector2i, b: Vector2i, col: Color) -> void:
		for p in _line(a, b):
			if p != b:
				f.put(ORIGIN + p, col, true)

	# --- weapons ----------------------------------------------------------------------------

	## The main weapon along `dir` from the grip. Blade / head pixels carry T_MAIN.
	func _weapon(f: Frame, kind: String, g: Vector2i, dir: Vector2, behind: bool) -> void:
		if kind == "":
			return
		var tint = _wfx.blade
		var steel: Color = tint if tint != null else PAL["w"]
		var metal: Color = tint.darkened(0.25) if tint != null else PAL["m"]
		var dark: Color = tint.darkened(0.5) if tint != null else PAL["M"]
		var pp := _perp(dir)
		var diagonal := pp.x != 0 and pp.y != 0
		var put := func(t: int, c: Color, side := 0, tg := 0) -> void:
			var p := g + _step(dir, t) + pp * side
			f.put(ORIGIN + p, c, behind, tg)
			if diagonal and absi(side) >= 2:
				# fill the gap a diagonal side offset leaves
				f.put(ORIGIN + p - Vector2i(pp.x * signi(side), 0), c, true if behind else false, tg)
		var M := _wtag
		match kind:
			"dagger":
				put.call(-1, PAL["B"])
				put.call(1, PAL["M"], 1); put.call(1, PAL["M"], -1); put.call(1, PAL["m"])
				for t in range(2, 5):
					put.call(t, steel, 0, M)
			"shortsword":
				put.call(-1, PAL["L"])
				put.call(1, PAL["m"]); put.call(1, PAL["M"], 1); put.call(1, PAL["M"], -1)
				for t in range(2, 7):
					put.call(t, steel, 0, M)
			"longsword":
				put.call(-1, PAL["b"])
				put.call(1, PAL["y"]); put.call(1, PAL["y"], 1); put.call(1, PAL["y"], -1)
				for t in range(2, 11):
					put.call(t, steel, 0, M)
			"greatsword":
				put.call(-3, PAL["y"])
				put.call(-2, PAL["b"]); put.call(-1, PAL["b"])
				put.call(1, PAL["y"])
				for s in [1, 2, -1, -2]:
					put.call(1, PAL["y"] if absi(s) == 1 else Color8(170, 120, 40), s)
				for t in range(2, 14):
					put.call(t, steel, 0, M)
					if t < 12:
						put.call(t, metal, 1, M)
			"rapier":
				put.call(-1, PAL["B"])
				put.call(0, PAL["y"], 1); put.call(1, PAL["y"], 1); put.call(1, PAL["y"]); put.call(1, PAL["y"], -1)
				for t in range(2, 11):
					put.call(t, metal if t < 10 else steel, 0, M)
			"scimitar":
				put.call(-1, PAL["b"])
				put.call(1, PAL["y"]); put.call(1, PAL["y"], 1); put.call(1, PAL["y"], -1)
				for t in range(2, 9):
					var bend := 0 if t < 5 else (1 if t < 8 else 2)
					put.call(t, steel, bend, M)
					if t >= 3 and t <= 6:
						put.call(t, metal, bend - 1, M)
			"mace":
				for t in range(-1, 5):
					put.call(t, PAL["b"])
				put.call(5, dark, 0, M); put.call(5, dark, 1, M); put.call(5, dark, -1, M)
				put.call(6, metal, 0, M); put.call(6, dark, 1, M); put.call(6, dark, -1, M)
				put.call(7, dark, 0, M)
			"morningstar":
				for t in range(-1, 5):
					put.call(t, PAL["b"])
				put.call(5, dark, 0, M); put.call(5, dark, 1, M); put.call(5, dark, -1, M)
				put.call(6, metal, 0, M); put.call(6, dark, 1, M); put.call(6, dark, -1, M)
				put.call(7, dark, 0, M)
				put.call(4, metal, 2, M); put.call(4, metal, -2, M)
				put.call(7, metal, 2, M); put.call(7, metal, -2, M)
				put.call(8, steel, 0, M)
			"warhammer":
				for t in range(-1, 6):
					put.call(t, PAL["b"])
				for t in [5, 6]:
					put.call(t, metal, 0, M)
					put.call(t, metal, 1, M); put.call(t, dark, 2, M)
				put.call(6, dark, -1, M); put.call(7, dark, -1, M)
			"battleaxe":
				for t in range(-1, 8):
					put.call(t, PAL["b"])
				_axe_head(put, 1, 4, 8, steel, metal, dark)
				put.call(6, dark, -1, M)
			"greataxe":
				for t in range(-3, 9):
					put.call(t, PAL["b"])
				_axe_head(put, 1, 4, 9, steel, metal, dark)
				_axe_head(put, -1, 4, 9, steel, metal, dark)
				put.call(9, dark, 0, M)
			"handaxe":
				for t in range(-1, 5):
					put.call(t, PAL["b"])
				put.call(3, metal, 1, M); put.call(4, metal, 1, M); put.call(2, dark, 2, M); put.call(3, steel, 2, M); put.call(4, steel, 2, M); put.call(5, dark, 2, M)
			"staff":
				put.call(-10, PAL["B"])
				for t in range(-9, 7):
					put.call(t, PAL["b"], 0, M if t >= 5 else 0)
				if hero == "mage":
					_gem(f, g + _step(dir, 8), 0)
				else:
					put.call(7, PAL["B"])

	## A crescent axe blade on side `s` (1 or -1) from t0 to t1: widest at the edge.
	func _axe_head(put: Callable, s: int, t0: int, t1: int, steel: Color, metal: Color, dark: Color) -> void:
		var mid := (t0 + t1) / 2
		for t in range(t0 + 1, t1):
			put.call(t, metal if absi(t - mid) <= 1 else dark, s, _wtag)
		for t in range(t0, t1 + 1):
			put.call(t, metal, 2 * s, _wtag)
		for t in range(t0 - 1, t1 + 2):
			put.call(t, steel if absi(t - mid) < (t1 - t0) / 2 + 1 else dark, 3 * s, _wtag)


	func _gem(f: Frame, c: Vector2i, size: int) -> void:
		f.put(ORIGIN + c, PAL["F"])
		f.put(ORIGIN + c + Vector2i(0, -1), PAL["F"])
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
			f.put(ORIGIN + c + d, PAL["f"])
		if size >= 1:
			f.put(ORIGIN + c + Vector2i(0, -2), PAL["f"])
			f.put(ORIGIN + c + Vector2i(1, -1), PAL["f"])
			f.put(ORIGIN + c + Vector2i(-1, -1), PAL["f"])

	func _swoosh(f: Frame, cx: int, from: Dictionary, to: Dictionary) -> void:
		if look.main == "":
			return
		var fwd := -1
		var g := Vector2(cx + int(to["g"][0]) * fwd, to["g"][1])
		var r := clampf(float(REACH.get(look.main, 6)) - 1.0, 4.0, 10.0)
		var a0 := Vector2(from["d"][0] * fwd, -from["d"][1]).angle()
		var a1 := Vector2(to["d"][0] * fwd, -to["d"][1]).angle()
		var da := wrapf(a1 - a0, -PI, PI)
		var tint: Color = main_fx.color if main_fx.mode >= Fx.FIRE else Color(1, 1, 1)
		for i in 14:
			var t := float(i) / 13.0
			var a := a0 + da * t
			for rr in [r, r - 1.0]:
				var p := Vector2i((g + Vector2.from_angle(a) * rr).round())
				if f.empty(ORIGIN + p):
					f.fx[ORIGIN + p] = Color(tint, 0.25 + 0.45 * t)

	func _cast(view: String, base: Dictionary, cx: int, i: int) -> Frame:
		var v: Dictionary = rig[view]
		var glow: Array = rig["glow"]
		var style: String = rig["cast"]
		if style == "staff" and look.main != "staff":
			style = "raise"
		var f: Frame
		var spark_at: Vector2i
		match style:
			"raise":
				var lift := 2 if i == 0 else 4
				f = _pose(view, base, cx, {"g": [3, 7 - lift], "d": [0, 1], "lean": [0, 0]})
				var g := Vector2i(cx - 3, 7 - lift)
				spark_at = g + Vector2i(0, -(REACH.get(look.main, 2) - 1 if look.main != "" else 2))
			"staff":
				var lift := 2 if i == 0 else 3
				var gx: int = v["grip"][0] - cx
				f = _pose(view, base, cx, {"g": [-gx, int(v["grip"][1]) - lift], "d": [0, 1], "lean": [0, 0]})
				var g := Vector2i(int(v["grip"][0]), int(v["grip"][1]) - lift)
				spark_at = g + Vector2i(0, -8)
				if i > 0:
					_gem(f, spark_at, 1)
			"symbol":
				f = _pose(view, base, cx, {"g": "idle"})
				var oh: Dictionary = v["offhand"]
				if look.shield == "":
					for r in oh["erase"]:
						for y in range(r[1], r[3] + 1):
							for x in range(r[0], r[2] + 1):
								f.put(ORIGIN + Vector2i(x, y), Color(0, 0, 0, 0))
				var sh := _v(oh["shoulder"])
				var hand := Vector2i(cx - 4, 3 if i > 0 else 6)
				if view == "back":
					hand = Vector2i(sh.x + 1, 3 if i > 0 else 6)
				_arm(f, sh, hand, PAL[rig["arm"]])
				f.put(ORIGIN + hand, PAL["s"])
				for d in [Vector2i(0, -1), Vector2i(0, -2), Vector2i(0, -3), Vector2i(-1, -2), Vector2i(1, -2)]:
					f.put(ORIGIN + hand + d, PAL["y"])
				spark_at = hand + Vector2i(0, -2)
		if i > 0:
			_sparkles(f, spark_at, i, glow)
		return f

	func _sparkles(f: Frame, c: Vector2i, i: int, glow: Array) -> void:
		var col_a: Color = PAL[glow[0]]
		var col_b: Color = PAL[glow[1]]
		var bayer := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
		for y in range(-4, 5):
			for x in range(-4, 5):
				var d := Vector2(x, y).length()
				var p := ORIGIN + c + Vector2i(x, y)
				if d <= 3.6 and d >= 1.5 and f.empty(p):
					if bayer[posmod(p.y, 4)][posmod(p.x, 4)] < int((1.0 - d / 3.6) * 16.0) + (i % 2) * 2:
						f.fx[p] = Color(col_a, 0.5)
		var sparks := [
			[Vector2i(-4, -2), Vector2i(3, -4), Vector2i(4, 1)],
			[Vector2i(-3, -5), Vector2i(5, -2), Vector2i(-5, 1)],
			[Vector2i(-1, -6), Vector2i(4, -5), Vector2i(-4, -1)],
		]
		for s: Vector2i in sparks[(i - 1) % 3]:
			f.fx[ORIGIN + c + s] = col_b

	## Bow held out in the forward hand, string drawn back (longbow: taller limbs).
	func _bow(view: String, base: Dictionary, cx: int, i: int) -> Frame:
		var v: Dictionary = rig[view]
		var fwd := -1
		var f := Frame.new()
		var lean := [1, 0] if i == 1 else [0, 0]
		_blit_body(f, base, lean, Vector2i.ZERO, 0)
		var hand := Vector2i(cx + 6 * fwd, 9)
		_arm(f, _v(v["shoulder"]), hand, PAL[rig["arm"]])
		var reach := 7 if look.ranged == "longbow" else 5
		var tint = ranged_fx.blade
		var wood: Color = PAL["b"] if tint == null else PAL["b"].lerp(tint, 0.45)
		var top := hand + Vector2i(1 * -fwd, -reach)
		var bot := hand + Vector2i(1 * -fwd, reach)
		for k in range(-reach, reach + 1):
			var tip := absi(k) >= reach - 1
			var bend := 0 if tip else 1
			f.put(ORIGIN + hand + Vector2i(bend * fwd + (1 if tip else 0) * -fwd, k), wood, false, T_RANGED)
		f.put(ORIGIN + hand, PAL["s"])
		var pull: int = [1, 4, 0][i]
		var nock := hand + Vector2i((1 + pull) * -fwd, 0)
		for p in _line(top, nock) + _line(nock, bot):
			if f.empty(ORIGIN + p):
				f.fx[ORIGIN + p] = Color(PAL["o"], 0.8)
		if i < 2:
			for p in _line(nock, hand + Vector2i(3 * fwd, 0)):
				f.put(ORIGIN + p, PAL["m"])
			f.put(ORIGIN + hand + Vector2i(3 * fwd, 0), PAL["w"])
			f.put(ORIGIN + nock, PAL["s"])
		return f

	## Crossbow levelled at the chest: stock to the shoulder, steel prod across the front.
	func _crossbow(view: String, base: Dictionary, cx: int, i: int) -> Frame:
		var v: Dictionary = rig[view]
		var fwd := -1
		var f := Frame.new()
		var lean := [-1, 0] if i == 2 else [0, 0]
		_blit_body(f, base, lean, Vector2i.ZERO, 0)
		var heavy: bool = look.ranged == "heavy_crossbow"
		var y := 9
		var back := Vector2i(cx + 1 * fwd, y)
		var front := Vector2i(cx + (7 if heavy else 6) * fwd, y)
		var hand := Vector2i(cx + 4 * fwd, y + 1)
		_arm(f, _v(v["shoulder"]), hand, PAL[rig["arm"]])
		var tint = ranged_fx.blade
		var prod_col: Color = PAL["M"] if tint == null else tint
		for p in _line(back, front):
			f.put(ORIGIN + p, PAL["b"], false)
		var arms := 3 if heavy else 2
		for k in range(-arms, arms + 1):
			f.put(ORIGIN + front + Vector2i(1 * -fwd, k), prod_col, false, T_RANGED)
		var a := front + Vector2i(1 * -fwd, -arms)
		var b := front + Vector2i(1 * -fwd, arms)
		var nut := Vector2i(cx + (3 if i < 2 else 5) * fwd, y)
		for p in _line(a, nut) + _line(nut, b):
			if f.empty(ORIGIN + p):
				f.fx[ORIGIN + p] = Color(PAL["o"], 0.7)
		if i < 2:
			f.put(ORIGIN + front + Vector2i(1 * fwd, -1), PAL["w"])
			for p in _line(nut + Vector2i(0, -1), front + Vector2i(0, -1)):
				f.put(ORIGIN + p, PAL["m"])
		f.put(ORIGIN + hand, PAL["s"])
		return f

	func _kneel(view: String, base: Dictionary, cx: int, stage: int) -> Frame:
		var lean := [1, 0] if stage == 1 else [2, 1]
		var p := {"g": [3, 15], "d": [1, -1], "lean": lean}
		if look.main == "staff":
			p = {"g": [2, 12], "d": [0.5, 1], "lean": lean}
		return _pose(view, base, cx, p, stage)

	func _lying(base: Dictionary) -> Frame:
		var f := Frame.new()
		var at := Vector2i(5, 31 - 14)
		for y in GH:
			for gx in GW:
				var c: Color = base["col"][y][gx]
				if c.a > 0:
					var x := gx - PAD
					f.put(at + Vector2i(y, 13 - x), c, false, base["tag"][y][gx])
		var g := Vector2i(at.x + 6 - ORIGIN.x, 30 - ORIGIN.y)
		_weapon(f, look.main, g, Vector2(1, 0), true)
		return f

	# --- images -----------------------------------------------------------------------------

	func _render(f: Frame) -> Image:
		var img := Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
		for y in 32:
			var row: Array = f.col[y]
			for x in 32:
				var c: Color = row[x]
				if c.a > 0:
					img.set_pixel(x, y, c)
		var outline: Color = PAL["K"]
		for y in 32:
			for x in 32:
				if f.col[y][x].a > 0:
					continue
				if (x > 0 and f.col[y][x - 1].a > 0) or (x < 31 and f.col[y][x + 1].a > 0) \
						or (y > 0 and f.col[y - 1][x].a > 0) or (y < 31 and f.col[y + 1][x].a > 0):
					img.set_pixel(x, y, outline)
		for p: Vector2i in f.fx:
			if p.x >= 0 and p.y >= 0 and p.x < 32 and p.y < 32 and img.get_pixelv(p).a == 0:
				img.set_pixelv(p, f.fx[p])
		return img

	## R = main weapon zone, G = glint, B = ranged weapon zone (0..1, spread by the effect).
	func _render_fx(f: Frame) -> Image:
		var r := PackedFloat32Array()
		r.resize(1024)
		var gch := PackedFloat32Array()
		gch.resize(1024)
		var b := PackedFloat32Array()
		b.resize(1024)
		for y in 32:
			for x in 32:
				var t: int = f.tag[y][x]
				if t == 0:
					continue
				if t & T_MAIN:
					_spread(r, x, y, main_fx.mode)
				if t & T_RANGED:
					_spread(b, x, y, ranged_fx.mode)
				if t & T_GLINT:
					gch[y * 32 + x] = 1.0
		var img := Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
		for i in 1024:
			if r[i] > 0.0 or gch[i] > 0.0 or b[i] > 0.0:
				img.set_pixel(i % 32, i / 32, Color(r[i], gch[i], b[i], 1.0))
		return img

	## Effect strength around one weapon pixel: fire licks upward, frost mist sinks, glows spread.
	func _spread(ch: PackedFloat32Array, x: int, y: int, mode: int) -> void:
		var up := 0
		var down := 0
		var side := 0
		match mode:
			Fx.NONE:
				return
			Fx.SHIMMER:
				pass
			Fx.GLOW:
				up = 1; down = 1; side = 1
			Fx.FIRE:
				up = 5; down = 1; side = 2
			Fx.FROST:
				up = 1; down = 3; side = 2
			Fx.RADIANT:
				up = 2; down = 2; side = 2
		for dy in range(-up, down + 1):
			for dx in range(-side, side + 1):
				var px := x + dx
				var py := y + dy
				if px < 0 or py < 0 or px >= 32 or py >= 32:
					continue
				var reach := float(up if dy < 0 else down)
				var d := Vector2(float(dx) / maxf(side, 1), float(dy) / maxf(reach, 1)).length()
				var s := 1.0 if dx == 0 and dy == 0 else clampf(1.0 - d, 0.0, 1.0) * 0.85
				var i := py * 32 + px
				ch[i] = maxf(ch[i], s)

	# --- helpers ----------------------------------------------------------------------------

	func _centre_x(body: Dictionary) -> int:
		var lo := 99
		var hi := -1
		for y in range(7, 16):
			for gx in range(PAD, PAD + 14):
				if body["col"][y][gx].a > 0:
					lo = mini(lo, gx)
					hi = maxi(hi, gx)
		return (lo + hi) / 2 - PAD

	func _v(a: Array) -> Vector2i:
		return Vector2i(a[0], a[1])

	func _step(dir: Vector2, t: int) -> Vector2i:
		var m := maxf(absf(dir.x), absf(dir.y))
		var u := dir / m
		return Vector2i(roundi(u.x * t), roundi(u.y * t))

	func _perp(dir: Vector2) -> Vector2i:
		var m := maxf(absf(dir.x), absf(dir.y))
		var u := dir / m
		return Vector2i(roundi(-u.y), roundi(u.x))

	func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
		for i in n + 1:
			var t := 0.0 if n == 0 else float(i) / n
			out.append(Vector2i(Vector2(a).lerp(Vector2(b), t).round()))
		return out
