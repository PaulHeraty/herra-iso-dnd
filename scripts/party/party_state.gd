class_name PartyState
## The heroes' state carried from one map to the next (HP, spell slots, uses, hit dice,
## death saves, equipment) and the party bag (gold + items). Saved when the party takes the
## stairs and applied to the freshly spawned heroes of the next map. Conditions are not carried (stairs are only taken outside combat). A restart after a party wipe (R) reloads the map, so the party
## comes back as it was when it arrived on that floor. SaveGame writes the same snapshot to disk.

## hero class -> Dictionary of runtime values. Empty = fresh party (full resources).
static var _heroes := {}
static var party_xp := 0
## The shared bag (Inventory.to_dict()); empty = a fresh party (Inventory.starting()).
static var bag := {}
## Quest + RunePortal state (their to_dict()), taken with the party; empty = a new game.
static var story := {}
## Time played in this game (seconds, maps only; not while paused). DungeonMap._process counts
## it; a restart (R) keeps counting, a load goes back to the save's time.
static var play_seconds := 0.0
## Which roster party this is ({id, name, modules_done}; Roster), {} = a new party never saved there.
static var roster := {}


static func has_state() -> bool:
	return not _heroes.is_empty()


static func save(map: DungeonMap) -> void:
	from_dict(snapshot(map))


## The party on `map` as plain data (what save() keeps), without changing the kept state.
static func snapshot(map: DungeonMap) -> Dictionary:
	var heroes := {}
	for h in map.party:
		heroes[h.hero_class] = {
			hp = h.hp, slots_left = h.slots_left.duplicate(), uses_left = h.uses_left.duplicate(),
			hit_dice_left = h.hit_dice_left,
			death_successes = h.death_successes, death_failures = h.death_failures,
			stable = h.stable, dead = h.dead, equipment = h.equipment.duplicate(),
			level = h.level, xp = h.xp,
		}
	return {heroes = heroes, party_xp = map.party_xp, bag = map.inventory.to_dict(),
			story = {quest = Quest.to_dict(), portal = RunePortal.to_dict()}, play_seconds = play_seconds,
			roster = roster.duplicate(true)}


## The kept state as plain data (for SaveGame).
static func to_dict() -> Dictionary:
	return {heroes = _heroes.duplicate(true), party_xp = party_xp, bag = bag.duplicate(true),
			story = story.duplicate(true), play_seconds = play_seconds, roster = roster.duplicate(true)}


static func from_dict(d: Dictionary) -> void:
	_heroes = d.get("heroes", {}).duplicate(true)
	party_xp = d.get("party_xp", 0)
	bag = d.get("bag", {}).duplicate(true)
	story = d.get("story", {}).duplicate(true)
	play_seconds = d.get("play_seconds", 0.0)
	roster = d.get("roster", {}).duplicate(true)


## Apply the saved values to a hero that has just been spawned (and _ready'd).
static func apply(h: Hero) -> void:
	if not _heroes.has(h.hero_class):
		return
	var s: Dictionary = _heroes[h.hero_class]
	h.equipment = s.get("equipment", h.equipment).duplicate()
	h.level = s.get("level", 1)
	h.xp = s.get("xp", 0)
	h.refresh_stats()
	if not s.has("hp"):                 # a roster party starting a new adventure: rested
		h.hp = h.stats.max_hp
		h.reset_resources()
		return
	h.hp = s.hp
	h.slots_left.assign(s.slots_left)
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
	play_seconds = 0.0
	roster = {}
