class_name Equipment
## What a hero wears and wields, and how that turns their base stat block (data/heroes/) into the
## stats the game uses: AC from armour + DEX (capped) + shield + rings, the attack list from the
## main-hand and ranged weapons, saving-throw bonuses from rings, speed -10 ft for heavy armour
## without the Strength for it. Pure static functions, so the rules tests can run them headless.
##
## A hero's equipment is a Dictionary slot -> item id (Hero.equipment). Simplifications: one
## main-hand weapon + one ranged weapon (bow, crossbow or thrown handaxe) carried at once, the
## off hand holds a shield only (no two-weapon fighting yet), two ring slots, no attunement.

const SLOTS := ["main", "off", "ranged", "armor", "ring1", "ring2"]
const SLOT_NAMES := {
	main = "Main hand", off = "Off hand", ranged = "Ranged", armor = "Armour",
	ring1 = "Ring", ring2 = "Ring",
}


## The slot an item normally goes in ("" = not equipment). Rings: the first free ring slot.
static func default_slot(item: ItemData, eq := {}) -> String:
	match item.kind:
		ItemData.Kind.WEAPON: return "ranged" if item.ranged_slot else "main"
		ItemData.Kind.SHIELD: return "off"
		ItemData.Kind.ARMOR: return "armor"
		ItemData.Kind.RING: return "ring2" if eq.has("ring1") and not eq.has("ring2") else "ring1"
	return ""


static func slot_accepts(slot: String, item: ItemData) -> bool:
	match slot:
		"main": return item.kind == ItemData.Kind.WEAPON and not item.ranged_slot
		"ranged": return item.kind == ItemData.Kind.WEAPON and item.ranged_slot
		"off": return item.kind == ItemData.Kind.SHIELD
		"armor": return item.kind == ItemData.Kind.ARMOR
		"ring1", "ring2": return item.kind == ItemData.Kind.RING
	return false


## Is the class trained with this item? (SRD class proficiencies: tags like "martial" / "heavy" /
## "shield", or single weapon ids like "rapier" for the Rogue and Wizard.)
static func is_trained(base: CreatureStats, item: ItemData) -> bool:
	var tag := item.training_tag()
	if tag == "":
		return true
	if item.kind == ItemData.Kind.WEAPON:
		return tag in base.weapon_training or item.base_id() in base.weapon_training
	return tag in base.armor_training


## Why `item` can't go in `slot` for this hero ("" = it can). Weapons without training can be
## used (no proficiency bonus); armour and shields without training can't be worn.
static func cannot_equip(base: CreatureStats, item: ItemData, slot: String) -> String:
	if item == null or not item.is_equipment():
		return "Not something to wear or wield"
	if not slot_accepts(slot, item):
		return "Doesn't go in the %s slot" % SLOT_NAMES.get(slot, slot).to_lower()
	if item.kind in [ItemData.Kind.ARMOR, ItemData.Kind.SHIELD] and not is_trained(base, item):
		return "%s isn't trained with %s" % [base.display_name,
				"shields" if item.kind == ItemData.Kind.SHIELD else item.armor_type + " armour"]
	return ""


## Slots that have to be emptied when `item` goes into `slot` (a two-handed weapon and a shield
## don't go together).
static func displaced_by(eq: Dictionary, item: ItemData, slot: String) -> Array[String]:
	var out: Array[String] = []
	if eq.has(slot):
		out.append(slot)
	if slot == "main" and item.two_handed and eq.has("off"):
		out.append("off")
	elif slot == "off" and eq.has("main"):
		var m := ItemData.get_item(eq.main)
		if m and m.two_handed:
			out.append("main")
	return out


## The equipment after putting `item` in `slot` (what it displaces taken off).
static func with_item(eq: Dictionary, item: ItemData, slot: String) -> Dictionary:
	var out := eq.duplicate()
	for s in displaced_by(eq, item, slot):
		out.erase(s)
	out[slot] = item.id
	return out


## Starting equipment (base.starting_equipment item ids) as slot -> id.
static func starting(base: CreatureStats) -> Dictionary:
	var eq := {}
	for iid in base.starting_equipment:
		var it := ItemData.get_item(iid)
		if it and it.is_equipment():
			eq[default_slot(it, eq)] = iid
	return eq


## The stats a hero with base stat block `base` and equipment `eq` fights with. A copy of `base`:
## armor_class, attacks, speed and the save bonus are worked out from the equipment.
static func build_stats(base: CreatureStats, eq: Dictionary, level := 0) -> CreatureStats:
	var s: CreatureStats = base.duplicate()
	# Heroes: the level-1 stat block grown to `level` (0 = the level written in the file).
	if base.class_id != "":
		Progression.apply(s, level if level > 0 else maxi(1, base.level))
	var dex := s.mod("DEX")
	var ac := 10 + dex
	var save_b := 0
	var attacks: Array[AttackData] = []
	var main := _item(eq, "main")
	if main and main.attack:
		attacks.append(_weapon_attack(base, main))
	else:
		attacks.append(_unarmed())
	var ranged := _item(eq, "ranged")
	if ranged and ranged.attack:
		attacks.append(_weapon_attack(base, ranged))
	var armor := _item(eq, "armor")
	if armor:
		var d := dex if armor.dex_cap < 0 else mini(dex, armor.dex_cap)
		ac = armor.base_ac + armor.magic_bonus + d
		if armor.str_required > s.str_score:
			s.speed_ft = maxi(5, base.speed_ft - 10)
		# Fighting Style: Defense (Fighter) - +1 AC while wearing armour.
		if base.class_id == "fighter":
			ac += 1
		s.stealth_disadvantage = armor.stealth_disadvantage
	var shield := _item(eq, "off")
	if shield:
		ac += shield.base_ac + shield.magic_bonus
	# own copies of the lists (a duplicate() may share them with the base stat block)
	var resist: Array[String] = base.resistances.duplicate()
	var cimm: Array[String] = base.condition_immunities.duplicate()
	for slot in ["ring1", "ring2"]:
		var r := _item(eq, slot)
		if r:
			ac += r.ac_bonus
			save_b += r.save_bonus
			for t in r.resistances:
				if t not in resist:
					resist.append(t)
			for c in r.condition_immunities:
				if c not in cimm:
					cimm.append(c)
	s.resistances = resist
	s.condition_immunities = cimm
	s.armor_class = ac
	s.item_save_bonus = save_b
	s.attacks = attacks
	return s


static func _item(eq: Dictionary, slot: String) -> ItemData:
	return ItemData.get_item(eq[slot]) if eq.has(slot) else null


static func _weapon_attack(base: CreatureStats, item: ItemData) -> AttackData:
	var a: AttackData = item.attack.duplicate()
	a.name = item.display_name
	a.magic_bonus += item.magic_bonus
	a.magical = item.is_magic()
	a.proficient = is_trained(base, item)
	return a


## 5e unarmed strike: 1 + STR bludgeoning.
static func _unarmed() -> AttackData:
	var a := AttackData.new()
	a.name = "Unarmed strike"
	a.damage = "1"
	a.damage_type = "bludgeoning"
	return a
