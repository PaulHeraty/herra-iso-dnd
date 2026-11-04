class_name DungeonMap
extends Node2D
## Root script for every map scene. Expected children (see scenes/maps/map_template.tscn):
##   Ambient   CanvasModulate   - dim cool ambient light
##   Floor     TileMapLayer     - floor tiles (dungeon_tileset, source 0)
##   World     Node2D (y-sort)  - everything that depth-sorts:
##     Walls     TileMapLayer (y-sort) - wall blocks (source 1)
##     Entities  Node2D (y-sort)       - markers (party start, monsters, chests, torches, doors, traps)
##                                       and actors (the party is spawned here at runtime)
##     Decor     Node2D (y-sort)       - pure decoration sprites (bones, webs...). Put sprites that
##                                       hang on a back wall/corner (webs) in group "wall_decor":
##                                       they are hidden when the view is rotated.
##   Camera    Camera2D
##
## View rotation (Q/E): the Floor and Walls layers you paint are the *map* (hidden at runtime);
## FloorView/WallsView show it turned by quarter turns. All game logic uses map cells.

## Monsters without a scene in scenes/actors/monsters/ get a static preview sprite instead.
@export var preview_missing_monsters := true
## Which PartyStart to use (matches PartyStart.entry_id).
@export var entry_id := "start"

const HERO_SCENE := preload("res://scenes/actors/hero.tscn")
const PARTY_ORDER := [Hero.HeroClass.FIGHTER, Hero.HeroClass.ROGUE, Hero.HeroClass.CLERIC, Hero.HeroClass.MAGE]
## Preferred formation around the leader's cell; falls back to the nearest free cells.
const FORMATION := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
const NEIGHBOURS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Wall atlas rows (see CLAUDE.md): which faces of a block are drawn.
const WALL_ROW_LEFT := 0      ## lower-left face only
const WALL_ROW_RIGHT := 1     ## lower-right face only
const WALL_ROW_BOTH := 2
const WALL_ROW_CAP := 3

## The heroes, leader first.
var party: Array[Hero] = []
## Monsters spawned from MonsterSpawn markers.
var monsters: Array[Monster] = []
var overlay: GridOverlay
var controller: PartyController
var camera_controller: CameraController
var wall_fader: WallFader
## Visible, rotated copies of the Floor / Walls layers.
var floor_view: TileMapLayer
var walls_view: TileMapLayer
var _astar := AStarGrid2D.new()
var _pending_turns := 0
## Sprites placed by map cell (decor, monster previews): node -> [map cell, offset from its centre]
var _placed := {}

@onready var floor_layer: TileMapLayer = $Floor
@onready var walls_layer: TileMapLayer = $World/Walls
@onready var entities: Node2D = $World/Entities
@onready var decor: Node2D = $World/Decor
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	IsoGrid.rotation = 0
	var fr := floor_layer.get_used_rect()
	IsoGrid.pivot = fr.position + fr.size / 2
	for n in entities.get_children():
		if n is MapMarker:
			n.lock_cell()
	for s in decor.get_children():
		if s is Node2D:
			_place_by_cell(s, s.position)
	_make_view_layers()
	overlay = GridOverlay.new()
	overlay.name = "Overlay"
	add_child(overlay)
	move_child(overlay, floor_view.get_index() + 1)   # above the floor, below World
	_spawn_monsters()
	refresh_navigation()
	_spawn_party()
	camera_controller = CameraController.new()
	camera_controller.name = "CameraController"
	camera_controller.camera = camera
	camera_controller.target = party[0] if not party.is_empty() else null
	camera_controller.bounds = get_world_bounds()
	add_child(camera_controller)
	controller = PartyController.new()
	controller.name = "PartyController"
	controller.map = self
	controller.overlay = overlay
	controller.camera = camera_controller
	controller.party = party
	add_child(controller)
	_apply_view()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("view_rotate_right"):
		rotate_view(1)
	elif Input.is_action_just_pressed("view_rotate_left"):
		rotate_view(-1)
	if _pending_turns != 0 and not _anyone_moving():
		apply_pending_rotation()
	var reveal: Array[Rect2] = []
	for h in party:
		reveal.append(WallFader.figure_rect(h.position))
	for mo in monsters:
		reveal.append(WallFader.figure_rect(mo.position))
	for c in overlay.revealed_cells():
		reveal.append(WallFader.floor_rect(c))
	wall_fader.update(reveal, delta)


## Turn the view by quarter turns (+1 = clockwise). Applied as soon as nobody is mid-step.
func rotate_view(turns: int) -> void:
	_pending_turns += turns


## Apply a requested rotation now (PartyController calls this between steps).
func apply_pending_rotation() -> void:
	if _pending_turns == 0:
		return
	# Keep the map cell at the centre of the screen at the centre after turning.
	var focus := IsoGrid.world_to_cell(camera.position)
	IsoGrid.rotation = posmod(IsoGrid.rotation + _pending_turns, 4)
	_pending_turns = 0
	_apply_view()
	camera_controller.bounds = get_world_bounds()
	camera_controller.jump_to(IsoGrid.cell_to_world(focus))


## True if a cell has floor, no wall, no closed door, no chest and no monster (heroes are ignored).
func is_walkable(cell: Vector2i) -> bool:
	if floor_layer.get_cell_source_id(cell) == -1:
		return false
	var wall := walls_layer.get_cell_tile_data(cell)
	if wall and wall.get_custom_data("blocks_move"):
		return false
	for n in entities.get_children():
		if n is Door and n.get_cell() == cell and n.blocks_move():
			return false
		if n is Chest and n.get_cell() == cell:
			return false
		if n is Monster and n.cell == cell:
			return false
		if n is MonsterSpawn and n.monster == null and n.get_cell() == cell:
			return false
	return true


## True if the map has a floor tile at `cell`.
func has_floor(cell: Vector2i) -> bool:
	return floor_layer.get_cell_source_id(cell) != -1


## Rebuild the walk grid from the tiles and doors. Call after opening/closing doors or editing tiles.
func refresh_navigation() -> void:
	_astar.region = floor_layer.get_used_rect().grow(1)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	var r := _astar.region
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			_astar.set_point_solid(Vector2i(x, y), not is_walkable(Vector2i(x, y)))


## Cells from `from` to `to` inclusive (diagonals allowed when not cutting a wall corner),
## or [] if `to` can't be reached.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _astar.is_in_boundsv(from) or not _astar.is_in_boundsv(to) or _astar.is_point_solid(to):
		return out
	out.assign(_astar.get_id_path(from, to))
	return out


## World-space box around all floor and wall tiles in the current view (walls reach 40 px up).
func get_world_bounds() -> Rect2:
	var r := Rect2()
	var first := true
	for layer: TileMapLayer in [floor_layer, walls_layer]:
		var up := 40.0 if layer == walls_layer else 0.0
		for c in layer.get_used_cells():
			var p := IsoGrid.cell_to_world(c)
			var cell_r := Rect2(p.x - 16, p.y - 8 - up, 32, 16 + up)
			r = cell_r if first else r.merge(cell_r)
			first = false
	return r


## The actor standing on a cell, or null.
func actor_at(cell: Vector2i) -> Actor:
	for n in entities.get_children():
		if n is Actor and n.cell == cell:
			return n
	return null


# --- view (rotation) ---------------------------------------------------------------------------

func _make_view_layers() -> void:
	floor_view = TileMapLayer.new()
	floor_view.name = "FloorView"
	floor_view.tile_set = floor_layer.tile_set
	add_child(floor_view)
	move_child(floor_view, floor_layer.get_index() + 1)
	walls_view = TileMapLayer.new()
	walls_view.name = "WallsView"
	walls_view.tile_set = walls_layer.tile_set
	walls_view.y_sort_enabled = true
	walls_layer.get_parent().add_child(walls_view)
	walls_layer.get_parent().move_child(walls_view, walls_layer.get_index() + 1)
	floor_layer.visible = false
	walls_layer.visible = false


## Rebuild everything visible for the current IsoGrid.rotation.
func _apply_view() -> void:
	floor_view.clear()
	for c in floor_layer.get_used_cells():
		floor_view.set_cell(IsoGrid.to_view(c), floor_layer.get_cell_source_id(c),
				floor_layer.get_cell_atlas_coords(c), floor_layer.get_cell_alternative_tile(c))
	walls_view.clear()
	var view_walls := {}
	for c in walls_layer.get_used_cells():
		view_walls[IsoGrid.to_view(c)] = c
	for v: Vector2i in view_walls:
		var c: Vector2i = view_walls[v]
		var sid := walls_layer.get_cell_source_id(c)
		var atlas := walls_layer.get_cell_atlas_coords(c)
		if IsoGrid.rotation == 0:
			walls_view.set_cell(v, sid, atlas, walls_layer.get_cell_alternative_tile(c))
		else:
			# Pick the block variant by which faces are now exposed to the viewer.
			var left := not view_walls.has(v + Vector2i(0, 1))
			var right := not view_walls.has(v + Vector2i(1, 0))
			var row := WALL_ROW_CAP
			if left and right:
				row = WALL_ROW_BOTH
			elif left:
				row = WALL_ROW_LEFT
			elif right:
				row = WALL_ROW_RIGHT
			walls_view.set_cell(v, sid, Vector2i(atlas.x, row))
	wall_fader = WallFader.new(walls_view, entities)
	for n in entities.get_children():
		if n is MapMarker:
			n.apply_view()
		elif n is Actor:
			n.place_at(n.cell)
	for s: Node2D in _placed:
		s.position = IsoGrid.cell_to_world(_placed[s][0]) + _placed[s][1]
		if s.is_in_group("wall_decor"):
			s.visible = IsoGrid.rotation == 0
	overlay.queue_redraw()


## Remember a sprite's map cell (and offset within it) so it can follow view rotation.
func _place_by_cell(s: Node2D, pos: Vector2) -> void:
	var c := IsoGrid.world_to_cell(pos)
	_placed[s] = [c, pos - IsoGrid.cell_to_world(c)]


func _anyone_moving() -> bool:
	for h in party:
		if h.is_moving():
			return true
	return false


# --- spawning ----------------------------------------------------------------------------------

func _find_party_start() -> PartyStart:
	var first: PartyStart = null
	for n in entities.get_children():
		if n is PartyStart:
			if n.entry_id == entry_id:
				return n
			if first == null:
				first = n
	return first


func _spawn_party() -> void:
	var start := _find_party_start()
	if start == null:
		push_warning("%s: no PartyStart marker, party not spawned" % name)
		return
	var cells := _formation_cells(start.get_cell(), PARTY_ORDER.size())
	for i in cells.size():
		var hero: Hero = HERO_SCENE.instantiate()
		hero.hero_class = PARTY_ORDER[i]
		entities.add_child(hero)
		hero.facing = PartyStart.FACING_DIR[start.facing]
		hero.place_at(cells[i])
		party.append(hero)


## n free walkable cells for the party: the FORMATION offsets where possible, else the nearest
## free cells reachable from the start (breadth-first), so walls never swallow a hero.
func _formation_cells(origin: Vector2i, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for off in FORMATION:
		if out.size() < n and is_walkable(origin + off):
			out.append(origin + off)
	var queue: Array[Vector2i] = [origin]
	var seen := {origin: true}
	while out.size() < n and not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if is_walkable(c) and c not in out:
			out.append(c)
		for d in NEIGHBOURS:
			var nc: Vector2i = c + d
			if not seen.has(nc) and is_walkable(nc):
				seen[nc] = true
				queue.append(nc)
	if out.size() < n:
		push_warning("%s: only %d free cells near PartyStart" % [name, out.size()])
	return out


## A Monster actor at every MonsterSpawn whose scenes/actors/monsters/<monster_id>.tscn exists.
func _spawn_monsters() -> void:
	for n in entities.get_children():
		if not n is MonsterSpawn:
			continue
		var path := "res://scenes/actors/monsters/%s.tscn" % n.monster_id
		if not ResourceLoader.exists(path):
			push_warning("%s: no scene for monster '%s'" % [name, n.monster_id])
			if preview_missing_monsters and n.preview:
				_spawn_preview_sprite(n)
			continue
		var m: Monster = (load(path) as PackedScene).instantiate()
		m.group_id = n.group_id
		entities.add_child(m)
		m.facing = PartyStart.FACING_DIR[n.facing]
		m.place_at(n.get_cell())
		n.monster = m
		monsters.append(m)


func _spawn_preview_sprite(n: MonsterSpawn) -> void:
	var s := Sprite2D.new()
	s.texture = n.preview
	s.centered = false
	s.offset = n.preview_offset
	entities.add_child(s)
	_placed[s] = [n.get_cell(), Vector2.ZERO]
	s.position = IsoGrid.cell_to_world(n.get_cell())
