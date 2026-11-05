class_name SpellData
extends Resource
## A spell, class ability or monster power (5e SRD, simplified). Data only; CombatManager resolves
## it. Ranges in feet (1 cell = 5 ft).

enum Kind { SPELL, ABILITY, MONSTER }
enum CastTime { ACTION, BONUS, REACTION, FREE, ATTACK }   ## ATTACK = replaces one attack (Shove)
## Who/what it targets.
##   ENEMY / ALLY / ANY: creatures (up to max_targets)   SELF: the caster
##   AREA: a square of area_size x area_size cells centred on a chosen cell (Fireball: 3)
##   LINE / CONE: from the caster, length = range (cone width grows with distance)
enum Target { ENEMY, ALLY, ANY, SELF, AREA, LINE, CONE }
## How it resolves.
##   ATTACK: spell/weapon attack roll vs AC   SAVE: target saves vs DC   AUTO: just happens
##   HEAL: restore HP                          CONTEST: ability contest (Shove)
enum Resolve { ATTACK, SAVE, AUTO, HEAL, CONTEST }
enum Recharge { NONE, SHORT_REST, LONG_REST, DICE }       ## DICE = "Recharge 5-6" on the d6

@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var kind := Kind.SPELL
@export var level := 0                       ## spell level; 0 = cantrip (no slot)
## Spells: the classes whose spell list has it ("wizard", "cleric"); who can read it from a scroll.
@export var classes: Array[String] = []
@export var cast_time := CastTime.ACTION
@export_group("Targeting")
@export var target := Target.ENEMY
@export var range_ft := 30                   ## 0 = self, 5 = touch
@export var area_size := 1                   ## AREA: side of the square in cells
@export var max_targets := 1                 ## ENEMY/ALLY/ANY: how many may be chosen
@export var needs_los := true
@export var hits_allies := true              ## AREA/LINE/CONE: allies in the area are affected too
@export_group("Effect")
@export var resolve := Resolve.AUTO
@export var save_ability := ""               ## SAVE: "DEX", "WIS"...
@export var half_on_save := false
## Monsters: the stat block's numbers (-99 = work it out from the caster's spellcasting).
@export var attack_bonus_override := -99
@export var dc_override := -99
## CONTEST: the caster's skill vs the target's best of these skills (Shove: athletics vs
## athletics/acrobatics). Hide: stealth vs passive perception.
@export var contest_skill := ""
@export var resist_skills: Array[String] = []
@export var damage := ""                     ## dice, e.g. "8d6"; per dart for missiles
@export var damage_type := ""
@export var add_ability_mod := false         ## add the spellcasting modifier (Cure Wounds)
@export var add_level := false               ## add the caster's level (Second Wind)
@export var heal := ""                       ## HEAL: dice
@export var darts := 0                       ## Magic Missile: number of auto-hit darts
## Upcasting: extra damage/heal dice per slot level above `level` (e.g. "1d6"), extra darts/targets.
@export var upcast_dice := ""
@export var upcast_darts := 0
@export var upcast_targets := 0
## Cantrips: dice count at character levels 5 / 11 / 17 (index 0 = levels 1-4).
@export var cantrip_dice: Array[int] = []
@export_group("Conditions")
@export var condition := ""                  ## applied on a failed save / hit / always (AUTO): "blessed"...
@export var condition_rounds := 0
@export var concentration := false
@export_group("Uses")
@export var uses := 0                        ## per rest (0 = unlimited / slot-based)
@export var recharge := Recharge.NONE
@export_group("Presentation")
@export var sfx := ""
@export var vfx := ""                        ## effect id for the VFX layer (Phase 3 steps 3/6)
@export var big_moment := false              ## full dice scene by default (Fireball)

const FT_PER_CELL := 5


func range_cells() -> int:
	return range_ft / FT_PER_CELL


func is_cantrip() -> bool:
	return kind == Kind.SPELL and level == 0


## Spells of 1st level and up spend a slot, except when read from a scroll (the scroll is used up).
func uses_slot() -> bool:
	return kind == Kind.SPELL and level > 0 and not has_meta("scroll")


## The description without its upcasting sentence ("+1d6 per slot above 3rd."): for scrolls,
## which always cast at their own level.
func description_at_level() -> String:
	return RegEx.create_from_string(" ?\\+\\d+[^.]*per slot above[^.]*\\.").sub(description, "", true)


## A spell read from a spell scroll (CombatManager.scroll_power).
func is_scroll() -> bool:
	return has_meta("scroll")


## Spell Scroll (SRD): the save DC and attack bonus a scroll of this spell level uses.
static func scroll_dc(spell_level: int) -> int:
	return [13, 13, 13, 15, 15, 17, 17, 18, 18, 19][clampi(spell_level, 0, 9)]


static func scroll_attack_bonus(spell_level: int) -> int:
	return scroll_dc(spell_level) - 8


## Damage dice for a caster of `char_level`, cast with a slot of `slot_level`.
func damage_for(char_level: int, slot_level: int) -> String:
	return _scaled(damage, char_level, slot_level)


func heal_for(char_level: int, slot_level: int) -> String:
	return _scaled(heal, char_level, slot_level)


func darts_for(slot_level: int) -> int:
	return darts + upcast_darts * maxi(0, slot_level - level)


func targets_for(slot_level: int) -> int:
	return max_targets + upcast_targets * maxi(0, slot_level - level)


func _scaled(dice: String, char_level: int, slot_level: int) -> String:
	if dice == "":
		return ""
	var out := dice
	if is_cantrip() and not cantrip_dice.is_empty():
		var tier := 0
		for t in [5, 11, 17]:
			if char_level >= t:
				tier += 1
		var n: int = cantrip_dice[mini(tier, cantrip_dice.size() - 1)]
		var terms := Dice.parse(dice)
		if not terms.is_empty() and terms[0].sides > 0:
			out = "%dd%d" % [n, terms[0].sides]
			for i in range(1, terms.size()):
				var t: Dictionary = terms[i]
				out += ("+" if t.sign > 0 else "-") + ("%dd%d" % [t.count, t.sides] if t.sides > 0 else str(t.count))
	if upcast_dice != "" and slot_level > level:
		for i in slot_level - level:
			out += "+" + upcast_dice
	return out


## Spell attack bonus / save DC for this caster.
func attack_bonus_for(caster: CreatureStats) -> int:
	return attack_bonus_override if attack_bonus_override != -99 else caster.spell_attack_bonus()


func dc_for(caster: CreatureStats) -> int:
	return dc_override if dc_override != -99 else caster.spell_save_dc()
