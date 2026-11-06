class_name MapScreen
extends Panel
## The full map (M, or a click on the minimap): everything explored on this floor, honouring the
## fog, turned like the game's view. Opens fitted to the explored area; mouse wheel / - + zoom,
## drag (left, right or middle button) pans, Space recentres on the party. M, Esc or a click
## outside closes it. Read-only, so it can be looked at in combat too.
## Lives on the CombatHud's root (inherits its theme).

const RECT := Rect2(12, 10, 616, 340)
const ZOOMS := [2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 16.0]
const LEGEND := [["Party", MapView.COL_HERO[0]], ["Enemy", MapView.COL_MONSTER],
		["Chest", MapView.COL_CHEST], ["Stairs", MapView.COL_STAIRS], ["Door", MapPicture.COL_DOOR],
		["Trader", MapView.COL_NPC], ["Portal", MapView.COL_PORTAL]]

var hud: CombatHud
var view: MapView
var _title: Label
var _zoom_i := 3
var _dragging := false


func _ready() -> void:
	position = RECT.position
	size = RECT.size
	add_theme_stylebox_override("panel", CombatHud._box_static(Color(CombatHud.COL_BG, 1.0), CombatHud.COL_EDGE))
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title = _label(Vector2(8, 4), CombatHud.COL_BANNER)
	var close_l := _label(Vector2(RECT.size.x - 74, 4), CombatHud.COL_DIM)
	close_l.text = "M / Esc: close"
	view = MapView.new()
	view.map = hud.combat.map
	view.position = Vector2(4, 18)
	view.size = Vector2(RECT.size.x - 8, RECT.size.y - 36)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	var x := 8.0
	var y := RECT.size.y - 14
	for entry: Array in LEGEND:
		var sw := ColorRect.new()
		sw.color = entry[1]
		sw.position = Vector2(x, y + 3)
		sw.size = Vector2(5, 5)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sw)
		var l := _label(Vector2(x + 8, y), CombatHud.COL_TEXT)
		l.text = entry[0]
		x += 8 + l.get_minimum_size().x + 10
	var help := _label(Vector2(RECT.size.x - 230, y), CombatHud.COL_DIM)
	help.text = "Wheel / - +: zoom   Drag: pan   Space: party"


func _label(pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	var m := hud.combat.map
	_title.text = (m.map_title if m.map_title != "" else "MAP").to_upper()
	_fit()
	visible = true
	Sfx.play("ui_select", -8.0)


func close() -> void:
	visible = false
	_dragging = false


## Zoom and centre so the whole explored area fits.
func _fit() -> void:
	var m := hud.combat.map
	var cells: Array = m.map_picture.explored_cells() if m.map_picture else []
	if cells.is_empty():
		_centre_on_party()
		return
	var b := Rect2(IsoGrid.cell_to_world(cells[0]), Vector2.ZERO)
	for c: Vector2i in cells:
		b = b.expand(IsoGrid.cell_to_world(c))
	b = b.grow_individual(IsoGrid.HALF.x, IsoGrid.HALF.y, IsoGrid.HALF.x, IsoGrid.HALF.y)
	_zoom_i = 0
	for i in ZOOMS.size():
		var k: float = ZOOMS[i] / float(IsoGrid.TILE_W)
		if b.size.x * k <= view.size.x - 8 and b.size.y * k <= view.size.y - 8:
			_zoom_i = i
	view.cell_px = ZOOMS[_zoom_i]
	view.centre = b.get_center()


func _centre_on_party() -> void:
	var m := hud.combat.map
	if not m.party.is_empty():
		view.centre = m.party[0].position


## Zoom by `step`, keeping the world point under `at` (view pixels) where it is.
func _zoom(step: int, at: Vector2) -> void:
	var i := clampi(_zoom_i + step, 0, ZOOMS.size() - 1)
	if i == _zoom_i:
		return
	var anchor := view.to_world(at)
	_zoom_i = i
	view.cell_px = ZOOMS[i]
	view.centre = anchor - (at - view.size / 2.0) / view.scale_k()


## Keys while open (CombatHud passes them on). True = used.
func handle_key(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_M, KEY_ESCAPE:
			close()
		KEY_SPACE, KEY_C:
			_centre_on_party()
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_zoom(1, view.size / 2.0)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_zoom(-1, view.size / 2.0)
		_:
			return false
	return true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var at := mb.position - view.position
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1, at)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(-1, at)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = mb.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		view.centre -= (event as InputEventMouseMotion).relative / view.scale_k()
		accept_event()
