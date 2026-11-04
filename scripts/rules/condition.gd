class_name Condition
extends RefCounted
## A condition on a creature, with a duration. Definitions + their rules effects live here as
## statics; CombatManager and Rules ask these.
##
##   blessed     +1d4 to attack rolls and saving throws (Bless, concentration)
##   prone       own attacks: disadvantage. Attacks against: advantage within 5 ft, else disadvantage.
##               Standing up costs half your speed.
##   restrained  speed 0. Own attacks: disadvantage. Attacks against: advantage. DEX saves: disadvantage.
##   hidden      next attack has advantage (then the condition ends)
##   frightened  own attacks: disadvantage (while the source can be seen)
##   shielded    +5 AC (Shield, until the start of the caster's next turn)

var id := ""
var rounds := 0          ## turns of the bearer left; ticks at the start of its turn. -1 = until removed
var source: Actor        ## who applied it (concentration, frightened source)
var spell: SpellData


func _init(cid := "", r := 0, src: Actor = null, sp: SpellData = null) -> void:
	id = cid
	rounds = r
	source = src
	spell = sp


const NAMES := {
	"blessed": "Blessed", "prone": "Prone", "restrained": "Restrained",
	"hidden": "Hidden", "frightened": "Frightened", "shielded": "Shielded",
}


static func display(cid: String) -> String:
	return NAMES.get(cid, cid.capitalize())


## Advantage (+1), disadvantage (-1) or neither (0) on an attack, from both sides' conditions.
## 5e: any advantage and any disadvantage cancel out.
static func attack_advantage(attacker: Actor, target: Actor, melee: bool, dist: int) -> int:
	var adv := false
	var dis := false
	if attacker.has_condition("hidden"):
		adv = true
	if attacker.has_condition("prone") or attacker.has_condition("restrained"):
		dis = true
	if attacker.has_condition("frightened"):
		dis = true
	if target.has_condition("restrained"):
		adv = true
	if target.has_condition("prone"):
		if melee and dist <= 1:
			adv = true
		else:
			dis = true
	if target.is_alive() == false:
		adv = true
	if adv and dis:
		return 0
	return 1 if adv else (-1 if dis else 0)


## Advantage/disadvantage on a saving throw.
static func save_advantage(who: Actor, ability: String) -> int:
	if ability.to_upper() == "DEX" and who.has_condition("restrained"):
		return -1
	return 0


## Flat AC bonus from conditions.
static func ac_bonus(who: Actor) -> int:
	return 5 if who.has_condition("shielded") else 0


## Extra dice added to attack rolls and saves ("1d4" for blessed), "" if none.
static func roll_bonus_dice(who: Actor) -> String:
	return "1d4" if who.has_condition("blessed") else ""


static func speed_zero(who: Actor) -> bool:
	return who.has_condition("restrained")
