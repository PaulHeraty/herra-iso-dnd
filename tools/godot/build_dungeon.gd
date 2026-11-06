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
## Phase 6 (dungeon features):
##   name + desc     a RoomNote over the room: its description shows the first time the party walks in
##   clue            instead of desc: a modal note (inscriptions, puzzle rules) in the dialogue box
##   traps           [{t = spikes / darts / fire / pit / alarm, at = cell in the room or "auto",
##                    detect, disarm, save, dmg, type, atk, xp, one_shot}]
##   puzzle          {kind = sequence / blocks / ring / riddle / lever, link, opens, ...} (_puzzle)
##   link options    {secret = true, sdc, link}: a secret door (on the SECOND room's wall: list the
##                   hidden room first); {gate = "name"}: a portcullis opened by the puzzle whose
##                   `opens` (or lever whose link) is "name"; {trap = {...}}: a trap mid-corridor
## THE WOODS are clearings joined by dirt paths; every cell near them is a block of forest (or
## cliff in the cliff zones), so the clearings read as glades in a dense wood.

const F = PartyStart.Facing
const FLOOR_SRC := 0
const WALL_SRC := 1
const FOREST_SRC := 2
enum WallRow { FACE_L, FACE_R, BOTH, CAP }
const SLOT := Vector2i(15, 13)
const TRAP_TYPES := {"spikes": Trap.TrapType.SPIKES, "darts": Trap.TrapType.DARTS, "fire": Trap.TrapType.FIRE_JET,
	"pit": Trap.TrapType.PIT, "alarm": Trap.TrapType.ALARM}
## default damage type, one_shot
const TRAP_DEFAULTS := {"spikes": ["piercing", false], "darts": ["poison", false], "fire": ["fire", false],
	"pit": ["bludgeoning", true], "alarm": ["", true]}
const SYMBOLS := {"sun": Lever.Symbol.SUN, "moon": Lever.Symbol.MOON, "star": Lever.Symbol.STAR,
	"skull": Lever.Symbol.SKULL, "eye": Lever.Symbol.EYE}

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
	"tent": Prop.Kind.TENT, "grave": Prop.Kind.GRAVE, "stall": Prop.Kind.STALL,
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
			"start": true, "name": "Entrance Hall",
			"desc": "Steps climb back up to daylight. The air smells of dust and old smoke, and somewhere a cold draught seeps through the stonework."},
		"B": {"slot": Vector2i(0, 1), "size": Vector2i(10, 7), "theme": "guard", "spawn": "kkk",
			"chests": [[30, ["mace_plus1", "potion_healing"]]], "name": "Guardroom",
			"desc": "Rusted weapon racks and an overturned table. The guards who kept watch here never left their posts."},
		"C": {"slot": Vector2i(1, 1), "size": Vector2i(8, 6), "theme": "store", "spawn": "rrrrrr",
			"chests": [[40, ["potion_healing", "potion_healing", "crypt_key", "scroll_cure_wounds", "scroll_burning_hands"], 12]],
			"name": "Storeroom", "desc": "Rotten sacks and split crates. Something has been nesting in the grain."},
		"D": {"slot": Vector2i(1, 2), "size": Vector2i(9, 9), "theme": "crypt", "spawn": "kku",
			"chests": [[120, ["longsword_plus1", "studded_leather_plus1", "scroll_magic_missile"]]],
			"name": "The Old Crypt", "desc": "Stone coffins in rows. Some of the lids have been pushed aside from within."},
		"E": {"slot": Vector2i(2, 1), "size": Vector2i(10, 9), "theme": "nest", "spawn": "SS",
			"chests": [[45, ["ring_free_action", "shortbow_plus1"]]],
			"name": "Webbed Gallery", "desc": "Thick webs sag from the ceiling, heavy with wrapped shapes."},
		"F": {"slot": Vector2i(2, 2), "size": Vector2i(9, 7), "theme": "tomb", "spawn": "zzzz",
			"chests": [[35, ["potion_healing", "scroll_healing_word", "breastplate"]]],
			"name": "Burial Hall", "desc": "The dead were laid to rest here with honour. They are not resting now."},
		"G": {"slot": Vector2i(0, 0), "size": Vector2i(8, 8), "theme": "flooded", "spawn": "rrrrz",
			"name": "Flooded Cellar", "desc": "Black water has pooled across the floor. Things move in it."},
		"H": {"slot": Vector2i(1, 0), "size": Vector2i(10, 7), "theme": "barracks", "spawn": "kkkk",
			"chests": [[25, ["battleaxe", "scimitar", "potion_healing"]]],
			"name": "Barracks", "desc": "Rows of mouldering bunks. Whoever slept in them sleeps no longer."},
		"I": {"slot": Vector2i(2, 0), "size": Vector2i(8, 7), "theme": "ossuary", "spawn": "uu",
			"name": "Ossuary", "desc": "Skulls stacked to the ceiling, watching with empty eyes."},
		"J": {"slot": Vector2i(3, 0), "size": Vector2i(9, 7), "theme": "store", "spawn": "kkzz",
			"chests": [[50, ["heavy_crossbow", "potion_healing", "scroll_bless"]]],
			"name": "Quartermaster's Store", "desc": "Barrels and crates: the old garrison's supplies, mostly spoiled."},
		"K": {"slot": Vector2i(3, 1), "size": Vector2i(9, 8), "theme": "nest", "spawn": "Skk",
			"traps": [{"t": "spikes", "at": "auto", "detect": 14, "disarm": 13, "save": 12, "dmg": "2d6"}],
			"name": "Spider Hall", "desc": "Webs everywhere, and the dry click of many legs in the dark."},
		"L": {"slot": Vector2i(3, 2), "size": Vector2i(8, 7), "theme": "hall", "spawn": "kku",
			"stairs": [false, "res://scenes/maps/dungeon_2.tscn", "from_above"], "arrive": "from_below",
			"name": "Lower Stair", "desc": "A stair winds down into the dark. A cold breath rises from below."},
		# Phase 6: a strongroom behind a secret door in the entrance hall
		"S": {"slot": Vector2i(0, 3), "size": Vector2i(7, 5), "theme": "bare",
			"chests": [[80, ["potion_healing", "potion_healing", "scroll_magic_missile", "dagger_plus1"]]],
			"name": "Hidden Strongroom", "desc": "A forgotten strongroom behind the wall, dry and silent. Someone hid this well."},
		# Phase 6: the first puzzle - three levers in the right order lift the vault's portcullis
		"N": {"slot": Vector2i(2, 3), "size": Vector2i(9, 7), "theme": "bare", "name": "The Hall of Hours",
			"clue": "Three levers stand along the wall, each marked with a sign: a sun, a moon and a star. Words are cut deep in the stone above them:\n\"The sun wakes first. The moon walks after. The stars keep the last watch.\"",
			"puzzle": {"kind": "sequence", "link": "d1_hours", "opens": "d1_vault", "solution": "sun,moon,star",
				"levers": [["moon", Vector2i(0, 1)], ["star", Vector2i(0, 3)], ["sun", Vector2i(7, 0)]],
				"penalty": "1d4", "xp": 150, "solved_text": "The last lever locks down, and chains rattle: the portcullis is rising!"}},
		"O": {"slot": Vector2i(3, 3), "size": Vector2i(7, 6), "theme": "hall",
			"chests": [[180, ["shield_plus1", "potion_greater_healing", "scroll_scorching_ray"]]],
			"name": "The Lords' Vault", "desc": "The old lords kept their treasure here, behind iron bars."},
	},
	"links": [["A", "B", {"trap": {"t": "spikes", "detect": 12, "disarm": 12, "save": 12, "dmg": "2d6"}}],
		["B", "C"], ["A", "D", {"locked": 13, "key": "crypt"}],
		["B", "G", {"trap": {"t": "darts", "detect": 15, "disarm": 13, "atk": 5, "dmg": "2d4"}}], ["G", "H"],
		["H", "I"], ["C", "E"], ["E", "I"], ["I", "J", {"trap": {"t": "pit", "detect": 16, "disarm": 13, "save": 12, "dmg": "2d6", "xp": 30}}],
		["J", "K"], ["K", "L"], ["E", "F"], ["D", "F"], ["F", "L"],
		["S", "A", {"secret": true, "sdc": 15}], ["F", "N"], ["N", "O", {"gate": "d1_vault"}]],
}

var DUNGEON_2 := {
	"title": "The Webbed Deep", "start_level": 3,
	"rooms": {
		"A": {"slot": Vector2i(0, 0), "size": Vector2i(7, 7), "theme": "hall",
			"stairs": [true, "res://scenes/maps/dungeon_1.tscn", "from_below"], "arrive": "from_above", "start": true,
			"chests": [[20, ["dagger_plus1", "potion_healing"]]],
			"name": "Webbed Stair", "desc": "The stair from the halls above opens into a cave choked with old webs."},
		"B": {"slot": Vector2i(1, 0), "size": Vector2i(10, 8), "theme": "ossuary", "spawn": "kkkk",
			"chests": [[60, ["potion_greater_healing", "lair_key", "scroll_lightning_bolt", "shield_plus1"]]],
			"name": "Bone Chapel", "desc": "Bones arranged with care into arches and pillars. The dead here still keep house."},
		"C": {"slot": Vector2i(0, 1), "size": Vector2i(11, 9), "theme": "nest", "spawn": "SSS",
			"chests": [[80, ["ring_resistance", "rapier_plus1", "potion_healing"]]],
			"name": "Brood Cavern", "desc": "Egg sacs as big as barrels hang in clusters. Their mothers are near."},
		"D": {"slot": Vector2i(2, 0), "size": Vector2i(9, 8), "theme": "nest", "spawn": "SS",
			"name": "Silk Tunnels", "desc": "The walls are papered with silk. It trembles as you pass."},
		"E": {"slot": Vector2i(1, 1), "size": Vector2i(9, 8), "theme": "ossuary", "spawn": "uuu",
			"chests": [[40, ["scroll_hold_person", "potion_greater_healing", "morningstar"]]],
			"name": "Charnel Pit", "desc": "Picked-clean bones and the stink of rot. Ghouls feed here."},
		"F": {"slot": Vector2i(2, 1), "size": Vector2i(10, 8), "theme": "flooded", "spawn": "zzzzzz",
			"name": "Drowned Hall", "desc": "Knee-deep water, cold as the grave. Shapes shamble through it."},
		"G": {"slot": Vector2i(0, 2), "size": Vector2i(9, 7), "theme": "nest", "spawn": "Srrrr",
			"traps": [{"t": "spikes", "at": "auto", "detect": 15, "disarm": 13, "save": 13, "dmg": "2d6", "xp": 30}],
			"name": "The Larder", "desc": "Wrapped bodies hang from the ceiling, waiting to be eaten."},
		# the Eye Tyrant's lair: the Bone Key (ossuary) opens it
		"H": {"slot": Vector2i(1, 2), "size": Vector2i(11, 9), "theme": "lair", "spawn": "Ekk",
			"chests": [[300, ["ring_protection", "chain_mail_plus1", "potion_greater_healing", "scroll_fireball"]]],
			"name": "The Eye's Lair", "desc": "A vast domed chamber, its floor scarred by rays of power. Something lives here that hates every eye but its own."},
		"I": {"slot": Vector2i(2, 2), "size": Vector2i(8, 7), "theme": "hall", "spawn": "ukk",
			"stairs": [false, "res://scenes/maps/dungeon_3.tscn", "from_above"], "arrive": "from_below",
			"name": "Lower Stair", "desc": "Steps lead down toward the warrens. A cold draught tugs at the torch flames from one wall."},
		"J": {"slot": Vector2i(3, 1), "size": Vector2i(9, 8), "theme": "nest", "spawn": "SS",
			"chests": [[70, ["potion_healing", "potion_healing", "scroll_scorching_ray"]]],
			"name": "Silk Gallery", "desc": "A long gallery hung with curtains of web."},
		# Phase 6: push the blocks onto the plates and the treasury's portcullis lifts
		"K": {"slot": Vector2i(3, 0), "size": Vector2i(10, 8), "theme": "bare", "name": "The Weighing Room",
			"clue": "Two worn plates are set into the floor, and two great blocks of carved stone stand near them. Beyond a portcullis on the far side, something glitters. A lever by the wall bears a circling arrow.",
			"puzzle": {"kind": "blocks", "link": "d2_weigh", "opens": "d2_vault", "xp": 200,
				"plates": [Vector2i(3, 1), Vector2i(6, 5)], "blocks": [Vector2i(3, 5), Vector2i(4, 3)], "reset": Vector2i(9, 0),
				"solved_text": "Both plates sink home with a deep thud, and chains rattle: the portcullis is rising!"}},
		"L": {"slot": Vector2i(4, 0), "size": Vector2i(7, 6), "theme": "hall",
			"chests": [[220, ["studded_leather_plus1", "potion_greater_healing", "potion_greater_healing", "scroll_hold_person"]]],
			"name": "Hidden Treasury", "desc": "A small vault, untouched for an age. Dust lies thick on everything."},
		# Phase 6: a hermit's hole behind a secret door in the stair room
		"M": {"slot": Vector2i(3, 2), "size": Vector2i(7, 6), "theme": "bare",
			"chests": [[90, ["ring_free_action", "potion_healing", "scroll_cure_wounds"]]],
			"name": "Hermit's Hole", "desc": "Someone lived here once, hidden from the spiders. Their bones sit by a long-dead fire."},
	},
	"links": [["A", "B"], ["A", "C", {"trap": {"t": "pit", "detect": 14, "disarm": 13, "save": 13, "dmg": "2d6"}}],
		["B", "D"], ["B", "E", {"trap": {"t": "spikes", "detect": 16, "disarm": 14, "save": 13, "dmg": "2d6", "xp": 35}}],
		["C", "E"], ["D", "F"], ["E", "F"], ["C", "G"],
		["G", "H", {"locked": 0, "key": "lair"}], ["H", "I"],
		["F", "J", {"trap": {"t": "darts", "detect": 15, "disarm": 14, "atk": 6, "dmg": "2d6", "xp": 30}}],
		["D", "K"], ["K", "L", {"gate": "d2_vault"}], ["M", "I", {"secret": true, "sdc": 16}]],
}

var DUNGEON_3 := {
	"title": "The Goblin Warrens", "start_level": 3,
	"rooms": {
		"A": {"slot": Vector2i(0, 0), "size": Vector2i(8, 7), "theme": "warren",
			"stairs": [true, "res://scenes/maps/dungeon_2.tscn", "from_below"], "arrive": "from_above", "start": true,
			"name": "Warren Mouth", "desc": "Crude goblin daubings cover the walls. The smell is awful. Goblins love their tripwires."},
		"B": {"slot": Vector2i(1, 0), "size": Vector2i(11, 8), "theme": "warren", "spawn": "gggggg",
			"chests": [[35, ["potion_healing", "potion_healing"]]],
			"traps": [{"t": "pit", "at": "auto", "detect": 14, "disarm": 13, "save": 13, "dmg": "2d6", "xp": 30}],
			"name": "Goblin Den", "desc": "Filthy bedding and gnawed bones. A whole tribe sleeps here."},
		"C": {"slot": Vector2i(0, 1), "size": Vector2i(9, 8), "theme": "kennel", "spawn": "wwwwgg",
			"name": "Kennels", "desc": "Chains, bones and the stink of wolf."},
		"D": {"slot": Vector2i(2, 0), "size": Vector2i(10, 7), "theme": "barracks", "spawn": "hhh",
			"chests": [[60, ["scimitar_plus1", "potion_greater_healing", "half_plate"]]],
			"puzzle": {"kind": "lever", "link": "d3_hoard", "at": Vector2i(2, 0)},
			"name": "Hobgoblin Barracks", "desc": "Neat rows of bunks and polished gear: hobgoblins, not goblins. An iron lever juts up by the back wall."},
		"E": {"slot": Vector2i(1, 1), "size": Vector2i(9, 8), "theme": "warren", "spawn": "BB",
			"chests": [[50, ["greataxe", "potion_greater_healing", "scroll_scorching_ray"]]],
			"traps": [{"t": "spikes", "at": "auto", "detect": 15, "disarm": 14, "save": 13, "dmg": "2d8", "xp": 40}],
			"name": "Bugbear Lair", "desc": "Huge furs heaped in the corners. Something big sleeps here."},
		"F": {"slot": Vector2i(2, 1), "size": Vector2i(10, 8), "theme": "barracks", "spawn": "ggggh",
			"name": "Guard Post", "desc": "A rusted portcullis bars the way east. Goblin scratchings beside it show a lever, and an arrow pointing back toward the hobgoblins' barracks."},
		"G": {"slot": Vector2i(0, 2), "size": Vector2i(10, 9), "theme": "kennel", "spawn": "O",
			"name": "Ogre's Pen", "desc": "The floor is trampled flat and the bones are big ones. An ogre lives here."},
		"H": {"slot": Vector2i(1, 2), "size": Vector2i(9, 8), "theme": "throne", "spawn": "Ghh",
			"chests": [[90, ["warren_key", "potion_greater_healing", "longbow_plus1"]]],
			"name": "Chief's Hall", "desc": "A throne of piled skulls and stolen silver."},
		# the war room: locked (the Chief's Key, or pick DC 15)
		"I": {"slot": Vector2i(2, 2), "size": Vector2i(10, 8), "theme": "barracks", "spawn": "Ohh",
			"name": "War Room", "desc": "Maps of the woods pinned to the wall with daggers. The goblins were planning a raid."},
		"J": {"slot": Vector2i(3, 2), "size": Vector2i(11, 9), "theme": "throne", "spawn": "GBBhh",
			"chests": [[250, ["longsword_plus2", "potion_superior_healing", "scroll_hold_person"]]],
			"stairs": [false, "res://scenes/maps/dungeon_4.tscn", "from_above"], "arrive": "from_below",
			"name": "Throne of the Deep", "desc": "The goblin king's true seat, and beneath it, the way down."},
		# behind the portcullis: the lever in the hobgoblins' barracks lifts it
		"K": {"slot": Vector2i(3, 1), "size": Vector2i(8, 7), "theme": "store", "spawn": "hh",
			"chests": [[400, ["warhammer_plus1", "breastplate_plus1", "potion_greater_healing", "scroll_fireball"]]],
			"name": "Goblin Hoard", "desc": "The tribe's treasure, piled high behind the portcullis."},
		# Phase 6: a secret cubby behind the barracks wall
		"L": {"slot": Vector2i(3, 0), "size": Vector2i(7, 5), "theme": "bare",
			"chests": [[120, ["potion_greater_healing", "scroll_lightning_bolt", "ring_resistance"]]],
			"name": "Chief's Stash", "desc": "A cubby behind the barracks wall, where someone hid the best of the loot from the rest of the tribe."},
	},
	"links": [["A", "B", {"trap": {"t": "alarm", "detect": 13, "disarm": 12, "xp": 25}}], ["A", "C"], ["B", "D"], ["B", "E"],
		["C", "E"], ["D", "F"], ["E", "F"], ["C", "G", {"trap": {"t": "alarm", "detect": 15, "disarm": 12, "xp": 25}}],
		["E", "H", {"trap": {"t": "alarm", "detect": 16, "disarm": 13, "xp": 30}}], ["G", "H"],
		["H", "I", {"locked": 15, "key": "warren"}], ["I", "J"], ["F", "K", {"gate": "d3_hoard"}],
		["L", "D", {"secret": true, "sdc": 14}]],
}

var DUNGEON_4 := {
	"title": "The Sunken Crypts", "start_level": 4,
	"rooms": {
		"A": {"slot": Vector2i(0, 0), "size": Vector2i(8, 7), "theme": "flooded",
			"stairs": [true, "res://scenes/maps/dungeon_3.tscn", "from_below"], "arrive": "from_above", "start": true,
			"name": "Flooded Stair", "desc": "Water runs down the steps and pools below. Everything smells of the grave."},
		"B": {"slot": Vector2i(1, 0), "size": Vector2i(10, 8), "theme": "ossuary", "spawn": "uuu",
			"name": "Bone Gallery", "desc": "Niches full of bones line the walls, and some of the bones are fresh."},
		"C": {"slot": Vector2i(0, 1), "size": Vector2i(10, 8), "theme": "ossuary", "spawn": "kkkkkk",
			"chests": [[70, ["mace_of_disruption", "potion_greater_healing"]]],
			"name": "Ossuary Deep", "desc": "Skeletons stand in rows, as if waiting for orders."},
		"D": {"slot": Vector2i(2, 0), "size": Vector2i(10, 8), "theme": "tomb", "spawn": "Wzzz",
			"chests": [[120, ["ring_resistance_necrotic", "potion_greater_healing"]]],
			"name": "Tomb of the Knight", "desc": "A sealed sarcophagus, and a chill in the air that is more than cold."},
		"E": {"slot": Vector2i(1, 1), "size": Vector2i(9, 8), "theme": "crypt", "spawn": "pp",
			"name": "Chapel of Whispers", "desc": "Faint voices whisper just out of hearing."},
		"F": {"slot": Vector2i(2, 1), "size": Vector2i(10, 8), "theme": "flooded", "spawn": "Uuu",
			"name": "Sunken Hall", "desc": "Black water up to the knees. Something cold brushes past your legs."},
		"G": {"slot": Vector2i(0, 2), "size": Vector2i(11, 9), "theme": "flooded", "spawn": "zzzzzzzzzu",
			"traps": [{"t": "pit", "at": "auto", "detect": 14, "disarm": 14, "save": 14, "dmg": "3d6", "xp": 40}],
			"name": "Drowned Crypt", "desc": "Bloated dead stir in the flooded crypt."},
		"H": {"slot": Vector2i(1, 2), "size": Vector2i(9, 8), "theme": "tomb", "spawn": "M",
			"chests": [[90, ["potion_superior_healing", "scroll_mass_healing_word", "scroll_hold_person"]]],
			"name": "The Embalmer's Tomb", "desc": "Linen wrappings and jars of spice. One sarcophagus stands open, and empty."},
		"I": {"slot": Vector2i(2, 2), "size": Vector2i(11, 9), "theme": "crypt", "spawn": "WW",
			"chests": [[200, ["plate_armor_plus1", "shortbow_plus2", "potion_greater_healing"]]],
			"name": "Crypt of the Wights", "desc": "Two stone thrones face the door. Their sitters are not dead enough."},
		"J": {"slot": Vector2i(3, 2), "size": Vector2i(9, 8), "theme": "tomb", "spawn": "UU",
			"stairs": [false, "res://scenes/maps/dungeon_5.tscn", "from_above"], "arrive": "from_below",
			"name": "Lower Stair", "desc": "The way down to the Sealed Vault. The walls are carved with warnings."},
		"K": {"slot": Vector2i(3, 1), "size": Vector2i(8, 7), "theme": "crypt", "spawn": "uukk",
			"chests": [[110, ["rapier_plus2", "potion_superior_healing"]]],
			"name": "Forgotten Crypt", "desc": "A side crypt few remember, and fewer visit."},
		# Phase 6: the ring of five fires - light them all and the reliquary opens
		"L": {"slot": Vector2i(3, 0), "size": Vector2i(9, 8), "theme": "bare", "name": "Chapel of Five Fires",
			"clue": "Five bowls of black iron stand in a ring, two of them burning. Words run round the floor between them:\n\"Kindle all five for the dead, and the way will open. But the fires are kin: touch one, and the two beside it answer.\"",
			"puzzle": {"kind": "ring", "link": "d4_fires", "opens": "d4_vault", "xp": 250,
				"braziers": [Vector2i(4, 0), Vector2i(6, 2), Vector2i(5, 5), Vector2i(2, 5), Vector2i(1, 2)], "lit": [1, 0, 0, 1, 0],
				"solved_text": "All five fires roar up at once, and chains rattle: the reliquary's portcullis is rising!"}},
		"M": {"slot": Vector2i(4, 0), "size": Vector2i(7, 6), "theme": "hall",
			"chests": [[260, ["mace_plus2", "potion_superior_healing", "scroll_mass_healing_word", "scroll_fireball"]]],
			"name": "Reliquary", "desc": "Relics of a forgotten order of knights, kept safe behind iron bars."},
	},
	"links": [["A", "B", {"trap": {"t": "fire", "detect": 15, "disarm": 14, "save": 13, "dmg": "3d6", "xp": 40}}], ["A", "C"],
		["B", "D"], ["B", "E"], ["C", "E"], ["C", "G", {"trap": {"t": "darts", "detect": 16, "disarm": 14, "atk": 7, "dmg": "2d8", "xp": 40}}],
		["D", "F"], ["E", "F"], ["E", "H", {"trap": {"t": "fire", "detect": 16, "disarm": 15, "save": 14, "dmg": "3d6", "xp": 45}}],
		["G", "H"], ["F", "I"], ["H", "I"], ["I", "J"], ["F", "K"], ["K", "J"],
		["D", "L"], ["L", "M", {"gate": "d4_vault"}]],
}

var DUNGEON_5 := {
	"title": "The Sealed Vault", "start_level": 4,
	"rooms": {
		"A": {"slot": Vector2i(0, 0), "size": Vector2i(8, 7), "theme": "hall",
			"stairs": [true, "res://scenes/maps/dungeon_4.tscn", "from_below"], "arrive": "from_above", "start": true,
			"name": "Vault Stair", "desc": "The last stair. The air down here is still, and very cold."},
		"B": {"slot": Vector2i(1, 0), "size": Vector2i(10, 8), "theme": "tomb", "spawn": "M",
			"chests": [[80, ["potion_superior_healing", "scroll_mass_healing_word"]]],
			"name": "Antechamber", "desc": "A mummified guardian stands in its alcove, wrapped in rotting linen."},
		"C": {"slot": Vector2i(0, 1), "size": Vector2i(10, 8), "theme": "crypt", "spawn": "pppkk",
			"name": "Hall of Specters", "desc": "Pale lights drift between the coffins."},
		"D": {"slot": Vector2i(2, 0), "size": Vector2i(10, 8), "theme": "tomb", "spawn": "Wkkkkkk",
			"chests": [[120, ["studded_leather_plus2", "potion_superior_healing"]]],
			"name": "Bone Throne", "desc": "Skeletons kneel before an empty throne."},
		"E": {"slot": Vector2i(1, 1), "size": Vector2i(11, 9), "theme": "vault", "spawn": "MM",
			"chests": [[200, ["flame_tongue", "scroll_fireball", "potion_greater_healing"]]],
			"traps": [{"t": "pit", "at": "auto", "detect": 15, "disarm": 15, "save": 14, "dmg": "3d6", "xp": 50}],
			"name": "Treasure Vault", "desc": "Gold glints between the pillars, guarded by the dead."},
		"F": {"slot": Vector2i(2, 1), "size": Vector2i(10, 9), "theme": "ossuary", "spawn": "UUuu",
			"name": "Ghast Pit", "desc": "The stench of the grave is overpowering."},
		"G": {"slot": Vector2i(0, 2), "size": Vector2i(10, 8), "theme": "flooded", "spawn": "zzzzzz",
			"chests": [[60, ["mace_plus2", "potion_greater_healing"]]],
			"name": "Flooded Vault", "desc": "Black water, and the dead rising out of it."},
		"H": {"slot": Vector2i(1, 2), "size": Vector2i(10, 8), "theme": "barracks", "spawn": "WW",
			"chests": [[150, ["vault_key", "half_plate_plus1", "potion_superior_healing"]]],
			"name": "Wights' Barracks", "desc": "Wights stand guard here over something precious."},
		"I": {"slot": Vector2i(2, 2), "size": Vector2i(9, 8), "theme": "tomb", "spawn": "Mzz",
			"name": "Last Gate", "desc": "Beyond this lies the Wraith's vault. A great lock shaped like a sun waits for its key."},
		# the Wraith's vault: only the Sun Key opens it
		"J": {"slot": Vector2i(3, 2), "size": Vector2i(11, 9), "theme": "vault", "spawn": "Xp",
			"chests": [[1000, ["ring_protection", "shield_plus2", "potion_superior_healing", "scroll_mass_healing_word"]]],
			"name": "The Wraith's Vault", "desc": "A crown on a throne of black stone. The air itself grows hungry."},
		# Phase 6: the speaking stone - the right answer opens a secret door to the kings' hoard
		"K": {"slot": Vector2i(3, 1), "size": Vector2i(9, 8), "theme": "hall", "name": "Hall of the Speaking Stone",
			"desc": "A carved stone head sits on a pedestal, its eyes glowing amber. It seems to be waiting for you.",
			"puzzle": {"kind": "riddle", "link": "d5_riddle", "at": Vector2i(6, 1), "damage": "3d6", "xp": 300,
				"riddle": "\"I wore a crown, and I wear one still, though no head lies under it. I walk these halls and my feet make no sound. Plain steel passes through me, and I hunger for the warmth of the living. Name me, and the way is yours.\"",
				"answers": ["A wraith", "A ghost", "The wind", "Your shadow"], "correct": 0}},
		"L": {"slot": Vector2i(3, 0), "size": Vector2i(8, 6), "theme": "hall",
			"chests": [[350, ["potion_superior_healing", "potion_superior_healing", "scroll_fireball", "longsword_plus2"]]],
			"name": "The Kings' Hoard", "desc": "The hidden hoard of the lords who ruled the vault before the Wraith."},
	},
	"links": [["A", "B"], ["A", "C", {"trap": {"t": "fire", "detect": 15, "disarm": 15, "save": 14, "dmg": "4d6", "xp": 50}}],
		["B", "D"], ["B", "E"], ["C", "E"], ["C", "G"],
		["D", "F", {"trap": {"t": "darts", "detect": 15, "disarm": 15, "atk": 7, "dmg": "2d10", "xp": 50}}], ["E", "F"],
		["G", "H", {"trap": {"t": "spikes", "detect": 16, "disarm": 15, "save": 14, "dmg": "3d6", "xp": 50}}],
		["E", "H"], ["F", "I"], ["H", "I"], ["I", "J", {"locked": 0, "key": "vault"}],
		["F", "K"], ["L", "K", {"secret": true, "sdc": 18, "link": "d5_riddle"}]],
}

# --- the woods ------------------------------------------------------------------------------------

var SURFACE := {
	"title": "The Harrow Woods", "start_level": 1,
	# clearings: rect + content (cells relative to the clearing)
	"clearings": {
		"start": {"rect": Rect2i(4, 40, 11, 8), "start": [Vector2i(4, 4), F.NORTH_EAST], "campfire": [Vector2i(7, 3)],
			"props": [["log", Vector2i(8, 4)], ["stump", Vector2i(2, 1)]],
			# a hunter's pit on the path to the glade (the first trap: the Rogue should spot it)
			"traps": [{"t": "pit", "at": Vector2i(14, 4), "detect": 13, "disarm": 10, "save": 10, "dmg": "1d6", "xp": 25}],
			"name": "The Old Camp", "desc": "The embers of your campfire. The Harrow Woods close in all around; the old silver mine lies somewhere to the north-east."},
		"farm": {"rect": Rect2i(4, 24, 12, 10), "spawn": "rrrr", "props": [["rubble", Vector2i(1, 1)], ["rubble", Vector2i(2, 1)],
			["crate", Vector2i(9, 1)], ["barrel", Vector2i(10, 1)], ["barrel", Vector2i(10, 2)], ["rubble", Vector2i(1, 7)]],
			"bones": [Vector2i(5, 6)], "chests": [[15, ["potion_healing", "potion_healing"], Vector2i(9, 2)]],
			"name": "Ruined Farmstead", "desc": "A burnt-out farm. Rats the size of dogs have made it their own."},
		"glade": {"rect": Rect2i(22, 38, 12, 9), "spawn": "www", "props": [["boulder", Vector2i(2, 2)], ["stump", Vector2i(9, 6)],
			["bush", Vector2i(10, 1)]], "bones": [Vector2i(6, 4), Vector2i(4, 6)],
			"name": "Wolf Glade", "desc": "Gnawed bones litter the grass. Something with sharp teeth hunts here."},
		"camp": {"rect": Rect2i(22, 20, 15, 12), "spawn": "bbbbbb", "campfire": [Vector2i(7, 6)],
			"props": [["tent", Vector2i(3, 2)], ["tent", Vector2i(11, 2)], ["tent", Vector2i(3, 9)], ["crate", Vector2i(12, 9)],
				["crate", Vector2i(13, 9)], ["barrel", Vector2i(13, 8)], ["log", Vector2i(7, 8)]],
			"chests": [[40, ["studded_leather", "potion_healing", "scroll_burning_hands"], Vector2i(12, 8)]],
			# a tripwire with a bell on the path up from the glade: the bandits come running
			"traps": [{"t": "alarm", "at": Vector2i(6, 14), "detect": 13, "disarm": 10, "xp": 25}],
			"name": "Bandit Camp", "desc": "Tents, a cookfire, and crates of stolen goods. The bandits who prey on the woods road sleep here."},
		"graveyard": {"rect": Rect2i(4, 6, 13, 12), "spawn": "zzz", "props": [["grave", Vector2i(2, 2)], ["grave", Vector2i(5, 2)],
			["grave", Vector2i(8, 2)], ["grave", Vector2i(2, 5)], ["grave", Vector2i(5, 5)], ["grave", Vector2i(8, 5)],
			["grave", Vector2i(11, 3)], ["pine", Vector2i(11, 8)], ["urn", Vector2i(1, 9)]],
			"bones": [Vector2i(4, 8)], "chests": [[20, ["scroll_bless", "potion_healing"], Vector2i(6, 0)]],
			"name": "The Old Graveyard", "desc": "Leaning headstones, and freshly turned earth where something has dug its way out."},
		"lookout": {"rect": Rect2i(24, 4, 11, 9), "spawn": "ggg", "props": [["boulder", Vector2i(2, 2)], ["boulder", Vector2i(8, 1)],
			["boulder", Vector2i(5, 6)], ["bush", Vector2i(1, 6)]],
			"name": "The Lookout Rocks", "desc": "Goblins have piled stones into a crude watch post over the road."},
		"deepwood": {"rect": Rect2i(44, 26, 11, 11), "spawn": "wwww", "props": [["oak", Vector2i(2, 2)], ["oak", Vector2i(8, 8)],
			["stump", Vector2i(5, 3)], ["log", Vector2i(3, 7)], ["bush", Vector2i(9, 2)]], "bones": [Vector2i(6, 6), Vector2i(5, 5)],
			"chests": [[30, ["longbow", "potion_healing"], Vector2i(5, 8)]],
			"name": "The Deep Wood", "desc": "The trees grow close and dark here. Wolves pad between the trunks."},
		"oldroad": {"rect": Rect2i(40, 40, 10, 7), "spawn": "gggg", "props": [["log", Vector2i(2, 1)], ["log", Vector2i(6, 5)],
			["bush", Vector2i(8, 1)]],
			"name": "The Old Road", "desc": "A forgotten road, half swallowed by the forest. Goblin tracks everywhere."},
		# the old silver mine: the way down
		"mine": {"rect": Rect2i(44, 4, 15, 12), "spawn": "Gggg", "campfire": [Vector2i(4, 7)],
			"props": [["tent", Vector2i(2, 4)], ["crate", Vector2i(11, 1)], ["barrel", Vector2i(12, 1)], ["rubble", Vector2i(13, 7)]],
			"stairs": [Vector2i(7, 0), "res://scenes/maps/dungeon_1.tscn", "from_above"], "arrive": [Vector2i(7, 2), "from_below", F.SOUTH_WEST],
			"chests": [[50, ["scimitar", "potion_healing"], Vector2i(13, 2)]],
			# Brannoc the trader (Npc) at his stall; he hides until the goblins here are dead. The Rune of
			# Return's portal opens beside the stall, the party arriving next to it.
			"trader": {"stall": Vector2i(11, 6), "npc": Vector2i(11, 7), "portal": Vector2i(8, 8), "arrive": Vector2i(8, 9)},
			"name": "The Mine Entrance", "desc": "Timbers frame a black mouth in the hillside: the old silver mine."},
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
		# Phase 6: disarmed traps and solved puzzles / riddles
		for t in areas[k].get("traps", []):
			xp += t.get("xp", 25)
		xp += areas[k].get("puzzle", {}).get("xp", 0)
	for l in d.get("links", []):
		if l.size() > 2 and l[2].has("trap"):
			xp += l[2].trap.get("xp", 25)
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
	var doors := []         # [cell, locked, dc, key, link options]
	var secret_cells := {}  # secret doors: painted as floor, but their neighbours treat them as wall
	var corridor_traps := []    # [cell, spec, name]
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
			doors.append([door_cell, opts.has("locked"), opts.get("locked", 0), opts.get("key", ""), opts])
		if opts.get("secret", false):
			secret_cells[door_cell] = true
		if opts.has("trap") and cells.size() >= 3:
			corridor_traps.append([cells[cells.size() / 2], opts.trap, "%s%s" % [l[0], l[1]]])
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
	_paint_walls(wall_layer, walls, WALL_SRC, {}, secret_cells)

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
		var dopts: Dictionary = dd[4]
		if dopts.get("secret", false):
			door.style = Door.Style.SECRET
			door.secret_dc = dopts.get("sdc", 15)
			door.link = dopts.get("link", "")
		elif dopts.has("gate"):
			door.style = Door.Style.PORTCULLIS
			door.link = dopts.gate

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
		# Phase 6: the room's puzzle pieces, traps and description (before the furniture)
		if room.has("puzzle"):
			_puzzle(room.puzzle, r, rn, keep, used, blocked, entities, root, root_name)
		for tspec in room.get("traps", []):
			var tc: Vector2i
			if tspec.get("at", "auto") is String:
				tc = _auto_trap_cell(r, keep, used)
			else:
				tc = o + tspec.at
				if keep.has(tc) or used.has(tc):
					push_error("%s: trap in %s at %s is in the way of something" % [root_name, rn, tspec.at])
					_ok = false
			_trap(tspec, tc, entities, root, "Trap_%s_%d_%d" % [rn, tc.x, tc.y])
			used[tc] = true
		_note(room, r, entities, root, rn)
		# braziers in the corners
		var corners :=[Vector2i(0, 0), Vector2i(r.size.x - 1, r.size.y - 1), Vector2i(r.size.x - 1, 0), Vector2i(0, r.size.y - 1)]
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
	for ct in corridor_traps:
		_trap(ct[1], ct[0], entities, root, "Trap_%s_%d_%d" % [ct[2], ct[0].x, ct[0].y])
	(root.get_node("Camera") as Camera2D).position = IsoGrid.view_cell_to_world(start_cell)
	ok = _check(root_name, floor_cells, blocked, start_cell, rects) and ok and _ok
	_save(root, path)
	return ok


# --- Phase 6: traps, puzzles, notes --------------------------------------------------------------

var _ok := true


func _trap(spec: Dictionary, c: Vector2i, entities: Node2D, root: Node, node_name: String) -> void:
	var t := _inst("trap", entities, root, c, node_name)
	var kind: String = spec.t
	t.trap_type = TRAP_TYPES[kind]
	t.detect_dc = spec.get("detect", 13)
	t.disarm_dc = spec.get("disarm", 13)
	t.save_dc = spec.get("save", 12)
	t.save_ability = spec.get("ability", "DEX")
	t.damage = spec.get("dmg", "" if kind == "alarm" else "2d6")
	t.damage_type = spec.get("type", TRAP_DEFAULTS[kind][0])
	t.attack_bonus = spec.get("atk", 0)
	t.one_shot = spec.get("one_shot", TRAP_DEFAULTS[kind][1])
	t.xp = spec.get("xp", 25)
	t.position = IsoGrid.view_cell_to_world(c) + Trap.SORT_UP


## A free cell near the middle of the room (where the party walks through).
func _auto_trap_cell(r: Rect2i, keep: Dictionary, used: Dictionary) -> Vector2i:
	var mid := r.get_center()
	var best := mid
	var bd := 999.0
	for c: Vector2i in _interior(r):
		if keep.has(c) or used.has(c):
			continue
		var d := Vector2(c - mid).length() + rnd.randf() * 0.5
		if d < bd:
			bd = d
			best = c
	return best


## A room description over the whole room (caption), or a clue (modal).
func _note(room: Dictionary, r: Rect2i, entities: Node2D, root: Node, rn: String) -> void:
	var text: String = room.get("clue", room.get("desc", ""))
	if text == "":
		return
	var n := _inst("room_note", entities, root, r.position, "Note_" + rn)
	n.title = room.get("name", "")
	n.text = text
	n.size = r.size
	n.modal = room.has("clue")


## Place a puzzle's pieces (cells relative to the room) and its Puzzle marker.
func _puzzle(pz: Dictionary, r: Rect2i, rn: String, keep: Dictionary, used: Dictionary, blocked: Dictionary,
		entities: Node2D, root: Node, root_name: String) -> void:
	var o := r.position
	var take := func(rel: Vector2i, what: String, blocks: bool) -> Vector2i:
		var c := o + rel
		if not r.has_point(c) or keep.has(c) or used.has(c):
			push_error("%s: %s in %s at %s is outside the room or in the way" % [root_name, what, rn, rel])
			_ok = false
		used[c] = true
		if blocks:
			blocked[c] = true
		return c
	var kind: String = pz.kind
	var p_kind := -1
	match kind:
		"sequence":
			for lv in pz.levers:                       # [symbol, cell]
				var c: Vector2i = take.call(lv[1], "lever", true)
				var lever := _inst("lever", entities, root, c, "Lever_%s_%s" % [rn, lv[0]])
				lever.link = pz.link
				lever.symbol = SYMBOLS[lv[0]]
			p_kind = Puzzle.Kind.SEQUENCE
		"blocks":
			for i in pz.plates.size():
				var c: Vector2i = take.call(pz.plates[i], "plate", false)
				var plate := _inst("pressure_plate", entities, root, c, "Plate_%s_%d" % [rn, i])
				plate.link = pz.link
				plate.position = IsoGrid.view_cell_to_world(c) + PressurePlate.SORT_UP
			for i in pz.blocks.size():
				var c: Vector2i = take.call(pz.blocks[i], "block", true)
				var b := _inst("prop", entities, root, c, "Block_%s_%d" % [rn, i])
				b.kind = Prop.Kind.BLOCK
				b.pushable = true
				b.link = pz.link
			var rc: Vector2i = take.call(pz.reset, "reset lever", true)
			var rl := _inst("lever", entities, root, rc, "Lever_%s_reset" % rn)
			rl.link = pz.link
			rl.role = "reset"
			p_kind = Puzzle.Kind.ALL_ON
		"ring":
			for i in pz.braziers.size():
				var c: Vector2i = take.call(pz.braziers[i], "brazier", true)
				var b := _inst("brazier", entities, root, c, "Brazier_%s_ring%d" % [rn, i])
				b.link = pz.link
				b.order = i
				b.lit = pz.lit[i] == 1
			p_kind = Puzzle.Kind.RING
		"riddle":
			var c: Vector2i = take.call(pz.at, "stone face", true)
			var f := _inst("stone_face", entities, root, c, "StoneFace_" + rn)
			f.link = pz.link
			f.riddle = pz.riddle
			f.answers.assign(pz.answers)
			f.correct = pz.correct
			f.wrong_damage = pz.get("damage", "2d6")
			f.xp = pz.get("xp", 0)
		"lever":
			var c: Vector2i = take.call(pz.at, "lever", true)
			var lever := _inst("lever", entities, root, c, "Lever_" + rn)
			lever.link = pz.link
	if p_kind >= 0:
		var p := _inst("puzzle", entities, root, o, "Puzzle_" + rn)
		p.link = pz.link
		p.kind = p_kind
		p.opens = pz.opens
		p.solution = pz.get("solution", "")
		p.penalty = pz.get("penalty", "")
		p.xp = pz.get("xp", 0)
		if pz.has("solved_text"):
			p.solved_text = pz.solved_text


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
		for tspec in cl.get("traps", []):
			var tc: Vector2i = o + tspec.at
			if not floor_cells.has(tc) or blocked.has(tc):
				push_error("%s: trap in %s at %s is not on open ground" % [root_name, cn, tspec.at])
				_ok = false
			_trap(tspec, tc, entities, root, "Trap_%s_%d_%d" % [cn, tc.x, tc.y])
			used[tc] = true
		_note(cl, r, entities, root, cn)
		if cl.has("trader"):
			var tr: Dictionary = cl.trader
			_prop("stall", o + tr.stall, entities, root, cn)
			var npc := _inst("npc", entities, root, o + tr.npc, "Npc_Brannoc")
			npc.npc_id = "brannoc"
			npc.display_name = "Brannoc"
			npc.guard_radius = 12
			var pt := _inst("portal", entities, root, o + tr.portal, "Portal_Home")
			pt.home = true
			var ps := _inst("party_start", entities, root, o + tr.arrive, "PartyStart_portal")
			ps.entry_id = RunePortal.HOME_ENTRY
			ps.facing = F.NORTH_EAST
			for c: Vector2i in [tr.stall, tr.npc, tr.portal, tr.arrive]:
				used[o + c] = true
			blocked[o + tr.stall] = true
			blocked[o + tr.npc] = true
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
	ok = _check(root_name, floor_cells, blocked, start_cell, rects) and ok and _ok
	_save(root, path)
	return ok


# --- shared ------------------------------------------------------------------------------------------

## Wall blocks: the row (faces shown) follows from the neighbours, like the rotated views. Cells in
## `alt` use the cliff source instead of `src`. Cells in `virtual` (secret doors) aren't painted but
## count as wall for their neighbours (no face shows toward them).
func _paint_walls(layer: TileMapLayer, walls: Dictionary, src: int, alt: Dictionary, virtual := {}) -> void:
	for c: Vector2i in walls:
		var left := not walls.has(c + Vector2i(0, 1)) and not virtual.has(c + Vector2i(0, 1))
		var right := not walls.has(c + Vector2i(1, 0)) and not virtual.has(c + Vector2i(1, 0))
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
