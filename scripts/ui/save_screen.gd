class_name SaveScreen
extends CanvasLayer
## Save / load. F5 = quick save: straight to the quick-save file, no screen (SaveGame.quick_save).
## F6 = save screen: the three named slots, each with its name, the map, the party's level, gold and
## when it was saved; pick a slot, type a name or leave it blank for the default (save001...), Save
## (Enter). F9 = load screen: the quick save (row Q) + the three slots; pick a used one, Load (Enter
## or a double-click). Up/Down pick (1-3 and Q too when loading), Esc closes. The game is paused
## while it is open. Its own canvas layer above the game-over screen and the fades, so F9 works after a wipe.

const RECT := Rect2(150, 40, 340, 0)
const ROW_H := 34
const COL_EMPTY := Color8(84, 80, 96)

var map: DungeonMap
var saving := true
var selected := 1

var _root: Control
var _panel: Panel
var _title: Label
var _rows: Array[Button] = []
var _name_l: Label
var _name: LineEdit
var _ok: Button
var _cancel: Button
var _msg: Label
var _was_paused := false
var _infos := {}
var _foot: Control
var _foot_h := 0.0


func _ready() -> void:
	layer = 60          # above the arrival title + fades (50)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.size = CombatHud.SCREEN
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = map.hud._make_theme() if map and map.hud else null
	add_child(_root)
	var dim := ColorRect.new()
	dim.size = CombatHud.SCREEN
	dim.color = Color(0.02, 0.01, 0.04, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP            # the map can't be clicked under it
	_root.add_child(dim)
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", CombatHud._box_static(CombatHud.COL_BG, CombatHud.COL_EDGE))
	_panel.position = RECT.position
	_root.add_child(_panel)
	_title = _label(_panel, Vector2(8, 4), CombatHud.COL_BANNER)
	var close_l := _label(_panel, Vector2(RECT.size.x - 56, 4), CombatHud.COL_DIM)
	close_l.text = "Esc: close"
	var rule := ColorRect.new()
	rule.color = CombatHud.COL_EDGE
	rule.position = Vector2(4, 17)
	rule.size = Vector2(RECT.size.x - 8, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(rule)
	# rows: _rows[slot], slot 0 = the quick save (shown when loading only); placed by _layout()
	for i in range(SaveGame.QUICK, SaveGame.SLOTS + 1):
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size = Vector2(RECT.size.x - 16, ROW_H - 3)
		b.gui_input.connect(_row_input.bind(i))
		b.pressed.connect(select.bind(i))
		_panel.add_child(b)
		_rows.append(b)
	# name box, buttons and message: one strip under the rows (_layout moves it)
	_foot = Control.new()
	_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_foot)
	var y := 0.0
	_name_l = _label(_foot, Vector2(10, y + 2), CombatHud.COL_TEXT)
	_name_l.text = "Name:"
	_name = LineEdit.new()
	_name.position = Vector2(44, y)
	_name.set_deferred("size", Vector2(150, 14))
	_name.max_length = SaveGame.NAME_MAX
	_name.add_theme_font_override("font", CombatHud.FONT)
	_name.add_theme_font_size_override("font_size", 10)
	_name.add_theme_color_override("font_color", CombatHud.COL_TEXT)
	_name.add_theme_color_override("font_placeholder_color", CombatHud.COL_DIM)
	_name.add_theme_color_override("caret_color", CombatHud.COL_ACTIVE)
	_name.add_theme_color_override("selection_color", CombatHud.COL_EDGE)
	for st in ["normal", "focus", "read_only"]:
		var sb := CombatHud._box_static(Color8(12, 10, 16), CombatHud.COL_ACTIVE if st == "focus" else CombatHud.COL_EDGE)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		_name.add_theme_stylebox_override(st, sb)
	_name.text_submitted.connect(func(_t: String): confirm())
	_foot.add_child(_name)
	_ok = Button.new()
	_ok.focus_mode = Control.FOCUS_NONE
	_ok.position = Vector2(RECT.size.x - 132, y + 1)
	_ok.set_deferred("size", Vector2(66, 13))
	_ok.pressed.connect(confirm)
	_foot.add_child(_ok)
	_cancel = Button.new()
	_cancel.text = "Cancel"
	_cancel.focus_mode = Control.FOCUS_NONE
	_cancel.position = Vector2(RECT.size.x - 62, y + 1)
	_cancel.set_deferred("size", Vector2(54, 13))
	_cancel.pressed.connect(close)
	_foot.add_child(_cancel)
	y += 20
	_msg = _label(_foot, Vector2(10, y), CombatHud.COL_DIM)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.size = Vector2(RECT.size.x - 20, 0)
	_foot_h = y + 24
	visible = false


func _label(parent: Control, pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


# --- open / close --------------------------------------------------------------------------------

## The slots this screen lists: the three named ones; loading also the quick save (first).
func _shown() -> Array[int]:
	var out: Array[int] = []
	if not saving:
		out.append(SaveGame.QUICK)
	for i in range(1, SaveGame.SLOTS + 1):
		out.append(i)
	return out


## Place the rows that show and the strip under them; size the panel.
func _layout() -> void:
	var y := 23.0
	for i in _rows.size():
		var show := i in _shown()
		_rows[i].visible = show
		if show:
			_rows[i].position = Vector2(8, y)
			y += ROW_H
	_foot.position = Vector2(0, y + 3)
	_panel.size = Vector2(RECT.size.x, y + 3 + _foot_h)


## Open the save (true) or load (false) screen. Saving when it can't be done says why instead.
func open(save_mode: bool) -> void:
	if save_mode:
		var why := SaveGame.blocked_reason(map)
		if why != "":
			_refuse(why)
			return
	if map.is_leaving():
		return
	saving = save_mode
	_read_slots()
	if not visible:
		_was_paused = get_tree().paused
		get_tree().paused = true
		if map.hud:
			map.hud.close_screens()
	visible = true
	_layout()
	# Saving: the first empty slot, else the oldest save. Loading: the newest save (quick save too).
	selected = 1
	var best := -1.0
	for i in _shown():
		var t: float = _infos[i].get("stamp", float(_infos[i].get("time", 0)))      # stamp: to the millisecond
		if saving:
			if _infos[i].is_empty():
				selected = i
				break
			if best < 0.0 or t < best:
				best = t
				selected = i
		elif not _infos[i].is_empty() and t > best:
			best = t
			selected = i
	_name.text = ""
	_name.placeholder_text = SaveGame.default_name()
	_title.text = "SAVE GAME" if saving else "LOAD GAME"
	_name.visible = saving
	_name_l.visible = saving
	if saving:
		_name.grab_focus.call_deferred()
	else:
		_name.release_focus()
	_refresh()
	Sfx.play("ui_select", -8.0)


func close() -> void:
	if not visible:
		return
	visible = false
	_name.release_focus()
	get_tree().paused = _was_paused


func _refuse(why: String) -> void:
	if map.hud:
		map.hud.flash_hint(why)
	Sfx.play("fail_sting", -10.0)


func _read_slots() -> void:
	_infos.clear()
	for i in range(SaveGame.QUICK, SaveGame.SLOTS + 1):
		_infos[i] = SaveGame.info(i)


## F5: quick save at once (no screen). Says why if it can't.
func quick_save() -> void:
	var err := SaveGame.quick_save(map)
	if err != "":
		_refuse(err)
		return
	if map.hud:
		map.hud.flash_hint("Quick saved. (F6: save to a slot, F9: load)")
	map.combat._say("Game quick saved.")
	Sfx.play("ui_select")


# --- slots ---------------------------------------------------------------------------------------

func select(slot: int) -> void:
	if not slot in _shown() or (not saving and _infos.get(slot, {}).is_empty()):
		return
	selected = slot
	_refresh()


func _row_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.double_click \
			and event.button_index == MOUSE_BUTTON_LEFT:
		select(slot)
		confirm()


func _refresh() -> void:
	for i in _shown():
		var b := _rows[i]
		for c in b.get_children():
			c.queue_free()
		var inf: Dictionary = _infos[i]
		var sel := i == selected
		var sb := CombatHud._box_static(CombatHud.COL_CARD if not sel else Color8(46, 42, 30),
				CombatHud.COL_ACTIVE if sel else CombatHud.COL_EDGE)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("disabled", sb)
		b.disabled = not saving and inf.is_empty()
		var num := _label(b, Vector2(6, 4), CombatHud.COL_ACTIVE if sel else CombatHud.COL_DIM)
		num.text = "Q" if i == SaveGame.QUICK else str(i)
		if inf.is_empty():
			var e := _label(b, Vector2(20, 9), COL_EMPTY)
			e.text = "- no quick save (F5) -" if i == SaveGame.QUICK else "- empty -"
			continue
		var n := _label(b, Vector2(20, 4), CombatHud.COL_BANNER)
		n.text = str(inf.get("name", "?"))
		var when := SaveGame.time_text(int(inf.get("time", 0)))
		var t := _label(b, Vector2(b.size.x - 6 - CombatHud.FONT.get_string_size(when, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, 4), CombatHud.COL_DIM)
		t.text = when
		var d := _label(b, Vector2(20, 16), CombatHud.COL_TEXT)
		var title: String = inf.get("map_title", "")
		d.text = "%s  -  Level %d  -  %d gold" % [title if title != "" else "Somewhere", int(inf.get("level", 1)), int(inf.get("gold", 0))]
	var used: bool = not _infos.get(selected, {}).is_empty()
	if saving:
		_ok.text = "Overwrite" if used else "Save"
		_ok.disabled = false
		_msg.text = ("Replaces \"%s\". " % _infos[selected].name if used else "") \
				+ "Type a name, or leave it blank for %s." % _name.placeholder_text
	else:
		_ok.text = "Load"
		_ok.disabled = not used
		_msg.text = "Unsaved progress will be lost." if used else "No saved games yet. F5 = quick save, F6 = save to a slot."


# --- doing it ------------------------------------------------------------------------------------

func confirm() -> void:
	if not visible:
		return
	if saving:
		var nm := _name.text
		var err := SaveGame.save(map, selected, nm)
		if err != "":
			_msg.text = err
			Sfx.play("fail_sting", -10.0)
			return
		var shown: String = str(SaveGame.info(selected).get("name", nm))
		close()
		if map.hud:
			map.hud.flash_hint("Game saved in slot %d: \"%s\"." % [selected, shown])
		map.combat._say("Game saved (slot %d: %s)." % [selected, shown])
		Sfx.play("ui_select")
	else:
		if _infos.get(selected, {}).is_empty():
			return
		get_tree().paused = false                 # the fade-out has to run
		_was_paused = false
		var err := map.load_game(selected)
		if err != "":
			get_tree().paused = true
			_msg.text = err
			Sfx.play("fail_sting", -10.0)
			return
		visible = false
		Sfx.play("ui_select")


func _move(dir: int) -> void:
	var list := _shown()
	var at := list.find(selected)
	for k in list.size():
		at = posmod(at + dir, list.size())
		if saving or not _infos[list[at]].is_empty():
			select(list[at])
			return


## F5 quick saves; F6 / F9 open (or switch / close) the save / load screen; while it is open it
## takes the keyboard.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var k: Key = event.keycode
	if k == KEY_F5:
		if visible:
			close()
		elif map.dice == null or not map.dice.visible:
			quick_save()
		get_viewport().set_input_as_handled()
		return
	if k == KEY_F6 or k == KEY_F9:
		var want_save := k == KEY_F6
		if visible and saving == want_save:
			close()
		elif map.dice == null or not map.dice.visible:
			open(want_save)
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	match k:
		KEY_ESCAPE:
			close()
		KEY_ENTER, KEY_KP_ENTER:
			confirm()
		KEY_UP:
			_move(-1)
		KEY_DOWN:
			_move(1)
		KEY_1, KEY_2, KEY_3, KEY_Q:
			if saving:
				return                           # typing the name
			select(SaveGame.QUICK if k == KEY_Q else k - KEY_1 + 1)
		_:
			return
	get_viewport().set_input_as_handled()
