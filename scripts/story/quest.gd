class_name Quest
## The current module's quest (Modules.current: its quest_title, giver, reward and quest_stages).
## In "The Wraith Below", Brannoc the trader gives it once the goblins at the mine are dead. Each
## stage is ticked off when the game sees it happen (a map reached, a key in
## the bag, a monster killed). A later stage done also ticks off every stage before it (a lock
## picked instead of a key found still counts). The last stage is claiming the reward from him.
##
## Static, like PartyState: PartyState.save() snapshots it with the party, and DungeonMap._ready
## loads it back (so a restart after a wipe, R, puts the quest back as the party arrived).

## The stages come from the module: [{id, text, and what completes it}]:
##   map = reached that map; item = that item in the party bag; kill = a monster with that id killed;
##   claim = the reward taken from the quest giver.
static func stages() -> Array[Dictionary]:
	if Modules.current:
		return Modules.current.quest_stages
	var none: Array[Dictionary] = []
	return none


static func title() -> String:
	return Modules.current.quest_title if Modules.current else ""


static func giver() -> String:
	return Modules.current.quest_giver if Modules.current else ""


static func reward_gold() -> int:
	return Modules.current.reward_gold if Modules.current else 0


static func reward_item() -> String:
	return Modules.current.reward_item if Modules.current else ""

## Brannoc has spoken to the party (his first talk, where he gives the quest and the rune).
static var met := false
static var given := false
static var claimed := false
## stage id -> true
static var done := {}
## Things seen so far (also before the quest is given, so stages done early still count):
## scene path -> true, monster id -> number killed.
static var visited := {}
static var kills := {}


static func reset() -> void:
	met = false
	given = false
	claimed = false
	done = {}
	visited = {}
	kills = {}


static func to_dict() -> Dictionary:
	return {met = met, given = given, claimed = claimed, done = done.duplicate(),
			visited = visited.duplicate(), kills = kills.duplicate()}


static func from_dict(d: Dictionary) -> void:
	reset()
	met = d.get("met", false)
	given = d.get("given", false)
	claimed = d.get("claimed", false)
	done = d.get("done", {}).duplicate()
	visited = d.get("visited", {}).duplicate()
	kills = d.get("kills", {}).duplicate()


static func note_map(path: String) -> void:
	visited[path] = true


static func note_kill(monster_id: String) -> void:
	kills[monster_id] = kills.get(monster_id, 0) + 1


static func is_done(stage_id: String) -> bool:
	return done.has(stage_id)


## Index of the stage the party is on (the first not done), or -1 when the quest is finished.
static func current() -> int:
	for i in stages().size():
		if not done.has(stages()[i].id):
			return i
	return -1


static func finished() -> bool:
	return given and current() == -1


## Everything but claiming the reward is done (the Wraith is dead), and it hasn't been claimed.
static func reward_due() -> bool:
	var c := current()
	return given and not claimed and c >= 0 and stages()[c].has("claim")


## Tick off the stages that have happened. Returns the stages newly done ([{id, text}], in order).
static func update(bag: Inventory) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not given:
		return out
	var last := -1
	for i in stages().size():
		if not done.has(stages()[i].id) and _happened(stages()[i], bag):
			last = i
	for i in last + 1:
		var s: Dictionary = stages()[i]
		if not done.has(s.id):
			done[s.id] = true
			out.append(s)
	return out


static func _happened(s: Dictionary, bag: Inventory) -> bool:
	if s.has("map"):
		return visited.has(s.map)
	if s.has("item"):
		return bag != null and bag.has(s.item)
	if s.has("kill"):
		return kills.get(s.kill, 0) > 0
	if s.has("claim"):
		return claimed
	return false


## Hand over the reward (Brannoc, after the Wraith): gold + an item into the bag.
static func claim(bag: Inventory) -> void:
	if claimed:
		return
	claimed = true
	bag.add_gold(reward_gold())
	if reward_item() != "":
		bag.add(reward_item())
	update(bag)
