extends AdventureModule
## Module 1: "The Wraith Below" (levels 1 -> 5). Four friends set out from their village into the
## Harrow Woods; Brannoc the trader at the old silver mine sends them down five floors to destroy
## the Wraith that broke out of the Sealed Vault.
##   maps/       surface (the woods) + dungeon_1..5, built by build_maps.gd (in this folder)
##   story/      trader_talk.gd (Brannoc: the quest, the shop, the reward)

const MAPS := "res://modules/wraith_below/maps/"


func _init() -> void:
	title = "The Wraith Below"
	tagline = "Five floors down an old silver mine, to the vault where the dead walk."
	description = "Four friends leave their village for the Harrow Woods, in search of adventure. At the old silver mine a trader has a job for them: something woke in the deep, and the dead walk the tunnels. Goblins, spiders, an Eye Tyrant, and the Wraith itself."
	level_min = 1
	level_max = 1
	level_end = 5
	start_map = MAPS + "surface.tscn"
	intro_pages = [
		"You and your three oldest friends grew up together in a quiet village on the edge of the Harrow Woods. A fighter, a rogue, a cleric and a mage, and one shared dream: adventure.",
		"One spring morning you packed your gear, said your goodbyes and took the forest road, in search of gold, glory and a story worth telling.",
		"After a night camped beneath the old pines, you wake to birdsong and the smell of cold ashes. The woods are waiting. Time to see what adventure awaits...",
	]
	epilogue = "The Wraith is destroyed. The dead lie still beneath the Harrow Woods, the old silver mine falls quiet, and the miners can go home. Songs will be sung about you in every tavern from here to the coast."
	quest_title = "The Wraith Below"
	quest_giver = "Brannoc the trader"
	quest_where = "at his stall by the old silver mine"
	reward_gold = 3000
	reward_item = "ring_protection"
	quest_stages = [
		{id = "mine", text = "Go down into the old silver mine.", map = MAPS + "dungeon_1.tscn"},
		{id = "deep", text = "Find the way down from the Upper Halls.", map = MAPS + "dungeon_2.tscn"},
		{id = "bone_key", text = "Find the Bone Key to the Eye Tyrant's lair.", item = "lair_key"},
		{id = "eye", text = "Slay the Eye Tyrant in the Webbed Deep.", kill = "eye_tyrant"},
		{id = "warrens", text = "Go down to the Goblin Warrens.", map = MAPS + "dungeon_3.tscn"},
		{id = "chief_key", text = "Take the Chief's Key from the goblin chief.", item = "warren_key"},
		{id = "crypts", text = "Go down into the Sunken Crypts.", map = MAPS + "dungeon_4.tscn"},
		{id = "vault", text = "Find the way down to the Sealed Vault.", map = MAPS + "dungeon_5.tscn"},
		{id = "sun_key", text = "Find the Sun Key to the Wraith's vault.", item = "vault_key"},
		{id = "wraith", text = "Destroy the Wraith.", kill = "wraith"},
		{id = "reward", text = "Return to Brannoc for your reward.", claim = true},
	]
	portal_home_map = MAPS + "surface.tscn"
	module_items = ["rune_of_return"]


func npc_talk(map: DungeonMap, npc: Npc) -> bool:
	if npc.npc_id == "brannoc":
		TraderTalk.start(map, npc)
		return true
	return false
