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
const COL_TALK := Color8(140, 240, 150)

var map: DungeonMap
var overlay: GridOverlay
var camera: CameraController
var party: Array[Hero] = []

## Cells still to walk (leader), destination last.
var _path: Array[Vector2i] = []
## Door to open when the leader gets there (clicked a closed door).
var _door_goal: Door
## Chest to open when the leader gets there (clicked a closed chest).
var _chest_goal: Chest
## NPC to talk to when the leader gets there (clicked him).
var _npc_goal: Npc
## Lever, trap, brazier, block or stone face to use when the leader gets there (Mechanisms).
var _thing_goal: MapMarker
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
		var npc := map.npc_under(mouse)
		var thing: MapMarker = null if npc else map.mech.thing_under(mouse)
		var chest: Chest = null if npc or thing else map.closed_chest_under(mouse)
		var door: Door = null if chest or npc or thing else map.closed_door_under(mouse)
		var target := IsoGrid.world_to_cell(mouse)
		_door_goal = null
		_chest_goal = null
		_thing_goal = null
		_npc_goal = null
		if npc:
			var np := approach_path(npc.sides())
			if np.is_empty():
				get_viewport().set_input_as_handled()
				return
			_npc_goal = npc
			target = np[-1]
			if target == party[0].cell:
				get_viewport().set_input_as_handled()
				_arrived()
				return
		elif thing:
			var tp := approach_path(map.mech.approach_cells(thing))
			if tp.is_empty():
				get_viewport().set_input_as_handled()
				if thing is Prop and map.hud:
					map.hud.flash_hint("The block can't be pushed from anywhere the party can reach.")
				return
			_thing_goal = thing
			target = tp[-1]
			if target == party[0].cell:
				get_viewport().set_input_as_handled()
				_arrived()
				return
		elif chest:
			var cp := approach_path(chest.sides())
			if cp.is_empty():
				get_viewport().set_input_as_handled()
				return
			_chest_goal = chest
			target = cp[-1]
			if target == party[0].cell:
				get_viewport().set_input_as_handled()
				_arrived()
				return
		elif door:
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
			var pt := map.portal_under(mouse)
			var st: Stairs = null if pt else map.stairs_under(mouse)
			if pt:
				target = pt.get_cell()
				if target == party[0].cell:
					get_viewport().set_input_as_handled()
					map.take_portal(pt)
					return
			elif st:
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
		if map.mech.after_party_step():
			_path.clear()                   # a trap went off, or a note to read
			_door_goal = null
			_chest_goal = null
			_npc_goal = null
			_thing_goal = null
	_walking = false
	_refresh_overlay()
	_arrived()



## The leader has stopped: open the door or chest it walked to, or take the stairs it stands on.
func _arrived() -> void:
	if not enabled:            # combat started on the way
		_door_goal = null
		_thing_goal = null
		_chest_goal = null
		_npc_goal = null
		return
	var npc := _npc_goal
	_npc_goal = null
	if npc and npc.present and party[0].cell in npc.sides():
		party[0].facing = npc.get_cell() - party[0].cell
		map.talk_to(npc)
		_refresh_overlay()
		return
	var thing := _thing_goal
	_thing_goal = null
	if thing and is_instance_valid(thing) and party[0].cell in map.mech.approach_cells(thing) + _here(thing):
		map.mech.interact(thing)
		_refresh_overlay()
		return
	var chest := _chest_goal
	_chest_goal = null
	if chest and not chest.opened and party[0].cell in chest.sides():
		party[0].facing = chest.get_cell() - party[0].cell
		map.try_open_chest(chest, party)
		_refresh_overlay()
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
	var pt := map.portal_at(party[0].cell)
	if pt:
		map.take_portal(pt)
		return
	var st := map.stairs_at(party[0].cell)
	if st:
		map.take_stairs(st)


## Path (leader cell first) to the nearer side of a closed door, or [] if neither side can be
## reached. Already standing on a side = just that cell.
func door_path(door: Door) -> Array[Vector2i]:
	return approach_path(door.sides())


## Shortest path (leader cell first) to any of `cells`, or [] if none can be reached. Already
## standing on one = just that cell.
func approach_path(cells: Array[Vector2i]) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	for s in cells:
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
	var npc: Npc = null if _walking else map.npc_under(map.get_local_mouse_position())
	if npc and not (map.hud and map.hud.mouse_over_ui()):
		preview = approach_path(npc.sides())
		if not preview.is_empty():
			preview.remove_at(0)
		overlay.set_cells("path", preview, COL_PATH, 0.12, 0.35, true)
		overlay.clear("destination")
		overlay.set_cells("cursor", [npc.get_cell()], COL_TALK, 0.15, 0.7, true)
		if map.hud:
			map.hud.flash_hint("%s: click to talk." % npc.display_name)
		return
	var thing: MapMarker = null if _walking else map.mech.thing_under(map.get_local_mouse_position())
	if thing and not (map.hud and map.hud.mouse_over_ui()):
		preview = approach_path(map.mech.approach_cells(thing))
		if not preview.is_empty():
			preview.remove_at(0)
		overlay.set_cells("path", preview, COL_PATH, 0.12, 0.35, true)
		var col := COL_LOCKED if thing is Trap else COL_CURSOR
		overlay.set_cells("cursor", [thing.get_cell()], col, 0.15, 0.7, true)
		overlay.clear("destination")
		if thing is Prop:
			# where the block would slide from where the leader will stand
			var from: Vector2i = preview[-1] if not preview.is_empty() else party[0].cell
			var dest := map.mech.push_target(thing, from)
			if dest != Mechanisms.NO_CELL:
				overlay.set_cells("destination", [dest], COL_LOCKED, 0.2, 0.6, true)
		if map.hud:
			map.hud.flash_hint(map.mech.hint(thing))
		return
	var pt: Portal = null if _walking else map.portal_under(map.get_local_mouse_position())
	if pt and not (map.hud and map.hud.mouse_over_ui()):
		preview = map.find_path(party[0].cell, pt.get_cell())
		if not preview.is_empty():
			preview.remove_at(0)
		overlay.set_cells("path", preview.slice(0, -1), COL_PATH, 0.12, 0.35, true)
		overlay.clear("destination")
		overlay.set_cells("cursor", [pt.get_cell()], COL_STAIRS, 0.2, 0.75, true)
		if map.hud:
			map.hud.flash_hint(pt.hint())
		return
	var chest: Chest = null if _walking else map.closed_chest_under(map.get_local_mouse_position())
	if chest and not (map.hud and map.hud.mouse_over_ui()):
		preview = approach_path(chest.sides())
		if not preview.is_empty():
			preview.remove_at(0)
		overlay.set_cells("path", preview, COL_PATH, 0.12, 0.35, true)
		overlay.clear("destination")
		overlay.set_cells("cursor", [chest.get_cell()], COL_CURSOR if not chest.locked else COL_LOCKED, 0.15, 0.7, true)
		if map.hud:
			map.hud.flash_hint("That chest is breathing... a mimic! Click to fight it." if chest.mimic_spotted else (map.lock_hint(chest, "Chest") if chest.locked else "Chest: click to open."))
		return
	var door: Door = null if _walking else map.closed_door_under(map.get_local_mouse_position())
	if door and not (map.hud and map.hud.mouse_over_ui()):
		preview = door_path(door)
		if not preview.is_empty():
			preview.remove_at(0)
		overlay.set_cells("path", preview, COL_PATH, 0.12, 0.35, true)
		overlay.clear("destination")
		overlay.set_cells("cursor", [door.get_cell()], COL_CURSOR if not door.locked else COL_LOCKED, 0.15, 0.7, true)
		if map.hud and door.hint(map) != "":
			map.hud.flash_hint(door.hint(map))
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


## Thing goals reached on a cell approach_cells no longer lists (a block whose far side just got
## blocked) still count if the leader is next to it: the block then says it won't budge.
func _here(thing: MapMarker) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if DungeonMap.grid_distance(party[0].cell, thing.get_cell()) == 1:
		out.append(party[0].cell)
	return out


## Walk the party one or more cells to `cell` (after pushing a block: into its old place).
func walk_to(cell: Vector2i) -> void:
	var p := map.find_path(party[0].cell, cell)
	if p.size() < 2:
		return
	p.remove_at(0)
	_path = p
	if not _walking:
		_walk()
