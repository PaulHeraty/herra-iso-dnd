@tool
class_name Portal
extends MapMarker
## A Rune of Return portal (RunePortal): a swirling oval of blue light with its own light.
## The `home` one is placed in the editor outside Brannoc's stall and shows only while a portal is
## open; the far end is made at runtime where the rune was used (DungeonMap.use_rune). Walk onto
## it (click it) to step through (DungeonMap.take_portal). Doesn't block movement or sight.

const SHEET := preload("res://assets/sprites/props/portal_sheet.png")
const FRAMES := 8
const FPS := 10.0
const OFFSET := Vector2(-12, -38)
const FRAME_SIZE := Vector2(24, 40)
const LIGHT_COLOR := Color(0.45, 0.62, 1.0)

## The end outside Brannoc's stall (surface): shown only while RunePortal.active.
@export var home := false
## Hover text, e.g. "back to the Upper Halls" (set by DungeonMap).
var where := ""

var _t := 0.0
var _frame := 0
var _light: PointLight2D
var _open := 1.0


func _init() -> void:
	gizmo_color = Color(0.45, 0.62, 1.0)


func _ready() -> void:
	super()
	gizmo_label = "PORTAL" + (" (home)" if home else "")
	if Engine.is_editor_hint():
		return
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED       # it glows by itself
	material = unshaded
	_light = PointLight2D.new()
	_light.name = "Light"
	_light.position = Vector2(0, -16)
	_light.color = LIGHT_COLOR
	_light.energy = 1.1
	_light.texture = _light_texture()
	add_child(_light)


static var _light_tex: Texture2D

static func _light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0, 0.25, 0.5, 0.75, 1])
		g.colors = PackedColorArray([Color(1, 1, 1), Color(0.63, 0.63, 0.63), Color(0.33, 0.33, 0.33),
				Color(0.11, 0.11, 0.11), Color(0, 0, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 180
		t.height = 112
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1, 0.5)
		_light_tex = t
	return _light_tex


func is_shown() -> bool:
	return not home or RunePortal.active


func hint() -> String:
	return "A portal %s (click to step through)" % where


## Grow out of a line of light (when the rune opens it).
func open_fx() -> void:
	_open = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_open", 1.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	_frame = int(_t * FPS) % FRAMES
	if _light:
		_light.energy = (1.0 + 0.12 * sin(_t * 5.0) + 0.06 * sin(_t * 13.0)) * _open
	queue_redraw()


func _draw() -> void:
	# a pool of blue light on the floor under it
	draw_set_transform(Vector2(0, 0), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 12 * _open, Color(0.35, 0.5, 1.0, 0.25))
	draw_circle(Vector2.ZERO, 7 * _open, Color(0.55, 0.7, 1.0, 0.3))
	draw_set_transform(Vector2(0, 0), 0, Vector2(maxf(0.05, _open), 1.0))
	draw_texture_rect_region(SHEET, Rect2(OFFSET, FRAME_SIZE), Rect2(_frame * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y))
	draw_set_transform(Vector2.ZERO)
	if Engine.is_editor_hint():
		_draw_gizmo()
