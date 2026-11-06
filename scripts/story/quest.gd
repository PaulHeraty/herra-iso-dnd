class_name Quest
## The campaign quest, "The Wraith Below": Brannoc the trader (the Npc by the mine in the Harrow
## Woods) gives it once the goblins at the mine are dead. Its stages follow the way down through
## the five floors; each one is ticked off when the game sees it happen (a map reached, a key in
## the bag, a monster killed). A later stage done also ticks off every stage before it (a lock
## picked instead of a key found still counts). The last stage is claiming the reward from him.
##
## Static, like PartyState: PartyState.save() snapshots it with the party, and DungeonMap._ready
## loads it back (so a restart after a wipe, R, puts the quest back as the party arrived).

const TITLE := "The Wraith Below"
const GIVER := "Brannoc the trader"
const REWARD_GOLD := 3000
const REWARD_ITEM := "ring_protection"

## id, the text shown in the quest log, and what completes it:
##   map = reached that map; item = that item in the party bag; kill = a monster with that id killed;
##   claim = the reward taken from Brannoc.
const STAGES := [
	{id = "mine", text = "Go down into the old silver mine.", map = "res://scenes/maps/dungeon_1.tscn"},
	{id = "deep", text = "Find the way down from the Upper Halls.", map = "res://scenes/maps/dungeon_2.tscn"},
	{id = "bone_key", text = "Find the Bone Key to the Eye Tyrant's lair.", item = "lair_key"},
	{id = "eye", text = "Slay the Eye Tyrant in the Webbed Deep.", kill = "eye_tyrant"},
	{id = "warrens", text = "Go down to the Goblin Warrens.", map = "res://scenes/maps/dungeon_3.tscn"},
	{id = "chief_key", text = "Take the Chief's Key from the goblin chief.", item = "warren_key"},
	{id = "crypts", text = "Go down into the Sunken Crypts.", map = "res://scenes/maps/dungeon_4.tscn"},
	{id = "vault", text = "Find the way down to the Sealed Vault.", map = "res://scenes/maps/dungeon_5.tscn"},
	{id = "sun_key", text = "Find the Sun Key to the Wraith's vault.", item = "vault_key"},
	{id = "wraith", text = "Destroy the Wraith.", kill = "wraith"},
	{id = "reward", text = "Return to Brannoc for your reward.", claim = true},
]

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
	for i in STAGES.size():
		if not done.has(STAGES[i].id):
			return i
	return -1


static func finished() -> bool:
	return given and current() == -1


## The Wraith is dead and the reward not yet taken.
static func reward_due() -> bool:
	return given and done.has("wraith") and not claimed


## Tick off the stages that have happened. Returns the stages newly done ([{id, text}], in order).
static func update(bag: Inventory) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not given:
		return out
	var last := -1
	for i in STAGES.size():
		if not done.has(STAGES[i].id) and _happened(STAGES[i], bag):
			last = i
	for i in last + 1:
		var s: Dictionary = STAGES[i]
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
	bag.add_gold(REWARD_GOLD)
	bag.add(REWARD_ITEM)
	update(bag)
