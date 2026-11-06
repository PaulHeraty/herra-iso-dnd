class_name MiniMap
extends Panel
## The minimap in the top-left corner: the explored map around the leader (MapView), turned like
## the game's view, with - / + buttons to zoom. A click on it opens the full map (M).
## Lives on the CombatHud's root (inherits its theme).

const RECT := Rect2(4, 4, 132, 84)
## Width of one cell's diamond, per zoom step.
const ZOOMS := [2.0, 4.0, 6.0, 8.0, 12.0]

## Kept between maps and loads.
static var zoom_i := 2

var hud: CombatHud
var view: MapView
var _minus: Button
var _plus: Button


func _ready() -> void:
	position = RECT.position
	size = RECT.size
	add_theme_stylebox_override("panel", CombatHud._box_static(CombatHud.COL_BG, CombatHud.COL_EDGE))
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = ""
	view = MapView.new()
	view.map = hud.combat.map
	view.blink_leader = true
	view.position = Vector2(2, 2)
	view.size = RECT.size - Vector2(4, 4)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	_minus = _button("-", Vector2(RECT.size.x - 29, RECT.size.y - 15), -1)
	_plus = _button("+", Vector2(RECT.size.x - 15, RECT.size.y - 15), 1)
	_apply_zoom()


func _process(_delta: float) -> void:
	var m := hud.combat.map
	if not m.party.is_empty():
		view.centre = m.party[0].position


func _button(text: String, pos: Vector2, step: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.set_deferred("size", Vector2(13, 13))      # after the theme's minimum size is applied
	b.pressed.connect(func():
		zoom_i = clampi(zoom_i + step, 0, ZOOMS.size() - 1)
		_apply_zoom()
		Sfx.play("ui_select", -10.0))
	add_child(b)
	return b


func _apply_zoom() -> void:
	view.cell_px = ZOOMS[zoom_i]
	_minus.disabled = zoom_i == 0
	_plus.disabled = zoom_i == ZOOMS.size() - 1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_i = clampi(zoom_i + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1), 0, ZOOMS.size() - 1)
			_apply_zoom()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			hud.open_map()
		accept_event()


func is_mouse_over() -> bool:
	return visible and get_global_rect().has_point(get_global_mouse_position())
