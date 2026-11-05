@tool
class_name Stairs
extends MapMarker
## Stairs to another map (a floor up or down). Click them: the party walks there and the game
## moves to `target_map`, placing the party at that map's PartyStart whose entry_id is
## `target_entry`. Only outside combat. Put a PartyStart next to the stairs on the other map
## (not on them) for the way back.

@export var up := false:
	set(v):
		up = v
		_tex = null
		queue_redraw()
@export_file("*.tscn") var target_map := ""
@export var target_entry := ""

var _tex: Texture2D

## Texture origin relative to the cell centre (gen_dungeon_art.gd).
const UP_OFFSET := Vector2(-17, -36)
const DOWN_OFFSET := Vector2(-17, -9)


func _init() -> void:
	gizmo_color = Color(0.5, 0.85, 1.0)


func _ready() -> void:
	super()
	gizmo_label = "UP" if up else "DOWN"


func apply_view() -> void:
	super()
	queue_redraw()


func _draw() -> void:
	if _tex == null:
		_tex = load("res://assets/sprites/props/%s.png" % ("stairs_up" if up else "stairs_down"))
	draw_texture(_tex, UP_OFFSET if up else DOWN_OFFSET)
	if Engine.is_editor_hint():
		gizmo_label = ("UP " if up else "DOWN ") + target_map.get_file().get_basename()
		_draw_gizmo()


## Hover text, e.g. "Stairs up to The Upper Halls".
var _hint := ""


func hint() -> String:
	if _hint != "":
		return _hint
	var where := ""
	if target_map != "" and ResourceLoader.exists(target_map):
		var st := (load(target_map) as PackedScene).get_state()
		for i in st.get_node_property_count(0):
			if st.get_node_property_name(0, i) == "map_title":
				where = " to " + str(st.get_node_property_value(0, i))
	_hint = "Stairs %s%s (click to take them)" % ["up" if up else "down", where]
	return _hint
