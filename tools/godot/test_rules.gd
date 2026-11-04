extends SceneTree
## Headless checks for the rules core (dice + stat blocks).
## Run: Godot_console --headless --path . -s res://tools/godot/test_rules.gd   -> prints PASS/FAIL, exit 1 on failure

var _fails := 0
var _checks := 0


func _init() -> void:
	_test_parse()
	_test_rolls()
	_test_stats()
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
	check(w.spell_slots == PackedInt32Array([4, 3, 2]), "Wizard slots 4/3/2")
	check(f.max_hp == 44 and r.max_hp == 33 and c.max_hp == 38 and w.max_hp == 27, "hero HP")
	check(f.save_bonus("CON") == 5 and f.save_bonus("DEX") == 1, "Fighter saves")
	check(et.mod("DEX") == 2 and et.save_bonus("DEX") == 2, "Eye Tyrant DEX +2 (mock-up)")
	check(sp.attack_bonus(sp.attacks[0]) == 5 and sp.damage_expr(sp.attacks[0]) == "1d8+3", "Spider bite +5, 1d8+3")
	check(sp.attacks[0].rider_dc == 11, "Spider poison DC 11")
	check(f.speed_cells() == 6 and et.speed_cells() == 4, "speed in cells")
	check(et.sight_cells() == 12 and sp.sight_cells() == 8, "sight in cells")
