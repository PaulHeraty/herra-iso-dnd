extends SceneTree
## Builds two map scenes:
##   scenes/maps/map_template.tscn - empty map with the right node layout (duplicate it for new maps)
##   scenes/maps/test_room.tscn    - the concept mock-up room (9x9, back walls, doorway, torches,
##                                   web, bones, chest, Eye Tyrant spawn, party start)
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/godot/build_test_room.gd
## Re-running overwrites both scenes, so don't run it after hand-editing them.

const TILESET := "res://assets/tiles/dungeon_tileset.tres"
const AMBIENT := Color(0.34, 0.36, 0.50)
const N := 9
const DOOR := Vector2i(5, -1)
const FLOOR_SRC := 0
const WALL_SRC := 1
enum WallRow { FACE_L, FACE_R, BOTH, CAP }


func _init() -> void:
	_save(_make_map("MapTemplate", false), "res://scenes/maps/map_template.tscn")
	_save(_make_map("TestRoom", true), "res://scenes/maps/test_room.tscn")
	quit()


func _save(root: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps, path)
	print("build_test_room: ", path, " ", "ok" if err == OK else "ERROR %d" % err)
	root.free()


func _own(node: Node, root: Node) -> void:
	node.owner = root


func _make_map(root_name: String, fill: bool) -> Node2D:
	var root := Node2D.new()
	root.name = root_name
	root.set_script(load("res://scripts/maps/dungeon_map.gd"))
	var ts: TileSet = load(TILESET)

	var amb := CanvasModulate.new()
	amb.name = "Ambient"
	amb.color = AMBIENT
	root.add_child(amb)
	_own(amb, root)

	var floor := TileMapLayer.new()
	floor.name = "Floor"
	floor.tile_set = ts
	root.add_child(floor)
	_own(floor, root)

	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	root.add_child(world)
	_own(world, root)

	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = ts
	walls.y_sort_enabled = true
	world.add_child(walls)
	_own(walls, root)

	var entities := Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	world.add_child(entities)
	_own(entities, root)

	var decor := Node2D.new()
	decor.name = "Decor"
	decor.y_sort_enabled = true
	world.add_child(decor)
	_own(decor, root)

	var cam := Camera2D.new()
	cam.name = "Camera"
	cam.position = IsoGrid.cell_to_world(Vector2i(4, 4)) + Vector2(0, -16)
	root.add_child(cam)
	_own(cam, root)

	if fill:
		_fill_test_room(root, floor, walls, entities, decor)
	return root


func _fill_test_room(root: Node, floor: TileMapLayer, walls: TileMapLayer, entities: Node2D, decor: Node2D) -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 42
	for y in N:
		for x in N:
			floor.set_cell(Vector2i(x, y), FLOOR_SRC, Vector2i(rnd.randi_range(0, 7), 0))
	floor.set_cell(DOOR, FLOOR_SRC, Vector2i(0, 1))
	floor.set_cell(DOOR + Vector2i(0, -1), FLOOR_SRC, Vector2i(1, 1))

	walls.set_cell(Vector2i(-1, -1), WALL_SRC, Vector2i(0, WallRow.CAP))
	for x in N:
		if Vector2i(x, -1) != DOOR:
			walls.set_cell(Vector2i(x, -1), WALL_SRC, Vector2i(rnd.randi_range(0, 3), WallRow.FACE_L))
	for y in N:
		walls.set_cell(Vector2i(-1, y), WALL_SRC, Vector2i(rnd.randi_range(0, 3), WallRow.FACE_R))

	var torch: PackedScene = load("res://scenes/markers/torch.tscn")
	for t in [[Vector2i(2, -1), 0], [Vector2i(8, -1), 0], [Vector2i(-1, 2), 1], [Vector2i(-1, 6), 1]]:
		var n := torch.instantiate()
		n.face = t[1]
		n.position = IsoGrid.cell_to_world(t[0]) + n._snap_offset()
		_add(entities, n, root)

	var door := (load("res://scenes/markers/door.tscn") as PackedScene).instantiate()
	door.position = IsoGrid.cell_to_world(DOOR)
	_add(entities, door, root)

	var chest := (load("res://scenes/markers/chest.tscn") as PackedScene).instantiate()
	chest.position = IsoGrid.cell_to_world(Vector2i(8, 0))
	chest.gold = 25
	_add(entities, chest, root)

	var spawn := (load("res://scenes/markers/monster_spawn.tscn") as PackedScene).instantiate()
	spawn.position = IsoGrid.cell_to_world(Vector2i(5, 2))
	_add(entities, spawn, root)

	var start := (load("res://scenes/markers/party_start.tscn") as PackedScene).instantiate()
	start.position = IsoGrid.cell_to_world(Vector2i(4, 5))
	_add(entities, start, root)

	var bones := Sprite2D.new()
	bones.name = "Bones"
	bones.texture = load("res://assets/sprites/props/bones.png")
	bones.centered = false
	bones.offset = Vector2(-7, -6)
	bones.position = IsoGrid.cell_to_world(Vector2i(0, 1))
	_add(decor, bones, root)

	# Web in the back corner: anchored just in front of the corner walls so it sorts above them.
	var web := Sprite2D.new()
	web.name = "Web"
	web.texture = load("res://assets/sprites/props/web.png")
	web.centered = false
	web.offset = Vector2(-27, -34)
	web.position = Vector2(16, 1)
	_add(decor, web, root)


func _add(parent: Node, n: Node, root: Node) -> void:
	parent.add_child(n)
	n.owner = root
