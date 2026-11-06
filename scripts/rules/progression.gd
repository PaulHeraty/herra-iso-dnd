class_name Progression
## Character levels 1-5 (5e SRD, simplified). The hero stat blocks in data/heroes/ are written at
## level 1; apply() turns a copy into the stat block for any level: proficiency bonus, hit points
## (max die at 1st level, then the fixed average + CON per level), hit dice, spell slots, the
## powers learned so far, ability score improvements and the numeric class features.
## Pure statics, so the rules tests can run them headless. Equipment.build_stats() calls apply().
##
## XP: SRD thresholds; a fight's XP is split between the heroes who aren't dead (CombatManager).

const MAX_LEVEL := 5
## Total XP needed for each level (index 0 = level 1).
const XP_FOR_LEVEL := [0, 300, 900, 2700, 6500]
const PROFICIENCY := [2, 2, 2, 2, 3]
## Full casters (Cleric, Wizard): slots per spell level, by character level.
const FULL_CASTER_SLOTS := [[2], [3], [4, 2], [4, 3], [4, 3, 2]]

## Per class: hit die, the level each power is learned at (power ids from data/spells/; powers
## not listed are known from level 1), ability score improvements, and what each level brings
## (the level-up summary).
const CLASSES := {
	"fighter": {
		"die": 10, "caster": false,
		"learn": {"action_surge": 2},
		"asi": {4: {"STR": 2}},
		"gains": {
			2: ["Action Surge: one extra action, once per short rest"],
			3: ["Champion: Improved Critical (crits on 19-20)"],
			4: ["Ability Score Improvement: STR +2"],
			5: ["Extra Attack: two attacks per Attack action"],
		},
	},
	"rogue": {
		"die": 8, "caster": false,
		"learn": {"hide": 2, "uncanny_dodge": 5},
		"asi": {4: {"DEX": 2}},
		"gains": {
			2: ["Cunning Action: Hide as a bonus action"],
			3: ["Sneak Attack 2d6"],
			4: ["Ability Score Improvement: DEX +2"],
			5: ["Sneak Attack 3d6", "Uncanny Dodge: halve an attack's damage (reaction)"],
		},
	},
	"cleric": {
		"die": 8, "caster": true,
		"learn": {"turn_undead": 2, "hold_person": 3, "mass_healing_word": 5},
		"asi": {4: {"WIS": 2}},
		"gains": {
			2: ["Channel Divinity: Turn Undead", "Spell slots: 3 x 1st"],
			3: ["2nd-level spells: Hold Person", "Spell slots: 4 x 1st, 2 x 2nd"],
			4: ["Ability Score Improvement: WIS +2", "Spell slots: 3 x 2nd"],
			5: ["3rd-level spells: Mass Healing Word", "Destroy Undead (CR 1/2)", "Sacred Flame 2d8"],
		},
	},
	"wizard": {
		"die": 6, "caster": true,
		"learn": {"scorching_ray": 3, "fireball": 5},
		"asi": {4: {"INT": 2}},
		"gains": {
			2: ["Spell slots: 3 x 1st"],
			3: ["2nd-level spells: Scorching Ray", "Spell slots: 4 x 1st, 2 x 2nd"],
			4: ["Ability Score Improvement: INT +2", "Spell slots: 3 x 2nd"],
			5: ["3rd-level spells: Fireball", "Fire Bolt 2d10"],
		},
	},
}


static func level_for_xp(xp: int) -> int:
	var lvl := 1
	for i in XP_FOR_LEVEL.size():
		if xp >= XP_FOR_LEVEL[i]:
			lvl = i + 1
	return mini(lvl, MAX_LEVEL)


## XP needed for the next level (0 at the top level).
static func xp_for_next(level: int) -> int:
	return XP_FOR_LEVEL[level] if level < MAX_LEVEL else 0


static func class_info(class_id: String) -> Dictionary:
	return CLASSES.get(class_id, {})


## The level a power is learned at for this class (1 if not listed).
static func learn_level(class_id: String, power_id: String) -> int:
	return class_info(class_id).get("learn", {}).get(power_id, 1)


## Hit points at `level`: max hit die + CON at 1st level, then (die/2 + 1) + CON per level.
static func hit_points(class_id: String, con_mod: int, level: int) -> int:
	var die: int = class_info(class_id).get("die", 8)
	return maxi(1, die + con_mod) + (level - 1) * maxi(1, die / 2 + 1 + con_mod)


## Rogue Sneak Attack dice: 1d6 at 1st level, +1d6 every odd level.
static func sneak_dice(level: int) -> int:
	return (level + 1) / 2


## What `level` brings (shown when a hero reaches it). Hit points are added by the caller.
static func gains(class_id: String, level: int) -> Array:
	return class_info(class_id).get("gains", {}).get(level, [])


## Turn `s` (a fresh copy of a level-1 hero stat block) into the stat block for `level`.
static func apply(s: CreatureStats, level: int) -> void:
	var info := class_info(s.class_id)
	if info.is_empty():
		return
	level = clampi(level, 1, MAX_LEVEL)
	s.level = level
	s.proficiency_bonus = PROFICIENCY[level - 1]
	for at: int in info.get("asi", {}):
		if level >= at:
			var asi: Dictionary = info.asi[at]
			for ab: String in asi:
				_add_score(s, ab, asi[ab])
	s.max_hp = hit_points(s.class_id, s.mod("CON"), level)
	s.hit_dice = "%dd%d" % [level, info.die]
	if info.caster:
		var slots: Array[int] = []
		slots.assign(FULL_CASTER_SLOTS[level - 1])
		s.spell_slots = slots
	var known: Array[SpellData] = []
	for p: SpellData in s.powers:
		if learn_level(s.class_id, p.id) <= level:
			known.append(p)
	s.powers = known
	match s.class_id:
		"fighter":
			s.extra_attacks = 1 if level >= 5 else 0
			s.crit_range = 19 if level >= 3 else 20
		"rogue":
			s.sneak_dice = sneak_dice(level)
		"cleric":
			s.destroy_undead_cr = 0.5 if level >= 5 else -1.0


static func _add_score(s: CreatureStats, ab: String, n: int) -> void:
	match ab:
		"STR": s.str_score = mini(20, s.str_score + n)
		"DEX": s.dex_score = mini(20, s.dex_score + n)
		"CON": s.con_score = mini(20, s.con_score + n)
		"INT": s.int_score = mini(20, s.int_score + n)
		"WIS": s.wis_score = mini(20, s.wis_score + n)
		"CHA": s.cha_score = mini(20, s.cha_score + n)
