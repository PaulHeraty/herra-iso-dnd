@tool
class_name RoomNote
extends MapMarker
## Text the party gets the first time a hero walks into an area: a room description (a caption at
## the top of the screen + the log) or, with `modal`, something to read properly (an inscription,
## a clue) in the dialogue box. The area is `size` cells with this marker's cell as its top
## (smallest x, y) corner. `link` (optional) is fired when it is first entered (Mechanisms.fire),
## e.g. to open a secret way. Invisible in game; outside combat only (in a fight it waits).

@export var title := ""
@export_multiline var text := ""
@export var size := Vector2i(1, 1):
	set(v):
		size = v
		queue_redraw()
@export var modal := false
@export var link := ""

var seen := false


func _init() -> void:
	gizmo_color = Color(0.6, 0.9, 1.0)
	gizmo_label = "NOTE"


func area() -> Rect2i:
	return Rect2i(get_cell(), size)


func is_shown() -> bool:
	return false


func save_state() -> Variant:
	return {s = true} if seen else null


func load_state(s: Variant) -> void:
	if s is Dictionary:
		seen = s.get("s", false)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# the area's outline (cells from this one, +x down-right, +y down-left)
	var h := IsoGrid.HALF
	var corners := PackedVector2Array([
		Vector2(0, -h.y), Vector2(size.x * h.x, (size.x - 1) * h.y),
		Vector2((size.x - size.y) * h.x, (size.x + size.y - 1) * h.y), Vector2(-size.y * h.x, (size.y - 1) * h.y)])
	corners.append(corners[0])
	draw_polyline(corners, Color(gizmo_color, 0.6), 1.0)
	_draw_gizmo()
