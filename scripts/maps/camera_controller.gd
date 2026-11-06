class_name CameraController
extends Node
## Drives the map's Camera2D: follows a target (the party leader), can be panned with WASD/arrows
## or by dragging with the middle mouse button, zooms 1x/2x/3x with the mouse wheel, and keeps the
## map in view (a map smaller than the screen is centred). Created by DungeonMap at runtime.

const FOLLOW_RATE := 8.0      ## higher = catches up faster
const PAN_SPEED := 240.0      ## px/s at 1x zoom
const ZOOM_LEVELS := [1, 2, 3]
const MARGIN := 24.0          ## px of dark border allowed around the map edges

var camera: Camera2D
var target: Node2D
## World-space rectangle that should stay on screen (map floor + walls).
var bounds := Rect2()
## False while the player is panning; set true again by recenter() (e.g. on a move order).
var following := true
## Screen pixels covered by UI at the bottom (combat panel): the camera keeps its target centred
## in the area above it and clamps to the map within that area.
var ui_bottom := 0.0
## ui_bottom as shown (eases toward ui_bottom, e.g. when the dialogue box opens).
var _ui_cur := -1.0

var _zoom_i := 0
var _dragging := false
var _shake_t := 0.0
var _shake_px := 0.0


func _ready() -> void:
	_ensure_actions()
	camera.zoom = Vector2.ONE * ZOOM_LEVELS[_zoom_i]
	if target:
		camera.position = _clamped(target.position)


## Shake the view for `duration` seconds, `px` screen pixels at the start (Fireball).
func shake(px: float, duration := 0.4) -> void:
	_shake_px = px
	_shake_t = duration


## Put the camera straight onto a point (e.g. after the view turns).
func jump_to(p: Vector2) -> void:
	camera.position = _clamped(p)
	camera.reset_smoothing()


## Snap back to following the target (smoothly).
func recenter() -> void:
	following = true


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("cam_recenter"):
		recenter()
	var pan := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if pan != Vector2.ZERO:
		following = false
		camera.position += pan * PAN_SPEED * delta / camera.zoom.x
	elif following and target:
		camera.position = camera.position.lerp(target.position, 1.0 - exp(-FOLLOW_RATE * delta))
	camera.position = _clamped(camera.position)
	if _ui_cur < 0.0:
		_ui_cur = ui_bottom
	_ui_cur = lerpf(_ui_cur, ui_bottom, 1.0 - exp(-8.0 * delta)) if absf(_ui_cur - ui_bottom) > 0.5 else ui_bottom
	camera.offset = Vector2(0, _ui_cur * 0.5 / camera.zoom.x)
	if _shake_t > 0.0:
		_shake_t -= delta
		var amt := _shake_px * clampf(_shake_t / 0.4, 0.0, 1.0)
		camera.offset += Vector2(randf_range(-amt, amt), randf_range(-amt, amt)).round()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom_i + 1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom_i - 1)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
			if _dragging:
				following = false
	elif event is InputEventMouseMotion and _dragging:
		camera.position -= (event as InputEventMouseMotion).relative / camera.zoom.x
		camera.position = _clamped(camera.position)


func _set_zoom(i: int) -> void:
	i = clampi(i, 0, ZOOM_LEVELS.size() - 1)
	if i == _zoom_i:
		return
	_zoom_i = i
	camera.zoom = Vector2.ONE * ZOOM_LEVELS[i]
	camera.position = _clamped(camera.position)


## Keep `p` (camera centre) such that the view stays over the map; centre the map on an axis
## where it is smaller than the view.
func _clamped(p: Vector2) -> Vector2:
	if not bounds.has_area():
		return p
	var view := (camera.get_viewport_rect().size - Vector2(0, ui_bottom)) / camera.zoom
	var b := bounds.grow(MARGIN)
	var out := p
	for axis in 2:
		if b.size[axis] <= view[axis]:
			out[axis] = b.get_center()[axis]
		else:
			out[axis] = clampf(p[axis], b.position[axis] + view[axis] / 2.0, b.end[axis] - view[axis] / 2.0)
	return out


static func _ensure_actions() -> void:
	var keys := {
		cam_left = [KEY_A, KEY_LEFT], cam_right = [KEY_D, KEY_RIGHT],
		cam_up = [KEY_W, KEY_UP], cam_down = [KEY_S, KEY_DOWN], cam_recenter = [KEY_SPACE],
		view_rotate_left = [KEY_Q], view_rotate_right = [KEY_E],
	}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k: Key in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
