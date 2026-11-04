class_name DungeonMap
extends Node2D
## Root script for every map scene. Expected children (see scenes/maps/map_template.tscn):
##   Ambient   CanvasModulate   - dim cool ambient light
##   Floor     TileMapLayer     - floor tiles (dungeon_tileset, source 0)
##   World     Node2D (y-sort)  - everything that depth-sorts:
##     Walls     TileMapLayer (y-sort) - wall blocks (source 1)
##     Entities  Node2D (y-sort)       - markers (party start, monsters, chests, torches, doors, traps)
##                                       and actors (the party is spawned here at runtime)
##     Decor     Node2D (y-sort)       - pure decoration sprites (bones, webs...)
##   Camera    Camera2D

## Until Phase 2 adds real monsters: show a static sprite at each MonsterSpawn marker.
@export var preview_monsters := true
## Which PartyStart to use (matches PartyStart.entry_id).
@export var entry_id := "start"

const HERO_SCENE := preload("res://scenes/actors/hero.tscn")
const PARTY_ORDER := [Hero.HeroClass.FIGHTER, Hero.HeroClass.ROGUE, Hero.HeroClass.CLERIC, Hero.HeroClass.MAGE]
## Preferred formation around the leader's cell; falls back to the nearest free cells.
const FORMATION := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
const NEIGHBOURS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## The heroes, leader first.
var party: Array[Hero] = []
var overlay: GridOverlay
var controller: PartyController
var camera_controller: CameraController
var wall_fader: WallFader
var _astar := AStarGrid2D.new()

@onready var floor_layer: TileMapLayer = $Floor
@onready var walls_layer: TileMapLayer = $World/Walls
@onready var entities: Node2D = $World/Entities
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	overlay = GridOverlay.new()
	overlay.name = "Overlay"
	add_child(overlay)
	move_child(overlay, floor_layer.get_index() + 1)   # above the floor, below World
	refresh_navigation()
	wall_fader = WallFader.new(walls_layer, entities)
	_spawn_party()
	if preview_monsters:
		_spawn_monster_previews()
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


func _process(delta: float) -> void:
	var reveal: Array[Rect2] = []
	for h in party:
		reveal.append(WallFader.figure_rect(h.position))
	for c in overlay.revealed_cells():
		reveal.append(WallFader.floor_rect(c))
	wall_fader.update(reveal, delta)


## True if a cell has floor, no wall, no closed door, no chest and no monster (actors are ignored).
func is_walkable(cell: Vector2i) -> bool:
	if floor_layer.get_cell_source_id(cell) == -1:
		return false
	var wall := walls_layer.get_cell_tile_data(cell)
	if wall and wall.get_custom_data("blocks_move"):
		return false
	for n in entities.get_children():
		if n is Door and n.get_cell() == cell and n.blocks_move():
			return false
		if (n is Chest or n is MonsterSpawn) and n.get_cell() == cell:
			return false
	return true


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


## World-space box around all floor and wall tiles (wall blocks reach 40 px up).
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


func _spawn_monster_previews() -> void:
	for n in entities.get_children():
		if n is MonsterSpawn and n.preview:
			var s := Sprite2D.new()
			s.texture = n.preview
			s.centered = false
			s.offset = n.preview_offset
			s.position = IsoGrid.cell_to_world(n.get_cell())
			entities.add_child(s)
