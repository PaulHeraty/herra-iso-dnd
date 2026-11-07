class_name TamsinTalk
## Tamsin, Hilde's niece and the Rimecaller's runaway apprentice (module 2). Locked in a cell in the
## laboratory (the block puzzle beside it opens the portcullis: flag "tamsin_free"). Seen through the
## bars she calls for help (flag "met_tamsin"); once free she thanks the party, gives a tip about the
## Star Key, and goes back down to Hilde's camp (flag "tamsin_left": she vanishes from the tower and
## turns up by the camp fire, the second Npc with show_flag "tamsin_left").

const NAME := "Tamsin"


static func start(map: DungeonMap, npc: Npc) -> void:
	if map.hud == null:
		return
	map.hud.close_screens()
	map.hud.frame_speaker(npc)
	if Quest.has_flag("tamsin_left"):
		_at_camp(map, npc)
	elif Quest.has_flag("tamsin_free"):
		_freed(map, npc)
	else:
		_caged(map, npc)


static func _say(map: DungeonMap, npc: Npc, text: String, choices: Array) -> void:
	var at := AtlasTexture.new()
	at.atlas = npc.sheet
	at.region = Rect2(0, 0, 16, 16)
	map.hud.dialogue.say(npc.display_name, at, text, choices)


static func _bye(map: DungeonMap) -> void:
	map.hud.dialogue.close()


static func _caged(map: DungeonMap, npc: Npc) -> void:
	var first := not Quest.has_flag("met_tamsin")
	Quest.set_flag("met_tamsin")
	map.quest_check()
	var line := "Over here! Please! I'm Tamsin, his apprentice, I mean, I WAS. He locked me in when I tried to run. The plates in the pen out there open this cell, but it takes two of those great blocks to hold them down."
	if not first:
		line = "The two plates, out in the pen. Push the blocks onto both of them and the bars will lift. Please hurry!"
	_say(map, npc, line, [{text = "Hold on, we'll get you out.", call = func(): _bye(map), bye = true}])


static func _freed(map: DungeonMap, npc: Npc) -> void:
	_say(map, npc, "You did it! Thank you, thank you. Listen: Morvaine keeps the [color=#ffdc78]Star Key[/color] to his observatory with the captain of his guard, in the frost chapel above. I know the servants' stair down. I'll go to Aunt Hilde's camp. Tell her I'm coming!",
			[{text = "Go, and stay safe.", call = func():
				Quest.set_flag("tamsin_left")
				map.quest_check()
				_bye(map), bye = true}])


static func _at_camp(map: DungeonMap, npc: Npc) -> void:
	var line := "Aunt Hilde won't stop feeding me. Be careful up there. He's stronger near the top: the cold feeds him."
	if Quest.claimed or Quest.is_done("rimecaller"):
		line = "He's really gone? Then the winter can finally end. I think I'll learn my magic somewhere warmer."
	_say(map, npc, line, [{text = "Goodbye", call = func(): _bye(map), bye = true}])
