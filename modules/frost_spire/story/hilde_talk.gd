class_name HildeTalk
## Hilde Ironbrook, Jarl Skarn's quartermaster, camped in the hidden vale below the Rimecaller's
## tower (module 2, The Frost Spire). She comes out once the white dragon is dead. First talk: who she
## is, and two side quests (Quest.give_side): her Sunfire Lantern, stolen into the tower, and her
## niece Tamsin, the Rimecaller's runaway apprentice. Then: the shop, rebinding the Rune of Return
## to her camp (RunePortal.bound), handing in the side quests, tips on the way up, and once Morvaine is
## dead the jarl's reward (then the victory screen).

const STOCK := [
	"potion_greater_healing", "potion_superior_healing", "potion_supreme_healing",
	"scroll_cure_wounds", "scroll_healing_word", "scroll_mass_healing_word", "scroll_mass_cure_wounds",
	"scroll_death_ward", "scroll_fireball", "scroll_lightning_bolt", "scroll_ice_storm", "scroll_cone_of_cold",
	"scroll_hold_person",
	"ring_warmth", "ring_resistance_fire", "ring_resistance_lightning",
	"longsword_plus2", "warhammer_plus2", "mace_plus2", "dagger_plus2", "rapier_plus2", "longbow_plus2", "shortbow_plus2",
	"chain_mail_plus2", "breastplate_plus2", "half_plate_plus2", "studded_leather_plus2", "shield_plus2",
	"gauntlets_ogre_power", "bracers_defense",
]
const NAME := "Hilde"


static func start(map: DungeonMap, npc: Npc) -> void:
	if map.hud == null:
		return
	map.hud.close_screens()
	map.hud.frame_speaker(npc)
	if not Quest.has_met("hilde"):
		_intro(map, npc, 0)
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
			Quest.set_flag("met_hilde")
			map.quest_check()
			_say(map, npc, "By the jarl's beard, you killed it! I've been crouched behind these crates for a week while that dragon picked its teeth. Hilde Ironbrook, quartermaster to Jarl Skarn. You must be his champions.",
					[{text = "Continue", call = next}])
		1:
			_say(map, npc, "That's the Rimecaller's tower, right there. I'll keep camp here and sell you what the jarl's wagons carried north. Two things, though, if you're going up there.",
					[{text = "Go on.", call = next}])
		2:
			Quest.give_side("sunfire")
			Quest.give_side("tamsin")
			Sfx.play("quest_update", -6.0)
			map.quest_check()
			_say(map, npc, "His apprentices raided our wagons and took my family's [color=#ffd75a]Sunfire Lantern[/color]. Bring it back and I'll make it worth your while. And my niece [color=#96aaff]Tamsin[/color]... she ran off to learn magic from him, the fool. She's still in there somewhere.",
					[{text = "We'll look for them both.", call = next}])
		3:
			var line := "If you carry a Rune of Return, bring it here and I'll bind it to my camp. Now, what do you need?"
			if not map.inventory.has("rune_of_return"):
				map.inventory.add("rune_of_return")
				RunePortal.bound = true
				line = "And take this: a [color=#96aaff]Rune of Return[/color], bound to my camp. Use it anywhere in that tower and you'll come straight back here. Now, what do you need?"
			_hub(map, npc, line)


## The usual talk.
static func _hub(map: DungeonMap, npc: Npc, line: String) -> void:
	var choices: Array = []
	if Quest.reward_due():
		if line == "":
			line = "The blizzard's gone. I saw the light go out at the top of the tower. You did it!"
		choices.append({text = "Our reward", call = func(): _reward(map, npc)})
	elif line == "":
		line = ["Still alive? Good. What do you need?", "Back from the tower? Warm yourselves at the fire.",
				"Mind the wind up there. Anything you need?"][randi() % 3]
	if Quest.side_reward_due("sunfire"):
		choices.append({text = "Your lantern", call = func(): _lantern(map, npc)})
	if Quest.side_reward_due("tamsin"):
		choices.append({text = "Tamsin is safe", call = func(): _tamsin(map, npc)})
	if map.inventory.has("rune_of_return") and not RunePortal.bound:
		choices.append({text = "Bind our rune", call = func(): _bind(map, npc)})
	choices.append({text = "Trade", call = func(): _trade(map, npc)})
	if not Quest.claimed and not Quest.reward_due():
		choices.append({text = "The tower", call = func(): _about(map, npc)})
	choices.append({text = "Goodbye", call = func(): _bye(map), bye = true})
	_say(map, npc, line, _fit(choices))


## The dialogue box takes four choices: keep Goodbye, drop "The tower" first if there are too many.
static func _fit(choices: Array) -> Array:
	while choices.size() > 4:
		var i := choices.find_custom(func(c): return c.text == "The tower")
		if i < 0:
			i = choices.find_custom(func(c): return c.text == "Trade")
		choices.remove_at(i)
	return choices


static func _bind(map: DungeonMap, npc: Npc) -> void:
	RunePortal.bound = true
	Sfx.play("portal_open")
	SpellFx.sparkles(map, npc.position + Vector2(0, -14), Color8(150, 186, 255), false)
	_hub(map, npc, "Hold it out... there. The rune's glow has turned blue-white: it's bound to my camp now. Use it anywhere up there and you'll come back to this fire.")


static func _about(map: DungeonMap, npc: Npc) -> void:
	var cur := Quest.current()
	var s: String = Quest.stages()[cur].text if cur >= 0 else ""
	var tip: String = {
		"tower": "The door's right there. Fire works well on whatever he keeps in there, I'd wager.",
		"library": "His apprentices keep his books on the floors above. They throw fire, mind.",
		"rime_key": "Tamsin told me once he keeps a key of ice with his accounts.",
		"lab": "Up above the books is his laboratory. He makes things in there. Things that walk.",
		"chapel": "They say he prays to the winter itself, up near the top.",
		"star_key": "The captain of his guard carries the key to the top. A star-shaped thing.",
		"observatory": "He watches the stars from the very top of the tower.",
		"rimecaller": "He's a wizard: get close, and keep your wits about you. His cold cuts deeper than any blade.",
	}.get(Quest.stages()[cur].id if cur >= 0 else "", "")
	_hub(map, npc, ("Next: [color=#ffdc78]%s[/color] %s" % [s, tip]).strip_edges())


static func _lantern(map: DungeonMap, npc: Npc) -> void:
	map.inventory.remove("sunfire_lantern")
	Quest.claim_side("sunfire", map.inventory)
	var q := Quest.side_def("sunfire")
	Sfx.play("coins")
	FloatText.spawn(map, npc.position + Vector2(0, -28), "+%d gold" % q.reward_gold, Color8(255, 215, 90))
	map.quest_check()
	var it := ItemData.get_item(q.reward_item)
	_hub(map, npc, "My grandmother's lantern! Still burning, after all that. Here: [color=#ffd75a]%d gold[/color], and my old [color=#96aaff]%s[/color]. It kept me alive in worse places than this." % [q.reward_gold, it.display_name])


static func _tamsin(map: DungeonMap, npc: Npc) -> void:
	Quest.claim_side("tamsin", map.inventory)
	var q := Quest.side_def("tamsin")
	Sfx.play("coins")
	FloatText.spawn(map, npc.position + Vector2(0, -28), "+%d gold" % q.reward_gold, Color8(255, 215, 90))
	map.quest_check()
	var it := ItemData.get_item(q.reward_item)
	_hub(map, npc, "She came stumbling into camp half frozen and talking nonstop. I could kiss you. Take this, [color=#ffd75a]%d gold[/color] and a [color=#96aaff]%s[/color]. Family pays its debts." % [q.reward_gold, it.display_name])


static func _reward(map: DungeonMap, npc: Npc) -> void:
	Quest.claim(map.inventory)
	Sfx.play("coins")
	var it := ItemData.get_item(Quest.reward_item())
	FloatText.spawn(map, npc.position + Vector2(0, -28), "+%d gold" % Quest.reward_gold(), Color8(255, 215, 90))
	SpellFx.sparkles(map, npc.position + Vector2(0, -14), Color8(255, 220, 120), false)
	map.quest_check()
	_say(map, npc, "The jarl promised [color=#ffd75a]%d gold[/color] to whoever ended the winter, and I carry his purse. And this: an [color=#96aaff]%s[/color] from his own treasury. Skarhold will never forget you." % [Quest.reward_gold(), it.display_name],
			[{text = "Farewell, Hilde.", call = func(): _bye(map); map.show_victory(), bye = true}])
	if map.hud:
		map.hud.quest_toast([Quest.stages()[-1]])


static func _trade(map: DungeonMap, npc: Npc) -> void:
	map.hud.dialogue.close()
	map.hud.shop.open(STOCK, npc.display_name)


static func _bye(map: DungeonMap) -> void:
	map.hud.dialogue.close()
