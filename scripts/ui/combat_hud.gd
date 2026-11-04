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
	combat.victory.connect(_on_victory)
	combat.defeat.connect(_on_defeat)
	_build_end_screen()
	visible = false


## True if the mouse is over the bottom panel (map input should ignore it).
func mouse_over_ui() -> bool:
	return visible and _panel.get_global_rect().has_point(_panel.get_global_mouse_position())


func _process(_delta: float) -> void:
	if not visible or combat == null:
		return
	var cur := combat.current
	_banner.text = ("%s'S TURN" % cur.display_name().to_upper()) if cur else ""
	_next.text = _upcoming()
	for card in _cards:
		_update_card(card, cur)
	var hero_turn := cur is Hero and not combat.moving
	_set_button(_buttons.attack, hero_turn and combat.attacks_left > 0, hero_turn and combat.attacks_left > 0)
	_set_button(_buttons.spell, false, false)
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
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(card)
		var frame := Panel.new()
		frame.position = Vector2(3, 3)
		frame.size = Vector2(36, 36)
		frame.add_theme_stylebox_override("panel", _box(Color8(16, 14, 20), COL_EDGE))
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frame)
		var pic := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = h.sprite.texture
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
		var pips: Array[ColorRect] = []
		var slots := h.stats.spell_slots[0] if h.stats.spell_slots.size() > 0 else 0
		for s in slots:
			var pip := ColorRect.new()
			pip.position = Vector2(3 + s * 8, 48)
			pip.size = Vector2(6, 3)
			pip.color = COL_SLOT
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(pip)
			pips.append(pip)
		_cards.append({hero = h, panel = card, pic = pic, hp = hp_l, cond = cond_l, bar = bar, bar_w = back.size.x, pips = pips})
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
	_buttons.attack.pressed.connect(func(): _hint.text = "Click an enemy marked in orange to attack.")
	_buttons.spell.tooltip_text = "Spells arrive in Phase 3"
	_buttons.item.tooltip_text = "Items arrive in Phase 4"


# --- updating --------------------------------------------------------------------------------

func _update_card(card: Dictionary, cur: Actor) -> void:
	var h: Hero = card.hero
	var active := h == cur
	card.panel.add_theme_stylebox_override("panel", _box(COL_CARD, COL_ACTIVE if active else COL_EDGE))
	card.hp.text = "%d/%d" % [h.hp, h.stats.max_hp]
	card.bar.size.x = roundf(card.bar_w * clampf(float(h.hp) / h.stats.max_hp, 0.0, 1.0))
	card.cond.text = "" if h.is_alive() else "DOWN"
	card.pic.modulate = Color.WHITE if h.is_alive() else Color(0.45, 0.45, 0.55)
	# Spell slots are not spent until Phase 3: all shown as available.
	for p: ColorRect in card.pips:
		p.color = COL_SLOT


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
	combat.map.camera_controller.ui_bottom = PANEL_H


func _on_ended() -> void:
	visible = false
	_lines.clear()
	_log.text = ""
	combat.map.camera_controller.ui_bottom = 0


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
