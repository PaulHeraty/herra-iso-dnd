extends SceneTree
## Builds res://assets/tiles/dungeon_tileset.tres from the generated atlases.
## Run after gen_art.gd and an import:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/godot/build_tileset.gd
##
## Source 0 "Floor" (32x16 cells): row 0 = stone floor variants, row 1 = dark floor (doorways).
## Source 1 "Walls" (32x56 cells, drawn 20px up so the base sits on the cell):
##   row 0 = lit lower-left face only   (back-right wall runs)
##   row 1 = dark lower-right face only (back-left wall runs)
##   row 2 = both faces                 (pillars / outside corners)
##   row 3 = cap only                   (back corner / filler)
## Custom data on every tile: blocks_move (bool), kind (String).
##
## NOTE: re-running this overwrites the TileSet. Any edits made by hand in the editor are lost,
## so once the user starts customising tiles, edit the .tres in the editor instead.

const OUT := "res://assets/tiles/dungeon_tileset.tres"
const FLOOR_VARIANTS := 8
const WALL_VARIANTS := 4
const WALL_ROWS := 4


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

	var floor_src := TileSetAtlasSource.new()
	floor_src.resource_name = "Floor"
	floor_src.texture = load("res://assets/tiles/floor_atlas.png")
	floor_src.texture_region_size = Vector2i(32, 16)
	ts.add_source(floor_src, 0)
	for row in 2:
		for i in FLOOR_VARIANTS:
			var c := Vector2i(i, row)
			floor_src.create_tile(c)
			var td := floor_src.get_tile_data(c, 0)
			td.set_custom_data("blocks_move", false)
			td.set_custom_data("kind", "floor" if row == 0 else "floor_dark")

	var wall_src := TileSetAtlasSource.new()
	wall_src.resource_name = "Walls"
	wall_src.texture = load("res://assets/tiles/wall_atlas.png")
	wall_src.texture_region_size = Vector2i(32, 56)
	ts.add_source(wall_src, 1)
	for row in WALL_ROWS:
		for i in WALL_VARIANTS:
			var c := Vector2i(i, row)
			wall_src.create_tile(c)
			var td := wall_src.get_tile_data(c, 0)
			td.texture_origin = Vector2i(0, 20)   # 56px tall texture: put its base diamond on the cell
			td.set_custom_data("blocks_move", true)
			td.set_custom_data("kind", "wall")

	var err := ResourceSaver.save(ts, OUT)
	print("build_tileset: ", OUT, " ", "ok" if err == OK else "ERROR %d" % err)
	quit()
