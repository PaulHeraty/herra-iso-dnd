class_name Actor
extends Node2D
## Anything that stands on the grid and moves around: heroes now, monsters in Phase 2.
## The node's position is the actor's feet (a cell centre). It draws a soft elliptical shadow
## under itself; the "Sprite" child draws the figure on top.

## Shadow ellipse radius (x) in px; it's squashed vertically like the iso floor.
@export var shadow_radius := 7.0
@export var shadow_alpha := 0.7

## The cell the actor stands on, or is walking into.
var cell := Vector2i.ZERO
var _tween: Tween

@onready var sprite: Sprite2D = $Sprite


## Put the actor straight onto a cell (no animation).
func place_at(c: Vector2i) -> void:
	cell = c
	position = IsoGrid.cell_to_world(c)


func is_moving() -> bool:
	return _tween != null and _tween.is_running()


## Walk to a neighbouring cell over `duration` seconds. `cell` changes at once (so pathing and
## occupancy see where the actor is going). Returns the tween; await its `finished`.
func step_to(c: Vector2i, duration: float) -> Tween:
	cell = c
	var target := IsoGrid.cell_to_world(c)
	if not is_equal_approx(target.x, position.x):
		sprite.flip_h = target.x < position.x   # until 4-way sprites exist: mirror to face left
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", target, duration)
	# Little 1px hop per step so walking reads as walking until real walk cycles exist.
	_tween.parallel().tween_property(sprite, "position:y", -1.0, duration * 0.5)
	_tween.parallel().tween_property(sprite, "position:y", 0.0, duration * 0.5).set_delay(duration * 0.5)
	return _tween


func _draw() -> void:
	# Soft shadow: a darker core inside a fainter rim, both squashed 0.45 vertically.
	draw_set_transform(Vector2(0, 1), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, shadow_radius + 1.5, Color(0, 0, 0, shadow_alpha * 0.5))
	draw_circle(Vector2.ZERO, shadow_radius, Color(0, 0, 0, shadow_alpha))
	draw_set_transform(Vector2.ZERO)
