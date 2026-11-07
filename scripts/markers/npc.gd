@tool
class_name Npc
extends MapMarker
## A non-player character standing on a cell (Brannoc the trader by the mine). Never in a fight;
## blocks his cell while he is there. He keeps out of sight while any living monster is within
## `guard_radius` cells (he hid from the goblins at the mine) and steps out once they are dead
## (DungeonMap._tick_npcs), then calls the party over the first time they see him (TraderTalk).
## Click him: the party walks up and talks to him.
## Art: `sheet`, 16x24 cells: idle A, idle B (breath), talk (hand raised); faces the viewer's
## left like the heroes' front row, mirrored to face right.

@export var npc_id := "brannoc"
@export var display_name := "Brannoc"
@export var sheet: Texture2D = preload("res://assets/sprites/npcs/trader_sheet.png")
## Hidden while a living monster is this close (cells, 5e grid distance). 0 = always there.
@export var guard_radius := 14
## Only hides from this monster (id; "" = from any monster within guard_radius). Hilde: the dragon.
@export var guard_monster := ""
@export var face_right := false:
	set(v):
		face_right = v
		queue_redraw()
## Story flags (Quest): only there once `show_flag` is set, gone once `hide_flag` is set (an
## apprentice who leaves her cell when freed and turns up at the camp). "" = no condition.
@export var show_flag := ""
@export var hide_flag := ""
## Calls the party over the first time they see each other (Brannoc, Hilde).
@export var calls_party := true

const SPRITE_OFFSET := Vector2(-8, -22)
const SIZE := Vector2(16, 24)

## Out in the open (talks, trades, blocks his cell). Set by DungeonMap.
var present := true
var _t := 0.0
var _frame := 0
var _talk_t := 0.0


func _init() -> void:
	gizmo_color = Color(0.55, 1.0, 0.6)


func _ready() -> void:
	super()
	gizmo_label = display_name
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	_t += delta
	_talk_t = maxf(0.0, _talk_t - delta)
	var f := 2 if _talk_t > 0.0 else (1 if fmod(_t, 2.2) > 1.7 else 0)
	if f != _frame:
		_frame = f
		queue_redraw()


func is_shown() -> bool:
	return present


## Does the story want this NPC here now? (show_flag / hide_flag)
func story_wants() -> bool:
	return (show_flag == "" or Quest.has_flag(show_flag)) and (hide_flag == "" or not Quest.has_flag(hide_flag))


## Gone (a story flag): fade out.
func vanish() -> void:
	present = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): visible = false)


## The cells to talk to him from: the 8 around him.
func sides() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DungeonMap.DIRS8:
		out.append(get_cell() + d)
	return out


func sprite_rect() -> Rect2:
	return Rect2(position + SPRITE_OFFSET, SIZE)


## Step out of hiding: fade in.
func appear() -> void:
	present = true
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


## Turn toward a world point and raise a hand for a moment.
func greet(toward: Vector2) -> void:
	face_right = toward.x > position.x
	_talk_t = 1.4
	_frame = 2
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0, Vector2(1, 0.45))      # soft floor shadow
	draw_circle(Vector2.ZERO, 6, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0, Vector2(-1, 1) if face_right else Vector2.ONE)
	if sheet:
		draw_texture_rect_region(sheet, Rect2(SPRITE_OFFSET, SIZE), Rect2(_frame * SIZE.x, 0, SIZE.x, SIZE.y))
	draw_set_transform(Vector2.ZERO)
	if Engine.is_editor_hint():
		_draw_gizmo()
