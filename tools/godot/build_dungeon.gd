extends SceneTree
## Builds the campaign's maps as ordinary map scenes you can keep editing in the editor:
##   scenes/maps/surface.tscn    "The Harrow Woods"     level 1 -> 2  (main scene; the mine entrance)
##   scenes/maps/dungeon_1.tscn  "The Upper Halls"      level 2 -> 3
##   scenes/maps/dungeon_2.tscn  "The Webbed Deep"      level 3      (the Eye Tyrant's lair)
##   scenes/maps/dungeon_3.tscn  "The Goblin Warrens"   level 3 -> 4
##   scenes/maps/dungeon_4.tscn  "The Sunken Crypts"    level 4
##   scenes/maps/dungeon_5.tscn  "The Sealed Vault"     level 4 -> 5  (the Wraith)
## Run: Godot_console --headless --path . -s res://tools/godot/build_dungeon.gd  [-- <map ids>]
## Re-running OVERWRITES the scenes (all, or the ones named: surface, dungeon_1...). Once a map has
## been edited in the editor, don't rebuild it.
##
## XP (5e SRD, split between the four heroes): the totals are planned so the party reaches level 2
## near the end of the woods, 3 in the Upper Halls, 4 in the Warrens and 5 in the Sealed Vault
## (thresholds x4: 1200 / 3600 / 10800 / 26000). The builder prints each map's total.
##
## DUNGEON FLOORS are laid out on a grid of slots (SLOT cells each). A room sits centred in its
## slot; a link between rooms in slots on the same row or column becomes a straight corridor with
## an arch on the first room's wall and a door on the second's. Room contents are placed by the
## builder from short descriptions:
##   spawn "kkS"     monsters by letter (MONSTERS), placed away from the doorways, one group per room
##   theme           props / decor / braziers / pillars (THEMES)
##   chests          [[gold, [items], lock_dc (0 = open), key_id]]  placed against the back wall
##   stairs / arrive / start  as before (stairs: [up, target map, target entry])
## THE WOODS are clearings joined by dirt paths; every cell near them is a block of forest (or
## cliff in the cliff zones), so the clearings read as glades in a dense wood.

const F = PartyStart.Facing
const FLOOR_SRC := 0
const WALL_SRC := 1
const FOREST_SRC := 2
enum WallRow { FACE_L, FACE_R, BOTH, CAP }
const SLOT := Vector2i(15, 13)

const MONSTERS := {
	"r": "giant_rat", "w": "wolf", "g": "goblin", "G": "goblin_boss", "b": "bandit", "z": "zombie",
	"k": "skeleton", "u": "ghoul", "U": "ghast", "h": "hobgoblin", "B": "bugbear", "O": "ogre",
	"W": "wight", "M": "mummy", "p": "specter", "X": "wraith", "S": "giant_spider", "E": "eye_tyrant",
}
const PROPS := {
	"barrel": Prop.Kind.BARREL, "crate": Prop.Kind.CRATE, "sarcophagus": Prop.Kind.SARCOPHAGUS,
	"rubble": Prop.Kind.RUBBLE, "cocoon": Prop.Kind.COCOON, "urn": Prop.Kind.URN,
	"oak": Prop.Kind.TREE_OAK, "pine": Prop.Kind.TREE_PINE, "bush": Prop.Kind.BUSH,
	"boulder": Prop.Kind.BOULDER, "stump": Prop.Kind.STUMP, "log": Prop.Kind.LOG,
	"tent": Prop.Kind.TENT, "grave": Prop.Kind.GRAVE,
}
## theme -> what furnishes a room: wall props (along the walls), mid props (in the middle, on a
## grid), bones, web, braziers (corners), pillars.
const THEMES := {
	"hall": {"wall": ["urn", "urn", "rubble"], "bones": 1, "braziers": 2},
	"guard": {"wall": ["barrel", "barrel", "crate", "crate"], "bones": 1, "web": true},
	"store": {"wall": ["crate", "crate", "crate", "barrel", "barrel", "barrel", "urn"]},
	"crypt": {"mid": ["sarcophagus", "sarcophagus", "sarcophagus", "sarcophagus"], "wall": ["urn", "urn"], "web": true, "braziers": 1},
	"nest": {"wall": ["cocoon", "cocoon", "cocoon", "cocoon", "rubble"], "bones": 3, "web": true},
	"ossuary": {"wall": ["urn", "urn", "urn", "rubble"], "mid": ["sarcophagus"], "bones": 4, "web": true},
	"lair": {"pillars": true, "braziers": 4, "bones": 2, "web": true, "wall": ["urn"]},
	"warren": {"wall": ["crate", "barrel", "rubble", "rubble", "crate"], "bones": 2, "braziers": 1},
	"barracks": {"wall": ["crate", "crate", "barrel", "barrel", "crate"], "braziers": 2},
	"kennel": {"wall": ["rubble", "barrel"], "bones": 5},
	"throne": {"pillars": true, "braziers": 4, "wall": ["urn", "urn", "crate"], "bones": 1},
	"tomb": {"mid": ["sarcophagus", "sarcophagus"], "wall": ["urn", "urn", "urn"], "braziers": 2, "web": true},
	"flooded": {"wall": ["rubble", "rubble", "urn"], "bones": 2, "web": true},
	"vault": {"pillars": true, "braziers": 4, "wall": ["urn", "urn"], "mid": ["sarcophagus"]},
	"bare": {},
}

# --- the dungeon floors ---------------------------------------------------------------------------

var DUNGEON_1 := {
	"title": "The Upper Halls", "start_level": 2,
	"rooms": {
		# the way in from the mine: stairs up to the woods
		"A": {"slot": Vector2i(0, 2), "size": Vector2i(8, 7), "theme": "hall",
			"stairs": [true, "res://scenes/maps/surface.tscn", "from_below"], "arrive": "from_above",
			"start": true},
		"B": {"slot": Vector2i(0, 1), "size": Vector2i(10, 7), "theme": "guard", "spawn": "kkk",
			"chests": [[30, ["mace_plus1", "potion_healing"]]]},
		"C": {"slot": Vector2i(1, 1), "size": Vector2i(8, 6), "theme": "store", "spawn": "rrrrrr",
			"chests": [[40, ["potion_healing", "potion_healing", "crypt_key", "scroll_cure_wounds", "scroll_burning_hands"], 12]]},
		"D": {"slot": Vector2i(1, 2), "size": Vector2i(9, 9), "theme": "crypt", "spawn": "kku",
			"chests": [[120, ["longsword_plus1", "studded_leather_plus1", "scroll_magic_missile"]]]},
		"E": {"slot": Vector2i(2, 1), "size": Vector2i(10, 9), "theme": "nest", "spawn": "SS",
			"chests": [[45, ["ring_free_action", "shortbow_plus1"]]]},
		"F": {"slot": Vector2i(2, 2), "size": Vector2i(9, 7), "theme": "tomb", "spawn": "zzzz",
			"chests": [[35, ["potion_healing", "scroll_healing_word", "breastplate"]]]},
		"G": {"slot": Vector2i(0, 0), "size": Vector2i(8, 8), "theme": "flooded", "spawn": "rrrrz"},
		"H": {"slot": Vector2i(1, 0), "size": Vector2i(10, 7), "theme": "barracks", "spawn": "kkkk",
			"chests": [[25, ["battleaxe", "scimitar", "potion_healing"]]]},
		"I": {"slot": Vector2i(2, 0), "size": Vector2i(8, 7), "theme": "ossuary", "spawn": "uu"},
		"J": {"slot": Vector2i(3, 0), "size": Vector2i(9, 7), "theme": "store", "spawn": "kkzz",
			"chests": [[50, ["heavy_crossbow", "potion_healing", "scroll_bless"]]]},
		"K": {"slot": Vector2i(3, 1), "size": Vector2i(9, 8), "theme": "nest", "spawn": "Skk"},
		"L": {"slot": Vector2i(3, 2), "size": Vector2i(8, 7), "theme": "hall", "spawn": "kku",
			"stairs": [false, "res://scenes/maps/dungeon_2.tscn", "from_above"], "arrive": "from_below"},
	},
	"links": [["A", "B"], ["B", "C"], ["A", "D", {"locked": 13, "key": "crypt"}], ["B", "G"], ["G", "H"],
		["H", "I"], ["C", "E"], ["E", "I"], ["I", "J"], ["J", "K"], ["K", "L"], ["E", "F"], ["D", "F"], ["F", "L"]],
}

var DUNGEON_2 := {
	"title": "The Webbed Deep", "start_level": 3,
	"rooms": {
		"A": {"slot": Vector2i(0, 0), "size": Vector2i(7, 7), "theme": "hall",
			"stairs": [true, "res://scenes/maps/dungeon_1.tscn", "from_below"], "arrive": "from_above", "start": true,
			"chests": [[20, ["dagger_plus1", "potion_healing"]]]},
		"B": {"slot": Vector2i(1, 0), "size": Vector2i(10, 8), "theme": "ossuary", "spawn": "kkkk",
			"chests": [[60, ["potion_greater_healing", "lair_key", "scroll_lightning_bolt", "shield_plus1"]]]},
		"C": {"slot": Vector2i(0, 1), "size": Vector2i(11, 9), "theme": "nest", "spawn": "SSS",
			"chests": [[80, ["ring_resistance", "rapier_plus1", "potion_healing"]]]},
		"D": {"slot": Vector2i(2, 0), "size": Vector2i(9, 8), "theme": "nest", "spawn": "SS"},
		"E": {"slot": Vector2i(1, 1), "size": Vector2i(9, 8), "theme": "ossuary", "spawn": "uuu",
			"chests": [[40, ["scroll_hold_person", "potion_greater_healing", "morningstar"]]]},
		"F": {"slot": Vector2i(2, 1), "size": Vector2i(10, 8), "theme": "flooded", "spawn": "zzzzzz"},
		"G": {"slot": Vector2i(0, 2), "size": Vector2i(9, 7), "theme": "nest", "spawn": "Srrrr"},
		# the Eye Tyrant's lair: the Bone Key (ossuary) opens it
		"H": {"slot": Vector2i(1, 2), "size": Vector2i(11, 9), "theme": "lair", "spawn": "Ekk",
			"chests": [[300, ["ring_protection", "chain_mail_plus1", "potion_greater_healing", "scroll_fireball"]]]},
		"I": {"slot": Vector2i(2, 2), "size": Vector2i(8, 7), "theme": "hall", "spawn": "ukk",
			"stairs": [false, "res://scenes/maps/dungeon_3.tscn", "from_above"], "arrive": "from_below"},
		"J": {"slot": Vector2i(3, 1), "size": Vector2i(9, 8), "theme": "nest", "spawn": "SS",
			"chests": [[70, ["potion_healing", "potion_healing", "scroll_scorching_ray"]]]},
	},
	"links": [["A", "B"], ["A", "C"], ["B", "D"], ["B", "E"], ["C", "E"], ["D", "F"], ["E", "F"], ["C", "G"],
		["G", "H", {"locked": 0, "key": "lair"}], ["H", "I"], ["F", "J"]],
}

var DUNGEON_3 := {
	"title": "The Goblin Warrens", "start_level": 3,
	"rooms": {
		"A": {"slot": Vector2i(0, 0), "size": Vector2i(8, 7), "theme": "warren",
			"stairs": [true, "res://scenes/maps/dungeon_2.tscn", "from_below"], "arrive": "from_above", "start": true},
		"B": {"slot": Vector2i(1, 0), "size": Vector2i(11, 8), "theme": "warren", "spawn": "gggggg",
			"chests": [[35, ["potion_healing", "potion_healing"]]]},
		"C": {"slot": Vector2i(0, 1), "size": Vector2i(9, 8), "theme": "kennel", "spawn": "wwwwgg"},
		"D": {"slot": Vector2i(2, 0), "size": Vector2i(10, 7), "theme": "barracks", "spawn": "hhh",
			"chests": [[60, ["scimitar_plus1", "potion_greater_healing", "half_plate"]]]},
		"E": {"slot": Vector2i(1, 1), "size": Vector2i(9, 8), "theme": "warren", "spawn": "BB",
			"chests": [[50, ["greataxe", "potion_greater_healing", "scroll_scorching_ray"]]]},
		"F": {"slot": Vector2i(2, 1), "size": Vector2i(10, 8), "theme": "barracks", "spawn": "ggggh"},
		"G": {"slot": Vector2i(0, 2), "size": Vector2i(10, 9), "theme": "kennel", "spawn": "O"},
		"H": {"slot": Vector2i(1, 2), "size": Vector2i(9, 8), "theme": "throne", "spawn": "Ghh",
			"chests": [[90, ["warren_key", "potion_greater_healing", "longbow_plus1"]]]},
		# the war room: locked (the Chief's Key, or pick DC 15)
		"I": {"slot": Vector2i(2, 2), "size": Vector2i(10, 8), "theme": "barracks", "spawn": "Ohh"},
		"J": {"slot": Vector2i(3, 2), "size": Vector2i(11, 9), "theme": "throne", "spawn": "GBBhh",
			"chests": [[250, ["longsword_plus2", "potion_superior_healing", "scroll_hold_person"]]],
			"stairs": [false, "res://scenes/maps/dungeon_4.tscn", "from_above"], "arrive": "from_below"},
		"K": {"slot": Vector2i(3, 1), "size": Vector2i(8, 7), "theme": "store", "spawn": "hh",
			"chests": [[400, ["warhammer_plus1", "breastplate_plus1", "potion_greater_healing", "scroll_fireball"]]]},
	},
	"links": [["A", "B"], ["A", "C"], ["B", "D"], ["B", "E"], ["C", "E"], ["D", "F"], ["E", "F"], ["C", "G"],
		["E", "H"], ["G", "H"], ["H", "I", {"locked": 15, "key": "warren"}], ["I", "J"], ["F", "K"]],
}

var DUNGEON_4 := {
	"title": "The Sunken Crypts", "start_level": 4,
	"rooms": {
		"A": {"slot": Vector2i(0, 0), "size": Vector2i(8, 7), "theme": "flooded",
			"stairs": [true, "res://scenes/maps/dungeon_3.tscn", "from_below"], "arrive": "from_above", "start": true},
		"B": {"slot": Vector2i(1, 0), "size": Vector2i(10, 8), "theme": "ossuary", "spawn": "uuu"},
		"C": {"slot": Vector2i(0, 1), "size": Vector2i(10, 8), "theme": "ossuary", "spawn": "kkkkkk",
			"chests": [[70, ["mace_of_disruption", "potion_greater_healing"]]]},
		"D": {"slot": Vector2i(2, 0), "size": Vector2i(10, 8), "theme": "tomb", "spawn": "Wzzz",
			"chests": [[120, ["ring_resistance_necrotic", "potion_greater_healing"]]]},
		"E": {"slot": Vector2i(1, 1), "size": Vector2i(9, 8), "theme": "crypt", "spawn": "pp"},
		"F": {"slot": Vector2i(2, 1), "size": Vector2i(10, 8), "theme": "flooded", "spawn": "Uuu"},
		"G": {"slot": Vector2i(0, 2), "size": Vector2i(11, 9), "theme": "flooded", "spawn": "zzzzzzzzzu"},
		"H": {"slot": Vector2i(1, 2), "size": Vector2i(9, 8), "theme": "tomb", "spawn": "M",
			"chests": [[90, ["potion_superior_healing", "scroll_mass_healing_word", "scroll_hold_person"]]]},
		"I": {"slot": Vector2i(2, 2), "size": Vector2i(11, 9), "theme": "crypt", "spawn": "WW",
			"chests": [[200, ["plate_armor_plus1", "shortbow_plus2", "potion_greater_healing"]]]},
		"J": {"slot": Vector2i(3, 2), "size": Vector2i(9, 8), "theme": "tomb", "spawn": "UU",
			"stairs": [false, "res://scenes/maps/dungeon_5.tscn", "from_above"], "arrive": "from_below"},
		"K": {"slot": Vector2i(3, 1), "size": Vector2i(8, 7), "theme": "crypt", "spawn": "uukk",
			"chests": [[110, ["rapier_plus2", "potion_superior_healing"]]]},
	},
	"links": [["A", "B"], ["A", "C"], ["B", "D"], ["B", "E"], ["C", "E"], ["C", "G"], ["D", "F"], ["E", "F"],
		["E", "H"], ["G", "H"], ["F", "I"], ["H", "I"], ["I", "J"], ["F", "K"], ["K", "J"]],
}

var DUNGEON_5 := {
	"title": "The Sealed Vault", "start_level": 4,
	"rooms": {
		"A": {"slot": Vector2i(0, 0), "size": Vector2i(8, 7), "theme": "hall",
			"stairs": [true, "res://scenes/maps/dungeon_4.tscn", "from_below"], "arrive": "from_above", "start": true},
		"B": {"slot": Vector2i(1, 0), "size": Vector2i(10, 8), "theme": "tomb", "spawn": "M",
			"chests": [[80, ["potion_superior_healing", "scroll_mass_healing_word"]]]},
		"C": {"slot": Vector2i(0, 1), "size": Vector2i(10, 8), "theme": "crypt", "spawn": "pppkk"},
		"D": {"slot": Vector2i(2, 0), "size": Vector2i(10, 8), "theme": "tomb", "spawn": "Wkkkkkk",
			"chests": [[120, ["studded_leather_plus2", "potion_superior_healing"]]]},
		"E": {"slot": Vector2i(1, 1), "size": Vector2i(11, 9), "theme": "vault", "spawn": "MM",
			"chests": [[200, ["flame_tongue", "scroll_fireball", "potion_greater_healing"]]]},
		"F": {"slot": Vector2i(2, 1), "size": Vector2i(10, 9), "theme": "ossuary", "spawn": "UUuu"},
		"G": {"slot": Vector2i(0, 2), "size": Vector2i(10, 8), "theme": "flooded", "spawn": "zzzzzz",
			"chests": [[60, ["mace_plus2", "potion_greater_healing"]]]},
		"H": {"slot": Vector2i(1, 2), "size": Vector2i(10, 8), "theme": "barracks", "spawn": "WW",
			"chests": [[150, ["vault_key", "half_plate_plus1", "potion_superior_healing"]]]},
		"I": {"slot": Vector2i(2, 2), "size": Vector2i(9, 8), "theme": "tomb", "spawn": "Mzz"},
		# the Wraith's vault: only the Sun Key opens it
		"J": {"slot": Vector2i(3, 2), "size": Vector2i(11, 9), "theme": "vault", "spawn": "Xp",
			"chests": [[1000, ["ring_protection", "shield_plus2", "potion_superior_healing", "scroll_mass_healing_word"]]]},
	},
	"links": [["A", "B"], ["A", "C"], ["B", "D"], ["B", "E"], ["C", "E"], ["C", "G"], ["D", "F"], ["E", "F"],
		["G", "H"], ["E", "H"], ["F", "I"], ["H", "I"], ["I", "J", {"locked": 0, "key": "vault"}]],
}

# --- the woods ------------------------------------------------------------------------------------

var SURFACE := {
	"title": "The Harrow Woods", "start_level": 1,
	# clearings: rect + content (cells relative to the clearing)
	"clearings": {
		"start": {"rect": Rect2i(4, 40, 11, 8), "start": [Vector2i(4, 4), F.NORTH_EAST], "campfire": [Vector2i(7, 3)],
			"props": [["log", Vector2i(8, 4)], ["stump", Vector2i(2, 1)]]},
		"farm": {"rect": Rect2i(4, 24, 12, 10), "spawn": "rrrr", "props": [["rubble", Vector2i(1, 1)], ["rubble", Vector2i(2, 1)],
			["crate", Vector2i(9, 1)], ["barrel", Vector2i(10, 1)], ["barrel", Vector2i(10, 2)], ["rubble", Vector2i(1, 7)]],
			"bones": [Vector2i(5, 6)], "chests": [[15, ["potion_healing", "potion_healing"], Vector2i(9, 2)]]},
		"glade": {"rect": Rect2i(22, 38, 12, 9), "spawn": "www", "props": [["boulder", Vector2i(2, 2)], ["stump", Vector2i(9, 6)],
			["bush", Vector2i(10, 1)]], "bones": [Vector2i(6, 4), Vector2i(4, 6)]},
		"camp": {"rect": Rect2i(22, 20, 15, 12), "spawn": "bbbbbb", "campfire": [Vector2i(7, 6)],
			"props": [["tent", Vector2i(3, 2)], ["tent", Vector2i(11, 2)], ["tent", Vector2i(3, 9)], ["crate", Vector2i(12, 9)],
				["crate", Vector2i(13, 9)], ["barrel", Vector2i(13, 8)], ["log", Vector2i(7, 8)]],
			"chests": [[40, ["studded_leather", "potion_healing", "scroll_burning_hands"], Vector2i(12, 8)]]},
		"graveyard": {"rect": Rect2i(4, 6, 13, 12), "spawn": "zzz", "props": [["grave", Vector2i(2, 2)], ["grave", Vector2i(5, 2)],
			["grave", Vector2i(8, 2)], ["grave", Vector2i(2, 5)], ["grave", Vector2i(5, 5)], ["grave", Vector2i(8, 5)],
			["grave", Vector2i(11, 3)], ["pine", Vector2i(11, 8)], ["urn", Vector2i(1, 9)]],
			"bones": [Vector2i(4, 8)], "chests": [[20, ["scroll_bless", "potion_healing"], Vector2i(6, 0)]]},
		"lookout": {"rect": Rect2i(24, 4, 11, 9), "spawn": "ggg", "props": [["boulder", Vector2i(2, 2)], ["boulder", Vector2i(8, 1)],
			["boulder", Vector2i(5, 6)], ["bush", Vector2i(1, 6)]]},
		"deepwood": {"rect": Rect2i(44, 26, 11, 11), "spawn": "wwww", "props": [["oak", Vector2i(2, 2)], ["oak", Vector2i(8, 8)],
			["stump", Vector2i(5, 3)], ["log", Vector2i(3, 7)], ["bush", Vector2i(9, 2)]], "bones": [Vector2i(6, 6), Vector2i(5, 5)],
			"chests": [[30, ["longbow", "potion_healing"], Vector2i(5, 8)]]},
		"oldroad": {"rect": Rect2i(40, 40, 10, 7), "spawn": "gggg", "props": [["log", Vector2i(2, 1)], ["log", Vector2i(6, 5)],
			["bush", Vector2i(8, 1)]]},
		# the old silver mine: the way down
		"mine": {"rect": Rect2i(44, 4, 15, 12), "spawn": "Gggg", "campfire": [Vector2i(4, 7)],
			"props": [["tent", Vector2i(2, 4)], ["crate", Vector2i(11, 1)], ["barrel", Vector2i(12, 1)], ["rubble", Vector2i(13, 7)]],
			"stairs": [Vector2i(7, 0), "res://scenes/maps/dungeon_1.tscn", "from_above"], "arrive": [Vector2i(7, 2), "from_below", F.SOUTH_WEST],
			"chests": [[50, ["scimitar", "potion_healing"], Vector2i(13, 2)]]},
	},
	# dirt paths (2 wide): [from, to] cells, drawn as an L (x first, then y)
	"paths": [
		[Vector2i(9, 44), Vector2i(9, 30)],      # start - farm
		[Vector2i(12, 44), Vector2i(27, 43)],    # start - glade
		[Vector2i(28, 40), Vector2i(28, 26)],    # glade - camp
		[Vector2i(9, 26), Vector2i(9, 12)],      # farm - graveyard
		[Vector2i(14, 28), Vector2i(24, 28)],    # farm - camp
		[Vector2i(30, 22), Vector2i(30, 8)],     # camp - lookout
		[Vector2i(32, 8), Vector2i(50, 9)],      # lookout - mine
		[Vector2i(34, 29), Vector2i(48, 30)],    # camp - deep wood
		[Vector2i(30, 42), Vector2i(44, 42)],    # glade - old road
		[Vector2i(46, 42), Vector2i(46, 32)],    # old road - deep wood
		[Vector2i(50, 30), Vector2i(50, 10)],    # deep wood - mine
	],
	# rock instead of trees: the hill the mine is cut into, the ridge by the lookout
	"cliffs": [Rect2i(40, -4, 24, 8), Rect2i(20, -4, 18, 8)],
}

var rnd := RandomNumberGenerator.new()


func _init() -> void:
	var only := Array(OS.get_cmdline_user_args())
	var maps := [
		["surface", SURFACE, "Surface"], ["dungeon_1", DUNGEON_1, "Dungeon1"], ["dungeon_2", DUNGEON_2, "Dungeon2"],
		["dungeon_3", DUNGEON_3, "Dungeon3"], ["dungeon_4", DUNGEON_4, "Dungeon4"], ["dungeon_5", DUNGEON_5, "Dungeon5"],
	]
	var ok := true
	var total := 0
	for m in maps:
		var xp := _xp_of(m[1])
		total += xp
		if not only.is_empty() and not m[0] in only:
			print("build_dungeon: %s skipped (%d XP, %d running total)" % [m[0], xp, total])
			continue
		rnd.seed = hash(m[0])
		var path := "res://scenes/maps/%s.tscn" % m[0]
		if m[0] == "surface":
			ok = _build_surface(m[1], m[2], path) and ok
		else:
			ok = _build_floor(m[1], m[2], path) and ok
		print("build_dungeon: %s %d XP (running total %d = %d each)" % [m[0], xp, total, total / 4])
	quit(0 if ok else 1)


func _xp_of(d: Dictionary) -> int:
	var xp := 0
	var areas: Dictionary = d.get("rooms", d.get("clearings", {}))
	for k in areas:
		for ch in areas[k].get("spawn", ""):
			var s: CreatureStats = load("res://data/monsters/%s.tres" % MONSTERS[ch])
			xp += s.xp
	return xp


# --- dungeon floors ---------------------------------------------------------------------------------

func _build_floor(d: Dictionary, root_name: String, path: String) -> bool:
	var ok := true
	# rooms: interior rects centred in their slots
	var rects := {}
	for rn in d.rooms:
		var room: Dictionary = d.rooms[rn]
		var size: Vector2i = room.size
		var origin: Vector2i = room.slot * SLOT + Vector2i(2, 2)
		rects[rn] = Rect2i(origin + (SLOT - Vector2i(3, 3) - size) / 2, size)
	var floor_cells := {}
	for rn in rects:
		var r: Rect2i = rects[rn]
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				floor_cells[Vector2i(x, y)] = rn
	var doors := []         # [cell, locked, dc, key]
	var doorways := {}
	var entries := {}       # room -> its doorway cells (to keep clear)
	for l in d.links:
		var a: Rect2i = rects[l[0]]
		var b: Rect2i = rects[l[1]]
		var opts: Dictionary = l[2] if l.size() > 2 else {}
		var cells: Array[Vector2i] = []
		var door_cell: Vector2i
		var arch_cell: Vector2i
		var sa: Vector2i = d.rooms[l[0]].slot
		var sb: Vector2i = d.rooms[l[1]].slot
		if sa.y == sb.y:
			var lo := maxi(a.position.y, b.position.y)
			var hi := mini(a.end.y, b.end.y) - 1
			var y := (lo + hi) / 2
			var left := a if a.position.x < b.position.x else b
			var right := b if left == a else a
			for x in range(left.end.x, right.position.x):
				cells.append(Vector2i(x, y))
			door_cell = Vector2i(b.position.x - 1, y) if b == right else Vector2i(b.end.x, y)
			arch_cell = Vector2i(a.end.x, y) if a == left else Vector2i(a.position.x - 1, y)
		elif sa.x == sb.x:
			var lo := maxi(a.position.x, b.position.x)
			var hi := mini(a.end.x, b.end.x) - 1
			var x := (lo + hi) / 2
			var top := a if a.position.y < b.position.y else b
			var bot := b if top == a else a
			for y in range(top.end.y, bot.position.y):
				cells.append(Vector2i(x, y))
			door_cell = Vector2i(x, b.position.y - 1) if b == bot else Vector2i(x, b.end.y)
			arch_cell = Vector2i(x, a.end.y) if a == top else Vector2i(x, a.position.y - 1)
		else:
			push_error("%s: link %s-%s: rooms not on one row or column" % [root_name, l[0], l[1]])
			ok = false
			continue
		for c in cells:
			if floor_cells.has(c) and floor_cells[c] != "":
				push_error("%s: corridor %s-%s runs through room %s" % [root_name, l[0], l[1], floor_cells[c]])
				ok = false
			floor_cells[c] = ""
		var is_door: bool = opts.get("door", true)
		if is_door:
			doors.append([door_cell, opts.has("locked"), opts.get("locked", 0), opts.get("key", "")])
		doorways[door_cell] = true
		doorways[arch_cell] = true
		for rn in [l[0], l[1]]:
			if not entries.has(rn):
				entries[rn] = []
		entries[l[1]].append(door_cell)
		entries[l[0]].append(arch_cell)
	# pillars
	var pillars := {}
	for rn in d.rooms:
		if THEMES[d.rooms[rn].get("theme", "bare")].get("pillars", false):
			var r: Rect2i = rects[rn]
			if r.size.x >= 9 and r.size.y >= 8:
				for p in [Vector2i(2, 2), Vector2i(r.size.x - 3, 2), Vector2i(2, r.size.y - 3), Vector2i(r.size.x - 3, r.size.y - 3)]:
					pillars[r.position + p] = true
	for p in pillars:
		floor_cells.erase(p)
	var walls := {}
	for c: Vector2i in floor_cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if not floor_cells.has(n):
					walls[n] = true

	var root := _make_root(root_name, d.title, "res://assets/tiles/dungeon_tileset.tres", Color(0.34, 0.36, 0.50), d.start_level)
	var floor: TileMapLayer = root.get_node("Floor")
	var wall_layer: TileMapLayer = root.get_node("World/Walls")
	var entities: Node2D = root.get_node("World/Entities")
	var decor: Node2D = root.get_node("World/Decor")
	for c: Vector2i in floor_cells:
		floor.set_cell(c, FLOOR_SRC, Vector2i(rnd.randi_range(0, 7), 1 if doorways.has(c) else 0))
	_paint_walls(wall_layer, walls, WALL_SRC, {})

	for dd in doors:
		var c: Vector2i = dd[0]
		var door := _inst("door", entities, root, c, "Door_%d_%d" % [c.x, c.y])
		if walls.has(c + Vector2i(1, 0)) and walls.has(c - Vector2i(1, 0)):
			door.wall_run = Door.WallRun.BACK_RIGHT
		elif walls.has(c + Vector2i(0, 1)) and walls.has(c - Vector2i(0, 1)):
			door.wall_run = Door.WallRun.BACK_LEFT
		else:
			push_error("%s: door at %s is not in a wall run" % [root_name, c])
			ok = false
		door.locked = dd[1]
		if dd[1]:
			door.lock_dc = dd[2]
			door.key_id = dd[3]

	var blocked := {}        # cells with props / chests / braziers / stairs (for the checks)
	var group := 1
	var start_cell := Vector2i.ZERO
	for rn in d.rooms:
		var room: Dictionary = d.rooms[rn]
		var r: Rect2i = rects[rn]
		var theme: Dictionary = THEMES[room.get("theme", "bare")]
		var o := r.position
		_torches(r, walls, doorways, entities, root, rn)
		# cells to keep clear: in front of every doorway, plus the stairs and arrival
		var keep := {}
		for e: Vector2i in entries.get(rn, []):
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					keep[e + Vector2i(dx, dy)] = true
			for k in range(2, 4):
				keep[e + (_inward(e, r) * k)] = true
		var used := {}
		for p in pillars:
			used[p] = true
		# stairs: back corner area; arrival next to them
		if room.has("stairs"):
			var s: Array = room.stairs
			var sc := o + Vector2i(r.size.x - 2, 1)
			if keep.has(sc):
				sc = o + Vector2i(1, r.size.y - 2)
			var st := _inst("stairs", entities, root, sc, "Stairs_" + ("Up" if s[0] else "Down"))
			st.up = s[0]
			st.target_map = s[1]
			st.target_entry = s[2]
			used[sc] = true
			blocked[sc] = true
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					keep[sc + Vector2i(dx, dy)] = true
			if room.has("arrive"):
				var ac := sc + Vector2i(-1, 1)
				var ps := _inst("party_start", entities, root, ac, "PartyStart_" + room.arrive)
				ps.entry_id = room.arrive
				ps.facing = F.SOUTH_WEST
				keep[ac] = true
				if room.get("start", false):
					var main := _inst("party_start", entities, root, ac, "PartyStart")
					main.facing = F.SOUTH_WEST
					start_cell = ac
		# braziers in the corners
		var corners := [Vector2i(0, 0), Vector2i(r.size.x - 1, r.size.y - 1), Vector2i(r.size.x - 1, 0), Vector2i(0, r.size.y - 1)]
		var nb: int = theme.get("braziers", 0)
		for c in corners:
			if nb <= 0:
				break
			var cc: Vector2i = o + c
			if keep.has(cc) or used.has(cc):
				continue
			_inst("brazier", entities, root, cc, "Brazier_%s_%d_%d" % [rn, cc.x, cc.y])
			used[cc] = true
			blocked[cc] = true
			nb -= 1
		# chests against the back wall
		for ch in room.get("chests", []):
			var cc := _free_near(o + Vector2i(r.size.x / 2, 0), r, keep, used)
			var chest := _inst("chest", entities, root, cc, "Chest_%s_%d_%d" % [rn, cc.x, cc.y])
			chest.gold = ch[0]
			chest.items.assign(ch[1])
			if ch.size() > 2 and ch[2] > 0:
				chest.locked = true
				chest.lock_dc = ch[2]
			used[cc] = true
			blocked[cc] = true
		# props in the middle (sarcophagi) and along the walls
		var mids := [Vector2i(2, 2), Vector2i(r.size.x - 3, 2), Vector2i(2, r.size.y - 3), Vector2i(r.size.x - 3, r.size.y - 3)]
		var mi := 0
		for kind in theme.get("mid", []):
			while mi < mids.size() and (keep.has(o + mids[mi]) or used.has(o + mids[mi])):
				mi += 1
			if mi >= mids.size():
				break
			var mc: Vector2i = o + mids[mi]
			_prop(kind, mc, entities, root, rn)
			used[mc] = true
			blocked[mc] = true
			mi += 1
		var edge := _edge_cells(r)
		_shuffle(edge)
		var ei := 0
		for kind in theme.get("wall", []):
			while ei < edge.size() and (keep.has(edge[ei]) or used.has(edge[ei]) or _crowded(edge[ei], used)):
				ei += 1
			if ei >= edge.size():
				break
			_prop(kind, edge[ei], entities, root, rn)
			used[edge[ei]] = true
			blocked[edge[ei]] = true
			ei += 1
		# decor: web in the back corner, bones about
		if theme.get("web", false):
			_web(decor, root, o, rn)
		var interior := _interior(r)
		_shuffle(interior)
		var nbones: int = theme.get("bones", 0)
		for c in interior:
			if nbones <= 0:
				break
			if not used.has(c):
				_bones(decor, root, c, rn)
				nbones -= 1
		# monsters: far from the doorways, spread out
		var spawn: String = room.get("spawn", "")
		if spawn != "":
			var cells := _monster_cells(r, spawn.length(), entries.get(rn, []), keep, used)
			for i in spawn.length():
				var id: String = MONSTERS[spawn[i]]
				if i >= cells.size():
					push_error("%s: no room for monster %d in %s" % [root_name, i, rn])
					ok = false
					break
				var mc: Vector2i = cells[i]
				var sp := _inst("monster_spawn", entities, root, mc, "%s_%s_%d_%d" % [id.to_pascal_case(), rn, mc.x, mc.y])
				sp.monster_id = id
				sp.group_id = group
				sp.facing = _facing_toward(mc, entries.get(rn, [r.get_center()]))
				_set_preview(sp, id)
				used[mc] = true
			group += 1
	(root.get_node("Camera") as Camera2D).position = IsoGrid.view_cell_to_world(start_cell)
	ok = _check(root_name, floor_cells, blocked, start_cell, rects) and ok
	_save(root, path)
	return ok


## Unit step from a doorway cell into its room.
func _inward(e: Vector2i, r: Rect2i) -> Vector2i:
	if e.y < r.position.y:
		return Vector2i(0, 1)
	if e.y >= r.end.y:
		return Vector2i(0, -1)
	if e.x < r.position.x:
		return Vector2i(1, 0)
	return Vector2i(-1, 0)


func _edge_cells(r: Rect2i) -> Array:
	var out := []
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			if x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1:
				out.append(Vector2i(x, y))
	return out


func _interior(r: Rect2i) -> Array:
	var out := []
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			out.append(Vector2i(x, y))
	return out


## Two wall props side by side would wall off a corner: keep one cell apart (except in a corner run).
func _crowded(c: Vector2i, used: Dictionary) -> bool:
	var n := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if used.has(c + d):
			n += 1
	return n >= 2


func _free_near(c: Vector2i, r: Rect2i, keep: Dictionary, used: Dictionary) -> Vector2i:
	for k in range(0, r.size.x):
		for s in [1, -1]:
			var t := c + Vector2i(k * s, 0)
			if r.has_point(t) and not keep.has(t) and not used.has(t):
				return t
	return c + Vector2i(0, 1)


## Cells for n monsters: the far half of the room from its doorways, two cells apart if possible.
func _monster_cells(r: Rect2i, n: int, entries: Array, keep: Dictionary, used: Dictionary) -> Array[Vector2i]:
	var cand := []
	for c: Vector2i in _interior(r):
		if keep.has(c) or used.has(c):
			continue
		var d := 99
		for e: Vector2i in entries:
			d = mini(d, DungeonMap.grid_distance(c, e))
		cand.append([c, d + rnd.randf() * 1.5])
	cand.sort_custom(func(a, b): return a[1] > b[1])
	var out: Array[Vector2i] = []
	for spacing in [2, 1]:
		for cd in cand:
			if out.size() >= n:
				break
			var c: Vector2i = cd[0]
			if c in out:
				continue
			var ok := true
			for o in out:
				if DungeonMap.grid_distance(c, o) < spacing:
					ok = false
					break
			if ok:
				out.append(c)
	return out


func _facing_toward(c: Vector2i, targets: Array) -> int:
	var best: Vector2i = targets[0]
	for t: Vector2i in targets:
		if DungeonMap.grid_distance(c, t) < DungeonMap.grid_distance(c, best):
			best = t
	var d := best - c
	if absi(d.x) >= absi(d.y):
		return F.SOUTH_EAST if d.x > 0 else F.NORTH_WEST
	return F.SOUTH_WEST if d.y > 0 else F.NORTH_EAST


## Torches on the room's walls: on the back walls every few cells, and one back-face torch in the
## middle of each front wall so the room is lit evenly.
func _torches(r: Rect2i, walls: Dictionary, doorways: Dictionary, entities: Node2D, root: Node, rn: String) -> void:
	var spots := []
	var step := 4
	for x in range(r.position.x + 1, r.end.x - 1, step):
		spots.append([Vector2i(x, r.position.y - 1), Torch.Face.LEFT])
	for y in range(r.position.y + 1, r.end.y - 1, step):
		spots.append([Vector2i(r.position.x - 1, y), Torch.Face.RIGHT])
	spots.append([Vector2i(r.position.x + r.size.x / 2, r.end.y), Torch.Face.BACK_RIGHT])
	spots.append([Vector2i(r.end.x, r.position.y + r.size.y / 2), Torch.Face.BACK_LEFT])
	var used := {}
	for s in spots:
		var c: Vector2i = s[0]
		for shift in [0, 1, -1, 2, -2]:
			var along := Vector2i(1, 0) if s[1] in [Torch.Face.LEFT, Torch.Face.BACK_RIGHT] else Vector2i(0, 1)
			var t: Vector2i = c + along * shift
			if walls.has(t) and not doorways.has(t) and not doorways.has(t + along) and not doorways.has(t - along) and not used.has(t):
				c = t
				break
		if not walls.has(c) or used.has(c) or doorways.has(c):
			continue
		used[c] = true
		var torch := (load("res://scenes/markers/torch.tscn") as PackedScene).instantiate()
		torch.name = "Torch_%s_%d_%d" % [rn, c.x, c.y]
		torch.face = s[1]
		torch.position = IsoGrid.view_cell_to_world(c) + torch._snap_offset()
		_add(entities, torch, root)


# --- the woods ------------------------------------------------------------------------------------------

func _build_surface(d: Dictionary, root_name: String, path: String) -> bool:
	var ok := true
	var floor_cells := {}       # cell -> "grass" / "path" / "forest"
	var rects := {}
	for cn in d.clearings:
		var r: Rect2i = d.clearings[cn].rect
		rects[cn] = r
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var c := Vector2i(x, y)
				# ragged edges: drop a few corner cells
				var corner := (x == r.position.x or x == r.end.x - 1) and (y == r.position.y or y == r.end.y - 1)
				if corner and rnd.randf() < 0.7:
					continue
				var edge := x == r.position.x or x == r.end.x - 1 or y == r.position.y or y == r.end.y - 1
				floor_cells[c] = "forest" if edge and rnd.randf() < 0.6 else "grass"
	var path_cells := {}
	for p in d.paths:
		var a: Vector2i = p[0]
		var b: Vector2i = p[1]
		var c := a
		var wiggle := 0
		while c != b:
			for k in 2:
				var w := c + (Vector2i(0, k) if c.x != b.x else Vector2i(k, 0))
				path_cells[w] = true
			if c.x != b.x:
				c.x += signi(b.x - c.x)
				if rnd.randf() < 0.15 and c.x != b.x:
					wiggle = clampi(wiggle + rnd.randi_range(-1, 1), -1, 1)
			else:
				c.y += signi(b.y - c.y)
		path_cells[b] = true
	for c in path_cells:
		floor_cells[c] = "path"
	# every other cell of the area (and a 2-cell rim) is forest: no holes of void inside the woods
	var walls := {}
	var bounds := Rect2i(floor_cells.keys()[0], Vector2i.ONE)
	for c: Vector2i in floor_cells:
		bounds = bounds.expand(c)
	bounds = bounds.grow(2)
	bounds.size += Vector2i.ONE
	for x in range(bounds.position.x, bounds.end.x):
		for y in range(bounds.position.y, bounds.end.y):
			if not floor_cells.has(Vector2i(x, y)):
				walls[Vector2i(x, y)] = true
	var cliff_cells := {}
	for c in walls:
		for cr: Rect2i in d.cliffs:
			if cr.has_point(c):
				cliff_cells[c] = true

	var root := _make_root(root_name, d.title, "res://assets/tiles/outdoor_tileset.tres", Color(0.56, 0.56, 0.7), d.start_level)
	var floor: TileMapLayer = root.get_node("Floor")
	var wall_layer: TileMapLayer = root.get_node("World/Walls")
	var entities: Node2D = root.get_node("World/Entities")
	var decor: Node2D = root.get_node("World/Decor")
	for c: Vector2i in floor_cells:
		var row: int = {"grass": 0, "path": 1, "forest": 2}[floor_cells[c]]
		floor.set_cell(c, FLOOR_SRC, Vector2i(rnd.randi_range(0, 7), row))
	_paint_walls(wall_layer, walls, FOREST_SRC, cliff_cells)

	var blocked := {}
	var group := 1
	var start_cell := Vector2i.ZERO
	for cn in d.clearings:
		var cl: Dictionary = d.clearings[cn]
		var r: Rect2i = cl.rect
		var o := r.position
		var used := {}
		for c in path_cells:
			used[c] = true                # paths stay clear
		for p in cl.get("props", []):
			_prop(p[0], o + p[1], entities, root, cn)
			used[o + p[1]] = true
			blocked[o + p[1]] = true
		for f in cl.get("campfire", []):
			var b := _inst("brazier", entities, root, o + f, "Campfire_%s" % cn)
			b.campfire = true
			used[o + f] = true
			blocked[o + f] = true
		for ch in cl.get("chests", []):
			var cc: Vector2i = o + ch[2]
			var chest := _inst("chest", entities, root, cc, "Chest_%s" % cn)
			chest.gold = ch[0]
			chest.items.assign(ch[1])
			used[cc] = true
			blocked[cc] = true
		for b: Vector2i in cl.get("bones", []):
			_bones(decor, root, o + b, cn)
		var entry_cells: Array = []
		if cl.has("start"):
			var ps := _inst("party_start", entities, root, o + cl.start[0], "PartyStart")
			ps.facing = cl.start[1]
			start_cell = o + cl.start[0]
		if cl.has("stairs"):
			var s: Array = cl.stairs
			var st := _inst("stairs", entities, root, o + s[0], "Stairs_Mine")
			st.cave = true
			st.target_map = s[1]
			st.target_entry = s[2]
			used[o + s[0]] = true
			blocked[o + s[0]] = true
			var a: Array = cl.arrive
			var ap := _inst("party_start", entities, root, o + a[0], "PartyStart_" + a[1])
			ap.entry_id = a[1]
			ap.facing = a[2]
			for dx in range(-1, 2):
				for dy in range(-1, 3):
					used[o + s[0] + Vector2i(dx, dy)] = true
		# a few trees and bushes round the edge of the glade (not on the paths)
		for c: Vector2i in _edge_cells(r):
			if floor_cells.has(c) and not used.has(c) and not _crowded(c, used) and rnd.randf() < 0.22:
				var kind: String = ["pine", "oak", "bush", "pine"][rnd.randi_range(0, 3)]
				_prop(kind, c, entities, root, cn)
				used[c] = true
				blocked[c] = true
		# entrances: where paths touch the clearing (monsters face them)
		for c in path_cells:
			if r.grow(1).has_point(c) and not r.has_point(c):
				entry_cells.append(c)
		if entry_cells.is_empty():
			entry_cells.append(r.get_center())
		var spawn: String = cl.get("spawn", "")
		if spawn != "":
			var keep := {}
			for e: Vector2i in entry_cells:
				for dx in range(-2, 3):
					for dy in range(-2, 3):
						keep[e + Vector2i(dx, dy)] = true
			var free := {}
			for c in used:
				if not path_cells.has(c):
					free[c] = true
			var cells := _monster_cells(r, spawn.length(), entry_cells, keep, free)
			for i in spawn.length():
				if i >= cells.size():
					push_error("%s: no room for monster %d in %s" % [root_name, i, cn])
					ok = false
					break
				var id: String = MONSTERS[spawn[i]]
				var mc: Vector2i = cells[i]
				var sp := _inst("monster_spawn", entities, root, mc, "%s_%s_%d_%d" % [id.to_pascal_case(), cn, mc.x, mc.y])
				sp.monster_id = id
				sp.group_id = group
				sp.facing = _facing_toward(mc, entry_cells)
				_set_preview(sp, id)
			group += 1
	# lone trees along the paths outside the clearings make the paths read as forest tracks
	(root.get_node("Camera") as Camera2D).position = IsoGrid.view_cell_to_world(start_cell)
	ok = _check(root_name, floor_cells, blocked, start_cell, rects) and ok
	_save(root, path)
	return ok


# --- shared ------------------------------------------------------------------------------------------

## Wall blocks: the row (faces shown) follows from the neighbours, like the rotated views. Cells in
## `alt` use the cliff source instead of `src`.
func _paint_walls(layer: TileMapLayer, walls: Dictionary, src: int, alt: Dictionary) -> void:
	for c: Vector2i in walls:
		var left := not walls.has(c + Vector2i(0, 1))
		var right := not walls.has(c + Vector2i(1, 0))
		var row := WallRow.CAP
		if left and right:
			row = WallRow.BOTH
		elif left:
			row = WallRow.FACE_L
		elif right:
			row = WallRow.FACE_R
		layer.set_cell(c, WALL_SRC if alt.has(c) else src, Vector2i(rnd.randi_range(0, 3), row))


func _prop(kind: String, c: Vector2i, entities: Node2D, root: Node, area: String) -> void:
	var prop := _inst("prop", entities, root, c, "%s_%s_%d_%d" % [kind.capitalize(), area, c.x, c.y])
	prop.kind = PROPS[kind]


func _web(decor: Node2D, root: Node, o: Vector2i, rn: String) -> void:
	var web := Sprite2D.new()
	web.name = "Web_" + rn
	web.texture = load("res://assets/sprites/props/web.png")
	web.centered = false
	web.offset = Vector2(-27, -34)
	web.position = IsoGrid.view_cell_to_world(o) + Vector2(0, -7)
	web.add_to_group("wall_decor", true)
	_add(decor, web, root)


func _bones(decor: Node2D, root: Node, c: Vector2i, rn: String) -> void:
	var bones := Sprite2D.new()
	bones.name = "Bones_%s_%d_%d" % [rn, c.x, c.y]
	bones.texture = load("res://assets/sprites/props/bones.png")
	bones.centered = false
	bones.offset = Vector2(-7, -6)
	bones.position = IsoGrid.view_cell_to_world(c)
	_add(decor, bones, root)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rnd.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## Every room / clearing must be reachable from the start on foot (props, chests and braziers
## block; doors don't), and every chest must have a free cell next to it.
func _check(root_name: String, floor_cells: Dictionary, blocked: Dictionary, start: Vector2i, rects: Dictionary) -> bool:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = c + n
			if floor_cells.has(nc) and not blocked.has(nc) and not seen.has(nc):
				seen[nc] = true
				queue.append(nc)
	var ok := true
	for rn in rects:
		var r: Rect2i = rects[rn]
		var any := false
		for c in _interior(r):
			if seen.has(c):
				any = true
				break
		if not any:
			push_error("%s: %s can't be reached" % [root_name, rn])
			ok = false
	for b: Vector2i in blocked:
		var reach := false
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			if seen.has(b + n):
				reach = true
		if not reach:
			push_error("%s: %s is walled in by props" % [root_name, b])
			ok = false
	var floors := 0
	for c in floor_cells:
		floors += 1
	print("build_dungeon: %s %d floor cells, %d reachable, %d areas %s" % [root_name, floors, seen.size(), rects.size(), "ok" if ok else "PROBLEMS"])
	return ok


func _set_preview(sp: Node, id: String) -> void:
	match id:
		"eye_tyrant":
			sp.preview = load("res://assets/sprites/monsters/eye_tyrant_32.png")
			sp.preview_offset = Vector2(-16, -33)
		"giant_spider":
			sp.preview = load("res://assets/sprites/monsters/giant_spider_preview.png")
			sp.preview_offset = Vector2(-20, -27)
		_:
			var tex: Texture2D = load("res://assets/sprites/monsters/%s_sheet.png" % id)
			var cell := Vector2(tex.get_width() / 17.0, tex.get_height() / 2.0)
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(Vector2.ZERO, cell)
			sp.preview = at
			sp.preview_offset = Vector2(-cell.x / 2.0, -(cell.y - 2.0))


func _inst(scene: String, parent: Node, root: Node, cell: Vector2i, node_name: String) -> Node2D:
	var n: Node2D = (load("res://scenes/markers/%s.tscn" % scene) as PackedScene).instantiate()
	n.name = node_name
	n.position = IsoGrid.view_cell_to_world(cell)
	_add(parent, n, root)
	return n


func _add(parent: Node, n: Node, root: Node) -> void:
	parent.add_child(n)
	n.owner = root


func _make_root(root_name: String, title: String, tileset: String, ambient: Color, start_level: int) -> Node2D:
	var root := Node2D.new()
	root.name = root_name
	root.set_script(load("res://scripts/maps/dungeon_map.gd"))
	root.map_title = title
	root.start_level = start_level
	var ts: TileSet = load(tileset)
	var amb := CanvasModulate.new()
	amb.name = "Ambient"
	amb.color = ambient
	_add(root, amb, root)
	var floor := TileMapLayer.new()
	floor.name = "Floor"
	floor.tile_set = ts
	_add(root, floor, root)
	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	_add(root, world, root)
	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = ts
	walls.y_sort_enabled = true
	_add(world, walls, root)
	for nm in ["Entities", "Decor"]:
		var n := Node2D.new()
		n.name = nm
		n.y_sort_enabled = true
		_add(world, n, root)
	var cam := Camera2D.new()
	cam.name = "Camera"
	_add(root, cam, root)
	return root


func _save(root: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps, path)
	print("build_dungeon: ", path, " ", "ok" if err == OK else "ERROR %d" % err)
	root.free()
