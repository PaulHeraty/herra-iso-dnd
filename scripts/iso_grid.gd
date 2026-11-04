class_name IsoGrid
## Isometric grid maths shared by maps, markers and (later) movement/combat.
## Matches a TileMapLayer with TileSet tile_shape = ISOMETRIC, layout = DIAMOND_DOWN,
## tile_size = 32x16, placed at the map origin. Cell (0,0) is centred at (16, 8);
## +x runs down-right on screen, +y runs down-left.

const TILE_W := 32
const TILE_H := 16
const HALF := Vector2(TILE_W / 2.0, TILE_H / 2.0)


## World (map-local) position of a cell's centre.
static func cell_to_world(cell: Vector2i) -> Vector2:
	return HALF + Vector2((cell.x - cell.y) * HALF.x, (cell.x + cell.y) * HALF.y)


## The cell containing a world (map-local) position.
static func world_to_cell(pos: Vector2) -> Vector2i:
	var p := pos - Vector2(HALF.x, 0)   # top corner of cell (0,0) is at (16, 0)
	var a := p.x / HALF.x
	var b := p.y / HALF.y
	return Vector2i(floori((a + b) / 2.0), floori((b - a) / 2.0))


## Snap a world position to the centre of its cell.
static func snap(pos: Vector2) -> Vector2:
	return cell_to_world(world_to_cell(pos))


## Points of a cell's diamond outline (for overlays and editor gizmos), relative to its centre.
static func diamond(inset := 0.0) -> PackedVector2Array:
	var hx := HALF.x - inset * 2.0
	var hy := HALF.y - inset
	return PackedVector2Array([Vector2(0, -hy), Vector2(hx, 0), Vector2(0, hy), Vector2(-hx, 0)])
