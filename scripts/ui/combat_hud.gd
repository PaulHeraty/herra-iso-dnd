class_name CombatHud
extends CanvasLayer
## TEMPORARY combat HUD (Phase 2 step 3): "X'S TURN" banner top-left and the last few log lines
## top-right, in Godot's default font. Step 7 replaces it with the mock-up's UI and our own
## pixel font.

const LOG_ENTRIES := 8          ## log entries kept
const LOG_VISIBLE := 12         ## wrapped lines shown (newest at the bottom)
const LOG_W := 250
const SCREEN_W := 640
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
	_wrap(_hint, SCREEN_W - LOG_W - 30)
	_log = _label(Vector2(SCREEN_W - LOG_W - 6, 6), HINT_COL, 8)
	_wrap(_log, LOG_W)
	_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_log.max_lines_visible = LOG_VISIBLE
	combat.log_line.connect(_on_log)
	combat.turn_started.connect(_on_turn)
	combat.status_changed.connect(func(t: String): _hint.text = t)
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


## Fixed width, wrap long lines inside it (nothing runs off the screen).
func _wrap(l: Label, width: float) -> void:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.size = Vector2(width, 0)


func _on_turn(a: Actor) -> void:
	_banner.text = "%s'S TURN" % a.display_name().to_upper()


func _on_log(text: String) -> void:
	_lines.append(text)
	while _lines.size() > LOG_ENTRIES:
		_lines.remove_at(0)
	_log.text = "\n".join(_lines)
	# Show the newest wrapped lines.
	_log.lines_skipped = maxi(0, _log.get_line_count() - LOG_VISIBLE)
