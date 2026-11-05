class_name Hero
extends Actor
## One of the four party members. The class picks the stat block (data/heroes/) and the sprites:
## the walk sheet <class>_sheet.png (16x24 cells: idle + walk, front/back) and the action sheet
## <class>_actions.png (32x32 cells, tools/godot/gen_hero_actions.gd): attack, shoot, cast, hurt,
## down. While an action plays the sprite switches to the action sheet, then back.

signal action_finished(anim: String)

enum HeroClass { FIGHTER, ROGUE, CLERIC, MAGE }

const SPRITE_DIR := "res://assets/sprites/heroes/"
## Stat block per class (the Mage is a 5e Wizard).
const STATS := {
	HeroClass.FIGHTER: "res://data/heroes/fighter.tres",
	HeroClass.ROGUE: "res://data/heroes/rogue.tres",
	HeroClass.CLERIC: "res://data/heroes/cleric.tres",
	HeroClass.MAGE: "res://data/heroes/wizard.tres",
}
const WALK_OFFSET := Vector2(-8, -22)
const ACTION_OFFSET := Vector2(-16, -30)
const ACTION_COLS := 16
## Action sheet animations: [first column, frame count, fps]. Must match gen_hero_actions.gd.
## cast: frame 0 = raise, then frames 1-3 loop until end_action(). down: holds its last frame
## (lying) until the hero gets up.
const ACTION_ANIMS := {
	"attack": [0, 4, 13.0],
	"shoot": [4, 3, 7.0],
	"cast": [7, 4, 9.0],
	"hurt": [11, 2, 8.0],
	"down": [13, 3, 9.0],
}
## Spells leave from here while casting (world px from the feet, front / back view, unmirrored):
## the Mage's raised staff gem, the Cleric's lifted holy symbol.
const CAST_POINTS := {
	HeroClass.MAGE: [Vector2(5, -22), Vector2(-6, -22)],
	HeroClass.CLERIC: [Vector2(-6, -20), Vector2(5, -20)],
}
const CAST_HOLD_MAX := 6.0          ## safety: a cast pose never sticks longer than this

@export var hero_class := HeroClass.FIGHTER:
	set(v):
		if v != hero_class:
			equipment.clear()
		hero_class = v
		if is_node_ready():
			_apply_class()

var hero_name := ""
## The class stat block as written in data/heroes/ (before equipment). `stats` is this hero's own
## copy with AC, attacks, speed and save bonus worked out from `equipment` (Equipment.build_stats).
var base_stats: CreatureStats
## slot -> item id (Equipment.SLOTS). Empty at spawn = the class's starting equipment.
var equipment := {}
var _walk_tex: Texture2D
var _action_tex: Texture2D
var _action := ""
var _at := 0.0


func _ready() -> void:
	_apply_class()
	super()


func _apply_class() -> void:
	var key: String = HeroClass.keys()[hero_class].to_lower()
	var sheet_path := SPRITE_DIR + key + "_sheet.png"
	if ResourceLoader.exists(sheet_path):
		_walk_tex = load(sheet_path)
		walk_sheet = true
	else:
		_walk_tex = load(SPRITE_DIR + key + ".png")
		walk_sheet = false
	var act_path := SPRITE_DIR + key + "_actions.png"
	_action_tex = load(act_path) if walk_sheet and ResourceLoader.exists(act_path) else null
	_use_walk_sheet()
	sprite.frame = 0
	base_stats = load(STATS[hero_class])
	if equipment.is_empty():
		equipment = Equipment.starting(base_stats)
	refresh_stats()
	if hero_name == "":
		hero_name = key.capitalize()
	name = hero_name


func _use_walk_sheet() -> void:
	sprite.texture = _walk_tex
	sprite.hframes = 5 if walk_sheet else 1
	sprite.vframes = 2 if walk_sheet else 1
	sprite.offset = WALK_OFFSET


# --- actions ---------------------------------------------------------------------------------

func has_action(anim: String) -> bool:
	return _action_tex != null and ACTION_ANIMS.has(anim)


## Play an action animation (no-op without an action sheet). attack / shoot / hurt return to
## idle by themselves; cast holds its glow until end_action(); down stays lying.
func play_action(anim: String) -> void:
	if not has_action(anim):
		return
	if _action == "down" and anim != "down" and not is_alive():
		return                      # lying down: only getting up (revive) ends it
	sprite.rotation_degrees = 0.0
	if _action == "":
		sprite.texture = _action_tex
		sprite.hframes = ACTION_COLS
		sprite.vframes = 2
		sprite.offset = ACTION_OFFSET
	_action = anim
	_at = 0.0
	_show_action_frame()


## Seconds until the frame where an action lands (the attack's strike, the bow's release).
func action_hit_time(anim: String) -> float:
	if not has_action(anim):
		return 0.0
	var a: Array = ACTION_ANIMS[anim]
	return (1.0 if anim == "attack" else 2.0) / a[2]


func current_action() -> String:
	return _action


## End a held action (the cast pose) and go back to the walk sheet.
func end_action() -> void:
	if _action == "" or (_action == "down" and not is_alive()):
		return
	var done := _action
	_action = ""
	_use_walk_sheet()
	sprite.frame = _row * sprite.hframes
	action_finished.emit(done)


func _process(delta: float) -> void:
	if _action == "":
		super(delta)
		return
	_at += delta
	var a: Array = ACTION_ANIMS[_action]
	var n := int(_at * a[2])
	match _action:
		"cast":
			if _at > CAST_HOLD_MAX:
				end_action()
				return
		"down":
			pass
		_:
			if n >= a[1]:
				end_action()
				return
	_show_action_frame()


func _show_action_frame() -> void:
	var a: Array = ACTION_ANIMS[_action]
	var n := int(_at * a[2])
	var i: int
	if _action == "cast":
		i = 0 if n == 0 else 1 + (n - 1) % (a[1] - 1)
	else:
		i = mini(n, a[1] - 1)
	sprite.frame = _row * ACTION_COLS + a[0] + i


func _update_facing_visual() -> void:
	if _action == "":
		super()
		return
	var v := IsoGrid.rotate_dir(facing)
	var screen := Vector2i(v.x - v.y, v.x + v.y)
	if screen.x != 0:
		sprite.flip_h = screen.x > 0
	if screen.y != 0:
		_row = 0 if screen.y > 0 else 1
	_show_action_frame()


# --- hurt / down / death -----------------------------------------------------------------------

func _on_hurt() -> void:
	_flash()
	Sfx.play("hero_hurt")
	if _action == "" or _action == "hurt":
		play_action("hurt")


## 0 HP: unconscious (death saves). Drops to a knee and falls over, greyed.
func _on_down() -> void:
	Sfx.play("hero_hurt", 0.0, 0.8)
	_lie_down(false)


func _lie_down(instant: bool) -> void:
	sprite.modulate = Color(0.55, 0.55, 0.65)
	if _action_tex == null:
		if instant:
			sprite.rotation_degrees = -90.0
		else:
			create_tween().tween_property(sprite, "rotation_degrees", -90.0, 0.25)
		return
	play_action("down")
	if instant:
		_at = 10.0
		_show_action_frame()


## Back on their feet with `amount` HP (stand up, colour back).
func revive(amount: int) -> void:
	hp = clampi(amount, 1, stats.max_hp)
	death_successes = 0
	death_failures = 0
	stable = false
	_on_revived()


func _on_revived() -> void:
	sprite.modulate = Color.WHITE
	if _action_tex == null:
		create_tween().tween_property(sprite, "rotation_degrees", 0.0, 0.25)
		return
	if _action == "down":
		_action = ""
		_use_walk_sheet()
		sprite.frame = _row * sprite.hframes
		# a little hop as they get up
		var tw := create_tween()
		tw.tween_property(sprite, "position:y", -2.0, 0.08)
		tw.tween_property(sprite, "position:y", 0.0, 0.1)


## Three failed death saves (or massive damage): stays down for good, darker.
func on_died() -> void:
	_lie_down(true)
	sprite.modulate = Color(0.32, 0.3, 0.36)


## Lying down already (arriving on a new floor while unconscious): no sound, no animation.
func restore_down() -> void:
	_lie_down(true)


## Where spells leave from: the raised staff gem / holy symbol while casting, the staff gem when
## standing (Mage), else the chest.
func cast_point() -> Vector2:
	var back := _row == 1
	if _action == "cast" and CAST_POINTS.has(hero_class):
		var p: Vector2 = CAST_POINTS[hero_class][1 if back else 0]
		if sprite.flip_h:
			p.x = -p.x
		return position + p
	if hero_class != HeroClass.MAGE or not walk_sheet:
		return body_position() + Vector2(0, -4)
	var x := -6.0 if back else 5.0          # staff column in the 14x22 drawing
	if sprite.flip_h:
		x = -x
	return position + Vector2(x, -20)


## The walk sheet (portraits crop its front idle frame, whatever the sprite shows right now).
func walk_texture() -> Texture2D:
	return _walk_tex


# --- equipment ---------------------------------------------------------------------------------

## Work `stats` out again from the base stat block + equipment (after equipping something).
func refresh_stats() -> void:
	stats = Equipment.build_stats(base_stats, equipment)


## Put item `item_id` in `slot`. Returns the item ids taken off to make room (they go back in the
## bag), or null if it can't go there (Equipment.cannot_equip says why).
func equip(slot: String, item_id: String) -> Variant:
	var it := ItemData.get_item(item_id)
	if Equipment.cannot_equip(base_stats, it, slot) != "":
		return null
	var off: Array[String] = []
	for s in Equipment.displaced_by(equipment, it, slot):
		off.append(equipment[s])
		equipment.erase(s)
	equipment[slot] = item_id
	refresh_stats()
	return off


## Take off whatever is in `slot`; returns its item id ("" if the slot was empty).
func unequip(slot: String) -> String:
	var iid: String = equipment.get(slot, "")
	equipment.erase(slot)
	refresh_stats()
	return iid
