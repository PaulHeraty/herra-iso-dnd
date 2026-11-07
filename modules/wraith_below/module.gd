extends AdventureModule
## Module 1: "The Wraith Below" (levels 1 -> 5). Four friends set out from their village into the
## Harrow Woods; Brannoc the trader at the old silver mine sends them down five floors to destroy
## the Wraith that broke out of the Sealed Vault.
##   maps/       surface (the woods) + dungeon_1..5, built by build_maps.gd (in this folder)
##   story/      trader_talk.gd (Brannoc: the quest, the shop, the reward, side quest "The Taken"),
##               hanna_talk.gd ("Word of Tobin"), pell_talk.gd (the goblins' prisoner), aldric_talk.gd (Sir
##               Aldric's ghost: "The King's Crown")

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
	quest_hint = "Someone in the Harrow Woods may need help: the old silver mine in the north is a good place to start asking."
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
	# Phase 7: three side quests. Brannoc asks after old Pell, whom the goblins dragged off from his farm;
	# Hanna (at the mine camp) waits for word of her husband Tobin, one of Grell's miners; Sir Aldric's
	# ghost, bound to his tomb in the Sunken Crypts, wants the Wraith's crown laid beside him.
	side_quests = [
		{id = "taken", title = "The Taken", giver = "Brannoc", where = "at his stall by the old silver mine",
			reward_gold = 250, reward_item = "potion_superior_healing",
			stages = [
				{id = "find", text = "Find old Pell, carried off by the goblins from his farmstead.", flag = "met_pell", xp = 200},
				{id = "free", text = "Get Pell out of the goblin warrens.", flag = "pell_left", xp = 300},
				{id = "back", text = "Tell Brannoc that Pell is safe.", claim = true, xp = 200},
			]},
		{id = "tobin", title = "Word of Tobin", giver = "Hanna", where = "at the camp by the old silver mine",
			reward_gold = 60, reward_item = "",
			stages = [
				{id = "find", text = "Learn what became of Tobin, one of Foreman Grell's miners.", flag = "tobin_letter", xp = 100},
				{id = "back", text = "Bring Hanna word of her husband.", claim = true, xp = 200},
			]},
		{id = "crown", title = "The King's Crown", giver = "Sir Aldric's ghost", where = "in his tomb in the Sunken Crypts",
			reward_gold = 0, reward_item = "cloak_protection",
			stages = [
				{id = "wraith", text = "Destroy the Wraith, King Ostric, in the Sealed Vault.", kill = "wraith"},
				{id = "take", text = "Take the Crown of Ostric from the Wraith's vault.", item = "crown_ostric", xp = 300},
				{id = "lay", text = "Lay the crown in Sir Aldric's tomb, in the Sunken Crypts.", claim = true, xp = 1000},
			]},
	]
	portal_home_map = MAPS + "surface.tscn"
	module_items = ["crown_ostric"]       # the Rune of Return goes on with the party (rebind it in the next adventure)


func npc_talk(map: DungeonMap, npc: Npc) -> bool:
	match npc.npc_id:
		"brannoc":
			TraderTalk.start(map, npc)
		"hanna":
			HannaTalk.start(map, npc)
		"pell":
			PellTalk.start(map, npc)
		"aldric":
			AldricTalk.start(map, npc)
		_:
			return false
	return true


## The ending changes with the story the party made.
func epilogue_text() -> String:
	var s := "The Wraith is destroyed, the dead lie still beneath the Harrow Woods, and the old silver mine falls quiet."
	var extra: Array[String] = []
	if Quest.side_claimed("crown"):
		extra.append("Sir Aldric sleeps at last beside the crown he guarded.")
	if Quest.side_claimed("taken") or Quest.has_flag("pell_left"):
		extra.append("Old Pell is rebuilding his farm.")
	if Quest.side_claimed("tobin"):
		extra.append("Hanna knows that her Tobin died brave.")
	if not extra.is_empty():
		s += " " + " ".join(extra)
	return s + " Songs will be sung about you in every tavern from here to the coast."
