class_name ShopScreen
extends Panel
## Brannoc's stall (TraderTalk "Trade"): his wares on the left (a list with prices), the party bag
## on the right. Click something to read about it (who in the party can use it, the price), then
## the Buy / Sell button, or double-click to do it at once. Buying costs the item's value; he buys
## for half (not keys or the rune). Esc, "Leave" or a click on the map closes it.
## Lives on the CombatHud's root (inherits its theme).

const RECT := Rect2(16, 6, 608, 290)
const ROW_H := 18
const COLS := 12
const ROWS := 5
const PITCH := 24
const CELL := 22
const BAG_POS := Vector2(308, 36)
const COL_MAGIC := Color8(150, 170, 255)
const COL_GOOD := Color8(140, 220, 130)
const COL_BAD := Color8(240, 110, 100)
const COL_SLOT_BG := Color8(16, 14, 20)
const SELL_SHARE := 0.5

var combat: CombatManager
var stock: Array = []
var trader_name := "Brannoc"

var _title: Label
var _gold: Label
var _list: VBoxContainer
var _rows: Array[Dictionary] = []     ## {panel, id, price}
var _cells: Array[Dictionary] = []    ## {box, icon, count}
var _more: Label
var _info_icon: TextureRect
var _info_title: Label
var _info_sub: Label
var _info_body: RichTextLabel
var _act: Button
var _msg: Label
## What is picked: {side = "buy" / "sell", id}; empty = nothing.
var _sel := {}
var _lit: Panel


func _ready() -> void:
	position = RECT.position
	size = RECT.size
	add_theme_stylebox_override("panel", CombatHud._box_static(CombatHud.COL_BG, CombatHud.COL_EDGE))
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title = _label(self, Vector2(8, 4), CombatHud.COL_BANNER)
	_gold = _label(self, Vector2(200, 4), CombatHud.COL_GOLD)
	var close_l := _label(self, Vector2(RECT.size.x - 60, 4), CombatHud.COL_DIM)
	close_l.text = "Esc: leave"
	_rule(Vector2(4, 17), Vector2(RECT.size.x - 8, 1))
	_rule(Vector2(300, 21), Vector2(1, 247))
	var wares_t := _label(self, Vector2(8, 21), CombatHud.COL_BANNER)
	wares_t.text = "FOR SALE"
	var price_t := _label(self, Vector2(250, 21), CombatHud.COL_DIM)
	price_t.text = "gold"
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(6, 34)
	scroll.size = Vector2(290, 234)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	_list.custom_minimum_size = Vector2(280, 0)
	scroll.add_child(_list)
	var bag_t := _label(self, Vector2(BAG_POS.x, 21), CombatHud.COL_BANNER)
	bag_t.text = "YOUR BAG"
	var bag_h := _label(self, Vector2(BAG_POS.x + 62, 21), CombatHud.COL_DIM)
	bag_h.text = "(click to sell)"
	for r in ROWS:
		for c in COLS:
			var k := r * COLS + c
			var box := _cell_box(BAG_POS + Vector2(c * PITCH, r * PITCH))
			var icon := _icon_rect(box, Vector2(3, 3), 1)
			var cnt := _label(box, Vector2(0, 11), CombatHud.COL_TEXT)
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cnt.size = Vector2(CELL - 1, 10)
			box.gui_input.connect(_on_cell_input.bind(k))
			box.mouse_entered.connect(_hover_cell.bind(k))
			box.mouse_exited.connect(_show_selected)
			_cells.append({box = box, icon = icon, count = cnt})
	_more = _label(self, BAG_POS + Vector2(0, ROWS * PITCH), CombatHud.COL_DIM)
	var info := Panel.new()
	info.position = Vector2(306, 162)
	info.size = Vector2(296, 88)
	info.add_theme_stylebox_override("panel", CombatHud._box_static(CombatHud.COL_CARD, CombatHud.COL_EDGE))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info)
	_info_icon = _icon_rect(info, Vector2(5, 5), 2)
	_info_title = _label(info, Vector2(42, 5), CombatHud.COL_TEXT)
	_info_sub = _label(info, Vector2(42, 17), CombatHud.COL_DIM)
	_info_body = RichTextLabel.new()
	_info_body.bbcode_enabled = true
	_info_body.scroll_active = false
	_info_body.position = Vector2(6, 40)
	_info_body.size = Vector2(286, 46)
	_info_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_body.add_theme_color_override("default_color", CombatHud.COL_TEXT)
	info.add_child(_info_body)
	_act = Button.new()
	_act.focus_mode = Control.FOCUS_NONE
	_act.position = Vector2(306, 254)
	add_child(_act)
	_act.set_deferred("size", Vector2(150, 14))
	_act.pressed.connect(func():
		if _sel.get("side", "") == "buy":
			buy(_sel.id)
		elif _sel.get("side", "") == "sell":
			sell(_sel.id))
	var leave := Button.new()
	leave.text = "Leave"
	leave.focus_mode = Control.FOCUS_NONE
	leave.position = Vector2(RECT.size.x - 56, 254)
	add_child(leave)
	leave.set_deferred("size", Vector2(48, 14))
	leave.pressed.connect(close)
	_msg = _label(self, Vector2(8, 274), CombatHud.COL_DIM)
	combat.map.inventory.changed.connect(_refresh)


# --- open / close ----------------------------------------------------------------------------

func open(wares: Array, who: String) -> void:
	stock = wares
	trader_name = who
	_title.text = "%s'S WARES" % who.to_upper()
	_build_list()
	_sel = {}
	visible = true
	_say("Click something to see it, then Buy or Sell (or double-click).", CombatHud.COL_DIM)
	_refresh()
	Sfx.play("ui_select", -8.0)


func close() -> void:
	visible = false


# --- prices + actions (also used by the tests) --------------------------------------------------

static func buy_price(it: ItemData) -> int:
	return it.value_gp


## What he pays for one (0 = he won't buy it: keys, the rune, worthless things).
static func sell_price(it: ItemData) -> int:
	if it == null or it.kind in [ItemData.Kind.KEY, ItemData.Kind.RUNE]:
		return 0
	return int(it.value_gp * SELL_SHARE)


func _bag() -> Inventory:
	return combat.map.inventory


func buy(item_id: String) -> bool:
	var it := ItemData.get_item(item_id)
	if it == null or item_id not in stock:
		return false
	var price := buy_price(it)
	if _bag().gold < price:
		Sfx.play("fail_sting", -12.0)
		return _say("Not enough gold for the %s (%d gp; you have %d)." % [it.display_name, price, _bag().gold], COL_BAD)
	_bag().gold -= price
	_bag().add(item_id)              # emits changed -> _refresh
	Sfx.play("coins", -4.0)
	_say("Bought the %s for %d gold." % [it.display_name, price], COL_GOOD)
	return true


func sell(item_id: String) -> bool:
	var it := ItemData.get_item(item_id)
	if it == null or not _bag().has(item_id):
		return false
	var price := sell_price(it)
	if price <= 0:
		Sfx.play("fail_sting", -12.0)
		return _say("%s won't buy the %s." % [trader_name, it.display_name], CombatHud.COL_DIM)
	_bag().remove(item_id)
	_bag().add_gold(price)
	Sfx.play("coins", -4.0)
	_say("Sold the %s for %d gold." % [it.display_name, price], COL_GOOD)
	if not _bag().has(item_id):
		_sel = {}
	_refresh()
	return true


func _say(text: String, col: Color) -> bool:
	_msg.text = text
	_msg.add_theme_color_override("font_color", col)
	return false


# --- building / refreshing ------------------------------------------------------------------------

func _build_list() -> void:
	for r in _rows:
		r.panel.queue_free()
	_rows.clear()
	for iid: String in stock:
		var it := ItemData.get_item(iid)
		if it == null:
			continue
		var p := Panel.new()
		p.custom_minimum_size = Vector2(280, ROW_H)
		p.add_theme_stylebox_override("panel", CombatHud._box_static(COL_SLOT_BG, CombatHud.COL_EDGE))
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		_list.add_child(p)
		var ic := _icon_rect(p, Vector2(1, 1), 1)
		ic.texture = it.icon_texture()
		var n := _label(p, Vector2(21, 3), COL_MAGIC if it.is_magic() else CombatHud.COL_TEXT)
		n.text = it.display_name
		var pr := _label(p, Vector2(200, 3), CombatHud.COL_GOLD)
		pr.size = Vector2(74, 10)
		pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pr.text = str(buy_price(it))
		p.gui_input.connect(_on_row_input.bind(iid))
		p.mouse_entered.connect(func(): _describe(it, "buy"))
		p.mouse_exited.connect(_show_selected)
		_rows.append({panel = p, id = iid, price = pr})


func _refresh() -> void:
	if not visible:
		return
	_gold.text = "Gold  %d" % _bag().gold
	for r in _rows:
		var it := ItemData.get_item(r.id)
		r.price.add_theme_color_override("font_color", CombatHud.COL_GOLD if buy_price(it) <= _bag().gold else COL_BAD.darkened(0.2))
		var sel: bool = _sel.get("side", "") == "buy" and _sel.id == r.id
		r.panel.add_theme_stylebox_override("panel", CombatHud._box_static(COL_SLOT_BG, CombatHud.COL_ACTIVE if sel else CombatHud.COL_EDGE))
	var st := _bag().stacks
	for k in _cells.size():
		var c: Dictionary = _cells[k]
		var sel: bool = false
		if k < st.size():
			var it := ItemData.get_item(st[k].id)
			c.icon.texture = it.icon_texture() if it else null
			c.count.text = str(st[k].count) if st[k].count > 1 else ""
			c.icon.modulate = Color.WHITE if sell_price(it) > 0 else Color(1, 1, 1, 0.45)
			sel = _sel.get("side", "") == "sell" and _sel.id == st[k].id
		else:
			c.icon.texture = null
			c.count.text = ""
		c.box.add_theme_stylebox_override("panel", CombatHud._box_static(COL_SLOT_BG, CombatHud.COL_ACTIVE if sel else CombatHud.COL_EDGE))
	_more.text = "+%d more" % (st.size() - _cells.size()) if st.size() > _cells.size() else ""
	_show_selected()


func _show_selected() -> void:
	if _sel.is_empty() or (_sel.side == "sell" and not _bag().has(_sel.id)):
		_sel = {}
		_info_icon.texture = null
		_info_title.text = ""
		_info_sub.text = ""
		_info_body.text = "[color=#%s]Point at something to read about it.[/color]" % CombatHud.COL_DIM.to_html(false)
		_act.visible = false
		return
	_describe(ItemData.get_item(_sel.id), _sel.side)


## Fill the description box; side "buy" (his) or "sell" (yours). Updates the action button when it
## is the picked item.
func _describe(it: ItemData, side: String) -> void:
	if it == null:
		return
	_info_icon.texture = it.icon_texture()
	_info_title.text = it.display_name
	_info_title.add_theme_color_override("font_color", COL_MAGIC if it.is_magic() else CombatHud.COL_TEXT)
	_info_sub.text = it.summary()
	var lines: PackedStringArray = [it.description.get_slice("\n", 0)]
	var users := _who_can_use(it)
	if users != "":
		lines.append(users)
	_info_body.text = "\n".join(lines)
	var picked: bool = _sel.get("side", "") == side and _sel.get("id", "") == it.id
	_act.visible = picked
	if not picked:
		return
	if side == "buy":
		var price := buy_price(it)
		_act.text = "Buy for %d gold" % price
		_act.disabled = price > _bag().gold
	else:
		var price := sell_price(it)
		_act.text = ("Sell for %d gold" % price) if price > 0 else "He won't buy this"
		_act.disabled = price <= 0


## "Can use: Fighter, Cleric" (equipment: trained with it; scrolls: on their spell list).
func _who_can_use(it: ItemData) -> String:
	var names: Array[String] = []
	var relevant := false
	for h: Hero in combat.map.party:
		if it.is_equipment() and it.kind != ItemData.Kind.RING:
			relevant = true
			if Equipment.is_trained(h.base_stats, it):
				names.append(h.display_name())
		elif it.kind == ItemData.Kind.SCROLL and it.spell:
			relevant = true
			if CombatManager.scroll_problem(h, it) == "":
				names.append(h.display_name())
	if not relevant:
		return ""
	if names.is_empty():
		return "[color=#%s]Nobody in the party is trained to use it.[/color]" % COL_BAD.to_html(false)
	return "[color=#%s]%s: %s[/color]" % [COL_GOOD.to_html(false),
			"Can read it" if it.kind == ItemData.Kind.SCROLL else "Trained", ", ".join(names)]


# --- input ----------------------------------------------------------------------------------------

func _on_row_input(e: InputEvent, iid: String) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if e.double_click:
			buy(iid)
		_sel = {side = "buy", id = iid}
		_refresh()


func _on_cell_input(e: InputEvent, k: int) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and k < _bag().stacks.size():
		var iid: String = _bag().stacks[k].id
		if e.double_click and _sel.get("side", "") == "sell" and _sel.id == iid:
			sell(iid)
			return
		_sel = {side = "sell", id = iid}
		_refresh()


func _hover_cell(k: int) -> void:
	if k < _bag().stacks.size():
		_describe(ItemData.get_item(_bag().stacks[k].id), "sell")


# --- helpers ----------------------------------------------------------------------------------------

func _label(parent: Control, pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _rule(pos: Vector2, sz: Vector2) -> void:
	var r := ColorRect.new()
	r.color = CombatHud.COL_EDGE
	r.position = pos
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)


func _cell_box(pos: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(CELL, CELL)
	p.add_theme_stylebox_override("panel", CombatHud._box_static(COL_SLOT_BG, CombatHud.COL_EDGE))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(p)
	return p


func _icon_rect(parent: Control, pos: Vector2, k: int) -> TextureRect:
	var t := TextureRect.new()
	t.position = pos
	t.size = Vector2(16, 16) * k
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t
