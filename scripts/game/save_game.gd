class_name SaveGame
## Save games: SLOTS slots, one file each (user://saves/slot<N>.sav, Godot's binary var format,
## no objects). A file holds a small header (shown in the slot list) and the game itself:
## PartyState + every map's MapState (the current one as it is now), where each hero stands and
## faces, and the view rotation. Saving is outside combat only (the state model has no fights in
## it); loading works any time. Loading goes through the same path as the stairs: the static state
## is set, then the saved map scene is loaded with MapState.next_entry = MapState.AT_SAVE.
## SaveScreen (F5 / F9) is the UI.

const SLOTS := 3
## Where the slot files go (tests point this elsewhere so real saves are never touched).
static var dir := "user://saves"
const VERSION := 1
## The name a save gets when the player leaves it blank: save001, save002...
const DEFAULT_FMT := "save%03d"
const NAME_MAX := 24


static func slot_path(slot: int) -> String:
	return "%s/slot%d.sav" % [dir, slot]


## The header of a slot ({name, number, time, map_path, map_title, level, gold}), or {} if the
## slot is empty or unreadable.
static func info(slot: int) -> Dictionary:
	var d := _read(slot)
	return d.get("header", {}) if not d.is_empty() else {}


## The name a new save gets if the player doesn't type one (one more than the highest number
## used in any slot).
static func default_name() -> String:
	return DEFAULT_FMT % (_highest_number() + 1)


static func _highest_number() -> int:
	var best := 0
	for i in range(1, SLOTS + 1):
		best = maxi(best, int(info(i).get("number", 0)))
	return best


## Why the game can't be saved right now ("" = it can).
static func blocked_reason(map: DungeonMap) -> String:
	if map == null or map.party.is_empty():
		return "Nothing to save."
	if map.combat.game_over:
		return "The party has fallen. Press F9 to load a game, or R to try again."
	if map.combat.in_combat:
		return "You can't save in the middle of a fight."
	if map.is_leaving():
		return "Wait until you get there."
	if map.hud and map.hud.dialogue and map.hud.dialogue.visible:
		return "Finish the conversation first."
	return ""


## Write the game on `map` to `slot`. A blank name gets the default one. Returns "" or an error.
static func save(map: DungeonMap, slot: int, save_name: String) -> String:
	var why := blocked_reason(map)
	if why != "":
		return why
	var n := _highest_number() + 1
	save_name = save_name.strip_edges().left(NAME_MAX)
	if save_name == "":
		save_name = DEFAULT_FMT % n
	var lead_level := 1
	for h in map.party:
		lead_level = maxi(lead_level, h.level)
	var cells: Array[Vector2i] = []
	var facings: Array[Vector2i] = []
	for h in map.party:
		cells.append(h.cell)
		facings.append(h.facing)
	var d := {
		version = VERSION,
		header = {
			name = save_name, number = n, time = int(Time.get_unix_time_from_system()),
			map_path = map.scene_file_path, map_title = map.map_title, level = lead_level,
			gold = map.inventory.gold,
		},
		game = {
			map_path = map.scene_file_path,
			party = PartyState.snapshot(map),
			maps = MapState.to_dict(map),
			cells = cells, facings = facings, rotation = IsoGrid.rotation,
		},
	}
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return "Couldn't write the save (%s)." % error_string(FileAccess.get_open_error())
	f.store_var(d)
	f.close()
	return ""


## Set up everything to continue the game in `slot`. Returns the map scene to load, or "" if the
## slot can't be loaded (`err` gets why). The caller changes the scene.
static func prepare_load(slot: int, err: Array = []) -> String:
	var d := _read(slot)
	if d.is_empty():
		err.append("That slot is empty.")
		return ""
	if int(d.get("version", 0)) > VERSION:
		err.append("That save is from a newer version of the game.")
		return ""
	var g: Dictionary = d.get("game", {})
	var path: String = g.get("map_path", "")
	if path == "" or not ResourceLoader.exists(path):
		err.append("That save's map (%s) is missing." % path)
		return ""
	PartyState.from_dict(g.get("party", {}))
	MapState.reset()
	MapState.from_dict(g.get("maps", {}))
	MapState.next_entry = MapState.AT_SAVE
	MapState.arrive_cells.assign(g.get("cells", []))
	MapState.arrive_facings.assign(g.get("facings", []))
	MapState.arrive_rotation = int(g.get("rotation", 0))
	return path


static func _read(slot: int) -> Dictionary:
	var p := slot_path(slot)
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var(false)
	f.close()
	return v if v is Dictionary and v.has("header") and v.has("game") else {}


## "2026-11-06 14:32" for a header's time (local time).
static func time_text(unix: int) -> String:
	if unix <= 0:
		return ""
	var local := unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var t := Time.get_datetime_dict_from_unix_time(local)
	return "%04d-%02d-%02d %02d:%02d" % [t.year, t.month, t.day, t.hour, t.minute]
