@tool
class_name PressurePlate
extends MapMarker
## A stone plate in the floor, pressed while someone (hero, monster) or a pushable block stands on
## it (Mechanisms.update_plates). Without a Puzzle on its `link` it holds the matching doors open
## while pressed (a portcullis drops again when it is let go). With an ALL_ON Puzzle, every plate
## of the link must be pressed at once (push blocks onto them). Walkable; drawn flat on the floor.

@export var link := ""

const OFFSET := Vector2(-17, -11)
const SORT_UP := Vector2(0, -9)
const GLOW := Color8(120, 200, 255)

var pressed := false:
	set(v):
		if v == pressed:
			return
		pressed = v
		_update_glow()
		queue_redraw()

var _tex_up: Texture2D
var _tex_down: Texture2D
var _glow: Node2D


func _init() -> void:
	gizmo_color = Color(0.5, 0.8, 1.0)
	gizmo_label = "PLATE"


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	# The rune glows when pressed: unshaded, so it shows in the dark.
	_glow = Node2D.new()
	_glow.name = "Glow"
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.position = -SORT_UP
	_glow.draw.connect(func():
		var c := Color(GLOW, 0.7)
		_glow.draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.5))
		_glow.draw_arc(Vector2.ZERO, 5.0, 0, TAU, 20, c, 1.0)
		_glow.draw_circle(Vector2.ZERO, 1.2, c)
		_glow.draw_set_transform(Vector2.ZERO))
	add_child(_glow)
	_update_glow()


func _snap_offset() -> Vector2:
	return SORT_UP


func _update_glow() -> void:
	if _glow:
		_glow.visible = pressed
		_glow.queue_redraw()


func hint() -> String:
	return "A pressure plate (%s)." % ("pressed" if pressed else "up")


func _draw() -> void:
	if _tex_up == null:
		_tex_up = load("res://assets/sprites/props/plate.png")
		_tex_down = load("res://assets/sprites/props/plate_down.png")
	draw_texture(_tex_down if pressed else _tex_up, -SORT_UP + OFFSET)
	if Engine.is_editor_hint():
		_draw_gizmo()
