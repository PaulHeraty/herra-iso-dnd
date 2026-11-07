class_name HannaTalk
## Hanna, wife of Tobin the miner (module 1, The Wraith Below). She waits by the fire at Brannoc's
## camp by the mine (she hid with him from the goblins: the same guard radius). First talk: her
## husband went down with Foreman Grell's crew and never came back: side quest "Word of Tobin".
## The answer lies in the Upper Halls: Tobin's last letter, on his remains by the entrance (a
## LoreNote with flag "tobin_letter"). Telling her ends the quest; the party may take her few coins
## or leave them with her (Quest.claim_side(paid = false); flag "hanna_kept").

const NAME := "Hanna"
const NOTE := "[color=#ffdc78]%s[/color]"


static func start(map: DungeonMap, npc: Npc) -> void:
	if map.hud == null:
		return
	map.hud.close_screens()
	map.hud.frame_speaker(npc)
	if not Quest.has_met("hanna"):
		_intro(map, npc, 0)
	elif Quest.side_reward_due("tobin"):
		_news(map, npc, 0)
	else:
		_hub(map, npc)


static func _say(map: DungeonMap, npc: Npc, text: String, choices: Array) -> void:
	var at := AtlasTexture.new()
	at.atlas = npc.sheet
	at.region = Rect2(0, 0, 16, 16)
	map.hud.dialogue.say(npc.display_name, at, text, choices)


static func _bye(map: DungeonMap) -> void:
	map.hud.dialogue.close()


static func _intro(map: DungeonMap, npc: Npc, page: int) -> void:
	var next := func(): _intro(map, npc, page + 1)
	match page:
		0:
			Quest.set_flag("met_hanna")
			_say(map, npc, "You're going down there? Into the mine? Then... please. My husband, Tobin. He went down with Foreman Grell's crew, a month past now, and none of them came back up.",
					[{text = "Go on.", call = next}])
		1:
			Quest.give_side("tobin")
			Sfx.play("quest_update", -6.0)
			map.quest_check()
			var line := ("I know what everyone thinks. I'm not a fool. But I need to " + NOTE + ", whatever it is. He worked the upper halls, near the old stair. If you find anything of his... anything at all.") % "know"
			_say(map, npc, line, [{text = "We'll find out what happened.", call = func():
				if Quest.side_reward_due("tobin"):
					_news(map, npc, 0)
				else:
					_bye(map), bye = true}])


static func _hub(map: DungeonMap, npc: Npc) -> void:
	var line: String
	if Quest.side_claimed("tobin"):
		line = ["I'm going home to my boy tomorrow. Brannoc has found a cart for me. Thank you, all of you.",
				"Mind yourselves down there. I'd not want anyone else waiting by this fire.",
				"I read his letter every night. He was afraid, and he went on anyway. So do you."][randi() % 3]
		if Quest.claimed:
			line = "The cold is gone from the mine, they say. Tobin can rest now. You did that."
	else:
		line = ["Any word of Tobin? He worked the upper halls, near the old stair.",
				"I keep looking at the mine, as if he'll just walk out of it.",
				"Grell said the new halls were luck. Some luck."][randi() % 3]
	_say(map, npc, line, [{text = "Goodbye", call = func(): _bye(map), bye = true}])


## The news: Tobin's letter.
static func _news(map: DungeonMap, npc: Npc, page: int) -> void:
	match page:
		0:
			_say(map, npc, "You found something. I can see it on your faces. Tell me. Please.",
					[{text = "We found his last letter.", call = func(): _news(map, npc, 1)}])
		1:
			_say(map, npc, "\"Tell the boy his father was not afraid.\" ...That's him. That's my Tobin, lying to the very end to make it easier for us. Thank you. Better to know. Better than waiting by this fire forever. Here: it's not much, but it's all we had put by.",
					[{text = "Thank you, Hanna.", call = func(): _pay(map, npc, true)},
					{text = "Keep it, for your boy.", call = func(): _pay(map, npc, false)}])


static func _pay(map: DungeonMap, npc: Npc, take: bool) -> void:
	Quest.claim_side("tobin", map.inventory, take)
	var q := Quest.side_def("tobin")
	if take:
		Sfx.play("coins")
		FloatText.spawn(map, npc.position + Vector2(0, -28), "+%d gold" % q.reward_gold, Color8(255, 215, 90))
	else:
		Quest.set_flag("hanna_kept")
	map.quest_check()
	var line := "Gods keep you down there. Bring the rest of them peace, if you can."
	if not take:
		line = "You're kind. Tobin would have liked you. Gods keep you down there, and bring the rest of them peace, if you can."
	_say(map, npc, line, [{text = "Goodbye", call = func(): _bye(map), bye = true}])
