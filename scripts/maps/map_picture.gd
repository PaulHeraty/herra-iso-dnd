class_name MapPicture
extends RefCounted
## The map as a small picture for the minimap and the full map (M): one pixel per map cell,
## coloured by its tile (each tile's average colour), honouring the fog of war:
##   unexplored = transparent, explored but out of sight = dimmed, in sight = full colour.
## Walls are brightened so rooms read as outlined shapes; props are darker floor; doors brown.
## MapView draws it through an isometric transform (each pixel becomes a diamond), so it matches
## the game's view and its rotation. Only the cells whose fog changed are redrawn (see refresh).

const COL_DOOR := Color8(170, 112, 52)
const COL_DOOR_OPEN := Color8(110, 78, 46)
const DIM := 0.5
const WALL_BRIGHT := 1.9
const FLOOR_BRIGHT := 1.35

var map: DungeonMap
var rect := Rect2i()
var image: Image
var texture: ImageTexture
## Set by DungeonMap whenever the fog look changes; the next texture() call catches up.
var dirty := true

var _base := {}          ## map cell -> Color (fully lit)
var _doors := {}         ## map cell -> Door
var _drawn_vis := {}     ## the visible set as last drawn
var _built := false
var _explored_n := 0

static var _tile_cols := {}     ## "texture path|x,y,w,h" -> average Color


func _init(m: DungeonMap) -> void:
	map = m
	rect = m.floor_layer.get_used_rect().merge(m.walls_layer.get_used_rect())
	image = Image.create(maxi(rect.size.x, 1), maxi(rect.size.y, 1), false, Image.FORMAT_RGBA8)
	for c in m.floor_layer.get_used_cells():
		_base[c] = _brighter(_tile_colour(m.floor_layer, c), FLOOR_BRIGHT)
	var props := {}
	for n in m.entities.get_children():
		if n is Door:
			_doors[n.get_cell()] = n
		elif n is Prop or n is Brazier or n is Chest:
			props[n.get_cell()] = true
	for c in props:
		if _base.has(c):
			_base[c] = (_base[c] as Color).darkened(0.45)
	for c in m.walls_layer.get_used_cells():
		_base[c] = _brighter(_tile_colour(m.walls_layer, c), WALL_BRIGHT)
	texture = ImageTexture.create_from_image(image)


## The picture, brought up to date with the fog.
func get_texture() -> ImageTexture:
	if dirty:
		refresh()
	return texture


## Redraw the cells whose look may have changed: everything the first time, then the cells that
## were or are in sight (newly explored cells are always in sight) and the doors.
func refresh() -> void:
	dirty = false
	var vis: Dictionary = map.fog.visible
	var fresh := 0                  # upper bound of the cells explored since the last refresh
	if _built and map.fog_of_war:
		for c: Vector2i in vis:
			if not _drawn_vis.has(c):
				fresh += 1
	if not _built or not map.fog_of_war or map.fog.explored.size() - _explored_n > fresh:
		# First time, no fog, or cells explored some other way (a load): draw everything.
		_built = true
		image.fill(Color(0, 0, 0, 0))
		for c: Vector2i in _base:
			_put(c)
	else:
		for c: Vector2i in _drawn_vis:
			if not vis.has(c):
				_put(c)
		for c: Vector2i in vis:
			if not _drawn_vis.has(c):
				_put(c)
		for c: Vector2i in _doors:
			_put(c)
	_drawn_vis = vis
	_explored_n = map.fog.explored.size()
	texture.update(image)


## Map cell -> pixel in `image`.
func pixel_of(cell: Vector2i) -> Vector2i:
	return cell - rect.position


func colour_of(cell: Vector2i) -> Color:
	if not _base.has(cell) or not map.is_explored(cell):
		return Color(0, 0, 0, 0)
	var col: Color = _base[cell]
	var d: Door = _doors.get(cell)
	if d:
		if d.is_hidden():
			col = _hidden_wall_colour(cell)
		elif d.style == Door.Style.ICE and not d.is_open:
			col = Color8(150, 200, 240)
		else:
			col = COL_DOOR_OPEN if d.is_open else COL_DOOR
	if not map.is_seen(cell):
		col = Color(col.r * DIM, col.g * DIM, col.b * DIM * 1.1)
	return col


## The explored part of the map (map cells), for fitting the full map.
func explored_cells() -> Array:
	if not map.fog_of_war:
		return _base.keys()
	return map.fog.explored.keys()


func _put(c: Vector2i) -> void:
	var p := pixel_of(c)
	if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height():
		image.set_pixelv(p, colour_of(c))


## Average colour of the opaque pixels of the tile painted at `c` (cached per tile).
static func _tile_colour(layer: TileMapLayer, c: Vector2i) -> Color:
	var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
	if src == null or src.texture == null:
		return Color8(80, 80, 90)
	var region := src.get_tile_texture_region(layer.get_cell_atlas_coords(c))
	var key := "%s|%s" % [src.texture.resource_path, region]
	if _tile_cols.has(key):
		return _tile_cols[key]
	var img := src.texture.get_image()
	if img.is_compressed():
		img.decompress()
	var sum := Vector3.ZERO
	var n := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var px := img.get_pixel(x, y)
			if px.a > 0.5:
				sum += Vector3(px.r, px.g, px.b)
				n += 1
	var col := Color(sum.x / n, sum.y / n, sum.z / n) if n > 0 else Color8(80, 80, 90)
	_tile_cols[key] = col
	return col


## Brighter by `k` (HSV value), keeping the hue: grey stone stays grey, forest stays green.
static func _brighter(c: Color, k: float) -> Color:
	return Color.from_hsv(c.h, c.s, minf(1.0, c.v * k))


## An unfound secret door looks like the wall beside it.
func _hidden_wall_colour(cell: Vector2i) -> Color:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if map.walls_layer.get_cell_source_id(cell + d) != -1 and _base.has(cell + d):
			return _base[cell + d]
	return _base.get(cell, Color.GRAY)
