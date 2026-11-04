class_name DungeonMap
extends Node2D
## Root script for every map scene. Expected children (see scenes/maps/map_template.tscn):
##   Ambient   CanvasModulate   - dim cool ambient light
##   Floor     TileMapLayer     - floor tiles (dungeon_tileset, source 0)
##   World     Node2D (y-sort)  - everything that depth-sorts:
##     Walls     TileMapLayer (y-sort) - wall blocks (source 1)
##     Entities  Node2D (y-sort)       - markers (party start, monsters, chests, torches, doors, traps)
##     Decor     Node2D (y-sort)       - pure decoration sprites (bones, webs...)

## Phase 0 only: show static hero/monster sprites at the markers so the room can be eyeballed.
## Phase 1 replaces this with real party/monster actors.
@export var preview_actors := true

const HERO_SPRITES := [
	preload("res://assets/sprites/heroes/fighter.png"),
	preload("res://assets/sprites/heroes/rogue.png"),
	preload("res://assets/sprites/heroes/cleric.png"),
	preload("res://assets/sprites/heroes/mage.png"),
]
const FORMATION := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]

@onready var floor_layer: TileMapLayer = $Floor
@onready var walls_layer: TileMapLayer = $World/Walls
@onready var entities: Node2D = $World/Entities


func _ready() -> void:
	if preview_actors:
		_spawn_preview_actors()


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


func _spawn_preview_actors() -> void:
	for n in entities.get_children():
		if n is PartyStart:
			for i in HERO_SPRITES.size():
				_add_sprite(HERO_SPRITES[i], n.get_cell() + FORMATION[i], Rect2(), Vector2(-8, -22))
		elif n is MonsterSpawn and n.preview:
			_add_sprite(n.preview, n.get_cell(), Rect2(), Vector2(-16, -33))


func _add_sprite(tex: Texture2D, cell: Vector2i, region: Rect2, offset: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = offset
	if region.has_area():
		s.region_enabled = true
		s.region_rect = region
	s.position = IsoGrid.cell_to_world(cell)
	entities.add_child(s)
