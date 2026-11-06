class_name PartyState
## The heroes' state carried from one map to the next (HP, spell slots, uses, hit dice,
## death saves, equipment) and the party bag (gold + items). Saved when the party takes the
## stairs and applied to the freshly spawned heroes of the next map. Conditions are not carried (stairs are only taken outside combat). A restart after a party wipe (R) reloads the map, so the party
## comes back as it was when it arrived on that floor.

## hero class -> Dictionary of runtime values. Empty = fresh party (full resources).
static var _heroes := {}
static var party_xp := 0
## The shared bag (Inventory.to_dict()); empty = a fresh party (Inventory.starting()).
static var bag := {}
## Quest + RunePortal state (their to_dict()), taken with the party; empty = a new game.
static var story := {}


static func has_state() -> bool:
	return not _heroes.is_empty()


static func save(map: DungeonMap) -> void:
	_heroes.clear()
	party_xp = map.party_xp
	bag = map.inventory.to_dict()
	story = {quest = Quest.to_dict(), portal = RunePortal.to_dict()}
	for h in map.party:
		_heroes[h.hero_class] = {
			hp = h.hp, slots_left = h.slots_left.duplicate(), uses_left = h.uses_left.duplicate(),
			hit_dice_left = h.hit_dice_left,
			death_successes = h.death_successes, death_failures = h.death_failures,
			stable = h.stable, dead = h.dead, equipment = h.equipment.duplicate(),
			level = h.level, xp = h.xp,
		}


## Apply the saved values to a hero that has just been spawned (and _ready'd).
static func apply(h: Hero) -> void:
	if not _heroes.has(h.hero_class):
		return
	var s: Dictionary = _heroes[h.hero_class]
	h.equipment = s.get("equipment", h.equipment).duplicate()
	h.level = s.get("level", 1)
	h.xp = s.get("xp", 0)
	h.refresh_stats()
	h.hp = s.hp
	h.slots_left = s.slots_left.duplicate()
	h.uses_left = s.uses_left.duplicate()
	h.hit_dice_left = s.hit_dice_left
	h.death_successes = s.death_successes
	h.death_failures = s.death_failures
	h.stable = s.stable
	h.dead = s.dead
	if h.dead:
		h.on_died()
	elif h.hp <= 0:
		h.restore_down()


static func reset() -> void:
	_heroes.clear()
	party_xp = 0
	bag = {}
	story = {}
