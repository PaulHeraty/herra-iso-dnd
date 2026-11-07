@tool
class_name Chest
extends MapMarker
## A treasure chest. At runtime: click it and the party walks up and opens it (PartyController ->
## DungeonMap.try_open_chest); gold and items go into the party bag. Locked chests are opened like
## locked doors: a key from the bag, else the Rogue picks (DEX vs lock_dc), else the strongest hero
## forces it (Athletics vs lock_dc + 2). key_id with lock_dc 0 = only the key opens it.
## Exploration only (not during a fight). Opened chests stay open (MapState).

const CLOSED_TEX := preload("res://assets/sprites/props/chest.png")
const OPEN_TEX := preload("res://assets/sprites/props/chest_open.png")
const CLOSED_OFFSET := Vector2(-8, -10)
const OPEN_OFFSET := Vector2(-8, -13)       # 3px taller (the lid stands up), same bottom edge

@export var locked := false
@export var lock_dc := 15            ## DEX (thieves' tools) to pick
@export var key_id := ""             ## key item that opens it ("" = none)
@export var gold := 0
@export var items: Array[String] = []   ## item ids (data/items/), e.g. "potion_healing"
## A mimic (module 2): opening it wakes a Mimic monster in its place (DungeonMap.try_open_chest).
## Passive Perception (DC 15) can notice it first.
@export var mimic := false

## The party has noticed it is a mimic.
var mimic_spotted := false

var opened := false:
	set(v):
		opened = v
		_update_sprite()


func _init() -> void:
	gizmo_color = Color(1.0, 0.8, 0.3)


func _ready() -> void:
	super()
	_update_sprite()


func _update_sprite() -> void:
	var s := get_node_or_null("Sprite") as Sprite2D
	if s == null:
		return
	s.texture = OPEN_TEX if opened else CLOSED_TEX
	s.offset = OPEN_OFFSET if opened else CLOSED_OFFSET


## The cells you open it from: the 8 around it.
func sides() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		out.append(get_cell() + d)
	return out


## Screen box of the sprite (clicks on the chest itself, not only its cell).
func sprite_rect() -> Rect2:
	return Rect2(position + Vector2(-9, -12), Vector2(18, 16))


## Lift the lid (no checks: DungeonMap.try_open_chest handles locks and loot).
func open() -> void:
	if opened:
		return
	opened = true
	locked = false
	Sfx.play("chest_open")
	var s := get_node_or_null("Sprite") as Sprite2D
	if s:                                    # a little bounce as the lid flies up
		var tw := create_tween()
		tw.tween_property(s, "position:y", -1.0, 0.06)
		tw.tween_property(s, "position:y", 0.0, 0.1)


func _draw() -> void:
	super()
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.45))   # soft floor shadow
	draw_circle(Vector2.ZERO, 9, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)


## A woken mimic's chest is gone (the monster stands there instead).
func is_shown() -> bool:
	return not (mimic and opened)


func save_state() -> Variant:
	return {m = true} if mimic_spotted else null


func load_state(s: Variant) -> void:
	if s is Dictionary:
		mimic_spotted = s.get("m", false)
