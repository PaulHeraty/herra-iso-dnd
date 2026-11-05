@tool
class_name Door
extends MapMarker
## A door standing in a doorway cell of a wall run. Paint the doorway cell with the dark floor
## tile (no wall), then drop a Door on it. Drawn in code (wood + iron bands).
## At runtime: click it to walk up and open it (PartyController / CombatManager). Locked doors
## are picked by the Rogue (thieves' tools, DEX vs lock_dc) or forced by the strongest hero
## (Athletics vs lock_dc + 2); a door with key_id and lock_dc 0 needs that key (Phase 4).

signal opened

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
@export var locked := false:
	set(v):
		locked = v
		queue_redraw()
@export var lock_dc := 15
@export var key_id := ""

## Runtime: the wall run as seen in the rotated view (-1 = same as wall_run).
var view_run := -1

const HEIGHT := 30
const WOOD := Color8(104, 62, 30)
const WOOD_DARK := Color8(70, 44, 26)
const IRON := Color8(40, 30, 26)
const OUTLINE := Color8(20, 16, 24)
const LOCK := Color8(150, 150, 160)


func _init() -> void:
	gizmo_color = Color(0.85, 0.6, 0.35)
	gizmo_label = "DOOR"


func apply_view() -> void:
	super()
	var v := IsoGrid.rotate_dir(axis())
	view_run = WallRun.BACK_RIGHT if v.y == 0 else WallRun.BACK_LEFT
	queue_redraw()


## Map direction the wall run goes along.
func axis() -> Vector2i:
	return Vector2i(1, 0) if wall_run == WallRun.BACK_RIGHT else Vector2i(0, 1)


## The two cells you open the door from (either side of the wall run).
func sides() -> Array[Vector2i]:
	var n := Vector2i(axis().y, axis().x)
	return [get_cell() + n, get_cell() - n]


func blocks_move() -> bool:
	return not is_open


## Swing it open (no checks: the caller handles locks).
func open() -> void:
	if is_open:
		return
	is_open = true
	locked = false
	Sfx.play("door_open")
	opened.emit()


## Screen box of the closed panel around the node (for clicks on the door itself, which stands
## taller than its cell).
func panel_rect() -> Rect2:
	return Rect2(position + Vector2(-16, -HEIGHT - 1), Vector2(32, HEIGHT + 9))


func _run() -> int:
	return wall_run if view_run < 0 else view_run


func _draw() -> void:
	super()
	var run := _run()
	var up := Vector2(0, -HEIGHT)
	var a: Vector2
	var b: Vector2
	if is_open:
		# Swung in against the left jamb of the doorway, seen almost edge-on.
		if run == WallRun.BACK_RIGHT:
			a = Vector2(-15, 0.5)
			b = Vector2(-4, -5)
		else:
			a = Vector2(1, -7.5)
			b = Vector2(12, -2)
		var slab := PackedVector2Array([a, b, b + up, a + up])
		draw_colored_polygon(slab, WOOD_DARK)
		draw_line(a.lerp(b, 0.5), a.lerp(b, 0.5) + up, OUTLINE, 1.0)
		for h in [0.25, 0.75]:
			draw_line(a + up * h, b + up * h, IRON, 1.0)
		slab.append(slab[0])
		draw_polyline(slab, OUTLINE, 1.0)
		return
	# The door panel stands on the cell's lower-left (BACK_RIGHT) or lower-right (BACK_LEFT) edge.
	a = Vector2(-15, 0.5) if run == WallRun.BACK_RIGHT else Vector2(1, 7.5)
	b = Vector2(-1, 7.5) if run == WallRun.BACK_RIGHT else Vector2(15, 0.5)
	var panel := PackedVector2Array([a, b, b + up, a + up])
	draw_colored_polygon(panel, WOOD if run == WallRun.BACK_RIGHT else WOOD_DARK)
	for t in [0.25, 0.5, 0.75]:                                  # plank seams
		var p: Vector2 = a.lerp(b, t)
		draw_line(p, p + up, WOOD_DARK if run == WallRun.BACK_RIGHT else OUTLINE, 1.0)
	for h in [0.25, 0.75]:                                       # iron bands
		draw_line(a + up * h, b + up * h, IRON, 2.0)
	var knob := a.lerp(b, 0.8) + up * 0.45
	draw_rect(Rect2(knob.floor(), Vector2(1, 1)), Color8(230, 190, 70))
	if locked:                                                   # iron lock plate under the knob
		var lp := (a.lerp(b, 0.8) + up * 0.38).floor()
		draw_rect(Rect2(lp + Vector2(-1, 0), Vector2(3, 4)), OUTLINE)
		draw_rect(Rect2(lp + Vector2(0, 1), Vector2(1, 2)), LOCK)
	panel.append(panel[0])
	draw_polyline(panel, OUTLINE, 1.0)
