class_name RunePortal
## The Rune of Return's portal (one at a time). Using the rune anywhere but the woods opens a
## portal next to the party (DungeonMap.use_rune); its other end stands outside Brannoc's stall
## (the `home` Portal marker on the surface, next to the PartyStart HOME_ENTRY). Stepping through
## from below takes the party to the stall; stepping back through the stall's portal returns the
## party to the cell where the rune was used, and the portal closes. The rune itself is never used
## up. Static; snapshotted with the party by PartyState like Quest.

const HOME_MAP := "res://scenes/maps/surface.tscn"
const HOME_ENTRY := "portal"
## MapState.next_entry for "arrive at RunePortal's cell" (no PartyStart marker for it).
const ARRIVE := "@portal"

static var active := false
## Where the far end is: the map and the (map) cell next to where the rune was used.
static var map_path := ""
static var cell := Vector2i.ZERO


static func reset() -> void:
	active = false
	map_path = ""
	cell = Vector2i.ZERO


static func to_dict() -> Dictionary:
	return {active = active, map_path = map_path, cell = cell}


static func from_dict(d: Dictionary) -> void:
	active = d.get("active", false)
	map_path = d.get("map_path", "")
	cell = d.get("cell", Vector2i.ZERO)


static func open_at(path: String, c: Vector2i) -> void:
	active = true
	map_path = path
	cell = c


static func close() -> void:
	active = false
