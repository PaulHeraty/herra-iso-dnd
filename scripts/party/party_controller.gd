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
const COL_LOCKED := Color8(255, 150, 60)
const COL_STAIRS := Color8(120, 220, 255)

var map: DungeonMap
var overlay: GridOverlay
var camera: CameraController
var party: Array[Hero] = []

## Cells still to walk (leader), destination last.
var _path: Array[Vector2i] = []
## Door to open when the leader gets there (clicked a closed door).
var _door_goal: Door
var _walking := false
var _hover := Vector2i(-99999, -99999)
## False while combat runs (CombatManager takes over input).
var enabled := true:
	set(v):
		enabled = v
		if not v:
			stop()
			for layer in ["path", "destination", "cursor"]:
				overlay.clear(layer)


## Stop walking after the step in progress.
func stop() -> void:
	_path.clear()


func is_walking() -> bool:
	return _walking


func _process(_delta: float) -> void:
	if party.is_empty() or not enabled:
		return
	var c := IsoGrid.world_to_cell(map.get_local_mouse_position())
	if map.hud and map.hud.mouse_over_ui():
		c = Vector2i(-99999, -99999)
	if c != _hover:
		_hover = c
		_refresh_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if party.is_empty() or not enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if map.hud and map.hud.mouse_over_ui():
			return
		var mouse := map.get_local_mouse_position()
		var door := map.closed_door_under(mouse)
		var target := IsoGrid.world_to_cell(mouse)
		_door_goal = null
		if door:
			var dp := door_path(door)
			if dp.is_empty():
				get_viewport().set_input_as_handled()
				return
			_door_goal = door
			target = dp[-1]
			if target == party[0].cell:
				get_viewport().set_input_as_handled()
				_arrived()
				return
		else:
			var st := map.stairs_under(mouse)
			if st:
				target = st.get_cell()
				if target == party[0].cell:
					get_viewport().set_input_as_handled()
					map.take_stairs(st)
					return
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
		map.apply_pending_rotation()
	_walking = false
	_refresh_overlay()
	_arrived()



## The leader has stopped: open the door it walked to, or take the stairs it stands on.
func _arrived() -> void:
	if not enabled:            # combat started on the way
		_door_goal = null
		return
	var door := _door_goal
	_door_goal = null
	if door and not door.is_open and party[0].cell in door.sides():
		party[0].facing = door.get_cell() - party[0].cell
		map.try_open_door(door, party)
		_refresh_overlay()
		return
	if not _path.is_empty():
		return
	var st := map.stairs_at(party[0].cell)
	if st:
		map.take_stairs(st)


## Path (leader cell first) to the nearer side of a closed door, or [] if neither side can be
## reached. Already standing on a side = just that cell.
func door_path(door: Door) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	for s in door.sides():
		if s == party[0].cell:
			return [s]
		var p := map.find_path(party[0].cell, s)
		if not p.is_empty() and (best.is_empty() or p.size() < best.size()):
			best = p
	return best

func _refresh_overlay() -> void:
	if not enabled:
		return
	var preview: Array[Vector2i] = []
	var door: Door = null if _walking else map.closed_door_under(map.get_local_mouse_position())
	if door and not (map.hud and map.hud.mouse_over_ui()):
		preview = door_path(door)
		if not preview.is_empty():
			preview.remove_at(0)
		overlay.set_cells("path", preview, COL_PATH, 0.12, 0.35, true)
		overlay.clear("destination")
		overlay.set_cells("cursor", [door.get_cell()], COL_CURSOR if not door.locked else COL_LOCKED, 0.15, 0.7, true)
		return
	var st: Stairs = null if _walking or door else map.stairs_under(map.get_local_mouse_position())
	if st and not (map.hud and map.hud.mouse_over_ui()):
		preview = map.find_path(party[0].cell, st.get_cell())
		if not preview.is_empty():
			preview.remove_at(0)
		overlay.set_cells("path", preview.slice(0, -1), COL_PATH, 0.12, 0.35, true)
		overlay.clear("destination")
		overlay.set_cells("cursor", [st.get_cell()], COL_STAIRS, 0.2, 0.75, true)
		if map.hud:
			map.hud.flash_hint(st.hint())
		return
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
	if not map.has_floor(_hover):
		overlay.clear("cursor")
	elif reachable:
		overlay.set_cells("cursor", [_hover], COL_CURSOR, 0.15, 0.7, true)
	else:
		overlay.set_cells("cursor", [_hover], COL_BLOCKED, 0.08, 0.5)
