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
##   flag = a story flag set (Quest.set_flag: a puzzle solved, someone met or freed...);
##   claim = the reward taken from the quest giver. Optional `xp`: awarded when the stage is done.
## Side quests (the module's side_quests): the same stages, given by an NPC (give_side), with their
## own reward; their state is in `side`.
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
## Story flags (string -> true): "beacons_lit", "met_hilde", "tamsin_free"...
static var flags := {}
## Side quests: id -> {given, claimed, done = {stage id: true}}.
static var side := {}


static func reset() -> void:
	met = false
	given = false
	claimed = false
	done = {}
	visited = {}
	kills = {}
	flags = {}
	side = {}


static func to_dict() -> Dictionary:
	return {met = met, given = given, claimed = claimed, done = done.duplicate(),
			visited = visited.duplicate(), kills = kills.duplicate(), flags = flags.duplicate(), side = side.duplicate(true)}


static func from_dict(d: Dictionary) -> void:
	reset()
	met = d.get("met", false)
	given = d.get("given", false)
	claimed = d.get("claimed", false)
	done = d.get("done", {}).duplicate()
	visited = d.get("visited", {}).duplicate()
	kills = d.get("kills", {}).duplicate()
	flags = d.get("flags", {}).duplicate()
	side = d.get("side", {}).duplicate(true)


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
	var out: Array[Dictionary] = _update_side(bag)
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
	if s.has("claim_side"):
		return side.get(s.claim_side, {}).get("claimed", false)
	if s.has("map"):
		return visited.has(s.map)
	if s.has("item"):
		return bag != null and bag.has(s.item)
	if s.has("kill"):
		return kills.get(s.kill, 0) > 0
	if s.has("flag"):
		return flags.has(s.flag)
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


# --- story flags, NPCs met ----------------------------------------------------------------------

static func set_flag(f: String) -> void:
	if f != "":
		flags[f] = true


static func has_flag(f: String) -> bool:
	return flags.has(f)


## Has the party spoken to this NPC yet? (Brannoc keeps his old `met`.)
static func has_met(npc_id: String) -> bool:
	return met if npc_id == "brannoc" else flags.has("met_" + npc_id)


# --- side quests (the module's side_quests) ------------------------------------------------------

static func side_quests() -> Array[Dictionary]:
	if Modules.current:
		return Modules.current.side_quests
	var none: Array[Dictionary] = []
	return none


static func side_def(qid: String) -> Dictionary:
	for q in side_quests():
		if q.id == qid:
			return q
	return {}


static func give_side(qid: String) -> void:
	if not side.has(qid):
		side[qid] = {given = true, claimed = false, done = {}}


static func side_given(qid: String) -> bool:
	return side.has(qid)


static func side_claimed(qid: String) -> bool:
	return side.get(qid, {}).get("claimed", false)


## Index of the side quest's current stage, -1 when it is finished (or not given).
static func side_current(qid: String) -> int:
	if not side.has(qid):
		return -1
	var st: Array = side_def(qid).get("stages", [])
	for i in st.size():
		if not side[qid].done.has(st[i].id):
			return i
	return -1


## Everything but the claim is done, and it hasn't been claimed.
static func side_reward_due(qid: String) -> bool:
	var c := side_current(qid)
	return c >= 0 and side_def(qid).stages[c].has("claim") and not side_claimed(qid)


## Hand over a side quest's reward (gold + item) and tick it off.
static func claim_side(qid: String, bag: Inventory) -> void:
	if not side.has(qid) or side_claimed(qid):
		return
	var q := side_def(qid)
	side[qid].claimed = true
	bag.add_gold(int(q.get("reward_gold", 0)))
	if q.get("reward_item", "") != "":
		bag.add(q.reward_item)
	update(bag)


## Tick off side-quest stages that have happened (like the main quest, a later stage done ticks off
## the ones before it). Returns the newly done stages, each with `quest` = the side quest's title.
static func _update_side(bag: Inventory) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for q in side_quests():
		if not side.has(q.id):
			continue
		var st: Array = q.stages
		var last := -1
		for i in st.size():
			var s: Dictionary = st[i]
			var happened: bool = side[q.id].claimed if s.has("claim") else _happened(s, bag)
			if not side[q.id].done.has(s.id) and happened:
				last = i
		for i in last + 1:
			var s: Dictionary = st[i]
			if not side[q.id].done.has(s.id):
				side[q.id].done[s.id] = true
				var o := s.duplicate()
				o.quest = q.title
				out.append(o)
	return out
