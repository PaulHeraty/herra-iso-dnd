class_name QuestScreen
extends Panel
## The quest log (Quest button / J): the quest, who gave it, the reward, the stages done so far
## (ticked) and the one the party is on now (later ones stay hidden). Read-only; J, Esc or a click
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
	if not Quest.given:
		var l := _text(Vector2(10, 4), w, CombatHud.COL_DIM)
		l.text = "No quests yet.\n\nSomeone in the Harrow Woods may need help: the old silver mine in the north is a good place to start asking."
		_fit(70.0)
		return
	var y := 2.0
	var t := _label(_body, Vector2(10, y), CombatHud.COL_BANNER)
	t.text = Quest.title().to_upper()
	t.scale = Vector2(2, 2)
	y += 24
	var by := _label(_body, Vector2(10, y), CombatHud.COL_DIM)
	by.text = "From %s, %s." % [Quest.giver(), Modules.current.quest_where if Modules.current else ""]
	y += 12
	var rw := _label(_body, Vector2(10, y), CombatHud.COL_GOLD)
	var ring := ItemData.get_item(Quest.reward_item())
	rw.text = "Reward: %d gold and a %s%s" % [Quest.reward_gold(), ring.display_name if ring else "magic ring",
			"  (claimed)" if Quest.claimed else ""]
	y += 16
	var cur := Quest.current()
	for i in Quest.stages().size():
		var s: Dictionary = Quest.stages()[i]
		if Quest.is_done(s.id):
			var tick := TextureRect.new()
			tick.texture = tick_texture()
			tick.position = Vector2(12, y + 2)
			tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_body.add_child(tick)
			var l := _label(_body, Vector2(24, y), COL_DONE)
			l.text = s.text
			y += 12
		elif i == cur:
			var arrow := _label(_body, Vector2(12, y), CombatHud.COL_ACTIVE)
			arrow.text = ">"
			var l := _text(Vector2(24, y), w - 14, CombatHud.COL_TEXT)
			l.text = s.text
			y += 12 * maxi(1, l.get_line_count())
	if cur == -1:
		var done := _label(_body, Vector2(10, y + 6), CombatHud.COL_BANNER)
		done.text = "Quest complete!"
		y += 18
	elif combat and combat.map.inventory.has("rune_of_return"):
		var tip := _text(Vector2(10, y + 8), w, CombatHud.COL_DIM)
		tip.text = "Rune of Return: click it in the Bag (I) to open a portal back to Brannoc's stall. Step through it again to come back."
		y += 8 + 22
	_fit(y)


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
