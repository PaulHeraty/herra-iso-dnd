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

	# --- the storeroom chest: locked (DC 12), walk up, pick it, loot goes in the bag ---
	m.try_open_door(storeroom, m.party)
	var chest := m.chest_at(Vector2i(19, 3))
	_check(chest != null and chest.locked and not chest.opened, "storeroom chest is closed and locked")
	var cpath := m.controller.approach_path(chest.sides())
	_check(not cpath.is_empty() and cpath[-1] in chest.sides(), "approach_path ends beside the chest")
	for i in m.party.size():
		m.party[i].place_at(cpath[-1] if i == 0 else Vector2i(16, 4 + i))
	m.update_fog()
	_check(m.closed_chest_under(chest.position + Vector2(0, -6)) == chest, "clicking the chest sprite finds it")
	var ctries := 0
	while not chest.opened and ctries < 30:
		m.try_open_chest(chest, m.party)
		ctries += 1
	_check(chest.opened and not chest.locked, "chest lock picked after %d tries" % ctries)
	_check(chest.get_node("Sprite").texture == Chest.OPEN_TEX, "open chest sprite")
	_check(m.inventory.gold == 40 and m.inventory.count("potion_healing") == 5, "chest loot in the bag (gold %d, potions %d)" % [m.inventory.gold, m.inventory.count("potion_healing")])
	_check(m.inventory.has("crypt_key") and m.inventory.has("scroll_cure_wounds"), "the storeroom chest held the Iron Key and a scroll")
	_check(m.hud.loot_open(), "loot box shown")
	m.try_open_chest(chest, m.party)
	_check(m.inventory.gold == 40, "an opened chest gives nothing twice")
	_check(m.closed_chest_under(chest.position) == null, "opened chest no longer clickable")

	# --- damage a hero, kill the stair guards, take the stairs down ---
	var fighter := m.party[0]
	fighter.hp = 20
	m.party[3].slots_left[0] = 1
	# items: party AC/attacks from the kit; change the bag and an equipment slot before the stairs
	_check(fighter.stats.armor_class == 18 and fighter.stats.attacks[0].name == "Longsword", "fighter fights with the kit (AC %d)" % fighter.stats.armor_class)
	_check(m.inventory.count("potion_healing") == 5, "3 starting potions + 2 from the chest")
	m.inventory.add_gold(25)
	m.inventory.add("warhammer")
	m.inventory.add("longsword")
	# the inventory screen: I opens it, equip / take off through it, Esc closes it
	var key_i := InputEventKey.new()
	key_i.keycode = KEY_I
	key_i.pressed = true
	Input.parse_input_event(key_i)
	await _frames(3)
	var inv := m.hud.inventory_screen
	_check(inv.visible and m.hud.mouse_over_ui(), "I opens the inventory (and blocks the map)")
	_check(inv.equip(fighter, "warhammer"), "fighter equips the warhammer from the screen")
	_check(fighter.stats.attacks[0].name == "Warhammer" and m.inventory.count("longsword") == 2 and not m.inventory.has("warhammer"), "fighter swaps to the warhammer")
	m.inventory.add("studded_leather")
	_check(not inv.equip(m.party[3], "studded_leather") and m.inventory.has("studded_leather"), "the mage can't wear armour; it stays in the bag")
	_check(inv.unequip(fighter, "ranged") and not fighter.equipment.has("ranged") and m.inventory.has("handaxe"), "take off the handaxe into the bag")
	_check(inv.equip(fighter, "handaxe") and fighter.equipment.get("ranged") == "handaxe", "and put it back on")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _frames(3)
	_check(not inv.visible, "Esc closes the inventory")
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
	_check(m.inventory.gold == 65 and m.inventory.count("longsword") == 2 and m.inventory.count("potion_healing") == 5, "bag carried over")
	_check(m.party[0].stats.attacks[0].name == "Warhammer" and m.party[0].stats.armor_class == 18, "equipment carried over")
	_check(m.inventory.has("crypt_key"), "the Iron Key came along")

	# --- keys: the lair door opens only with the Bone Key ---
	var lair := m.door_at(Vector2i(15, 17))
	_check(lair.locked and lair.key_id == "lair" and lair.lock_dc == 0, "lair door: key only")
	_check(m.lock_hint(lair, "Door").contains("needs a key"), "hover hint: needs a key")
	for i in 5:
		m.try_open_door(lair, m.party)
	_check(lair.locked and not lair.is_open, "no picking or forcing a key-only lock")
	var cm1 := m.combat
	var opener := m.party[1]
	var keep_cell := opener.cell
	opener.place_at(lair.sides()[0] if m.has_floor(lair.sides()[0]) else lair.sides()[1])
	cm1.current = opener
	cm1.action_used = false
	cm1.attacks_left = opener.stats.attacks_per_action()
	cm1.interact_used = false
	_check(cm1._door_problem(lair) == "Locked: it needs a key", "in a fight, without the key: '%s'" % cm1._door_problem(lair))
	m.inventory.add("lair_key")
	_check(m.lock_hint(lair, "Door").contains("Bone Key"), "hover hint names the key")
	cm1.action_used = true
	cm1.attacks_left = 0
	_check(cm1._door_problem(lair) == "", "with the key it's the free interaction, even after the action")
	cm1.interact_used = true
	_check(cm1._door_problem(lair) != "", "but only one door a turn")
	cm1.current = null
	opener.place_at(keep_cell)
	m.try_open_door(lair, m.party)
	_check(lair.is_open and m.inventory.has("lair_key"), "the Bone Key opens it (and is kept)")

	# --- back up: floor 1 remembers its doors and dead monsters ---
	var up := m.stairs_at(Vector2i(3, 2))
	_check(up != null and up.up, "stairs up on floor 2")
	var old_up := m
	m.take_stairs(up)
	await _until_scene_changes(old_up)
	m = _map()
	_check(m.scene_file_path.ends_with("dungeon_1.tscn"), "back on floor 1")
	m.combat.set_process(false)
	_check(m.party[0].cell == Vector2i(31, 21), "party at the from_below entry (%s)" % m.party[0].cell)
	_check(m.door_at(Vector2i(5, 9)).is_open and m.door_at(Vector2i(13, 21)).is_open, "opened doors stay open")
	var guards := 0
	for mo in m.monsters:
		if mo.cell.x >= 26 and mo.cell.y >= 16:
			guards += 1
	_check(guards == 0, "killed stair guards stay dead")
	_check(m.chest_at(Vector2i(19, 3)).opened, "opened chest stays open")
	_check(m.is_explored(Vector2i(5, 5)) and not m.is_seen(Vector2i(5, 5)), "fog: guard room remembered (dimmed) on return")
	_check(m.monsters.size() == 8, "the other monsters are still there (%d)" % m.monsters.size())

	# --- potions: drink from the inventory screen (exploring), the Item action (combat) ---
	var inv2 := m.hud.inventory_screen
	var f2 := m.party[0]
	var potions := m.inventory.count("potion_healing")
	_check(inv2.equip(f2, "potion_healing") and f2.hp >= 24 and f2.hp <= 30, "clicking a potion: the fighter drinks it (HP %d)" % f2.hp)
	_check(m.inventory.count("potion_healing") == potions - 1, "the potion is gone from the bag")
	var rogue := m.party[1]
	rogue.hp = rogue.stats.max_hp
	_check(not inv2.drink(rogue, "potion_healing") and m.inventory.count("potion_healing") == potions - 1, "an unhurt hero doesn't waste a potion")
	var cm := m.combat
	var cleric := m.party[2]
	var mage := m.party[3]
	f2.hp = f2.stats.max_hp
	cleric.hp = cleric.stats.max_hp
	cleric.place_at(Vector2i(28, 21))
	mage.place_at(Vector2i(29, 21))
	f2.place_at(Vector2i(31, 21))
	mage.hp = 0
	cm.current = cleric
	cm.action_used = false
	cm.attacks_left = cleric.stats.attacks_per_action()
	var items := cm.menu_items(cleric).filter(func(x): return x.item.kind == ItemData.Kind.POTION)
	_check(items.size() == 1 and items[0].ok and items[0].count == potions - 1, "Item menu offers the potions")
	cm.begin_item("potion_healing")
	var pt := cm.valid_targets(cleric, cm.targeting)
	_check(pt.size() == 1 and pt[0] == mage, "potion targets: only the downed mage next to the cleric")
	_check(cm.pick_target(mage), "cleric gives the mage the potion")
	for i in 300:
		if not cm.moving:
			break
		await process_frame
	_check(mage.is_alive() and mage.hp <= 12, "the mage is back up (HP %d)" % mage.hp)
	_check(m.inventory.count("potion_healing") == potions - 2 and cm.action_used, "potion used up, action spent")
	_check(not cm.menu_items(cleric).any(func(x): return x.ok), "no second potion this turn (action used)")

	# --- scrolls: read Cure Wounds from the bag (exploring), the Item menu, Lightning Bolt ---
	cm.current = null
	f2.hp = 10
	_check(m.inventory.count("scroll_cure_wounds") == 1, "the Cure Wounds scroll from the storeroom")
	_check(inv2.equip(f2, "scroll_cure_wounds") and f2.hp > 10 and not m.inventory.has("scroll_cure_wounds"), "clicking the scroll: the cleric heals the fighter (HP %d), the scroll is gone" % f2.hp)
	_check(not inv2.equip(f2, "scroll_cure_wounds"), "none left to read")
	m.inventory.add("scroll_fireball")
	_check(not inv2.equip(f2, "scroll_fireball") and m.inventory.has("scroll_fireball"), "Fireball scroll waits for a fight")
	m.inventory.add("scroll_lightning_bolt")
	var fighter_items := cm.menu_items(f2).filter(func(x): return x.item.kind == ItemData.Kind.SCROLL)
	_check(fighter_items.size() == 2 and not fighter_items[0].ok and fighter_items[0].why.contains("spell list"), "the fighter can't read scrolls (%s)" % (fighter_items[0].why if fighter_items else "?"))
	cm.current = mage
	cm.action_used = false
	cm.attacks_left = mage.stats.attacks_per_action()
	var mage_items := cm.menu_items(mage).filter(func(x): return x.item.id == "scroll_lightning_bolt")
	_check(mage_items.size() == 1 and mage_items[0].ok, "the mage can read Lightning Bolt")
	# Lightning Bolt along the stair room: through two skeletons, stopped by the far wall.
	var sk: Array[Actor] = []
	for mo in m.monsters:
		if mo.is_alive() and mo.stats.id == "skeleton" and sk.size() < 2:
			sk.append(mo)
	mage.place_at(Vector2i(27, 19))
	sk[0].place_at(Vector2i(30, 19))
	sk[1].place_at(Vector2i(32, 19))
	var lbp := CombatManager.scroll_power(ItemData.get_item("scroll_lightning_bolt"))
	var line := cm.shape_cells(mage, lbp, Vector2i(33, 19))
	_check(line.size() >= 6 and Vector2i(30, 19) in line and Vector2i(32, 19) in line, "line covers both skeletons (%d cells)" % line.size())
	_check(line.all(func(c): return m.has_floor(c) and not m.blocks_sight(c)), "the line stops at the wall")
	var hp0: Array[int] = [sk[0].hp, sk[1].hp]
	var slots0: Array = mage.slots_left.duplicate()
	cm.dice_mode = CombatManager.DiceMode.OFF
	cm.order = [mage, sk[0], sk[1]]
	var none: Array[Actor] = []
	await cm._cast(mage, lbp, 0, none, Vector2i(33, 19))
	_check(sk[0].hp < hp0[0] and sk[1].hp < hp0[1], "both skeletons hit (%d -> %d, %d -> %d)" % [hp0[0], sk[0].hp, hp0[1], sk[1].hp])
	_check(not m.inventory.has("scroll_lightning_bolt") and mage.slots_left == slots0 and cm.action_used, "scroll used up, no slot spent, action spent")
	cm.order.clear()
	cm.current = null

	# --- magic items: Ring of Free Action stops the spider's Web; the AI knows it ---
	m.inventory.add("ring_free_action")
	_check(rogue.equip_from(m.inventory, "ring_free_action") == "" and "restrained" in rogue.stats.condition_immunities,
			"the rogue puts on the Ring of Free Action")
	var spider: Actor = null
	for mo in m.monsters:
		if mo.is_alive() and mo.stats.id == "giant_spider":
			spider = mo
			break
	var web: SpellData = null
	if spider:
		for p in spider.stats.powers:
			if p.condition == "restrained":
				web = p
	_check(spider != null and web != null, "a giant spider with Web")
	if spider and web:
		spider.place_at(Vector2i(28, 18))
		rogue.place_at(Vector2i(30, 18))
		f2.place_at(Vector2i(30, 20))
		_check(cm._power_value(spider, web, f2, spider.cell) > 0.0, "the spider would web the fighter")
		_check(cm._power_value(spider, web, rogue, spider.cell) == 0.0, "but not the rogue with the ring")
		_check(cm._shrugs_off(rogue, "restrained") and not cm._shrugs_off(f2, "restrained"), "only the ring-wearer shrugs off restrained")
	rogue.unequip_to(m.inventory, "ring1")
	_check("restrained" not in rogue.stats.condition_immunities and m.inventory.has("ring_free_action"), "ring off: no immunity, back in the bag")
	print("test_dungeon: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILURES", fails])
	quit(1 if fails else 0)
