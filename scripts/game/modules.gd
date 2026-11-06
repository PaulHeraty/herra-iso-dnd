class_name Modules
## The adventures in the game: every res://modules/<id>/module.gd (an AdventureModule), sorted by
## the level they start at. `current` is the one being played (set by the start screen, a loaded
## save, or - when a map is run on its own from the editor - the module owning that map).

const ROOT := "res://modules/"

static var current: AdventureModule
static var _all: Array[AdventureModule] = []


## Every module, lowest starting level first.
static func all() -> Array[AdventureModule]:
	if _all.is_empty():
		for dir in DirAccess.get_directories_at(ROOT):
			var path := ROOT + dir + "/module.gd"
			if not ResourceLoader.exists(path):
				continue
			var m: AdventureModule = (load(path) as GDScript).new()
			m.id = dir
			_all.append(m)
		_all.sort_custom(func(a: AdventureModule, b: AdventureModule) -> bool:
			return a.level_min < b.level_min if a.level_min != b.level_min else a.id < b.id)
	return _all


static func by_id(module_id: String) -> AdventureModule:
	for m in all():
		if m.id == module_id:
			return m
	return null


## The module a map scene belongs to (null if none).
static func for_scene(scene_path: String) -> AdventureModule:
	for m in all():
		if m.owns(scene_path):
			return m
	return null


## Make sure there is a current module for a map being played (a map run on its own).
static func ensure_for(scene_path: String) -> AdventureModule:
	if current == null or not current.owns(scene_path):
		var m := for_scene(scene_path)
		if m:
			current = m
	return current
