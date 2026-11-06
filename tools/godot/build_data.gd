extends SceneTree
## Writes the stat blocks: data/heroes/*.tres (the party at level 1; Progression grows them to
## levels 2-5), data/monsters/*.tres and data/spells/*.tres.
## Run: Godot_console --headless --path . -s res://tools/godot/build_data.gd
## Overwrites the files. Once they have been hand-tuned in the editor, don't re-run this (or add
## a merge), like the other build_* tools.
##
## Rules content: 5e SRD 5.1 (CC-BY-4.0, see CREDITS.md). The Eye Tyrant is our own original
## monster, written in the same format.

const HERO_DIR := "res://data/heroes/"
const MONSTER_DIR := "res://data/monsters/"
const SPELL_DIR := "res://data/spells/"

const MELEE := AttackData.Kind.MELEE
const RANGED := AttackData.Kind.RANGED

## Saved spells/abilities by id (stats reference these files).
var sp := {}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HERO_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MONSTER_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SPELL_DIR))
	_build_spells()
	for s in [_fighter(), _rogue(), _cleric(), _wizard()]:
		_save(s, HERO_DIR)
	for s in [_giant_spider(), _eye_tyrant(), _skeleton(), _giant_rat(), _wolf(), _goblin(),
			_goblin_boss(), _bandit(), _zombie(), _ghoul(), _ghast(), _hobgoblin(), _bugbear(),
			_ogre(), _wight(), _mummy(), _specter(), _wraith()]:
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


## A monster attack straight from the stat block: "+4 to hit, 1d6+2 slashing".
func _matk(name: String, to_hit: int, damage: String, damage_type: String, range_ft := 0, long_ft := 0) -> AttackData:
	var a := _attack(name, RANGED if range_ft > 0 else MELEE, AttackData.Ability.DEX, damage, damage_type)
	a.to_hit_override = to_hit
	if range_ft > 0:
		_ranged(a, range_ft, long_ft)
		if damage_type == "piercing":
			a.sfx = "bow_shot"
	return a


## Common monster fields: type, CR, XP, AC, HP (+ hit dice), speed, sight.
func _monster(s: CreatureStats, type: String, cr: float, xp: int, ac: int, hp: int, hd: String,
		speed := 30, sight := 40) -> void:
	s.creature_type = type
	s.challenge = cr
	s.xp = xp
	s.proficiency_bonus = 2 if cr < 5 else 3
	s.armor_class = ac
	s.max_hp = hp
	s.hit_dice = hd
	s.speed_ft = speed
	s.sight_ft = sight


func _hero(s: CreatureStats, class_id: String, die: String, saves: Array) -> void:
	s.class_id = class_id
	s.level = 1
	s.proficiency_bonus = 2
	s.hit_dice = "1" + die
	s.max_hp = Progression.hit_points(class_id, s.mod("CON"), 1)
	s.armor_class = 10              # unarmoured; the real AC comes from the equipment
	s.save_proficiencies = _s(saves)
	s.speed_ft = 30


# --- heroes (written at level 1; Progression.apply grows them: HP, slots, powers, ASI...) ----------
# `powers` lists everything the class will learn up to level 5; Progression.CLASSES says when.

func _fighter() -> CreatureStats:
	var s := _stats("fighter", "Fighter", [16, 12, 14, 10, 12, 8])
	_hero(s, "fighter", "d10", ["STR", "CON"])                # chain mail + shield
	s.powers = [sp.second_wind, sp.shove, sp.action_surge]
	s.skill_proficiencies = _s(["athletics", "perception"])
	s.armor_training = _s(["light", "medium", "heavy", "shield"])
	s.weapon_training = _s(["simple", "martial"])
	s.starting_equipment = _s(["longsword", "shield", "handaxe", "chain_mail"])
	return s


func _rogue() -> CreatureStats:
	var s := _stats("rogue", "Rogue", [8, 16, 12, 12, 12, 10])
	_hero(s, "rogue", "d8", ["DEX", "INT"])                   # leather armour
	s.powers = [sp.sneak_attack, sp.hide, sp.uncanny_dodge]
	s.skill_proficiencies = _s(["acrobatics", "athletics", "thieves_tools"])
	s.skill_expertise = _s(["stealth", "perception"])
	s.armor_training = _s(["light"])
	s.weapon_training = _s(["simple", "hand_crossbow", "longsword", "rapier", "shortsword"])
	s.starting_equipment = _s(["shortsword", "shortbow", "leather_armor"])
	return s


func _cleric() -> CreatureStats:
	var s := _stats("cleric", "Cleric", [14, 10, 14, 10, 16, 12])
	_hero(s, "cleric", "d8", ["WIS", "CHA"])                  # chain mail + shield (Life domain)
	s.spell_ability = "WIS"
	s.powers = [sp.sacred_flame, sp.cure_wounds, sp.healing_word, sp.bless, sp.turn_undead,
			sp.hold_person, sp.mass_healing_word]
	s.skill_proficiencies = _s(["insight", "medicine"])
	s.armor_training = _s(["light", "medium", "heavy", "shield"])
	s.weapon_training = _s(["simple"])
	s.starting_equipment = _s(["mace", "shield", "chain_mail"])
	return s


func _wizard() -> CreatureStats:
	var s := _stats("wizard", "Mage", [8, 14, 12, 16, 12, 10])
	_hero(s, "wizard", "d6", ["INT", "WIS"])
	s.spell_ability = "INT"
	s.powers = [sp.fire_bolt, sp.magic_missile, sp.burning_hands, sp.shield, sp.scorching_ray, sp.fireball]
	s.skill_proficiencies = _s(["arcana", "investigation"])
	s.armor_training = _s([])
	s.weapon_training = _s(["dagger", "dart", "sling", "quarterstaff", "light_crossbow"])
	s.starting_equipment = _s(["quarterstaff", "light_crossbow"])
	return s


# --- monsters (SRD 5.1 unless noted; Large creatures take one cell for now) ---------------------

func _giant_spider() -> CreatureStats:
	var s := _stats("giant_spider", "Giant Spider", [14, 16, 12, 2, 11, 4])
	_monster(s, "beast", 1, 200, 14, 26, "4d10+4")
	s.size = CreatureStats.Size.LARGE
	var bite := _matk("Bite", 5, "1d8+3", "piercing")
	bite.rider_damage = "2d8"
	bite.rider_damage_type = "poison"
	bite.rider_save = "CON"
	bite.rider_dc = 11
	s.attacks = [bite]
	s.powers = [sp.spider_web]
	s.skill_overrides = {"stealth": 7, "perception": 0}
	return s


func _skeleton() -> CreatureStats:
	# CR 1/4. Vulnerable to bludgeoning, immune to poison.
	var s := _stats("skeleton", "Skeleton", [10, 14, 15, 6, 8, 5])
	_monster(s, "undead", 0.25, 50, 13, 13, "2d8+4")
	s.vulnerabilities = _s(["bludgeoning"])
	s.immunities = _s(["poison"])
	s.attacks = [_matk("Shortsword", 4, "1d6+2", "piercing"), _matk("Shortbow", 4, "1d6+2", "piercing", 80, 320)]
	s.skill_overrides = {"perception": -1}
	return s


func _eye_tyrant() -> CreatureStats:
	# Our own monster (not from the SRD): a floating eye that shoots gaze rays.
	var s := _stats("eye_tyrant", "Eye Tyrant", [8, 14, 14, 14, 14, 10])
	_monster(s, "aberration", 3, 700, 14, 52, "8d8+16", 20, 60)
	s.fly = true
	s.save_proficiencies = _s(["WIS"])
	s.attacks = [_matk("Gaze Ray", 5, "2d8+2", "necrotic", 60), _matk("Bite", 4, "2d6", "piercing")]
	s.powers = [sp.fear_ray]
	s.skill_overrides = {"perception": 4}
	return s


func _giant_rat() -> CreatureStats:
	# CR 1/8. Pack Tactics.
	var s := _stats("giant_rat", "Giant Rat", [7, 15, 11, 2, 10, 4])
	_monster(s, "beast", 0.125, 25, 12, 7, "2d6", 30, 30)
	s.size = CreatureStats.Size.SMALL
	s.traits = _s(["pack_tactics"])
	s.attacks = [_matk("Bite", 4, "1d4+2", "piercing")]
	return s


func _wolf() -> CreatureStats:
	# CR 1/4. Pack Tactics; a bite knocks the target prone (STR save DC 11).
	var s := _stats("wolf", "Wolf", [12, 15, 12, 3, 12, 6])
	_monster(s, "beast", 0.25, 50, 13, 11, "2d8+2", 40, 50)
	s.traits = _s(["pack_tactics"])
	var bite := _matk("Bite", 4, "2d4+2", "piercing")
	bite.rider_condition = "prone"
	bite.rider_save = "STR"
	bite.rider_dc = 11
	s.attacks = [bite]
	s.skill_overrides = {"perception": 3, "stealth": 4}
	return s


func _goblin() -> CreatureStats:
	# CR 1/4.
	var s := _stats("goblin", "Goblin", [8, 14, 10, 10, 8, 8])
	_monster(s, "humanoid", 0.25, 50, 15, 7, "2d6")
	s.size = CreatureStats.Size.SMALL
	s.attacks = [_matk("Scimitar", 4, "1d6+2", "slashing"), _matk("Shortbow", 4, "1d6+2", "piercing", 80, 320)]
	s.skill_overrides = {"stealth": 6, "perception": -1}
	return s


func _goblin_boss() -> CreatureStats:
	# CR 1. Multiattack: two scimitar attacks. (Redirect Attack not used.)
	var s := _stats("goblin_boss", "Goblin Boss", [10, 14, 10, 10, 8, 10])
	_monster(s, "humanoid", 1, 200, 17, 21, "6d6")
	s.size = CreatureStats.Size.SMALL
	s.extra_attacks = 1
	s.attacks = [_matk("Scimitar", 4, "1d6+2", "slashing"), _matk("Javelin", 2, "1d6", "piercing", 30, 120)]
	s.skill_overrides = {"stealth": 6, "perception": -1}
	return s


func _bandit() -> CreatureStats:
	# CR 1/8.
	var s := _stats("bandit", "Bandit", [11, 12, 12, 10, 10, 10])
	_monster(s, "humanoid", 0.125, 25, 12, 11, "2d8+2")
	s.attacks = [_matk("Scimitar", 3, "1d6+1", "slashing"), _matk("Light Crossbow", 3, "1d8+1", "piercing", 80, 320)]
	return s


func _zombie() -> CreatureStats:
	# CR 1/4. Undead Fortitude. Slow.
	var s := _stats("zombie", "Zombie", [13, 6, 16, 3, 6, 5])
	_monster(s, "undead", 0.25, 50, 8, 22, "3d8+9", 20, 40)
	s.save_proficiencies = _s(["WIS"])
	s.immunities = _s(["poison"])
	s.traits = _s(["undead_fortitude"])
	s.attacks = [_matk("Slam", 3, "1d6+1", "bludgeoning")]
	s.skill_overrides = {"perception": -2}
	return s


func _ghoul() -> CreatureStats:
	# CR 1. Claws paralyze (CON save DC 10, repeats at the end of each turn).
	var s := _stats("ghoul", "Ghoul", [13, 15, 10, 7, 10, 6])
	_monster(s, "undead", 1, 200, 12, 22, "5d8")
	s.immunities = _s(["poison"])
	var claws := _matk("Claws", 4, "2d4+2", "slashing")
	claws.rider_condition = "paralyzed"
	claws.rider_condition_rounds = 10
	claws.rider_save = "CON"
	claws.rider_dc = 10
	s.attacks = [claws, _matk("Bite", 2, "2d6+2", "piercing")]
	return s


func _ghast() -> CreatureStats:
	# CR 2. A ghoul's elder: tougher claws, resists necrotic, stands up to turning.
	var s := _stats("ghast", "Ghast", [16, 17, 10, 11, 10, 8])
	_monster(s, "undead", 2, 450, 13, 36, "8d8")
	s.immunities = _s(["poison"])
	s.resistances = _s(["necrotic"])
	s.traits = _s(["turn_resistance"])
	var claws := _matk("Claws", 5, "2d6+3", "slashing")
	claws.rider_condition = "paralyzed"
	claws.rider_condition_rounds = 10
	claws.rider_save = "CON"
	claws.rider_dc = 10
	s.attacks = [claws, _matk("Bite", 3, "2d8+3", "piercing")]
	return s


func _hobgoblin() -> CreatureStats:
	# CR 1/2. Martial Advantage (+2d6 once a turn next to an ally).
	var s := _stats("hobgoblin", "Hobgoblin", [13, 12, 12, 10, 10, 9])
	_monster(s, "humanoid", 0.5, 100, 18, 11, "2d8+2")
	s.traits = _s(["martial_advantage"])
	s.attacks = [_matk("Longsword", 3, "1d8+1", "slashing"), _matk("Longbow", 3, "1d8+1", "piercing", 150, 600)]
	return s


func _bugbear() -> CreatureStats:
	# CR 1. Brute: the extra die is in the damage.
	var s := _stats("bugbear", "Bugbear", [15, 14, 13, 8, 11, 9])
	_monster(s, "humanoid", 1, 200, 16, 27, "5d8+5")
	s.attacks = [_matk("Morningstar", 4, "2d8+2", "piercing"), _matk("Javelin", 4, "1d6+2", "piercing", 30, 120)]
	s.skill_overrides = {"stealth": 6, "perception": 0}
	return s


func _ogre() -> CreatureStats:
	# CR 2. Large giant.
	var s := _stats("ogre", "Ogre", [19, 8, 16, 5, 7, 7])
	_monster(s, "giant", 2, 450, 11, 59, "7d10+21", 40)
	s.size = CreatureStats.Size.LARGE
	s.attacks = [_matk("Greatclub", 6, "2d8+4", "bludgeoning"), _matk("Javelin", 6, "2d6+4", "piercing", 30, 120)]
	s.skill_overrides = {"perception": -2}
	return s


func _wight() -> CreatureStats:
	# CR 3. Multiattack (two longsword or two longbow attacks). Needs magic weapons.
	var s := _stats("wight", "Wight", [15, 14, 16, 10, 13, 15])
	_monster(s, "undead", 3, 700, 14, 45, "6d8+18", 30, 60)
	s.extra_attacks = 1
	s.resistances = _s(["necrotic"])
	s.immunities = _s(["poison"])
	s.traits = _s(["resist_nonmagical"])
	s.attacks = [_matk("Longsword", 4, "1d8+2", "slashing"), _matk("Longbow", 4, "1d8+2", "piercing", 150, 600)]
	s.skill_overrides = {"perception": 3, "stealth": 4}
	return s


func _mummy() -> CreatureStats:
	# CR 3. Rotting Fist + necrotic; Dreadful Glare (as a recharge power here). Burns well.
	var s := _stats("mummy", "Mummy", [16, 8, 15, 6, 10, 12])
	_monster(s, "undead", 3, 700, 11, 58, "9d8+18", 20)
	s.save_proficiencies = _s(["WIS"])
	s.vulnerabilities = _s(["fire"])
	s.immunities = _s(["necrotic", "poison"])
	s.traits = _s(["resist_nonmagical"])
	var fist := _matk("Rotting Fist", 5, "2d6+3", "bludgeoning")
	fist.rider_damage = "3d6"
	fist.rider_damage_type = "necrotic"
	s.attacks = [fist]
	s.powers = [sp.dreadful_glare]
	return s


func _specter() -> CreatureStats:
	# CR 1. Floats; Life Drain. Resists almost everything that isn't magic.
	var s := _stats("specter", "Specter", [1, 14, 11, 10, 10, 11])
	_monster(s, "undead", 1, 200, 12, 22, "5d8", 50, 60)
	s.fly = true
	s.resistances = _s(["acid", "cold", "fire", "lightning", "thunder"])
	s.immunities = _s(["necrotic", "poison"])
	s.traits = _s(["resist_nonmagical"])
	s.attacks = [_matk("Life Drain", 4, "3d6", "necrotic")]
	return s


func _wraith() -> CreatureStats:
	# CR 5: the dungeon's master. Floats; Life Drain.
	var s := _stats("wraith", "Wraith", [6, 16, 16, 12, 14, 15])
	_monster(s, "undead", 5, 1800, 13, 67, "9d8+27", 60, 60)
	s.fly = true
	s.resistances = _s(["acid", "cold", "fire", "lightning", "thunder"])
	s.immunities = _s(["necrotic", "poison"])
	s.traits = _s(["resist_nonmagical", "turn_resistance"])
	s.attacks = [_matk("Life Drain", 6, "4d8+3", "necrotic")]
	s.powers = [sp.dreadful_glare]
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
	var M := SpellData.Kind.MONSTER
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

	var bh := _spell("burning_hands", "Burning Hands", S, 1, C.ACTION, T.CONE, 15, R.SAVE,
			"A fan of flame from your fingertips: a 15-ft cone, 3d6 fire, DEX save for half. +1d6 per slot above 1st.")
	bh.save_ability = "DEX"
	bh.half_on_save = true
	bh.damage = "3d6"
	bh.damage_type = "fire"
	bh.upcast_dice = "1d6"
	bh.sfx = "cast_whoosh"
	bh.vfx = "burning_hands"

	var sh := _spell("shield", "Shield", S, 1, C.REACTION, T.SELF, 0, R.AUTO,
			"Reaction when hit by an attack: +5 AC until the start of your next turn, including against the triggering attack.")
	sh.condition = "shielded"
	sh.condition_rounds = 1
	sh.needs_los = false
	sh.sfx = "charge"
	sh.vfx = "shield"

	var sr := _spell("scorching_ray", "Scorching Ray", S, 2, C.ACTION, T.ENEMY, 120, R.ATTACK,
			"Three rays of fire, each a ranged spell attack for 2d6 fire. Split them between targets. +1 ray per slot above 2nd.")
	sr.damage = "2d6"
	sr.damage_type = "fire"
	sr.darts = 3
	sr.upcast_darts = 1
	sr.max_targets = 3
	sr.sfx = "cast_whoosh"
	sr.vfx = "scorching_ray"

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

	var hw := _spell("healing_word", "Healing Word", S, 1, C.BONUS, T.ALLY, 60, R.HEAL,
			"Bonus action, 60 ft: heal 1d4 + your spellcasting modifier. Brings a dying ally back. +1d4 per slot above 1st.")
	hw.heal = "1d4"
	hw.add_ability_mod = true
	hw.upcast_dice = "1d4"
	hw.sfx = ""
	hw.vfx = "heal"

	var bl := _spell("bless", "Bless", S, 1, C.ACTION, T.ALLY, 30, R.AUTO,
			"Up to three allies add 1d4 to attack rolls and saving throws. Concentration, up to 1 minute. +1 target per slot above 1st.")
	bl.max_targets = 3
	bl.upcast_targets = 1
	bl.condition = "blessed"
	bl.condition_rounds = 10
	bl.concentration = true
	bl.sfx = "turn_chime"
	bl.vfx = "bless"

	var hp := _spell("hold_person", "Hold Person", S, 2, C.ACTION, T.ENEMY, 60, R.SAVE,
			"A humanoid must make a WIS save or be paralyzed (it saves again at the end of each of its turns). Hits from within 5 ft crit. Concentration, up to 1 minute. +1 target per slot above 2nd.")
	hp.save_ability = "WIS"
	hp.condition = "paralyzed"
	hp.condition_rounds = 10
	hp.concentration = true
	hp.save_each_turn = true
	hp.creature_types = _s(["humanoid"])
	hp.upcast_targets = 1
	hp.sfx = "charge"
	hp.vfx = "hold"

	var mh := _spell("mass_healing_word", "Mass Healing Word", S, 3, C.BONUS, T.ALLY, 60, R.HEAL,
			"Bonus action: up to six allies within 60 ft each heal 1d4 + your spellcasting modifier. +1d4 per slot above 3rd.")
	mh.heal = "1d4"
	mh.add_ability_mod = true
	mh.upcast_dice = "1d4"
	mh.max_targets = 6
	mh.sfx = ""
	mh.vfx = "heal"

	var tu := _spell("turn_undead", "Turn Undead", A, 0, C.ACTION, T.SELF, 30, R.SAVE,
			"Channel Divinity (once per short rest): every undead within 30 ft that can see you makes a WIS save or is turned for a minute - it flees and can't attack until it takes damage. From 5th level, weak undead (CR 1/2 or less) are destroyed.")
	tu.save_ability = "WIS"
	tu.uses = 1
	tu.recharge = SpellData.Recharge.SHORT_REST
	tu.needs_los = false
	tu.sfx = "radiant"

	var sw := _spell("second_wind", "Second Wind", A, 0, C.BONUS, T.SELF, 0, R.HEAL,
			"Bonus action: regain 1d10 + fighter level HP. Once per short rest.")
	sw.heal = "1d10"
	sw.add_level = true
	sw.uses = 1
	sw.recharge = SpellData.Recharge.SHORT_REST
	sw.needs_los = false
	sw.sfx = "charge"
	sw.vfx = "heal"

	var su := _spell("action_surge", "Action Surge", A, 0, C.FREE, T.SELF, 0, R.AUTO,
			"Once per short rest, after using your action: take one more action this turn (attack again, or drink a potion...).")
	su.uses = 1
	su.recharge = SpellData.Recharge.SHORT_REST
	su.needs_los = false

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
			"Once per turn: extra damage (1d6, +1d6 at 3rd and 5th level) with a finesse or ranged weapon attack that has advantage, or when an ally is next to the target.")
	sa.damage = "1d6"

	var ud := _spell("uncanny_dodge", "Uncanny Dodge", A, 0, C.REACTION, T.SELF, 0, R.AUTO,
			"Reaction when an attacker you can see hits you: halve the attack's damage.")
	ud.needs_los = false

	var wb := _spell("spider_web", "Web", M, 0, C.ACTION, T.ENEMY, 30, R.ATTACK,
			"Recharge 5-6. Ranged attack +5, 30/60 ft: the target is restrained (escape: DC 12 Strength check).")
	wb.attack_bonus_override = 5
	wb.dc_override = 12
	wb.condition = "restrained"
	wb.condition_rounds = -1
	wb.recharge = SpellData.Recharge.DICE
	wb.sfx = "spider_hiss"
	wb.vfx = "web"

	# Our own Eye Tyrant power (not from the SRD).
	var fr := _spell("fear_ray", "Fear Ray", M, 0, C.ACTION, T.ENEMY, 60, R.SAVE,
			"Recharge 5-6. A pale ray from the central eye: WIS save DC 13 or frightened until the end of its next turn (disadvantage on attacks).")
	fr.save_ability = "WIS"
	fr.dc_override = 13
	fr.condition = "frightened"
	fr.condition_rounds = 2
	fr.recharge = SpellData.Recharge.DICE
	fr.sfx = "ray_zap"
	fr.vfx = "fear_ray"

	# Mummy / Wraith (SRD Dreadful Glare, simplified to a recharge power).
	var dg := _spell("dreadful_glare", "Dreadful Glare", M, 0, C.ACTION, T.ENEMY, 60, R.SAVE,
			"Recharge 5-6. A creature that meets its gaze makes a WIS save (DC 11) or is frightened until the end of its next turn.")
	dg.save_ability = "WIS"
	dg.dc_override = 11
	dg.condition = "frightened"
	dg.condition_rounds = 2
	dg.recharge = SpellData.Recharge.DICE
	dg.sfx = "ray_zap"
	dg.vfx = "fear_ray"

	# Lightning Bolt: nobody knows it yet; it comes on scrolls (a wizard can read them).
	var lb := _spell("lightning_bolt", "Lightning Bolt", S, 3, C.ACTION, T.LINE, 100, R.SAVE,
			"A 100-ft line of lightning: 8d6 lightning, DEX save for half. Stops at walls. +1d6 per slot above 3rd.")
	lb.save_ability = "DEX"
	lb.half_on_save = true
	lb.damage = "8d6"
	lb.damage_type = "lightning"
	lb.upcast_dice = "1d6"
	lb.sfx = "lightning_crack"
	lb.vfx = "lightning"
	lb.big_moment = true

	# Spell lists (SRD): who can read each spell from a scroll.
	for s: SpellData in [fb, mm, bh, sh, sr, fi, lb]:
		s.classes = _s(["wizard"])
	for s: SpellData in [sf, cw, hw, bl, mh]:
		s.classes = _s(["cleric"])
	hp.classes = _s(["cleric", "wizard"])

	for s: SpellData in [fb, mm, bh, sh, sr, fi, sf, cw, hw, bl, hp, mh, tu, sw, su, sv, hd, sa, ud, wb, fr, dg, lb]:
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
