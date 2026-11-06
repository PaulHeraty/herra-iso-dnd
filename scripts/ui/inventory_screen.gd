class_name InventoryScreen
extends Panel
## The inventory screen (I): the party bag (gold + a grid of item icons) and one hero's six
## equipment slots, their stats (AC, attacks, saves) and a description box for whatever the
## mouse is over, with what equipping it would change. Equip: click an item in the bag (it goes
## on the hero shown) or drag it onto a slot or a hero tab; take off: click the slot or drag it
## to the bag. Equipment can't change during a fight (the screen is read-only then).
## Lives on the CombatHud's root (inherits its theme); the party cards below select the hero too.

const RECT := Rect2(16, 6, 608, 290)
const COLS := 12
const ROWS := 5
const PITCH := 24
const CELL := 22
const BAG_POS := Vector2(308, 36)
const COL_MAGIC := Color8(150, 170, 255)
const COL_GOOD := Color8(140, 220, 130)
const COL_BAD := Color8(240, 110, 100)
const COL_WARN := Color8(255, 180, 90)
const COL_SLOT_BG := Color8(16, 14, 20)

var combat: CombatManager
var hero: Hero                       ## the hero whose equipment is shown

var _gold: Label
var _tabs: Array[Button] = []
var _slots := {}                     ## slot -> {box, icon, name}
var _cells: Array[Dictionary] = []   ## {box, icon, count, index}
var _stats: RichTextLabel
var _info_icon: TextureRect
var _info_title: Label
var _info_sub: Label
var _info_body: RichTextLabel
var _msg: Label
var _more: Label
var _dragged := false
var _lit: Panel                      ## the cell / slot the mouse is over


func _ready() -> void:
	position = RECT.position
	size = RECT.size
	add_theme_stylebox_override("panel", _box(CombatHud.COL_BG, CombatHud.COL_EDGE))
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var title := _label(self, Vector2(8, 4), CombatHud.COL_BANNER)
	title.text = "INVENTORY"
	_gold = _label(self, Vector2(120, 4), CombatHud.COL_GOLD)
	var close := _label(self, Vector2(RECT.size.x - 92, 4), CombatHud.COL_DIM)
	close.text = "I / Esc: close"
	_rule(Vector2(4, 17), Vector2(RECT.size.x - 8, 1))
	_rule(Vector2(300, 21), Vector2(1, 247))
	# hero tabs
	for i in combat.map.party.size():
		var h: Hero = combat.map.party[i]
		var b := Button.new()
		b.text = h.display_name()
		b.icon = _head(h)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.position = Vector2(8 + i * 72, 21)
		add_child(b)
		b.set_deferred("size", Vector2(70, 20))
		b.pressed.connect(select.bind(h))
		b.set_drag_forwarding(Callable(), _can_drop_on_hero.bind(h), _drop_on_hero.bind(h))
		_tabs.append(b)
	# equipment slots: weapons on the left, armour + rings on the right
	for i in Equipment.SLOTS.size():
		var slot: String = Equipment.SLOTS[i]
		var pos := Vector2(8 + (i / 3) * 146, 47 + (i % 3) * 26)
		var box := _cell_box(pos)
		var icon := _icon_rect(box, Vector2(3, 3), 1)
		var l := _label(self, pos + Vector2(26, 0), CombatHud.COL_DIM)
		l.text = Equipment.SLOT_NAMES[slot]
		var n := _label(self, pos + Vector2(26, 10), CombatHud.COL_TEXT)
		n.clip_text = true
		n.size = Vector2(112, 12)
		box.gui_input.connect(_on_slot_input.bind(slot))
		box.mouse_entered.connect(_hover_slot.bind(slot))
		box.mouse_exited.connect(_hover_none)
		box.set_drag_forwarding(_drag_slot.bind(slot), _can_drop_on_slot.bind(slot), _drop_on_slot.bind(slot))
		_slots[slot] = {box = box, icon = icon, name = n}
	_stats = _rich(Vector2(8, 128), Vector2(286, 140))
	# the bag
	var bag_t := _label(self, Vector2(BAG_POS.x, 21), CombatHud.COL_BANNER)
	bag_t.text = "PARTY BAG"
	var sort := Button.new()
	sort.text = "Sort"
	sort.focus_mode = Control.FOCUS_NONE
	sort.position = Vector2(RECT.size.x - 50, 20)
	add_child(sort)
	sort.set_deferred("size", Vector2(40, 13))
	sort.pressed.connect(func():
		combat.map.inventory.sort()
		Sfx.play("ui_select", -6.0))
	var bag_area := Control.new()
	bag_area.position = BAG_POS - Vector2(2, 2)
	bag_area.size = Vector2(COLS * PITCH + 2, ROWS * PITCH + 2)
	bag_area.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bag_area)
	bag_area.set_drag_forwarding(Callable(), _can_drop_on_bag, _drop_on_bag)
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
			box.mouse_exited.connect(_hover_none)
			box.set_drag_forwarding(_drag_cell.bind(k), _can_drop_on_bag, _drop_on_bag)
			_cells.append({box = box, icon = icon, count = cnt})
	_more = _label(self, BAG_POS + Vector2(0, ROWS * PITCH), CombatHud.COL_DIM)
	# description box
	var info := Panel.new()
	info.position = Vector2(306, 162)
	info.size = Vector2(296, 106)
	info.add_theme_stylebox_override("panel", _box(CombatHud.COL_CARD, CombatHud.COL_EDGE))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info)
	_info_icon = _icon_rect(info, Vector2(5, 5), 2)
	_info_title = _label(info, Vector2(42, 5), CombatHud.COL_TEXT)
	_info_sub = _label(info, Vector2(42, 17), CombatHud.COL_DIM)
	_info_body = _rich(Vector2(6, 40), Vector2(286, 64))
	_info_body.reparent(info, false)
	_msg = _label(self, Vector2(8, 274), CombatHud.COL_TEXT)
	combat.map.inventory.changed.connect(_refresh)


# --- open / close / select ----------------------------------------------------------------------

func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open(h: Hero = null) -> void:
	if h == null:
		h = hero if hero else _first_hero()
	hero = h
	visible = true
	_default_msg()
	_hover_none()
	_refresh()
	Sfx.play("ui_select", -8.0)


func close() -> void:
	visible = false


func select(h: Hero) -> void:
	hero = h
	_default_msg()
	_hover_none()
	_refresh()


func _default_msg() -> void:
	if _locked():
		_say("Equipment can't change during a fight.", COL_WARN)
	else:
		_say("Click an item to equip it on %s, or drag it to a slot or a hero." % hero.display_name(), CombatHud.COL_DIM)


func _first_hero() -> Hero:
	return combat.map.party[0] if not combat.map.party.is_empty() else null


func _locked() -> bool:
	return combat.in_combat


func _bag() -> Inventory:
	return combat.map.inventory


# --- actions (also used by the tests) -------------------------------------------------------------

## Put bag entry `id` on hero `h` (in `slot`, or its usual slot). True if it worked.
func equip(h: Hero, item_id: String, slot := "") -> bool:
	var it := ItemData.get_item(item_id)
	if it == null:
		return false
	if it.kind == ItemData.Kind.POTION:
		return drink(h, item_id)
	if it.kind == ItemData.Kind.SCROLL:
		return read(h, item_id)
	if it.kind == ItemData.Kind.KEY:
		return _say("Keys are used by themselves: click the locked door or chest.", CombatHud.COL_DIM)
	if it.kind == ItemData.Kind.RUNE:
		return use_rune()
	if _locked():
		return _say("Equipment can't change during a fight.", COL_WARN)
	if not it.is_equipment():
		return _say("%s isn't something to wear or wield." % it.display_name, CombatHud.COL_DIM)
	var why := h.equip_from(_bag(), item_id, slot)
	if why != "":
		Sfx.play("fail_sting", -12.0)
		return _say(why + ".", COL_BAD)
	Sfx.play("lock_click", -4.0)
	_say("%s equips the %s." % [h.display_name(), it.display_name], COL_GOOD)
	_refresh()
	return true


## `h` drinks a potion from the bag (exploring only; in a fight it's the Item action).
func drink(h: Hero, item_id: String) -> bool:
	var it := ItemData.get_item(item_id)
	if _locked():
		return _say("In a fight, drink potions with the Item action on the hero's turn.", COL_WARN)
	if h.dead:
		return _say("%s is beyond the help of potions." % h.display_name(), COL_BAD)
	if h.is_alive() and h.hp >= h.stats.max_hp:
		return _say("%s is unhurt: no need for the %s." % [h.display_name(), it.display_name], CombatHud.COL_DIM)
	var got := combat.drink_now(h, item_id)
	if got < 0:
		return false
	_say("%s drinks the %s: +%d HP (%d/%d)." % [h.display_name(), it.display_name, got, h.hp, h.stats.max_hp], COL_GOOD)
	_refresh()
	return true


## A scroll clicked (or dropped on `h`'s tab): healing scrolls are read on `h` by whoever can
## read them (exploring only); others wait for a fight (the Item action).
func read(h: Hero, item_id: String) -> bool:
	var it := ItemData.get_item(item_id)
	if _locked():
		return _say("In a fight, read scrolls with the Item action on the reader's turn.", COL_WARN)
	var r := combat.read_now(h, item_id)
	if r.got < 0:
		Sfx.play("fail_sting", -12.0)
		return _say(r.why, COL_WARN)
	_say("%s reads the %s: %s +%d HP (%d/%d)." % [r.reader.display_name(), it.display_name,
			h.display_name(), r.got, h.hp, h.stats.max_hp], COL_GOOD)
	_refresh()
	return true


## The Rune of Return: open a portal next to the party (DungeonMap.use_rune); the screen closes
## so the portal can be seen.
func use_rune() -> bool:
	var why := combat.map.use_rune()
	if why != "":
		Sfx.play("fail_sting", -12.0)
		return _say(why, COL_WARN)
	close()
	return true


## Take off what `h` has in `slot` (into the bag).
func unequip(h: Hero, slot: String) -> bool:
	if _locked():
		return _say("Equipment can't change during a fight.", COL_WARN)
	var iid := h.unequip_to(_bag(), slot)
	if iid == "":
		return false
	Sfx.play("ui_select", -6.0)
	_say("%s takes off the %s." % [h.display_name(), ItemData.get_item(iid).display_name], CombatHud.COL_TEXT)
	_refresh()
	return true


## Hand what `from` has in `slot` to hero `to` (their usual slot for it).
func give(from: Hero, slot: String, to: Hero) -> bool:
	if _locked():
		return _say("Equipment can't change during a fight.", COL_WARN)
	var iid: String = from.equipment.get(slot, "")
	var it := ItemData.get_item(iid) if iid != "" else null
	if it == null:
		return false
	var why := Equipment.cannot_equip(to.base_stats, it, Equipment.default_slot(it, to.equipment))
	if why != "":
		Sfx.play("fail_sting", -12.0)
		return _say(why + ".", COL_BAD)
	from.unequip_to(_bag(), slot)
	to.equip_from(_bag(), iid)
	Sfx.play("lock_click", -4.0)
	_say("%s hands the %s to %s." % [from.display_name(), it.display_name, to.display_name()], COL_GOOD)
	_refresh()
	return true


func _say(text: String, col: Color) -> bool:
	_msg.text = text
	_msg.add_theme_color_override("font_color", col)
	return false


# --- input ---------------------------------------------------------------------------------------

func _on_cell_input(event: InputEvent, k: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragged = false
		elif not _dragged and k < _bag().stacks.size():
			equip(hero, _bag().stacks[k].id)
			_hover_cell(k)


func _on_slot_input(event: InputEvent, slot: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragged = false
		elif not _dragged:
			unequip(hero, slot)
			_hover_slot(slot)


func _drag_cell(_at: Vector2, k: int) -> Variant:
	if _locked() or k >= _bag().stacks.size():
		return null
	var iid: String = _bag().stacks[k].id
	_dragged = true
	_cells[k].box.set_drag_preview(_preview(ItemData.get_item(iid)))
	return {from = "bag", id = iid}


func _drag_slot(_at: Vector2, slot: String) -> Variant:
	if _locked() or not hero.equipment.has(slot):
		return null
	_dragged = true
	_slots[slot].box.set_drag_preview(_preview(ItemData.get_item(hero.equipment[slot])))
	return {from = "slot", hero = hero, slot = slot, id = hero.equipment[slot]}


func _can_drop_on_slot(_at: Vector2, data: Variant, slot: String) -> bool:
	if not data is Dictionary:
		return false
	var it := ItemData.get_item(data.id)
	return it != null and Equipment.slot_accepts(slot, it) and not (data.from == "slot" and data.slot == slot and data.hero == hero)


func _drop_on_slot(_at: Vector2, data: Variant, slot: String) -> void:
	if data.from == "bag":
		equip(hero, data.id, slot)
	elif data.hero == hero:
		# ring1 <-> ring2: swap them
		var other: String = hero.equipment.get(slot, "")
		hero.equipment.erase(data.slot)
		hero.equipment[slot] = data.id
		if other != "":
			hero.equipment[data.slot] = other
		hero.refresh_stats()
		_refresh()
	else:
		data.hero.unequip_to(_bag(), data.slot)
		equip(hero, data.id, slot)


func _can_drop_on_bag(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.from == "slot"


func _drop_on_bag(_at: Vector2, data: Variant) -> void:
	unequip(data.hero, data.slot)


func _can_drop_on_hero(_at: Vector2, data: Variant, h: Hero) -> bool:
	return data is Dictionary and not (data.from == "slot" and data.hero == h)


func _drop_on_hero(_at: Vector2, data: Variant, h: Hero) -> void:
	if data.from == "bag":
		if equip(h, data.id):
			select(h)
	elif give(data.hero, data.slot, h):
		select(h)


func _preview(it: ItemData) -> Control:
	var c := Control.new()
	var t := TextureRect.new()
	t.texture = it.icon_texture()
	t.position = Vector2(-8, -8)
	t.modulate.a = 0.85
	c.add_child(t)
	return c


# --- hover: the description box ------------------------------------------------------------------

func _hover_cell(k: int) -> void:
	if k < _bag().stacks.size():
		_highlight(_cells[k].box)
		_describe(ItemData.get_item(_bag().stacks[k].id), "", _bag().stacks[k].count)
	else:
		_hover_none()


## Light up the edge of the cell under the mouse (null = none).
func _highlight(box: Panel) -> void:
	if _lit and is_instance_valid(_lit):
		_lit.add_theme_stylebox_override("panel", _box(COL_SLOT_BG, CombatHud.COL_EDGE))
	_lit = box
	if box:
		box.add_theme_stylebox_override("panel", _box(CombatHud.COL_CARD, CombatHud.COL_TEXT))


func _hover_slot(slot: String) -> void:
	_highlight(_slots[slot].box)
	if hero.equipment.has(slot):
		_describe(ItemData.get_item(hero.equipment[slot]), slot, 1)
	else:
		_info_icon.texture = null
		_info_title.text = Equipment.SLOT_NAMES[slot] + ": empty"
		_info_title.add_theme_color_override("font_color", CombatHud.COL_TEXT)
		_info_sub.text = ""
		var what := {main = "a melee weapon", off = "a shield", ranged = "a bow, crossbow or throwing axe",
				armor = "armour", ring1 = "a ring", ring2 = "a ring"}
		_info_body.text = "[color=#%s]Drag %s here from the bag.[/color]" % [CombatHud.COL_DIM.to_html(false), what[slot]]


func _hover_none() -> void:
	_highlight(null)
	_info_icon.texture = null
	_info_title.text = ""
	_info_sub.text = ""
	_info_body.text = "[color=#%s]Point at an item to read about it.[/color]" % CombatHud.COL_DIM.to_html(false)


## Fill the description box for `it`; `slot` != "" = worn by the current hero in that slot.
func _describe(it: ItemData, slot: String, count: int) -> void:
	_info_icon.texture = it.icon_texture()
	_info_title.text = it.display_name + ("  x%d" % count if count > 1 else "")
	_info_title.add_theme_color_override("font_color", COL_MAGIC if it.is_magic() else CombatHud.COL_TEXT)
	_info_sub.text = it.summary()
	var lines: PackedStringArray = [it.description]
	if it.is_equipment():
		if slot != "":
			lines.append(_c("Worn by %s. Click to take it off." % hero.display_name(), CombatHud.COL_DIM))
		else:
			lines.append_array(_compare(hero, it))
	elif it.kind == ItemData.Kind.POTION:
		lines.append(_c("Click: %s drinks it. In a fight: the Item action." % hero.display_name(), CombatHud.COL_DIM))
	elif it.kind == ItemData.Kind.SCROLL and it.spell:
		# one line only: the description box is full
		if it.spell.resolve == SpellData.Resolve.HEAL:
			lines.append(_c("Click: read it to heal %s. In a fight: Item." % hero.display_name(), CombatHud.COL_DIM))
		elif CombatManager.scroll_problem(hero, it) != "":
			lines.append(_c("Not a spell %s can cast." % hero.display_name(), COL_BAD))
		else:
			lines.append(_c("Read it in a fight: the Item action.", CombatHud.COL_DIM))
	elif it.kind == ItemData.Kind.KEY:
		lines.append(_c("Used by itself when you open its lock.", CombatHud.COL_DIM))
	elif it.kind == ItemData.Kind.RUNE:
		lines.append(_c("Click: open a portal back to Brannoc's stall (not in a fight).", CombatHud.COL_DIM))
	if it.value_gp > 0:
		lines.append(_c("Worth %d gp" % it.value_gp, CombatHud.COL_GOLD.darkened(0.15)))
	_info_body.text = "\n".join(lines)


## What putting `it` on `h` would do: can't / not proficient / AC, attack, speed changes.
func _compare(h: Hero, it: ItemData) -> PackedStringArray:
	var out: PackedStringArray = []
	var slot := Equipment.default_slot(it, h.equipment)
	var why := Equipment.cannot_equip(h.base_stats, it, slot)
	if why != "":
		out.append(_c(why + ".", COL_BAD))
		return out
	if it.kind == ItemData.Kind.WEAPON and not Equipment.is_trained(h.base_stats, it):
		out.append(_c("%s isn't proficient: no proficiency bonus to hit." % h.display_name(), COL_WARN))
	var new_eq := Equipment.with_item(h.equipment, it, slot)
	var after := Equipment.build_stats(h.base_stats, new_eq, h.level)
	var before := h.stats
	var changes: PackedStringArray = []
	if after.armor_class != before.armor_class:
		changes.append(_delta("AC %d" % before.armor_class, "%d" % after.armor_class, after.armor_class > before.armor_class))
	if after.item_save_bonus != before.item_save_bonus:
		changes.append(_delta("Saves %+d" % before.item_save_bonus, "%+d" % after.item_save_bonus, after.item_save_bonus > before.item_save_bonus))
	if after.speed_ft != before.speed_ft:
		changes.append(_delta("Speed %d" % before.speed_ft, "%d ft" % after.speed_ft, after.speed_ft > before.speed_ft))
	for t in after.resistances:
		if t not in before.resistances:
			changes.append(_c("+ resist %s" % t, COL_GOOD))
	for t in before.resistances:
		if t not in after.resistances:
			changes.append(_c("- resist %s" % t, COL_BAD))
	for c in after.condition_immunities:
		if c not in before.condition_immunities:
			changes.append(_c("+ never %s" % c, COL_GOOD))
	for c in before.condition_immunities:
		if c not in after.condition_immunities:
			changes.append(_c("- never %s" % c, COL_BAD))
	if it.kind == ItemData.Kind.WEAPON:
		var ranged := it.ranged_slot
		var old_a := _attack_of(before, ranged)
		var new_a := _attack_of(after, ranged)
		if new_a:
			var was := "%s %s" % [old_a.name, _atk(before, old_a)] if old_a else "nothing"
			var better := old_a == null or _expected(after, new_a) >= _expected(before, old_a)
			changes.append("%s -> %s" % [was, _c("%s %s" % [new_a.name, _atk(after, new_a)], COL_GOOD if better else COL_BAD)])
	if not changes.is_empty():
		out.append("  ".join(changes))
	var off: PackedStringArray = []
	for s in Equipment.displaced_by(h.equipment, it, slot):
		off.append(ItemData.get_item(h.equipment[s]).display_name)
	if not off.is_empty():
		out.append(_c("Takes off: " + ", ".join(off), CombatHud.COL_DIM))
	if not _locked():
		out.append(_c("Click: equip on %s. Or drag to a slot / hero." % h.display_name(), CombatHud.COL_DIM))
	return out


static func _attack_of(s: CreatureStats, ranged: bool) -> AttackData:
	for a in s.attacks:
		if (a.kind == AttackData.Kind.RANGED) == ranged and a.name != "Unarmed strike":
			return a
	return null


## Average damage per swing against a typical AC 13 (to colour a weapon swap better / worse).
static func _expected(s: CreatureStats, a: AttackData) -> float:
	var hit := clampf((21.0 - (13 - s.attack_bonus(a))) / 20.0, 0.05, 0.95)
	return hit * Dice.average(s.damage_expr(a))


static func _atk(s: CreatureStats, a: AttackData) -> String:
	return "%+d %s" % [s.attack_bonus(a), s.damage_expr(a)]


static func _delta(before: String, after: String, better: bool) -> String:
	return "%s -> %s" % [before, _c(after, COL_GOOD if better else COL_BAD)]


static func _c(text: String, col: Color) -> String:
	return "[color=#%s]%s[/color]" % [col.to_html(false), text.replace("[", "[lb]")]


# --- refresh -------------------------------------------------------------------------------------

func _refresh() -> void:
	if not visible or hero == null:
		return
	var bag := _bag()
	_gold.text = "Gold  %d" % bag.gold
	for i in _tabs.size():
		var h: Hero = combat.map.party[i]
		var sel := h == hero
		var sb := _box(CombatHud.COL_EDGE if sel else CombatHud.COL_CARD, CombatHud.COL_ACTIVE if sel else CombatHud.COL_EDGE)
		sb.content_margin_left = 3
		for st in ["normal", "hover", "pressed"]:
			_tabs[i].add_theme_stylebox_override(st, sb)
		_tabs[i].modulate = Color.WHITE if not h.dead else Color(0.6, 0.6, 0.7)
	for slot: String in _slots:
		var d: Dictionary = _slots[slot]
		var iid: String = hero.equipment.get(slot, "")
		if iid != "":
			var it := ItemData.get_item(iid)
			d.icon.texture = it.icon_texture()
			d.icon.modulate = Color.WHITE
			d.name.text = it.display_name
			d.name.add_theme_color_override("font_color", COL_MAGIC if it.is_magic() else CombatHud.COL_TEXT)
		else:
			# a dark silhouette of what goes there
			var ghost := {main = "longsword", off = "shield", ranged = "shortbow", armor = "leather_armor", ring1 = "ring", ring2 = "ring"}
			d.icon.texture = ItemData.icon_texture_at(ItemData.ICON_ORDER.find(ghost[slot]))
			d.icon.modulate = Color(0.32, 0.3, 0.4, 0.75)
			d.name.text = "-"
			d.name.add_theme_color_override("font_color", CombatHud.COL_DIM)
	for k in _cells.size():
		var c: Dictionary = _cells[k]
		if k < bag.stacks.size():
			var st: Dictionary = bag.stacks[k]
			var it := ItemData.get_item(st.id)
			c.icon.texture = it.icon_texture() if it else null
			c.count.text = str(st.count) if st.count > 1 else ""
			c.box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			c.icon.texture = null
			c.count.text = ""
			c.box.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var extra := bag.stacks.size() - _cells.size()
	_more.text = "+%d more (sort to see them)" % extra if extra > 0 else ""
	_stats.text = _stats_text(hero)


func _stats_text(h: Hero) -> String:
	var s := h.stats
	var lines: PackedStringArray = []
	lines.append("%s  %s" % [_c("AC %d" % s.armor_class, CombatHud.COL_BANNER), _c("HP %d/%d" % [h.hp, s.max_hp], CombatHud.COL_HP)]
			+ "  Speed %d ft" % s.speed_ft + ("  Saves %+d" % s.item_save_bonus if s.item_save_bonus else ""))
	for a in s.attacks:
		var rng := "" if a.kind == AttackData.Kind.MELEE else ", %d/%d ft" % [a.range_ft, a.long_range_ft]
		var prof := "" if a.proficient else _c(" (not proficient)", COL_WARN)
		lines.append("%s  %s %s%s%s" % [_c(a.name, CombatHud.COL_TEXT), _c(_atk(s, a), COL_GOOD), a.damage_type, rng, prof])
	if s.stealth_disadvantage:
		lines.append(_c("Stealth at disadvantage (armour)", COL_WARN))
	var guards: PackedStringArray = []
	if not s.resistances.is_empty():
		guards.append("Resists " + ", ".join(s.resistances))
	if not s.condition_immunities.is_empty():
		guards.append("Can't be " + ", ".join(s.condition_immunities))
	if not guards.is_empty():
		lines.append(_c(". ".join(guards), COL_MAGIC))
	var arm := ", ".join(h.base_stats.armor_training) if not h.base_stats.armor_training.is_empty() else "none"
	lines.append(_c("Armour: " + arm.replace("shield", "shields"), CombatHud.COL_DIM))
	lines.append(_c("Weapons: " + ", ".join(h.base_stats.weapon_training).replace("_", " "), CombatHud.COL_DIM))
	return "\n".join(lines)


# --- building helpers ----------------------------------------------------------------------------

static func _box(bg: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(1)
	sb.anti_aliasing = false
	return sb


func _label(parent: Control, pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _rich(pos: Vector2, sz: Vector2) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = false
	r.position = pos
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_color_override("default_color", CombatHud.COL_TEXT)
	add_child(r)
	return r


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
	p.add_theme_stylebox_override("panel", _box(COL_SLOT_BG, CombatHud.COL_EDGE))
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


## The hero's head and shoulders (front idle frame), for the tabs.
func _head(h: Hero) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = h.walk_texture()
	at.region = Rect2(0, 0, 16, 16)
	return at
