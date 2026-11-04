class_name IsoGrid
## Isometric grid maths shared by maps, markers, movement and combat.
## Matches a TileMapLayer with TileSet tile_shape = ISOMETRIC, layout = DIAMOND_DOWN,
## tile_size = 32x16, placed at the map origin. Cell (0,0) is centred at (16, 8);
## +x runs down-right on screen, +y runs down-left.
##
## View rotation: the map can be shown turned by quarter turns (see DungeonMap.rotate_view).
## Game logic always uses *map* cells (as built in the editor). cell_to_world / world_to_cell
## convert map cells <-> screen positions through the current rotation; the view_* functions
## work on *view* cells (what the visible TileMapLayers hold) with no rotation. In the editor
## the rotation is always 0, so both are the same.

const TILE_W := 32
const TILE_H := 16
const HALF := Vector2(TILE_W / 2.0, TILE_H / 2.0)

## Quarter turns clockwise (0..3) and the map cell the view turns around.
static var rotation := 0
static var pivot := Vector2i.ZERO


## Turn a direction/offset by the view rotation (+x -> +y -> -x -> -y for each quarter turn).
static func rotate_dir(d: Vector2i, turns := rotation) -> Vector2i:
	for i in posmod(turns, 4):
		d = Vector2i(-d.y, d.x)
	return d


## Map cell -> view cell.
static func to_view(cell: Vector2i) -> Vector2i:
	return pivot + rotate_dir(cell - pivot)


## View cell -> map cell.
static func from_view(cell: Vector2i) -> Vector2i:
	return pivot + rotate_dir(cell - pivot, -rotation)


## World (map-local) position of a map cell's centre, in the current view.
static func cell_to_world(cell: Vector2i) -> Vector2:
	return view_cell_to_world(to_view(cell))


## The map cell under a world (map-local) position, in the current view.
static func world_to_cell(pos: Vector2) -> Vector2i:
	return from_view(view_world_to_cell(pos))


## World position of a view cell's centre (no rotation).
static func view_cell_to_world(cell: Vector2i) -> Vector2:
	return HALF + Vector2((cell.x - cell.y) * HALF.x, (cell.x + cell.y) * HALF.y)


## The view cell containing a world position (no rotation).
static func view_world_to_cell(pos: Vector2) -> Vector2i:
	var p := pos - Vector2(HALF.x, 0)   # top corner of cell (0,0) is at (16, 0)
	var a := p.x / HALF.x
	var b := p.y / HALF.y
	return Vector2i(floori((a + b) / 2.0), floori((b - a) / 2.0))


## Snap a world position to the centre of its cell.
static func snap(pos: Vector2) -> Vector2:
	return view_cell_to_world(view_world_to_cell(pos))


## Points of a cell's diamond outline (for overlays and editor gizmos), relative to its centre.
static func diamond(inset := 0.0) -> PackedVector2Array:
	var hx := HALF.x - inset * 2.0
	var hy := HALF.y - inset
	return PackedVector2Array([Vector2(0, -hy), Vector2(hx, 0), Vector2(0, hy), Vector2(-hx, 0)])
