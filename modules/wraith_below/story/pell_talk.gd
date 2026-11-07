class_name PellTalk
## Old Pell, the farmer the goblins dragged off from the Ruined Farmstead (module 1, side quest "The
## Taken", given by Brannoc). He sits in the goblins' holding pen in the Warrens, behind a locked
## door (the Chief's Key, or a pick). Found: flag "met_pell"; he tells the party where the goblins
## were taking their prisoners (the Cold King below the crypts) and where the chief hid his loot (the
## secret stash behind the hobgoblins' barracks), then makes for the surface (flag "pell_left": he
## vanishes from the pen and turns up by Brannoc's fire, the second Npc with show_flag "pell_left").

const NAME := "Pell"
const NOTE := "[color=#ffdc78]%s[/color]"


static func start(map: DungeonMap, npc: Npc) -> void:
	if map.hud == null:
		return
	map.hud.close_screens()
	map.hud.frame_speaker(npc)
	if Quest.has_flag("pell_left"):
		_at_camp(map, npc)
	else:
		_pen(map, npc, 0)


static func _say(map: DungeonMap, npc: Npc, text: String, choices: Array) -> void:
	var at := AtlasTexture.new()
	at.atlas = npc.sheet
	at.region = Rect2(0, 0, 16, 16)
	map.hud.dialogue.say(npc.display_name, at, text, choices)


static func _bye(map: DungeonMap) -> void:
	map.hud.dialogue.close()


static func _pen(map: DungeonMap, npc: Npc, page: int) -> void:
	var next := func(): _pen(map, npc, page + 1)
	match page:
		0:
			var first := not Quest.has_flag("met_pell")
			Quest.set_flag("met_pell")
			map.quest_check()
			var line := "Who's that? You're no goblins... Gods be thanked! Pell's the name. They took me off my own farm, burned the roof over my head, and they've kept me in this pen ever since."
			if not first:
				line = "Still here, still breathing. Are we going, then?"
			_say(map, npc, line, [{text = "Brannoc sent us.", call = next}])
		1:
			_say(map, npc, ("Brannoc? Bless the old miser. Listen: there were five of us in here. Every few days the goblins take one down the stair under the chief's throne, to something they call the " + NOTE + ". The ones they take don't come back.") % "Cold King",
					[{text = "What else do you know?", call = next}])
		2:
			_say(map, npc, ("One more thing, for your trouble. The chief didn't trust his own tribe. I watched him hide his best loot in a " + NOTE + " behind the hobgoblins' barracks wall. Search that wall.") % "secret cubby",
					[{text = "Go. Get out while you can.", call = func():
						Quest.set_flag("pell_left")
						map.quest_check()
						_bye(map), bye = true}])


static func _at_camp(map: DungeonMap, npc: Npc) -> void:
	var line: String = ["Brannoc's feeding me and working me half to death. Better than a goblin pen, mind.",
			"Soon as the road's safe, I'm going back to rebuild. Rats or no rats.",
			"The Cold King... I hear it in my sleep. Give it a thump from me, will you?"][randi() % 3]
	if Quest.claimed or Quest.kills.get("wraith", 0) > 0:
		line = "You killed the Cold King? Then the goblins have no one left to sell to. I'll sleep sound tonight, and every night after."
	_say(map, npc, line, [{text = "Goodbye", call = func(): _bye(map), bye = true}])
