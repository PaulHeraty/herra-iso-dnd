class_name Hero
extends Actor
## One of the four party members. Stats/classes come from data/ in Phase 2; for now the class
## only picks the sprite: the walk sheet <class>_sheet.png if it exists, else the single
## front-facing <class>.png.

enum HeroClass { FIGHTER, ROGUE, CLERIC, MAGE }

const SPRITE_DIR := "res://assets/sprites/heroes/"
## Stat block per class (the Mage is a 5e Wizard).
const STATS := {
	HeroClass.FIGHTER: "res://data/heroes/fighter.tres",
	HeroClass.ROGUE: "res://data/heroes/rogue.tres",
	HeroClass.CLERIC: "res://data/heroes/cleric.tres",
	HeroClass.MAGE: "res://data/heroes/wizard.tres",
}

@export var hero_class := HeroClass.FIGHTER:
	set(v):
		hero_class = v
		if is_node_ready():
			_apply_class()

var hero_name := ""


func _ready() -> void:
	_apply_class()
	super()


func _apply_class() -> void:
	var key: String = HeroClass.keys()[hero_class].to_lower()
	var sheet_path := SPRITE_DIR + key + "_sheet.png"
	if ResourceLoader.exists(sheet_path):
		sprite.texture = load(sheet_path)
		sprite.hframes = 5
		sprite.vframes = 2
		walk_sheet = true
	else:
		sprite.texture = load(SPRITE_DIR + key + ".png")
		sprite.hframes = 1
		sprite.vframes = 1
		walk_sheet = false
	sprite.frame = 0
	stats = load(STATS[hero_class])
	if hero_name == "":
		hero_name = key.capitalize()
	name = hero_name


func _on_hurt() -> void:
	_flash()
	Sfx.play("hero_hurt")


## 0 HP: unconscious (5e death saves come later). Lies down, greyed.
func _on_down() -> void:
	Sfx.play("hero_hurt", 0.0, 0.8)
	var tw := create_tween()
	tw.tween_property(sprite, "rotation_degrees", -90.0, 0.25)
	sprite.modulate = Color(0.55, 0.55, 0.65)
