class_name AdventureModule
extends RefCounted
## One adventure ("module"): a story the party plays from start to finish, after which the same
## party can go on to the next module. Each module is a folder, res://modules/<id>/, holding:
##   module.gd     extends AdventureModule and fills in the fields below in _init() (and overrides
##                 the hooks it needs, e.g. npc_talk)
##   maps/         its map scenes (DungeonMap), usually built by a build_maps.gd in the folder
##   story/        its own story scripts (NPC dialogue...)
## Modules share everything else: the engine (scripts/), the rules data (data/: heroes, monsters,
## items, spells) and the art and sounds (assets/). Modules (the registry) finds the folders.

## Folder name under res://modules/ (set by Modules when it loads the module).
var id := ""
var title := ""
## One line under the title on the adventure list.
var tagline := ""
## A few sentences for the adventure list.
var description := ""
## The party levels the module is made to be started at (the adventure list only lets a party
## within this range start it), and the level the party should reach by its end.
var level_min := 1
var level_max := 1
var level_end := 1
## The first map and the PartyStart entry_id the party starts at ("" = the map's own entry_id).
var start_map := ""
var start_entry := ""
## The story pages typed out before the first map (the start screen's intro).
var intro_pages: Array[String] = []
## The epilogue on the victory screen.
var epilogue := ""

## The module's quest (Quest): its title, who gives it and where, the reward, and its stages:
## [{id, text, map | item | kill | claim}] (see Quest).
var quest_title := ""
var quest_giver := ""
var quest_where := ""
var reward_gold := 0
var reward_item := ""
var quest_stages: Array[Dictionary] = []

## Where the Rune of Return's portal comes out (RunePortal; "" = the module has no rune).
var portal_home_map := ""
var portal_home_entry := "portal"

## Items that belong to this story and stay behind when the party moves on to another module
## (keys, the rune...). Items with a key_id are left behind anyway.
var module_items: Array[String] = []


## res://modules/<id>/
func folder() -> String:
	return "res://modules/%s/" % id


## Does this map scene belong to the module?
func owns(scene_path: String) -> bool:
	return scene_path.begins_with(folder())


## Can a party of this level start it?
func fits_level(level: int) -> bool:
	return level >= level_min and level <= level_max


## "Level 1" / "Levels 3-5" for the adventure list.
func level_text() -> String:
	return "Level %d" % level_min if level_min == level_max else "Levels %d-%d" % [level_min, level_max]


## Hook: talk to an NPC (DungeonMap.talk_to). Return true if the module handled it.
func npc_talk(_map: DungeonMap, _npc: Npc) -> bool:
	return false
