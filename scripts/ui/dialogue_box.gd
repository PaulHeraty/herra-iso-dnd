class_name DialogueBox
extends Panel

signal closed
## Talking to an NPC (TraderTalk): portrait, name, the line (typed out letter by letter) and up to
## four choices. Keys: 1-4 pick a choice; Space / Enter finish the typing, then pick the only
## choice; Esc picks the "goodbye" choice when there is one. The map can't be clicked meanwhile.
## Lives on the CombatHud's root (inherits its theme).

const RECT := Rect2(70, 216, 500, 80)
const TYPE_SPEED := 70.0            ## letters per second

var _pic: TextureRect
var _name: Label
var _text: RichTextLabel
var _buttons: Array[Button] = []
var _choices: Array = []
var _typing: Tween


func _ready() -> void:
	position = RECT.position
	size = RECT.size
	add_theme_stylebox_override("panel", CombatHud._box_static(CombatHud.COL_BG, CombatHud.COL_GOLD.darkened(0.35)))
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var frame := Panel.new()
	frame.position = Vector2(6, 6)
	frame.size = Vector2(36, 36)
	frame.add_theme_stylebox_override("panel", CombatHud._box_static(Color8(16, 14, 20), CombatHud.COL_EDGE))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_pic = TextureRect.new()
	_pic.position = Vector2(2, 2)
	_pic.size = Vector2(32, 32)
	_pic.stretch_mode = TextureRect.STRETCH_SCALE
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_pic)
	_name = Label.new()
	_name.position = Vector2(50, 5)
	_name.add_theme_color_override("font_color", CombatHud.COL_BANNER)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.position = Vector2(50, 17)
	_text.size = Vector2(RECT.size.x - 58, 46)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_color_override("default_color", CombatHud.COL_TEXT)
	add_child(_text)
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and typing():
			_finish_typing())


## Show a line. choices: [{text, call (Callable), bye (optional: Esc picks it)}].
func say(speaker: String, portrait: Texture2D, text: String, choices: Array) -> void:
	_name.text = speaker
	_pic.texture = portrait
	_text.text = text
	_text.visible_characters = 0
	# long texts (lore, clues): the box grows upwards to fit them; its bottom stays put
	var th := CombatHud.FONT.get_multiline_string_size(_text.get_parsed_text(), HORIZONTAL_ALIGNMENT_LEFT, RECT.size.x - 58, 10).y
	var h := maxf(RECT.size.y, 17.0 + th + 26.0)
	size = Vector2(RECT.size.x, h)
	position = Vector2(RECT.position.x, RECT.end.y - h)
	_text.size = Vector2(RECT.size.x - 58, h - 34)
	_choices = choices
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	var x := 50.0
	for i in choices.size():
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, choices[i].text]
		b.focus_mode = Control.FOCUS_NONE
		var w := CombatHud.FONT.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12
		b.position = Vector2(x, size.y - 17)
		add_child(b)
		b.set_deferred("size", Vector2(w, 13))
		b.pressed.connect(pick.bind(i))
		_buttons.append(b)
		x += w + 5
	visible = true
	if _typing:
		_typing.kill()
	var n := _text.get_total_character_count()
	_typing = create_tween()
	_typing.tween_property(_text, "visible_characters", n, n / TYPE_SPEED)


func typing() -> bool:
	return _typing != null and _typing.is_running()


func _finish_typing() -> void:
	if _typing:
		_typing.kill()
	_text.visible_characters = -1


func close() -> void:
	if _typing:
		_typing.kill()
	if visible:
		visible = false
		closed.emit()


## Pick choice i (its callable decides what comes next: another line, or close()).
func pick(i: int) -> void:
	if i < 0 or i >= _choices.size():
		return
	Sfx.play("ui_select", -8.0)
	var c: Callable = _choices[i].call
	c.call()


## The current line's text (tests).
func current_text() -> String:
	return _text.get_parsed_text()


## Choice labels (tests).
func choice_texts() -> Array[String]:
	var out: Array[String] = []
	for c in _choices:
		out.append(c.text)
	return out


## Keys while open. True = used.
func handle_key(e: InputEventKey) -> bool:
	if not visible or not e.pressed or e.echo:
		return false
	if e.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		if typing():
			_finish_typing()
		elif _choices.size() == 1:
			pick(0)
		return true
	if e.keycode >= KEY_1 and e.keycode <= KEY_4:
		if typing():
			_finish_typing()
		pick(e.keycode - KEY_1)
		return true
	if e.keycode == KEY_ESCAPE:
		for i in _choices.size():
			if _choices[i].get("bye", false):
				pick(i)
				break
		return true
	return true                 # everything else waits while someone is talking
