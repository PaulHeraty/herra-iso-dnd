class_name MapState
## What changed on each map while the party was there, so a map looks the same when the party
## comes back up or down the stairs: doors opened, monsters killed, chests opened, cells explored.
## Kept in memory for the session (save/load comes in Phase 8). Keyed by the map's scene path;
## things are identified by their node name under Entities.

## scene path -> {doors = {name: true}, dead = {spawn name: true}, chests = {name: true},
##                explored = {cell: true} (fog of war)}
static var _maps := {}
## The PartyStart entry_id the map should use ("" = the map's own entry_id). Set by the stairs;
## kept, so a restart (R) after a wipe puts the party back where it arrived.
static var next_entry := ""


## Remember the state of `map` (call when leaving it).
static func save(map: DungeonMap) -> void:
	var s := {doors = {}, dead = {}, chests = {}, explored = map.fog.explored.duplicate()}
	for n in map.entities.get_children():
		if n is Door and n.is_open:
			s.doors[String(n.name)] = true
		elif n is MonsterSpawn and (n.cleared or (n.monster and not n.monster.is_alive())):
			s.dead[String(n.name)] = true
		elif n is Chest and n.opened:
			s.chests[String(n.name)] = true
	_maps[map.scene_file_path] = s


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


## Forget everything (new game).
static func reset() -> void:
	_maps.clear()
	next_entry = ""
