@tool
class_name Prop
extends MapMarker
## A piece of dungeon furniture standing on a floor cell: barrel, crate, sarcophagus, rubble,
## cocoon, urn. Blocks movement (not sight) unless `blocks` is off. Art from
## tools/godot/gen_dungeon_art.gd. Drop it under Entities; pick the kind in the inspector.

enum Kind { BARREL, CRATE, SARCOPHAGUS, RUBBLE, COCOON, URN }

## texture, feet offset (top-left of the image relative to the cell centre), shadow radius
const KINDS := {
	Kind.BARREL: ["barrel", Vector2(-8, -16), 6.0],
	Kind.CRATE: ["crate", Vector2(-14, -19), 0.0],
	Kind.SARCOPHAGUS: ["sarcophagus", Vector2(-16, -17), 0.0],
	Kind.RUBBLE: ["rubble", Vector2(-16, -12), 0.0],
	Kind.COCOON: ["cocoon", Vector2(-8, -22), 5.0],
	Kind.URN: ["urn", Vector2(-7, -13), 4.0],
}

@export var kind := Kind.BARREL:
	set(v):
		kind = v
		_tex = null
		queue_redraw()
## Turned a quarter: a sarcophagus lying along the map's y axis instead of x (mirrors the sprite).
@export var along_y := false:
	set(v):
		along_y = v
		queue_redraw()
@export var blocks := true

var _tex: Texture2D


func _init() -> void:
	gizmo_color = Color(0.6, 0.55, 0.5)


func apply_view() -> void:
	super()
	queue_redraw()


func _texture() -> Texture2D:
	if _tex == null:
		_tex = load("res://assets/sprites/props/%s.png" % KINDS[kind][0])
	return _tex


func _draw() -> void:
	var k: Array = KINDS[kind]
	if k[2] > 0.0:
		draw_set_transform(Vector2(0, 0), 0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, k[2], Color(0, 0, 0, 0.45))
		draw_set_transform(Vector2.ZERO)
	var flip := along_y != (IsoGrid.rotation % 2 == 1 and not Engine.is_editor_hint())
	var tex := _texture()
	if flip:          # mirrored about the cell centre (x = 0)
		draw_set_transform(Vector2.ZERO, 0, Vector2(-1, 1))
	draw_texture(tex, k[1])
	draw_set_transform(Vector2.ZERO)
	if Engine.is_editor_hint():
		_draw_gizmo()
