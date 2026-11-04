@tool
class_name Torch
extends MapMarker
## A wall torch with a flickering flame and warm light. Drop it on a WALL cell and pick which
## face it hangs on; it snaps to the bottom-middle of that face so it y-sorts in front of the wall.

enum Face { LEFT, RIGHT }   ## LEFT = lit lower-left face (back-right walls), RIGHT = lower-right face

@export var face := Face.LEFT:
	set(v):
		face = v
		_snap()
		queue_redraw()
@export var lit := true:
	set(v):
		lit = v
		_apply_lit()
@export var light_energy := 1.25
@export var flicker := 0.18

const FRAMES := 8
const FPS := 8.0

@onready var flame: Sprite2D = $Flame
@onready var light: PointLight2D = $Light

var _t := 0.0
var _seed := 0.0


func _init() -> void:
	gizmo_color = Color(1.0, 0.6, 0.25)


func _ready() -> void:
	super()
	_seed = randf() * 100.0
	_apply_lit()


func _snap_offset() -> Vector2:
	# Bottom-middle of the face edge, relative to the wall cell's centre.
	return Vector2(-8, 4) if face == Face.LEFT else Vector2(8, 4)


func _apply_lit() -> void:
	if not is_node_ready():
		return
	flame.visible = lit
	light.enabled = lit


func _process(delta: float) -> void:
	if not lit:
		return
	_t += delta
	flame.frame = int((_t + _seed) * FPS) % FRAMES
	var f := _t * 2.3 + _seed
	light.energy = light_energy * (1.0 + flicker * sin(f) * 0.6 + flicker * sin(f * 3.7) * 0.4 + randf_range(-0.03, 0.03))
