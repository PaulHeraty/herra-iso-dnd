class_name CharacterSheet
extends Panel
## The character sheet (C / Sheet button / right-click a hero card): one hero's portrait, level and
## XP, HP and hit dice, AC / initiative / speed / proficiency, the six abilities, saving throws,
## skills, attacks, spellcasting (DC, attack, slots left), powers and class features. Hovering an
## attack, power or feature shows what it does. Read-only, also in a fight; updates live while open.
## Hero tabs (or the party cards below) pick the hero. C, Esc or a click on the map closes it.
## Lives on the CombatHud's root (inherits its theme).

const RECT := Rect2(16, 6, 608, 290)
const COL_A := 8.0              ## identity, numbers, abilities, saves
const COL_B := 212.0            ## skills
const COL_C := 362.0            ## attacks, spells, powers, features
const COL_C_W := 238.0
const TIP_W := 224.0
const COL_PROF := Color8(120, 186, 116)
const COL_EXPERT := Color8(255, 215, 90)
const COL_MAGIC := Color8(150, 170, 255)
const COL_WARN := Color8(255, 180, 90)
const ABILITIES := ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
const ABILITY_NAMES := {
	"STR": "Strength", "DEX": "Dexterity", "CON": "Constitution",
	"INT": "Intelligence", "WIS": "Wisdom", "CHA": "Charisma",
}
## Skills in sheet order (CreatureStats.SKILL_ABILITY has them all).
const SKILLS := ["acrobatics", "arcana", "athletics", "deception", "history", "insight",
		"intimidation", "investigation", "medicine", "perception", "persuasion", "religion",
		"sleight_of_hand", "stealth", "survival", "thieves_tools"]
const SKILL_NAMES := {"sleight_of_hand": "Sleight of Hand", "thieves_tools": "Thieves' Tools"}
## What each skill covers (SRD) and, where it matters already, how the game uses it.
const SKILL_INFO := {
	"acrobatics": "Keeping your balance, tumbling, slipping free. Used to resist a Shove and to break free of webs and grapples (whichever is better of Athletics and Acrobatics).",
	"arcana": "Knowledge of spells, magic items, runes and planes. Not used in the game yet.",
	"athletics": "Climbing, jumping, swimming and brute force. Used for Shove, to resist one, to break free of webs, and to force locked doors and chests.",
	"deception": "Hiding the truth with words or a straight face. Not used in the game yet.",
	"history": "Lore of old kingdoms, wars and lost places. Not used in the game yet.",
	"insight": "Reading someone's true intentions. Not used in the game yet.",
	"intimidation": "Getting your way through threats. Not used in the game yet.",
	"investigation": "Searching for clues and working out how things fit together. Not used in the game yet.",
	"medicine": "Tending wounds and judging someone's condition. Not used in the game yet.",
	"perception": "Noticing what's around you. Passive Perception (10 + this) is what a hiding creature's Stealth roll must beat. So far only the Rogue hides in the game, against the enemies' passive Perception.",
	"persuasion": "Winning people over with tact and good nature. Not used in the game yet.",
	"religion": "Lore of gods, rites and the undead. Not used in the game yet.",
	"sleight_of_hand": "Pickpocketing, palming things, nimble hands. Not used in the game yet.",
	"stealth": "Moving unseen and unheard. Hide rolls this against the enemies' passive Perception: success gives advantage on your next attack.",
	"survival": "Tracking, finding the way, reading the wild. Not used in the game yet.",
	"thieves_tools": "Picking locks and disarming traps (a tool, with DEX). The Rogue rolls it against a door's or chest's lock DC.",
}

var combat: CombatManager
var hero: Hero

var _tabs: Array[Button] = []
var _body: Control
var _tip: Panel
var _tip_title: Label
var _tip_sub: Label
var _tip_text: Label
var _sig := ""


func _ready() -> void:
	position = RECT.position
	size = RECT.size
	add_theme_stylebox_override("panel", CombatHud._box_static(CombatHud.COL_BG, CombatHud.COL_EDGE))
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var title := _label(self, Vector2(8, 4), CombatHud.COL_BANNER)
	title.text = "CHARACTER SHEET"
	var close_l := _label(self, Vector2(RECT.size.x - 74, 4), CombatHud.COL_DIM)
	close_l.text = "C / Esc: close"
	_rule(self, Vector2(4, 17), Vector2(RECT.size.x - 8, 1))
	for i in combat.map.party.size():
		var h: Hero = combat.map.party[i]
		var b := Button.new()
		b.text = h.display_name()
		b.icon = h.head_icon()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.position = Vector2(8 + i * 72, 21)
		add_child(b)
		b.set_deferred("size", Vector2(70, 20))
		b.pressed.connect(func():
			select(h)
			Sfx.play("ui_select", -10.0))
		_tabs.append(b)
	_tip = Panel.new()
	_tip.add_theme_stylebox_override("panel", CombatHud._box_static(CombatHud.COL_CARD, CombatHud.COL_ACTIVE.darkened(0.3)))
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip.z_index = 1
	add_child(_tip)
	_tip_title = _label(_tip, Vector2(5, 3), CombatHud.COL_BANNER)
	_tip_sub = _label(_tip, Vector2(5, 14), CombatHud.COL_DIM)
	_tip_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_sub.size = Vector2(TIP_W - 10, 0)
	_tip_sub.add_theme_constant_override("line_spacing", 1)
	_tip_text = _label(_tip, Vector2(5, 26), CombatHud.COL_TEXT)
	_tip_text.add_theme_constant_override("line_spacing", 1)
	_tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_text.size = Vector2(TIP_W - 10, 0)


func toggle(h: Hero = null) -> void:
	if visible and (h == null or h == hero):
		close()
	else:
		open(h)


func open(h: Hero = null) -> void:
	if h == null:
		h = hero if hero else (combat.map.party[0] if not combat.map.party.is_empty() else null)
	if h == null:
		return
	hero = h
	visible = true
	_build()
	Sfx.play("ui_select", -8.0)


func close() -> void:
	visible = false
	_tip.visible = false


func select(h: Hero) -> void:
	hero = h
	_build()


## Rebuild when something on the sheet changed (HP, slots, conditions, level, equipment...).
func _process(_delta: float) -> void:
	if visible and hero and _signature() != _sig:
		_build()


func _signature() -> String:
	var conds := Condition.shown_ids(hero)
	return "%s|%d|%d|%d|%s|%s|%s|%d|%d/%d|%s|%s" % [hero.name, hero.hp, hero.xp, hero.level,
			str(hero.slots_left), str(hero.uses_left), ",".join(conds), hero.hit_dice_left,
			hero.death_successes, hero.death_failures, str(hero.equipment), str(hero.dead)]


# --- building ------------------------------------------------------------------------------------

func _build() -> void:
	_sig = _signature()
	_tip.visible = false
	for i in _tabs.size():
		var h: Hero = combat.map.party[i]
		var sel := h == hero
		var sb := CombatHud._box_static(CombatHud.COL_EDGE if sel else CombatHud.COL_CARD, CombatHud.COL_ACTIVE if sel else CombatHud.COL_EDGE)
		sb.content_margin_left = 3
		for st in ["normal", "hover", "pressed"]:
			_tabs[i].add_theme_stylebox_override(st, sb)
		_tabs[i].modulate = Color.WHITE if not h.dead else Color(0.6, 0.6, 0.7)
		if not _tabs[i].icon is AtlasTexture or (_tabs[i].icon as AtlasTexture).atlas != h.walk_texture():
			_tabs[i].icon = h.head_icon()          # the outfit (and its sprites) changed
	if _body:
		_body.free()
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	move_child(_tip, -1)
	_build_identity()
	_build_numbers()
	_build_abilities()
	_build_skills()
	_build_right()


## Portrait, name, class, level + XP bar, HP bar, hit dice, conditions / death saves.
func _build_identity() -> void:
	var h := hero
	var s := h.stats
	var frame := Panel.new()
	frame.position = Vector2(COL_A, 46)
	frame.size = Vector2(68, 68)
	frame.add_theme_stylebox_override("panel", CombatHud._box_static(Color8(16, 14, 20), CombatHud.COL_EDGE))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(frame)
	var pic := TextureRect.new()
	pic.texture = h.portrait()                  # the 32x32 face at 2x
	pic.position = Vector2(2, 2)
	pic.size = Vector2(64, 64)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if h.dead:
		pic.modulate = Color(0.4, 0.38, 0.45)
	elif h.hp <= 0:
		pic.modulate = Color(0.6, 0.6, 0.7)
	frame.add_child(pic)
	var x := COL_A + 72
	var w := 196.0 - 72
	var name_l := _label(_body, Vector2(x, 44), CombatHud.COL_TEXT)
	name_l.text = h.display_name().to_upper()
	name_l.scale = Vector2(2, 2)
	var cls := _label(_body, Vector2(x, 66), CombatHud.COL_DIM)
	cls.text = Progression.CLASS_TITLES.get(h.base_stats.class_id, h.base_stats.class_id.capitalize())
	var lvl := _label(_body, Vector2(x, 78), CombatHud.COL_BANNER)
	lvl.text = "Level %d" % h.level
	var nxt := Progression.xp_for_next(h.level)
	var xp_l := _right_label(_body, Vector2(x, 78), w, CombatHud.COL_XP.lightened(0.25))
	xp_l.text = "XP %d/%d" % [h.xp, nxt] if nxt > 0 else "XP %d (max)" % h.xp
	var frac := 1.0
	if nxt > 0:
		var base: int = Progression.XP_FOR_LEVEL[h.level - 1]
		frac = clampf(float(h.xp - base) / float(nxt - base), 0.0, 1.0)
	_bar(Vector2(x, 90), w, 2, frac, Color8(36, 28, 50), CombatHud.COL_XP)
	var hp_l := _label(_body, Vector2(x, 95), CombatHud.COL_HP)
	hp_l.text = "HP %d/%d" % [maxi(h.hp, 0), s.max_hp]
	var die := s.hit_dice.substr(s.hit_dice.find("d"))
	var hd := _right_label(_body, Vector2(x, 95), w, CombatHud.COL_DIM)
	hd.text = "Hit dice %d/%d %s" % [h.hit_dice_left, h.level, die]
	_bar(Vector2(x, 107), w, 3, clampf(float(h.hp) / maxf(1.0, s.max_hp), 0.0, 1.0), CombatHud.COL_HP_BACK, CombatHud.COL_HP_BAR)
	# conditions (icons, hover = what they do) or the state of a downed hero
	var y := 113.0
	if h.dead:
		var d := _label(_body, Vector2(x, y), CombatHud.COL_LOG_BAD)
		d.text = "Dead"
		return
	var ids := Condition.shown_ids(h)
	if ids.is_empty():
		var ok := _label(_body, Vector2(x, y), CombatHud.COL_DIM)
		ok.text = "No conditions"
		return
	var ix := x
	for cid in ids:
		var ic := TextureRect.new()
		var at2 := AtlasTexture.new()
		at2.atlas = Condition.ICONS
		at2.region = Condition.icon_rect(cid)
		ic.texture = at2
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.position = Vector2(ix, y + 1)
		ic.size = Vector2(9, 9)
		ic.mouse_filter = Control.MOUSE_FILTER_PASS
		var tip := Condition.tooltip(h, cid)
		var colon := tip.find(": ")
		ic.mouse_entered.connect(_show_tip.bind(ic, tip.substr(0, colon), "", tip.substr(colon + 2)))
		ic.mouse_exited.connect(_hide_tip)
		_body.add_child(ic)
		ix += 11
	if h.hp <= 0:
		var ds := _label(_body, Vector2(ix + 2, y), CombatHud.COL_DIM)
		ds.text = "saves %d/3  fails %d/3" % [h.death_successes, h.death_failures]


## AC, initiative, speed, proficiency bonus: four boxes.
func _build_numbers() -> void:
	var s := hero.stats
	var boxes := [
		["AC", str(s.armor_class), "Armour Class: an attack roll must reach this to hit."],
		["INIT", "%+d" % s.initiative_bonus(), "Initiative: added to the d20 that sets the turn order (DEX modifier)."],
		["SPEED", str(s.speed_ft), "Feet per turn (%d squares)." % s.speed_cells()],
		["PROF", "%+d" % s.proficiency_bonus, "Proficiency bonus: added to attacks, saves and skills the hero is trained in. Grows with level."],
	]
	for i in boxes.size():
		var b: Array = boxes[i]
		var box := _box(Vector2(COL_A + i * 49, 128), Vector2(47, 30))
		var l := _centre_label(box, 2, 47, CombatHud.COL_DIM)
		l.text = b[0]
		var v := _centre_label(box, 11, 23.5, CombatHud.COL_BANNER if i == 0 else CombatHud.COL_TEXT)
		v.text = b[1]
		v.scale = Vector2(2, 2)
		_hover(box, b[0] if b[0] != "INIT" else "Initiative", "", b[2])


## The six ability scores (modifier big, score small) and the saving throws.
func _build_abilities() -> void:
	var s := hero.stats
	for i in ABILITIES.size():
		var ab: String = ABILITIES[i]
		# name, the modifier (2x: 14 px of digits + shadow), the score below it
		var box := _box(Vector2(COL_A + i * 32.6, 162), Vector2(31, 41))
		var l := _centre_label(box, 2, 31, CombatHud.COL_DIM)
		l.text = ab
		var m := _centre_label(box, 11, 15.5, CombatHud.COL_TEXT)
		m.text = "%+d" % s.mod(ab)
		m.scale = Vector2(2, 2)
		var sc := _centre_label(box, 29, 31, CombatHud.COL_DIM)
		sc.text = str(s.score(ab))
		var up := s.score(ab) - hero.base_stats.score(ab)
		_hover(box, ABILITY_NAMES[ab], "Score %d, modifier %+d%s" % [s.score(ab), s.mod(ab),
				(" (+%d from Ability Score Improvement)" % up) if up > 0 else ""], _ability_use(ab))
	var hdr := _label(_body, Vector2(COL_A, 206), CombatHud.COL_BANNER)
	hdr.text = "SAVING THROWS"
	if s.item_save_bonus:
		var rb := _right_label(_body, Vector2(COL_A, 206), 194, COL_MAGIC)
		rb.text = "%+d from rings" % s.item_save_bonus
	for i in ABILITIES.size():
		var ab: String = ABILITIES[i]
		var pos := Vector2(COL_A + (i / 3) * 98, 218 + (i % 3) * 11)
		var prof: bool = ab in s.save_proficiencies
		_mark(pos + Vector2(1, 3), COL_PROF if prof else Color.TRANSPARENT)
		var l := _label(_body, pos + Vector2(9, 0), CombatHud.COL_TEXT if prof else CombatHud.COL_DIM)
		l.text = ABILITY_NAMES[ab]
		var v := _right_label(_body, pos, 90, CombatHud.COL_TEXT if prof else CombatHud.COL_DIM)
		v.text = "%+d" % s.save_bonus(ab)
	# training
	var arm := ", ".join(hero.base_stats.armor_training).replace("shield", "shields") if not hero.base_stats.armor_training.is_empty() else "none"
	var tr := _label(_body, Vector2(COL_A, 252), CombatHud.COL_DIM)
	tr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tr.size = Vector2(196, 0)
	tr.text = "Armour: %s\nWeapons: %s" % [arm, ", ".join(hero.base_stats.weapon_training).replace("_", " ")]


func _ability_use(ab: String) -> String:
	match ab:
		"STR": return "Melee attacks and damage (not finesse), Athletics, heavy armour, forcing doors."
		"DEX": return "AC in light or medium armour, initiative, ranged and finesse attacks, Acrobatics, Stealth, picking locks."
		"CON": return "Hit points per level, holding concentration on a spell."
		"INT": return "Wizard spells (save DC, spell attacks), Arcana, Investigation."
		"WIS": return "Cleric spells (save DC, spell attacks), Perception, Insight, Medicine."
		"CHA": return "Persuasion, Deception, Intimidation."
	return ""


## Hover area over one skill row: what the skill is for (and where the game uses it) and how
## the bonus is made up.
func _skill_hover(sk: String, y: float, bonus: int, prof: bool, expert: bool) -> void:
	var s := hero.stats
	var ab: String = CreatureStats.SKILL_ABILITY.get(sk, "STR")
	var parts := "%s %+d" % [ab, s.mod(ab)]
	if expert:
		parts += ", expertise %+d" % (s.proficiency_bonus * 2)
	elif prof:
		parts += ", proficient %+d" % s.proficiency_bonus
	var sub := "%s skill: %+d (%s)" % [ABILITY_NAMES[ab], bonus, parts]
	var desc: String = SKILL_INFO.get(sk, "")
	if sk == "stealth" and s.stealth_disadvantage:
		desc += " Your armour gives disadvantage on Stealth checks."
	var r := Control.new()
	r.position = Vector2(COL_B - 2, y)
	r.size = Vector2(146, 10)
	_body.add_child(r)
	var hl := ColorRect.new()
	hl.color = Color(1, 1, 1, 0.06)
	hl.size = r.size
	hl.visible = false
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(hl)
	_hover(r, SKILL_NAMES.get(sk, sk.replace("_", " ").capitalize()), sub, desc)
	r.mouse_entered.connect(func(): hl.visible = true)
	r.mouse_exited.connect(func(): hl.visible = false)


## Skills: proficient (green mark) and expertise (gold mark), then passive Perception and
## damage resistances / condition immunities.
func _build_skills() -> void:
	var s := hero.stats
	var hdr := _label(_body, Vector2(COL_B, 46), CombatHud.COL_BANNER)
	hdr.text = "SKILLS"
	var y := 58.0
	for sk: String in SKILLS:
		var expert := sk in s.skill_expertise
		var prof := expert or sk in s.skill_proficiencies
		var col := CombatHud.COL_TEXT if prof else CombatHud.COL_DIM
		_mark(Vector2(COL_B + 1, y + 3), COL_EXPERT if expert else (COL_PROF if prof else Color.TRANSPARENT))
		var l := _label(_body, Vector2(COL_B + 9, y), col)
		l.text = sk.replace("_", " ").capitalize() if sk != "thieves_tools" else "Thieves' Tools"
		var ab := _label(_body, Vector2(COL_B + 96, y), Color8(96, 90, 108))
		ab.text = CreatureStats.SKILL_ABILITY.get(sk, "")
		var v := _right_label(_body, Vector2(COL_B, y), 140, col)
		var b := s.skill_bonus(sk)
		if sk == "stealth" and s.stealth_disadvantage:
			v.add_theme_color_override("font_color", COL_WARN)
		v.text = "%+d" % b
		_skill_hover(sk, y, b, prof, expert)
		y += 10
	var pp := _label(_body, Vector2(COL_B, y + 3), CombatHud.COL_TEXT)
	pp.text = "Passive Perception"
	var ppv := _right_label(_body, Vector2(COL_B, y + 3), 140, CombatHud.COL_TEXT)
	ppv.text = str(s.passive_perception())
	y += 16
	var notes: PackedStringArray = []
	if s.stealth_disadvantage:
		notes.append("Stealth at disadvantage (armour).")
	if not s.resistances.is_empty():
		notes.append("Resists %s damage." % " and ".join(s.resistances))
	if not s.condition_immunities.is_empty():
		notes.append("Can't be %s." % " or ".join(s.condition_immunities))
	if not notes.is_empty():
		var n := _label(_body, Vector2(COL_B, y), COL_MAGIC)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.size = Vector2(142, 0)
		n.text = " ".join(notes)
	_rule(_body, Vector2(COL_B - 6, 46), Vector2(1, 236))
	_rule(_body, Vector2(COL_C - 6, 46), Vector2(1, 236))


## Attacks, spellcasting + slots, powers, features (each row: hover for details).
func _build_right() -> void:
	var h := hero
	var s := h.stats
	var y := 46.0
	var hdr := _label(_body, Vector2(COL_C, y), CombatHud.COL_BANNER)
	hdr.text = "ATTACKS"
	if s.attacks_per_action() > 1:
		var n := _right_label(_body, Vector2(COL_C, y), COL_C_W, CombatHud.COL_DIM)
		n.text = "%d per Attack action" % s.attacks_per_action()
	y += 12
	for a: AttackData in s.attacks:
		var crit := " Crits on %d-20." % s.crit_range if s.crit_range < 20 else ""
		var rng := "melee (reach 5 ft)" if a.kind == AttackData.Kind.MELEE else "ranged %d/%d ft" % [a.range_ft, a.long_range_ft]
		var desc := "%s to hit, %s %s damage.%s" % ["%+d" % s.attack_bonus(a), s.damage_expr(a), a.damage_type, crit]
		if not a.proficient:
			desc += " Not proficient: no proficiency bonus to hit."
		var tag := "%+d  %s %s" % [s.attack_bonus(a), s.damage_expr(a), a.damage_type]
		_row(y, a.name, tag, CombatHud.COL_TEXT if a.proficient else COL_WARN, a.name, rng, desc)
		y += 11
	if s.spell_ability != "":
		y += 4
		var sh := _label(_body, Vector2(COL_C, y), CombatHud.COL_BANNER)
		sh.text = "SPELLCASTING"
		var sv := _right_label(_body, Vector2(COL_C, y), COL_C_W, CombatHud.COL_TEXT)
		sv.text = "%s   DC %d   attack %+d" % [s.spell_ability, s.spell_save_dc(), s.spell_attack_bonus()]
		y += 12
		var x := COL_C
		for lvl in s.spell_slots.size():
			var l := _label(_body, Vector2(x, y), CombatHud.COL_DIM)
			l.text = CombatManager.power_tag_level(lvl + 1)
			x += 18
			var left: int = h.slots_left[lvl] if lvl < h.slots_left.size() else 0
			for k in s.spell_slots[lvl]:
				var pip := ColorRect.new()
				pip.position = Vector2(x, y + 3)
				pip.size = Vector2(6, 4)
				pip.color = CombatHud.COL_SLOT if k < left else CombatHud.COL_SLOT_USED
				pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_body.add_child(pip)
				x += 8
			x += 10
		var slots_hover := Control.new()
		slots_hover.position = Vector2(COL_C, y)
		slots_hover.size = Vector2(x - COL_C, 11)
		_body.add_child(slots_hover)
		_hover(slots_hover, "Spell slots", "Blue = ready, dark = spent",
				"Spells of 1st level and up spend a slot of their level or higher (a higher slot can make them stronger). Slots come back on a long rest%s." % [" (and some on a short rest: Arcane Recovery)" if h.base_stats.class_id == "wizard" else ""])
		y += 13
	y += 4
	var ph := _label(_body, Vector2(COL_C, y), CombatHud.COL_BANNER)
	ph.text = "SPELLS & ABILITIES" if s.spell_ability != "" else "ABILITIES"
	y += 12
	for p: SpellData in s.powers:
		var t := _power_tag(p)
		_row(y, p.display_name, t.text, t.col, p.display_name, _power_sub(p), _power_desc(p))
		y += 11
	var feats: Array = []
	for f: Array in Progression.FEATURES.get(h.base_stats.class_id, []):
		if f[0] <= h.level:
			feats.append(f)
	if not feats.is_empty():
		y += 4
		var fh := _label(_body, Vector2(COL_C, y), CombatHud.COL_BANNER)
		fh.text = "FEATURES"
		y += 12
		for f: Array in feats:
			var tag := "level %d" % f[0]
			var col := CombatHud.COL_DIM
			if f[1] == "Arcane Recovery":
				var ready: bool = h.uses_left.get("arcane_recovery", 0) > 0
				tag = "ready" if ready else "used"
				col = COL_PROF if ready else CombatHud.COL_DIM
			_row(y, f[1], tag, col, f[1], "Class feature, level %d" % f[0], f[2])
			y += 11


func _power_tag(p: SpellData) -> Dictionary:
	if p.kind == SpellData.Kind.SPELL:
		return {text = CombatManager.power_tag_level(p.level), col = CombatHud.COL_SLOT.lightened(0.3)}
	if p.uses > 0:
		var left: int = hero.uses_left.get(p.id, 0)
		var rest := "short rest" if p.recharge == SpellData.Recharge.SHORT_REST else "long rest"
		return {text = "%d/%d per %s" % [left, p.uses, rest], col = COL_PROF if left > 0 else CombatHud.COL_LOG_BAD}
	if p.id == "sneak_attack":
		return {text = "%dd6" % hero.stats.sneak_dice, col = CombatHud.COL_TEXT}
	match p.cast_time:
		SpellData.CastTime.BONUS: return {text = "bonus action", col = CombatHud.COL_DIM}
		SpellData.CastTime.REACTION: return {text = "reaction", col = CombatHud.COL_DIM}
		SpellData.CastTime.ATTACK: return {text = "instead of an attack", col = CombatHud.COL_DIM}
	return {text = "", col = CombatHud.COL_DIM}


## "1st-level spell - action - 120 ft - DEX save DC 13 - concentration"
func _power_sub(p: SpellData) -> String:
	var parts: PackedStringArray = []
	if p.kind == SpellData.Kind.SPELL:
		parts.append("Cantrip" if p.level == 0 else "%s-level spell" % CombatManager.power_tag_level(p.level))
	else:
		parts.append("Class ability")
	match p.cast_time:
		SpellData.CastTime.ACTION: parts.append("action")
		SpellData.CastTime.BONUS: parts.append("bonus action")
		SpellData.CastTime.REACTION: parts.append("reaction")
	if p.range_ft > 5 and p.target != SpellData.Target.SELF:
		parts.append("%d ft" % p.range_ft)
	elif p.range_ft == 5:
		parts.append("touch")
	match p.resolve:
		SpellData.Resolve.ATTACK:
			if p.kind == SpellData.Kind.SPELL:
				parts.append("spell attack %+d" % p.attack_bonus_for(hero.stats))
		SpellData.Resolve.SAVE:
			parts.append("%s save DC %d" % [p.save_ability, p.dc_for(hero.stats)])
	if p.concentration:
		parts.append("concentration")
	return " - ".join(parts)


func _power_desc(p: SpellData) -> String:
	var d := p.description
	if p.is_cantrip() and p.damage != "":
		d += " Now: %s %s." % [p.damage_for(hero.level, 0), p.damage_type]
	return d


# --- hover tips ----------------------------------------------------------------------------------

## One row in the right column: name on the left, tag on the right; hover shows the tip.
func _row(y: float, text: String, tag: String, tag_col: Color, title: String, sub: String, desc: String) -> void:
	var r := Control.new()
	r.position = Vector2(COL_C - 2, y)
	r.size = Vector2(COL_C_W + 4, 11)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.add_child(r)
	var hl := ColorRect.new()
	hl.color = Color(1, 1, 1, 0.06)
	hl.size = r.size
	hl.visible = false
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(hl)
	var l := _label(r, Vector2(2, 0), CombatHud.COL_TEXT)
	l.text = text
	var t := _right_label(r, Vector2(2, 0), COL_C_W, tag_col)
	t.text = tag
	r.mouse_entered.connect(func():
		hl.visible = true
		_show_tip(r, title, sub, desc))
	r.mouse_exited.connect(func():
		hl.visible = false
		_hide_tip())


func _hover(c: Control, title: String, sub: String, desc: String) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.mouse_entered.connect(_show_tip.bind(c, title, sub, desc))
	c.mouse_exited.connect(_hide_tip)


## The tip box: to the left of things in the right-hand column, else to their right.
func _show_tip(c: Control, title: String, sub: String, desc: String) -> void:
	_tip_title.text = title
	_tip_sub.text = sub
	_tip_sub.visible = sub != ""
	_tip_text.text = desc
	# Size from the labels' measured heights (wrapped lines are taller than the font's 11 px).
	_tip_sub.size.y = 0
	_tip_text.size.y = 0
	var y := 14.0
	if sub != "":
		_tip_sub.position.y = y
		y += _tip_sub.get_minimum_size().y
	_tip_text.position.y = y + 1
	var h := y + 1 + _tip_text.get_minimum_size().y + 3
	_tip.size = Vector2(TIP_W, h)
	var r := Rect2(c.global_position - global_position, c.size)
	var x := r.position.x - TIP_W - 4 if r.position.x > RECT.size.x / 2.0 else r.end.x + 4
	_tip.position = Vector2(x, clampf(r.position.y, 20.0, RECT.size.y - h - 4)).round()
	_tip.visible = true


func _hide_tip() -> void:
	_tip.visible = false


# --- helpers -------------------------------------------------------------------------------------

func _label(parent: Control, pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## A label whose text ends at pos.x + w.
func _right_label(parent: Control, pos: Vector2, w: float, col: Color) -> Label:
	var l := _label(parent, pos, col)
	l.size = Vector2(w, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


## A label centred in a box of width `w` (before its own scale).
func _centre_label(parent: Control, y: float, w: float, col: Color) -> Label:
	var l := _label(parent, Vector2(0, y), col)
	l.size = Vector2(w, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _box(pos: Vector2, sz: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = sz
	p.add_theme_stylebox_override("panel", CombatHud._box_static(CombatHud.COL_CARD, CombatHud.COL_EDGE))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(p)
	return p


func _bar(pos: Vector2, w: float, h: float, frac: float, back: Color, fill: Color) -> void:
	var b := ColorRect.new()
	b.color = back
	b.position = pos
	b.size = Vector2(w, h)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(b)
	if frac > 0.0:
		var f := ColorRect.new()
		f.color = fill
		f.position = pos
		f.size = Vector2(maxf(1.0, roundf(w * frac)), h)
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(f)


## A small square: green = proficient, gold = expertise; an empty outline otherwise.
func _mark(pos: Vector2, col: Color) -> void:
	var o := ColorRect.new()
	o.color = CombatHud.COL_EDGE
	o.position = pos
	o.size = Vector2(5, 5)
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(o)
	var i := ColorRect.new()
	i.color = col if col.a > 0.0 else Color8(16, 14, 20)
	i.position = pos + Vector2(1, 1)
	i.size = Vector2(3, 3)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(i)


func _rule(parent: Control, pos: Vector2, sz: Vector2) -> void:
	var r := ColorRect.new()
	r.color = CombatHud.COL_EDGE
	r.position = pos
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
