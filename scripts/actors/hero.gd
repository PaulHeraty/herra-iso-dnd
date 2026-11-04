class_name Hero
extends Actor
## One of the four party members. Stats/classes come from data/ in Phase 2; for now the class
## only picks the sprite.

enum HeroClass { FIGHTER, ROGUE, CLERIC, MAGE }

const SPRITES := {
	HeroClass.FIGHTER: preload("res://assets/sprites/heroes/fighter.png"),
	HeroClass.ROGUE: preload("res://assets/sprites/heroes/rogue.png"),
	HeroClass.CLERIC: preload("res://assets/sprites/heroes/cleric.png"),
	HeroClass.MAGE: preload("res://assets/sprites/heroes/mage.png"),
}

@export var hero_class := HeroClass.FIGHTER:
	set(v):
		hero_class = v
		if is_node_ready():
			_apply_class()

var hero_name := ""


func _ready() -> void:
	_apply_class()


func _apply_class() -> void:
	sprite.texture = SPRITES[hero_class]
	if hero_name == "":
		hero_name = HeroClass.keys()[hero_class].capitalize()
	name = hero_name
