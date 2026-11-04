@tool
class_name Torch
extends MapMarker
## A wall torch with a flickering flame and warm light. Drop it on a WALL cell and pick which
## face it hangs on; it snaps to the middle of that face's floor edge.
##   LEFT / RIGHT           = the lower-left / lower-right faces you see (back walls of a room).
##   BACK_LEFT / BACK_RIGHT = the upper-left / upper-right faces, hidden in the normal view (e.g. the
##     room side of a front wall). They light the room as usual; their flame shows when the view
##     is turned so that face points at you. In the editor they draw on top, faded, labelled BACK.

enum Face { LEFT, RIGHT, BACK_LEFT, BACK_RIGHT }

## Map direction each face looks along (indexed by Face).
const FACE_NORMAL := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]
## Node offset from the wall cell's centre (middle of the face's bottom edge), by view direction.
const EDGE_OFFSET := {Vector2i(0, 1): Vector2(-8, 4), Vector2i(1, 0): Vector2(8, 4),
		Vector2i(0, -1): Vector2(8, -4), Vector2i(-1, 0): Vector2(-8, -4)}

@export var face := Face.LEFT:
	set(v):
		face = v
		_snap()
		_apply_editor_look()
		queue_redraw()
@export var lit := true:
	set(v):
		lit = v
		_apply_lit()
@export var light_energy := 1.25
@export var flicker := 0.18

const FRAMES := 8
const FPS := 8.0
## Soft additive halo around the flame (the mock-ups' glow).
const GLOW_COLOR := Color(1.0, 0.55, 0.22, 0.45)
## Warm tint on the (unshaded) flame, like the mock-ups where fire picks up its own light colour.
const FLAME_TINT := Color(1.0, 0.84, 0.62)
const GLOW_SIZE := 18
const GLOW_POS := Vector2(0, -25)      ## flame centre, relative to the torch node

@onready var flame: Sprite2D = $Flame
@onready var light: PointLight2D = $Light

var _t := 0.0
var _front_facing := true
var _seed := 0.0
var _jitter := 0.0
var _glow: Sprite2D


func _init() -> void:
	gizmo_color = Color(1.0, 0.6, 0.25)


func _ready() -> void:
	super()
	_seed = randf() * 100.0
	if Engine.is_editor_hint():   # runtime-only look; don't let the editor save it into maps
		_apply_lit()
		_apply_editor_look()
		return
	# Fire glows by itself: the flame ignores ambient + light, so its palette shows as drawn.
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	flame.material = unshaded
	flame.modulate = FLAME_TINT
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.texture = _glow_texture()
	_glow.position = GLOW_POS
	var add := CanvasItemMaterial.new()
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.modulate = GLOW_COLOR
	add_child(_glow)
	_apply_lit()


static var _glow_tex: Texture2D

static func _glow_texture() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = GLOW_SIZE
		t.height = GLOW_SIZE
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_glow_tex = t
	return _glow_tex


func _snap_offset() -> Vector2:
	# Middle of the face's bottom edge, relative to the wall cell's centre (editor = unturned view).
	return EDGE_OFFSET[face_normal()]


## Direction the torch's face points, in map cells (LEFT +y, RIGHT +x, BACK_LEFT -x, BACK_RIGHT -y).
func face_normal() -> Vector2i:
	return FACE_NORMAL[face]


## Editor only: back-face torches sit behind their wall, so draw them on top, faded and labelled.
func _apply_editor_look() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	var back := face == Face.BACK_LEFT or face == Face.BACK_RIGHT
	z_index = 1 if back else 0
	flame.modulate.a = 0.5 if back else 1.0
	gizmo_label = "BACK" if back else ""
	queue_redraw()


## Hang on the same face of the block in the rotated view. If that face now points away from the
## viewer, it sits on the hidden back of the block: the flame is hidden but the light stays.
func apply_view() -> void:
	var n := IsoGrid.rotate_dir(face_normal())
	position = _home_position if IsoGrid.rotation == 0 else IsoGrid.cell_to_world(get_cell()) + EDGE_OFFSET[n]
	_front_facing = n == Vector2i(0, 1) or n == Vector2i(1, 0)
	_apply_lit()


func _apply_lit() -> void:
	if not is_node_ready():
		return
	flame.visible = lit and _front_facing
	if _glow:
		_glow.visible = flame.visible
	light.enabled = lit


func _process(delta: float) -> void:
	if not lit:
		return
	_t += delta
	flame.frame = int((_t + _seed) * FPS) % FRAMES
	var f := _t * 2.3 + _seed
	# Smoothed random jitter on top of two slow waves (a fresh random value every frame buzzes).
	_jitter = lerpf(_jitter, randf_range(-1.0, 1.0), 1.0 - exp(-12.0 * delta))
	var k := 1.0 + flicker * (sin(f) * 0.6 + sin(f * 3.7) * 0.4) + 0.05 * _jitter
	light.energy = light_energy * k
	if _glow:
		_glow.modulate.a = GLOW_COLOR.a * clampf(k, 0.0, 1.5)
