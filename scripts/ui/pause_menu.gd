class_name PauseMenu
extends CanvasLayer
## The Esc menu (in every map): Resume, Quick save, Save game, Load game, Help, the settings
## (fullscreen, dice scene, help tips), Main menu, Quit. Esc opens it when nothing else wants the
## key (an open screen, a popup, targeting, a talk: those close first). The game is paused while it
## is open; the save / load screen opens on top of it and comes back to it. Main menu and Quit ask
## first (unsaved progress is lost). F11 / Alt+Enter toggles fullscreen anywhere in a map.
## One per map, a child of DungeonMap (after the save screen, before the help box).

const W := 200.0
const ROW := 16.0

var map: DungeonMap

var _root: Control
var _panel: Panel
var _where: Label
var _played: Label
var _rows_end := 0.0
var _msg: Label
var _buttons := {}                         ## id -> Button
var _confirm: Panel
var _confirm_text: Label
var _confirm_yes: Button
var _confirm_do: Callable
var _was_paused := false


func _ready() -> void:
	layer = 58          # above the HUD, fades (50) and the game-over screen; under the save screen (60)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.size = CombatHud.SCREEN
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = CombatHud.make_theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.size = CombatHud.SCREEN
	dim.color = Color(0.02, 0.01, 0.04, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", CombatHud._box_static(CombatHud.COL_BG, CombatHud.COL_ACTIVE))
	_root.add_child(_panel)
	var title := _label(_panel, Vector2(8, 4), CombatHud.COL_BANNER)
	title.text = "PAUSED"
	var close_l := _label(_panel, Vector2(W - 58, 4), CombatHud.COL_DIM)
	close_l.text = "Esc: resume"
	_where = _label(_panel, Vector2(8, 17), CombatHud.COL_DIM)
	_where.size = Vector2(W - 16, 0)
	_where.clip_text = true
	_played = _label(_panel, Vector2(8, 28), CombatHud.COL_DIM)
	var y := 41.0
	y = _rule(y)
	y = _add("resume", "Resume", "Esc", y, close)
	y = _rule(y)
	y = _add("quick", "Quick save", "F5", y, _quick_save)
	y = _add("save", "Save game...", "F6", y, _open_saves.bind(true))
	y = _add("load", "Load game...", "F9", y, _open_saves.bind(false))
	y = _rule(y)
	y = _add("fullscreen", "", "F11", y, func():
		Settings.toggle_fullscreen()
		_refresh())
	y = _add("dice", "", "F2", y, func():
		map.combat.cycle_dice_mode()
		_refresh())
	y = _add("tips", "", "", y, func():
		HelpBox.set_enabled(not HelpBox.enabled)
		_refresh())
	y = _add("help", "Help topics...", "F1", y, _open_help)
	y = _rule(y)
	y = _add("title", "Main menu", "", y, _ask.bind(
			"Leave for the main menu? Unsaved progress will be lost.", "Main menu", _to_title))
	y = _add("quit", "Quit game", "", y, _ask.bind(
			"Quit the game? Unsaved progress will be lost.", "Quit", _quit))
	_msg = _label(_panel, Vector2(8, y + 2), CombatHud.COL_DIM)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.size = Vector2(W - 16, 0)
	_rows_end = y
	_fit()
	_build_confirm()
	visible = false


func _label(parent: Control, pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _rule(y: float) -> float:
	var r := ColorRect.new()
	r.color = CombatHud.COL_EDGE
	r.position = Vector2(6, y + 2)
	r.size = Vector2(W - 12, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(r)
	return y + 6


## A menu row: the text on the left, its key (dim) on the right.
func _add(id: String, text: String, key: String, y: float, call: Callable) -> float:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.position = Vector2(8, y)
	b.set_deferred("size", Vector2(W - 16, ROW - 2))
	b.pressed.connect(func():
		Sfx.play("ui_select", -8.0)
		call.call())
	_panel.add_child(b)
	if key != "":
		var k := _label(b, Vector2(0, 1), CombatHud.COL_DIM)
		k.text = key
		k.position.x = W - 16 - 6 - CombatHud.FONT.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	_buttons[id] = b
	return y + ROW


func _build_confirm() -> void:
	_confirm = Panel.new()
	_confirm.add_theme_stylebox_override("panel", CombatHud._box_static(CombatHud.COL_BG, CombatHud.COL_ACTIVE))
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.size = Vector2(240, 56)
	_confirm.position = ((CombatHud.SCREEN - _confirm.size) / 2.0).round()
	_confirm.visible = false
	_root.add_child(_confirm)
	_confirm_text = _label(_confirm, Vector2(8, 6), CombatHud.COL_TEXT)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.size = Vector2(_confirm.size.x - 16, 0)
	_confirm_yes = Button.new()
	_confirm_yes.focus_mode = Control.FOCUS_NONE
	_confirm_yes.position = Vector2(_confirm.size.x - 136, _confirm.size.y - 18)
	_confirm_yes.set_deferred("size", Vector2(70, 13))
	_confirm_yes.pressed.connect(func(): _confirm_do.call())
	_confirm.add_child(_confirm_yes)
	var no := Button.new()
	no.text = "Cancel"
	no.focus_mode = Control.FOCUS_NONE
	no.position = Vector2(_confirm.size.x - 62, _confirm.size.y - 18)
	no.set_deferred("size", Vector2(54, 13))
	no.pressed.connect(_cancel_ask)
	_confirm.add_child(no)


# --- open / close --------------------------------------------------------------------------------

## Esc may open the menu: nothing else is up that Esc would close first.
func can_open() -> bool:
	if map == null or map.is_leaving() or get_tree().paused or HelpBox.showing():
		return false
	if map.save_screen and map.save_screen.visible:
		return false
	var hud := map.hud
	if hud and (hud.ui_busy() or hud.popup_open()):
		return false
	return not (map.combat and map.combat.targeting)


func open() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	if map.hud:
		map.hud.close_screens()
	_confirm.visible = false
	_panel.visible = true
	_msg.text = ""
	visible = true
	_refresh()
	Sfx.play("ui_select", -8.0)


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused


func _refresh() -> void:
	var mod_title := Modules.current.title if Modules.current else ""
	var place := map.map_title if map.map_title != "" else "Somewhere"
	var secs := int(PartyState.play_seconds)
	_where.text = "%s%s" % [(mod_title + ": ") if mod_title != "" else "", place]
	_played.text = "Time played %d:%02d" % [secs / 3600, (secs / 60) % 60]
	_buttons.fullscreen.text = "Fullscreen: %s" % ("On" if Settings.fullscreen else "Off")
	_buttons.dice.text = "Dice scene: %s" % CombatManager.DICE_MODE_NAMES[map.combat.dice_mode]
	_buttons.tips.text = "Help tips: %s" % ("On" if HelpBox.enabled else "Off")
	var why := SaveGame.blocked_reason(map)
	_buttons.quick.disabled = why != ""
	_buttons.save.disabled = why != ""
	if why != "" and _msg.text == "":
		_msg.text = why
	_fit()


# --- the rows ------------------------------------------------------------------------------------

func _quick_save() -> void:
	var err := SaveGame.quick_save(map)
	if err != "":
		_msg.text = err
		Sfx.play("fail_sting", -10.0)
		_fit()
		return
	map.combat._say("Game quick saved.")
	_msg.text = "Quick saved."
	_fit()


## The save / load screen, on top of this menu; closing it comes back here.
func _open_saves(save_mode: bool) -> void:
	map.save_screen.open(save_mode)


func _open_help() -> void:
	close()
	if map.help:
		map.help._open_menu()


func _ask(text: String, yes: String, what: Callable) -> void:
	_confirm_text.text = text
	_confirm_yes.text = yes
	_confirm_do = what
	_panel.visible = false
	_confirm.visible = true


func _cancel_ask() -> void:
	_confirm.visible = false
	_panel.visible = true


func _to_title() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Intro.start_at_menu = true
	get_tree().change_scene_to_file(Intro.SCENE)


func _quit() -> void:
	get_tree().quit()


# --- keys ----------------------------------------------------------------------------------------

## Unhandled: the screens, popups and targeting that Esc closes take it first (and can_open checks).
func _unhandled_input(event: InputEvent) -> void:
	if Settings.is_fullscreen_key(event):
		Settings.toggle_fullscreen()
		if visible:
			_refresh()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if visible:
		if map.save_screen and map.save_screen.visible:
			return                              # the save screen has the keys
		if event.keycode == KEY_ESCAPE:
			if _confirm.visible:
				_cancel_ask()
			else:
				close()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER] and _confirm.visible:
			_confirm_do.call()
		get_viewport().set_input_as_handled()   # the game behind waits
		return
	if event.keycode == KEY_ESCAPE and can_open():
		open()
		get_viewport().set_input_as_handled()


## Size the panel to the rows, plus the message line(s) when there is one; keep it centred.
func _fit() -> void:
	var h := _rows_end + 4.0
	if _msg.text != "":
		var lines := ceili(CombatHud.FONT.get_string_size(_msg.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x / (W - 20.0))
		h += 2.0 + maxi(lines, 1) * 11.0
	_panel.size = Vector2(W, h)
	_panel.position = ((CombatHud.SCREEN - _panel.size) / 2.0).round()
