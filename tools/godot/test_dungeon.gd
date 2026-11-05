extends SceneTree
## Dungeon mechanics test (doors, locks, stairs, state carried between floors). Prints PASS/FAIL.
## Needs a window (no --headless needed for logic, but scenes use lights), e.g.:
##   HERRA_AUTO_REACT=1 Godot_console --path . -s res://tools/godot/test_dungeon.gd
## Uses scenes/maps/dungeon_1.tscn and dungeon_2.tscn (tools/godot/build_dungeon.gd).

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until_scene_changes(old: Node) -> void:
	for i in 600:
		await process_frame
		if current_scene != old and current_scene != null and current_scene.is_node_ready():
			break
	await _frames(10)


func _map() -> DungeonMap:
	return current_scene as DungeonMap


func _init() -> void:
	_run()


func _run() -> void:
	var first: DungeonMap = (load("res://scenes/maps/dungeon_1.tscn") as PackedScene).instantiate()
	root.add_child(first)
	current_scene = first
	await _frames(5)
	var m := _map()
	m.combat.set_process(false)            # no fights during the test
	_check(m.party.size() == 4, "party spawned on floor 1")
	_check(m.is_explored(m.party[0].cell) and not m.is_explored(Vector2i(5, 5)), "fog: start explored, guard room not")
	for i in m.party.size():
		m.party[i].place_at(Vector2i(5, 10 + i))
	m.update_fog()

	# --- an ordinary door: closed blocks the path, opening it clears it ---
	var door := m.door_at(Vector2i(5, 9))
	_check(door != null and not door.is_open, "guard-room door starts closed")
	_check(m.find_path(Vector2i(5, 10), Vector2i(5, 8)).is_empty(), "closed door blocks the path")
	_check(not m.has_line_of_sight(Vector2i(5, 11), Vector2i(5, 6)), "closed door blocks sight")
	m.try_open_door(door, m.party)
	_check(door.is_open, "door opens")
	_check(m.is_explored(Vector2i(5, 5)) and m.is_seen(Vector2i(5, 5)), "fog: opening the door reveals the guard room")
	_check(not m.find_path(Vector2i(5, 10), Vector2i(5, 8)).is_empty(), "open door lets the party through")

	# --- the locked crypt: the Rogue picks it (may take a few tries) ---
	var crypt := m.door_at(Vector2i(13, 21))
	_check(crypt.locked, "crypt door is locked")
	var tries := 0
	while not crypt.is_open and tries < 30:
		m.try_open_door(crypt, m.party)
		tries += 1
	_check(crypt.is_open and not crypt.locked, "crypt lock picked after %d tries" % tries)

	# --- the party clicks a door: walks to its near side, then opens it ---
	for i in m.party.size():
		m.party[i].place_at(Vector2i(8, 4 + i))
	m.update_fog()
	m.refresh_navigation()
	var storeroom := m.door_at(Vector2i(13, 5))
	var path := m.controller.door_path(storeroom)
	_check(not path.is_empty() and path[-1] in storeroom.sides(), "door_path ends beside the door")

	# --- damage a hero, kill the stair guards, take the stairs down ---
	var fighter := m.party[0]
	fighter.hp = 20
	m.party[3].slots_left[0] = 1
	# items: party AC/attacks from the kit; change the bag and an equipment slot before the stairs
	_check(fighter.stats.armor_class == 18 and fighter.stats.attacks[0].name == "Longsword", "fighter fights with the kit (AC %d)" % fighter.stats.armor_class)
	_check(m.inventory.count("potion_healing") == 3, "party starts with 3 potions")
	m.inventory.add_gold(25)
	m.inventory.add("warhammer")
	m.inventory.add("longsword")
	for it in fighter.equip("main", "warhammer"):
		m.inventory.add(it)
	m.inventory.remove("warhammer")
	_check(fighter.stats.attacks[0].name == "Warhammer" and m.inventory.count("longsword") == 2, "fighter swaps to the warhammer")
	var killed := 0
	for mo in m.monsters:
		if mo.cell.x >= 26 and mo.cell.y >= 16:
			mo.hp = 0
			killed += 1
	_check(killed == 2, "two stair guards removed")
	var down := m.stairs_at(Vector2i(32, 21))
	_check(down != null and not down.up, "stairs down in the stair room")
	for i in m.party.size():
		m.party[i].place_at(Vector2i(31 - i, 21))
	var old_down := m
	m.take_stairs(down)
	await _until_scene_changes(old_down)
	m = _map()
	_check(m.scene_file_path.ends_with("dungeon_2.tscn"), "arrived on floor 2")
	m.combat.set_process(false)
	_check(m.party[0].cell == Vector2i(4, 4), "party at the from_above entry (%s)" % m.party[0].cell)
	_check(m.party[0].hp == 20, "fighter's HP carried over (%d)" % m.party[0].hp)
	_check(m.party[3].slots_left[0] == 1, "mage's spent slots carried over")
	_check(m.inventory.gold == 25 and m.inventory.count("longsword") == 2 and m.inventory.count("potion_healing") == 3, "bag carried over")
	_check(m.party[0].stats.attacks[0].name == "Warhammer" and m.party[0].stats.armor_class == 18, "equipment carried over")

	# --- back up: floor 1 remembers its doors and dead monsters ---
	var up := m.stairs_at(Vector2i(3, 2))
	_check(up != null and up.up, "stairs up on floor 2")
	var old_up := m
	m.take_stairs(up)
	await _until_scene_changes(old_up)
	m = _map()
	_check(m.scene_file_path.ends_with("dungeon_1.tscn"), "back on floor 1")
	_check(m.party[0].cell == Vector2i(31, 21), "party at the from_below entry (%s)" % m.party[0].cell)
	_check(m.door_at(Vector2i(5, 9)).is_open and m.door_at(Vector2i(13, 21)).is_open, "opened doors stay open")
	var guards := 0
	for mo in m.monsters:
		if mo.cell.x >= 26 and mo.cell.y >= 16:
			guards += 1
	_check(guards == 0, "killed stair guards stay dead")
	_check(m.is_explored(Vector2i(5, 5)) and not m.is_seen(Vector2i(5, 5)), "fog: guard room remembered (dimmed) on return")
	_check(m.monsters.size() == 8, "the other monsters are still there (%d)" % m.monsters.size())
	print("test_dungeon: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILURES", fails])
	quit(1 if fails else 0)
