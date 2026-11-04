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
	check(f.attack_bonus(f.attacks[0]) == 6, "Fighter longsword +6 (%d)" % f.attack_bonus(f.attacks[0]))
	check(f.damage_expr(f.attacks[0]) == "1d8+3", "Fighter longsword 1d8+3 (%s)" % f.damage_expr(f.attacks[0]))
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
	check(Array(c.spell_slots) == [4, 3, 2], "Cleric slots 4/3/2 (%s)" % c.spell_slots)
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
	var w: CreatureStats = load("res://data/heroes/wizard.tres")
	var r: CreatureStats = load("res://data/heroes/rogue.tres")
	var f: CreatureStats = load("res://data/heroes/fighter.tres")
	var sp: CreatureStats = load("res://data/monsters/giant_spider.tres")
	var et: CreatureStats = load("res://data/monsters/eye_tyrant.tres")
	var ids := w.powers.map(func(p): return p.id)
	check(ids == ["fire_bolt", "magic_missile", "shield", "fireball"], "Wizard powers %s" % str(ids))
	check(fi.attack_bonus_for(w) == 7 and fi.dc_for(w) == 15, "Wizard spell attack +7, DC 15")
	check(r.skill_bonus("stealth") == 10, "Rogue Stealth +10 (expertise) (%d)" % r.skill_bonus("stealth"))
	check(f.skill_bonus("athletics") == 6, "Fighter Athletics +6")
	check(sp.skill_bonus("stealth") == 7 and sp.passive_perception() == 10, "Spider Stealth +7, passive 10")
	check(et.passive_perception() == 14, "Eye Tyrant passive Perception 14")
	check(sp.powers.size() == 1 and sp.powers[0].id == "spider_web" and sp.powers[0].attack_bonus_for(sp) == 5, "Spider Web +5")


func _hero(cls: int) -> Hero:
	var h: Hero = (load("res://scenes/actors/hero.tscn") as PackedScene).instantiate()
	h.stats = load(Hero.STATS[cls])
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
