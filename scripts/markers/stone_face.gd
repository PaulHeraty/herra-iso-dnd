@tool
class_name StoneFace
extends MapMarker
## A carved stone head on a pedestal that asks a riddle (blocks its cell). Click it: the party walks
## up and it speaks (Mechanisms.talk_to_face, a DialogueBox): the riddle and `answers` to pick from.
## The right one (`correct`, 0-based) opens the doors whose link is `link` and gives `xp`; a wrong
## one makes its eyes flare and `wrong_damage` (lightning) strikes the hero in front. Ask again
## any time. Its eyes glow while it is awake: amber before it is answered, green after.

@export var display_name := "The Stone Face"
@export var link := ""
@export_multiline var riddle := ""
@export var answers: Array[String] = []
@export var correct := 0
@export var wrong_damage := "2d6"
@export var xp := 0

const OFFSET := Vector2(-14, -36)
## The two eye sockets, relative to the cell centre (gen_puzzle_art.gd: left face, v 8.6-11.2).
const EYES := [Vector2(-7, -17), Vector2(-3, -15)]
const COL_AWAKE := Color8(255, 190, 80)
const COL_SOLVED := Color8(130, 240, 140)
const COL_ANGRY := Color8(255, 60, 40)

var solved := false:
	set(v):
		solved = v
		_update_eyes()
var _tex: Texture2D
var _eyes: Node2D
var _flare := 0.0


func _init() -> void:
	gizmo_color = Color(0.8, 0.8, 0.7)
	gizmo_label = "RIDDLE"


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	_eyes = Node2D.new()
	_eyes.name = "Eyes"
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_eyes.material = mat
	_eyes.draw.connect(_draw_eyes)
	add_child(_eyes)
	_update_eyes()


func _process(delta: float) -> void:
	if _flare > 0.0:
		_flare = maxf(0.0, _flare - delta)
		_eyes.queue_redraw()


func _update_eyes() -> void:
	if _eyes:
		_eyes.queue_redraw()


## The eyes flare red (a wrong answer).
func flare() -> void:
	_flare = 1.2
	_update_eyes()


func _draw_eyes() -> void:
	var col := COL_ANGRY if _flare > 0.0 else (COL_SOLVED if solved else COL_AWAKE)
	for e: Vector2 in EYES:
		_eyes.draw_rect(Rect2(e, Vector2(2, 1)), col)
		if _flare > 0.0:
			_eyes.draw_rect(Rect2(e + Vector2(0, -1), Vector2(2, 1)), Color(col, 0.5))


func sides() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DungeonMap.DIRS8:
		out.append(get_cell() + d)
	return out


func sprite_rect() -> Rect2:
	return Rect2(position + Vector2(-10, -34), Vector2(20, 38))


## The head, cropped, for the dialogue portrait.
func portrait() -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = _texture()
	at.region = Rect2(4, 6, 20, 20)
	return at


func hint() -> String:
	if solved:
		return "%s: its eyes glow a calm green." % display_name
	return "%s: click to listen to it." % display_name


func save_state() -> Variant:
	return {s = true} if solved else null


func load_state(s: Variant) -> void:
	if s is Dictionary:
		solved = s.get("s", false)


func _texture() -> Texture2D:
	if _tex == null:
		_tex = load("res://assets/sprites/props/stone_face.png")
	return _tex


func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO)
	draw_texture(_texture(), OFFSET)
	if Engine.is_editor_hint():
		_draw_gizmo()
