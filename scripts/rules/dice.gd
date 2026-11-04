class_name Dice
## Dice rolling for the 5e rules. Rolls are really random (seeded from the clock) unless a test
## calls Dice.seed_rng(n).
##
## Expressions: "d20", "1d8+3", "2d6", "8d6", "1d4-1", "3", "2d8+1d6+2" (terms joined by + or -).

static var _rng: RandomNumberGenerator


static func rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng


## Make rolls repeatable (tests).
static func seed_rng(s: int) -> void:
	rng().seed = s


## One die with `sides` faces.
static func die(sides: int) -> int:
	return rng().randi_range(1, sides)


## Roll an expression. Returns a DiceRoll with every die, the modifier and the total.
static func roll(expr: String) -> DiceRoll:
	var r := DiceRoll.new()
	r.expr = expr
	var terms := parse(expr)
	if terms.is_empty():
		push_error("Dice: can't parse '%s'" % expr)
		return r
	for t: Dictionary in terms:
		if t.sides == 0:
			r.modifier += t.sign * t.count
		else:
			for i in t.count:
				var v := die(t.sides)
				r.dice.append(v)
				r.sides.append(t.sides)
				r.total += t.sign * v
	r.total += r.modifier
	return r


## A d20 roll with a bonus, optional advantage (+1) / disadvantage (-1).
## DiceRoll.natural holds the kept d20; .dice holds both when rolled twice.
static func d20(bonus := 0, advantage := 0) -> DiceRoll:
	var r := DiceRoll.new()
	r.expr = "d20%+d" % bonus if bonus != 0 else "d20"
	var a := die(20)
	r.dice.append(a)
	r.sides.append(20)
	r.natural = a
	if advantage != 0:
		var b := die(20)
		r.dice.append(b)
		r.sides.append(20)
		r.natural = maxi(a, b) if advantage > 0 else mini(a, b)
	r.modifier = bonus
	r.total = r.natural + bonus
	return r


## Double the dice of an expression (critical hit damage): "1d8+3" -> "2d8+3".
static func crit(expr: String) -> String:
	var out := ""
	for t: Dictionary in parse(expr):
		var s := "+" if t.sign > 0 else "-"
		if out == "" and t.sign > 0:
			s = ""
		out += s + ("%dd%d" % [t.count * 2, t.sides] if t.sides > 0 else str(t.count))
	return out


## Average result of an expression (for AI and tooltips).
static func average(expr: String) -> float:
	var a := 0.0
	for t: Dictionary in parse(expr):
		a += t.sign * (t.count * (t.sides + 1) / 2.0 if t.sides > 0 else float(t.count))
	return a


## "2d6+3" -> [{sign 1, count 2, sides 6}, {sign 1, count 3, sides 0}]. [] if malformed.
static func parse(expr: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := expr.replace(" ", "").to_lower()
	if s == "":
		return out
	var re := RegEx.create_from_string("([+-]?)(\\d*)(?:d(\\d+))?")
	var pos := 0
	while pos < s.length():
		var m := re.search(s, pos)
		if m == null or m.get_start() != pos or m.get_string() == "" or m.get_string() in ["+", "-"]:
			out.clear()
			return out
		var sign := -1 if m.get_string(1) == "-" else 1
		var has_d := m.get_string(3) != ""
		var count := int(m.get_string(2)) if m.get_string(2) != "" else (1 if has_d else -1)
		if count < 0:
			out.clear()
			return out
		out.append({sign = sign, count = count, sides = int(m.get_string(3)) if has_d else 0})
		pos = m.get_end()
		if pos < s.length() and s[pos] not in ["+", "-"]:
			out.clear()
			return out
	return out
