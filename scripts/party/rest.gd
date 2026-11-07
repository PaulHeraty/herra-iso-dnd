class_name Rest
## Short and long rests (5e, simplified). Out of combat only, and not with an enemy in sight.
##   Short rest: each living hero spends hit dice (class die + CON, at least 1 each) until full HP or
##               out of dice; powers that recharge on a short rest (Second Wind) come back.
##   Long rest:  full HP, all spell slots, all uses, all hit dice; conditions cleared; heroes at
##               0 HP who aren't dead get back up. The dead stay dead.
## Each returns log lines.

## Why the party can't rest right now, or "" if it can.
static func blocked_reason(map: DungeonMap) -> String:
	if map.combat.in_combat:
		return "You can't rest during a fight."
	for m in map.monsters:
		if not m.is_alive():
			continue
		for h in map.party:
			if DungeonMap.grid_distance(m.cell, h.cell) <= m.stats.sight_cells() and map.has_line_of_sight(m.cell, h.cell):
				return "You can't rest with an enemy in sight."
	return ""


static func short_rest(party: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for h: Actor in party:
		if h.dead:
			continue
		var sides := _hit_die_sides(h.stats.hit_dice)
		var spent := 0
		var healed := 0
		while h.hp < h.stats.max_hp and h.hit_dice_left > 0:
			var r := Dice.die(sides) + h.stats.mod("CON")
			h.hit_dice_left -= 1
			spent += 1
			healed += h.heal(maxi(1, r))
		for p: SpellData in h.stats.powers:
			if p.recharge == SpellData.Recharge.SHORT_REST and Progression.uses_of(h.stats, p) > 0:
				h.uses_left[p.id] = Progression.uses_of(h.stats, p)
		var rec := arcane_recovery(h)
		if rec != "":
			out.append(rec)
		if spent > 0:
			out.append("%s spends %d hit %s: +%d HP (%d left)" % [h.display_name(), spent, "die" if spent == 1 else "dice", healed, h.hit_dice_left])
		elif h.hp >= h.stats.max_hp:
			out.append("%s is already at full health" % h.display_name())
		else:
			out.append("%s has no hit dice left" % h.display_name())
	return out


## Arcane Recovery (SRD Wizard): once per long rest, on a short rest, regain expended spell slots
## with a combined level up to half the wizard level (rounded up). Highest slots first.
static func arcane_recovery(h: Actor) -> String:
	if h.uses_left.get("arcane_recovery", 0) <= 0:
		return ""
	var budget := ceili(h.stats.level / 2.0)
	var got: PackedStringArray = []
	for lvl in range(mini(h.stats.spell_slots.size(), 5), 0, -1):
		while budget >= lvl and h.slots_left[lvl - 1] < h.stats.spell_slots[lvl - 1]:
			h.slots_left[lvl - 1] += 1
			budget -= lvl
			got.append(CombatManager.power_tag_level(lvl))
	if got.is_empty():
		return ""
	h.uses_left["arcane_recovery"] = 0
	return "%s: Arcane Recovery - %s-level slot%s back" % [h.display_name(), ", ".join(got), "" if got.size() == 1 else "s"]


static func long_rest(party: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for h: Actor in party:
		if h.dead:
			out.append("%s is dead." % h.display_name())
			continue
		var was_down := not h.is_alive()
		h.conditions.clear()
		h._on_conditions_changed()
		h.concentrating = null
		if was_down and h.has_method("revive"):
			h.revive(h.stats.max_hp)
		else:
			h.heal(h.stats.max_hp)
		h.reset_resources()
		out.append("%s is fully rested (%d HP)" % [h.display_name(), h.hp])
	return out


static func _hit_die_sides(expr: String) -> int:
	var t := Dice.parse(expr)
	return t[0].sides if not t.is_empty() and t[0].sides > 0 else 8
