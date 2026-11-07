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

	# --- spell scrolls (SRD Spell Scroll): read by a class with the spell on its list ---
	_scroll("magic_missile", 75, "Violet ink on thin parchment.")
	_scroll("cure_wounds", 75, "A healing prayer in gold leaf.")
	_scroll("bless", 75, "A short blessing on fine vellum.")
	_scroll("fireball", 300, "Scorched at the edges, warm to the touch.")
	_scroll("lightning_bolt", 300, "It crackles. Your hair stands on end.")

	# --- keys: open the doors and chests with the same key_id; never used up ---
	_key("crypt_key", "Iron Key", "crypt", "A heavy iron key, green with age. A skull is cut into its bow.")
	_key("lair_key", "Bone Key", "lair", "A key carved from a single long bone. It is cold to hold.")

	# --- rings ---
	var rp := _item("ring_protection", "Ring of Protection", ItemData.Kind.RING, 500,
			"A plain silver band that hums faintly. +1 to AC and to every saving throw.")
	rp.ac_bonus = 1
	rp.save_bonus = 1
	_save(rp)
	var rf := _item("ring_free_action", "Ring of Free Action", ItemData.Kind.RING, 500,
			"A band of woven silver wire, light as thread. Webs and bonds slide off its wearer: you can't be restrained.")
	rf.condition_immunities.assign(["restrained"])
	_save(rf)
	var rr := _item("ring_resistance", "Ring of Resistance (poison)", ItemData.Kind.RING, 500,
			"A gold ring set with a green stone. Poison does half damage to its wearer.")
	rr.resistances.assign(["poison"])
	_save(rr)

	# --- magic weapons and armour (SRD Weapon / Armor / Shield, +1): a copy of the plain item ---
	_plus1("longsword", "The blade never dulls and gleams faintly blue in the dark.")
	_plus1("mace", "Holy runes run round its flanges. Bones crack like eggshell under it.")
	_plus1("rapier", "A whisper-thin blade that finds the gaps in any guard.")
	_plus1("dagger", "Perfectly balanced. Its edge hums when drawn.")
	_plus1("shortbow", "Pale yew strung with spider silk. Arrows fly true.")
	_plus1("chain_mail", "Rings of bright mithral-silvered steel. Never rusts.")
	_plus1("studded_leather", "Dark leather set with silver studs. Moves like a second skin.")
	_plus1("shield", "A steel shield with a sunburst boss. Blows glance off it.")

	# --- Phase 5: more SRD weapons and armour ---
	_weapon("scimitar", "Scimitar", "martial", "1d6", "slashing", FIN, 25, "A curved blade, quick in the hand. Finesse.")
	_weapon("battleaxe", "Battleaxe", "martial", "1d8", "slashing", STR, 10, "A broad-bladed war axe.")
	var ga := _weapon("greataxe", "Greataxe", "martial", "1d12", "slashing", STR, 30, "A huge double-bitted axe. Two-handed.")
	ga.two_handed = true
	_save(ga)
	_weapon("morningstar", "Morningstar", "martial", "1d8", "piercing", STR, 15, "A spiked iron ball on a haft.")
	_ranged("heavy_crossbow", "Heavy Crossbow", "martial", "1d10", "piercing", DEX, 100, 400, 50, true, "A heavy crossbow with a steel prod.")
	_armor("breastplate", "Breastplate", "medium", 14, 2, 0, false, 400, "A fitted steel cuirass. AC 14 + DEX (max 2). Quiet.")
	_armor("half_plate", "Half Plate", "medium", 15, 2, 0, true, 750, "Plates over most of the body. AC 15 + DEX (max 2). Noisy.")
	var ps := _item("potion_superior_healing", "Potion of Superior Healing", ItemData.Kind.POTION, 450,
			"A ruby-dark potion that glows from within. Drink it to regain 8d4 + 8 hit points.")
	ps.heal = "8d4+8"
	ps.stackable = true
	_save(ps)
	for sid in [["burning_hands", 75, "Smells of smoke."], ["healing_word", 75, "A single word of power, gilded."],
			["hold_person", 150, "Lines of binding script, cold to touch."], ["scorching_ray", 150, "The ink still smoulders."],
			["mass_healing_word", 300, "Six names, and a prayer for each."]]:
		_scroll(sid[0], sid[1], sid[2])
	_key("warren_key", "Chief's Key", "warren", "A crude iron key on a thong of goblin hide.")
	_key("vault_key", "Sun Key", "vault", "A gold key shaped like a sunburst. It is warm in the dark.")

	# --- the Rune of Return: Brannoc the trader's gift (Quest); not SRD, our own ---
	var rune := _item("rune_of_return", "Rune of Return", ItemData.Kind.RUNE, 0,
			"A smooth grey stone with a blue rune that never stops glowing. Speak its word anywhere below ground and a portal opens back to Brannoc's stall; step through it again to return. It never runs out.")
	rune.wondrous = true
	_save(rune)

	# --- magic: +1 / +2 and named items ---
	_plus1("warhammer", "Dwarf-made. The head rings like a bell on every blow.")
	_plus1("scimitar", "A desert blade with a moon etched near the hilt.")
	_plus1("breastplate", "Burnished steel. Arrows skid off it.")
	_plus1("half_plate", "Enamelled plates in faded royal blue.")
	_plus1("plate_armor", "Black-lacquered plate. It fits whoever wears it.")
	_plus1("longbow", "Elm and horn. It never warps.")
	_plus("longsword", 2, "An heirloom blade. Its edge has never been honed and never needed it.")
	_plus("rapier", 2, "Light as a reed. It seems to know where to go.")
	_plus("shortbow", 2, "Wrapped in silver wire. Its arrows hardly make a sound.")
	_plus("shield", 2, "An ancient kite shield with a hawk painted on it. Nothing gets past it.")
	_plus("studded_leather", 2, "Shadow-dark leather with mithral studs.")
	_plus("mace", 2, "A temple's holy mace, its head shaped like a crown.")
	var ft: ItemData = ResourceLoader.load(DIR + "longsword.tres", "", ResourceLoader.CACHE_MODE_IGNORE).duplicate(true)
	ft.id = "flame_tongue"
	ft.display_name = "Flame Tongue"
	ft.resource_name = ft.display_name
	ft.base_item = "longsword"
	ft.wondrous = true
	ft.icon = ItemData.ICON_ORDER.find("flame_tongue")
	ft.value_gp = 5000
	ft.description = "A longsword whose blade bursts into flame when drawn.\nMagic: +2d6 fire damage on every hit."
	ft.attack.name = ft.display_name
	ft.attack.rider_damage = "2d6"
	ft.attack.rider_damage_type = "fire"
	_save(ft)
	var md: ItemData = ResourceLoader.load(DIR + "mace.tres", "", ResourceLoader.CACHE_MODE_IGNORE).duplicate(true)
	md.id = "mace_of_disruption"
	md.display_name = "Mace of Disruption"
	md.resource_name = md.display_name
	md.base_item = "mace"
	md.wondrous = true
	md.icon = ItemData.ICON_ORDER.find("mace_of_disruption")
	md.value_gp = 4000
	md.description = "Sunlight seems to cling to its golden head.\nMagic: +2d6 radiant damage against undead and fiends."
	md.attack.name = md.display_name
	md.attack.rider_damage = "2d6"
	md.attack.rider_damage_type = "radiant"
	md.attack.rider_vs.assign(["undead", "fiend"])
	_save(md)
	var rn := _item("ring_resistance_necrotic", "Ring of Resistance (necrotic)", ItemData.Kind.RING, 500,
			"A black iron ring set with a violet stone. The touch of the grave does half damage to its wearer.")
	rn.resistances.assign(["necrotic"])
	_save(rn)

	# --- module 2 (the Frostfell, the Rimecaller's tower): SRD gear for levels 5-9 ---
	var fbr: ItemData = ResourceLoader.load(DIR + "longsword.tres", "", ResourceLoader.CACHE_MODE_IGNORE).duplicate(true)
	fbr.id = "frost_brand"
	fbr.display_name = "Frost Brand"
	fbr.resource_name = fbr.display_name
	fbr.base_item = "longsword"
	fbr.wondrous = true
	fbr.icon = ItemData.ICON_ORDER.find("frost_brand")
	fbr.value_gp = 6000
	fbr.description = "A longsword rimed with frost that never melts. Cold mist pours from the blade.\nMagic: +1d6 cold damage on every hit, and its wielder resists fire."
	fbr.attack.name = fbr.display_name
	fbr.attack.rider_damage = "1d6"
	fbr.attack.rider_damage_type = "cold"
	fbr.resistances.assign(["fire"])
	_save(fbr)
	_plus("warhammer", 2, "A dwarf-lord's hammer. Runes of the forge glow along its haft.")
	_plus("longbow", 2, "White ash and frost-giant sinew. It never loses its pull in the cold.")
	_plus("dagger", 2, "A sliver of blue steel. It finds every gap.")
	_plus("chain_mail", 2, "Mail of bright elven rings, light as cloth.")
	_plus("plate_armor", 2, "Plate enamelled white and silver. Frost never forms on it.")
	_plus("breastplate", 2, "A silvered cuirass etched with a snowflake crest.")
	_plus("half_plate", 2, "Knightly plates lined with white bearskin.")
	for rs in [["ring_warmth", "Ring of Warmth", "cold", "A gold ring set with a stone that glows like a coal. Its wearer never feels the cold: cold does half damage to them."],
			["ring_resistance_fire", "Ring of Resistance (fire)", "fire", "A copper ring set with a ruby. Fire does half damage to its wearer."],
			["ring_resistance_lightning", "Ring of Resistance (lightning)", "lightning", "A silver ring set with a blue spark of a stone. Lightning does half damage to its wearer."]]:
		var rg := _item(rs[0], rs[1], ItemData.Kind.RING, 500 if rs[0] != "ring_warmth" else 1000, rs[3])
		rg.resistances.assign([rs[2]])
		if rs[0] != "ring_resistance_lightning":
			rg.icon = ItemData.ICON_ORDER.find("ring_warmth")
		_save(rg)
	var cp := _wondrous("cloak_protection", "Cloak of Protection", 3500,
			"A cloak of deep blue wool with a silver clasp. Blows and spells alike seem to slide off it.\nMagic: +1 to AC and to every saving throw.")
	cp.ac_bonus = 1
	cp.save_bonus = 1
	_save(cp)
	var ah := _wondrous("amulet_health", "Amulet of Health", 8000,
			"A heart-shaped ruby on a gold chain. It beats, very faintly.\nMagic: your Constitution is 19 (more hit points).")
	ah.ability_set = {"CON": 19}
	_save(ah)
	var go := _wondrous("gauntlets_ogre_power", "Gauntlets of Ogre Power", 8000,
			"Heavy leather gauntlets studded with iron. Your grip could crush stone.\nMagic: your Strength is 19.")
	go.ability_set = {"STR": 19}
	_save(go)
	var bd := _wondrous("bracers_defense", "Bracers of Defense", 6000,
			"Bands of blued steel trimmed with gold. Blows turn aside from a wearer without armour.\nMagic: +2 AC while you wear no armour and carry no shield.")
	bd.ac_unarmored = 2
	_save(bd)
	var hi := _wondrous("headband_intellect", "Headband of Intellect", 8000,
			"A silver circlet with a single blue gem over the brow. Thoughts come clear and quick.\nMagic: your Intelligence is 19.")
	hi.ability_set = {"INT": 19}
	_save(hi)
	var pss := _item("potion_supreme_healing", "Potion of Supreme Healing", ItemData.Kind.POTION, 1350,
			"A violet potion that shines like a star. Drink it to regain 10d4 + 20 hit points.")
	pss.heal = "10d4+20"
	pss.stackable = true
	_save(pss)
	for sid in [["ice_storm", 1000, "The vellum is frozen stiff."], ["death_ward", 1000, "A prayer against the last breath."],
			["cone_of_cold", 2000, "Frost creeps across your fingers as you unroll it."],
			["mass_cure_wounds", 2000, "A hymn of healing, signed by six priests."]]:
		_scroll(sid[0], sid[1], sid[2])
	_key("rime_key", "Rime Key", "rime", "A key of blue ice that never melts. It aches with cold.")
	_key("star_key", "Star Key", "star", "A silver key whose bow is a seven-pointed star.")
	var lan := _item("sunfire_lantern", "Sunfire Lantern", ItemData.Kind.TREASURE, 0,
			"A brass lantern whose flame never goes out, even in the deepest cold. Hilde's family heirloom: bring it back to her.")
	lan.icon = ItemData.ICON_ORDER.find("lantern")
	lan.wondrous = true
	_save(lan)
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


## A Spell Scroll of `spell_id` (data/spells/, built by build_data.gd first).
func _scroll(spell_id: String, value: int, flavour: String) -> void:
	var sp: SpellData = load("res://data/spells/%s.tres" % spell_id)
	const HERO := {wizard = "Mage", cleric = "Cleric"}   # the party's names for the classes
	var who := " or ".join(sp.classes.map(func(c: String) -> String: return HERO.get(c, c.capitalize())))
	var lvl := "cantrip" if sp.level == 0 else "%s level" % ["", "1st", "2nd", "3rd", "4th", "5th"][sp.level]
	var what := sp.description_at_level()     # a scroll casts at its own level: no upcasting
	var it := _item("scroll_" + spell_id, "Scroll of " + sp.display_name, ItemData.Kind.SCROLL, value,
			"%s\n%s (%s): %s\n%s only. Crumbles once read. DC %d, attack +%d." % [
				flavour, sp.display_name, lvl, what, who, SpellData.scroll_dc(sp.level), SpellData.scroll_attack_bonus(sp.level)])
	it.spell = sp
	it.stackable = true
	_save(it)


## "<id>_plus1": the plain item (already written above) with +1 to hit and damage (weapons) or
## +1 AC (armour, shields), 1st-tier SRD value.
func _plus1(base_id: String, flavour: String) -> void:
	var base: ItemData = ResourceLoader.load(DIR + base_id + ".tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	var it: ItemData = base.duplicate(true)
	it.id = base_id + "_plus1"
	it.display_name = base.display_name + " +1"
	it.resource_name = it.display_name
	it.magic_bonus = 1
	it.value_gp = base.value_gp + (500 if base.kind == ItemData.Kind.WEAPON else 1000)
	var bonus := "Magic: +1 to hit and damage." if base.kind == ItemData.Kind.WEAPON else "Magic: +1 AC."
	it.description = "%s\n%s" % [flavour, bonus]
	if it.attack:
		it.attack.name = it.display_name
	_save(it)


func _key(id: String, name: String, key_id: String, desc: String) -> void:
	var it := _item(id, name, ItemData.Kind.KEY, 0, desc + " It opens a lock somewhere in the dungeon.")
	it.key_id = key_id
	_save(it)


## "<id>_plus<n>": like _plus1 with a bigger bonus (2nd tier: rarer, worth more).
func _plus(base_id: String, n: int, flavour: String) -> void:
	var base: ItemData = ResourceLoader.load(DIR + base_id + ".tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	var it: ItemData = base.duplicate(true)
	it.id = "%s_plus%d" % [base_id, n]
	it.display_name = "%s +%d" % [base.display_name, n]
	it.resource_name = it.display_name
	it.magic_bonus = n
	it.value_gp = base.value_gp + (2000 if base.kind == ItemData.Kind.WEAPON else 4000)
	var bonus := ("Magic: +%d to hit and damage." if base.kind == ItemData.Kind.WEAPON else "Magic: +%d AC.") % n
	it.description = "%s\n%s" % [flavour, bonus]
	if it.attack:
		it.attack.name = it.display_name
	_save(it)


## A worn wondrous item (cloak, amulet, gauntlets...): its icon by id.
func _wondrous(id: String, name: String, value: int, desc: String) -> ItemData:
	var it := _item(id, name, ItemData.Kind.WONDROUS, value, desc)
	it.icon = ItemData.ICON_ORDER.find(id)
	return it
