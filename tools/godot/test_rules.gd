extends SceneTree
## Headless checks for the rules core (dice + stat blocks).
## Run: Godot_console --headless --path . -s res://tools/godot/test_rules.gd   -> prints PASS/FAIL, exit 1 on failure

var _fails := 0
var _checks := 0


func _init() -> void:
	_test_parse()
	_test_rolls()
	_test_stats()
	_test_spells()
	_test_conditions()
	_test_items()
	_test_scrolls()
	_test_progression()
	print("%d checks, %d failed" % [_checks, _fails])
	print("PASS" if _fails == 0 else "FAIL")
	quit(1 if _fails > 0 else 0)


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL: ", what)


func _test_parse() -> void:
	check(Dice.parse("2d6+3").size() == 2, "parse 2d6+3")
	check(Dice.parse("d20")[0].count == 1 and Dice.parse("d20")[0].sides == 20, "parse d20")
	check(Dice.parse("1d4-1")[1].sign == -1, "parse negative modifier")
	check(Dice.parse("2d8+1d6+2").size() == 3, "parse multi-term")
	check(Dice.parse("hello").is_empty(), "reject garbage")
	check(Dice.parse("2d").is_empty(), "reject 2d")
	check(Dice.parse("").is_empty(), "reject empty")
	check(Dice.crit("1d8+3") == "2d8+3", "crit doubles dice: %s" % Dice.crit("1d8+3"))
	check(Dice.crit("2d6") == "4d6", "crit 2d6")
	check(is_equal_approx(Dice.average("2d6+3"), 10.0), "average 2d6+3")
	check(is_equal_approx(Dice.average("8d6"), 28.0), "average 8d6")


func _test_rolls() -> void:
	Dice.seed_rng(12345)
	var lo := 999
	var hi := -999
	var sum := 0
	var n := 20000
	for i in n:
		var r := Dice.roll("2d6+3")
		lo = mini(lo, r.total)
		hi = maxi(hi, r.total)
		sum += r.total
		if r.dice.size() != 2 or r.modifier != 3:
			check(false, "2d6+3 roll shape")
			return
	check(lo == 5 and hi == 15, "2d6+3 range 5..15 (got %d..%d)" % [lo, hi])
	check(absf(sum / float(n) - 10.0) < 0.1, "2d6+3 mean ~10 (got %.2f)" % (sum / float(n)))
	var counts := {}
	for i in n:
		var v := Dice.die(20)
		counts[v] = counts.get(v, 0) + 1
	check(counts.size() == 20, "d20 hits all faces")
	for f in counts:
		check(absf(counts[f] / float(n) - 0.05) < 0.01, "d20 face %d ~5%% (%.3f)" % [f, counts[f] / float(n)])
	var adv := 0.0
	var dis := 0.0
	for i in n:
		adv += Dice.d20(0, 1).natural
		dis += Dice.d20(0, -1).natural
	check(absf(adv / n - 13.82) < 0.2, "advantage mean ~13.8 (%.2f)" % (adv / n))
	check(absf(dis / n - 7.18) < 0.2, "disadvantage mean ~7.2 (%.2f)" % (dis / n))
	var r := Dice.d20(5)
	check(r.total == r.natural + 5, "d20 bonus applied")
	# Not seeded twice the same: two fresh generators differ (rolls are really random).
	Dice._rng = null
	var a := []
	for i in 10:
		a.append(Dice.die(20))
	Dice._rng = null
	var b := []
	for i in 10:
		b.append(Dice.die(20))
	check(a != b, "unseeded rolls differ between runs")


func _test_stats() -> void:
	var f: CreatureStats = load("res://data/heroes/fighter.tres")
	var r: CreatureStats = load("res://data/heroes/rogue.tres")
	var c: CreatureStats = load("res://data/heroes/cleric.tres")
	var w: CreatureStats = load("res://data/heroes/wizard.tres")
	var sp: CreatureStats = load("res://data/monsters/giant_spider.tres")
	var et: CreatureStats = load("res://data/monsters/eye_tyrant.tres")
	check(f and r and c and w and sp and et, "data files load")
	if not (f and r and c and w and sp and et):
		return
	# Heroes fight with their equipment: base stat block + starting kit.
	f = _bs(f, Equipment.starting(f))
	r = _bs(r, Equipment.starting(r))
	c = _bs(c, Equipment.starting(c))
	w = _bs(w, Equipment.starting(w))
	check(f.armor_class == 19 and r.armor_class == 15 and c.armor_class == 18 and w.armor_class == 12,
			"hero AC from kit 19 (Defense)/15/18/12 (%d/%d/%d/%d)" % [f.armor_class, r.armor_class, c.armor_class, w.armor_class])
	check(f.attacks.size() == 2 and f.attacks[1].name == "Handaxe" and f.attacks[1].range_cells() == 4, "Fighter longsword + handaxe")
	check(c.attacks.size() == 1 and c.attacks[0].damage_type == "bludgeoning", "Cleric mace only")
	check(w.attacks[1].name == "Light Crossbow" and w.damage_expr(w.attacks[1]) == "1d8+2", "Mage light crossbow 1d8+2")
	check(f.attack_bonus(f.attacks[0]) == 7, "Fighter longsword +7 (STR 18 at 5th) (%d)" % f.attack_bonus(f.attacks[0]))
	check(f.damage_expr(f.attacks[0]) == "1d8+4", "Fighter longsword 1d8+4 (%s)" % f.damage_expr(f.attacks[0]))
	check(f.attacks_per_action() == 2, "Fighter Extra Attack")
	check(r.attack_bonus(r.attacks[0]) == 7, "Rogue shortsword (finesse) +7")
	check(r.damage_expr(r.attacks[1]) == "1d6+4", "Rogue shortbow 1d6+4")
	check(r.attacks[1].range_cells() == 16 and r.attacks[1].long_range_cells() == 64, "shortbow 16/64 cells")
	check(w.spell_save_dc() == 15, "Wizard spell DC 15 (8 + 3 + 4) (%d)" % w.spell_save_dc())
	check(c.spell_save_dc() == 15, "Cleric spell DC 15")
	check(w.damage_expr(w.attacks[0]) == "1d6-1", "Wizard quarterstaff 1d6-1 (%s)" % w.damage_expr(w.attacks[0]))
	check(Array(w.spell_slots) == [4, 3, 2], "Wizard slots 4/3/2")
	check(f.max_hp == 44 and r.max_hp == 33 and c.max_hp == 38 and w.max_hp == 27, "hero HP")
	check(f.save_bonus("CON") == 5 and f.save_bonus("DEX") == 1, "Fighter saves")
	check(et.mod("DEX") == 2 and et.save_bonus("DEX") == 2, "Eye Tyrant DEX +2 (mock-up)")
	check(sp.attack_bonus(sp.attacks[0]) == 5 and sp.damage_expr(sp.attacks[0]) == "1d8+3", "Spider bite +5, 1d8+3")
	check(sp.attacks[0].rider_dc == 11, "Spider poison DC 11")
	# Packed-array exports once got dropped by an editor re-save: guard every one of them.
	check(Array(c.spell_slots) == [4, 3, 2], "Cleric slots 4/3/2 (%s)" % str(c.spell_slots))
	check(c.save_bonus("WIS") == 7 and c.save_bonus("CHA") == 4, "Cleric WIS/CHA saves")
	check(r.save_bonus("DEX") == 7 and w.save_bonus("INT") == 7, "Rogue DEX / Wizard INT saves")
	check(et.save_bonus("WIS") == 4, "Eye Tyrant WIS save +4")
	check(f.speed_cells() == 6 and et.speed_cells() == 4, "speed in cells")
	check(et.sight_cells() == 12 and sp.sight_cells() == 8, "sight in cells")


func _test_spells() -> void:
	var fi: SpellData = load("res://data/spells/fireball.tres")
	var fb: SpellData = load("res://data/spells/fire_bolt.tres")
	var sf: SpellData = load("res://data/spells/sacred_flame.tres")
	var mm: SpellData = load("res://data/spells/magic_missile.tres")
	var bl: SpellData = load("res://data/spells/bless.tres")
	var cw: SpellData = load("res://data/spells/cure_wounds.tres")
	check(fi and fb and sf and mm and bl and cw, "spell files load")
	if not (fi and fb and sf and mm and bl and cw):
		return
	check(fi.damage_for(5, 3) == "8d6", "Fireball 8d6 (%s)" % fi.damage_for(5, 3))
	check(fi.damage_for(5, 4) == "8d6+1d6", "Fireball upcast at 4th (%s)" % fi.damage_for(5, 4))
	check(fi.area_size == 3 and fi.save_ability == "DEX" and fi.half_on_save, "Fireball 3x3 DEX half")
	check(fb.damage_for(5, 0) == "2d10", "Fire Bolt 2d10 at level 5 (%s)" % fb.damage_for(5, 0))
	check(fb.damage_for(4, 0) == "1d10", "Fire Bolt 1d10 at level 4")
	check(sf.damage_for(5, 0) == "2d8", "Sacred Flame 2d8 at level 5")
	check(mm.darts_for(1) == 3 and mm.darts_for(2) == 4, "Magic Missile darts 3 / 4")
	check(bl.targets_for(1) == 3 and bl.targets_for(2) == 4, "Bless targets 3 / 4")
	check(cw.heal_for(5, 2) == "1d8+1d8", "Cure Wounds upcast (%s)" % cw.heal_for(5, 2))
	check(fb.is_cantrip() and not fb.uses_slot() and fi.uses_slot(), "cantrip / slot")
	var w: CreatureStats = _l5(load("res://data/heroes/wizard.tres"))
	var r: CreatureStats = _l5(load("res://data/heroes/rogue.tres"))
	var f: CreatureStats = _l5(load("res://data/heroes/fighter.tres"))
	var sp: CreatureStats = load("res://data/monsters/giant_spider.tres")
	var et: CreatureStats = load("res://data/monsters/eye_tyrant.tres")
	var ids := w.powers.map(func(p): return p.id)
	check(ids == ["fire_bolt", "magic_missile", "burning_hands", "shield", "scorching_ray", "fireball"], "Wizard powers at 5th %s" % str(ids))
	check(fi.attack_bonus_for(w) == 7 and fi.dc_for(w) == 15, "Wizard spell attack +7, DC 15")
	check(r.skill_bonus("stealth") == 10, "Rogue Stealth +10 (expertise) (%d)" % r.skill_bonus("stealth"))
	check(f.skill_bonus("athletics") == 7, "Fighter Athletics +7")
	check(sp.skill_bonus("stealth") == 7 and sp.passive_perception() == 10, "Spider Stealth +7, passive 10")
	check(et.passive_perception() == 14, "Eye Tyrant passive Perception 14")
	check(sp.powers.size() == 1 and sp.powers[0].id == "spider_web" and sp.powers[0].attack_bonus_for(sp) == 5, "Spider Web +5")


## The rules tests check the party at level 5 (the data files hold level 1).
func _bs(base: CreatureStats, eq: Dictionary) -> CreatureStats:
	return Equipment.build_stats(base, eq, 5)


## A bare level-5 stat block (no equipment applied).
func _l5(s: CreatureStats) -> CreatureStats:
	var c: CreatureStats = s.duplicate()
	Progression.apply(c, 5)
	return c


func _hero(cls: int) -> Hero:
	var h: Hero = (load("res://scenes/actors/hero.tscn") as PackedScene).instantiate()
	h.base_stats = load(Hero.STATS[cls])
	h.level = 5
	h.stats = Equipment.build_stats(h.base_stats, Equipment.starting(h.base_stats), 5)
	h.hp = h.stats.max_hp
	h.reset_resources()
	return h


func _test_conditions() -> void:
	var a := _hero(Hero.HeroClass.MAGE)
	var b := _hero(Hero.HeroClass.FIGHTER)
	var fi: SpellData = load("res://data/spells/fireball.tres")
	var mm: SpellData = load("res://data/spells/magic_missile.tres")
	# slots
	check(Array(a.slots_left) == [4, 3, 2], "Mage starts with 4/3/2 slots")
	check(a.lowest_slot_for(fi) == 3 and a.lowest_slot_for(mm) == 1, "lowest slot for Fireball / Magic Missile")
	a.spend_slot(3)
	a.spend_slot(3)
	check(a.lowest_slot_for(fi) == 0 and not a.can_use(fi), "no 3rd-level slots left -> can't Fireball")
	check(not a.spend_slot(3), "can't spend an empty slot")
	var sw: SpellData = load("res://data/spells/second_wind.tres")
	var fighter := _hero(Hero.HeroClass.FIGHTER)
	check(fighter.can_use(sw), "Second Wind available")
	fighter.spend_use(sw)
	check(not fighter.can_use(sw), "Second Wind used up")
	# advantage
	check(CombatManager.combine_advantage(1, -1) == 0 and CombatManager.combine_advantage(1, 0) == 1 and CombatManager.combine_advantage(0, -1) == -1, "combine advantage")
	check(Condition.attack_advantage(a, b, true, 1) == 0, "no conditions -> 0")
	a.add_condition("hidden", -1)
	check(Condition.attack_advantage(a, b, false, 5) == 1, "hidden attacker -> advantage")
	a.add_condition("prone", -1)
	check(Condition.attack_advantage(a, b, false, 5) == 0, "hidden + prone attacker cancel")
	a.conditions.clear()
	b.add_condition("prone", -1)
	check(Condition.attack_advantage(a, b, true, 1) == 1, "melee vs prone adjacent -> advantage")
	check(Condition.attack_advantage(a, b, false, 4) == -1, "ranged vs prone -> disadvantage")
	b.conditions.clear()
	b.add_condition("restrained", -1)
	check(Condition.attack_advantage(a, b, false, 4) == 1 and Condition.save_advantage(b, "DEX") == -1, "restrained: attacked with adv, DEX save disadv")
	b.add_condition("shielded", 1)
	check(Condition.ac_bonus(b) == 5, "shielded +5 AC")
	var ended := b.tick_conditions()
	check("shielded" in ended and not b.has_condition("shielded") and b.has_condition("restrained"), "shield ends at start of next turn, restrained stays")
	b.add_condition("blessed", 10)
	check(Condition.roll_bonus_dice(b) == "1d4", "blessed adds 1d4")
	for i in 9:
		b.tick_conditions()
	check(b.has_condition("blessed"), "bless lasts 10 rounds (9 ticks)")
	b.tick_conditions()
	check(not b.has_condition("blessed"), "bless gone after 10")
	a.free()
	b.free()
	fighter.free()


## Phase 4 step 6: +1 weapons / armour / shield, Rings of Free Action and Resistance, loot.
func _test_magic_items(fb: CreatureStats, rb: CreatureStats, wb: CreatureStats, cb: CreatureStats) -> void:
	var I := ItemData.get_item
	for iid in ["longsword_plus1", "mace_plus1", "rapier_plus1", "dagger_plus1", "shortbow_plus1",
			"chain_mail_plus1", "studded_leather_plus1", "shield_plus1", "ring_free_action", "ring_resistance"]:
		var it: ItemData = I.call(iid)
		check(it != null and it.is_magic(), "%s loads and is magic" % iid)
		if it:
			var tex := it.icon_texture()
			check(tex.region.position.y == 16 and it.icon_index() == ItemData.ICON_ORDER.find(it.base_id()),
					"%s: glimmer icon of its plain version" % iid)
	check(not I.call("longsword").is_magic() and I.call("longsword").icon_texture().region.position.y == 0, "plain longsword: plain icon")
	check(I.call("longsword_plus1").display_name == "Longsword +1" and I.call("longsword").magic_bonus == 0, "+1 name; plain one untouched")
	# +1 weapon: +1 to hit and damage. Fighter longsword +6 / 1d8+3 -> +7 / 1d8+4.
	var plain := _bs(fb, {main = "longsword"})
	var magic := _bs(fb, {main = "longsword_plus1"})
	check(magic.attack_bonus(magic.attacks[0]) == plain.attack_bonus(plain.attacks[0]) + 1
			and is_equal_approx(Dice.average(magic.damage_expr(magic.attacks[0])), Dice.average(plain.damage_expr(plain.attacks[0])) + 1.0) and magic.attacks[0].name == "Longsword +1",
			"Longsword +1: +1 to hit and damage (%s)" % magic.damage_expr(magic.attacks[0]))
	check(Equipment.is_trained(rb, I.call("rapier_plus1")) and Equipment.is_trained(wb, I.call("dagger_plus1")),
			"single-weapon training covers the +1 version")
	check(_bs(rb, {ranged = "shortbow_plus1"}).attacks[1].magic_bonus == 1, "Shortbow +1 in the ranged slot")
	# +1 armour / shield: +1 AC.
	check(_bs(cb, {armor = "chain_mail_plus1", off = "shield_plus1"}).armor_class == 20, "Chain Mail +1 + Shield +1: 17 + 3")
	check(_bs(rb, {armor = "studded_leather_plus1"}).armor_class == 17, "Studded Leather +1: 12 + 1 + DEX 4")
	check(I.call("chain_mail_plus1").summary().begins_with("AC 17"), "armour summary shows the +1")
	# Rings: resistance and condition immunity on the hero's copy only.
	var rr := _bs(rb, {ring1 = "ring_resistance"})
	check("poison" in rr.resistances and rb.resistances.is_empty(), "Ring of Resistance: poison; base block untouched")
	var rf := _bs(rb, {ring1 = "ring_free_action", ring2 = "ring_resistance"})
	check("restrained" in rf.condition_immunities and "poison" in rf.resistances and rb.condition_immunities.is_empty(),
			"Free Action + Resistance together")
	check(_bs(rb, {}).condition_immunities.is_empty(), "no ring, no immunity")
	check(I.call("ring_free_action").summary().contains("restrained") and I.call("ring_resistance").summary().contains("poison"),
			"ring summaries name their effect")
	# Loot: every chest item on both floors exists.
	for path in ["res://scenes/maps/dungeon_1.tscn", "res://scenes/maps/dungeon_2.tscn"]:
		var st := (load(path) as PackedScene).get_state()
		var n_chests := 0
		for ni in st.get_node_count():
			for pi in st.get_node_property_count(ni):
				if st.get_node_property_name(ni, pi) == "items":
					n_chests += 1
					for iid in st.get_node_property_value(ni, pi):
						check(ItemData.get_item(iid) != null, "%s: chest item %s exists" % [path.get_file(), iid])
		check(n_chests >= 4, "%s: %d stocked chests" % [path.get_file(), n_chests])


func _test_items() -> void:
	var ids := ["dagger", "mace", "quarterstaff", "shortsword", "longsword", "rapier", "warhammer",
			"greatsword", "handaxe", "light_crossbow", "shortbow", "longbow", "leather_armor",
			"studded_leather", "chain_shirt", "scale_mail", "chain_mail", "plate_armor", "shield",
			"potion_healing", "potion_greater_healing", "ring_protection"]
	for iid in ids:
		var it := ItemData.get_item(iid)
		check(it != null and it.id == iid, "item %s loads" % iid)
		if it and it.kind == ItemData.Kind.WEAPON:
			check(it.attack != null and Dice.parse(it.attack.damage).size() > 0, "%s has an attack" % iid)
	var fb: CreatureStats = load("res://data/heroes/fighter.tres")
	var rb: CreatureStats = load("res://data/heroes/rogue.tres")
	var wb: CreatureStats = load("res://data/heroes/wizard.tres")
	var cb: CreatureStats = load("res://data/heroes/cleric.tres")
	check(Array(fb.starting_equipment).size() == 4 and Array(wb.weapon_training).has("light_crossbow"),
			"hero training / kit arrays survived (%s)" % str(fb.starting_equipment))
	var I := ItemData.get_item
	# Training: the Wizard can't wear armour, the Rogue no shield; anyone can swing a weapon.
	check(Equipment.cannot_equip(wb, I.call("leather_armor"), "armor") != "", "Wizard can't wear armour")
	check(Equipment.cannot_equip(rb, I.call("shield"), "off") != "", "Rogue can't use a shield")
	check(Equipment.cannot_equip(rb, I.call("studded_leather"), "armor") == "", "Rogue wears studded leather")
	check(Equipment.cannot_equip(fb, I.call("shield"), "main") != "", "shield not in the main hand")
	check(Equipment.cannot_equip(fb, I.call("potion_healing"), "main") != "", "potion isn't equipment")
	check(Equipment.cannot_equip(wb, I.call("longsword"), "main") == "", "Wizard can hold a longsword")
	var wl := _bs(wb, {main = "longsword"})
	check(not wl.attacks[0].proficient and wl.attack_bonus(wl.attacks[0]) == -1, "untrained weapon: no proficiency (-1)")
	check(_bs(rb, {main = "rapier"}).attack_bonus(_bs(rb, {main = "rapier"}).attacks[0]) == 7,
			"Rogue rapier: finesse + proficient +7")
	# AC maths: DEX cap, shield, ring; no armour = 10 + DEX; heavy armour without the STR = slower.
	check(_bs(rb, {}).armor_class == 14, "Rogue unarmoured 10 + 4")
	check(_bs(rb, {armor = "chain_shirt"}).armor_class == 15, "chain shirt caps DEX at +2")
	check(_bs(fb, {armor = "plate_armor", off = "shield"}).armor_class == 21, "plate + shield + Defense 21")
	var ringed := _bs(wb, {ring1 = "ring_protection"})
	check(ringed.armor_class == 13 and ringed.save_bonus("INT") == 8 and ringed.save_bonus("STR") == 0,
			"Ring of Protection +1 AC / +1 saves")
	check(wb.save_bonus("INT") == 5 and wb.level == 1, "the base stat block is never changed (level 1: +5)")
	check(_bs(wb, {armor = "plate_armor"}).speed_ft == 20, "plate without STR 15: -10 ft")
	check(_bs(fb, {armor = "chain_mail"}).stealth_disadvantage, "chain mail: stealth disadvantage")
	var un := _bs(fb, {})
	check(un.attacks.size() == 1 and un.damage_expr(un.attacks[0]) == "1+4" and is_equal_approx(Dice.average("1+4"), 5.0),
			"no weapon: unarmed strike 1 + STR")
	# Two-handed weapon and shield push each other out.
	var eq := Equipment.starting(fb)
	check(eq.main == "longsword" and eq.off == "shield" and eq.ranged == "handaxe" and eq.armor == "chain_mail", "Fighter kit slots")
	check(Array(Equipment.displaced_by(eq, I.call("greatsword"), "main")) == ["main", "off"], "greatsword displaces the shield")
	check(Array(Equipment.displaced_by({main = "greatsword"}, I.call("shield"), "off")) == ["main"], "shield displaces a greatsword")
	check(Equipment.default_slot(I.call("ring_protection"), {ring1 = "ring_protection"}) == "ring2", "second ring slot")
	check(Equipment.starting(cb).has("off"), "Cleric starts with a shield")
	var gs_eq := Equipment.with_item(eq, I.call("greatsword"), "main")
	check(gs_eq.main == "greatsword" and not gs_eq.has("off") and eq.off == "shield", "with_item: greatsword drops the shield, original untouched")
	# Icons: every item has its own picture; unknown kinds fall back to the kind's icon.
	for iid in ids:
		check(I.call(iid).icon_index() == ItemData.ICON_ORDER.find(iid), "%s has its own icon" % iid)
	var odd := ItemData.new()
	odd.kind = ItemData.Kind.KEY
	check(odd.icon_index() == ItemData.ICON_ORDER.find("key"), "unknown key uses the key icon")
	odd.id = "longsword_plus1"
	odd.kind = ItemData.Kind.WEAPON
	check(odd.icon_index() == ItemData.ICON_ORDER.find("longsword"), "+1 longsword uses the longsword icon")
	_test_magic_items(fb, rb, wb, cb)
	# Equip from / take off to the bag.
	var hf := _hero(Hero.HeroClass.FIGHTER)
	hf.base_stats = fb
	hf.level = 5
	hf.equipment = Equipment.starting(fb)
	hf.refresh_stats()
	var bag := Inventory.new()
	bag.add("greatsword")
	check(hf.equip_from(bag, "greatsword") == "" and hf.equipment.main == "greatsword" and not hf.equipment.has("off"), "fighter takes the greatsword")
	check(bag.has("longsword") and bag.has("shield") and not bag.has("greatsword"), "longsword + shield back in the bag")
	check(hf.stats.armor_class == 17, "AC 17 without the shield (chain + Defense) (%d)" % hf.stats.armor_class)
	check(hf.equip_from(bag, "plate_armor") != "", "can't equip what isn't in the bag")
	check(hf.unequip_to(bag, "armor") == "chain_mail" and bag.has("chain_mail") and hf.stats.armor_class == 11, "chain mail off: AC 10 + DEX 1")
	var hw := _hero(Hero.HeroClass.MAGE)
	hw.base_stats = wb
	hw.level = 5
	hw.equipment = {}
	hw.refresh_stats()
	check(hw.equip_from(bag, "chain_mail") != "" and bag.has("chain_mail"), "mage refuses chain mail; it stays in the bag")
	bag.add("ring_protection", 2)
	check(hw.equip_from(bag, "ring_protection") == "" and hw.equip_from(bag, "ring_protection") == "", "two rings")
	check(hw.equipment.has("ring1") and hw.equipment.has("ring2") and hw.stats.item_save_bonus == 2, "both ring slots, saves +2")
	hf.free()
	hw.free()
	# Sorting the bag: weapons, armour, shields, rings, potions...
	var sb := Inventory.new()
	for iid in ["potion_healing", "shield", "ring_protection", "rapier", "chain_mail", "dagger"]:
		sb.add(iid)
	sb.sort()
	var sorted_ids := sb.stacks.map(func(st): return st.id)
	check(sorted_ids == ["dagger", "rapier", "chain_mail", "shield", "ring_protection", "potion_healing"], "sorted bag %s" % [sorted_ids])
	# The bag: stacks, counts, gold, round trip.
	var inv := Inventory.starting()
	check(inv.count("potion_healing") == 3 and inv.stacks.size() == 1, "starting bag: 3 potions in one stack")
	inv.add("potion_healing", 2)
	inv.add("dagger")
	inv.add("dagger")
	check(inv.count("potion_healing") == 5 and inv.count("dagger") == 2 and inv.stacks.size() == 3, "stack potions, not daggers")
	check(not inv.remove("dagger", 3) and inv.count("dagger") == 2, "can't take more than there is")
	check(inv.remove("potion_healing", 5) and not inv.has("potion_healing") and inv.stacks.size() == 2, "used-up stack disappears")
	inv.add_gold(40)
	var back := Inventory.from_dict(inv.to_dict())
	check(back.gold == 40 and back.count("dagger") == 2, "bag survives to_dict / from_dict")
	back.add("dagger")
	check(inv.count("dagger") == 2, "restored bag is a copy")
	check(I.call("chain_mail").summary() == "AC 16, heavy, stealth disadv.", "summary: %s" % I.call("chain_mail").summary())
	check(I.call("shortbow").summary() == "1d6 piercing, range 80/320 ft, two-handed", "summary: %s" % I.call("shortbow").summary())


## Spell scrolls + keys (Phase 4 step 5).
func _test_scrolls() -> void:
	for iid in ["scroll_magic_missile", "scroll_cure_wounds", "scroll_bless", "scroll_fireball", "scroll_lightning_bolt"]:
		var it := ItemData.get_item(iid)
		check(it != null and it.kind == ItemData.Kind.SCROLL and it.spell != null and it.stackable, "%s loads with its spell" % iid)
	for kid in [["crypt_key", "crypt"], ["lair_key", "lair"]]:
		var k := ItemData.get_item(kid[0])
		check(k != null and k.kind == ItemData.Kind.KEY and k.key_id == kid[1], "%s opens '%s'" % kid)
	var bag := Inventory.new()
	bag.add("lair_key")
	check(bag.key_for("lair") == "lair_key" and bag.key_for("crypt") == "", "the bag finds the right key")
	# spell lists survive in the data files (typed arrays, see the editor re-save note)
	var fi: SpellData = load("res://data/spells/fireball.tres")
	var cw: SpellData = load("res://data/spells/cure_wounds.tres")
	check(Array(fi.classes) == ["wizard"] and Array(cw.classes) == ["cleric"], "spell lists: fireball wizard, cure wounds cleric")
	var lb: SpellData = load("res://data/spells/lightning_bolt.tres")
	check(lb.level == 3 and lb.target == SpellData.Target.LINE and lb.range_cells() == 20 and lb.damage == "8d6", "Lightning Bolt: 3rd, 100-ft line, 8d6")
	# the SRD scroll table
	check(SpellData.scroll_dc(1) == 13 and SpellData.scroll_attack_bonus(1) == 5, "1st-level scroll: DC 13, +5")
	check(SpellData.scroll_dc(3) == 15 and SpellData.scroll_attack_bonus(3) == 7, "3rd-level scroll: DC 15, +7")
	check(SpellData.scroll_dc(5) == 17 and SpellData.scroll_dc(9) == 19, "5th 17, 9th 19")
	check(fi.description_at_level() == "A burst of flame on a 3x3 area: 8d6 fire, DEX save for half.", "no upcasting text: '%s'" % fi.description_at_level())
	# reading a scroll: a copy of the spell that spends no slot and uses the scroll's numbers
	var sf := ItemData.get_item("scroll_fireball")
	var p := CombatManager.scroll_power(sf)
	check(p != fi and p.is_scroll() and not p.uses_slot() and fi.uses_slot(), "scroll power: no slot (the spell itself still uses one)")
	check(p.dc_for(load("res://data/heroes/wizard.tres")) == 15 and p.attack_bonus_for(load("res://data/heroes/cleric.tres")) == 7, "scroll DC / attack bonus")
	check(CombatManager.is_item_power(p) and not CombatManager.is_potion_power(p), "scroll is an item power, not a potion")
	check(CombatManager.scroll_power(sf) == p, "scroll power cached")
	var mage := _hero(Hero.HeroClass.MAGE)
	var fighter := _hero(Hero.HeroClass.FIGHTER)
	var cleric := _hero(Hero.HeroClass.CLERIC)
	check(CombatManager.scroll_problem(mage, sf) == "", "the mage can read Fireball")
	check(CombatManager.scroll_problem(fighter, sf) != "", "the fighter can't (%s)" % CombatManager.scroll_problem(fighter, sf))
	check(CombatManager.scroll_problem(cleric, sf) != "" and CombatManager.scroll_problem(cleric, ItemData.get_item("scroll_cure_wounds")) == "", "the cleric reads Cure Wounds, not Fireball")
	check(CombatManager.max_spell_level(mage) == 3 and CombatManager.max_spell_level(fighter) == 0, "mage casts up to 3rd")
	check(CombatManager.scroll_check_dc(mage, p) == 0, "no check for a 3rd-level scroll at level 5")
	var big: SpellData = p.duplicate()
	big.level = 5
	check(CombatManager.scroll_check_dc(mage, big) == 15, "a 5th-level scroll needs a DC 15 check")
	mage.free()
	fighter.free()
	cleric.free()


## Phase 5: levels 1-5 (Progression), XP, level-ups, class features, new monsters and spells.
func _test_progression() -> void:
	check(Progression.level_for_xp(0) == 1 and Progression.level_for_xp(299) == 1 and Progression.level_for_xp(300) == 2
			and Progression.level_for_xp(2700) == 4 and Progression.level_for_xp(99999) == 5, "XP thresholds")
	check(Progression.xp_for_next(1) == 300 and Progression.xp_for_next(5) == 0, "XP for next level")
	var fb: CreatureStats = load("res://data/heroes/fighter.tres")
	var rb: CreatureStats = load("res://data/heroes/rogue.tres")
	var cb: CreatureStats = load("res://data/heroes/cleric.tres")
	var wb: CreatureStats = load("res://data/heroes/wizard.tres")
	check(fb.level == 1 and fb.max_hp == 12 and rb.max_hp == 9 and cb.max_hp == 10 and wb.max_hp == 7, "level-1 data: HP 12/9/10/7")
	# HP per level: max die + CON at 1st, then die/2 + 1 + CON; the level-5 numbers of the old party.
	var hp5 := [44, 33, 38, 27]
	var hp_ok := true
	for i in 4:
		var s := _l5([fb, rb, cb, wb][i])
		hp_ok = hp_ok and s.max_hp == hp5[i]
	check(hp_ok, "level 5 HP 44/33/38/27")
	var f1 := Equipment.build_stats(fb, Equipment.starting(fb), 1)
	var f3 := Equipment.build_stats(fb, Equipment.starting(fb), 3)
	check(f1.proficiency_bonus == 2 and f1.attacks_per_action() == 1 and f1.crit_range == 20 and f1.powers.size() == 2,
			"Fighter 1: prof 2, one attack, no Action Surge yet")
	check(f3.crit_range == 19 and f3.powers.any(func(p): return p.id == "action_surge") and f3.attack_bonus(f3.attacks[0]) == 5,
			"Fighter 3: Improved Critical, Action Surge, longsword +5")
	check(f1.armor_class == 19, "Fighter 1: chain + shield + Defense 19")
	var r1 := Equipment.build_stats(rb, Equipment.starting(rb), 1)
	var r3 := Equipment.build_stats(rb, Equipment.starting(rb), 3)
	check(r1.sneak_dice == 1 and r3.sneak_dice == 2 and _l5(rb).sneak_dice == 3, "Sneak Attack 1d6 / 2d6 / 3d6")
	check(not r1.powers.any(func(p): return p.id == "hide") and r3.powers.any(func(p): return p.id == "hide"), "Cunning Action (Hide) from 2nd")
	check(_l5(rb).powers.any(func(p): return p.id == "uncanny_dodge") and _l5(rb).dex_score == 18 and rb.dex_score == 16, "Rogue 5: Uncanny Dodge, DEX 18 (ASI)")
	var c1 := Equipment.build_stats(cb, Equipment.starting(cb), 1)
	check(Array(c1.spell_slots) == [2] and c1.spell_save_dc() == 13, "Cleric 1: two 1st-level slots, DC 13")
	check(c1.powers.map(func(p): return p.id) == ["sacred_flame", "cure_wounds", "healing_word", "bless"], "Cleric 1 spells")
	var c5 := _l5(cb)
	check(c5.destroy_undead_cr == 0.5 and c5.powers.any(func(p): return p.id == "mass_healing_word"), "Cleric 5: Destroy Undead, Mass Healing Word")
	var w3 := Equipment.build_stats(wb, {}, 3)
	check(Array(w3.spell_slots) == [4, 2] and w3.powers.any(func(p): return p.id == "scorching_ray")
			and not w3.powers.any(func(p): return p.id == "fireball"), "Mage 3: slots 4/2, Scorching Ray, no Fireball")
	# Level up a hero: HP and slots grow on top of what's left.
	var h: Hero = (load("res://scenes/actors/hero.tscn") as PackedScene).instantiate()
	h.base_stats = wb
	h.equipment = Equipment.starting(wb)
	h.refresh_stats()
	h.hp = h.stats.max_hp
	h.reset_resources()
	check(h.level == 1 and h.hp == 7 and Array(h.slots_left) == [2], "fresh mage: level 1, 7 HP, 2 slots")
	h.spend_slot(1)
	h.hp = 3
	var ups := h.add_xp(300)
	check(ups.size() == 1 and h.level == 2 and h.stats.max_hp == 12 and h.hp == 8 and Array(h.slots_left) == [2] and h.hit_dice_left == 2,
			"level 2: +5 max HP on top (3 -> 8), a 3rd slot (1 left -> 2), a hit die (%d HP, %s)" % [h.hp, str(h.slots_left)])
	ups = h.add_xp(2400)
	check(ups.size() == 2 and h.level == 4 and h.stats.int_score == 18 and Array(h.stats.spell_slots) == [4, 3], "two levels at once -> 4, INT 18")
	check(h.add_xp(99999).size() == 1 and h.level == 5 and h.add_xp(10000).is_empty(), "top level is 5")
	h.free()
	# XP is split between the heroes who aren't dead (DungeonMap.award_xp), level-ups returned.
	# Arcane Recovery: a short rest gives back ceil(level/2) slot levels once a day.
	var m := _hero(Hero.HeroClass.MAGE)
	m.reset_resources()
	m.slots_left = [0, 0, 0]
	var msg := Rest.arcane_recovery(m)
	check(Array(m.slots_left) == [0, 0, 1] and msg.contains("3rd"), "Arcane Recovery at 5th: one 3rd-level slot (%s)" % str(m.slots_left))
	check(Rest.arcane_recovery(m) == "", "Arcane Recovery once per long rest")
	m.free()
	# Conditions: paralyzed.
	var a := _hero(Hero.HeroClass.FIGHTER)
	var b := _hero(Hero.HeroClass.ROGUE)
	b.add_condition("paralyzed", 10)
	check(Condition.attack_advantage(a, b, true, 1) == 1 and Condition.auto_fails_save(b, "DEX") and not Condition.auto_fails_save(b, "WIS"),
			"paralyzed: attacked with advantage, fails DEX saves")
	a.free()
	b.free()
	# New monsters and spells load with their SRD numbers.
	var M := func(id): return load("res://data/monsters/%s.tres" % id) as CreatureStats
	for id in ["giant_rat", "wolf", "goblin", "goblin_boss", "bandit", "zombie", "ghoul", "ghast", "hobgoblin",
			"bugbear", "ogre", "wight", "mummy", "specter", "wraith"]:
		var s: CreatureStats = M.call(id)
		check(s != null and s.xp > 0 and not s.attacks.is_empty(), "monster %s loads" % id)
	check("pack_tactics" in M.call("wolf").traits and M.call("wolf").attacks[0].rider_condition == "prone", "wolf: pack tactics, knocks prone")
	check(M.call("ghoul").attacks[0].rider_condition == "paralyzed" and M.call("ghoul").attacks[0].rider_dc == 10, "ghoul claws paralyze (DC 10)")
	check("undead_fortitude" in M.call("zombie").traits and M.call("zombie").armor_class == 8, "zombie")
	check(M.call("goblin_boss").extra_attacks == 1 and M.call("wight").extra_attacks == 1, "multiattack")
	check("resist_nonmagical" in M.call("wight").traits and M.call("wraith").xp == 1800, "wight / wraith")
	check(M.call("ogre").attack_bonus(M.call("ogre").attacks[0]) == 6 and M.call("ogre").damage_expr(M.call("ogre").attacks[0]) == "2d8+4", "ogre greatclub +6 2d8+4")
	var hp: SpellData = load("res://data/spells/hold_person.tres")
	check(hp.level == 2 and Array(hp.creature_types) == ["humanoid"] and hp.save_each_turn and hp.condition == "paralyzed", "Hold Person")
	var bh: SpellData = load("res://data/spells/burning_hands.tres")
	check(bh.target == SpellData.Target.CONE and bh.damage_for(1, 2) == "3d6+1d6", "Burning Hands cone, upcast")
	var sr: SpellData = load("res://data/spells/scorching_ray.tres")
	check(sr.darts_for(2) == 3 and sr.darts_for(3) == 4 and sr.resolve == SpellData.Resolve.ATTACK, "Scorching Ray 3 rays (+1 per slot)")
