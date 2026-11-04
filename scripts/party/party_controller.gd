class_name PartyController
extends Node
## Exploration mode: click a floor cell and the party walks there. The leader follows an A*
## path; each other hero steps into the cell the hero ahead of it just left (a trail).
## Created by DungeonMap at runtime; the CameraController follows the leader.

## Seconds per orthogonal step (a grid diagonal takes sqrt(2) times as long).
const STEP_TIME := 0.18

const COL_CURSOR := Color8(255, 220, 90)
const COL_BLOCKED := Color8(255, 80, 60)
const COL_PATH := Color8(90, 150, 255)

var map: DungeonMap
var overlay: GridOverlay
var camera: CameraController
var party: Array[Hero] = []

## Cells still to walk (leader), destination last.
var _path: Array[Vector2i] = []
var _walking := false
var _hover := Vector2i(-99999, -99999)


func _process(_delta: float) -> void:
	if party.is_empty():
		return
	var c := IsoGrid.world_to_cell(map.get_local_mouse_position())
	if c != _hover:
		_hover = c
		_refresh_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if party.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target := IsoGrid.world_to_cell(map.get_local_mouse_position())
		var p := map.find_path(party[0].cell, target)
		if p.size() > 1:
			p.remove_at(0)
			_path = p
			camera.recenter()
			if not _walking:
				_walk()
		get_viewport().set_input_as_handled()
		_refresh_overlay()


func _walk() -> void:
	_walking = true
	while not _path.is_empty():
		var next: Vector2i = _path.pop_front()
		var leader := party[0]
		var d := next - leader.cell
		var dur := STEP_TIME * (1.4142 if d.x != 0 and d.y != 0 else 1.0)
		var trail: Array[Vector2i] = []
		for h in party:
			trail.append(h.cell)
		var tw := leader.step_to(next, dur)
		for i in range(1, party.size()):
			if party[i].cell != trail[i - 1]:
				party[i].step_to(trail[i - 1], dur)
		_refresh_overlay()
		await tw.finished
	_walking = false
	_refresh_overlay()


func _refresh_overlay() -> void:
	var preview: Array[Vector2i] = []
	if _walking:
		preview = _path
	elif map.is_walkable(_hover) and _hover != party[0].cell:
		preview = map.find_path(party[0].cell, _hover)
		if not preview.is_empty():
			preview.remove_at(0)
	if preview.size() > 1:
		overlay.set_cells("path", preview.slice(0, -1), COL_PATH, 0.12, 0.35, true)
	else:
		overlay.clear("path")
	if _walking and not _path.is_empty():
		overlay.set_cells("destination", [_path[-1]], COL_CURSOR, 0.2, 0.6, true)
	else:
		overlay.clear("destination")
	var reachable := map.is_walkable(_hover) and (_hover == party[0].cell or not preview.is_empty() or _walking)
	if map.floor_layer.get_cell_source_id(_hover) == -1:
		overlay.clear("cursor")
	elif reachable:
		overlay.set_cells("cursor", [_hover], COL_CURSOR, 0.15, 0.7, true)
	else:
		overlay.set_cells("cursor", [_hover], COL_BLOCKED, 0.08, 0.5)
