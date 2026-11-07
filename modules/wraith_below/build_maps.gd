extends SceneTree
## Builds the maps of "The Wraith Below" (this module) with MapBuilder (tools/godot/map_builder.gd):
##   maps/surface.tscn    "The Harrow Woods"     level 1 -> 2  (the start; the mine entrance)
##   maps/dungeon_1.tscn  "The Upper Halls"      level 2 -> 3
##   maps/dungeon_2.tscn  "The Webbed Deep"      level 3      (the Eye Tyrant's lair)
##   maps/dungeon_3.tscn  "The Goblin Warrens"   level 3 -> 4
##   maps/dungeon_4.tscn  "The Sunken Crypts"    level 4
##   maps/dungeon_5.tscn  "The Sealed Vault"     level 4 -> 5  (the Wraith)
## Run: Godot_console --headless --path . -s res://modules/wraith_below/build_maps.gd  [-- <map ids>]
## Re-running OVERWRITES the scenes (all, or the ones named: surface, dungeon_1...). Once a map has
## been edited in the editor, don't rebuild it.
##
## XP (5e SRD, split between the four heroes): the totals are planned so the party reaches level 2
## near the end of the woods, 3 in the Upper Halls, 4 in the Warrens and 5 in the Sealed Vault
## (thresholds x4: 1200 / 3600 / 10800 / 26000). The builder prints each map's total.

const F = PartyStart.Facing
const OUT := "res://modules/wraith_below/maps/"
const NPCS := "res://assets/sprites/npcs/"

# --- the dungeon floors ---------------------------------------------------------------------------

var DUNGEON_1 := {
	"title": "The Upper Halls", "start_level": 2,
	"rooms": {
		# the way in from the mine: stairs up to the woods
		"A": {"slot": Vector2i(0, 2), "size": Vector2i(8, 7), "theme": "hall",
			"stairs": [true, "res://modules/wraith_below/maps/surface.tscn", "from_below"], "arrive": "from_above",
			"start": true, "name": "Entrance Hall",
			"desc": "Steps climb back up to daylight. The air smells of dust and old smoke, and somewhere a cold draught seeps through the stonework.",
			"lore": [{"kind": "remains", "at": Vector2i(1, 4), "title": "A Miner's Last Letter", "flag": "tobin_letter",
				"text": "To my Hanna, if this finds you. We broke through into old halls under the silver seam: carved stone, older than Harrowmere. Foreman Grell called it luck. Then the cold came up the stair, and the lamps went blue, and the dead in the crypts began to knock. I hear the others below, walking. They don't answer to their names. Tell the boy his father was not afraid. That is a lie, but tell him anyway.\nYour Tobin."}]},
		"B": {"slot": Vector2i(0, 1), "size": Vector2i(10, 7), "theme": "guard", "spawn": "kkk",
			"chests": [[30, ["mace_plus1", "potion_healing"]]], "name": "Guardroom",
			"desc": "Rusted weapon racks and an overturned table. The guards who kept watch here never left their posts."},
		"C": {"slot": Vector2i(1, 1), "size": Vector2i(8, 6), "theme": "store", "spawn": "rrrrrr",
			"chests": [[40, ["potion_healing", "potion_healing", "crypt_key", "scroll_cure_wounds", "scroll_burning_hands"], 12]],
			"name": "Storeroom", "desc": "Rotten sacks and split crates. Something has been nesting in the grain."},
		"D": {"slot": Vector2i(1, 2), "size": Vector2i(9, 9), "theme": "crypt", "spawn": "kku",
			"chests": [[120, ["longsword_plus1", "studded_leather_plus1", "scroll_magic_missile"]]],
			"name": "The Old Crypt", "desc": "Stone coffins in rows. Some of the lids have been pushed aside from within.",
			"lore": [{"kind": "tablet", "title": "The Lords' Tablet",
				"text": "HERE SLEEP THE LORDS OF THE SILVER HALLS.\nTheir wealth they gave to the Hall of Hours, to be kept behind iron until the end of days. Let the thief remember: the Lords' servants never sleep, and the iron falls as easily as it rises."}]},
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
			"stairs": [false, "res://modules/wraith_below/maps/dungeon_2.tscn", "from_above"], "arrive": "from_below",
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
			# Phase 6: the vault's guardians step down from their alcoves, and the portcullis drops again
			"ambush": {"spawn": "aa", "how": "step", "seal": "d1_vault",
				"text": "With a grinding of rusted joints, two suits of armour step down from their alcoves. The Lords' servants never sleep!"},
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
			"stairs": [true, "res://modules/wraith_below/maps/dungeon_1.tscn", "from_below"], "arrive": "from_above", "start": true,
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
			"stairs": [false, "res://modules/wraith_below/maps/dungeon_3.tscn", "from_above"], "arrive": "from_below",
			"name": "Lower Stair", "desc": "Steps lead down toward the warrens. A cold draught tugs at the torch flames from one wall."},
		"J": {"slot": Vector2i(3, 1), "size": Vector2i(9, 8), "theme": "nest",
			"ambush": {"spawn": "SS", "how": "drop", "text": "Silk rustles overhead... and two giant spiders drop out of the dark on their lines!"},
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
			"name": "Hermit's Hole", "desc": "Someone lived here once, hidden from the spiders. Their bones sit by a long-dead fire.",
			"lore": [{"kind": "remains", "title": "The Hermit's Journal",
				"text": "Day 40-something. The Eye still floats in its great dome to the south. It cannot abide being looked at: it tears anyone it sees with its rays, but it is slow to turn. The spiders fear it and keep to the west. The door to its lair takes a bone key; the skeletons in their bone chapel guard one. I watched them carry it there. I will not go near either. I am old, and the silk is warm."}]},
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
			"stairs": [true, "res://modules/wraith_below/maps/dungeon_2.tscn", "from_below"], "arrive": "from_above", "start": true,
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
			"name": "War Room", "desc": "Maps of the woods pinned to the wall with daggers. The goblins were planning a raid.",
			"lore": [{"kind": "book", "title": "Goblin War Orders", "flag": "war_orders",
				"text": "(Scrawled in Goblin, with drawings.) CHIEF SAYS: The Cold King under the crypts gives us the woods if we bring him warm ones. Take the farm. Take the road. Bring the warm ones down the stair, alive, tied. Do not look at the Cold King. Do not go past the drowned crypt. Those who went past came back cold, and Chief had to burn them."}]},
		"J": {"slot": Vector2i(3, 2), "size": Vector2i(11, 9), "theme": "throne", "spawn": "GBBhh",
			"chests": [[250, ["longsword_plus2", "potion_superior_healing", "scroll_hold_person"]]],
			"stairs": [false, "res://modules/wraith_below/maps/dungeon_4.tscn", "from_above"], "arrive": "from_below",
			"name": "Throne of the Deep", "desc": "The goblin king's true seat, and beneath it, the way down."},
		# behind the portcullis: the lever in the hobgoblins' barracks lifts it
		"K": {"slot": Vector2i(3, 1), "size": Vector2i(8, 7), "theme": "store", "spawn": "hh",
			"chests": [[400, ["warhammer_plus1", "breastplate_plus1", "potion_greater_healing", "scroll_fireball"]]],
			"name": "Goblin Hoard", "desc": "The tribe's treasure, piled high behind the portcullis."},
		# Phase 6: a secret cubby behind the barracks wall
		"L": {"slot": Vector2i(3, 0), "size": Vector2i(7, 5), "theme": "bare",
			"chests": [[120, ["potion_greater_healing", "scroll_lightning_bolt", "ring_resistance"]]],
			"name": "Chief's Stash", "desc": "A cubby behind the barracks wall, where someone hid the best of the loot from the rest of the tribe."},
		# Phase 7: the goblins' holding pen: old Pell, waiting to be sold to the Cold King (side quest "The Taken")
		"M": {"slot": Vector2i(1, 3), "size": Vector2i(8, 7), "theme": "kennel", "spawn": "gg",
			"npcs": [{"id": "pell", "name": "Pell", "at": Vector2i(2, 2), "sheet": NPCS + "pell_sheet.png", "hide": "pell_left"}],
			"name": "Holding Pen", "desc": "Chains bolted to the walls, filthy straw, a water trough. The goblins keep their prisoners here. Only one is left."},
	},
	"links": [["A", "B", {"trap": {"t": "alarm", "detect": 13, "disarm": 12, "xp": 25}}], ["A", "C"], ["B", "D"], ["B", "E"],
		["C", "E"], ["D", "F"], ["E", "F"], ["C", "G", {"trap": {"t": "alarm", "detect": 15, "disarm": 12, "xp": 25}}],
		["E", "H", {"trap": {"t": "alarm", "detect": 16, "disarm": 13, "xp": 30}}], ["G", "H"],
		["H", "I", {"locked": 15, "key": "warren"}], ["I", "J"], ["F", "K", {"gate": "d3_hoard"}],
		["L", "D", {"secret": true, "sdc": 14}], ["H", "M", {"locked": 14, "key": "warren"}]],
}

var DUNGEON_4 := {
	"title": "The Sunken Crypts", "start_level": 4,
	"rooms": {
		"A": {"slot": Vector2i(0, 0), "size": Vector2i(8, 7), "theme": "flooded",
			"stairs": [true, "res://modules/wraith_below/maps/dungeon_3.tscn", "from_below"], "arrive": "from_above", "start": true,
			"name": "Flooded Stair", "desc": "Water runs down the steps and pools below. Everything smells of the grave."},
		"B": {"slot": Vector2i(1, 0), "size": Vector2i(10, 8), "theme": "ossuary", "spawn": "uuu",
			"name": "Bone Gallery", "desc": "Niches full of bones line the walls, and some of the bones are fresh."},
		"C": {"slot": Vector2i(0, 1), "size": Vector2i(10, 8), "theme": "ossuary", "spawn": "kkkkkk",
			"chests": [[70, ["mace_of_disruption", "potion_greater_healing"]]],
			"name": "Ossuary Deep", "desc": "Skeletons stand in rows, as if waiting for orders."},
		"D": {"slot": Vector2i(2, 0), "size": Vector2i(10, 8), "theme": "tomb", "spawn": "Wzzz",
			"chests": [[120, ["ring_resistance_necrotic", "potion_greater_healing"]]],
			"name": "Tomb of the Knight", "desc": "A sealed sarcophagus, and a chill in the air that is more than cold.",
			"lore": [{"kind": "tablet", "title": "Sir Aldric's Epitaph",
				"text": "SIR ALDRIC OF THE SUN, LAST KNIGHT OF THE ORDER.\nHe went down to the Vault when the king would not die, and he sealed the king in with the Sun Key, and he came back up grey and cold and did not live the winter. Let no one wake what he sealed. Plain steel did not harm it. Only fire, and faith, and blades with the old magic in them."}],
			# Phase 7: Sir Aldric's ghost shows himself once his tomb's dead are destroyed (side quest "The King's Crown")
			"npcs": [{"id": "aldric", "name": "Sir Aldric", "at": Vector2i(3, 2), "sheet": NPCS + "aldric_sheet.png", "guard": 7,
				"ghost": true, "hide": "aldric_rests"}]},
		"E": {"slot": Vector2i(1, 1), "size": Vector2i(9, 8), "theme": "crypt", "spawn": "pp",
			"name": "Chapel of Whispers", "desc": "Faint voices whisper just out of hearing."},
		"F": {"slot": Vector2i(2, 1), "size": Vector2i(10, 8), "theme": "flooded", "spawn": "Uuu",
			"name": "Sunken Hall", "desc": "Black water up to the knees. Something cold brushes past your legs."},
		"G": {"slot": Vector2i(0, 2), "size": Vector2i(11, 9), "theme": "flooded", "spawn": "zzzzu",
			"ambush": {"spawn": "zzzzz", "how": "rise", "text": "The black water heaves, and more of the drowned dead rise up all around you!"},
			"traps": [{"t": "pit", "at": "auto", "detect": 14, "disarm": 14, "save": 14, "dmg": "3d6", "xp": 40}],
			"name": "Drowned Crypt", "desc": "Bloated dead stir in the flooded crypt."},
		"H": {"slot": Vector2i(1, 2), "size": Vector2i(9, 8), "theme": "tomb", "spawn": "M",
			"chests": [[90, ["potion_superior_healing", "scroll_mass_healing_word", "scroll_hold_person"]]],
			"name": "The Embalmer's Tomb", "desc": "Linen wrappings and jars of spice. One sarcophagus stands open, and empty."},
		"I": {"slot": Vector2i(2, 2), "size": Vector2i(11, 9), "theme": "crypt", "spawn": "WW",
			"chests": [[200, ["plate_armor_plus1", "shortbow_plus2", "potion_greater_healing"]]],
			"name": "Crypt of the Wights", "desc": "Two stone thrones face the door. Their sitters are not dead enough."},
		"J": {"slot": Vector2i(3, 2), "size": Vector2i(9, 8), "theme": "tomb", "spawn": "UU",
			"stairs": [false, "res://modules/wraith_below/maps/dungeon_5.tscn", "from_above"], "arrive": "from_below",
			"name": "Lower Stair", "desc": "The way down to the Sealed Vault. The walls are carved with warnings."},
		"K": {"slot": Vector2i(3, 1), "size": Vector2i(8, 7), "theme": "crypt", "spawn": "uukk",
			"chests": [[110, ["rapier_plus2", "potion_superior_healing"]], [0, [], 0, "", true]],   # the second chest is a mimic
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
			"stairs": [true, "res://modules/wraith_below/maps/dungeon_4.tscn", "from_below"], "arrive": "from_above", "start": true,
			"name": "Vault Stair", "desc": "The last stair. The air down here is still, and very cold."},
		"B": {"slot": Vector2i(1, 0), "size": Vector2i(10, 8), "theme": "tomb", "spawn": "M",
			"chests": [[80, ["potion_superior_healing", "scroll_mass_healing_word"]]],
			"name": "Antechamber", "desc": "A mummified guardian stands in its alcove, wrapped in rotting linen."},
		"C": {"slot": Vector2i(0, 1), "size": Vector2i(10, 8), "theme": "crypt", "spawn": "pppkk",
			"name": "Hall of Specters", "desc": "Pale lights drift between the coffins."},
		"D": {"slot": Vector2i(2, 0), "size": Vector2i(10, 8), "theme": "tomb", "spawn": "Wkkkkkk",
			"chests": [[120, ["studded_leather_plus2", "potion_superior_healing"]]],
			"name": "Bone Throne", "desc": "Skeletons kneel before an empty throne.",
			"lore": [{"kind": "book", "title": "The Last Chronicle of the Vault",
				"text": "In the ninth year of his reign King Ostric grew afraid of death. He paid a nameless thing below the world for a crown that would keep him, and it kept him: his flesh went, and his warmth went, and still he ruled, a wraith upon a black throne, and his court knelt to him until they died and knelt still. The crown is the chain that holds him here. He hungers for the warmth of the living, and he walks through walls, and his touch drinks life away."}]},
		"E": {"slot": Vector2i(1, 1), "size": Vector2i(11, 9), "theme": "vault", "spawn": "M",
			"ambush": {"spawn": "yy", "how": "drop", "seal": "d5_vault",
				"text": "Stone wings crack open above the pillars: the gargoyles were never statues at all!"},
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
			"name": "Last Gate", "desc": "Beyond this lies the Wraith's vault. A great lock shaped like a sun waits for its key.",
			"lore": [{"kind": "tablet", "title": "The Warning at the Last Gate",
				"text": "TURN BACK. THE KING WHO WOULD NOT DIE SITS BEYOND.\nHe feeds on the warmth of the living. Bring light, bring holy fire, bring blades of old magic. Do not let him touch you twice."}]},
		# the Wraith's vault: only the Sun Key opens it
		"J": {"slot": Vector2i(3, 2), "size": Vector2i(11, 9), "theme": "vault", "spawn": "Xp",
			"chests": [[1000, ["ring_protection", "shield_plus2", "potion_superior_healing", "scroll_mass_healing_word", "crown_ostric"]]],
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
		["B", "D"], ["B", "E", {"seal": "d5_vault"}], ["C", "E", {"seal": "d5_vault"}], ["C", "G"],
		["D", "F", {"trap": {"t": "darts", "detect": 15, "disarm": 15, "atk": 7, "dmg": "2d10", "xp": 50}}], ["E", "F", {"seal": "d5_vault"}],
		["G", "H", {"trap": {"t": "spikes", "detect": 16, "disarm": 15, "save": 14, "dmg": "3d6", "xp": 50}}],
		["E", "H", {"seal": "d5_vault"}], ["F", "I"], ["H", "I"], ["I", "J", {"locked": 0, "key": "vault"}],
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
			"lore": [{"kind": "tablet", "at": Vector2i(10, 6), "title": "A Weathered Headstone",
				"text": "GRELL, FOREMAN OF THE HARROW MINE.\nHe dug too deep. The mine is shut by order of the reeve, and its dead are buried here. They did not stay buried."}],
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
			"lore": [{"kind": "remains", "at": Vector2i(4, 3), "title": "A Trader's Ledger",
				"text": "Bought: rope, lamp oil, picks for the mine. Sold: salt. The road is bad: goblins, more every week, and they take people, not goods. Brannoc says there is a fortune in the old mine for anyone brave enough, and he will buy whatever comes up out of it. Brannoc is braver than I am. I turn back tomorrow."}],
			"name": "The Old Road", "desc": "A forgotten road, half swallowed by the forest. Goblin tracks everywhere."},
		# the old silver mine: the way down
		"mine": {"rect": Rect2i(44, 4, 15, 12), "spawn": "Gggg", "campfire": [Vector2i(4, 7)],
			"props": [["tent", Vector2i(2, 4)], ["crate", Vector2i(11, 1)], ["barrel", Vector2i(12, 1)], ["rubble", Vector2i(13, 7)]],
			"stairs": [Vector2i(7, 0), "res://modules/wraith_below/maps/dungeon_1.tscn", "from_above"], "arrive": [Vector2i(7, 2), "from_below", F.SOUTH_WEST],
			"chests": [[50, ["scimitar", "potion_healing"], Vector2i(13, 2)]],
			# Brannoc the trader (Npc) at his stall; he hides until the goblins here are dead. The Rune of
			# Return's portal opens beside the stall, the party arriving next to it.
			"trader": {"stall": Vector2i(11, 6), "npc": Vector2i(11, 7), "portal": Vector2i(8, 8), "arrive": Vector2i(8, 9)},
			# Phase 7: Hanna waits by the fire (she hid with Brannoc); Pell turns up once freed from the Warrens
			"npcs": [{"id": "hanna", "name": "Hanna", "at": Vector2i(5, 8), "sheet": NPCS + "hanna_sheet.png", "guard": 12, "calls": false},
				{"id": "pell", "name": "Pell", "at": Vector2i(3, 6), "sheet": NPCS + "pell_sheet.png", "show": "pell_left", "calls": false, "face_right": true}],
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


func _init() -> void:
	var only := Array(OS.get_cmdline_user_args())
	var maps := [
		["surface", SURFACE, "Surface"], ["dungeon_1", DUNGEON_1, "Dungeon1"], ["dungeon_2", DUNGEON_2, "Dungeon2"],
		["dungeon_3", DUNGEON_3, "Dungeon3"], ["dungeon_4", DUNGEON_4, "Dungeon4"], ["dungeon_5", DUNGEON_5, "Dungeon5"],
	]
	var b := MapBuilder.new()
	var ok := true
	var total := 0
	DirAccess.make_dir_recursive_absolute(OUT)
	for m in maps:
		var xp := b.xp_of(m[1])
		total += xp
		if not only.is_empty() and not m[0] in only:
			print("build_maps: %s skipped (%d XP, %d running total)" % [m[0], xp, total])
			continue
		b.rnd.seed = hash(m[0])
		var path: String = OUT + "%s.tscn" % m[0]
		if m[0] == "surface":
			ok = b.build_surface(m[1], m[2], path) and ok
		else:
			ok = b.build_floor(m[1], m[2], path) and ok
		print("build_maps: %s %d XP (running total %d = %d each)" % [m[0], xp, total, total / 4])
	quit(0 if ok else 1)
