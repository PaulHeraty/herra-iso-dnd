class_name HelpBox
extends CanvasLayer
## Help mode (on by default): the first time something new happens (the first fight, a hero at
## 0 HP, a trap...) a box explains it. `HelpBox.tip(id, focus)` asks for a topic (HelpTopics);
## each is shown once, ever. The box pauses the game (and freezes time, so fights wait too),
## frames the part of the screen it talks about and dims the rest. Space / Enter / Right = next
## page, Left / Backspace = back, Esc = close; "Help off" stops the tips for good. F1 = the help
## menu: every topic to read again, tips on / off, show all tips again.
## The setting + the topics seen are kept in user://settings.cfg (not in save games). Test runs
## (a -s script, HERRA_AUTO_REACT set, or headless) have help off and never write the file; HERRA_HELP=1 turns
## it on without the file (screenshots).
## One per map, a child of DungeonMap added last (it takes the keys before the save screen).

const SETTINGS := "user://settings.cfg"
const W := 244.0
const MENU_W := 420.0
const CALM_DELAY := 3.4             ## s after arriving before calm tips (the map title has gone)
const COL_DIM_BG := Color(0.02, 0.01, 0.05, 0.55)

static var enabled := true
static var seen := {}
static var _loaded := false
static var _persist := true
static var _inst: HelpBox
## Set by DungeonMap.take_stairs: the next map says what a new place means.
static var arrived_by_stairs := false

var map: DungeonMap
var _queue: Array[Dictionary] = []          ## [{id, focus}]
var _topic := ""
var _focus: Variant = null
var _page := 0
var _from_menu := false
var _born := 0.0
var _was_paused := false
var _old_scale := 1.0
var _frozen := false

var _root: Control
var _dims: Array[ColorRect] = []
var _frame: Panel
var _panel: Panel
var _title: Label
var _count: Label
var _body: Label
var _back: Button
var _next: Button
var _off: Button
var _menu: Panel
var _menu_toggle: Button


# --- settings -----------------------------------------------------------------------------------

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if OS.get_environment("HERRA_HELP") == "1":
		enabled = true
		_persist = false
		return
	var scripted := "-s" in OS.get_cmdline_args() or "--script" in OS.get_cmdline_args()
	if scripted or OS.get_environment("HERRA_AUTO_REACT") != "" or DisplayServer.get_name() == "headless":
		enabled = false                # scripted runs must never wait on a help box
		_persist = false
		return
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		enabled = bool(cf.get_value("help", "enabled", true))
		for id in cf.get_value("help", "seen", []):
			seen[str(id)] = true


static func _save() -> void:
	if not _persist:
		return
	var cf := ConfigFile.new()
	cf.load(SETTINGS)                  # keep any other sections
	cf.set_value("help", "enabled", enabled)
	cf.set_value("help", "seen", seen.keys())
	cf.save(SETTINGS)


static func set_enabled(on: bool) -> void:
	_load()
	enabled = on
	_save()


## Show the help for `id` if help is on and it hasn't been shown before. focus: a Rect2 (screen)
## or a Control (its rect when shown) for pages whose `at` is "focus".
static func tip(id: String, focus: Variant = null) -> void:
	_load()
	if not enabled or seen.has(id) or _inst == null or not is_instance_valid(_inst):
		return
	_inst._enqueue(id, focus)


## Is a help box (or the menu) up?
static func showing() -> bool:
	return _inst != null and is_instance_valid(_inst) and (_inst._panel.visible or _inst._menu.visible)


# --- building -----------------------------------------------------------------------------------

func _ready() -> void:
	_load()
	_inst = self
	layer = 70                    # above the save screen (60) and the fades (50)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_born = _now()
	_root = Control.new()
	_root.size = CombatHud.SCREEN
	_root.mouse_filter = Control.MOUSE_FILTER_STOP     # nothing under the box takes clicks
	_root.theme = CombatHud.make_theme()
	_root.visible = false
	add_child(_root)
	for i in 4:
		var d := ColorRect.new()
		d.color = COL_DIM_BG
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(d)
		_dims.append(d)
	_frame = Panel.new()
	_frame.add_theme_stylebox_override("panel", _frame_box())
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_frame)
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", CombatHud._box_static(CombatHud.COL_BG, CombatHud.COL_ACTIVE, 1))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	_root.add_child(_panel)
	var tag := Label.new()
	tag.text = "HELP"
	tag.position = Vector2(6, 3)
	tag.add_theme_color_override("font_color", Color8(120, 200, 255))
	_panel.add_child(tag)
	_title = Label.new()
	_title.position = Vector2(34, 3)
	_title.add_theme_color_override("font_color", CombatHud.COL_BANNER)
	_panel.add_child(_title)
	_count = Label.new()
	_count.position = Vector2(W - 46, 3)
	_count.size = Vector2(40, 10)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.add_theme_color_override("font_color", CombatHud.COL_DIM)
	_panel.add_child(_count)
	var rule := ColorRect.new()
	rule.color = CombatHud.COL_EDGE
	rule.position = Vector2(4, 15)
	rule.size = Vector2(W - 8, 1)
	_panel.add_child(rule)
	_body = Label.new()
	_body.position = Vector2(7, 19)
	_body.size = Vector2(W - 14, 0)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_color_override("font_color", CombatHud.COL_TEXT)
	_body.add_theme_constant_override("line_spacing", 1)
	_panel.add_child(_body)
	_off = _button(_panel, "Help off", _turn_off)
	_off.tooltip_text = "No more help boxes (F1 turns them back on)"
	_back = _button(_panel, "< Back", func(): _show_page(_page - 1))
	_next = _button(_panel, "Next >", _advance)
	_build_menu()


func _button(parent: Control, text: String, call: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Sfx.play("ui_select", -8.0)
		call.call())
	parent.add_child(b)
	return b


func _frame_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = CombatHud.COL_ACTIVE
	sb.set_border_width_all(2)
	sb.anti_aliasing = false
	return sb


func _exit_tree() -> void:
	if _frozen:
		_unfreeze()
	if _inst == self:
		_inst = null


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- queue --------------------------------------------------------------------------------------

func _enqueue(id: String, focus: Variant) -> void:
	if not HelpTopics.TOPICS.has(id) or id == _topic:
		return
	for q in _queue:
		if q.id == id:
			return
	_queue.append({id = id, focus = focus})


func _process(_delta: float) -> void:
	if _panel.visible:
		var a := 0.55 + 0.45 * sin(_now() * TAU / 1.1)          # real time: the game's clock is frozen
		_frame.modulate.a = a
		return
	if _menu.visible or map == null:
		return
	_poll()
	if _queue.is_empty() or not _free_to_show():
		return
	for i in _queue.size():
		var q: Dictionary = _queue[i]
		if HelpTopics.TOPICS[q.id].get("calm", false) and not _calm():
			continue
		_queue.remove_at(i)
		if seen.has(q.id) or not enabled:
			return
		_open_topic(q.id, q.focus, false)
		return


## Nothing else owns the screen (a fade to another map, the save screen, the victory screen).
func _free_to_show() -> bool:
	if map.is_leaving() or get_tree().paused:
		return false
	return map.hud != null and map.combat != null


## Calm tips wait for exploring with no screen or talk open, after the arrival title.
func _calm() -> bool:
	if _now() - _born < CALM_DELAY:
		return false
	var c := map.combat
	if c.in_combat or c._starting or c.game_over:
		return false
	var hud := map.hud
	if hud.inventory_screen.visible or hud.shop.visible or hud.quest_screen.visible or hud.sheet.visible \
			or hud.dialogue.visible or hud.map_screen.visible or hud.reaction_open():
		return false
	return map.dice == null or not map.dice.visible


## States worth a tip, checked every frame (cheap: tip() returns at once for topics seen).
func _poll() -> void:
	if not enabled:
		return
	var c := map.combat
	var party := map.party
	for i in party.size():
		var h: Hero = party[i]
		var card := HelpTopics.card_rect(i)
		if h.dead:
			tip("hero_died", card)
		elif h.hp <= 0:
			tip("hero_down" if c.in_combat else "knocked_out", card)
		for cid in ["prone", "restrained", "frightened", "paralyzed"]:
			if h.has_condition(cid):
				tip("conditions", card)
		if h.concentrating:
			tip("concentration", card)
	if c.in_combat:
		tip("combat")
	var hud := map.hud
	if hud:
		if hud.dialogue.visible:
			tip("talk")
		if hud.shop.visible:
			tip("shop")
	if map.inventory and map.inventory.has("rune_of_return"):
		tip("rune")


## Hooks into the map's combat (called by DungeonMap once everything exists).
func setup(m: DungeonMap) -> void:
	map = m
	var c := m.combat
	c.turn_started.connect(func(a: Actor):
		tip("combat")                  # the fight's own help comes before the first hero's
		if a is Hero and a.is_alive():
			var ids := {Hero.HeroClass.FIGHTER: "class_fighter", Hero.HeroClass.ROGUE: "class_rogue",
					Hero.HeroClass.CLERIC: "class_cleric", Hero.HeroClass.MAGE: "class_mage"}
			tip(ids[a.hero_class], HelpTopics.card_rect(maxi(0, m.party.find(a)))))
	c.reaction_prompt.connect(func(_t: String): tip("reaction"))
	c.combat_ended.connect(func():
		if not c.game_over:
			tip("after_combat"))
	c.level_ups.connect(func(_u: Array): tip("level_up", m.hud._loot if m.hud else null))
	tip("welcome")
	if arrived_by_stairs:
		arrived_by_stairs = false
		tip("stairs")


# --- showing ------------------------------------------------------------------------------------

func _open_topic(id: String, focus: Variant, from_menu: bool) -> void:
	_topic = id
	_focus = focus
	_from_menu = from_menu
	_menu.visible = false
	if focus is Control and is_instance_valid(focus):
		(focus as Control).modulate.a = 1.0       # a box still fading in would stay faint while frozen
	_freeze()
	_root.visible = true
	_panel.visible = true
	Sfx.play("ui_select", -4.0)
	_show_page(0)


func _show_page(i: int) -> void:
	var pages: Array = HelpTopics.TOPICS[_topic].pages
	_page = clampi(i, 0, pages.size() - 1)
	var p: Dictionary = pages[_page]
	_apply_screen(p.get("open", ""))
	_title.text = p.get("h", HelpTopics.TOPICS[_topic].title)
	_count.text = "%d/%d" % [_page + 1, pages.size()] if pages.size() > 1 else ""
	_body.text = p.t
	_body.size = Vector2(W - 14, 0)
	var lines := maxi(1, _body.get_line_count())
	var h := 19.0 + lines * 12.0 + 22.0
	_panel.size = Vector2(W, h)
	var last := _page == pages.size() - 1
	_next.text = "Done" if last else "Next >"
	_back.visible = _page > 0
	_off.visible = not _from_menu
	_place_buttons()
	var rect := _resolve(p.get("at", null))
	_highlight(rect)
	_panel.position = _place_panel(rect, _panel.size)


func _place_buttons() -> void:
	var y := _panel.size.y - 17.0
	var bw := func(b: Button) -> float:
		return CombatHud.FONT.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12.0
	var nw: float = bw.call(_next)
	_next.position = Vector2(W - 6 - nw, y)
	_next.size = Vector2(nw, 13)
	var backw: float = bw.call(_back)
	_back.position = Vector2(_next.position.x - 4 - backw, y)
	_back.size = Vector2(backw, 13)
	var ow: float = bw.call(_off)
	_off.position = Vector2(6, y)
	_off.size = Vector2(ow, 13)


## A page's `at` as a screen rect (empty = nothing framed).
func _resolve(at: Variant) -> Rect2:
	if at is Rect2:
		return at
	if at is String and at == "focus":
		if _focus is Rect2:
			return _focus
		if _focus is Control and is_instance_valid(_focus) and _focus.is_visible_in_tree():
			return (_focus as Control).get_global_rect().grow(1)
	return Rect2()


## Dim everything but `r` (nothing framed: a lighter dim all over) and frame it.
func _highlight(r: Rect2) -> void:
	var s := CombatHud.SCREEN
	if r.size == Vector2.ZERO:
		_dims[0].position = Vector2.ZERO
		_dims[0].size = s
		_dims[0].color = Color(COL_DIM_BG, 0.35)
		for k in range(1, 4):
			_dims[k].visible = false
		_dims[0].visible = true
		_frame.visible = false
		return
	r = Rect2(r.position.round(), r.size.round())
	var parts := [Rect2(0, 0, s.x, r.position.y), Rect2(0, r.end.y, s.x, s.y - r.end.y),
			Rect2(0, r.position.y, r.position.x, r.size.y), Rect2(r.end.x, r.position.y, s.x - r.end.x, r.size.y)]
	for k in 4:
		_dims[k].visible = true
		_dims[k].color = COL_DIM_BG
		_dims[k].position = parts[k].position
		_dims[k].size = parts[k].size
	_frame.visible = true
	_frame.position = r.position - Vector2(2, 2)
	_frame.size = r.size + Vector2(4, 4)


## Where the box goes: beside the framed rect (right, left, below, above), else the middle.
func _place_panel(r: Rect2, sz: Vector2) -> Vector2:
	var s := CombatHud.SCREEN
	var m := 6.0
	if r.size == Vector2.ZERO:
		return ((s - sz) / 2.0 - Vector2(0, 30)).round()
	var y := clampf(r.position.y + (r.size.y - sz.y) / 2.0, m, s.y - sz.y - m)
	var x := clampf(r.position.x + (r.size.x - sz.x) / 2.0, m, s.x - sz.x - m)
	var tries := [
		Vector2(r.end.x + 8, y), Vector2(r.position.x - 8 - sz.x, y),
		Vector2(x, r.end.y + 8), Vector2(x, r.position.y - 8 - sz.y),
	]
	for p: Vector2 in tries:
		if p.x >= m and p.y >= m and p.x + sz.x <= s.x - m and p.y + sz.y <= s.y - m:
			return p.round()
	return Vector2(((s.x - sz.x) / 2.0), m).round()


func _advance() -> void:
	var pages: Array = HelpTopics.TOPICS[_topic].pages
	if _page < pages.size() - 1:
		_show_page(_page + 1)
	else:
		_close_topic()


func _close_topic() -> void:
	var was := _topic
	if was != "" and not _from_menu:
		seen[was] = true
		_save()
	if _touches_screens(was):
		_apply_screen("none")
	_topic = ""
	_panel.visible = false
	if _from_menu:
		_open_menu()
		return
	_root.visible = false
	_unfreeze()


func _touches_screens(id: String) -> bool:
	for p: Dictionary in HelpTopics.TOPICS.get(id, {pages = []}).pages:
		if p.get("open", "") in ["inventory", "sheet"]:
			return true
	return false


func _turn_off() -> void:
	if _topic != "":
		seen[_topic] = true
	set_enabled(false)
	_queue.clear()
	_from_menu = false
	_close_topic()
	if map and map.hud:
		map.hud.flash_hint("Help is off. Press F1 to turn it back on.")


## The tour opens the screen it talks about (or closes them).
func _apply_screen(which: String) -> void:
	if which == "" or map == null or map.hud == null:
		return
	var hud := map.hud
	match which:
		"inventory":
			if not hud.inventory_screen.visible:
				hud.close_screens()
				hud.inventory_screen.open(map.party[0] if not map.party.is_empty() else null)
		"sheet":
			if not hud.sheet.visible:
				hud.close_screens()
				hud.sheet.open(map.party[0] if not map.party.is_empty() else null)
		"none":
			hud.close_screens()


## Pause the game and stop its clock: timers in a fight (a monster's next swing) wait too.
func _freeze() -> void:
	if _frozen:
		return
	_frozen = true
	_was_paused = get_tree().paused
	_old_scale = Engine.time_scale
	get_tree().paused = true
	Engine.time_scale = 0.0


func _unfreeze() -> void:
	if not _frozen:
		return
	_frozen = false
	Engine.time_scale = _old_scale if _old_scale > 0.0 else 1.0
	if is_inside_tree():
		get_tree().paused = _was_paused


# --- the F1 menu --------------------------------------------------------------------------------

func _build_menu() -> void:
	_menu = Panel.new()
	_menu.add_theme_stylebox_override("panel", CombatHud._box_static(CombatHud.COL_BG, CombatHud.COL_ACTIVE, 1))
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.visible = false
	_root.add_child(_menu)
	var t := Label.new()
	t.text = "HELP"
	t.position = Vector2(6, 3)
	t.add_theme_color_override("font_color", CombatHud.COL_BANNER)
	_menu.add_child(t)
	var hint := Label.new()
	hint.text = "Click a topic to read it.   F1 / Esc: close"
	hint.position = Vector2(40, 3)
	hint.add_theme_color_override("font_color", CombatHud.COL_DIM)
	_menu.add_child(hint)
	var ids := HelpTopics.TOPICS.keys()
	var per_col := ceili(ids.size() / 2.0)
	var col_w := (MENU_W - 18.0) / 2.0
	for i in ids.size():
		var id: String = ids[i]
		var b := Button.new()
		b.text = HelpTopics.TOPICS[id].title.capitalize() if id != "welcome" else "Getting started (the tour)"
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.position = Vector2(6 + (i / per_col) * (col_w + 6), 19 + (i % per_col) * 14)
		_menu.add_child(b)
		b.set_deferred("size", Vector2(col_w, 13))
		b.pressed.connect(func():
			Sfx.play("ui_select", -8.0)
			_open_topic(id, null, true))
	var y := 19.0 + per_col * 14 + 6
	_menu_toggle = _button(_menu, "", func():
		set_enabled(not enabled)
		_menu_toggle.text = _toggle_text())
	_menu_toggle.position = Vector2(6, y)
	_menu_toggle.set_deferred("size", Vector2(150, 13))
	var reset := _button(_menu, "Show all tips again", func():
		seen.clear()
		set_enabled(true)
		_menu_toggle.text = _toggle_text()
		if map and map.hud:
			map.hud.flash_hint("Every help tip will show again."))
	reset.position = Vector2(162, y)
	reset.set_deferred("size", Vector2(130, 13))
	var close := _button(_menu, "Close", _close_menu)
	close.position = Vector2(MENU_W - 56, y)
	close.set_deferred("size", Vector2(50, 13))
	_menu.size = Vector2(MENU_W, y + 19)
	_menu.position = ((CombatHud.SCREEN - _menu.size) / 2.0 - Vector2(0, 20)).round()


func _toggle_text() -> String:
	return "Help tips: ON (click: off)" if enabled else "Help tips: OFF (click: on)"


func _open_menu() -> void:
	_menu_toggle.text = _toggle_text()
	_freeze()
	_root.visible = true
	_panel.visible = false
	_frame.visible = false
	_highlight(Rect2())
	_menu.visible = true


func _close_menu() -> void:
	_menu.visible = false
	_root.visible = false
	_unfreeze()


# --- keys ---------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var k: Key = event.keycode
	if _panel.visible:
		match k:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_RIGHT:
				_advance()
			KEY_LEFT, KEY_BACKSPACE:
				_show_page(_page - 1)
			KEY_ESCAPE, KEY_F1:
				_close_topic()
		get_viewport().set_input_as_handled()        # everything else waits
		return
	if _menu.visible:
		if k in [KEY_ESCAPE, KEY_F1]:
			_close_menu()
		get_viewport().set_input_as_handled()
		return
	if k == KEY_F1 and map and not map.is_leaving() and not get_tree().paused:
		get_viewport().set_input_as_handled()
		_open_menu()
