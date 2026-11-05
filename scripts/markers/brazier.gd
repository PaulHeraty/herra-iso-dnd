@tool
class_name Brazier
extends Torch
## A free-standing iron fire bowl on a floor cell: the torch flame + warm light, for lighting the
## middle of big rooms. Blocks movement like a prop. Same flicker as Torch (face is ignored).

const BOWL := preload("res://assets/sprites/props/brazier.png")
const BOWL_OFFSET := Vector2(-10, -14)


func _init() -> void:
	super()
	gizmo_color = Color(1.0, 0.5, 0.2)


func _ready() -> void:
	super()
	if _glow:
		_glow.position = Vector2(0, -15)


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
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	draw_texture(BOWL, BOWL_OFFSET)
	if Engine.is_editor_hint():
		_draw_gizmo()
