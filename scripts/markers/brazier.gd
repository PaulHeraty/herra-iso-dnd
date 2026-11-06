@tool
class_name Brazier
extends Torch
## A free-standing iron fire bowl on a floor cell: the torch flame + warm light, for lighting the
## middle of big rooms. Blocks movement like a prop. Same flicker as Torch (face is ignored).

const BOWL := preload("res://assets/sprites/props/brazier.png")
const BOWL_OFFSET := Vector2(-10, -14)
const CAMPFIRE := preload("res://assets/sprites/props/campfire.png")
const CAMPFIRE_OFFSET := Vector2(-10, -7)

## A campfire on the ground (outdoors) instead of the iron bowl: the flame sits low, in a stone ring.
@export var campfire := false:
	set(v):
		campfire = v
		queue_redraw()
## Phase 6: a brazier the party can light and douse (click it), part of the Puzzle with this link.
@export var link := ""
## Its place in a RING puzzle (neighbours = order - 1 and order + 1, round the ring).
@export var order := 0


func _init() -> void:
	super()
	gizmo_color = Color(1.0, 0.5, 0.2)


func _ready() -> void:
	super()
	if _glow:
		_glow.position = Vector2(0, -6 if campfire else -15)
	if campfire:
		flame.position.y += 10
		var l := get_node_or_null("Light")
		if l:
			l.position.y += 9


func _snap_offset() -> Vector2:
	return Vector2.ZERO


func apply_view() -> void:
	position = _home_position if IsoGrid.rotation == 0 else IsoGrid.cell_to_world(get_cell())
	_front_facing = true
	_apply_lit()


func _apply_editor_look() -> void:
	pass


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.45 if not campfire else 0.3))
	draw_set_transform(Vector2.ZERO)
	if campfire:
		draw_texture(CAMPFIRE, CAMPFIRE_OFFSET)
	else:
		draw_texture(BOWL, BOWL_OFFSET)
	if Engine.is_editor_hint():
		_draw_gizmo()


func sides() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DungeonMap.DIRS8:
		out.append(get_cell() + d)
	return out


func sprite_rect() -> Rect2:
	return Rect2(position + Vector2(-10, -22), Vector2(20, 26))


func hint() -> String:
	return "A brazier (%s): click to %s it." % ["lit" if lit else "cold", "douse" if lit else "light"]


func save_state() -> Variant:
	return {l = lit} if link != "" else null


func load_state(s: Variant) -> void:
	if s is Dictionary:
		lit = s.get("l", lit)
