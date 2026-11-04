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

@onready var floor_layer: TileMapLayer = $Floor
@onready var walls_layer: TileMapLayer = $World/Walls
@onready var entities: Node2D = $World/Entities
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	_spawn_party()
	if preview_monsters:
		_spawn_monster_previews()


## True if a cell has floor, no wall and no closed door.
func is_walkable(cell: Vector2i) -> bool:
	if floor_layer.get_cell_source_id(cell) == -1:
		return false
	var wall := walls_layer.get_cell_tile_data(cell)
	if wall and wall.get_custom_data("blocks_move"):
		return false
	for n in entities.get_children():
		if n is Door and n.get_cell() == cell and n.blocks_move():
			return false
	return true


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
	camera.position = party[0].position.round()


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
