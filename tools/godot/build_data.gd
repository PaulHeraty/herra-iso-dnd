extends SceneTree
## Writes the starting stat blocks: data/heroes/*.tres (level 5 party) and data/monsters/*.tres.
## Run: Godot_console --headless --path . -s res://tools/godot/build_data.gd
## Overwrites the files. Once they have been hand-tuned in the editor, don't re-run this (or add
## a merge), like the other build_* tools.
##
## Rules content: 5e SRD 5.1 (CC-BY-4.0, see CREDITS.md). The Eye Tyrant is our own original
## monster, written in the same format.

const HERO_DIR := "res://data/heroes/"
const MONSTER_DIR := "res://data/monsters/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HERO_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MONSTER_DIR))
	for s in [_fighter(), _rogue(), _cleric(), _wizard()]:
		_save(s, HERO_DIR)
	for s in [_giant_spider(), _eye_tyrant()]:
		_save(s, MONSTER_DIR)
	quit()


func _save(s: CreatureStats, dir: String) -> void:
	var path := dir + s.id + ".tres"
	var err := ResourceSaver.save(s, path)
	print("wrote ", path, " err=", err)


func _stats(id: String, name: String, scores: Array) -> CreatureStats:
	var s := CreatureStats.new()
	s.id = id
	s.display_name = name
	s.resource_name = name
	s.str_score = scores[0]
	s.dex_score = scores[1]
	s.con_score = scores[2]
	s.int_score = scores[3]
	s.wis_score = scores[4]
	s.cha_score = scores[5]
	return s


func _attack(name: String, kind: AttackData.Kind, ability: AttackData.Ability, damage: String,
		damage_type: String) -> AttackData:
	var a := AttackData.new()
	a.name = name
	a.resource_name = name
	a.kind = kind
	a.ability = ability
	a.damage = damage
	a.damage_type = damage_type
	return a


func _ranged(a: AttackData, normal_ft: int, long_ft: int) -> AttackData:
	a.range_ft = normal_ft
	a.long_range_ft = long_ft
	return a


func _hero(s: CreatureStats, class_id: String, hp: int, hit_dice: String, ac: int, saves: Array) -> void:
	s.class_id = class_id
	s.level = 5
	s.proficiency_bonus = 3
	s.max_hp = hp
	s.hit_dice = hit_dice
	s.armor_class = ac
	s.save_proficiencies = PackedStringArray(saves)
	s.speed_ft = 30


# --- heroes (level 5; HP = max die + average per level + CON) ----------------------------------

func _fighter() -> CreatureStats:
	var s := _stats("fighter", "Fighter", [16, 12, 14, 10, 12, 8])
	_hero(s, "fighter", 44, "5d10", 18, ["STR", "CON"])      # chain mail + shield
	s.extra_attacks = 1                                       # Extra Attack (level 5)
	s.attacks = [
		_attack("Longsword", AttackData.Kind.MELEE, AttackData.Ability.STR, "1d8", "slashing"),
		_ranged(_attack("Handaxe", AttackData.Kind.RANGED, AttackData.Ability.STR, "1d6", "slashing"), 20, 60),
	]
	return s


func _rogue() -> CreatureStats:
	var s := _stats("rogue", "Rogue", [8, 18, 12, 12, 12, 10])
	_hero(s, "rogue", 33, "5d8", 15, ["DEX", "INT"])          # leather armour
	s.attacks = [
		_attack("Shortsword", AttackData.Kind.MELEE, AttackData.Ability.FINESSE, "1d6", "piercing"),
		_ranged(_attack("Shortbow", AttackData.Kind.RANGED, AttackData.Ability.DEX, "1d6", "piercing"), 80, 320),
	]
	return s


func _cleric() -> CreatureStats:
	var s := _stats("cleric", "Cleric", [14, 10, 14, 10, 18, 12])
	_hero(s, "cleric", 38, "5d8", 18, ["WIS", "CHA"])         # chain mail + shield (Life domain)
	s.spell_ability = "WIS"
	s.spell_slots = PackedInt32Array([4, 3, 2])
	s.attacks = [
		_attack("Mace", AttackData.Kind.MELEE, AttackData.Ability.STR, "1d6", "bludgeoning"),
	]
	return s


func _wizard() -> CreatureStats:
	var s := _stats("wizard", "Mage", [8, 14, 12, 18, 12, 10])
	_hero(s, "wizard", 27, "5d6", 12, ["INT", "WIS"])
	s.spell_ability = "INT"
	s.spell_slots = PackedInt32Array([4, 3, 2])
	s.attacks = [
		_attack("Quarterstaff", AttackData.Kind.MELEE, AttackData.Ability.STR, "1d6", "bludgeoning"),
		_ranged(_attack("Light Crossbow", AttackData.Kind.RANGED, AttackData.Ability.DEX, "1d8", "piercing"), 80, 320),
	]
	return s


# --- monsters -------------------------------------------------------------------------------------

func _giant_spider() -> CreatureStats:
	# SRD 5.1 Giant Spider. Simplification: Large, but occupies one cell for now.
	var s := _stats("giant_spider", "Giant Spider", [14, 16, 12, 2, 11, 4])
	s.creature_type = "beast"
	s.size = CreatureStats.Size.LARGE
	s.challenge = 1
	s.xp = 200
	s.proficiency_bonus = 2
	s.max_hp = 26
	s.hit_dice = "4d10+4"
	s.armor_class = 14
	s.speed_ft = 30
	s.sight_ft = 40
	var bite := _attack("Bite", AttackData.Kind.MELEE, AttackData.Ability.DEX, "1d8+3", "piercing")
	bite.to_hit_override = 5
	bite.rider_damage = "2d8"
	bite.rider_damage_type = "poison"
	bite.rider_save = "CON"
	bite.rider_dc = 11
	var web := _ranged(_attack("Web", AttackData.Kind.RANGED, AttackData.Ability.DEX, "0", "none"), 30, 60)
	web.to_hit_override = 5     # restrains (Phase 3 conditions); recharge 5-6
	s.attacks = [bite, web]
	return s


func _eye_tyrant() -> CreatureStats:
	# Our own monster (not from the SRD): a floating eye that shoots gaze rays.
	var s := _stats("eye_tyrant", "Eye Tyrant", [8, 14, 14, 14, 14, 10])
	s.creature_type = "aberration"
	s.challenge = 3
	s.xp = 700
	s.proficiency_bonus = 2
	s.max_hp = 52
	s.hit_dice = "8d8+16"
	s.armor_class = 14
	s.speed_ft = 20
	s.fly = true
	s.sight_ft = 60
	s.save_proficiencies = PackedStringArray(["WIS"])
	var bite := _attack("Bite", AttackData.Kind.MELEE, AttackData.Ability.DEX, "2d6", "piercing")
	bite.to_hit_override = 4
	var ray := _ranged(_attack("Gaze Ray", AttackData.Kind.RANGED, AttackData.Ability.DEX, "2d8+2", "necrotic"), 60, 0)
	ray.to_hit_override = 5
	s.attacks = [ray, bite]
	return s
