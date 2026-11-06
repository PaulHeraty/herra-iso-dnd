class_name TraderTalk
## What Brannoc the trader says (the Npc by the mine; DungeonMap.talk_to). The first time the
## party sees him after the goblins are dead he calls them over: thanks, the story of the mine,
## the quest (Quest) and the Rune of Return. After that: trade (ShopScreen), ask about the quest,
## and once the Wraith is destroyed, the reward.
## Story text is placeholder-level, like the rest of the campaign's story (Phase 7).

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
			_say(map, npc, "Something woke in the old silver mine. The miners dug into a sealed vault five levels down, and a [color=#c8d8ff]wraith[/color] came out of it. Now the dead walk the tunnels, and nobody who goes down comes back up.",
					[{text = "Continue", call = next}])
		2:
			var ring := ItemData.get_item(Quest.REWARD_ITEM)
			_say(map, npc, "You look like you can handle yourselves. Go down there and destroy that wraith, and I'll pay you [color=#ffd75a]%d gold[/color] and give you the best thing in my stock: a [color=#96aaff]%s[/color]." % [Quest.REWARD_GOLD, ring.display_name],
					[{text = "We'll do it.", call = next}])
		3:
			Quest.given = true
			if not map.inventory.has("rune_of_return"):
				map.inventory.add("rune_of_return")
			Sfx.play("quest_update", -6.0)
			map.quest_check()
			_say(map, npc, "Take this: a [color=#96aaff]Rune of Return[/color]. Use it anywhere below (it's in your bag) and a portal opens back to my stall. Step through it again and you're right back where you were. It never runs dry. And come and trade when you've gold to spend!",
					[{text = "Trade", call = func(): _trade(map, npc)}, {text = "Goodbye", call = func(): _bye(map), bye = true}])


## The usual talk once the quest is given.
static func _hub(map: DungeonMap, npc: Npc, line: String) -> void:
	var choices: Array = []
	if Quest.reward_due():
		if line == "":
			line = "You did it! I felt the cold lift off the mine the moment that thing fell. The miners will sing about you for years."
		choices.append({text = "Our reward", call = func(): _reward(map, npc)})
	elif line == "":
		if Quest.claimed:
			line = "The heroes of the Harrow Woods! What can I do for you?"
		else:
			line = ["Back already? Good, the rune works. What do you need?",
					"Still in one piece, I see. Need supplies?",
					"Welcome back. Anything catch your eye?"][randi() % 3]
	choices.append({text = "Trade", call = func(): _trade(map, npc)})
	if Quest.given and not Quest.claimed and not Quest.reward_due():
		choices.append({text = "The wraith", call = func(): _about(map, npc)})
	choices.append({text = "Goodbye", call = func(): _bye(map), bye = true})
	_say(map, npc, line, choices)


static func _about(map: DungeonMap, npc: Npc) -> void:
	var cur := Quest.current()
	var s: String = Quest.STAGES[cur].text if cur >= 0 else ""
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
	}.get(Quest.STAGES[cur].id if cur >= 0 else "", "")
	_hub(map, npc, ("Next: [color=#ffdc78]%s[/color] %s" % [s, tip]).strip_edges())


static func _reward(map: DungeonMap, npc: Npc) -> void:
	Quest.claim(map.inventory)
	Sfx.play("coins")
	var ring := ItemData.get_item(Quest.REWARD_ITEM)
	FloatText.spawn(map, npc.position + Vector2(0, -28), "+%d gold" % Quest.REWARD_GOLD, Color8(255, 215, 90))
	SpellFx.sparkles(map, npc.position + Vector2(0, -14), Color8(255, 220, 120), false)
	map.quest_check()
	# Then the win screen (VictoryScreen); after it the game goes on (he still trades).
	_say(map, npc, "As promised: [color=#ffd75a]%d gold[/color], and my [color=#96aaff]%s[/color]. Wear it well. You've earned it." % [Quest.REWARD_GOLD, ring.display_name],
			[{text = "Farewell, Brannoc.", call = func(): _bye(map); map.show_victory(), bye = true}])
	# the quest's own update (the last stage) shows too
	if map.hud:
		map.hud.quest_toast([Quest.STAGES[-1]])


static func _trade(map: DungeonMap, npc: Npc) -> void:
	map.hud.dialogue.close()
	map.hud.shop.open(STOCK, npc.display_name)


static func _bye(map: DungeonMap) -> void:
	map.hud.dialogue.close()
