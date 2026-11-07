class_name Intro
extends Control
## The start screen (scenes/intro.tscn, the main scene):
##   1. Herrasoft splash: the name letter by letter in the fire palette, a shine sweeping across,
##      "presents", a chime.
##   2. Title: "HerraDnD" between two burning torches (the wall-torch flame, 4x, with a warm glow).
##   3. Menu: New adventure / Load game / Quit.
##   4. New adventure: pick a party - a new one (level 1) or one from the Roster (parties that have
##      finished an adventure; skipped while there are none) - then pick an adventure (Modules: the
##      ones whose level range fits the party's level can be played; the rest are greyed).
##   5. The adventure's story pages (AdventureModule.intro_pages), typed out over the four heroes.
##   6. Fade to black, then the adventure's first map fades in from black with its title.
## Splash / title / story: click / Space / Enter = skip ahead, Esc = skip to the menu (or, in the
## story, straight into the game). Menus: click; Esc = back.

const SCENE := "res://scenes/intro.tscn"
const SCREEN := CombatHud.SCREEN
const FONT := CombatHud.FONT
const FIRE := [Color8(200, 50, 20), Color8(255, 130, 30), Color8(255, 210, 80), Color8(255, 250, 200)]
const BG := Color8(10, 8, 14)
const HEROES := ["fighter", "rogue", "cleric", "mage"]
const TYPE_SPEED := 45.0             ## letters per second
const BOX := Rect2(110, 206, 420, 62)
const COL_CARD := Color8(26, 23, 33)
const COL_CARD_EDGE := Color8(90, 76, 60)

## Set before changing to this scene to skip the splash and title (back from a finished adventure).
static var start_at_menu := false

enum Stage { LOGO, TITLE, MENU, LOAD, PARTY, MODULE, STORY, LEAVING }

var _stage := Stage.LOGO
var _layer: Control               ## everything of the current stage (faded / freed as one)
var _tween: Tween
var _shine := -1.0                ## logo shine position (letters), animated
var _letters: Array[Label] = []
var _page := 0
var _pages: Array[String] = []
var _text: Label
var _more: Label
var _typing: Tween
var _flames: Array[TextureRect] = []
var _flame_t := 0.0
var _black: ColorRect
## The party picked for the new adventure ({} = a new level-1 party) and the adventure.
var _party := {}
var _module: AdventureModule


func _ready() -> void:
	size = SCREEN
	Settings.apply()
	Music.stop(1.0)                          # (a title tune comes later)
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
	if start_at_menu:
		start_at_menu = false
		_menu()
	else:
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
	if Settings.is_fullscreen_key(event):
		Settings.toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	var menus := _stage in [Stage.MENU, Stage.LOAD, Stage.PARTY, Stage.MODULE]
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		match _stage:
			Stage.LOGO, Stage.TITLE:
				_menu()
			Stage.LOAD, Stage.PARTY:
				_menu()
			Stage.MODULE:
				_choose_party(true)
			Stage.STORY:
				_start_game()
		get_viewport().set_input_as_handled()
		return
	if menus:
		return                                   # the buttons take the clicks
	var go := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		go = true
	elif event is InputEventKey and event.pressed and not event.echo:
		go = event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	if go:
		_advance()
		get_viewport().set_input_as_handled()


## Skip ahead one step (splash, title, story).
func _advance() -> void:
	match _stage:
		Stage.LOGO:
			_title()
		Stage.TITLE:
			_menu()
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


func _fade_in(l: Control, sec := 0.35) -> void:
	l.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(l, "modulate:a", 1.0, sec)


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

## The game's name between two torches (the title and the menu).
func _game_title(l: Control, y: float, k: int) -> void:
	var t := _label(l, Vector2.ZERO, CombatHud.COL_BANNER)
	_centre(t, "HerraDnD", y, k)
	t.add_theme_color_override("font_shadow_color", Color8(110, 20, 10))
	var tw := FONT.get_string_size("HerraDnD", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x * k
	for side in [-1, 1]:
		_flame(l, Vector2(SCREEN.x / 2.0 + side * (tw / 2.0 + 7 * k), y + 38.0 * k / 5.0), k - 1)


func _title() -> void:
	_stage = Stage.TITLE
	var l := _new_layer()
	_game_title(l, 128, 5)
	var sub := _label(l, Vector2.ZERO, CombatHud.COL_TEXT)
	_centre(sub, "Adventures for four heroes", 186, 2)
	var by := _label(l, Vector2.ZERO, CombatHud.COL_DIM)
	_centre(by, "A Herrasoft game", 214, 1)
	var hint := _label(l, Vector2.ZERO, Color8(84, 80, 96))
	_centre(hint, "Click or Space to begin", 330, 1)
	l.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(l, "modulate:a", 1.0, 1.0)
	_tween.tween_interval(3.5)
	_tween.tween_callback(_menu)


# --- 3. Menu -------------------------------------------------------------------------------------

func _menu() -> void:
	_stage = Stage.MENU
	var l := _new_layer()
	_game_title(l, 60, 4)
	var y := 170.0
	for spec in [["New adventure", _new_adventure], ["Load game", _load_menu], ["Quit", func(): get_tree().quit()]]:
		var b := _button(l, spec[0], Vector2(SCREEN.x / 2.0 - 80, y), 160)
		b.pressed.connect(spec[1])
		y += 22
	var by := _label(l, Vector2.ZERO, CombatHud.COL_DIM)
	_centre(by, "A Herrasoft game", 330, 1)
	_fade_in(l)


func _new_adventure() -> void:
	Sfx.play("ui_select", -8.0)
	_choose_party(false)


# --- Load game -----------------------------------------------------------------------------------

func _load_menu() -> void:
	Sfx.play("ui_select", -8.0)
	_stage = Stage.LOAD
	var l := _new_layer()
	_heading(l, "Load a game", "")
	var y := 64.0
	for slot in range(SaveGame.QUICK, SaveGame.SLOTS + 1):
		var h := SaveGame.info(slot)
		var what := "Quick save" if slot == SaveGame.QUICK else "Slot %d" % slot
		var lines: Array[String] = []
		if h.is_empty():
			lines = ["%s: empty" % what]
		else:
			lines = [what if slot == SaveGame.QUICK else "%s: %s" % [what, h.get("name", "")],
				"%s - %s, level %d, %d gold" % [h.get("module_title", "The Wraith Below"), h.get("map_title", ""), h.get("level", 1), h.get("gold", 0)],
				SaveGame.time_text(int(h.get("time", 0)))]
		y += _card(l, Rect2(150, y, 340, 44), lines, not h.is_empty(), _load_slot.bind(slot)) + 6
	_back(l, _menu)
	_fade_in(l)


func _load_slot(slot: int) -> void:
	var err := []
	var target := SaveGame.prepare_load(slot, err)
	if target == "":
		_flash_note(err[0] if not err.is_empty() else "That save can't be loaded.")
		return
	_leave_to(target, false)


# --- 4. Party, then adventure ----------------------------------------------------------------------

## Pick the party: a new one (level 1) or one from the Roster. With no saved parties, straight on
## to the adventures with a new party (`back` = coming back from the adventure list: then to the
## menu instead).
func _choose_party(back: bool) -> void:
	var parties := Roster.parties()
	if parties.is_empty():
		_party = {}
		if back:
			_menu()
		else:
			_choose_module()
		return
	_stage = Stage.PARTY
	var l := _new_layer()
	_heading(l, "Choose your party", "A new party starts at level 1. Parties that finished an adventure carry on from there.")
	var y := 82.0
	y += _card(l, Rect2(150, y, 340, 32), ["A new party", "Fighter, Rogue, Cleric and Mage, level 1"], true, _pick_party.bind({})) + 6
	for p in parties.slice(0, 5):
		var done: Array = p.get("modules_done", [])
		var titles: Array[String] = []
		for mid in done:
			var m := Modules.by_id(mid)
			titles.append(m.title if m else mid)
		var gold: int = p.get("party", {}).get("bag", {}).get("gold", 0)
		y += _card(l, Rect2(150, y, 340, 32), ["%s (level %d)" % [p.name, p.level],
			"%d gold. Finished: %s" % [gold, ", ".join(titles) if not titles.is_empty() else "nothing yet"]], true, _pick_party.bind(p)) + 6
	_back(l, _menu)
	_fade_in(l)


func _pick_party(p: Dictionary) -> void:
	Sfx.play("ui_select", -8.0)
	_party = p
	_choose_module()


func _party_level() -> int:
	return int(_party.get("level", 1)) if not _party.is_empty() else 1


## Pick the adventure: every module, the ones that fit the party's level playable.
func _choose_module() -> void:
	_stage = Stage.MODULE
	var l := _new_layer()
	var who := "A new party" if _party.is_empty() else String(_party.name)
	_heading(l, "Choose an adventure", "%s, level %d" % [who, _party_level()])
	var y := 80.0
	var done: Array = _party.get("modules_done", [])
	for m in Modules.all():
		# a new party can also jump straight into a later adventure, at its level with its starter kit
		var quick := _party.is_empty() and not m.fits_level(1) and not m.new_party_kit.is_empty()
		var ok := m.fits_level(_party_level()) or quick
		var status := ""
		if m.id in done:
			status = "  (finished)"
		var lines: Array[String] = ["%s%s" % [m.title, status],
			"%s, ends around level %d. %s" % [m.level_text(), m.level_end, m.tagline]]
		if quick:
			lines.append("A new party starts this one at level %d, with gear to match. %s" % [m.level_min, m.description])
		elif ok:
			lines.append(m.description)
		else:
			lines.append("Your party is level %d: this adventure is for a party of %s." % [_party_level(), m.level_text().to_lower()])
		y += _card(l, Rect2(100, y, 440, 40), lines, ok, _pick_module.bind(m)) + 6
	if Modules.all().is_empty():
		var none := _label(l, Vector2.ZERO, CombatHud.COL_DIM)
		_centre(none, "No adventures found (res://modules/).", 120, 1)
	_back(l, func(): _choose_party(true))
	_fade_in(l)


func _pick_module(m: AdventureModule) -> void:
	Sfx.play("ui_select", -8.0)
	_module = m
	_story()


# --- 5. The adventure's story ----------------------------------------------------------------------

## What hero `i` (HEROES order = Hero.HeroClass) will wear: the kept party's gear, a quick start's
## kit, else the class's starting equipment.
func _outfit(i: int) -> Dictionary:
	var kept: Dictionary = _party.get("party", {}).get("heroes", {}).get(i, {})
	if kept.has("equipment"):
		return kept.equipment
	var base: CreatureStats = load(Hero.STATS[i])
	var eq := Equipment.starting(base)
	if _party.is_empty() and _module and not _module.fits_level(1):
		for iid in _module.new_party_kit.get(base.class_id, []):
			var it := ItemData.get_item(iid)
			if it and it.is_equipment():
				eq[Equipment.default_slot(it, eq)] = iid
	return eq


## A hero's front idle frame (cell 0 of a HeroLook walk or effects sheet), 3x, feet at `feet_cell`
## + the 16x24 figure cell's bottom.
func _hero_pic(sheet: Texture2D, feet_cell: Vector2, flip: bool) -> TextureRect:
	const K := 3
	var pic := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(0, 0, 32, 32)
	pic.texture = at
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.size = Vector2(32 * K, 32 * K)
	pic.position = feet_cell - Vector2(8 * K, 8 * K)
	pic.flip_h = flip
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pic


func _story() -> void:
	_stage = Stage.STORY
	_pages.assign(_module.intro_pages if _module else [])
	if _pages.is_empty():
		_start_game()
		return
	var l := _new_layer()
	# The party: four heroes in the gear they bring (HeroLook), front idle frame, 3x. The 32x32
	# cell holds the 16x24 figure cell at (8, 8), so weapons and shields can stick out.
	const K := 3
	var gap := 64
	var x0 := SCREEN.x / 2.0 - gap * 1.5 - 8 * K
	for i in HEROES.size():
		var look := HeroLook.sheets(HEROES[i], _outfit(i))
		var pos := Vector2(roundf(x0 + i * gap), BOX.position.y - 24 * K - 14)
		var pic := _hero_pic(look.walk, pos, i >= 2)       # the two on the right face the others
		l.add_child(pic)
		if look.fx_walk:
			var fx := _hero_pic(look.fx_walk, pos, i >= 2)
			var mat := ShaderMaterial.new()
			mat.shader = Hero.FX_SHADER
			mat.set_shader_parameter("sheet_px", Vector2(look.fx_walk.get_size()))
			mat.set_shader_parameter("main_mode", look.main_fx.mode)
			mat.set_shader_parameter("main_color", look.main_fx.color)
			mat.set_shader_parameter("ranged_mode", look.ranged_fx.mode)
			mat.set_shader_parameter("ranged_color", look.ranged_fx.color)
			mat.set_shader_parameter("glint", look.glint.strength)
			mat.set_shader_parameter("glint_color", look.glint.color)
			mat.set_shader_parameter("phase", i * 2.7)
			fx.material = mat
			l.add_child(fx)
		var shadow := ColorRect.new()          # a flat dark oval-ish strip under their feet
		shadow.color = Color(0, 0, 0, 0.45)
		shadow.position = pos + Vector2(3 * K, 24 * K - 2)
		shadow.size = Vector2(10 * K, 3)
		l.add_child(shadow)
		l.move_child(shadow, pic.get_index())
	var name_l := _label(l, Vector2.ZERO, CombatHud.COL_BANNER)
	_centre(name_l, _module.title.to_upper(), 30, 2)
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
	if _page >= _pages.size():
		_start_game()
		return
	_text.text = _pages[_page]
	_text.visible_characters = 0
	if _typing:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_interval(0.5 if _page == 0 else 0.1)
	_typing.tween_property(_text, "visible_ratio", 1.0, _pages[_page].length() / TYPE_SPEED)
	if _page > 0:
		Sfx.play("ui_select", -10.0)


func _is_typing() -> bool:
	return _typing != null and _typing.is_valid() and _typing.is_running()


# --- 6. Into the adventure -------------------------------------------------------------------------

## Set up the picked party and adventure and go to its first map.
func _start_game() -> void:
	if _stage == Stage.LEAVING or _module == null:
		return
	begin(_module, _party)
	_leave_to(_module.start_map, true)


## Everything a new adventure needs before its first map loads: the module, a fresh map memory, and
## the party (new = PartyState empty, so the map makes a level-start_level party; else the Roster's).
static func begin(module: AdventureModule, party: Dictionary) -> void:
	Modules.current = module
	MapState.reset()
	MapState.next_entry = module.start_entry
	if party.is_empty():
		PartyState.reset()
	else:
		Roster.load_party(party)
	Quest.reset()
	RunePortal.reset()


func _leave_to(scene: String, from_black: bool) -> void:
	if _stage == Stage.LEAVING:
		return
	_stage = Stage.LEAVING
	if _typing:
		_typing.kill()
	if _tween:
		_tween.kill()
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, 1.0 if from_black else 0.5)
	tw.tween_interval(0.3)
	tw.tween_callback(func():
		DungeonMap.fade_from_black = from_black
		get_tree().change_scene_to_file(scene))


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


func _button(parent: Control, text: String, pos: Vector2, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	parent.add_child(b)
	b.set_deferred("size", Vector2(w, 16))
	return b


## A menu screen's heading (2x) and a line under it.
func _heading(l: Control, text: String, sub: String) -> void:
	var h := _label(l, Vector2.ZERO, CombatHud.COL_BANNER)
	_centre(h, text, 24, 2)
	if sub != "":
		var s := _label(l, Vector2.ZERO, CombatHud.COL_DIM)
		_centre(s, sub, 50, 1)


## "Back" at the bottom of a menu screen.
func _back(l: Control, call: Callable) -> void:
	var b := _button(l, "Back (Esc)", Vector2(SCREEN.x / 2.0 - 50, 326), 100)
	b.pressed.connect(func():
		Sfx.play("ui_select", -8.0)
		call.call())


## A clickable box: the first line in gold, the rest wrapped under it (the box grows to fit; returns
## its height). Greyed and not clickable when `enabled` is false.
func _card(l: Control, r: Rect2, lines: Array[String], enabled: bool, on_click: Callable) -> float:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.add_theme_stylebox_override("panel", CombatHud._box_static(COL_CARD, COL_CARD_EDGE))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_child(p)
	var y := 4.0
	for i in lines.size():
		var lab := _label(p, Vector2(8, y), CombatHud.COL_BANNER if i == 0 else (CombatHud.COL_TEXT if i == 1 else CombatHud.COL_DIM))
		lab.text = lines[i]
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.size = Vector2(r.size.x - 16, 0)
		var rows := maxi(1, roundi(FONT.get_multiline_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 10).y / FONT.get_height(10)))
		y += (rows - 1) * 14.0 + 12.0          # a wrapped label puts its lines 14 px apart
	r.size.y = maxf(r.size.y, y + 4.0)
	p.size = r.size
	if not enabled:
		p.modulate = Color(0.55, 0.55, 0.6)
		return r.size.y
	# a flat button over the whole card: hover lights the edge, click picks it
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2.ZERO
	b.size = r.size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.add_child(b)
	b.mouse_entered.connect(func(): p.add_theme_stylebox_override("panel", CombatHud._box_static(COL_CARD.lightened(0.08), CombatHud.COL_GOLD)))
	b.mouse_exited.connect(func(): p.add_theme_stylebox_override("panel", CombatHud._box_static(COL_CARD, COL_CARD_EDGE)))
	b.pressed.connect(on_click)
	return r.size.y


## A short message at the bottom (e.g. why a save can't be loaded).
func _flash_note(text: String) -> void:
	var n := _label(_layer, Vector2.ZERO, CombatHud.COL_HP)
	_centre(n, text, 306, 1)
	Sfx.play("fail_sting", -10.0)


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
