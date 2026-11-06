extends SceneTree
## Builds res://assets/tiles/outdoor_tileset.tres (the woods above the dungeon) from the atlases of
## gen_outdoor_art.gd. Same layout as dungeon_tileset.tres, so DungeonMap treats it the same way:
##   source 0 "Ground" (32x16): row 0 grass x8, row 1 dirt path x8, row 2 forest floor x8
##   source 1 "Cliffs" (32x56, texture_origin (0, 20)): rows 0-3 like the wall atlas
##   source 2 "Forest" (32x56): the edge of the woods as wall blocks, same rows
## Custom data: blocks_move (bool), kind (String). Overwrites the file (don't re-run after editing
## the TileSet by hand).

const OUT := "res://assets/tiles/outdoor_tileset.tres"


func _init() -> void:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(32, 16)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "blocks_move")
	ts.set_custom_data_layer_type(0, TYPE_BOOL)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(1, "kind")
	ts.set_custom_data_layer_type(1, TYPE_STRING)
	var ground := TileSetAtlasSource.new()
	ground.resource_name = "Ground"
	ground.texture = load("res://assets/tiles/outdoor_floor_atlas.png")
	ground.texture_region_size = Vector2i(32, 16)
	ts.add_source(ground, 0)
	for row in 3:
		for i in 8:
			var c := Vector2i(i, row)
			ground.create_tile(c)
			var td := ground.get_tile_data(c, 0)
			td.set_custom_data("blocks_move", false)
			td.set_custom_data("kind", ["grass", "path", "forest"][row])
	var cliff := TileSetAtlasSource.new()
	cliff.resource_name = "Cliffs"
	cliff.texture = load("res://assets/tiles/cliff_atlas.png")
	cliff.texture_region_size = Vector2i(32, 56)
	ts.add_source(cliff, 1)
	for row in 4:
		for i in 4:
			var c := Vector2i(i, row)
			cliff.create_tile(c)
			var td := cliff.get_tile_data(c, 0)
			td.texture_origin = Vector2i(0, 20)
			td.set_custom_data("blocks_move", true)
			td.set_custom_data("kind", "cliff")
	var forest := TileSetAtlasSource.new()
	forest.resource_name = "Forest"
	forest.texture = load("res://assets/tiles/forest_atlas.png")
	forest.texture_region_size = Vector2i(32, 56)
	ts.add_source(forest, 2)
	for row in 4:
		for i in 4:
			var c := Vector2i(i, row)
			forest.create_tile(c)
			var td := forest.get_tile_data(c, 0)
			td.texture_origin = Vector2i(0, 20)
			td.set_custom_data("blocks_move", true)
			td.set_custom_data("kind", "forest")
	var err := ResourceSaver.save(ts, OUT)
	print("build_outdoor_tileset: ", OUT, " ", "ok" if err == OK else "ERROR %d" % err)
	quit()
