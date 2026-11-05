class_name CombatHud
extends CanvasLayer
## Combat UI (after the mock-up, docs/previews/iso_scene.png), in our HerraPixel font:
##   top-left   "X'S TURN" (2x), a hint line, the next turns in order
##   top-right  combat log (colour-coded, wraps in a fixed column, newest at the bottom)
##   bottom     4 hero cards (portrait, name, HP, HP bar, spell-slot pips; active one framed in
##              yellow) + action menu Attack / Spell / Item / Wait (Spell + Item: Phases 3-4)
## Shown only during combat. Reads state from the CombatManager every frame.

const FONT := preload("res://assets/fonts/herra_pixel.fnt")
const SCREEN := Vector2(640, 360)
const PANEL_H := 60
const LOG_W := 250
const LOG_ENTRIES := 9

const COL_BG := Color8(20, 18, 26, 235)
const COL_CARD := Color8(32, 30, 40)
const COL_EDGE := Color8(66, 60, 78)
const COL_ACTIVE := Color8(255, 220, 90)
const COL_TEXT := Color8(220, 216, 228)
const COL_DIM := Color8(140, 134, 152)
const COL_BANNER := Color8(255, 220, 120)
const COL_HP := Color8(235, 110, 100)
const COL_HP_BAR := Color8(196, 52, 48)
const COL_HP_BACK := Color8(58, 22, 28)
const COL_SLOT := Color8(96, 140, 250)
const COL_SLOT_USED := Color8(40, 46, 74)
const COL_LOG_CRIT := Color8(255, 220, 90)
const COL_LOG_BAD := Color8(240, 110, 100)
const COL_LOG_GOOD := Color8(140, 220, 130)
const COL_LOG_MAGIC := Color8(214, 120, 230)
const COL_GOLD := Color8(255, 215, 90)

var combat: CombatManager
var _banner: Label
var _hint: Label
var _next: Label
var _log: RichTextLabel
var _lines: PackedStringArray = []
var _panel: Panel
var _cards: Array[Dictionary] = []
var _buttons := {}


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.size = SCREEN
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_banner = _label(root, Vector2(8, 4), COL_BANNER)
	_banner.scale = Vector2(2, 2)
	_hint = _label(root, Vector2(8, 26), COL_TEXT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.size = Vector2(SCREEN.x - LOG_W - 30, 0)
	_next = _label(root, Vector2(8, 38), COL_DIM)
	_next.size = Vector2(SCREEN.x - LOG_W - 30, 0)
	_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.scroll_active = false
	_log.position = Vector2(SCREEN.x - LOG_W - 6, 4)
	_log.size = Vector2(LOG_W, 0)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_color_override("default_color", COL_TEXT)
	root.add_child(_log)
	_build_panel(root)
	combat.log_line.connect(_on_log)
	combat.status_changed.connect(func(t: String): _hint.text = t)
	combat.combat_started.connect(_on_started)
	combat.combat_ended.connect(_on_ended)
	combat.turn_started.connect(func(_a: Actor): _close_popup())     # a new turn: any open menu is stale
	combat.announce.connect(_on_announce)
	combat.victory.connect(_on_victory)
	combat.defeat.connect(_on_defeat)
	_build_end_screen()
	_build_rest_buttons()
	# The party panel stays up while exploring too (HP, slots, conditions, rests).
	visible = true
	combat.map.camera_controller.ui_bottom = PANEL_H


## True if the mouse is over the bottom panel (map input should ignore it).
func mouse_over_ui() -> bool:
	if not visible:
		return false
	if _panel.get_global_rect().has_point(_panel.get_global_mouse_position()):
		return true
	return _popup.visible and _popup.get_global_rect().has_point(_popup.get_global_mouse_position())


func _process(_delta: float) -> void:
	if not visible or combat == null:
		return
	if _loot:
		_loot_t -= _delta
		if _loot_t <= 0.0:
			_close_loot()
	var cur := combat.current
	if _announce_t > 0.0:
		if combat.map.dice == null or not combat.map.dice.visible:   # hold it through the dice scene
			_announce_t -= _delta
	else:
		_banner.add_theme_color_override("font_color", COL_BANNER)
		_banner.text = ("%s'S TURN" % cur.display_name().to_upper()) if cur else ""
	_next.text = _upcoming()
	# "Next:" always sits below the hint, however many lines the hint wraps to.
	_next.position.y = _hint.position.y + maxf(12.0, _hint.get_line_count() * 11.0) + 1.0
	for card in _cards:
		_update_card(card, cur)
	# Exploring: rest buttons instead of the combat actions.
	var fighting := combat.in_combat
	for b: Button in _buttons.values():
		b.visible = fighting
	for b: Button in _rest_buttons:
		b.visible = not fighting
	_gold.visible = not fighting
	_gold.text = "Gold  %d" % combat.map.inventory.gold if combat.map.inventory else ""
	if not fighting:
		_banner.text = ""
		_next.text = ""
		return
	var hero_turn := cur is Hero and not combat.moving
	var busy := combat.targeting != null
	_set_button(_buttons.attack, hero_turn and combat.attacks_left > 0, hero_turn and combat.attacks_left > 0 and not busy and _popup_kind != "spell")
	if cur:
		_buttons.spell.text = _buttons.spell.text.replace("Spell", "Ability") if cur.stats.spell_ability == "" else _buttons.spell.text.replace("Ability", "Spell")
	_set_button(_buttons.spell, hero_turn and not cur.stats.powers.is_empty(), hero_turn and (busy or _popup_kind == "spell"))
	if not hero_turn and _popup.visible:
		_close_popup()
	_set_button(_buttons.item, false, false)
	_set_button(_buttons.wait, hero_turn, false)


# --- building --------------------------------------------------------------------------------

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 10
	t.set_color("font_shadow_color", "Label", Color8(8, 6, 10))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_color("font_shadow_color", "RichTextLabel", Color8(8, 6, 10))
	t.set_constant("shadow_offset_x", "RichTextLabel", 1)
	t.set_constant("shadow_offset_y", "RichTextLabel", 1)
	t.set_constant("line_separation", "RichTextLabel", 0)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := _box(COL_CARD, COL_EDGE)
		if state == "hover":
			sb.border_color = COL_TEXT
		if state == "pressed":
			sb.bg_color = COL_EDGE
		sb.content_margin_left = 5
		sb.content_margin_right = 2
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		t.set_stylebox(state, "Button", sb)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", COL_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color8(84, 80, 96))
	return t


func _box(bg: Color, edge: Color, width := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(width)
	sb.anti_aliasing = false
	return sb


func _label(parent: Control, pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_panel(root: Control) -> void:
	_panel = Panel.new()
	_panel.position = Vector2(0, SCREEN.y - PANEL_H)
	_panel.size = Vector2(SCREEN.x, PANEL_H)
	var sb := _box(COL_BG, COL_EDGE)
	sb.border_width_left = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 0
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_panel)
	var card_w := 121
	for i in combat.map.party.size():
		var h: Hero = combat.map.party[i]
		var card := Panel.new()
		card.position = Vector2(4 + i * (card_w + 3), 3)
		card.size = Vector2(card_w, PANEL_H - 6)
		# Clicking a portrait picks that hero while targeting (or centres the camera on them).
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_card_input.bind(h))
		card.mouse_entered.connect(func(): combat.hover_card = h)
		card.mouse_exited.connect(func(): if combat.hover_card == h: combat.hover_card = null)
		_panel.add_child(card)
		var frame := Panel.new()
		frame.position = Vector2(3, 3)
		frame.size = Vector2(36, 36)
		frame.add_theme_stylebox_override("panel", _box(Color8(16, 14, 20), COL_EDGE))
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frame)
		var pic := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = h.walk_texture() if h is Hero else h.sprite.texture
		at.region = Rect2(0, 0, 16, 16)          # head and shoulders of the front idle frame
		pic.texture = at
		pic.position = Vector2(2, 2)
		pic.size = Vector2(32, 32)
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(pic)
		var name_l := _label(card, Vector2(43, 3), COL_TEXT)
		name_l.text = h.display_name()
		var hp_l := _label(card, Vector2(43, 15), COL_HP)
		var cond_l := _label(card, Vector2(43, 27), COL_DIM)
		var back := ColorRect.new()
		back.color = COL_HP_BACK
		back.position = Vector2(3, 42)
		back.size = Vector2(card_w - 6, 4)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(back)
		var bar := ColorRect.new()
		bar.color = COL_HP_BAR
		bar.position = back.position
		bar.size = back.size
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(bar)
		# Spell-slot pips: one group per spell level (Cleric/Mage: 4 / 3 / 2).
		var pips: Array[Dictionary] = []
		var px := 3
		for lvl in h.stats.spell_slots.size():
			for s in h.stats.spell_slots[lvl]:
				var pip := ColorRect.new()
				pip.position = Vector2(px, 48)
				pip.size = Vector2(6, 3)
				pip.color = COL_SLOT
				pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.add_child(pip)
				pips.append({rect = pip, level = lvl, index = s})
				px += 8
			px += 4
		# Condition icons (hover: name + effect) and death-save pips.
		var icons: Array[TextureRect] = []
		for k in 7:
			var ic := TextureRect.new()
			var at2 := AtlasTexture.new()
			at2.atlas = Condition.ICONS
			at2.region = Rect2(0, 0, Condition.ICON_SIZE, Condition.ICON_SIZE)
			ic.texture = at2
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ic.position = Vector2(43 + k * 10, 28)
			ic.size = Vector2(9, 9)
			ic.mouse_filter = Control.MOUSE_FILTER_PASS
			ic.visible = false
			ic.mouse_entered.connect(func(): _hint.text = ic.tooltip_text)
			card.add_child(ic)
			icons.append(ic)
		var dpips: Array[ColorRect] = []
		for k in 6:
			var dp := ColorRect.new()
			dp.position = Vector2(54 + k * 5 + (4 if k >= 3 else 0), 31)
			dp.size = Vector2(4, 3)
			dp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dp.visible = false
			card.add_child(dp)
			dpips.append(dp)
		_cards.append({hero = h, panel = card, pic = pic, hp = hp_l, cond = cond_l, bar = bar, bar_w = back.size.x, pips = pips, icons = icons, dpips = dpips})
	# Action menu.
	var mx := 4 + 4 * (card_w + 3)
	var labels := [["attack", "Attack"], ["spell", "Spell"], ["item", "Item"], ["wait", "Wait"]]
	for i in labels.size():
		var b := Button.new()
		b.text = labels[i][1]
		b.position = Vector2(mx, 3 + i * 14)
		b.size = Vector2(SCREEN.x - mx - 4, 13)
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_panel.add_child(b)
		_buttons[labels[i][0]] = b
	_fix_button_sizes.call_deferred(SCREEN.x - mx - 4)
	_buttons.wait.pressed.connect(func(): if combat.current is Hero and not combat.moving: combat.end_turn())
	_buttons.attack.pressed.connect(_open_weapons)
	_buttons.spell.pressed.connect(_open_powers)
	_build_popup(root)
	_build_reaction(root)
	_buttons.item.tooltip_text = "Items arrive in Phase 4"


# --- updating --------------------------------------------------------------------------------

func _update_card(card: Dictionary, cur: Actor) -> void:
	var h: Hero = card.hero
	var active := h == cur
	# Frame: picked target (bright, 2px) > valid target while targeting (green) > active hero (yellow).
	var edge := COL_ACTIVE if active else COL_EDGE
	var width := 1
	if combat.targeting:
		if h in combat.picked:
			edge = Color8(255, 244, 170)
			width = 2
		elif combat.is_valid_pick(h):
			edge = Color8(120, 220, 140)
			width = 2 if combat.hover_card == h else 1
	card.panel.add_theme_stylebox_override("panel", _box(COL_CARD, edge, width))
	card.hp.text = "%d/%d" % [h.hp, h.stats.max_hp]
	card.bar.size.x = roundf(card.bar_w * clampf(float(h.hp) / h.stats.max_hp, 0.0, 1.0))
	card.cond.text = "DEAD" if h.dead else ""
	var ids := Condition.shown_ids(h) if not h.dead else PackedStringArray()
	var dying := CombatManager._is_dying(h)
	for k in card.icons.size():
		var ic: TextureRect = card.icons[k]
		# while dying the icon row holds just the heart, followed by the death-save pips
		var show: bool = k < ids.size() and (not dying or k == 0)
		ic.visible = show
		if show:
			(ic.texture as AtlasTexture).region = Condition.icon_rect(ids[k])
			ic.tooltip_text = Condition.tooltip(h, ids[k])
	for k in card.dpips.size():
		var dp: ColorRect = card.dpips[k]
		dp.visible = dying
		if k < 3:
			dp.color = Color8(110, 210, 120) if k < h.death_successes else Color8(36, 60, 40)
		else:
			dp.color = Color8(220, 60, 60) if (k - 3) < h.death_failures else Color8(70, 26, 30)
	card.pic.modulate = Color.WHITE if h.is_alive() else Color(0.45, 0.45, 0.55)
	for p: Dictionary in card.pips:
		var left: int = h.slots_left[p.level] if p.level < h.slots_left.size() else 0
		p.rect.color = COL_SLOT if p.index < left else COL_SLOT_USED


## Buttons size themselves with the default font before our theme applies; reset once it has.
func _fix_button_sizes(w: float) -> void:
	for b: Button in _buttons.values():
		b.size = Vector2(w, 13)


func _set_button(b: Button, enabled: bool, selected: bool) -> void:
	b.disabled = not enabled
	var base := b.text.trim_prefix("> ")
	b.text = ("> " + base) if selected else base
	b.add_theme_color_override("font_color", COL_ACTIVE if selected else COL_TEXT)


func _upcoming() -> String:
	if combat.order.is_empty() or combat.current == null:
		return ""
	var names: PackedStringArray = []
	var i := combat.order.find(combat.current)
	for k in range(1, combat.order.size()):
		var a: Actor = combat.order[(i + k) % combat.order.size()]
		if a.is_alive():
			names.append(a.display_name())
		if names.size() >= 4:
			break
	return "Next: " + ", ".join(names) if not names.is_empty() else ""


func _on_log(text: String) -> void:
	var col := COL_TEXT
	if text.contains("CRITICAL") :
		col = COL_LOG_CRIT
	elif text.contains("is down") or text.contains("has fallen"):
		col = COL_LOG_BAD
	elif text.contains("slain") or text.contains("Victory"):
		col = COL_LOG_GOOD
	elif text.contains("spots") or text.contains("joins"):
		col = COL_LOG_MAGIC
	elif text.begins_with("--") or text.begins_with("Initiative"):
		col = COL_DIM
	elif text.begins_with("  "):
		col = Color8(190, 186, 200)
	_lines.append("[color=#%s]%s[/color]" % [col.to_html(false), _escape(text.strip_edges())])
	while _lines.size() > LOG_ENTRIES:
		_lines.remove_at(0)
	_log.text = "[right]" + "\n".join(_lines) + "[/right]"


static func _escape(s: String) -> String:
	return s.replace("[", "[lb]")


func _on_started() -> void:
	visible = true


func _on_ended() -> void:
	_lines.clear()
	_log.text = ""
	_hint.text = ""


# --- end of combat -------------------------------------------------------------------------

var _end_layer: CanvasLayer
var _end_dim: ColorRect
var _end_big: Label
var _end_small: Label


func _build_end_screen() -> void:
	_end_layer = CanvasLayer.new()
	_end_layer.layer = 12
	add_sibling.call_deferred(_end_layer)
	var root := Control.new()
	root.size = SCREEN
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	_end_layer.add_child(root)
	_end_dim = ColorRect.new()
	_end_dim.size = SCREEN
	_end_dim.color = Color(0.02, 0.01, 0.04, 0.6)
	_end_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_end_dim)
	_end_big = _label(root, Vector2.ZERO, COL_BANNER)
	_end_small = _label(root, Vector2.ZERO, COL_TEXT)
	_end_layer.visible = false


## Centre a label horizontally at height y, drawn at `scale_k`x.
func _centre(l: Label, text: String, y: float, scale_k: float) -> void:
	l.text = text
	l.scale = Vector2(scale_k, scale_k)
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x * scale_k
	l.position = Vector2(roundf((SCREEN.x - w) / 2.0), y)


func _on_victory(xp: int) -> void:
	_end_dim.visible = false
	_end_big.add_theme_color_override("font_color", COL_BANNER)
	_centre(_end_big, "VICTORY!", 120, 3)
	_centre(_end_small, "+%d XP" % xp, 160, 1)
	_end_layer.visible = true
	var r := _end_big.get_parent() as Control
	r.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(r, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _end_layer.visible = false; r.modulate.a = 1.0)


func _on_defeat() -> void:
	_end_dim.visible = true
	_end_big.add_theme_color_override("font_color", COL_LOG_BAD)
	_centre(_end_big, "THE PARTY HAS FALLEN", 130, 2)
	_centre(_end_small, "Press R to try again", 164, 1)
	_end_layer.visible = true


# --- submenus: spells/abilities and weapon choice -----------------------------------------------

const POPUP_W := 196
const ROW_H := 13

var _popup: Panel
var _popup_rows: VBoxContainer
var _popup_kind := ""
var _info: Panel
var _info_title: Label
var _info_text: Label


func _build_popup(root: Control) -> void:
	_popup = Panel.new()
	_popup.add_theme_stylebox_override("panel", _box(COL_BG, COL_EDGE))
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.visible = false
	root.add_child(_popup)
	# Description box: sits just above the popup while a row is hovered.
	_info = Panel.new()
	_info.add_theme_stylebox_override("panel", _box(COL_BG, COL_EDGE))
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	root.add_child(_info)
	_info_title = _label(_info, Vector2(5, 3), COL_BANNER)
	_info_text = _label(_info, Vector2(5, 14), COL_TEXT)
	_info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_text.size = Vector2(POPUP_W - 10, 0)
	_popup_rows = VBoxContainer.new()
	_popup_rows.position = Vector2(3, 3)
	_popup_rows.add_theme_constant_override("separation", 1)
	_popup.add_child(_popup_rows)


func _close_popup() -> void:
	_popup.visible = false
	_popup_kind = ""
	if _info:
		_info.visible = false


## Popup rows: [{text, tag, ok, why, desc, pick: Callable}]
func _show_popup(kind: String, rows: Array) -> void:
	if _popup.visible and _popup_kind == kind:
		_close_popup()
		return
	for c in _popup_rows.get_children():
		c.queue_free()
	for r: Dictionary in rows:
		var b := Button.new()
		b.text = r.text
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(POPUP_W - 6, ROW_H)
		b.disabled = not r.ok
		var tag := Label.new()
		tag.text = r.tag
		tag.add_theme_color_override("font_color", COL_DIM if r.ok else Color8(84, 80, 96))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tag.size = Vector2(POPUP_W - 12, ROW_H)
		tag.position = Vector2(0, 1)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tag)
		var info: String = r.desc if r.ok else "%s: %s" % [r.text, r.why]
		var title: String = r.text.trim_prefix("> ")
		b.mouse_entered.connect(func(): _show_info(title, info))
		b.mouse_exited.connect(func(): _info.visible = false)
		var pick: Callable = r.pick
		b.pressed.connect(func():
			_close_popup()
			pick.call())
		_popup_rows.add_child(b)
	var h := rows.size() * (ROW_H + 1) + 5
	_popup.size = Vector2(POPUP_W, h)
	_popup.position = Vector2(SCREEN.x - POPUP_W - 4, SCREEN.y - PANEL_H - h - 2)
	_info.visible = false
	_popup_kind = kind
	_popup.visible = true


func _open_powers() -> void:
	var h := combat.current
	if not h is Hero or combat.moving:
		return
	if combat.targeting:
		combat.cancel_targeting()
	var rows := []
	for m: Dictionary in combat.menu_powers(h):
		var p: SpellData = m.power
		var tag: String = m.tag
		if p.uses_slot():
			var lvl := h.lowest_slot_for(p)
			tag = "%s  %d left" % [tag, h.slots_left[p.level - 1] if p.level <= h.slots_left.size() else 0] if lvl == p.level or lvl == 0 else "%s (%s)" % [tag, CombatManager.power_tag_level(lvl)]
		var pick := func(): combat.begin_targeting(p)
		if p.id == "shove":
			pick = func(): _open_shove(p)
		rows.append({text = p.display_name, tag = tag, ok = m.ok, why = m.why, desc = p.description, pick = pick})
	if rows.is_empty():
		return
	_show_popup("spell", rows)


func _open_weapons() -> void:
	var h := combat.current
	if not h is Hero or combat.moving:
		return
	if combat.targeting:
		combat.cancel_targeting()
	var attacks: Array = h.stats.attacks
	if attacks.size() <= 1:
		_hint.text = "Click an enemy marked in orange to attack."
		return
	var rows := [{text = "Best weapon", tag = "auto", ok = true, why = "", desc = "Use whichever attack does the most expected damage.",
			pick = func(): combat.choose_weapon(null)}]
	for a: AttackData in attacks:
		var rng := "reach" if a.kind == AttackData.Kind.MELEE else "%d/%d ft" % [a.range_ft, a.long_range_ft]
		var tag := "%+d %s" % [h.stats.attack_bonus(a), h.stats.damage_expr(a)]
		var chosen := combat.chosen_attack == a
		rows.append({text = ("> " if chosen else "") + a.name, tag = tag, ok = true, why = "",
				desc = "%s: %s %s, %s" % [a.name, h.stats.damage_expr(a), a.damage_type, rng],
				pick = func(): combat.choose_weapon(a)})
	_show_popup("attack", rows)


func _on_card_input(event: InputEvent, h: Hero) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if combat.targeting:
		if not combat.pick_target(h):
			_hint.text = "%s can't be targeted with %s (out of range or already picked)." % [h.display_name(), combat.targeting.display_name]
	else:
		combat.map.camera_controller.following = false
		combat.map.camera_controller.jump_to(h.position)


## Esc or a click outside the popup (on the map) closes it.
func _unhandled_input(event: InputEvent) -> void:
	if reaction_open() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_Y, KEY_ENTER, KEY_KP_ENTER]:
			_answer(true)
		elif event.keycode in [KEY_N, KEY_ESCAPE]:
			_answer(false)
		get_viewport().set_input_as_handled()
		return
	if not _popup or not _popup.visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_popup()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_close_popup()
		get_viewport().set_input_as_handled()    # the click only closes the menu


# --- reaction prompt (Shield) -------------------------------------------------------------------

var _react: Panel
var _react_text: Label


func _build_reaction(root: Control) -> void:
	_react = Panel.new()
	_react.add_theme_stylebox_override("panel", _box(COL_BG, COL_ACTIVE))
	_react.size = Vector2(300, 64)
	_react.position = ((SCREEN - _react.size) / 2.0 - Vector2(0, 30)).round()
	_react.mouse_filter = Control.MOUSE_FILTER_STOP
	_react.visible = false
	root.add_child(_react)
	var title := _label(_react, Vector2(6, 4), COL_BANNER)
	title.text = "REACTION"
	_react_text = _label(_react, Vector2(6, 15), COL_TEXT)
	_react_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_react_text.size = Vector2(288, 0)
	for i in 2:
		var b := Button.new()
		b.text = "Yes (Y)" if i == 0 else "No (N)"
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(_react.size.x - 118 + i * 58, _react.size.y - 17)
		_react.add_child(b)
		b.pressed.connect(_answer.bind(i == 0))
		b.set_deferred("size", Vector2(54, 13))
	combat.reaction_prompt.connect(_on_reaction_prompt)


func _on_reaction_prompt(text: String) -> void:
	_close_popup()
	_react_text.text = text
	_react.visible = true
	Sfx.play("ui_select")


func _answer(yes: bool) -> void:
	_react.visible = false
	combat.answer_reaction(yes)


func reaction_open() -> bool:
	return _react != null and _react.visible


## Shove: knock prone or push 5 ft, then pick the target.
func _open_shove(p: SpellData) -> void:
	var rows := [
		{text = "Knock prone", tag = "", ok = true, why = "", desc = "Win the contest: the target falls prone (attacks against it up close have advantage).",
				pick = func():
					combat.shove_push = false
					combat.begin_targeting(p)},
		{text = "Push 5 ft", tag = "", ok = true, why = "", desc = "Win the contest: the target is pushed one square away from you (if there is room).",
				pick = func():
					combat.shove_push = true
					combat.begin_targeting(p)},
	]
	_show_popup("shove", rows)


## Show a spell/ability/weapon description in the box above the popup.
func _show_info(title: String, text: String) -> void:
	_info_title.text = title
	_info_text.text = text
	var lines := maxi(1, _info_text.get_line_count())
	var h := 18 + lines * 11
	_info.size = Vector2(POPUP_W, h)
	_info.position = Vector2(_popup.position.x, _popup.position.y - h - 2)
	_info.visible = true


var _announce_t := 0.0


## Big moments replace the turn banner for a moment, in fire orange (mock-up: "MAGE CASTS FIREBALL!").
func _on_announce(text: String) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", Color8(255, 170, 80))
	_announce_t = 2.2


## Show a short message in the hint line (also outside combat, e.g. the F2 dice setting).
func flash_hint(text: String) -> void:
	_hint.text = text
	if not visible:
		print("[hud] ", text)


# --- rests (exploration) -----------------------------------------------------------------------

var _rest_buttons: Array[Button] = []
var _gold: Label


func _build_rest_buttons() -> void:
	var first: Button = _buttons.attack
	var specs := [["Short rest", false], ["Long rest", true]]
	for i in specs.size():
		var b := Button.new()
		b.text = specs[i][0]
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.position = Vector2(first.position.x, 3 + i * 14)
		_panel.add_child(b)
		b.set_deferred("size", Vector2(first.size.x, 13))
		b.pressed.connect(_rest.bind(specs[i][1]))
		b.mouse_entered.connect(func():
			_hint.text = "Long rest: full HP, spell slots and abilities." if specs[i][1] else "Short rest: spend hit dice to heal; Second Wind comes back.")
		_rest_buttons.append(b)
	_gold = _label(_panel, Vector2(first.position.x + 2, 33), COL_GOLD)


func _rest(long: bool) -> void:
	var why := Rest.blocked_reason(combat.map)
	if why != "":
		_hint.text = why
		Sfx.play("fail_sting", -10.0)
		return
	_end_dim.visible = true
	_end_big.text = ""
	_end_small.text = ""
	_end_layer.visible = true
	var root := _end_dim.get_parent() as Control
	root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.35)
	_centre(_end_small, "Resting...", 172, 1)
	await tw.finished
	var lines := Rest.long_rest(combat.map.party) if long else Rest.short_rest(combat.map.party)
	Sfx.play("heal_chime")
	await get_tree().create_timer(0.7).timeout
	var tw2 := create_tween()
	tw2.tween_property(root, "modulate:a", 0.0, 0.35)
	await tw2.finished
	_end_layer.visible = false
	root.modulate.a = 1.0
	_lines.clear()
	_on_log("-- %s rest --" % ("Long" if long else "Short"))
	for l in lines:
		_on_log(l)
	for h: Hero in combat.map.party:
		if not h.dead:
			SpellFx.sparkles(combat.map, h.body_position(), Color8(150, 235, 140), false)
	_hint.text = "%s rest done." % ("Long" if long else "Short")


# --- loot (chests) -----------------------------------------------------------------------------

const LOOT_W := 210
const LOOT_TIME := 7.0               ## the box closes by itself after this long

var _loot: Panel
var _loot_t := 0.0


## Show what was found in a chest: gold + [{id, count}]. Closes on the next click / key, or by
## itself after a few seconds. (Everything is already in the bag.)
func show_loot(gold: int, found: Array[Dictionary]) -> void:
	if _loot:
		_loot.queue_free()
	_loot = Panel.new()
	_loot.add_theme_stylebox_override("panel", _box(COL_BG, COL_GOLD.darkened(0.35)))
	_loot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.get_parent().add_child(_loot)
	var title := _label(_loot, Vector2(6, 3), COL_GOLD)
	title.text = "TREASURE"
	var y := 16.0
	if gold > 0:
		var g := _label(_loot, Vector2(8, y), COL_GOLD)
		g.text = "%d gold" % gold
		y += 11
	for f in found:
		var it := ItemData.get_item(f.id)
		var l := _label(_loot, Vector2(8, y), COL_TEXT)
		l.text = it.display_name + ("  x%d" % f.count if f.count > 1 else "")
		var s := it.summary()
		y += 11
		if s != "":
			var d := _label(_loot, Vector2(16, y), COL_DIM)
			d.text = s
			y += 11
	var hint := _label(_loot, Vector2(6, y + 2), COL_DIM)
	hint.text = "Added to the party bag."
	_loot.size = Vector2(LOOT_W, y + 16)
	_loot.position = Vector2(roundf((SCREEN.x - LOOT_W) / 2.0), 60)
	_loot_t = LOOT_TIME
	_loot.modulate.a = 0.0
	create_tween().tween_property(_loot, "modulate:a", 1.0, 0.15)


func _close_loot() -> void:
	if _loot:
		_loot.queue_free()
		_loot = null


func loot_open() -> bool:
	return _loot != null


func _input(event: InputEvent) -> void:
	# Any click or key closes the loot box (the click still does its normal job).
	if _loot and ((event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed)):
		_close_loot.call_deferred()
