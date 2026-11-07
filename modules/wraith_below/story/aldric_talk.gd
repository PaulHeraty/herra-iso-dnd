class_name AldricTalk
## Sir Aldric's ghost (module 1), bound to his tomb in the Sunken Crypts (the Tomb of the Knight).
## He shows himself once the dead in his tomb are destroyed. Long ago he sealed King Ostric, the
## Wraith, in the Sealed Vault with the Sun Key; now the seal is broken. First talk (flag
## "met_aldric"): who he is, how to fight the Wraith, where the Sun Key is, and side quest "The King's
## Crown": destroy the Wraith, take the Crown of Ostric from its vault and lay it in his tomb, so the
## king can never return. Laying it: the reward (his cloak), flag "aldric_rests", and he fades away
## (the Npc's hide_flag).

const NAME := "Sir Aldric"
const NOTE := "[color=#ffdc78]%s[/color]"
const MAGIC := "[color=#96aaff]%s[/color]"


static func start(map: DungeonMap, npc: Npc) -> void:
	if map.hud == null:
		return
	map.hud.close_screens()
	map.hud.frame_speaker(npc)
	if not Quest.has_met("aldric"):
		_intro(map, npc, 0)
	else:
		_hub(map, npc, "")


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
			Quest.set_flag("met_aldric")
			Sfx.play("discover", -4.0)
			_say(map, npc, "Living souls, here? Be not afraid. I am Aldric, last knight of the Order of the Sun. Once I went down to the Vault below and sealed the king who would not die behind a door of gold. I did not live the winter after.",
					[{text = "The seal is broken.", call = next}])
		1:
			_say(map, npc, "I know. I felt it break, as a sleeper feels the cold. Ostric walks again. Hear me: plain steel will not bite him. Bring fire, and faith, and blades with the old magic in them. And do not let him touch you twice.",
					[{text = "How do we reach him?", call = next}])
		2:
			_say(map, npc, ("The vault door answers only to the " + NOTE + ". His wights keep it now, in their barracks by the Last Gate. Take it from them.") % "Sun Key",
					[{text = "And when he falls?", call = next}])
		3:
			Quest.give_side("crown")
			Sfx.play("quest_update", -6.0)
			map.quest_check()
			_say(map, npc, ("His " + NOTE + " is the chain that holds him to this world. While it sits on his throne he may rise again. Bring it here and lay it in my tomb, and I will guard it until the end of days. Then, at last, I may rest.") % "crown",
					[{text = "We'll bring it.", call = func(): _hub(map, npc, "Go with the light of the Sun, friends.")}])


static func _hub(map: DungeonMap, npc: Npc, line: String) -> void:
	var choices: Array = []
	if Quest.side_reward_due("crown") and map.inventory.has("crown_ostric"):
		if line == "":
			line = "I feel it... his crown. You have it. You have truly destroyed him!"
		choices.append({text = "Lay the crown in the tomb", call = func(): _lay(map, npc, 0)})
	elif line == "":
		if Quest.kills.get("wraith", 0) > 0:
			line = "He is gone. I felt him go. But his crown still sits upon his throne. Bring it to me."
		elif map.inventory.has("vault_key"):
			line = "You carry the Sun Key. I can feel its warmth from here. Go down, and end him."
		else:
			line = ["The Sun Key. His wights keep it, in their barracks by the Last Gate.",
					"Fire, faith and old magic. Plain steel will not harm him.",
					"Do not let him touch you twice."][randi() % 3]
	choices.append({text = "Farewell", call = func(): _bye(map), bye = true})
	_say(map, npc, line, choices)


static func _lay(map: DungeonMap, npc: Npc, page: int) -> void:
	match page:
		0:
			map.inventory.remove("crown_ostric")
			Quest.claim_side("crown", map.inventory)
			Quest.set_flag("crown_laid")
			map.quest_check()
			Sfx.play("puzzle_solved", -4.0)
			SpellFx.sparkles(map, npc.position + Vector2(0, -14), Color8(255, 236, 170), false)
			var it := ItemData.get_item(Quest.side_def("crown").reward_item)
			_say(map, npc, ("It is done. The crown is in my keeping now, and the king will never wear it again. Take my " + MAGIC + ". It served me well, and it will serve you better.") % it.display_name,
					[{text = "Rest well, Sir Aldric.", call = func(): _lay(map, npc, 1), bye = true}])
		1:
			_bye(map)
			Quest.set_flag("aldric_rests")       # the Npc's hide_flag: he fades away
			SpellFx.sparkles(map, npc.position + Vector2(0, -14), Color8(200, 230, 255), false)
			if map.combat:
				map.combat._say("Sir Aldric smiles, and fades into a warm golden light.")
