class_name CreatureStats
extends Resource
## A stat block (simplified 5e SRD) shared by heroes and monsters. This is the *definition*;
## current HP, conditions etc. live on the actor at runtime (Phase 2 step 5).

enum Size { TINY, SMALL, MEDIUM, LARGE, HUGE }

@export var id := ""
@export var display_name := ""
@export_group("Class / type")
@export var class_id := ""              ## heroes: "fighter", "rogue", "cleric", "wizard"
@export var level := 0                  ## heroes
@export var challenge := 0.0            ## monsters: CR
@export var xp := 0                     ## monsters: XP for defeating it
@export var size := Size.MEDIUM
@export var creature_type := "humanoid"
@export_group("Abilities")
@export var str_score := 10
@export var dex_score := 10
@export var con_score := 10
@export var int_score := 10
@export var wis_score := 10
@export var cha_score := 10
@export var save_proficiencies: Array[String] = []   ## "STR", "DEX"...
@export_group("Defence")
@export var max_hp := 10
@export var hit_dice := "1d8"           ## e.g. "5d10" (heroes, for short rests) / "4d10+4" (monsters)
@export var armor_class := 10
@export var resistances: Array[String] = []
@export var vulnerabilities: Array[String] = []   ## double damage (e.g. skeletons: bludgeoning)
@export var immunities: Array[String] = []
## Conditions that can't be put on it ("restrained"...; heroes: from rings, Equipment.build_stats).
@export var condition_immunities: Array[String] = []
## Special monster traits (SRD): "pack_tactics" (advantage when an ally is next to the target),
## "martial_advantage" (+2d6 once a turn when an ally is next to the target), "undead_fortitude"
## (CON save to drop to 1 HP instead of 0), "turn_resistance" (advantage vs Turn Undead).
@export var traits: Array[String] = []
@export_group("Movement")
@export var speed_ft := 30
@export var fly := false                ## floats/flies: ignores difficult terrain (later)
@export var sight_ft := 40              ## how far it notices the party (combat start); 8 cells
@export_group("Offence")
@export var proficiency_bonus := 2
@export var attacks: Array[AttackData] = []
@export var extra_attacks := 0          ## Fighter 5: Extra Attack = 1 (two attacks per Attack action)
## Spells and abilities this creature can use (data/spells/*.tres).
@export var powers: Array[SpellData] = []
@export_group("Skills")
@export var skill_proficiencies: Array[String] = []   ## "stealth", "athletics", "perception"...
@export var skill_expertise: Array[String] = []       ## double proficiency (Rogue)
## Monsters: skill bonuses straight from the stat block (e.g. {"stealth": 7}); overrides the maths.
@export var skill_overrides := {}
@export_group("Spellcasting")
@export var spell_ability := ""         ## "INT" (wizard), "WIS" (cleric), "" = none
## Slots per spell level: index 0 = 1st level. Level 5 full caster: [4, 3, 2].
@export var spell_slots: Array[int] = []
@export_group("Equipment")
## SRD class proficiencies: armour tags ("light", "medium", "heavy", "shield") and weapon tags
## ("simple", "martial") or single weapon ids ("rapier", "light_crossbow"). See Equipment.
@export var armor_training: Array[String] = []
@export var weapon_training: Array[String] = []
## Item ids the hero starts wearing / wielding (data/items/). Heroes only: their armor_class and
## attacks here are replaced by what Equipment.build_stats() works out from the equipment.
@export var starting_equipment: Array[String] = []

## Runtime only (set by Equipment.build_stats on a hero's own copy): ring bonus to every save,
## armour that gives disadvantage on Stealth.
var item_save_bonus := 0
var stealth_disadvantage := false
## Runtime only (Progression.apply on a hero copy): a natural roll this high crits (Champion 19),
## Sneak Attack d6s, Destroy Undead CR (-1 = none).
var crit_range := 20
var sneak_dice := 0
var destroy_undead_cr := -1.0

const FT_PER_CELL := 5


static func modifier_for(score: int) -> int:
	return floori((score - 10) / 2.0)


func score(ability: String) -> int:
	match ability.to_upper():
		"STR": return str_score
		"DEX": return dex_score
		"CON": return con_score
		"INT": return int_score
		"WIS": return wis_score
		"CHA": return cha_score
	push_error("unknown ability " + ability)
	return 10


func mod(ability: String) -> int:
	return modifier_for(score(ability))


func initiative_bonus() -> int:
	return mod("DEX")


func save_bonus(ability: String) -> int:
	var b := mod(ability) + item_save_bonus
	if ability.to_upper() in save_proficiencies:
		b += proficiency_bonus
	return b


func spell_save_dc() -> int:
	return 8 + proficiency_bonus + mod(spell_ability) if spell_ability != "" else 0


func spell_attack_bonus() -> int:
	return proficiency_bonus + mod(spell_ability) if spell_ability != "" else 0


func speed_cells() -> int:
	return speed_ft / FT_PER_CELL


func sight_cells() -> int:
	return sight_ft / FT_PER_CELL


## The ability modifier an attack uses.
func attack_ability_mod(a: AttackData) -> int:
	match a.ability:
		AttackData.Ability.STR: return mod("STR")
		AttackData.Ability.DEX: return mod("DEX")
		AttackData.Ability.FINESSE: return maxi(mod("STR"), mod("DEX"))
		AttackData.Ability.SPELL: return mod(spell_ability) if spell_ability != "" else 0
	return 0


## Total to-hit bonus for an attack.
func attack_bonus(a: AttackData) -> int:
	if a.to_hit_override != -99:
		return a.to_hit_override
	return attack_ability_mod(a) + (proficiency_bonus if a.proficient else 0) + a.magic_bonus


## Damage expression for an attack, e.g. "1d8+3". Monsters' damage strings are used as written.
func damage_expr(a: AttackData) -> String:
	if a.to_hit_override != -99:
		return a.damage
	var bonus := attack_ability_mod(a) + a.magic_bonus
	if bonus == 0:
		return a.damage
	return "%s%+d" % [a.damage, bonus]


## Number of attacks one Attack action makes.
func attacks_per_action() -> int:
	return 1 + extra_attacks


const SKILL_ABILITY := {
	"athletics": "STR", "acrobatics": "DEX", "stealth": "DEX", "sleight_of_hand": "DEX",
	"perception": "WIS", "insight": "WIS", "survival": "WIS", "medicine": "WIS",
	"arcana": "INT", "investigation": "INT", "religion": "INT", "history": "INT",
	"intimidation": "CHA", "persuasion": "CHA", "deception": "CHA",
	"thieves_tools": "DEX",
}


func skill_bonus(skill: String) -> int:
	if skill_overrides.has(skill):
		return skill_overrides[skill]
	var b := mod(SKILL_ABILITY.get(skill, "STR"))
	if skill in skill_expertise:
		b += proficiency_bonus * 2
	elif skill in skill_proficiencies:
		b += proficiency_bonus
	return b


func passive_perception() -> int:
	return 10 + skill_bonus("perception")
