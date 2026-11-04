@tool
class_name PartyStart
extends MapMarker
## Where the party begins on this map. The leader stands here; the others form up on free
## neighbouring cells. One per map (more than one = entry points, picked by id on level change).

enum Facing { NORTH_EAST, SOUTH_EAST, SOUTH_WEST, NORTH_WEST }

@export var entry_id := "start"
@export var facing := Facing.SOUTH_WEST


func _init() -> void:
	gizmo_color = Color(1.0, 0.86, 0.35)
	gizmo_label = "PARTY"
