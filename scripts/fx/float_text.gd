class_name FloatText
extends Node2D
## A floating combat number/word ("12", "MISS", "CRIT 18") that rises and fades, drawn above
## everything and not darkened by the ambient light. Font: Godot default for now (pixel font in
## Phase 2 step 7).

const RISE := 14.0
const LIFE := 0.9

var text := ""
var color := Color.WHITE
var size := 10
var _t := 0.0


static func spawn(parent: Node, at: Vector2, txt: String, col: Color, font_size := 10) -> FloatText:
	var f := FloatText.new()
	f.text = txt
	f.color = col
	f.size = font_size
	f.position = at
	f.z_index = 50
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	f.material = mat
	parent.add_child(f)
	return f


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var k := _t / LIFE
	var y := -RISE * (1.0 - pow(1.0 - k, 2.0))       # ease out
	var a := 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(-w / 2.0, y).round()
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, p + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.08, 0.06, 0.1, a))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, a))
