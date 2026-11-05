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
const SPELL_DIR := "res://data/spells/"

## Saved spells/abilities by id (stats reference these files).
var sp := {}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HERO_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MONSTER_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SPELL_DIR))
	_build_spells()
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
	s.save_proficiencies = _s(saves)
	s.speed_ft = 30


# --- heroes (level 5; HP = max die + average per level + CON) ----------------------------------

func _fighter() -> CreatureStats:
	var s := _stats("fighter", "Fighter", [16, 12, 14, 10, 12, 8])
	_hero(s, "fighter", 44, "5d10", 18, ["STR", "CON"])      # chain mail + shield
	s.extra_attacks = 1                                       # Extra Attack (level 5)
	s.powers = [sp.second_wind, sp.shove]
	s.skill_proficiencies = _s(["athletics", "perception"])
	s.attacks = [
		_attack("Longsword", AttackData.Kind.MELEE, AttackData.Ability.STR, "1d8", "slashing"),
		_ranged(_attack("Handaxe", AttackData.Kind.RANGED, AttackData.Ability.STR, "1d6", "slashing"), 20, 60),
	]
	return s


func _rogue() -> CreatureStats:
	var s := _stats("rogue", "Rogue", [8, 18, 12, 12, 12, 10])
	_hero(s, "rogue", 33, "5d8", 15, ["DEX", "INT"])          # leather armour
	s.powers = [sp.sneak_attack, sp.hide]
	s.skill_proficiencies = _s(["acrobatics", "athletics"])
	s.skill_expertise = _s(["stealth", "perception"])
	s.attacks = [
		_attack("Shortsword", AttackData.Kind.MELEE, AttackData.Ability.FINESSE, "1d6", "piercing"),
		_ranged(_attack("Shortbow", AttackData.Kind.RANGED, AttackData.Ability.DEX, "1d6", "piercing"), 80, 320),
	]
	return s


func _cleric() -> CreatureStats:
	var s := _stats("cleric", "Cleric", [14, 10, 14, 10, 18, 12])
	_hero(s, "cleric", 38, "5d8", 18, ["WIS", "CHA"])         # chain mail + shield (Life domain)
	s.spell_ability = "WIS"
	s.spell_slots = _i([4, 3, 2])
	s.powers = [sp.sacred_flame, sp.cure_wounds, sp.bless]
	s.skill_proficiencies = _s(["insight", "medicine"])
	s.attacks = [
		_attack("Mace", AttackData.Kind.MELEE, AttackData.Ability.STR, "1d6", "bludgeoning"),
	]
	return s


func _wizard() -> CreatureStats:
	var s := _stats("wizard", "Mage", [8, 14, 12, 18, 12, 10])
	_hero(s, "wizard", 27, "5d6", 12, ["INT", "WIS"])
	s.spell_ability = "INT"
	s.spell_slots = _i([4, 3, 2])
	s.powers = [sp.fire_bolt, sp.magic_missile, sp.shield, sp.fireball]
	s.skill_proficiencies = _s(["arcana", "investigation"])
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
	s.attacks = [bite]
	s.powers = [sp.spider_web]
	s.skill_overrides = {"stealth": 7, "perception": 0}
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
	s.save_proficiencies = _s(["WIS"])
	var bite := _attack("Bite", AttackData.Kind.MELEE, AttackData.Ability.DEX, "2d6", "piercing")
	bite.to_hit_override = 4
	var ray := _ranged(_attack("Gaze Ray", AttackData.Kind.RANGED, AttackData.Ability.DEX, "2d8+2", "necrotic"), 60, 0)
	ray.to_hit_override = 5
	s.attacks = [ray, bite]
	s.powers = [sp.fear_ray]
	s.skill_overrides = {"perception": 4}
	return s


# --- spells & abilities (SRD 5.1; Fireball's area simplified to 3x3) -------------------------------

func _spell(id: String, name: String, kind: SpellData.Kind, level: int, cast: SpellData.CastTime,
		target: SpellData.Target, range_ft: int, resolve: SpellData.Resolve, desc: String) -> SpellData:
	var s := SpellData.new()
	s.id = id
	s.display_name = name
	s.resource_name = name
	s.kind = kind
	s.level = level
	s.cast_time = cast
	s.target = target
	s.range_ft = range_ft
	s.resolve = resolve
	s.description = desc
	return s


func _build_spells() -> void:
	var S := SpellData.Kind.SPELL
	var A := SpellData.Kind.ABILITY
	var T := SpellData.Target
	var R := SpellData.Resolve
	var C := SpellData.CastTime

	var fb := _spell("fire_bolt", "Fire Bolt", S, 0, C.ACTION, T.ENEMY, 120, R.ATTACK,
			"Hurl a mote of fire. Ranged spell attack, 1d10 fire (2d10 at 5th level).")
	fb.damage = "1d10"
	fb.damage_type = "fire"
	fb.cantrip_dice = _i([1, 2, 3, 4])
	fb.sfx = "cast_whoosh"
	fb.vfx = "fire_bolt"

	var mm := _spell("magic_missile", "Magic Missile", S, 1, C.ACTION, T.ENEMY, 120, R.AUTO,
			"Three glowing darts that never miss, 1d4+1 force each. Split them between targets. +1 dart per slot above 1st.")
	mm.damage = "1d4+1"
	mm.damage_type = "force"
	mm.darts = 3
	mm.upcast_darts = 1
	mm.max_targets = 3
	mm.sfx = "cast_whoosh"
	mm.vfx = "magic_missile"

	var sh := _spell("shield", "Shield", S, 1, C.REACTION, T.SELF, 0, R.AUTO,
			"Reaction when hit by an attack: +5 AC until the start of your next turn, including against the triggering attack.")
	sh.condition = "shielded"
	sh.condition_rounds = 1
	sh.needs_los = false
	sh.sfx = "charge"
	sh.vfx = "shield"

	var fi := _spell("fireball", "Fireball", S, 3, C.ACTION, T.AREA, 150, R.SAVE,
			"A burst of flame on a 3x3 area: 8d6 fire, DEX save for half. +1d6 per slot above 3rd.")
	fi.area_size = 3
	fi.save_ability = "DEX"
	fi.half_on_save = true
	fi.damage = "8d6"
	fi.damage_type = "fire"
	fi.upcast_dice = "1d6"
	fi.sfx = "explosion"
	fi.vfx = "fireball"
	fi.big_moment = true

	var sf := _spell("sacred_flame", "Sacred Flame", S, 0, C.ACTION, T.ENEMY, 60, R.SAVE,
			"Radiant flame descends on a creature: DEX save or 1d8 radiant (2d8 at 5th level). Ignores cover.")
	sf.save_ability = "DEX"
	sf.damage = "1d8"
	sf.damage_type = "radiant"
	sf.cantrip_dice = _i([1, 2, 3, 4])
	sf.sfx = "cast_whoosh"
	sf.vfx = "sacred_flame"

	var cw := _spell("cure_wounds", "Cure Wounds", S, 1, C.ACTION, T.ALLY, 5, R.HEAL,
			"Touch: heal 1d8 + your spellcasting modifier. Brings a dying ally back. +1d8 per slot above 1st.")
	cw.heal = "1d8"
	cw.add_ability_mod = true
	cw.upcast_dice = "1d8"
	cw.needs_los = false
	cw.sfx = ""
	cw.vfx = "heal"

	var bl := _spell("bless", "Bless", S, 1, C.ACTION, T.ALLY, 30, R.AUTO,
			"Up to three allies add 1d4 to attack rolls and saving throws. Concentration, up to 1 minute. +1 target per slot above 1st.")
	bl.max_targets = 3
	bl.upcast_targets = 1
	bl.condition = "blessed"
	bl.condition_rounds = 10
	bl.concentration = true
	bl.sfx = "turn_chime"
	bl.vfx = "bless"

	var sw := _spell("second_wind", "Second Wind", A, 0, C.BONUS, T.SELF, 0, R.HEAL,
			"Bonus action: regain 1d10 + fighter level HP. Once per short rest.")
	sw.heal = "1d10"
	sw.add_level = true
	sw.uses = 1
	sw.recharge = SpellData.Recharge.SHORT_REST
	sw.needs_los = false
	sw.sfx = "charge"
	sw.vfx = "heal"

	var sv := _spell("shove", "Shove", A, 0, C.ATTACK, T.ENEMY, 5, R.CONTEST,
			"Instead of one attack: Athletics vs the target's Athletics or Acrobatics. Win: knock it prone (or push it 5 ft).")
	sv.contest_skill = "athletics"
	sv.resist_skills = _s(["athletics", "acrobatics"])
	sv.condition = "prone"
	sv.condition_rounds = -1
	sv.sfx = "hit_blunt"

	var hd := _spell("hide", "Hide", A, 0, C.BONUS, T.SELF, 0, R.CONTEST,
			"Cunning Action (bonus action): Stealth vs the enemies' passive Perception. Success: your next attack has advantage.")
	hd.contest_skill = "stealth"
	hd.condition = "hidden"
	hd.condition_rounds = -1
	hd.needs_los = false
	hd.sfx = "miss_swish"

	var sa := _spell("sneak_attack", "Sneak Attack", A, 0, C.FREE, T.ENEMY, 0, R.AUTO,
			"Once per turn: +3d6 damage with a finesse or ranged weapon attack that has advantage, or when an ally is next to the target.")
	sa.damage = "3d6"

	var wb := _spell("spider_web", "Web", SpellData.Kind.MONSTER, 0, C.ACTION, T.ENEMY, 30, R.ATTACK,
			"Recharge 5-6. Ranged attack +5, 30/60 ft: the target is restrained (escape: DC 12 Strength check).")
	wb.attack_bonus_override = 5
	wb.dc_override = 12
	wb.condition = "restrained"
	wb.condition_rounds = -1
	wb.recharge = SpellData.Recharge.DICE
	wb.sfx = "spider_hiss"
	wb.vfx = "web"

	# Our own Eye Tyrant power (not from the SRD).
	var fr := _spell("fear_ray", "Fear Ray", SpellData.Kind.MONSTER, 0, C.ACTION, T.ENEMY, 60, R.SAVE,
			"Recharge 5-6. A pale ray from the central eye: WIS save DC 13 or frightened until the end of its next turn (disadvantage on attacks).")
	fr.save_ability = "WIS"
	fr.dc_override = 13
	fr.condition = "frightened"
	fr.condition_rounds = 2
	fr.recharge = SpellData.Recharge.DICE
	fr.sfx = "ray_zap"
	fr.vfx = "fear_ray"

	for s: SpellData in [fb, mm, sh, fi, sf, cw, bl, sw, sv, hd, sa, wb, fr]:
		var path := SPELL_DIR + s.id + ".tres"
		var err := ResourceSaver.save(s, path, ResourceSaver.FLAG_CHANGE_PATH)
		print("wrote ", path, " err=", err)
		sp[s.id] = load(path)


## Typed arrays for the data files. (Not PackedStringArray/PackedInt32Array: the editor once
## re-saved these files and silently dropped every packed-array export.)
static func _s(a: Array) -> Array[String]:
	var o: Array[String] = []
	o.assign(a)
	return o


static func _i(a: Array) -> Array[int]:
	var o: Array[int] = []
	o.assign(a)
	return o
