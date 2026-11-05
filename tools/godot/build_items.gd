extends SceneTree
## Writes the item definitions: data/items/<id>.tres (ItemData).
## Run: Godot_console --headless --path . -s res://tools/godot/build_items.gd
## Overwrites the files (like the other build_* tools). Hero starting kits and class training
## refer to these ids (tools/godot/build_data.gd).
##
## Rules content: 5e SRD 5.1 (CC-BY-4.0, see CREDITS.md): weapon and armour tables, Potion of
## Healing, Ring of Protection. Simplifications: thrown/versatile properties are not used yet
## (the handaxe sits in the ranged slot and is always thrown), no ammunition.

const DIR := "res://data/items/"

const MELEE := AttackData.Kind.MELEE
const RANGED := AttackData.Kind.RANGED
const STR := AttackData.Ability.STR
const DEX := AttackData.Ability.DEX
const FIN := AttackData.Ability.FINESSE

var _written := {}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	# --- weapons: id, name, category, damage, type, ability, value gp ---
	_weapon("dagger", "Dagger", "simple", "1d4", "piercing", FIN, 2, "A light blade. Finesse.")
	_weapon("mace", "Mace", "simple", "1d6", "bludgeoning", STR, 5, "A flanged iron head on a haft. Good against skeletons.")
	_weapon("quarterstaff", "Quarterstaff", "simple", "1d6", "bludgeoning", STR, 0, "A stout wooden staff.")
	_weapon("shortsword", "Shortsword", "martial", "1d6", "piercing", FIN, 10, "A short stabbing blade. Finesse.")
	_weapon("longsword", "Longsword", "martial", "1d8", "slashing", STR, 15, "A knight's straight blade.")
	_weapon("rapier", "Rapier", "martial", "1d8", "piercing", FIN, 25, "A slender duelling blade. Finesse.")
	_weapon("warhammer", "Warhammer", "martial", "1d8", "bludgeoning", STR, 15, "A heavy hammer. Shatters bone.")
	var gs := _weapon("greatsword", "Greatsword", "martial", "2d6", "slashing", STR, 50, "A huge two-handed blade.")
	gs.two_handed = true
	_save(gs)
	_ranged("handaxe", "Handaxe", "simple", "1d6", "slashing", STR, 20, 60, 5, false, "A small axe made for throwing.")
	_ranged("light_crossbow", "Light Crossbow", "simple", "1d8", "piercing", DEX, 80, 320, 25, true, "A light crossbow.")
	_ranged("shortbow", "Shortbow", "simple", "1d6", "piercing", DEX, 80, 320, 25, true, "A short hunting bow.")
	_ranged("longbow", "Longbow", "martial", "1d8", "piercing", DEX, 150, 600, 50, true, "A tall war bow.")

	# --- armour: id, name, type, AC, DEX cap, STR, stealth disadvantage, value ---
	_armor("leather_armor", "Leather Armour", "light", 11, -1, 0, false, 10, "Boiled leather. AC 11 + DEX.")
	_armor("studded_leather", "Studded Leather", "light", 12, -1, 0, false, 45, "Leather set with rivets. AC 12 + DEX.")
	_armor("chain_shirt", "Chain Shirt", "medium", 13, 2, 0, false, 50, "A shirt of mail. AC 13 + DEX (max 2).")
	_armor("scale_mail", "Scale Mail", "medium", 14, 2, 0, true, 50, "Overlapping metal scales. AC 14 + DEX (max 2). Noisy.")
	_armor("chain_mail", "Chain Mail", "heavy", 16, 0, 13, true, 75, "Full mail with padding. AC 16. Needs STR 13.")
	_armor("plate_armor", "Plate Armour", "heavy", 18, 0, 15, true, 1500, "Shaped steel plates. AC 18. Needs STR 15.")
	var sh := _item("shield", "Shield", ItemData.Kind.SHIELD, 10, "A wooden shield rimmed with iron. +2 AC.")
	sh.base_ac = 2
	_save(sh)

	# --- potions ---
	var ph := _item("potion_healing", "Potion of Healing", ItemData.Kind.POTION, 50,
			"A red liquid that glimmers when shaken. Drink it to regain 2d4 + 2 hit points.")
	ph.heal = "2d4+2"
	ph.stackable = true
	_save(ph)
	var pg := _item("potion_greater_healing", "Potion of Greater Healing", ItemData.Kind.POTION, 150,
			"A deep red potion. Drink it to regain 4d4 + 4 hit points.")
	pg.heal = "4d4+4"
	pg.stackable = true
	_save(pg)

	# --- rings ---
	var rp := _item("ring_protection", "Ring of Protection", ItemData.Kind.RING, 500,
			"A plain silver band that hums faintly. +1 to AC and to every saving throw.")
	rp.ac_bonus = 1
	rp.save_bonus = 1
	_save(rp)
	print("%d items written" % _written.size())
	quit()


func _item(id: String, name: String, kind: ItemData.Kind, value: int, desc: String) -> ItemData:
	var it := ItemData.new()
	it.id = id
	it.display_name = name
	it.resource_name = name
	it.kind = kind
	it.value_gp = value
	it.description = desc
	return it


func _weapon(id: String, name: String, cat: String, dmg: String, type: String,
		ability: AttackData.Ability, value: int, desc: String) -> ItemData:
	var it := _item(id, name, ItemData.Kind.WEAPON, value, desc)
	it.category = cat
	var a := AttackData.new()
	a.name = name
	a.kind = MELEE
	a.ability = ability
	a.damage = dmg
	a.damage_type = type
	it.attack = a
	_save(it)
	return it


func _ranged(id: String, name: String, cat: String, dmg: String, type: String,
		ability: AttackData.Ability, normal_ft: int, long_ft: int, value: int, two_handed: bool,
		desc: String) -> ItemData:
	var it := _weapon(id, name, cat, dmg, type, ability, value, desc)
	it.attack.kind = RANGED
	it.attack.range_ft = normal_ft
	it.attack.long_range_ft = long_ft
	it.ranged_slot = true
	it.two_handed = two_handed
	_save(it)
	return it


func _armor(id: String, name: String, type: String, ac: int, dex_cap: int, str_req: int,
		stealth: bool, value: int, desc: String) -> void:
	var it := _item(id, name, ItemData.Kind.ARMOR, value, desc)
	it.armor_type = type
	it.base_ac = ac
	it.dex_cap = dex_cap
	it.str_required = str_req
	it.stealth_disadvantage = stealth
	_save(it)


func _save(it: ItemData) -> void:
	var path := DIR + it.id + ".tres"
	var err := ResourceSaver.save(it, path)
	if err != OK:
		push_error("can't write %s (%d)" % [path, err])
	_written[it.id] = true
