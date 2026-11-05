@tool
class_name MonsterSpawn
extends MapMarker
## A monster that appears here. monster_id refers to a monster definition in data/ (Phase 2).
## Monsters sharing a group_id join combat together.

@export var monster_id := "eye_tyrant":
	set(v):
		monster_id = v
		queue_redraw()
@export var group_id := 0
## Which way it faces until it notices the party (screen direction in the unturned view).
@export var facing := PartyStart.Facing.SOUTH_WEST
## Editor-only picture so you can see what's placed. Drawn with its feet on the cell centre.
@export var preview: Texture2D:
	set(v):
		preview = v
		queue_redraw()
@export var preview_offset := Vector2(-16, -33)

## Runtime: the Monster actor spawned here (null if its scene is missing).
var monster: Node2D
## Runtime: killed on an earlier visit (MapState), so nothing spawns.
var cleared := false


func _init() -> void:
	gizmo_color = Color(1.0, 0.35, 0.3)


func _draw_gizmo() -> void:
	gizmo_label = monster_id.to_upper()
	super()
	if preview:
		draw_texture(preview, preview_offset, Color(1, 1, 1, 0.8))
