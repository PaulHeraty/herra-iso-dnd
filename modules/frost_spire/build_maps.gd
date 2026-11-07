extends SceneTree
## Builds the maps of "The Frost Spire" (this module) with MapBuilder (tools/godot/map_builder.gd):
##   maps/frostfell.tscn  "The Frostfell"       level 5 -> 6  (the snow lands, the beacons, the vale)
##   maps/tower_1.tscn    "The Frozen Gate"     level 6
##   maps/tower_2.tscn    "The Library"         level 6 -> 7  (lever puzzle, the Rime Key)
##   maps/tower_3.tscn    "The Laboratory"      level 7       (Tamsin's cell, block puzzle)
##   maps/tower_4.tscn    "The Frost Chapel"    level 7 -> 8  (ring of fires, the Star Key, the lantern)
##   maps/tower_5.tscn    "The Observatory"     level 8 -> 9  (the riddle, Morvaine the Rimecaller)
## Run: Godot_console --headless --path . -s res://modules/frost_spire/build_maps.gd  [-- <map ids>]
## Re-running OVERWRITES the scenes. Once a map has been edited in the editor, don't rebuild it.
##
## XP: the party arrives at level 5 (6500 XP each, 26000 in all) and should leave at about 9 (48000
## each, 192000 in all). Monsters give about 90000; disarmed traps and puzzles about 10000; the rest
## comes from quest stages (module.gd: the beacons, each floor reached, the keys, the Rimecaller,
## the side quests). The builder prints each map's monster + trap + puzzle XP.

const F = PartyStart.Facing
const OUT := "res://modules/frost_spire/maps/"
const NPCS := "res://assets/sprites/npcs/"
const TOWER_TILES := "res://assets/tiles/tower_tileset.tres"
const TOWER_AMBIENT := Color(0.30, 0.34, 0.52)

# --- the snow lands ----------------------------------------------------------------------------

var FROSTFELL := {
	"title": "The Frostfell", "start_level": 5,
	"tileset": "res://assets/tiles/snow_tileset.tres", "ambient": Color(0.62, 0.66, 0.82),
	"edge_trees": ["pine_snow", "pine_snow", "oak_snow", "bush_snow", "boulder_snow"],
	"clearings": {
		"pass": {"rect": Rect2i(4, 44, 11, 8), "start": [Vector2i(4, 4), F.NORTH_EAST], "campfire": [Vector2i(7, 3)],
			"props": [["log", Vector2i(8, 4)], ["tent", Vector2i(2, 1)], ["boulder_snow", Vector2i(9, 1)]],
			# a snow-covered pit on the way north
			"traps": [{"t": "pit", "at": Vector2i(5, -4), "detect": 15, "disarm": 14, "save": 13, "dmg": "2d6", "xp": 50}],
			"name": "The Frozen Pass",
			"desc": "The pass behind you is choked with snow. Ahead lies the Frostfell, and somewhere in it the Rimecaller's tower. The old songs say three beacons once guarded this land."},
		"wolf_ridge": {"rect": Rect2i(4, 26, 12, 10), "spawn": "ffwww",
			"props": [["boulder_snow", Vector2i(2, 2)], ["stump_snow", Vector2i(9, 6)], ["bush_snow", Vector2i(10, 1)]],
			"bones": [Vector2i(6, 4), Vector2i(4, 6)],
			"name": "Wolf Ridge", "desc": "Great white wolves howl from the ridge. Their breath smokes, colder than the air."},
		"beacon_west": {"rect": Rect2i(4, 6, 11, 10), "spawn": "yyii",
			"braziers": [[Vector2i(5, 4), "beacons", false]],
			"props": [["boulder_snow", Vector2i(2, 2)], ["boulder_snow", Vector2i(8, 7)], ["rubble", Vector2i(8, 2)]],
			"name": "The West Beacon",
			"desc": "An old beacon crowns the hill: a great iron bowl, cold and dark. The jarl's people once lit these to warn of danger. (Click it to light it.)"},
		"frozen_lake": {"rect": Rect2i(22, 40, 13, 9), "spawn": "iiiiiiP",
			"props": [["boulder_snow", Vector2i(2, 2)], ["boulder_snow", Vector2i(10, 6)], ["bush_snow", Vector2i(11, 1)]],
			"name": "The Frozen Lake",
			"desc": "A lake frozen hard as stone, and shapes of living ice drifting over it. To the east, the path into the hills ends at a wall of blue ice."},
		"bear_den": {"rect": Rect2i(22, 24, 12, 10), "spawn": "PPP",
			"props": [["boulder_snow", Vector2i(2, 2)], ["boulder_snow", Vector2i(9, 2)], ["stump_snow", Vector2i(2, 7)]],
			"bones": [Vector2i(5, 5), Vector2i(7, 6), Vector2i(4, 7)],
			"name": "Bear Den", "desc": "Enormous white bears have made their den among the rocks."},
		"watchtower": {"rect": Rect2i(22, 6, 13, 10), "spawn": "maaa",
			"props": [["rubble", Vector2i(2, 2)], ["rubble", Vector2i(3, 2)], ["rubble", Vector2i(10, 7)], ["crate", Vector2i(10, 1)],
				["barrel", Vector2i(11, 1)]],
			# a tripwire on the way up from the bear den
			"traps": [{"t": "alarm", "at": Vector2i(6, 12), "detect": 16, "disarm": 14, "xp": 50}],
			"chests": [[120, ["potion_greater_healing", "scroll_ice_storm"], Vector2i(6, 1)]],
			"name": "The Old Watchtower", "desc": "The ruins of a watchtower. Someone in a white robe has made it their post."},
		"beacon_north": {"rect": Rect2i(40, 4, 11, 9), "spawn": "ffw",
			"braziers": [[Vector2i(5, 4), "beacons", false]],
			"props": [["boulder_snow", Vector2i(2, 2)], ["boulder_snow", Vector2i(8, 6)]],
			"name": "The North Beacon", "desc": "The second beacon, on a windswept crag. Wolves have made the hilltop theirs."},
		"troll_bridge": {"rect": Rect2i(40, 22, 12, 10), "spawn": "TO",
			"props": [["boulder_snow", Vector2i(2, 2)], ["boulder_snow", Vector2i(9, 7)], ["log", Vector2i(5, 1)]],
			"bones": [Vector2i(4, 5), Vector2i(6, 6), Vector2i(7, 4)],
			"chests": [[200, ["potion_superior_healing", "ring_resistance_fire"], Vector2i(10, 2)]],
			"name": "Troll's Gulch", "desc": "A gulch strewn with gnawed bones. Something big lives here, and it heals faster than you can hurt it. Fire might help."},
		"beacon_east": {"rect": Rect2i(56, 14, 11, 10), "spawn": "iiiiyy",
			"braziers": [[Vector2i(5, 4), "beacons", false]],
			"props": [["boulder_snow", Vector2i(2, 2)], ["boulder_snow", Vector2i(8, 7)]],
			"name": "The East Beacon", "desc": "The third beacon stands among frozen stones. The air around it glitters with ice."},
		# the hidden vale: behind the ward, the white dragon, Hilde's camp and the Rimecaller's tower
		"vale": {"rect": Rect2i(42, 40, 18, 12), "spawn": "D",
			"campfire": [Vector2i(6, 7)],
			"props": [["tent", Vector2i(1, 7)], ["crate", Vector2i(1, 10)], ["barrel", Vector2i(2, 11)], ["boulder_snow", Vector2i(14, 3)]],
			"tower": true,
			"stairs": [Vector2i(9, 0), OUT + "tower_1.tscn", "from_surface"], "arrive": [Vector2i(9, 2), "from_tower", F.SOUTH_WEST],
			"trader": {"id": "hilde", "name": "Hilde", "sheet": NPCS + "hilde_sheet.png", "guard": 30, "guard_monster": "young_white_dragon",
				"stall": Vector2i(3, 9), "npc": Vector2i(4, 10), "portal": Vector2i(7, 10), "arrive": Vector2i(8, 11)},
			"npcs": [{"id": "tamsin", "name": "Tamsin", "at": Vector2i(5, 10), "sheet": NPCS + "tamsin_sheet.png",
				"show": "tamsin_left", "calls": false}],
			"name": "The Hidden Vale",
			"desc": "A sheltered valley, and at its heart the Rimecaller's spire, glittering with frost. Something huge and white is coiled in the snow."},
	},
	"paths": [
		[Vector2i(9, 44), Vector2i(9, 34)],      # pass - wolf ridge
		[Vector2i(9, 26), Vector2i(9, 14)],      # wolf ridge - west beacon
		[Vector2i(14, 47), Vector2i(23, 46)],    # pass - frozen lake
		[Vector2i(28, 40), Vector2i(28, 32)],    # lake - bear den
		[Vector2i(28, 24), Vector2i(28, 14)],    # bear den - watchtower
		[Vector2i(34, 10), Vector2i(41, 9)],     # watchtower - north beacon
		[Vector2i(33, 28), Vector2i(41, 27)],    # bear den - troll's gulch
		[Vector2i(46, 22), Vector2i(46, 11)],    # troll's gulch - north beacon
		[Vector2i(51, 26), Vector2i(60, 22)],    # troll's gulch - east beacon
		[Vector2i(34, 44), Vector2i(43, 45)],    # lake - the vale (through the ward)
	],
	"cliffs": [Rect2i(36, 33, 32, 7), Rect2i(58, 38, 10, 16)],
	# the ward across the only way into the vale; the beacons (all three lit) melt it
	"wards": [[Vector2i(38, 44), "ward"], [Vector2i(38, 45), "ward"]],
	"puzzles": [{"link": "beacons", "kind": "all_on", "opens": "ward", "flag": "beacons_lit", "xp": 1500,
		"solved_text": "The third beacon roars up, and far to the south-east a wall of ice cracks like thunder and melts away!"}],
}

# --- the tower -----------------------------------------------------------------------------------

var TOWER_1 := {
	"title": "The Frozen Gate", "start_level": 6, "tileset": TOWER_TILES, "ambient": TOWER_AMBIENT,
	"rooms": {
		"A": {"slot": Vector2i(0, 2), "size": Vector2i(8, 7), "theme": "frozen",
			"stairs": [false, OUT + "frostfell.tscn", "from_tower"], "arrive": "from_surface", "start": true,
			"name": "The Frozen Gate", "desc": "Inside the door the cold is worse than outside. Frost furs every wall, and somewhere above, something is laughing."},
		"B": {"slot": Vector2i(0, 1), "size": Vector2i(10, 7), "theme": "armory", "spawn": "aaaa",
			"chests": [[60, ["potion_greater_healing", "potion_greater_healing"]]],
			"name": "Guard Hall", "desc": "Empty suits of armour stand to attention along the walls. Their helmets turn to follow you."},
		"C": {"slot": Vector2i(1, 1), "size": Vector2i(8, 6), "theme": "armory", "spawn": "aassss",
			"chests": [[0, [], 0, "", true], [80, ["dagger_plus2"]]],
			"name": "Armory", "desc": "Racks of blades hum with a faint blue light. Not all of them are on their racks."},
		"D": {"slot": Vector2i(1, 2), "size": Vector2i(9, 9), "theme": "frozen", "spawn": "yyy",
			"chests": [[200, ["ring_warmth", "potion_superior_healing"]]],
			"name": "Hall of Statues", "desc": "Grey stone figures crouch on pedestals. Their eyes are not quite stone."},
		"E": {"slot": Vector2i(2, 1), "size": Vector2i(10, 9), "theme": "frozen", "spawn": "iiiiiiff",
			"name": "The Frozen Hall", "desc": "Ice hangs from the ceiling in long teeth, and tiny shapes of living frost flit between them."},
		"F": {"slot": Vector2i(2, 2), "size": Vector2i(9, 7), "theme": "cells", "spawn": "Tff",
			"chests": [[150, ["half_plate_plus2", "potion_greater_healing"]]],
			"name": "The Kennels", "desc": "Bones gnawed white, and the musk of something that heals as fast as you cut it."},
		"G": {"slot": Vector2i(0, 0), "size": Vector2i(8, 8), "theme": "cells", "spawn": "aay",
			"name": "Old Cells", "desc": "Rusted cells, long empty. Scratches on the walls count days that never ended."},
		"H": {"slot": Vector2i(1, 0), "size": Vector2i(10, 7), "theme": "armory", "spawn": "yyaa",
			"chests": [[90, ["scroll_death_ward", "potion_greater_healing"]]],
			"name": "Barracks", "desc": "Cold bunks for servants who don't sleep."},
		"I": {"slot": Vector2i(2, 0), "size": Vector2i(8, 7), "theme": "frozen", "spawn": "iiii",
			"traps": [{"t": "fire", "at": "auto", "detect": 17, "disarm": 15, "save": 15, "dmg": "4d6", "xp": 100}],
			"name": "Ice Gallery", "desc": "A gallery of frozen fountains, still in mid-splash."},
		"J": {"slot": Vector2i(3, 0), "size": Vector2i(9, 7), "theme": "study", "spawn": "ssssm",
			"chests": [[120, ["scroll_fireball", "potion_superior_healing"]]],
			"name": "Apprentices' Study", "desc": "Desks and spilled ink. Someone here was practising frost runes, badly."},
		"K": {"slot": Vector2i(3, 1), "size": Vector2i(9, 8), "theme": "frozen", "spawn": "Taa",
			"name": "Trophy Hall", "desc": "The heads of great beasts hang on the walls, every one of them rimed with frost."},
		"L": {"slot": Vector2i(3, 2), "size": Vector2i(8, 7), "theme": "hall", "spawn": "yyaa",
			"stairs": [true, OUT + "tower_2.tscn", "from_below"], "arrive": "from_above",
			"name": "Stair of Frost", "desc": "A spiral stair climbs into the cold dark."},
		"S": {"slot": Vector2i(0, 3), "size": Vector2i(7, 5), "theme": "bare",
			"chests": [[250, ["potion_superior_healing", "potion_superior_healing", "scroll_cone_of_cold", "breastplate_plus2"]]],
			"name": "The Hidden Larder", "desc": "A forgotten store behind the wall, packed for a long siege."},
	},
	"links": [["A", "B", {"trap": {"t": "spikes", "detect": 16, "disarm": 15, "save": 15, "dmg": "4d6", "xp": 100}}],
		["B", "C"], ["A", "D"], ["B", "G"], ["G", "H"], ["H", "I"], ["C", "E"], ["E", "I"],
		["I", "J", {"trap": {"t": "darts", "detect": 18, "disarm": 15, "atk": 8, "dmg": "3d6", "xp": 100}}],
		["J", "K"], ["K", "L"], ["E", "F"], ["D", "F"], ["F", "L"], ["S", "A", {"secret": true, "sdc": 17}]],
}

var TOWER_2 := {
	"title": "The Library", "start_level": 6, "tileset": TOWER_TILES, "ambient": TOWER_AMBIENT,
	"rooms": {
		"A": {"slot": Vector2i(0, 2), "size": Vector2i(8, 7), "theme": "study",
			"stairs": [false, OUT + "tower_1.tscn", "from_above"], "arrive": "from_below", "start": true,
			"name": "Library Landing", "desc": "Shelves rise out of sight. The air smells of old paper and lightning."},
		"B": {"slot": Vector2i(0, 1), "size": Vector2i(10, 7), "theme": "library", "spawn": "msss",
			"chests": [[100, ["scroll_lightning_bolt", "potion_greater_healing"]]],
			"name": "Reading Room", "desc": "Lecterns stand in rows, each with a book open on it. The pages turn by themselves."},
		"C": {"slot": Vector2i(1, 1), "size": Vector2i(8, 6), "theme": "library", "spawn": "ssssa",
			"name": "The Stacks", "desc": "Narrow alleys of shelves. Swords hang in the air between them, slowly turning."},
		"D": {"slot": Vector2i(1, 2), "size": Vector2i(9, 9), "theme": "library", "spawn": "ppp",
			"chests": [[150, ["potion_superior_healing", "scroll_mass_healing_word"]]],
			"name": "Scriptorium", "desc": "Ghostly scribes bend over their desks, copying words no living eye can read."},
		"E": {"slot": Vector2i(2, 1), "size": Vector2i(10, 9), "theme": "study", "spawn": "myay",
			"name": "Hall of Maps", "desc": "Maps of the Frostfell cover the walls, every village marked in the Rimecaller's hand. Most are crossed out."},
		"F": {"slot": Vector2i(2, 2), "size": Vector2i(9, 7), "theme": "library", "spawn": "yy",
			"name": "Gargoyle Perch", "desc": "Stone gargoyles crouch on top of the shelves like owls."},
		"G": {"slot": Vector2i(0, 0), "size": Vector2i(8, 8), "theme": "study", "spawn": "yay",
			"chests": [[90, ["rime_key", "scroll_ice_storm", "potion_greater_healing"]]],
			"name": "The Archive", "desc": "Locked cabinets and dusty ledgers: the tower's accounts, kept for a hundred years. Something cold glints among them."},
		"H": {"slot": Vector2i(1, 0), "size": Vector2i(10, 7), "theme": "library", "spawn": "ppss",
			"name": "Haunted Shelves", "desc": "Cold spots drift between the shelves. Books fall without a hand to push them."},
		"I": {"slot": Vector2i(2, 0), "size": Vector2i(8, 7), "theme": "study", "spawn": "mss",
			"chests": [[0, [], 0, "", true]],
			"name": "Copying Room", "desc": "Quills scratch by themselves at empty desks."},
		"J": {"slot": Vector2i(3, 0), "size": Vector2i(9, 7), "theme": "library", "spawn": "aayy",
			"chests": [[140, ["longbow_plus2", "potion_greater_healing"]]],
			"name": "Restricted Section", "desc": "Chained books strain against their chains."},
		"K": {"slot": Vector2i(3, 1), "size": Vector2i(9, 8), "theme": "library", "spawn": "sssspp",
			"name": "Hall of Echoes", "desc": "Your footsteps come back to you a moment too late."},
		"L": {"slot": Vector2i(3, 2), "size": Vector2i(8, 7), "theme": "hall", "spawn": "myy",
			"stairs": [true, OUT + "tower_3.tscn", "from_below"], "arrive": "from_above",
			"name": "Upper Stair", "desc": "The stair climbs on. A smell of chemicals drifts down from above."},
		# the lever puzzle: the order of the night sky
		"N": {"slot": Vector2i(2, 3), "size": Vector2i(9, 7), "theme": "bare", "name": "The Orrery Room",
			"clue": "Three levers stand by the wall, each marked with a sign: a moon, a star and an eye. Above them, a brass orrery creaks round, and words are etched into its base:\n\"First the moon climbs the sky. Then the stars wake. Last of all opens the Eye that watches over them.\"",
			"puzzle": {"kind": "sequence", "link": "t2_orrery", "opens": "t2_vault", "solution": "moon,star,eye",
				"levers": [["star", Vector2i(0, 1)], ["eye", Vector2i(0, 3)], ["moon", Vector2i(7, 0)]],
				"penalty": "2d6", "xp": 1500, "solved_text": "The orrery clicks into place, and chains rattle: the vault's portcullis is rising!"}},
		"O": {"slot": Vector2i(3, 3), "size": Vector2i(7, 6), "theme": "study",
			"chests": [[300, ["headband_intellect", "scroll_cone_of_cold", "potion_supreme_healing"]]],
			"name": "The Rimecaller's Vault", "desc": "His private collection, behind iron bars: books bound in white leather, and stranger things."},
	},
	"links": [["A", "B"], ["B", "C"], ["A", "D"], ["B", "G"], ["G", "H"], ["H", "I"], ["C", "E"], ["E", "I"],
		["I", "J", {"trap": {"t": "fire", "detect": 17, "disarm": 15, "save": 15, "dmg": "4d6", "xp": 100}}],
		["J", "K"], ["K", "L"], ["E", "F"], ["D", "F", {"trap": {"t": "darts", "detect": 18, "disarm": 16, "atk": 8, "dmg": "3d6", "xp": 100}}],
		["F", "L"], ["F", "N"], ["N", "O", {"gate": "t2_vault"}]],
}

var TOWER_3 := {
	"title": "The Laboratory", "start_level": 7, "tileset": TOWER_TILES, "ambient": TOWER_AMBIENT,
	"rooms": {
		"A": {"slot": Vector2i(0, 0), "size": Vector2i(8, 7), "theme": "lab",
			"stairs": [false, OUT + "tower_2.tscn", "from_above"], "arrive": "from_below", "start": true,
			"name": "Laboratory Landing", "desc": "Glass tubes run along the walls, bubbling with something blue."},
		"B": {"slot": Vector2i(1, 0), "size": Vector2i(10, 8), "theme": "lab", "spawn": "Fiiii",
			"name": "Specimen Hall", "desc": "Things float in jars of green fluid. One of the jars is empty, and broken."},
		"C": {"slot": Vector2i(0, 1), "size": Vector2i(11, 9), "theme": "lab", "spawn": "maa",
			"chests": [[120, ["potion_superior_healing", "scroll_fireball"]]],
			"name": "Alchemy Hall", "desc": "Benches crowded with retorts and alembics. A cauldron steams all on its own."},
		"D": {"slot": Vector2i(2, 0), "size": Vector2i(9, 8), "theme": "cells", "spawn": "aaa",
			"name": "The Pens", "desc": "Iron pens and heavy chains, made for things much larger than a man."},
		"E": {"slot": Vector2i(1, 1), "size": Vector2i(9, 8), "theme": "lab", "spawn": "FF",
			"chests": [[200, ["warhammer_plus2", "potion_superior_healing"]]],
			"name": "The Golem Works", "desc": "Half-built bodies of stitched flesh hang from hooks. Two of them are not hanging any more."},
		"F": {"slot": Vector2i(2, 1), "size": Vector2i(10, 8), "theme": "armory", "spawn": "cc",
			"chests": [[0, [], 0, "", true], [180, ["chain_mail_plus2", "potion_greater_healing"]]],
			"name": "Store Room", "desc": "Boxes and chests of supplies. Some of them are breathing."},
		"G": {"slot": Vector2i(0, 2), "size": Vector2i(9, 7), "theme": "frozen", "spawn": "iiiiii",
			"traps": [{"t": "spikes", "at": "auto", "detect": 17, "disarm": 16, "save": 15, "dmg": "4d6", "xp": 100}],
			"name": "Cold Store", "desc": "Frozen carcasses on hooks, and the flicker of mephits feeding."},
		"H": {"slot": Vector2i(1, 2), "size": Vector2i(11, 9), "theme": "lab", "spawn": "mF",
			"chests": [[250, ["potion_supreme_healing", "scroll_mass_cure_wounds", "ring_resistance_lightning"]]],
			"name": "Grand Laboratory", "desc": "The Rimecaller's great work: a machine of copper and ice that hums with power."},
		"I": {"slot": Vector2i(2, 2), "size": Vector2i(8, 7), "theme": "frozen", "spawn": "TT",
			"stairs": [true, OUT + "tower_4.tscn", "from_below"], "arrive": "from_above",
			"name": "Sealed Stair", "desc": "A stair climbs from behind a door of ice-blue steel. The air beyond is bitter."},
		"J": {"slot": Vector2i(3, 1), "size": Vector2i(9, 8), "theme": "study", "spawn": "myy",
			"name": "Apprentice Quarters", "desc": "Narrow beds, and robes hung on hooks. Their owners left in a hurry."},
		# the pens: push the blocks onto the plates and Tamsin's cell opens
		"K": {"slot": Vector2i(3, 0), "size": Vector2i(10, 8), "theme": "bare", "name": "The Weighing Pens",
			"clue": "Two worn plates are set in the floor, and two great blocks of stone stand near them. Through the bars of a cell on the far side, someone is waving at you. A lever on the wall bears a circling arrow.",
			"puzzle": {"kind": "blocks", "link": "t3_pens", "opens": "tamsin_cell", "flag": "tamsin_free", "xp": 1500,
				"plates": [Vector2i(3, 1), Vector2i(6, 5)], "blocks": [Vector2i(3, 5), Vector2i(4, 3)], "reset": Vector2i(9, 0),
				"solved_text": "Both plates sink home, and the bars of the cell rattle upward. Tamsin is free!"}},
		"L": {"slot": Vector2i(4, 0), "size": Vector2i(7, 6), "theme": "cells",
			"npcs": [{"id": "tamsin", "name": "Tamsin", "at": Vector2i(4, 2), "sheet": NPCS + "tamsin_sheet.png", "hide": "tamsin_left"}],
			"name": "Tamsin's Cell", "desc": "A cramped cell. A young woman in an apprentice's robe sits on the floor, shivering."},
	},
	"links": [["A", "B"], ["A", "C"], ["B", "D"], ["B", "E"], ["C", "E"], ["D", "F"], ["E", "F"], ["C", "G"],
		["E", "H", {"trap": {"t": "darts", "detect": 18, "disarm": 16, "atk": 8, "dmg": "3d6", "xp": 100}}], ["G", "H"],
		["H", "I", {"locked": 0, "key": "rime"}], ["F", "J"], ["D", "K"], ["K", "L", {"gate": "tamsin_cell"}]],
}

var TOWER_4 := {
	"title": "The Frost Chapel", "start_level": 7, "tileset": TOWER_TILES, "ambient": TOWER_AMBIENT,
	"rooms": {
		"A": {"slot": Vector2i(0, 0), "size": Vector2i(8, 7), "theme": "frozen",
			"stairs": [false, OUT + "tower_3.tscn", "from_above"], "arrive": "from_below", "start": true,
			"name": "Chapel Landing", "desc": "The walls here are made of ice, lit from within."},
		"B": {"slot": Vector2i(1, 0), "size": Vector2i(10, 8), "theme": "cells", "spawn": "fff",
			"name": "Wolf Pens", "desc": "Great white wolves pace in the cold, watching you with pale eyes."},
		"C": {"slot": Vector2i(0, 1), "size": Vector2i(10, 8), "theme": "study", "spawn": "may",
			"chests": [[150, ["potion_superior_healing", "scroll_death_ward"]]],
			"name": "Vestry", "desc": "Robes of white and silver hang ready for some cold ceremony."},
		"D": {"slot": Vector2i(2, 0), "size": Vector2i(10, 8), "theme": "observatory", "spawn": "TT",
			"name": "Hall of Pillars", "desc": "Pillars of solid ice hold up the roof. Shapes are frozen inside them."},
		"E": {"slot": Vector2i(1, 1), "size": Vector2i(9, 8), "theme": "frozen", "spawn": "ffiiii",
			"name": "Frozen Kennels", "desc": "Ice-crusted cages, and things that live in the cold."},
		"F": {"slot": Vector2i(2, 1), "size": Vector2i(10, 8), "theme": "study", "spawn": "msss",
			"name": "Mirror Hall", "desc": "Mirrors of polished ice show you yourselves, a little colder."},
		# the guard captain: the Star Key
		"G": {"slot": Vector2i(0, 2), "size": Vector2i(11, 9), "theme": "armory", "spawn": "maayy",
			"chests": [[250, ["star_key", "potion_supreme_healing", "scroll_cone_of_cold"]]],
			"name": "Guard Captain's Hall", "desc": "Weapon racks, a map table and a strongbox: whoever commands the tower's guard lives here."},
		"H": {"slot": Vector2i(1, 2), "size": Vector2i(9, 8), "theme": "lab", "spawn": "FF",
			"traps": [{"t": "fire", "at": "auto", "detect": 18, "disarm": 16, "save": 16, "dmg": "5d6", "xp": 150}],
			"name": "Hall of Golems", "desc": "Two great figures of stitched flesh stand waiting for orders."},
		"I": {"slot": Vector2i(2, 2), "size": Vector2i(11, 9), "theme": "frozen", "spawn": "TTii",
			"chests": [[200, ["breastplate_plus2", "potion_superior_healing"]]],
			"name": "Troll Den", "desc": "Gnawed bones and a smell like wet rot. Something big snores."},
		"J": {"slot": Vector2i(3, 2), "size": Vector2i(9, 8), "theme": "hall", "spawn": "yyy",
			"stairs": [true, OUT + "tower_5.tscn", "from_below"], "arrive": "from_above",
			"name": "Last Stair", "desc": "The stair to the top of the tower. Starlight glints down it."},
		"K": {"slot": Vector2i(3, 1), "size": Vector2i(8, 7), "theme": "armory", "spawn": "c",
			"chests": [[0, [], 0, "", true], [400, ["shield_plus2", "potion_greater_healing"]]],
			"name": "Treasure Room", "desc": "Gold glints in the corners... perhaps too invitingly."},
		# the ring of frost fires: light all five and the reliquary opens (the Sunfire Lantern)
		"L": {"slot": Vector2i(3, 0), "size": Vector2i(9, 8), "theme": "bare", "name": "Chapel of Frost Fires",
			"clue": "Five iron bowls stand in a ring, two of them burning with pale blue fire. Frost-script runs round the floor:\n\"Wake all five, and the reliquary opens. But the fires are bound together: touch one, and the two beside it answer.\"",
			"puzzle": {"kind": "ring", "link": "t4_fires", "opens": "t4_vault", "xp": 2000,
				"braziers": [Vector2i(4, 0), Vector2i(6, 2), Vector2i(5, 5), Vector2i(2, 5), Vector2i(1, 2)], "lit": [0, 1, 0, 0, 1],
				"solved_text": "All five fires blaze up together, and chains rattle: the reliquary's portcullis is rising!"}},
		"M": {"slot": Vector2i(4, 0), "size": Vector2i(7, 6), "theme": "hall",
			"chests": [[350, ["sunfire_lantern", "potion_supreme_healing", "longsword_plus2"]]],
			"name": "Reliquary", "desc": "Treasures stolen from the jarl's wagons, kept behind iron bars. A brass lantern burns among them."},
	},
	"links": [["A", "B"], ["A", "C", {"trap": {"t": "spikes", "detect": 18, "disarm": 16, "save": 16, "dmg": "4d6", "xp": 150}}],
		["B", "D"], ["B", "E"], ["C", "E"], ["C", "G"], ["D", "F"], ["E", "F"], ["E", "H"], ["G", "H"], ["F", "I"], ["H", "I"],
		["I", "J"], ["F", "K"], ["K", "J"], ["D", "L"], ["L", "M", {"gate": "t4_vault"}]],
}

var TOWER_5 := {
	"title": "The Observatory", "start_level": 8, "tileset": TOWER_TILES, "ambient": TOWER_AMBIENT,
	"rooms": {
		"A": {"slot": Vector2i(0, 0), "size": Vector2i(8, 7), "theme": "hall",
			"stairs": [false, OUT + "tower_4.tscn", "from_above"], "arrive": "from_below", "start": true,
			"name": "Observatory Landing", "desc": "The roof of the tower is close now. The wind howls round it."},
		"B": {"slot": Vector2i(1, 0), "size": Vector2i(10, 8), "theme": "study", "spawn": "yyaa",
			"name": "Antechamber", "desc": "Stone guardians stand by a door of ice."},
		"C": {"slot": Vector2i(0, 1), "size": Vector2i(10, 8), "theme": "library", "spawn": "mss",
			"chests": [[200, ["potion_supreme_healing", "scroll_ice_storm"]]],
			"name": "Star Library", "desc": "Books of star-lore, and a mage poring over them."},
		"D": {"slot": Vector2i(2, 0), "size": Vector2i(10, 8), "theme": "observatory", "spawn": "F",
			"chests": [[250, ["studded_leather_plus2", "potion_superior_healing"]]],
			"name": "Lens Room", "desc": "A great lens of ice, three paces across, gathers the cold starlight."},
		"E": {"slot": Vector2i(1, 1), "size": Vector2i(11, 9), "theme": "observatory", "spawn": "myy",
			"name": "Hall of Constellations", "desc": "The ceiling is a map of the winter sky, its stars made of real ice that glitters."},
		"F": {"slot": Vector2i(2, 1), "size": Vector2i(10, 9), "theme": "frozen", "spawn": "ffT",
			"name": "Frozen Garden", "desc": "A garden of ice: frozen flowers, frozen trees, and frozen birds on their branches."},
		"G": {"slot": Vector2i(0, 2), "size": Vector2i(10, 8), "theme": "armory", "spawn": "aaaayy",
			"chests": [[150, ["potion_supreme_healing", "scroll_death_ward"]]],
			"name": "Guard Post", "desc": "The last guards of the tower stand ready."},
		"H": {"slot": Vector2i(1, 2), "size": Vector2i(10, 8), "theme": "study", "spawn": "msss",
			"traps": [{"t": "darts", "at": "auto", "detect": 19, "disarm": 17, "atk": 9, "dmg": "4d6", "xp": 200}],
			"name": "Robing Room", "desc": "Morvaine's robes hang here, each one colder than the last."},
		"I": {"slot": Vector2i(2, 2), "size": Vector2i(9, 8), "theme": "hall", "spawn": "yy",
			"name": "The Star Door", "desc": "A door of silver set with a seven-pointed star. Beyond it, someone is chanting."},
		# the Rimecaller himself
		"J": {"slot": Vector2i(3, 2), "size": Vector2i(11, 9), "theme": "observatory", "spawn": "Ryy",
			"chests": [[1500, ["bracers_defense", "gauntlets_ogre_power", "plate_armor_plus2", "potion_supreme_healing"]]],
			"name": "The Observatory", "desc": "Under a dome of ice open to the winter sky, the Rimecaller turns from his telescope to face you."},
		# the riddle: the right answer opens a secret door to Morvaine's own hoard
		"K": {"slot": Vector2i(3, 1), "size": Vector2i(9, 8), "theme": "hall", "name": "Hall of the Frost Mask",
			"desc": "A mask of carved stone sits on a pedestal, its eyes glowing amber. It seems to be waiting for you.",
			"puzzle": {"kind": "riddle", "link": "t5_riddle", "at": Vector2i(6, 1), "damage": "4d6", "xp": 3000,
				"riddle": "\"I am born of water, and water is my death. I grow in the dark and the cold, and I wither in the sun. I have no hands, yet I build bridges over rivers and walls across a vale. Name me, and pass.\"",
				"answers": ["Ice", "Snow", "Glass", "Stone"], "correct": 0}},
		"L": {"slot": Vector2i(3, 0), "size": Vector2i(8, 6), "theme": "observatory",
			"chests": [[800, ["frost_brand", "ring_resistance_lightning", "potion_supreme_healing", "scroll_cone_of_cold"]]],
			"name": "Morvaine's Hoard", "desc": "The Rimecaller's own treasure, hidden even from his apprentices."},
	},
	"links": [["A", "B"], ["A", "C"], ["B", "D"], ["B", "E"], ["C", "E"],
		["C", "G", {"trap": {"t": "fire", "detect": 18, "disarm": 17, "save": 16, "dmg": "6d6", "xp": 200}}],
		["D", "F"], ["E", "F"], ["G", "H"], ["E", "H"], ["F", "I"], ["H", "I"], ["I", "J", {"locked": 0, "key": "star"}],
		["F", "K"], ["L", "K", {"secret": true, "sdc": 20, "link": "t5_riddle"}]],
}


func _init() -> void:
	var only := Array(OS.get_cmdline_user_args())
	var maps := [
		["frostfell", FROSTFELL, "Frostfell"], ["tower_1", TOWER_1, "Tower1"], ["tower_2", TOWER_2, "Tower2"],
		["tower_3", TOWER_3, "Tower3"], ["tower_4", TOWER_4, "Tower4"], ["tower_5", TOWER_5, "Tower5"],
	]
	var b := MapBuilder.new()
	var ok := true
	var total := 0
	DirAccess.make_dir_recursive_absolute(OUT)
	for m in maps:
		var xp := b.xp_of(m[1])
		for pz in m[1].get("puzzles", []):
			xp += pz.get("xp", 0)
		total += xp
		if not only.is_empty() and not m[0] in only:
			print("build_maps: %s skipped (%d XP, %d running total)" % [m[0], xp, total])
			continue
		b.rnd.seed = hash(m[0])
		var path: String = OUT + "%s.tscn" % m[0]
		if m[0] == "frostfell":
			ok = b.build_surface(m[1], m[2], path) and ok
		else:
			ok = b.build_floor(m[1], m[2], path) and ok
		print("build_maps: %s %d XP (running total %d = %d each)" % [m[0], xp, total, total / 4])
	var quest := 0
	var mod: AdventureModule = (load("res://modules/frost_spire/module.gd") as GDScript).new()
	for s in mod.quest_stages:
		quest += s.get("xp", 0)
	for q in mod.side_quests:
		for s in q.stages:
			quest += s.get("xp", 0)
	print("build_maps: quest stages %d XP; with the maps %d (+26000 at the start = %d each)" % [quest, total + quest, (total + quest + 26000) / 4])
	quit(0 if ok else 1)
