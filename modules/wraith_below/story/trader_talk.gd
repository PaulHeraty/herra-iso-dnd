class_name TraderTalk
## What Brannoc the trader says (the Npc by the mine; DungeonMap.talk_to). The first time the
## party sees him after the goblins are dead he calls them over: thanks, the story of the mine,
## the quest (Quest), the Rune of Return, and a side quest: old Pell, whom the goblins carried off
## from his farm ("The Taken"). He points the party to Hanna (HannaTalk), who waits at his camp.
## After that: trade (ShopScreen), "Ask about..." (what's next, the mine, the goblins), handing in
## Pell, and once the Wraith is destroyed, the reward. His greeting follows the party's progress.

## What he sells (ids in data/items/; prices = ItemData.value_gp). Plain gear for the early
## levels, potions and scrolls, and magic gear to save up for. Not the quest's reward ring.
const STOCK := [
	"potion_healing", "potion_greater_healing", "potion_superior_healing",
	"scroll_cure_wounds", "scroll_healing_word", "scroll_bless", "scroll_magic_missile",
	"scroll_burning_hands", "scroll_scorching_ray", "scroll_hold_person", "scroll_fireball",
	"scroll_lightning_bolt", "scroll_mass_healing_word",
	"longbow", "heavy_crossbow", "chain_mail", "breastplate", "half_plate", "plate_armor", "shield",
	"longsword_plus1", "mace_plus1", "rapier_plus1", "shortbow_plus1", "shield_plus1",
	"studded_leather_plus1", "chain_mail_plus1", "ring_resistance_necrotic", "plate_armor_plus1",
	"longsword_plus2", "flame_tongue",
]
const GOLD := "[color=#ffd75a]%s[/color]"
const MAGIC := "[color=#96aaff]%s[/color]"
const NOTE := "[color=#ffdc78]%s[/color]"
const MAPS := "res://modules/wraith_below/maps/"


static func start(map: DungeonMap, npc: Npc) -> void:
	if map.hud == null:
		return
	map.hud.close_screens()
	map.hud.frame_speaker(npc)
	if not Quest.met:
		Quest.met = true
		_intro(map, npc, 0)
	elif not Quest.given:
		_intro(map, npc, 1)
	else:
		_hub(map, npc, "")


static func _say(map: DungeonMap, npc: Npc, text: String, choices: Array) -> void:
	var at := AtlasTexture.new()
	at.atlas = npc.sheet
	at.region = Rect2(0, 0, 16, 16)
	map.hud.dialogue.say(npc.display_name, at, text, choices)


static func _intro(map: DungeonMap, npc: Npc, page: int) -> void:
	var next := func(): _intro(map, npc, page + 1)
	match page:
		0:
			_say(map, npc, "Easy there, friends, I'm no goblin! Name's Brannoc. I trade with the miners up here... or I did. That lot had me hiding behind my stall for two days. You have my thanks.",
					[{text = "Continue", call = next}])
		1:
			_say(map, npc, "Something woke in the old silver mine. Foreman Grell's crew dug into a sealed vault five levels down, and a [color=#c8d8ff]wraith[/color] came out of it. Now the dead walk the tunnels, and nobody who goes down comes back up.",
					[{text = "Continue", call = next}])
		2:
			var ring := ItemData.get_item(Quest.reward_item())
			_say(map, npc, ("You look like you can handle yourselves. Go down there and destroy that wraith, and I'll pay you " + GOLD + " and give you the best thing in my stock: a " + MAGIC + ".") % ["%d gold" % Quest.reward_gold(), ring.display_name],
					[{text = "We'll do it.", call = next}])
		3:
			Quest.given = true
			if not map.inventory.has("rune_of_return"):
				map.inventory.add("rune_of_return")
			RunePortal.bound = true
			Sfx.play("quest_update", -6.0)
			map.quest_check()
			_say(map, npc, ("Take this: a " + MAGIC + ". Use it anywhere below (it's in your bag) and a portal opens back to my stall. Step through it again and you're right back where you were. It never runs dry.") % "Rune of Return",
					[{text = "Thank you.", call = next}])
		4:
			Quest.give_side("taken")
			Sfx.play("quest_update", -6.0)
			map.quest_check()
			_say(map, npc, ("One more thing. The goblins burned old " + NOTE + "'s farm on the woods road and dragged him off alive. They're taking people, not just goods. If he's still breathing down there, bring him out, and I'll make it worth your while.") % "Pell",
					[{text = "We'll look for him.", call = next}])
		5:
			_say(map, npc, ("And that's " + NOTE + " by the fire. Her husband Tobin went down with Grell's crew. She's been waiting here a week for news. Have a word with her, if you've a moment. Now: come and trade when you've gold to spend!") % "Hanna",
					[{text = "Trade", call = func(): _trade(map, npc)}, {text = "Goodbye", call = func(): _bye(map), bye = true}])


## The usual talk once the quest is given.
static func _hub(map: DungeonMap, npc: Npc, line: String) -> void:
	var choices: Array = []
	if Quest.reward_due():
		if line == "":
			line = "You did it! I felt the cold lift off the mine the moment that thing fell. The miners will sing about you for years."
		choices.append({text = "Our reward", call = func(): _reward(map, npc)})
	elif line == "":
		line = _greeting()
	if Quest.side_reward_due("taken"):
		choices.append({text = "Pell is safe", call = func(): _pell_back(map, npc)})
	choices.append({text = "Trade", call = func(): _trade(map, npc)})
	choices.append({text = "Ask about...", call = func(): _ask(map, npc, "")})
	choices.append({text = "Goodbye", call = func(): _bye(map), bye = true})
	_say(map, npc, line, _fit(choices))


## The dialogue box takes four choices: keep Goodbye, drop "Ask about..." first.
static func _fit(choices: Array) -> Array:
	while choices.size() > 4:
		choices.remove_at(choices.find_custom(func(c): return c.text == "Ask about..."))
	return choices


## A greeting that knows how far down the party has got.
static func _greeting() -> String:
	if Quest.claimed:
		return "The heroes of the Harrow Woods! What can I do for you?"
	var lines: Array[String] = ["Back already? Good, the rune works. What do you need?",
			"Still in one piece, I see. Need supplies?", "Welcome back. Anything catch your eye?"]
	if Quest.kills.get("wraith", 0) > 0:
		lines = ["You did it! Come, sit by the fire."]
	elif Quest.visited.has(MAPS + "dungeon_5.tscn"):
		lines = ["You've been to the Sealed Vault? You've frost in your hair. What do you need?",
				"The bottom of the mine... I didn't think anyone would get that far. Stock up while you can."]
	elif Quest.visited.has(MAPS + "dungeon_4.tscn"):
		lines = ["The crypts? Gods. You smell of the grave, friends. What do you need?",
				"Down among the dead, are you? Then you'll want potions. Lots of potions."]
	elif Quest.is_done("chief_key"):
		lines = ["Word is the goblin chief is dead. The road will be safer for it. What can I get you?"]
	elif Quest.kills.get("eye_tyrant", 0) > 0:
		lines = ["You killed the Eye? Hah! I'd have paid to see that. What do you need?",
				"The one-eyed horror of the Webbed Deep, dead. I'll drink to that. Anything you need?"]
	if Quest.side_claimed("taken"):
		lines.append("Pell's been chopping my firewood all morning. Says it beats a goblin cage. What do you need?")
	return lines[randi() % lines.size()]


# --- ask about... ------------------------------------------------------------------------------

static func _ask(map: DungeonMap, npc: Npc, line: String) -> void:
	if line == "":
		line = "Ask away. I know the woods and the mine as well as anyone still breathing."
	var choices: Array = []
	if not Quest.claimed and not Quest.reward_due():
		choices.append({text = "What next?", call = func(): _about(map, npc)})
	choices.append({text = "The mine", call = func(): _mine(map, npc)})
	choices.append({text = "The goblins", call = func(): _goblins(map, npc)})
	choices.append({text = "Back", call = func(): _hub(map, npc, "Anything else?"), bye = true})
	_say(map, npc, line, choices)


static func _about(map: DungeonMap, npc: Npc) -> void:
	var cur := Quest.current()
	var s: String = Quest.stages()[cur].text if cur >= 0 else ""
	var tip: String = {
		"mine": "The mine entrance is just there in the hillside.",
		"deep": "The Upper Halls were the miners' old workings. The way down is somewhere at the far end.",
		"bone_key": "The miners said the spiders' deep has a lair behind a door carved from bone. The key won't be far.",
		"eye": "Something with one great eye rules the Webbed Deep. Don't let it stare at you.",
		"warrens": "Below the webs, goblins. Lots of goblins.",
		"chief_key": "Goblin chiefs keep their keys close. Find the biggest goblin.",
		"crypts": "The old miners buried their dead deep. Too deep, maybe.",
		"vault": "The Sealed Vault is the bottom of it all. That's where the wraith came from.",
		"sun_key": "The vault was sealed with a gold key, they say. Someone down there has it.",
		"wraith": "Magic or silver hurts it most. Don't let it touch you; it drains the life right out of you.",
	}.get(Quest.stages()[cur].id if cur >= 0 else "", "")
	_ask(map, npc, (("Next: " + NOTE + " %s") % [s, tip]).strip_edges())


static func _mine(map: DungeonMap, npc: Npc) -> void:
	var line := "The Harrow mine gave good silver for forty years. Then Grell's crew broke into old halls under the seam: carved stone, older than Harrowmere. Grell called it luck. A month later the reeve shut the mine and buried what came up of the crew."
	if Quest.has_flag("tobin_letter"):
		line = "Grell broke into those old halls, and the cold came up the stair after him. You've seen it yourself now. Poor Tobin. Poor all of them."
	_ask(map, npc, line)


static func _goblins(map: DungeonMap, npc: Npc) -> void:
	var line := "Goblins have always raided the woods road, but never like this. More every week, and bolder. And they take people. Alive. Why would a goblin want a prisoner it doesn't eat?"
	if Quest.has_flag("war_orders"):
		line = "A 'Cold King' under the crypts, trading the woods for living prisoners? That's your wraith, or I'm a dwarf. It wants the warmth of the living, and the goblins have been feeding it."
	elif Quest.is_done("chief_key"):
		line = "With their chief dead the rest are scattering. Good riddance. I still wonder what they wanted with all those prisoners."
	_ask(map, npc, line)


# --- rewards ---------------------------------------------------------------------------------------

static func _pell_back(map: DungeonMap, npc: Npc) -> void:
	Quest.claim_side("taken", map.inventory)
	var q := Quest.side_def("taken")
	Sfx.play("coins")
	FloatText.spawn(map, npc.position + Vector2(0, -28), "+%d gold" % q.reward_gold, Color8(255, 215, 90))
	map.quest_check()
	var it := ItemData.get_item(q.reward_item)
	_hub(map, npc, ("Pell turned up at my fire last night, thin as a rake and swearing like a goblin. I owe you. Here: " + GOLD + " and a " + MAGIC + ". You'll need it more than I do.") % ["%d gold" % q.reward_gold, it.display_name])


static func _reward(map: DungeonMap, npc: Npc) -> void:
	Quest.claim(map.inventory)
	Sfx.play("coins")
	var ring := ItemData.get_item(Quest.reward_item())
	FloatText.spawn(map, npc.position + Vector2(0, -28), "+%d gold" % Quest.reward_gold(), Color8(255, 215, 90))
	SpellFx.sparkles(map, npc.position + Vector2(0, -14), Color8(255, 220, 120), false)
	map.quest_check()
	# Then the win screen (VictoryScreen); after it the game goes on (he still trades).
	_say(map, npc, ("As promised: " + GOLD + ", and my " + MAGIC + ". Wear it well. You've earned it.") % ["%d gold" % Quest.reward_gold(), ring.display_name],
			[{text = "Farewell, Brannoc.", call = func(): _bye(map); map.show_victory(), bye = true}])
	# the quest's own update (the last stage) shows too
	if map.hud:
		map.hud.quest_toast([Quest.stages()[-1]])


static func _trade(map: DungeonMap, npc: Npc) -> void:
	map.hud.dialogue.close()
	map.hud.shop.open(STOCK, npc.display_name)


static func _bye(map: DungeonMap) -> void:
	map.hud.dialogue.close()
