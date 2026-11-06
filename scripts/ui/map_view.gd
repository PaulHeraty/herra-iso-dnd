class_name MapView
extends Control
## Draws a DungeonMap's MapPicture, isometric and turned like the game's view, plus markers:
## heroes (class colours), monsters the party can see, chests not yet opened, stairs, the
## trader, portals. Everything honours the fog (markers only on explored cells, monsters only
## while seen or in the fight). Used by MiniMap (follows the leader) and MapScreen (pan + zoom).
##   `centre` = world position at the middle of the view, `cell_px` = width of one cell's diamond.

const COL_BG := Color8(10, 9, 14)
const COL_OUTLINE := Color8(20, 16, 24)
const COL_HERO := [Color8(96, 150, 255), Color8(110, 214, 110), Color8(255, 236, 150), Color8(214, 120, 250)]
const COL_HERO_DOWN := Color8(120, 116, 128)
const COL_MONSTER := Color8(240, 64, 52)
const COL_CHEST := Color8(255, 210, 80)
const COL_STAIRS := Color8(120, 230, 240)
const COL_NPC := Color8(150, 255, 150)
const COL_PORTAL := Color8(200, 130, 255)
const COL_TRAP := Color8(255, 90, 60)

var map: DungeonMap
var centre := Vector2.ZERO
var cell_px := 6.0
## Blink the leader's dot (the minimap: "you are here").
var blink_leader := false

var _t := 0.0


func _ready() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		queue_redraw()


## World units -> view pixels.
func scale_k() -> float:
	return cell_px / float(IsoGrid.TILE_W)


## World position -> position in this control.
func to_view(world: Vector2) -> Vector2:
	return ((world - centre) * scale_k() + size / 2.0).round()


## Position in this control -> world position.
func to_world(p: Vector2) -> Vector2:
	return (p - size / 2.0) / scale_k() + centre


## Picture pixel -> view pixel: pixel -> map cell (continuous) -> view cell (rotated) -> world -> here.
func picture_transform(pic: MapPicture) -> Transform2D:
	var t_map := Transform2D(Vector2.RIGHT, Vector2.DOWN, Vector2(pic.rect.position))
	var v0 := Vector2(IsoGrid.to_view(Vector2i.ZERO))
	var lx := Vector2(IsoGrid.to_view(Vector2i(1, 0))) - v0
	var ly := Vector2(IsoGrid.to_view(Vector2i(0, 1))) - v0
	var t_view := Transform2D(lx, ly, v0 + Vector2(0.5, 0.5) - (lx + ly) * 0.5)
	var hx := IsoGrid.HALF.x
	var hy := IsoGrid.HALF.y
	var t_world := Transform2D(Vector2(hx, hy), Vector2(-hx, hy), Vector2(hx, 0))
	var k := scale_k()
	var origin := (size / 2.0 - centre * k).round()
	var t_here := Transform2D(Vector2(k, 0), Vector2(0, k), origin)
	return t_here * t_world * t_view * t_map


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG)
	if map == null or map.map_picture == null:
		return
	var pic := map.map_picture
	draw_set_transform_matrix(picture_transform(pic))
	draw_texture(pic.get_texture(), Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var r := 1.0 if cell_px < 8.0 else 2.0       # dot "radius": 3x3 or 5x5 px with the outline
	for n in map.entities.get_children():
		if not n is MapMarker or not n.visible:
			continue
		var c: Vector2i = n.get_cell()
		if not map.is_explored(c):
			continue
		if n is Chest and not n.opened:
			_dot(IsoGrid.cell_to_world(c), COL_CHEST, r)
		elif n is Stairs:
			_diamond(IsoGrid.cell_to_world(c), COL_STAIRS, r + 1.0)
		elif n is Npc and n.is_shown():
			_dot(IsoGrid.cell_to_world(c), COL_NPC, r)
		elif n is Portal and n.is_shown():
			_diamond(IsoGrid.cell_to_world(c), COL_PORTAL, r + 1.0)
		elif n is Trap and n.blocks_party():
			_dot(IsoGrid.cell_to_world(c), COL_TRAP, maxf(0.0, r - 1.0))
	for m in map.monsters:
		if m.visible and m.is_alive():
			_dot(m.position, COL_MONSTER, r)
	for i in range(map.party.size() - 1, -1, -1):
		var h := map.party[i]
		var col: Color = COL_HERO[int(h.hero_class) % COL_HERO.size()] if h.is_alive() else COL_HERO_DOWN
		if i == 0 and blink_leader and fmod(_t, 1.0) > 0.75:
			col = Color.WHITE
		_dot(h.position, col, r)


func _dot(world: Vector2, col: Color, r: float) -> void:
	var p := to_view(world)
	draw_rect(Rect2(p - Vector2(r + 1, r + 1), Vector2(r * 2 + 3, r * 2 + 3)), COL_OUTLINE)
	draw_rect(Rect2(p - Vector2(r, r), Vector2(r * 2 + 1, r * 2 + 1)), col)


func _diamond(world: Vector2, col: Color, r: float) -> void:
	var p := to_view(world) + Vector2(0.5, 0.5)
	var o := r + 1.5
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -o), p + Vector2(o, 0), p + Vector2(0, o), p + Vector2(-o, 0)]), COL_OUTLINE)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), col)
