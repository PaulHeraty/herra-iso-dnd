@tool
class_name Chest
extends MapMarker
## A treasure chest. Contents are opened/looted in Phase 4.

@export var locked := false
@export var lock_dc := 15            ## DEX (thieves' tools) to pick
@export var key_id := ""             ## key item that opens it ("" = none)
@export var gold := 0
@export var items: Array[String] = []   ## item ids from data/ (Phase 4)

var opened := false


func _init() -> void:
	gizmo_color = Color(1.0, 0.8, 0.3)


func _draw() -> void:
	super()
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.45))   # soft floor shadow
	draw_circle(Vector2.ZERO, 9, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
