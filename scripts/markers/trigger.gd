@tool
class_name Trigger
extends MapMarker
## An ambush (Phase 6): an invisible area that springs the first time the party walks in.
##   - the MonsterSpawns whose `ambush` is this trigger's `link` were hidden until now: their
##     monsters appear (`how`: step out of the shadows / rise out of the floor / drop from above)
##     and the fight starts (in a fight already, they join it);
##   - `seal` (optional): the doors with that link (portcullises, standing open) slam shut, and
##     stay shut until every ambusher is dead; then they rise again (Mechanisms.after_combat).
## The area is `size` cells with this marker's cell as its top (smallest x, y) corner, like a
## RoomNote. `whole_party`: spring only once every conscious hero is inside (a sealed room shuts
## nobody out). Invisible in game. Mechanisms does the work; MapState keeps fired / done.

enum How { STEP_OUT, RISE, DROP }

@export var link := ""
## Said (log + caption) when it springs.
@export_multiline var text := ""
@export var size := Vector2i(1, 1):
	set(v):
		size = v
		queue_redraw()
@export var whole_party := false
@export var seal := ""
@export var how := How.STEP_OUT

var fired := false
## The ambushers are dead (a seal is lifted).
var done := false


func _init() -> void:
	gizmo_color = Color(1.0, 0.45, 0.2)
	gizmo_label = "AMBUSH"


func area() -> Rect2i:
	return Rect2i(get_cell(), size)


func is_shown() -> bool:
	return false


func save_state() -> Variant:
	return {f = fired, d = done} if fired else null


func load_state(s: Variant) -> void:
	if s is Dictionary:
		fired = s.get("f", false)
		done = s.get("d", false)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var h := IsoGrid.HALF
	var corners := PackedVector2Array([
		Vector2(0, -h.y), Vector2(size.x * h.x, (size.x - 1) * h.y),
		Vector2((size.x - size.y) * h.x, (size.x + size.y - 1) * h.y), Vector2(-size.y * h.x, (size.y - 1) * h.y)])
	corners.append(corners[0])
	draw_polyline(corners, Color(gizmo_color, 0.6), 1.0)
	_draw_gizmo()
