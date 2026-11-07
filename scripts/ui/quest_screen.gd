class_name QuestScreen
extends Panel
## The quest log (Quest button / J): the main quest and any side quests: who gave each, the reward,
## the last few stages done (ticked) and the one the party is on now (later ones stay hidden). Read-only; J, Esc or a click
## on the map closes it. Lives on the CombatHud's root (inherits its theme).

const RECT := Rect2(120, 24, 400, 266)
const COL_DONE := Color8(120, 186, 116)

var combat: CombatManager
var _body: Control

static var _tick_tex: Texture2D


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
	var w := RECT.size.x - 24
	var sides: Array[Dictionary] = []
	for q in Quest.side_quests():
		if Quest.side_given(q.id):
			sides.append(q)
	if not Quest.given and sides.is_empty():
		var l := _text(Vector2(10, 4), w, CombatHud.COL_DIM)
		l.text = "No quests yet.\n\n" + (Modules.current.quest_hint if Modules.current else "")
		_fit(70.0)
		return
	var y := 2.0
	if Quest.given:
		var t := _label(_body, Vector2(10, y), CombatHud.COL_BANNER)
		t.text = Quest.title().to_upper()
		t.scale = Vector2(2, 2)
		y += 24
		var by := _label(_body, Vector2(10, y), CombatHud.COL_DIM)
		by.text = "From %s, %s." % [Quest.giver(), Modules.current.quest_where if Modules.current else ""]
		y += 12
		y = _reward_line(y, Quest.reward_gold(), Quest.reward_item(), Quest.claimed)
		y = _stages(y, w, Quest.stages(), Quest.current(), func(sid): return Quest.is_done(sid))
		if Quest.current() == -1:
			var done := _label(_body, Vector2(10, y + 4), CombatHud.COL_BANNER)
			done.text = "Quest complete!"
			y += 16
	for q in sides:
		y += 6
		var st := _label(_body, Vector2(10, y), CombatHud.COL_BANNER)
		st.text = String(q.title).to_upper() + "  (side quest)"
		y += 12
		var sby := _label(_body, Vector2(10, y), CombatHud.COL_DIM)
		sby.text = "From %s, %s." % [q.get("giver", ""), q.get("where", "")]
		y += 12
		y = _reward_line(y, int(q.get("reward_gold", 0)), q.get("reward_item", ""), Quest.side_claimed(q.id))
		var qid: String = q.id
		y = _stages(y, w, q.stages, Quest.side_current(qid), func(sid): return Quest.side.get(qid, {}).get("done", {}).has(sid))
	if combat and combat.map.inventory.has("rune_of_return"):
		var tip := _text(Vector2(10, y + 8), w, CombatHud.COL_DIM)
		tip.text = "Rune of Return: click it in the Bag (I) to open a portal back to the trader. Step through it again to come back." \
				if RunePortal.bound else "Rune of Return: it isn't bound to anywhere here yet. A trader nearby may be able to rebind it."
		y += 8 + 22
	_fit(y)


func _reward_line(y: float, gold: int, item_id: String, claimed: bool) -> float:
	var rw := _label(_body, Vector2(10, y), CombatHud.COL_GOLD)
	var it := ItemData.get_item(item_id) if item_id != "" else null
	rw.text = "Reward: %d gold%s%s" % [gold, (" and a %s" % it.display_name) if it else "", "  (claimed)" if claimed else ""]
	return y + 14


## The stages: the last few done (ticked; older ones summed up in one line), then the current one.
func _stages(y: float, w: float, st: Array, cur: int, is_done: Callable) -> float:
	var done_idx: Array[int] = []
	for i in st.size():
		if is_done.call(st[i].id):
			done_idx.append(i)
	const SHOW := 3
	if done_idx.size() > SHOW:
		var more := _label(_body, Vector2(24, y), COL_DONE.darkened(0.25))
		more.text = "(%d earlier steps done)" % (done_idx.size() - SHOW)
		y += 12
		done_idx = done_idx.slice(done_idx.size() - SHOW)
	for i in done_idx:
		var tick := TextureRect.new()
		tick.texture = tick_texture()
		tick.position = Vector2(12, y + 2)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(tick)
		var l := _label(_body, Vector2(24, y), COL_DONE)
		l.text = st[i].text
		y += 12
	if cur >= 0:
		var arrow := _label(_body, Vector2(12, y), CombatHud.COL_ACTIVE)
		arrow.text = ">"
		var l := _text(Vector2(24, y), w - 14, CombatHud.COL_TEXT)
		l.text = st[cur].text
		y += 12 * maxi(1, ceili(CombatHud.FONT.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x / (w - 14)))
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
