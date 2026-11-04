class_name CombatHud
extends CanvasLayer
## TEMPORARY combat HUD (Phase 2 step 3): "X'S TURN" banner top-left and the last few log lines
## top-right, in Godot's default font. Step 7 replaces it with the mock-up's UI and our own
## pixel font.

const LOG_LINES := 6
const BANNER_COL := Color8(255, 220, 120)
const HINT_COL := Color8(200, 196, 210)

var combat: CombatManager
var _banner: Label
var _hint: Label
var _log: Label
var _lines: PackedStringArray = []


func _ready() -> void:
	layer = 10
	_banner = _label(Vector2(10, 6), BANNER_COL, 12)
	_hint = _label(Vector2(10, 22), HINT_COL, 8)
	_log = _label(Vector2(380, 6), HINT_COL, 8)
	_log.size = Vector2(250, 120)
	_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combat.log_line.connect(_on_log)
	combat.turn_started.connect(_on_turn)
	combat.combat_ended.connect(func(): visible = false)
	combat.combat_started.connect(func(): visible = true)
	visible = false


func _label(pos: Vector2, col: Color, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l


func _on_turn(a: Actor) -> void:
	_banner.text = "%s'S TURN" % a.display_name().to_upper()
	_hint.text = "Enter = end turn" if a is Hero else ""


func _on_log(text: String) -> void:
	_lines.append(text)
	while _lines.size() > LOG_LINES:
		_lines.remove_at(0)
	_log.text = "\n".join(_lines)
