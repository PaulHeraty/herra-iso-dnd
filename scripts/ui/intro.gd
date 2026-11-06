extends Control
## The game's opening (scenes/intro.tscn, the main scene):
##   1. Herrasoft splash: the name letter by letter in the fire palette, a shine sweeping across,
##      "presents", a chime.
##   2. Title: "HerraDnD" between two burning torches (the wall-torch flame, 4x, with a warm glow).
##   3. The story so far: a text box typed out page by page, the four heroes standing above it.
##   4. Fade to black, then the Harrow Woods (surface.tscn) fade in from black with their title.
## Click / Space / Enter: skip ahead (finish the typing, next page). Esc: straight into the game.

const GAME_SCENE := "res://scenes/maps/surface.tscn"
const SCREEN := CombatHud.SCREEN
const FONT := CombatHud.FONT
const FIRE := [Color8(200, 50, 20), Color8(255, 130, 30), Color8(255, 210, 80), Color8(255, 250, 200)]
const BG := Color8(10, 8, 14)
const PAGES := [
	"You and your three oldest friends grew up together in a quiet village on the edge of the Harrow Woods. A fighter, a rogue, a cleric and a mage, and one shared dream: adventure.",
	"One spring morning you packed your gear, said your goodbyes and took the forest road, in search of gold, glory and a story worth telling.",
	"After a night camped beneath the old pines, you wake to birdsong and the smell of cold ashes. The woods are waiting. Time to see what adventure awaits...",
]
const HEROES := ["fighter", "rogue", "cleric", "mage"]
const TYPE_SPEED := 45.0             ## letters per second
const BOX := Rect2(110, 206, 420, 62)

enum Stage { LOGO, TITLE, STORY, LEAVING }

var _stage := Stage.LOGO
var _layer: Control               ## everything of the current stage (faded / freed as one)
var _tween: Tween
var _shine := -1.0                ## logo shine position (letters), animated
var _letters: Array[Label] = []
var _page := 0
var _text: Label
var _more: Label
var _typing: Tween
var _flames: Array[TextureRect] = []
var _flame_t := 0.0
var _black: ColorRect


func _ready() -> void:
	size = SCREEN
	theme = CombatHud.make_theme()
	var bg := ColorRect.new()
	bg.size = SCREEN
	bg.color = BG
	add_child(bg)
	_black = ColorRect.new()                 # the fade curtain, on top of everything
	_black.size = SCREEN
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_logo()


func _process(delta: float) -> void:
	_flame_t += delta
	for i in _flames.size():
		var f := _flames[i]
		if is_instance_valid(f):
			(f.texture as AtlasTexture).region.position.x = 8 * (int(_flame_t * 8.0 + i * 3) % 8)
	if _stage == Stage.LOGO and not _letters.is_empty():
		for i in _letters.size():
			var base: Color = FIRE[1].lerp(FIRE[2], float(i) / (_letters.size() - 1))
			var glow := clampf(1.0 - absf(i - _shine) / 1.6, 0.0, 1.0)
			_letters[i].add_theme_color_override("font_color", base.lerp(FIRE[3], glow))
	if _more and is_instance_valid(_more):
		_more.visible = not _is_typing() and int(_flame_t * 2.0) % 2 == 0


func _input(event: InputEvent) -> void:
	var go := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		go = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_start_game()
			get_viewport().set_input_as_handled()
			return
		go = event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	if go:
		_advance()
		get_viewport().set_input_as_handled()


## Skip ahead one step.
func _advance() -> void:
	match _stage:
		Stage.LOGO:
			_title()
		Stage.TITLE:
			_story()
		Stage.STORY:
			if _is_typing():
				_typing.kill()
				_text.visible_ratio = 1.0
			else:
				_next_page()


func _new_layer() -> Control:
	if _tween:
		_tween.kill()
	if _layer:
		_layer.queue_free()
	_flames.clear()
	_letters.clear()
	_layer = Control.new()
	_layer.size = SCREEN
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	move_child(_layer, _black.get_index())       # under the curtain
	return _layer


# --- 1. Herrasoft --------------------------------------------------------------------------------

func _logo() -> void:
	_stage = Stage.LOGO
	var l := _new_layer()
	const NAME := "HERRASOFT"
	const K := 4
	var w := FONT.get_string_size(NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x * K
	var x := roundf((SCREEN.x - w) / 2.0)
	for c in NAME:
		var lab := _label(l, Vector2(x, 140), FIRE[1])
		lab.text = c
		lab.scale = Vector2(K, K)
		_letters.append(lab)
		x += FONT.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x * K
	var rule := ColorRect.new()
	rule.color = FIRE[0]
	rule.position = Vector2(roundf((SCREEN.x - w) / 2.0), 180)
	rule.size = Vector2(w, 1)
	l.add_child(rule)
	var flame := _flame(l, Vector2(SCREEN.x / 2.0, 132), 3)
	flame.modulate.a = 1.0
	var pres := _label(l, Vector2.ZERO, CombatHud.COL_DIM)
	_centre(pres, "presents", 188, 1)
	l.modulate.a = 0.0
	_shine = -3.0
	_tween = create_tween()
	_tween.tween_interval(0.4)
	_tween.tween_callback(Sfx.play.bind("logo_chime"))
	_tween.tween_property(l, "modulate:a", 1.0, 0.9)
	_tween.parallel().tween_property(self, "_shine", NAME.length() + 3.0, 1.3).set_delay(0.3)
	_tween.tween_interval(1.6)
	_tween.tween_property(l, "modulate:a", 0.0, 0.7)
	_tween.tween_callback(_title)


# --- 2. HerraDnD ---------------------------------------------------------------------------------

func _title() -> void:
	_stage = Stage.TITLE
	var l := _new_layer()
	var t := _label(l, Vector2.ZERO, CombatHud.COL_BANNER)
	_centre(t, "HerraDnD", 128, 5)
	t.add_theme_color_override("font_shadow_color", Color8(110, 20, 10))
	var tw := FONT.get_string_size("HerraDnD", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x * 5
	for side in [-1, 1]:
		_flame(l, Vector2(SCREEN.x / 2.0 + side * (tw / 2.0 + 34), 166), 4)
	var sub := _label(l, Vector2.ZERO, CombatHud.COL_TEXT)
	_centre(sub, "The Wraith Below", 186, 2)
	var by := _label(l, Vector2.ZERO, CombatHud.COL_DIM)
	_centre(by, "A Herrasoft game", 214, 1)
	var hint := _label(l, Vector2.ZERO, Color8(84, 80, 96))
	_centre(hint, "Click or Space to begin", 330, 1)
	l.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(l, "modulate:a", 1.0, 1.0)
	_tween.tween_interval(3.5)
	_tween.tween_property(l, "modulate:a", 0.0, 0.8)
	_tween.tween_callback(_story)


# --- 3. The story so far -------------------------------------------------------------------------

func _story() -> void:
	_stage = Stage.STORY
	var l := _new_layer()
	# The party: four heroes, front idle frame of their walk sheets, 3x.
	const K := 3
	var gap := 64
	var x0 := SCREEN.x / 2.0 - gap * 1.5 - 8 * K
	for i in HEROES.size():
		var tex: Texture2D = load("res://assets/sprites/heroes/%s_sheet.png" % HEROES[i])
		var pic := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, 0, 16, 24)
		pic.texture = at
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.size = Vector2(16 * K, 24 * K)
		pic.position = Vector2(roundf(x0 + i * gap), BOX.position.y - 24 * K - 14)
		pic.flip_h = i >= 2                      # the two on the right face the others
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_child(pic)
		var shadow := ColorRect.new()          # a flat dark oval-ish strip under their feet
		shadow.color = Color(0, 0, 0, 0.45)
		shadow.position = pic.position + Vector2(3 * K, 24 * K - 2)
		shadow.size = Vector2(10 * K, 3)
		l.add_child(shadow)
		l.move_child(shadow, pic.get_index())
	var box := Panel.new()
	box.position = BOX.position
	box.size = BOX.size
	box.add_theme_stylebox_override("panel", CombatHud._box_static(CombatHud.COL_BG, CombatHud.COL_GOLD.darkened(0.35)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_child(box)
	_text = _label(box, Vector2(12, 9), CombatHud.COL_TEXT)
	_text.size = Vector2(BOX.size.x - 24, 0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_more = _label(box, Vector2(BOX.size.x - 16, BOX.size.y - 14), CombatHud.COL_ACTIVE)
	_more.text = ">"
	var skip := _label(l, Vector2.ZERO, Color8(84, 80, 96))
	_centre(skip, "Click / Space: continue     Esc: skip", 330, 1)
	l.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(l, "modulate:a", 1.0, 0.8)
	_page = -1
	_next_page()


func _next_page() -> void:
	_page += 1
	if _page >= PAGES.size():
		_start_game()
		return
	_text.text = PAGES[_page]
	_text.visible_characters = 0
	if _typing:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_interval(0.5 if _page == 0 else 0.1)
	_typing.tween_property(_text, "visible_ratio", 1.0, PAGES[_page].length() / TYPE_SPEED)
	if _page > 0:
		Sfx.play("ui_select", -10.0)


func _is_typing() -> bool:
	return _typing != null and _typing.is_valid() and _typing.is_running()


# --- 4. Into the woods ---------------------------------------------------------------------------

func _start_game() -> void:
	if _stage == Stage.LEAVING:
		return
	_stage = Stage.LEAVING
	if _typing:
		_typing.kill()
	if _tween:
		_tween.kill()
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, 1.0)
	tw.tween_interval(0.3)
	tw.tween_callback(func():
		PartyState.reset()
		MapState.reset()
		DungeonMap.fade_from_black = true
		get_tree().change_scene_to_file(GAME_SCENE))


# --- helpers -------------------------------------------------------------------------------------

func _label(parent: Control, pos: Vector2, col: Color) -> Label:
	var lab := Label.new()
	lab.position = pos
	lab.add_theme_color_override("font_color", col)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lab)
	return lab


func _centre(lab: Label, text: String, y: float, k: float) -> void:
	lab.text = text
	lab.scale = Vector2(k, k)
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x * k
	lab.position = Vector2(roundf((SCREEN.x - w) / 2.0), y)


## A burning torch (the wall torch's sheet, scale k) with a soft warm glow; `base` = the bracket's
## bottom centre.
func _flame(parent: Control, base: Vector2, k: int) -> TextureRect:
	var glow := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.55, 0.22, 0.32), Color(1.0, 0.45, 0.15, 0.10), Color(1.0, 0.4, 0.1, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 40 * k
	gt.height = 40 * k
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	glow.texture = gt
	glow.position = base + Vector2(-20 * k, -20 * k - 12 * k)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	parent.add_child(glow)
	var pic := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/sprites/props/torch_sheet.png")
	at.region = Rect2(0, 0, 8, 18)
	pic.texture = at
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.size = Vector2(8 * k, 18 * k)
	pic.position = base - Vector2(3.5 * k, 17 * k)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(pic)
	_flames.append(pic)
	return pic
