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
##   paralyzed   loses its turns, auto-fails STR and DEX saves; attacks against have advantage and
##               hits from within 5 ft are critical (Hold Person, ghoul claws). Save at the end of each turn.
##   turned      (undead, Turn Undead) won't attack, moves away from the cleric; ends on damage.
##   death_ward  (Death Ward) the first time damage would drop it to 0 HP it stays at 1 instead.

var id := ""
var rounds := 0          ## turns of the bearer left; ticks at the start of its turn. -1 = until removed
var source: Actor        ## who applied it (concentration, frightened source)
var spell: SpellData
## A save that ends it at the end of each of the bearer's turns ("" = none): Hold Person WIS, ghoul CON.
var save_ability := ""
var save_dc := 0


func _init(cid := "", r := 0, src: Actor = null, sp: SpellData = null) -> void:
	id = cid
	rounds = r
	source = src
	spell = sp


const NAMES := {
	"blessed": "Blessed", "prone": "Prone", "restrained": "Restrained",
	"hidden": "Hidden", "frightened": "Frightened", "shielded": "Shielded",
	"concentrating": "Concentrating", "dying": "Dying", "stable": "Stable",
	"paralyzed": "Paralyzed", "turned": "Turned", "death_ward": "Death Ward",
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
	if target.has_condition("restrained") or target.has_condition("paralyzed"):
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


## Paralyzed creatures fail STR and DEX saves outright.
static func auto_fails_save(who: Actor, ability: String) -> bool:
	return ability.to_upper() in ["STR", "DEX"] and who.has_condition("paralyzed")


## Flat AC bonus from conditions.
static func ac_bonus(who: Actor) -> int:
	return 5 if who.has_condition("shielded") else 0


## Extra dice added to attack rolls and saves ("1d4" for blessed), "" if none.
static func roll_bonus_dice(who: Actor) -> String:
	return "1d4" if who.has_condition("blessed") else ""


static func speed_zero(who: Actor) -> bool:
	return who.has_condition("restrained")


## Icons (assets/ui/condition_icons.png, 9x9 cells, order as in tools/godot/gen_icons.gd).
const ICONS := preload("res://assets/ui/condition_icons.png")
const ICON_SIZE := 9
const ICON_INDEX := {
	"blessed": 0, "prone": 1, "restrained": 2, "hidden": 3, "frightened": 4, "shielded": 5,
	"concentrating": 6, "dying": 7, "stable": 8, "paralyzed": 9, "turned": 10, "death_ward": 11,
}
const EFFECTS := {
	"blessed": "+1d4 to attack rolls and saving throws.",
	"prone": "Own attacks have disadvantage. Attacks against: advantage within 5 ft, disadvantage from further. Standing up costs half your speed.",
	"restrained": "Can't move. Own attacks and DEX saves have disadvantage; attacks against have advantage.",
	"hidden": "Your next attack has advantage.",
	"frightened": "Own attacks have disadvantage.",
	"shielded": "+5 AC until the start of your next turn.",
	"concentrating": "Taking damage forces a CON save (DC 10 or half the damage) or the spell ends.",
	"dying": "At 0 HP: a death save each turn. 3 successes = stable, 3 failures = death. Healing brings you back.",
	"stable": "Unconscious but no longer dying. Healing brings you back.",
	"paralyzed": "Can't move or act. Fails STR and DEX saves. Attacks against have advantage; hits from within 5 ft are critical. Saves again at the end of each turn.",
	"turned": "Must move away from the cleric and can't attack. Ends if it takes damage.",
	"death_ward": "The first time damage would drop you to 0 HP, you drop to 1 HP instead (then it ends).",
}


static func icon_rect(cid: String) -> Rect2:
	return Rect2(ICON_INDEX.get(cid, 0) * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)


## Icons to show for a creature: its conditions, plus concentrating / dying / stable.
static func shown_ids(a: Actor) -> PackedStringArray:
	var out: PackedStringArray = []
	if a.hp <= 0 and not a.dead and a is Hero:
		out.append("stable" if a.stable else "dying")
	for c in a.conditions:
		if ICON_INDEX.has(c.id) and not c.id in out:
			out.append(c.id)
	if a.concentrating:
		out.append("concentrating")
	return out


## Hover text for an icon: "Blessed (8 rounds): +1d4 to ..."
static func tooltip(a: Actor, cid: String) -> String:
	var name := display(cid)
	if cid == "concentrating" and a.concentrating:
		name = "Concentrating on %s" % a.concentrating.display_name
	elif cid == "dying":
		name = "Dying (saves %d/3, failures %d/3)" % [a.death_successes, a.death_failures]
	var c := a.get_condition(cid)
	if c and c.rounds > 0:
		name += " (%d round%s)" % [c.rounds, "" if c.rounds == 1 else "s"]
	return "%s: %s" % [name, EFFECTS.get(cid, "")]
