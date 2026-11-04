@tool
class_name Door
extends MapMarker
## A door standing in a doorway cell of a wall run. Paint the doorway cell with the dark floor
## tile (no wall), then drop a Door on it. Placeholder art (drawn) until real door sprites exist.

## Which wall run the doorway is in: BACK_RIGHT = a wall row along +x (its face points down-left),
## BACK_LEFT = a wall column along +y (its face points down-right).
enum WallRun { BACK_RIGHT, BACK_LEFT }

@export var wall_run := WallRun.BACK_RIGHT:
	set(v):
		wall_run = v
		queue_redraw()
@export var is_open := false:
	set(v):
		is_open = v
		queue_redraw()
@export var locked := false
@export var lock_dc := 15
@export var key_id := ""

const HEIGHT := 30
const WOOD := Color8(104, 62, 30)
const WOOD_DARK := Color8(70, 44, 26)
const IRON := Color8(40, 30, 26)
const OUTLINE := Color8(20, 16, 24)


func _init() -> void:
	gizmo_color = Color(0.85, 0.6, 0.35)
	gizmo_label = "DOOR"


func blocks_move() -> bool:
	return not is_open


func _draw() -> void:
	super()
	if is_open:
		return
	# The door panel stands on the cell's lower-left (BACK_RIGHT) or lower-right (BACK_LEFT) edge.
	var a := Vector2(-15, 0.5) if wall_run == WallRun.BACK_RIGHT else Vector2(1, 7.5)
	var b := Vector2(-1, 7.5) if wall_run == WallRun.BACK_RIGHT else Vector2(15, 0.5)
	var up := Vector2(0, -HEIGHT)
	var panel := PackedVector2Array([a, b, b + up, a + up])
	draw_colored_polygon(panel, WOOD if wall_run == WallRun.BACK_RIGHT else WOOD_DARK)
	for t in [0.25, 0.5, 0.75]:                                  # plank seams
		var p: Vector2 = a.lerp(b, t)
		draw_line(p, p + up, WOOD_DARK if wall_run == WallRun.BACK_RIGHT else OUTLINE, 1.0)
	for h in [0.25, 0.75]:                                       # iron bands
		draw_line(a + up * h, b + up * h, IRON, 2.0)
	var knob := a.lerp(b, 0.8) + up * 0.45
	draw_rect(Rect2(knob.floor(), Vector2(1, 1)), Color8(230, 190, 70))
	panel.append(panel[0])
	draw_polyline(panel, OUTLINE, 1.0)
