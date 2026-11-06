@tool
class_name MapMarker
extends Node2D
## Base for things placed on a map in the editor (party start, spawns, chests, doors, traps...).
## Snaps itself to the centre of an isometric cell while you drag it in the editor, and draws a
## coloured diamond + label there (editor only). Put markers under the map's y-sorted "Entities"
## node, which sits at the map origin like the TileMapLayers.

@export var snap_to_grid := true:
	set(v):
		snap_to_grid = v
		_snap()

var gizmo_color := Color.WHITE
var gizmo_label := ""

var _cell_locked := false
var _locked_cell := Vector2i.ZERO
var _home_position := Vector2.ZERO


func _ready() -> void:
	set_notify_local_transform(true)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_snap()


## Offset of the node from its cell centre (overridden by e.g. Torch, which hangs on a wall face).
func _snap_offset() -> Vector2:
	return Vector2.ZERO


func _snap() -> void:
	if not snap_to_grid or not is_inside_tree():
		return
	var off := _snap_offset()
	var p := IsoGrid.snap(position - off) + off
	if p != position:
		position = p


## The (map) grid cell this marker stands on.
func get_cell() -> Vector2i:
	if _cell_locked:
		return _locked_cell
	return IsoGrid.view_world_to_cell(position - _snap_offset())


## Runtime: remember the map cell as placed in the editor, so it survives view rotation.
func lock_cell() -> void:
	_locked_cell = get_cell()
	_home_position = position
	_cell_locked = true


## Runtime: re-place the marker for the current view rotation (unturned = exactly where it was
## placed in the editor). Subclasses that hang on a wall face or face a direction (Torch, Door)
## extend this.
func apply_view() -> void:
	position = _home_position if IsoGrid.rotation == 0 else IsoGrid.cell_to_world(get_cell()) + _snap_offset()


## Runtime: the marker now stands on another (map) cell (a pushed block). Returns where it goes
## in the current view (tween `position` there, or set it).
func move_to_cell(c: Vector2i) -> Vector2:
	_locked_cell = c
	_cell_locked = true
	_home_position = IsoGrid.view_cell_to_world(c) + _snap_offset()
	return _home_position if IsoGrid.rotation == 0 else IsoGrid.cell_to_world(c) + _snap_offset()


## Runtime state kept by MapState (and save games) for markers that change while the party plays
## (traps, levers, puzzles...): plain data, or null for nothing to keep. Override both.
func save_state() -> Variant:
	return null


func load_state(_s: Variant) -> void:
	pass


func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_gizmo()


func _draw_gizmo() -> void:
	var c := -_snap_offset()
	var d := IsoGrid.diamond(1)
	for i in d.size():
		d[i] += c
	draw_colored_polygon(d, Color(gizmo_color, 0.25))
	d.append(d[0])
	draw_polyline(d, gizmo_color, 1.0)
	if gizmo_label != "":
		draw_string(ThemeDB.fallback_font, c + Vector2(-24, -6), gizmo_label,
				HORIZONTAL_ALIGNMENT_CENTER, 48, 7, gizmo_color)
