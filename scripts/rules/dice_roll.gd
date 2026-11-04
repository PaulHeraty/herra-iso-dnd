class_name DiceRoll
extends RefCounted
## The result of a roll: every die (for the log and the dice animation), the modifier and total.

var expr := ""
var dice: Array[int] = []       ## each die rolled, in order
var sides: Array[int] = []      ## faces of each die (parallel to `dice`)
var modifier := 0
var total := 0
var natural := 0                ## d20 rolls: the kept die (20 = crit, 1 = fumble)


func is_crit() -> bool:
	return natural == 20


func is_fumble() -> bool:
	return natural == 1


## "8 + 5 = 13", "[3, 6] + 2 = 11"
func describe() -> String:
	var d := str(dice[0]) if dice.size() == 1 else str(dice)
	if natural != 0 and dice.size() == 2:
		d = "%d (%d, %d)" % [natural, dice[0], dice[1]]
	if modifier == 0:
		return "%s = %d" % [d, total]
	return "%s %s %d = %d" % [d, "+" if modifier > 0 else "-", absi(modifier), total]
