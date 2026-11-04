class_name AttackData
extends Resource
## One attack a creature can make (weapon or natural attack). Ranges are in feet; 1 cell = 5 ft.
##
## Heroes: leave to_hit_override at -99 and the bonus is worked out (ability mod + proficiency +
## magic). Monsters: set to_hit_override and damage straight from the SRD stat block.

enum Kind { MELEE, RANGED }
enum Ability { STR, DEX, FINESSE, SPELL }   ## FINESSE = better of STR/DEX; SPELL = spellcasting ability

@export var name := "Attack"
@export var kind := Kind.MELEE
@export var ability := Ability.STR
@export var reach_ft := 5               ## melee reach
@export var range_ft := 0               ## ranged: normal range
@export var long_range_ft := 0          ## ranged: long range (disadvantage), 0 = none
@export var damage := "1d6"             ## dice only for heroes ("1d8"); full expression for monsters
@export var damage_type := "slashing"
@export var proficient := true
@export var magic_bonus := 0
## Monsters: the stat block's "+5 to hit"; -99 = compute it (heroes).
@export var to_hit_override := -99
## Extra damage riding on a hit, e.g. the Giant Spider's poison (save for half). Empty = none.
@export var rider_damage := ""
@export var rider_damage_type := ""
@export var rider_save := ""            ## ability of the save: "CON", "DEX"...
@export var rider_dc := 0
@export var sfx := ""                   ## sound id (assets/sfx/<id>.wav), "" = default

const FT_PER_CELL := 5


func reach_cells() -> int:
	return maxi(1, reach_ft / FT_PER_CELL)


func range_cells() -> int:
	return range_ft / FT_PER_CELL


func long_range_cells() -> int:
	return long_range_ft / FT_PER_CELL
