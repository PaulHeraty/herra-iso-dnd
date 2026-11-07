class_name QuestScreen
extends Panel
## The quest log (Quest button / J). Pages: Quests (the ones still going), Completed, Journal (the
## lore the party has read, LoreNote; pick a title to read it again). Each quest is one line, folded
## by default (one open at a time): click its name for who gave it, the reward, the last few stages done (ticked) and the
## one the party is on now (later ones stay hidden). J, Esc or a click on the map closes it. Lives on
## the CombatHud's root (inherits its theme).

const RECT := Rect2(120, 24, 400, 266)
const COL_DONE := Color8(120, 186, 116)
const MAIN := "_main"            ## the main quest's key in _open

var combat: CombatManager
var _body: Control
var _page := "quests"            ## or "completed", "journal"
var _sel := -1                   ## journal: the entry shown (-1 = the latest)
var _page_btns := {}

static var _tick_tex: Texture2D
## The quest unfolded (quest id -> true; MAIN for the main one; one at a time): kept while the game runs.
static var _open := {}


func _ready() -> void:
	position = RECT.position
	size = RECT.size
	add_theme_stylebox_override("panel", CombatHud._box_static(CombatHud.COL_BG, CombatHud.COL_EDGE))
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var title := _label(self, Vector2(8, 4), CombatHud.COL_BANNER)
	title.text = "QUEST LOG"
	var close_l := _label(self, Vector2(RECT.size.x - 74, 4), CombatHud.COL_DIM)
	close_l.text = "J / Esc: close"
	var bx := 92.0
	for p in ["quests", "completed", "journal"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(bx, 2)
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(func():
			_page = p
			Sfx.play("ui_select", -10.0)
			_build())
		add_child(b)
		_page_btns[p] = b
		bx += 74.0
	var rule := ColorRect.new()
	rule.color = CombatHud.COL_EDGE
	rule.position = Vector2(4, 17)
	rule.size = Vector2(RECT.size.x - 8, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_build()
	visible = true
	Sfx.play("ui_select", -8.0)


func close() -> void:
	visible = false


func _build() -> void:
	if _body:
		_body.queue_free()
	_body = Control.new()
	_body.position = Vector2(0, 22)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	var all := quests()
	var n_done := 0
	for q in all:
		n_done += 1 if q.done else 0
	_page_btns.quests.text = "Quests (%d)" % (all.size() - n_done)
	_page_btns.completed.text = "Completed (%d)" % n_done
	_page_btns.journal.text = "Journal (%d)" % Quest.lore.size()
	for p in _page_btns:
		_page_btns[p].set_deferred("size", Vector2(70, 14))
		_page_btns[p].modulate = Color.WHITE if p == _page else Color(0.65, 0.65, 0.7)
	if _page == "journal":
		_journal()
		return
	var w := RECT.size.x - 24
	var shown: Array[Dictionary] = []
	for q in all:
		if q.done == (_page == "completed"):
			shown.append(q)
	if shown.is_empty():
		var l := _text(Vector2(10, 4), w, CombatHud.COL_DIM)
		if _page == "completed":
			l.text = "No quests finished yet."
		elif all.is_empty():
			l.text = "No quests yet.\n\n" + (Modules.current.quest_hint if Modules.current else "")
		else:
			l.text = "Every quest the party has taken on is finished (see Completed)."
		_fit(70.0 if all.is_empty() else 30.0)
		return
	var y := 2.0
	for q in shown:
		y = _quest(q, y, w)
	if _page == "quests" and combat and combat.map.inventory.has("rune_of_return"):
		var tip := _text(Vector2(10, y + 8), w, CombatHud.COL_DIM)
		tip.text = "Rune of Return: click it in the Bag (I) to open a portal back to the trader. Step through it again to come back." \
				if RunePortal.bound else "Rune of Return: it isn't bound to anywhere here yet. A trader nearby may be able to rebind it."
		y += 8 + 22
	_fit(y)


## Every quest the party has been given, main first: {key, title, kind, giver, where, gold, item,
## claimed, stages, cur, is_done (Callable: stage id -> bool), done}.
static func quests() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if Quest.given:
		out.append({key = MAIN, title = Quest.title(), kind = "main quest", giver = Quest.giver(),
				where = Modules.current.quest_where if Modules.current else "",
				gold = Quest.reward_gold(), item = Quest.reward_item(), claimed = Quest.claimed,
				stages = Quest.stages(), cur = Quest.current(), done = Quest.current() == -1,
				is_done = func(sid): return Quest.is_done(sid)})
	for q in Quest.side_quests():
		if not Quest.side_given(q.id):
			continue
		var qid: String = q.id
		var cur := Quest.side_current(qid)
		out.append({key = qid, title = String(q.title), kind = "side quest", giver = q.get("giver", ""),
				where = q.get("where", ""), gold = int(q.get("reward_gold", 0)), item = q.get("reward_item", ""),
				claimed = Quest.side_claimed(qid), stages = q.stages, cur = cur, done = cur == -1,
				is_done = func(sid): return Quest.side.get(qid, {}).get("done", {}).has(sid)})
	return out


## One quest: its name as a button ("+" folded, "-" open); open = giver, reward and stages below.
func _quest(q: Dictionary, y: float, w: float) -> float:
	var open: bool = _open.get(q.key, false)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "%s %s  (%s)" % ["-" if open else "+", String(q.title).to_upper(), q.kind]
	b.position = Vector2(6, y)
	b.add_theme_font_size_override("font_size", 10)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, COL_DONE if q.done else CombatHud.COL_BANNER)
	b.pressed.connect(func():
		_open.clear()                    # one open at a time: four open quests would overflow the screen
		_open[q.key] = not open
		Sfx.play("ui_select", -10.0)
		_build())
	_body.add_child(b)
	b.set_deferred("size", Vector2(w + 8, 14))
	y += 16
	if not open:
		return y
	var by := _label(_body, Vector2(16, y), CombatHud.COL_DIM)
	by.text = "From %s, %s." % [q.giver, q.where]
	y += 12
	y = _reward_line(y, q.gold, q.item, q.claimed, 16)
	y = _stages(y, w, q.stages, q.cur, q.is_done)
	if q.done:
		var done := _label(_body, Vector2(16, y), COL_DONE)
		done.text = "Quest complete!"
		y += 12
	return y + 6


func _reward_line(y: float, gold: int, item_id: String, claimed: bool, x := 10.0) -> float:
	var rw := _label(_body, Vector2(x, y), CombatHud.COL_GOLD)
	var it := ItemData.get_item(item_id) if item_id != "" else null
	rw.text = "Reward: %d gold%s%s" % [gold, (" and a %s" % it.display_name) if it else "", "  (claimed)" if claimed else ""]
	return y + 14


## The stages: the last few done (ticked; older ones summed up in one line), then the current one.
func _stages(y: float, w: float, st: Array, cur: int, is_done: Callable, ind := 6.0) -> float:
	var done_idx: Array[int] = []
	for i in st.size():
		if is_done.call(st[i].id):
			done_idx.append(i)
	const SHOW := 3
	if done_idx.size() > SHOW:
		var more := _label(_body, Vector2(24 + ind, y), COL_DONE.darkened(0.25))
		more.text = "(%d earlier steps done)" % (done_idx.size() - SHOW)
		y += 12
		done_idx = done_idx.slice(done_idx.size() - SHOW)
	for i in done_idx:
		var tick := TextureRect.new()
		tick.texture = tick_texture()
		tick.position = Vector2(12 + ind, y + 2)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(tick)
		var l := _label(_body, Vector2(24 + ind, y), COL_DONE)
		l.text = st[i].text
		y += 12
	if cur >= 0:
		var arrow := _label(_body, Vector2(12 + ind, y), CombatHud.COL_ACTIVE)
		arrow.text = ">"
		var l := _text(Vector2(24 + ind, y), w - 14 - ind, CombatHud.COL_TEXT)
		l.text = st[cur].text
		y += 12 * maxi(1, ceili(CombatHud.FONT.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x / (w - 14 - ind)))
	return y


## Size the panel to its content (body height `h`), centred above the party panel.
func _fit(h: float) -> void:
	size = Vector2(RECT.size.x, 22 + h + 8)
	position = Vector2(RECT.position.x, roundf((CombatHud.SCREEN.y - CombatHud.PANEL_H - size.y) / 2.0))


## A 7x6 green tick (the pixel font has no tick).
static func tick_texture() -> Texture2D:
	if _tick_tex == null:
		var rows := [
			"......#",
			".....##",
			"#...##.",
			"##.##..",
			".###...",
			"..#....",
		]
		var img := Image.create_empty(7, 6, false, Image.FORMAT_RGBA8)
		for y in rows.size():
			for x in rows[y].length():
				if rows[y][x] == "#":
					img.set_pixel(x, y, COL_DONE.lightened(0.15))
		_tick_tex = ImageTexture.create_from_image(img)
	return _tick_tex


func _label(parent: Control, pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _text(pos: Vector2, w: float, col: Color) -> Label:
	var l := _label(_body, pos, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size = Vector2(w, 0)
	return l


## The journal: titles down the left (the latest at the bottom), the chosen entry's text on the right.
func _journal() -> void:
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	if Quest.lore.is_empty():
		var l := _text(Vector2(10, 4), RECT.size.x - 24, CombatHud.COL_DIM)
		l.text = "Nothing in the journal yet. Books, inscriptions and letters the party reads are kept here."
		_fit(40.0)
		return
	var sel := _sel if _sel >= 0 and _sel < Quest.lore.size() else Quest.lore.size() - 1
	const LIST_W := 128.0
	const ROWS := 14
	var first := maxi(0, mini(sel - ROWS / 2, Quest.lore.size() - ROWS))
	var y := 2.0
	for i in range(first, mini(Quest.lore.size(), first + ROWS)):
		var e: Dictionary = Quest.lore[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.flat = i != sel
		b.text = String(e.title)
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.position = Vector2(8, y)
		b.add_theme_font_size_override("font_size", 10)
		b.add_theme_color_override("font_color", CombatHud.COL_BANNER if i == sel else CombatHud.COL_TEXT)
		b.pressed.connect(func():
			_sel = i
			Sfx.play("ui_select", -10.0)
			_build())
		_body.add_child(b)
		b.set_deferred("size", Vector2(LIST_W, 14))
		y += 15
	var rule := ColorRect.new()
	rule.color = CombatHud.COL_EDGE
	rule.position = Vector2(LIST_W + 14, 2)
	rule.size = Vector2(1, maxf(y, 120.0) - 4)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(rule)
	var e: Dictionary = Quest.lore[sel]
	var t := _label(_body, Vector2(LIST_W + 22, 2), CombatHud.COL_BANNER)
	t.text = String(e.title)
	var body := _text(Vector2(LIST_W + 22, 16), RECT.size.x - LIST_W - 34, CombatHud.COL_TEXT)
	body.text = String(e.text)
	var th := CombatHud.FONT.get_multiline_string_size(body.text, HORIZONTAL_ALIGNMENT_LEFT, body.size.x, 10).y
	var h := maxf(y, 22.0 + th + 12.0)
	rule.size = Vector2(1, h - 4)
	_fit(h)
