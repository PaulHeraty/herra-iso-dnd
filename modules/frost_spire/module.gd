extends AdventureModule
## Module 2: "The Frost Spire" (levels 5 -> 9). Jarl Skarn of Skarhold sends the heroes north into
## the Frostfell against Morvaine the Rimecaller, a wizard whose blizzards bury the land. His tower
## stands in a vale walled in by enchanted ice: the three old beacons of the Frostfell, lit together,
## melt the ward. A young white dragon guards the tower; Hilde, the jarl's quartermaster, has a camp
## by it (shop, the Rune of Return rebound, two side quests). Five floors up, the Rimecaller waits.
##   maps/       frostfell (the snow lands) + tower_1..5, built by build_maps.gd (in this folder)
##   story/      hilde_talk.gd (the camp: quests, shop, the rune), tamsin_talk.gd (the apprentice)

const MAPS := "res://modules/frost_spire/maps/"


func _init() -> void:
	title = "The Frost Spire"
	tagline = "An endless winter, a hidden tower of ice, and the wizard who made them both."
	description = "Jarl Skarn of Skarhold needs heroes. A wizard called the Rimecaller has buried the north in snow, and his tower hides in a vale walled in by enchanted ice. Winter wolves, trolls, a white dragon, and five floors of golems, mages and worse."
	level_min = 5
	level_max = 6
	level_end = 9
	start_map = MAPS + "frostfell.tscn"
	intro_pages = [
		"Word of your victory beneath the Harrow Woods travelled far. Before the songs were even finished, a rider came south with a message from Jarl Skarn of Skarhold.",
		"A wizard called Morvaine, the Rimecaller, has raised a tower of ice in the Frostfell. His blizzards bury whole villages and his creatures hunt the roads. The jarl's scouts went north to find him, and never came back.",
		"Their last message spoke of a hidden vale walled in by enchanted ice, and of the three old beacons of the Frostfell. Now you stand at the top of the frozen pass, and the wind is screaming...",
	]
	epilogue = "Morvaine the Rimecaller is no more. His tower groans and cracks as the spell that held it melts away, the blizzards die over the Frostfell, and spring comes north for the first time in three years. In Skarhold they will tell this story for a hundred winters."
	quest_title = "The Rimecaller"
	quest_giver = "Jarl Skarn of Skarhold"
	quest_where = "by his rider's message"
	quest_hint = ""
	reward_gold = 5000
	reward_item = "amulet_health"
	quest_stages = [
		{id = "beacons", text = "Light the three beacons of the Frostfell to break the ice ward.", flag = "beacons_lit", xp = 3000},
		{id = "dragon", text = "Slay the white dragon that guards the tower.", kill = "young_white_dragon", xp = 3000},
		{id = "hilde", text = "Find the jarl's quartermaster, Hilde, in the hidden vale.", flag = "met_hilde", xp = 1000},
		{id = "tower", text = "Enter the Rimecaller's tower.", map = MAPS + "tower_1.tscn", xp = 2000},
		{id = "library", text = "Climb to the library.", map = MAPS + "tower_2.tscn", xp = 2000},
		{id = "rime_key", text = "Find the Rime Key: it opens the stair up from the laboratory.", item = "rime_key", xp = 1000},
		{id = "lab", text = "Climb to the laboratory.", map = MAPS + "tower_3.tscn", xp = 2000},
		{id = "chapel", text = "Climb to the frost chapel.", map = MAPS + "tower_4.tscn", xp = 2000},
		{id = "star_key", text = "Find the Star Key to the observatory.", item = "star_key", xp = 2000},
		{id = "observatory", text = "Reach the observatory at the top of the tower.", map = MAPS + "tower_5.tscn", xp = 2000},
		{id = "rimecaller", text = "Defeat Morvaine the Rimecaller.", kill = "frost_wizard", xp = 10000},
		{id = "reward", text = "Return to Hilde with the news.", claim = true, xp = 3000},
	]
	side_quests = [
		{id = "sunfire", title = "The Sunfire Lantern", giver = "Hilde", where = "at her camp in the vale",
			reward_gold = 1500, reward_item = "cloak_protection",
			stages = [
				{id = "find", text = "Find Hilde's Sunfire Lantern somewhere in the tower.", item = "sunfire_lantern", xp = 1000},
				{id = "back", text = "Bring the lantern back to Hilde.", claim = true, xp = 2000},
			]},
		{id = "tamsin", title = "The Lost Apprentice", giver = "Hilde", where = "at her camp in the vale",
			reward_gold = 1000, reward_item = "scroll_mass_cure_wounds",
			stages = [
				{id = "find", text = "Find Tamsin, Hilde's niece, held somewhere in the tower.", flag = "met_tamsin", xp = 1000},
				{id = "free", text = "Free Tamsin from her cell.", flag = "tamsin_free", xp = 2000},
				{id = "home", text = "Send Tamsin back to the camp.", flag = "tamsin_left"},
				{id = "back", text = "Tell Hilde her niece is safe.", claim = true, xp = 2000},
			]},
	]
	portal_home_map = MAPS + "frostfell.tscn"
	module_items = ["sunfire_lantern"]
	# A brand-new party starting here (not one carried on from The Wraith Below): level 5, kitted out.
	new_party_kit = {
		"fighter": ["longsword_plus1", "shield_plus1", "chain_mail_plus1", "longbow"],
		"rogue": ["rapier_plus1", "shortbow_plus1", "studded_leather_plus1"],
		"cleric": ["mace_plus1", "shield", "chain_mail", "ring_protection"],
		"wizard": ["quarterstaff", "light_crossbow", "ring_protection"],
	}
	new_party_gold = 1500


## The jarl's message is the quest: it is under way from the first step.
func on_start(map: DungeonMap) -> void:
	Quest.given = true
	map.quest_check.call_deferred()


func npc_talk(map: DungeonMap, npc: Npc) -> bool:
	match npc.npc_id:
		"hilde":
			HildeTalk.start(map, npc)
			return true
		"tamsin":
			TamsinTalk.start(map, npc)
			return true
	return false
