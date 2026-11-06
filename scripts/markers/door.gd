@tool
class_name Door
extends MapMarker
## A door standing in a doorway cell of a wall run. Paint the doorway cell with the dark floor
## tile (no wall), then drop a Door on it. Drawn in code (wood + iron bands).
## At runtime: click it to walk up and open it (PartyController / CombatManager). Locked doors
## are picked by the Rogue (thieves' tools, DEX vs lock_dc) or forced by the strongest hero
## (Athletics vs lock_dc + 2); a door with key_id and lock_dc 0 needs that key (Phase 4).
## Styles (Phase 6):
##   PORTCULLIS  iron bars: you see through them; only its mechanism raises it (a lever, a plate or
##               a puzzle whose output is `link`; Mechanisms). Drops again when a plate is let go.
##   SECRET      looks like the wall around it (it draws a wall block) until a hero finds it
##               (passive Perception vs secret_dc, or Search); then it is a stone door you open by
##               hand, or its `link` opens it.

signal opened

## Which wall run the doorway is in: BACK_RIGHT = a wall row along +x (its face points down-left),
## BACK_LEFT = a wall column along +y (its face points down-right).
enum WallRun { BACK_RIGHT, BACK_LEFT }
enum Style { WOOD, PORTCULLIS, SECRET }

@export var wall_run := WallRun.BACK_RIGHT:
	set(v):
		wall_run = v
		queue_redraw()
@export var is_open := false:
	set(v):
		is_open = v
		_lift = 1.0 if v else 0.0         # open() / close() animate it from where it was
		queue_redraw()
@export var locked := false:
	set(v):
		locked = v
		queue_redraw()
@export var lock_dc := 15
@export var key_id := ""
@export var style := Style.WOOD:
	set(v):
		style = v
		queue_redraw()
## Opened by the lever / plate / puzzle with this link (Mechanisms.fire).
@export var link := ""
## SECRET: Perception to notice it.
@export var secret_dc := 14

## Runtime: the wall run as seen in the rotated view (-1 = same as wall_run).
var view_run := -1
## SECRET: found by the party (then it shows as a stone door).
var found := false:
	set(v):
		found = v
		queue_redraw()
## SECRET: the wall block to draw while it is closed (DungeonMap sets it for the current view):
## atlas column, row (which faces show).
var wall_tile := Vector2i(0, 0)
## PORTCULLIS: 0 = down, 1 = raised (animated).
var _lift := 0.0
var _t := 0.0

const HEIGHT := 30
const WOOD := Color8(104, 62, 30)
const WOOD_DARK := Color8(70, 44, 26)
const IRON := Color8(40, 30, 26)
const OUTLINE := Color8(20, 16, 24)
const LOCK := Color8(150, 150, 160)
const BAR := Color8(70, 66, 72)
const BAR_LIT := Color8(124, 118, 122)
const SEAM := Color8(255, 214, 120)
const WALL_TEX := preload("res://assets/tiles/wall_atlas.png")


func _init() -> void:
	gizmo_color = Color(0.85, 0.6, 0.35)
	gizmo_label = "DOOR"


func _ready() -> void:
	super()
	if style == Style.PORTCULLIS:
		gizmo_label = "GATE"
	elif style == Style.SECRET:
		gizmo_label = "SECRET"
	set_process(style == Style.SECRET and not Engine.is_editor_hint())


func apply_view() -> void:
	super()
	var v := IsoGrid.rotate_dir(axis())
	view_run = WallRun.BACK_RIGHT if v.y == 0 else WallRun.BACK_LEFT
	queue_redraw()


## Map direction the wall run goes along.
func axis() -> Vector2i:
	return Vector2i(1, 0) if wall_run == WallRun.BACK_RIGHT else Vector2i(0, 1)


## The two cells you open the door from (either side of the wall run).
func sides() -> Array[Vector2i]:
	var n := Vector2i(axis().y, axis().x)
	return [get_cell() + n, get_cell() - n]


func blocks_move() -> bool:
	return not is_open


## Closed wooden and secret doors block sight; a portcullis doesn't (bars).
func blocks_sight() -> bool:
	return not is_open and style != Style.PORTCULLIS


## A secret door nobody has found yet: it is just wall (can't be clicked, drawn as a block).
func is_hidden() -> bool:
	return style == Style.SECRET and not found and not is_open


## Can a hero open it by hand? (Not a portcullis, not an unfound secret door.)
func by_hand() -> bool:
	return style == Style.WOOD or (style == Style.SECRET and found)


## Swing it open (no checks: the caller handles locks).
func open() -> void:
	if is_open:
		return
	var from := _lift
	is_open = true
	locked = false
	_lift = from
	if style == Style.SECRET:
		found = true
		Sfx.play("stone_slide")
	elif style == Style.PORTCULLIS:
		Sfx.play("gate_rise")
		_animate_lift(1.0)
	else:
		Sfx.play("door_open")
	opened.emit()


## Drop a portcullis again (a plate let go). Doesn't check who stands in it (Mechanisms does).
func close() -> void:
	if not is_open:
		return
	var from := _lift
	is_open = false
	_lift = from
	if style == Style.PORTCULLIS:
		Sfx.play("gate_rise", -2.0, 0.8)
		_animate_lift(0.0)
	opened.emit()


func _animate_lift(to: float) -> void:
	if not is_inside_tree():
		_lift = to
		return
	var tw := create_tween()
	tw.tween_method(func(v: float):
		_lift = v
		queue_redraw(), _lift, to, 0.7 if to > _lift else 0.25)


## Screen box of the closed panel around the node (for clicks on the door itself, which stands
## taller than its cell).
func panel_rect() -> Rect2:
	if style == Style.SECRET:
		return Rect2(position + Vector2(-16, -48), Vector2(32, 56))
	return Rect2(position + Vector2(-16, -HEIGHT - 1), Vector2(32, HEIGHT + 9))


func hint(map: DungeonMap) -> String:
	if style == Style.PORTCULLIS:
		return "A heavy portcullis. It won't lift by hand: there must be a mechanism."
	if locked:
		return map.lock_hint(self, "Door")
	if style == Style.SECRET:
		return "A secret door: click to open it."
	return ""


func save_state() -> Variant:
	return {f = true} if found else null


func load_state(s: Variant) -> void:
	if s is Dictionary:
		found = s.get("f", false)


func _process(delta: float) -> void:
	if found and not is_open:
		_t += delta
		queue_redraw()             # the found seam glints


func _run() -> int:
	return wall_run if view_run < 0 else view_run


func _draw() -> void:
	super()
	match style:
		Style.PORTCULLIS:
			_draw_portcullis()
		Style.SECRET:
			_draw_secret()
		_:
			_draw_wood()


## The bars: an iron grid in the doorway's plane. Raised, only the spiked foot shows at the top.
func _draw_portcullis() -> void:
	var run := _run()
	var a := Vector2(-15, 0.5) if run == WallRun.BACK_RIGHT else Vector2(1, 7.5)
	var b := Vector2(-1, 7.5) if run == WallRun.BACK_RIGHT else Vector2(15, 0.5)
	var up := Vector2(0, -HEIGHT)
	var lift := Vector2(0, -roundf(_lift * (HEIGHT - 5)))
	# keep the raised part out of sight above the doorway: clip to the doorway height
	for i in 6:                                              # upright bars
		var p: Vector2 = a.lerp(b, (i + 0.5) / 6.0) + lift
		var top := maxf(p.y - HEIGHT, a.y + up.y - 2) if _lift > 0 else p.y - HEIGHT
		var col := BAR_LIT if i % 2 == 0 else BAR
		draw_line(Vector2(p.x, p.y - 1), Vector2(p.x, top), OUTLINE, 3.0)
		draw_line(Vector2(p.x, p.y - 1), Vector2(p.x, top), col, 1.0)
		draw_rect(Rect2(Vector2(p.x, p.y), Vector2(1, 1)).abs(), BAR_LIT)   # spiked foot
	for h in [0.3, 0.7]:                                     # cross bars
		var y: float = -HEIGHT * h
		var p0 := a + Vector2(0, y) + lift
		var p1 := b + Vector2(0, y) + lift
		if _lift > 0 and minf(p0.y, p1.y) < a.y + up.y - 2:
			continue
		draw_line(p0, p1, OUTLINE, 3.0)
		draw_line(p0, p1, BAR, 1.0)


## Hidden: a wall block like its neighbours. Found and closed: the block with a glinting door seam.
## Open: nothing (the dark doorway floor shows).
func _draw_secret() -> void:
	if is_open:
		return
	if Engine.is_editor_hint():
		_draw_wood()
		return
	draw_texture_rect_region(WALL_TEX, Rect2(-16, -48, 32, 56), Rect2(wall_tile.x * 32, wall_tile.y * 56, 32, 56))
	if not found:
		return
	# the outline of a door cut into the face the room sees
	var run := _run()
	var a := Vector2(-13, 1.5) if run == WallRun.BACK_RIGHT else Vector2(3, 6.5)
	var b := Vector2(-3, 6.5) if run == WallRun.BACK_RIGHT else Vector2(13, 1.5)
	var up := Vector2(0, -HEIGHT + 4)
	var glint := 0.55 + 0.35 * sin(_t * TAU / 1.6)
	var col := Color(SEAM, glint)
	draw_polyline(PackedVector2Array([a, a + up, b + up, b]), col, 1.0)


func _draw_wood() -> void:
	var run := _run()
	var up := Vector2(0, -HEIGHT)
	var a: Vector2
	var b: Vector2
	if is_open:
		# Swung in against the left jamb of the doorway, seen almost edge-on.
		if run == WallRun.BACK_RIGHT:
			a = Vector2(-15, 0.5)
			b = Vector2(-4, -5)
		else:
			a = Vector2(1, -7.5)
			b = Vector2(12, -2)
		var slab := PackedVector2Array([a, b, b + up, a + up])
		draw_colored_polygon(slab, WOOD_DARK)
		draw_line(a.lerp(b, 0.5), a.lerp(b, 0.5) + up, OUTLINE, 1.0)
		for h in [0.25, 0.75]:
			draw_line(a + up * h, b + up * h, IRON, 1.0)
		slab.append(slab[0])
		draw_polyline(slab, OUTLINE, 1.0)
		return
	# The door panel stands on the cell's lower-left (BACK_RIGHT) or lower-right (BACK_LEFT) edge.
	a = Vector2(-15, 0.5) if run == WallRun.BACK_RIGHT else Vector2(1, 7.5)
	b = Vector2(-1, 7.5) if run == WallRun.BACK_RIGHT else Vector2(15, 0.5)
	var panel := PackedVector2Array([a, b, b + up, a + up])
	draw_colored_polygon(panel, WOOD if run == WallRun.BACK_RIGHT else WOOD_DARK)
	for t in [0.25, 0.5, 0.75]:                                  # plank seams
		var p: Vector2 = a.lerp(b, t)
		draw_line(p, p + up, WOOD_DARK if run == WallRun.BACK_RIGHT else OUTLINE, 1.0)
	for h in [0.25, 0.75]:                                       # iron bands
		draw_line(a + up * h, b + up * h, IRON, 2.0)
	var knob := a.lerp(b, 0.8) + up * 0.45
	draw_rect(Rect2(knob.floor(), Vector2(1, 1)), Color8(230, 190, 70))
	if locked:                                                   # iron lock plate under the knob
		var lp := (a.lerp(b, 0.8) + up * 0.38).floor()
		draw_rect(Rect2(lp + Vector2(-1, 0), Vector2(3, 4)), OUTLINE)
		draw_rect(Rect2(lp + Vector2(0, 1), Vector2(1, 2)), LOCK)
	panel.append(panel[0])
	draw_polyline(panel, OUTLINE, 1.0)
