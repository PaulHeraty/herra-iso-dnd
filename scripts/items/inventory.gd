class_name Inventory
extends RefCounted
## The party's shared bag: gold and items (by id). Stackable items (potions, scrolls, treasure)
## share one entry with a count; everything else takes an entry each. Lives on the DungeonMap
## (DungeonMap.inventory) and is carried between floors by PartyState, like the heroes' HP.

signal changed

## What a fresh party sets out with (on top of each hero's starting equipment).
const STARTING := {"potion_healing": 3}

var gold := 0
## [{id, count}] in the order things were picked up.
var stacks: Array[Dictionary] = []


static func starting() -> Inventory:
	var inv := Inventory.new()
	for iid in STARTING:
		inv.add(iid, STARTING[iid])
	return inv


func add(item_id: String, n := 1) -> void:
	var it := ItemData.get_item(item_id)
	if it == null or n <= 0:
		return
	if it.stackable:
		for st in stacks:
			if st.id == item_id:
				st.count += n
				changed.emit()
				return
		stacks.append({id = item_id, count = n})
	else:
		for i in n:
			stacks.append({id = item_id, count = 1})
	changed.emit()


## Take `n` of an item out of the bag. False (and nothing taken) if there aren't that many.
func remove(item_id: String, n := 1) -> bool:
	if count(item_id) < n:
		return false
	for i in range(stacks.size() - 1, -1, -1):
		if n <= 0:
			break
		var st: Dictionary = stacks[i]
		if st.id != item_id:
			continue
		var k := mini(n, st.count)
		st.count -= k
		n -= k
		if st.count <= 0:
			stacks.remove_at(i)
	changed.emit()
	return true


func count(item_id: String) -> int:
	var c := 0
	for st in stacks:
		if st.id == item_id:
			c += st.count
	return c


func has(item_id: String) -> bool:
	return count(item_id) > 0


## Any item in the bag that opens locks with this key_id ("" if none).
func key_for(key_id: String) -> String:
	if key_id == "":
		return ""
	for st in stacks:
		var it := ItemData.get_item(st.id)
		if it and it.kind == ItemData.Kind.KEY and it.key_id == key_id:
			return st.id
	return ""


## Tidy the bag: weapons, armour, shields, rings, potions, scrolls, keys, treasure; by name within.
func sort() -> void:
	var order := [ItemData.Kind.WEAPON, ItemData.Kind.ARMOR, ItemData.Kind.SHIELD, ItemData.Kind.RING,
			ItemData.Kind.POTION, ItemData.Kind.SCROLL, ItemData.Kind.RUNE, ItemData.Kind.KEY, ItemData.Kind.TREASURE]
	var key := func(st: Dictionary) -> String:
		var it := ItemData.get_item(st.id)
		return "%d %s" % [order.find(it.kind), it.display_name] if it else "9"
	stacks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return key.call(a) < key.call(b))
	changed.emit()


func add_gold(n: int) -> void:
	gold += n
	changed.emit()


func to_dict() -> Dictionary:
	return {gold = gold, stacks = stacks.duplicate(true)}


static func from_dict(d: Dictionary) -> Inventory:
	var inv := Inventory.new()
	inv.gold = d.get("gold", 0)
	inv.stacks.assign(d.get("stacks", []).duplicate(true))
	return inv
