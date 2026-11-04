class_name Actor
extends Node2D
## Anything that stands on the grid and moves around: heroes now, monsters in Phase 2.
## The node's position is the actor's feet (a cell centre). It draws a soft elliptical shadow
## under itself; the "Sprite" child draws the figure on top.

## Shadow ellipse radius (x) in px; it's squashed vertically like the iso floor.
@export var shadow_radius := 7.0
@export var shadow_alpha := 0.7

var cell := Vector2i.ZERO

@onready var sprite: Sprite2D = $Sprite


## Put the actor straight onto a cell (no animation).
func place_at(c: Vector2i) -> void:
	cell = c
	position = IsoGrid.cell_to_world(c)


func _draw() -> void:
	# Soft shadow: a darker core inside a fainter rim, both squashed 0.45 vertically.
	draw_set_transform(Vector2(0, 1), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, shadow_radius + 1.5, Color(0, 0, 0, shadow_alpha * 0.5))
	draw_circle(Vector2.ZERO, shadow_radius, Color(0, 0, 0, shadow_alpha))
	draw_set_transform(Vector2.ZERO)
