class_name MapState
## What changed on each map while the party was there, so a map looks the same when the party
## comes back up or down the stairs: doors opened, monsters killed, chests opened, cells explored.
## Kept in memory for the session; SaveGame writes it to disk. Keyed by the map's scene path;
## things are identified by their node name under Entities.

## next_entry for "arrive where a save game was made" (arrive_cells / arrive_facings / arrive_rotation).
const AT_SAVE := "@save"

## scene path -> {doors = {name: true}, dead = {spawn name: true}, chests = {name: true},
##                explored = {cell: true} (fog of war)}
static var _maps := {}
## The PartyStart entry_id the map should use ("" = the map's own entry_id). Set by the stairs;
## kept, so a restart (R) after a wipe puts the party back where it arrived.
static var next_entry := ""
## With next_entry == RunePortal.ARRIVE: the (map) cell to arrive at (through the rune's portal).
static var arrive_cell := Vector2i.ZERO
## With next_entry == AT_SAVE: each hero's (map) cell and facing, in party order, and the view rotation.
static var arrive_cells: Array[Vector2i] = []
static var arrive_facings: Array[Vector2i] = []
static var arrive_rotation := 0


## Remember the state of `map` (call when leaving it).
static func save(map: DungeonMap) -> void:
	_maps[map.scene_file_path] = snapshot(map)


## The state of `map` as plain data (what save() keeps), without changing the kept state.
static func snapshot(map: DungeonMap) -> Dictionary:
	var s := {doors = {}, dead = {}, chests = {}, explored = map.fog.explored.duplicate()}
	for n in map.entities.get_children():
		if n is Door and n.is_open:
			s.doors[String(n.name)] = true
		elif n is MonsterSpawn and (n.cleared or (n.monster and not n.monster.is_alive())):
			s.dead[String(n.name)] = true
		elif n is Chest and n.opened:
			s.chests[String(n.name)] = true
	return s


## Put a map back the way the party left it (called at the start of DungeonMap._ready, before
## anything spawns).
static func restore(map: DungeonMap) -> void:
	var s: Dictionary = _maps.get(map.scene_file_path, {})
	if s.is_empty():
		return
	map.fog.explored = s.get("explored", {}).duplicate()
	for n in map.entities.get_children():
		var key := String(n.name)
		if n is Door and s.doors.has(key):
			n.is_open = true
			n.locked = false
		elif n is MonsterSpawn and s.dead.has(key):
			n.cleared = true
		elif n is Chest and s.chests.has(key):
			n.opened = true


## Every map's kept state as plain data (for SaveGame); `map` (the one the party is on) is
## snapshotted as it is now.
static func to_dict(map: DungeonMap = null) -> Dictionary:
	var maps := _maps.duplicate(true)
	if map:
		maps[map.scene_file_path] = snapshot(map)
	return {maps = maps}


static func from_dict(d: Dictionary) -> void:
	_maps = d.get("maps", {}).duplicate(true)


## Forget everything (new game).
static func reset() -> void:
	_maps.clear()
	next_entry = ""
	arrive_cells.clear()
	arrive_facings.clear()
	arrive_rotation = 0
