class_name Roster
## Parties that have finished an adventure, kept for the next one (user://parties/<id>.party,
## Godot's binary var format, no objects). An entry: {id, name, level, time, modules_done,
## party (a PartyState dict: each hero's level, XP and equipment; the bag; party XP)}.
## Finishing a module (the victory screen) writes the party here; the start screen offers these
## parties for a new adventure. HP, slots and uses aren't kept: a new adventure starts rested.

static var dir := "user://parties"
const VERSION := 1


## Every saved party, highest level first.
static func parties() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".party"):
			continue
		var file := FileAccess.open(dir + "/" + f, FileAccess.READ)
		if file == null:
			continue
		var v: Variant = file.get_var(false)
		file.close()
		if v is Dictionary and v.has("party") and v.has("id"):
			out.append(v)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.level > b.level if a.level != b.level else a.time > b.time)
	return out


static func by_id(party_id: String) -> Dictionary:
	for p in parties():
		if p.id == party_id:
			return p
	return {}


## The party on `map` has finished `module`: keep it (under its roster id, or a new one). Its
## module items, keys and the quest are left behind; HP and resources aren't kept. Returns the entry.
static func keep(map: DungeonMap, module: AdventureModule) -> Dictionary:
	var snap := PartyState.snapshot(map)
	var heroes := {}
	var level := 1
	for cls in snap.heroes:
		var h: Dictionary = snap.heroes[cls]
		heroes[cls] = {level = h.level, xp = h.xp, equipment = h.equipment.duplicate()}
		level = maxi(level, h.level)
	var bag: Dictionary = snap.bag.duplicate(true)
	bag["stacks"] = _portable(bag.get("stacks", []), module)
	var done: Array = PartyState.roster.get("modules_done", []).duplicate()
	if module and not module.id in done:
		done.append(module.id)
	var party_id: String = PartyState.roster.get("id", "")
	if party_id == "":
		party_id = "party_%d" % int(Time.get_unix_time_from_system())
	var entry := {
		version = VERSION, id = party_id,
		name = PartyState.roster.get("name", "") if PartyState.roster.get("name", "") != "" else "Heroes of %s" % (module.title if module else "the realm"),
		level = level, time = int(Time.get_unix_time_from_system()), modules_done = done,
		party = {heroes = heroes, party_xp = snap.party_xp, bag = bag},
	}
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open("%s/%s.party" % [dir, party_id], FileAccess.WRITE)
	if f:
		f.store_var(entry)
		f.close()
	PartyState.roster = {id = party_id, name = entry.name, modules_done = done}
	return entry


## The bag's items without the ones that belong to the module's story (its module_items, keys).
static func _portable(items: Variant, module: AdventureModule) -> Variant:
	if items is Dictionary:
		var out := {}
		for iid in items:
			if _stays(String(iid), module):
				continue
			out[iid] = items[iid]
		return out
	if items is Array:
		return items.filter(func(e): return not _stays(String(e.get("id", e) if e is Dictionary else e), module))
	return items


static func _stays(iid: String, module: AdventureModule) -> bool:
	if module and iid in module.module_items:
		return true
	var it := ItemData.get_item(iid)
	return it != null and it.key_id != ""


## Set up PartyState for a new adventure with this roster party (rested, no quest, no portal).
static func load_party(entry: Dictionary) -> void:
	var p: Dictionary = entry.get("party", {})
	PartyState.reset()
	PartyState.from_dict({heroes = p.get("heroes", {}).duplicate(true), party_xp = p.get("party_xp", 0),
			bag = p.get("bag", {}).duplicate(true), story = {}, play_seconds = 0.0})
	PartyState.roster = {id = entry.get("id", ""), name = entry.get("name", ""),
			modules_done = entry.get("modules_done", []).duplicate()}
