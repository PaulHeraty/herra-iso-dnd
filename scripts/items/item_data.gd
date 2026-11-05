class_name ItemData
extends Resource
## One kind of item (a definition, like SpellData): weapons, armour, shields, potions, scrolls,
## keys, rings, treasure. Files live in data/items/<id>.tres (tools/godot/build_items.gd).
## The party bag (Inventory) and hero equipment (Hero.equipment) refer to items by id.
##
## Rules content: 5e SRD 5.1 (CC-BY-4.0, see CREDITS.md).

enum Kind { WEAPON, ARMOR, SHIELD, POTION, SCROLL, KEY, RING, TREASURE }

const DIR := "res://data/items/"

@export var id := ""
@export var display_name := ""
@export var kind := Kind.TREASURE
@export_multiline var description := ""
@export var value_gp := 0
## Column in assets/ui/item_icons.png (step 3); -1 = generic icon for the kind.
@export var icon := -1
## Several of these share one bag slot (potions, scrolls, treasure).
@export var stackable := false
@export var magic_bonus := 0            ## +1 weapon / armour / shield
@export_group("Weapon")
@export var attack: AttackData          ## damage dice, ability, ranges (magic_bonus is added on top)
@export var category := "simple"        ## "simple" / "martial"
@export var ranged_slot := false        ## goes in the ranged slot (bows, crossbows, thrown handaxe)
@export var two_handed := false         ## main hand only: no shield with it
@export_group("Armour / shield / ring")
@export var armor_type := ""            ## "light" / "medium" / "heavy" (ARMOR)
@export var base_ac := 0                ## armour: 11 leather ... 16 chain mail; shield: +2
@export var dex_cap := -1               ## armour: max DEX added (-1 = no cap, 0 = none added)
@export var str_required := 0
@export var stealth_disadvantage := false
@export var ac_bonus := 0               ## rings (Ring of Protection +1)
@export var save_bonus := 0             ## rings (Ring of Protection +1 to all saves)
@export_group("Use")
@export var heal := ""                  ## potion: dice healed ("2d4+2")
@export var spell: SpellData            ## scroll: the spell it casts
@export var key_id := ""                ## key: opens doors/chests with this key_id

## Columns of assets/ui/item_icons.png (tools/godot/gen_item_art.gd draws them in this order).
## Items find theirs by id ("_plus1" magic versions share the plain one), else by kind.
const ICON_ORDER := [
	"dagger", "mace", "quarterstaff", "shortsword", "longsword", "rapier", "warhammer",
	"greatsword", "handaxe", "light_crossbow", "shortbow", "longbow",
	"leather_armor", "studded_leather", "chain_shirt", "scale_mail", "chain_mail", "plate_armor",
	"shield", "potion_healing", "potion_greater_healing", "ring_protection", "ring",
	"scroll", "key", "gem", "gold",
]
const KIND_ICON := {
	Kind.WEAPON: "longsword", Kind.ARMOR: "leather_armor", Kind.SHIELD: "shield",
	Kind.POTION: "potion_healing", Kind.SCROLL: "scroll", Kind.KEY: "key", Kind.RING: "ring",
	Kind.TREASURE: "gem",
}
const ICON_SIZE := 16
const ICONS_PATH := "res://assets/ui/item_icons.png"

static var _cache := {}
static var _icons: Texture2D


## Column of this item's picture in the icon sheet.
func icon_index() -> int:
	if icon >= 0:
		return icon
	var i := ICON_ORDER.find(id.trim_suffix("_plus1"))
	return i if i >= 0 else ICON_ORDER.find(KIND_ICON.get(kind, "gem"))


## A 16x16 texture of the icon (a fresh AtlasTexture on the icon sheet).
func icon_texture() -> AtlasTexture:
	return icon_texture_at(icon_index())


static func icon_texture_at(index: int) -> AtlasTexture:
	if _icons == null:
		_icons = load(ICONS_PATH)
	var at := AtlasTexture.new()
	at.atlas = _icons
	at.region = Rect2(index * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
	return at


## The item with this id (cached), or null.
static func get_item(item_id: String) -> ItemData:
	if _cache.has(item_id):
		return _cache[item_id]
	var path := DIR + item_id + ".tres"
	var it: ItemData = load(path) if ResourceLoader.exists(path) else null
	if it == null:
		push_warning("unknown item '%s'" % item_id)
	_cache[item_id] = it
	return it


func is_equipment() -> bool:
	return kind in [Kind.WEAPON, Kind.ARMOR, Kind.SHIELD, Kind.RING]


## Proficiency tag used by the class training lists: "simple"/"martial" for weapons,
## "light"/"medium"/"heavy" for armour, "shield" for shields; "" = anyone.
func training_tag() -> String:
	match kind:
		Kind.WEAPON: return category
		Kind.ARMOR: return armor_type
		Kind.SHIELD: return "shield"
	return ""


## Short line for tooltips, e.g. "1d8 slashing, +1" / "AC 16, heavy" / "Heals 2d4+2".
func summary() -> String:
	match kind:
		Kind.WEAPON:
			if attack == null:
				return ""
			var s := "%s %s" % [attack.damage, attack.damage_type]
			if attack.kind == AttackData.Kind.RANGED:
				s += ", range %d/%d ft" % [attack.range_ft, attack.long_range_ft]
			if attack.ability == AttackData.Ability.FINESSE:
				s += ", finesse"
			if two_handed:
				s += ", two-handed"
			return s + (", %+d" % magic_bonus if magic_bonus else "")
		Kind.ARMOR:
			var cap := ""
			if dex_cap < 0:
				cap = " + DEX"
			elif dex_cap > 0:
				cap = " + DEX (max %d)" % dex_cap
			return "AC %d%s, %s%s" % [base_ac + magic_bonus, cap, armor_type, ", stealth disadv." if stealth_disadvantage else ""]
		Kind.SHIELD:
			return "+%d AC" % (base_ac + magic_bonus)
		Kind.RING:
			var parts := []
			if ac_bonus:
				parts.append("%+d AC" % ac_bonus)
			if save_bonus:
				parts.append("%+d saves" % save_bonus)
			return ", ".join(parts)
		Kind.POTION:
			return "Heals %s" % heal if heal != "" else ""
		Kind.SCROLL:
			return "Casts %s" % spell.display_name if spell else ""
	return ""
