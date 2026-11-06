extends SceneTree
## Dungeon mechanics test (doors, locks, stairs, state carried between floors, items). Prints PASS/FAIL.
## Needs a window (no --headless needed for logic, but scenes use lights), e.g.:
##   HERRA_AUTO_REACT=1 Godot_console --path . -s res://tools/godot/test_dungeon.gd
## Uses modules/wraith_below/maps/dungeon_1.tscn and dungeon_2.tscn (modules/wraith_below/build_maps.gd). Things are
## found by what they are (the locked crypt door, the DC 12 chest, the stairs down), not by cell,
## so the test survives the maps being rebuilt.

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


func _all(m: DungeonMap, type: Variant) -> Array:
	return m.entities.get_children().filter(func(n): return is_instance_of(n, type))


func _door_with_key(m: DungeonMap, key: String) -> Door:
	for d: Door in _all(m, Door):
		if d.key_id == key:
			return d
	return null


func _stairs(m: DungeonMap, up: bool) -> Stairs:
	for s: Stairs in _all(m, Stairs):
		if s.up == up:
			return s
	return null


func _entry_cell(m: DungeonMap, id: String) -> Vector2i:
	for p: PartyStart in _all(m, PartyStart):
		if p.entry_id == id:
			return p.get_cell()
	return Vector2i(-999, -999)


## The door's two side cells: [the one nearer `from`, the far one].
func _near_far(door: Door, from: Vector2i) -> Array:
	var s := door.sides()
	if DungeonMap.grid_distance(s[0], from) <= DungeonMap.grid_distance(s[1], from):
		return [s[0], s[1]]
	return [s[1], s[0]]


func _place_party(m: DungeonMap, at: Vector2i) -> void:
	var cells := [at]
	for d in DungeonMap.DIRS8:
		if cells.size() < m.party.size() and m.terrain_walkable(at + d) and m.actor_at(at + d) == null:
			cells.append(at + d)
	for i in m.party.size():
		m.party[i].place_at(cells[mini(i, cells.size() - 1)])
	m.update_fog()
	m.refresh_navigation()


func _run() -> void:
	var first: DungeonMap = (load("res://modules/wraith_below/maps/dungeon_1.tscn") as PackedScene).instantiate()
	root.add_child(first)
	current_scene = first
	await _frames(5)
	var m := _map()
	m.combat.set_process(false)            # no fights during the test
	_check(m.party.size() == 4, "party spawned on floor 1")
	_check(m.party[0].level == 2 and m.party[0].stats.max_hp == 20, "a fresh party on floor 1 is level 2 (map start_level) (Lv %d, %d HP)" % [m.party[0].level, m.party[0].stats.max_hp])
	var start := m.party[0].cell

	# --- an ordinary door: closed blocks the path, opening it clears it ---
	var door: Door = null
	for d: Door in _all(m, Door):
		if not d.locked and (door == null or DungeonMap.grid_distance(d.get_cell(), start) < DungeonMap.grid_distance(door.get_cell(), start)):
			door = d
	_check(door != null and not door.is_open, "the nearest door starts closed")
	var door_cell := door.get_cell()
	var nf := _near_far(door, start)
	_place_party(m, nf[0])
	_check(not m.is_explored(nf[1]), "fog: the far side isn't explored yet")
	_check(m.find_path(nf[0], door.get_cell()).is_empty(), "closed door blocks the path")
	_check(not m.has_line_of_sight(nf[0], nf[1]), "closed door blocks sight")
	m.try_open_door(door, m.party)
	_check(door.is_open, "door opens")
	_check(m.is_explored(nf[1]) and m.is_seen(nf[1]), "fog: opening the door reveals the far side")
	_check(not m.find_path(nf[0], nf[1]).is_empty(), "open door lets the party through")

	# --- one creature per square: nobody moves through or onto anyone (combat movement) ---
	var o_fighter := m.party[0]
	var o_rogue := m.party[1]
	var o_cleric := m.party[2]
	var home_cells: Array[Vector2i] = []
	for h in m.party:
		home_cells.append(h.cell)
	o_fighter.place_at(nf[0])
	o_rogue.place_at(door_cell)                 # standing in the doorway (a 1-wide gap)
	o_cleric.place_at(nf[1] + (nf[1] - door_cell))
	var o_reach := m.combat_reach(nf[0], 3, o_fighter)
	_check(o_reach.has(nf[1]) == false, "an ally in the doorway blocks the way through (can't pass allies)")
	_check(not o_reach.has(door_cell), "can't end a move on an ally's square")
	o_rogue.place_at(Vector2i(-500, -500))     # well out of the way
	o_reach = m.combat_reach(nf[0], 3, o_fighter)
	_check(o_reach.has(door_cell) and o_reach.has(nf[1]), "with the doorway clear the fighter gets through")
	_check(not o_reach.has(o_cleric.cell), "... but not onto the cleric's square beyond it")
	o_cleric.hp = 0                             # downed, making death saves: still takes up the square
	o_reach = m.combat_reach(nf[0], 3, o_fighter)
	_check(not o_reach.has(o_cleric.cell), "a downed hero still takes up the square")
	o_cleric.dead = true
	o_reach = m.combat_reach(nf[0], 3, o_fighter)
	_check(o_reach.has(o_cleric.cell), "the dead don't take up a square")
	o_cleric.dead = false
	o_cleric.hp = o_cleric.stats.max_hp
	var o_mon: Monster = null
	for mo in m.monsters:
		if mo.is_alive():
			o_mon = mo
			break
	if o_mon:
		var mon_home := o_mon.cell
		o_mon.place_at(door_cell)
		o_reach = m.combat_reach(nf[0], 3, o_fighter)
		_check(not o_reach.has(door_cell) and not o_reach.has(nf[1]), "a monster in the doorway blocks the hero")
		var mreach := m.combat_reach(door_cell, 3, o_mon)
		_check(not mreach.has(nf[0]) and not mreach.has(o_cleric.cell), "the monster can't move onto a hero's square")
		o_mon.place_at(mon_home)
	for i in m.party.size():
		m.party[i].place_at(home_cells[i])
	m.update_fog()

	# --- the locked crypt: the Rogue picks it (may take a few tries) ---
	var crypt := _door_with_key(m, "crypt")
	_check(crypt != null and crypt.locked and crypt.lock_dc == 13, "crypt door is locked (DC 13, or the Iron Key)")
	var tries := 0
	while not crypt.is_open and tries < 30:
		m.try_open_door(crypt, m.party)
		tries += 1
	_check(crypt.is_open and not crypt.locked, "crypt lock picked after %d tries" % tries)

	# --- the party clicks a door: walks to its near side, then opens it ---
	var other: Door = null
	for d: Door in _all(m, Door):
		if not d.is_open and not d.locked:
			other = d
			break
	var s0 := other.sides()[0]
	var back := s0 + (s0 - other.get_cell())
	_place_party(m, back if m.terrain_walkable(back) else s0)
	var path := m.controller.door_path(other)
	_check(not path.is_empty() and path[-1] in other.sides(), "door_path ends beside the door")

	# --- the storeroom chest: locked (DC 12), walk up, pick it, loot goes in the bag ---
	var chest: Chest = null
	for c: Chest in _all(m, Chest):
		if c.locked and c.lock_dc == 12:
			chest = c
	_check(chest != null and chest.locked and not chest.opened, "storeroom chest is closed and locked")
	var chest_cell := chest.get_cell()
	var near_chest: Vector2i = chest.sides()[0]
	for sc in chest.sides():
		if m.terrain_walkable(sc):
			near_chest = sc
	_place_party(m, near_chest + Vector2i(0, 1) if m.terrain_walkable(near_chest + Vector2i(0, 1)) else near_chest)
	var cpath := m.controller.approach_path(chest.sides())
	_check(cpath.is_empty() or cpath[-1] in chest.sides(), "approach_path ends beside the chest")
	_place_party(m, near_chest)
	_check(m.closed_chest_under(chest.position + Vector2(0, -6)) == chest, "clicking the chest sprite finds it")
	var ctries := 0
	while not chest.opened and ctries < 30:
		m.try_open_chest(chest, m.party)
		ctries += 1
	_check(chest.opened and not chest.locked, "chest lock picked after %d tries" % ctries)
	_check(chest.get_node("Sprite").texture == Chest.OPEN_TEX, "open chest sprite")
	_check(m.inventory.gold == 40 and m.inventory.count("potion_healing") == 5, "chest loot in the bag (gold %d, potions %d)" % [m.inventory.gold, m.inventory.count("potion_healing")])
	_check(m.inventory.has("crypt_key") and m.inventory.has("scroll_cure_wounds") and m.inventory.has("scroll_burning_hands"), "the storeroom chest held the Iron Key and scrolls")
	_check(m.hud.loot_open(), "loot box shown")
	m.try_open_chest(chest, m.party)
	_check(m.inventory.gold == 40, "an opened chest gives nothing twice")
	_check(m.closed_chest_under(chest.position) == null, "opened chest no longer clickable")

	# --- damage a hero, kill the stair guards, take the stairs down ---
	var fighter := m.party[0]
	fighter.hp = 15
	m.party[3].slots_left[0] = 1
	_check(fighter.stats.armor_class == 19 and fighter.stats.attacks[0].name == "Longsword", "fighter fights with the kit (AC %d: chain, shield, Defense)" % fighter.stats.armor_class)
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
	var down := _stairs(m, false)
	_check(down != null and not down.up, "stairs down on floor 1")
	var total_monsters := m.monsters.size()
	var killed := 0
	for mo in m.monsters:
		if DungeonMap.grid_distance(mo.cell, down.get_cell()) <= 9:
			mo.hp = 0
			killed += 1
	_check(killed >= 2, "the stair guards removed (%d)" % killed)
	var below := _entry_cell(m, "from_below")
	_place_party(m, below)
	var old_down := m
	m.take_stairs(down)
	await _until_scene_changes(old_down)
	m = _map()
	_check(m.scene_file_path.ends_with("dungeon_2.tscn"), "arrived on floor 2")
	m.combat.set_process(false)
	_check(m.party[0].cell == _entry_cell(m, "from_above"), "party at the from_above entry (%s)" % m.party[0].cell)
	_check(m.party[0].hp == 15, "fighter's HP carried over (%d)" % m.party[0].hp)
	_check(m.party[0].level == 2, "the party's level carried over (not floor 2's start level)")
	_check(m.party[3].slots_left[0] == 1, "mage's spent slots carried over")
	_check(m.inventory.gold == 65 and m.inventory.count("longsword") == 2 and m.inventory.count("potion_healing") == 5, "bag carried over")
	_check(m.party[0].stats.attacks[0].name == "Warhammer" and m.party[0].stats.armor_class == 19, "equipment carried over")
	_check(m.inventory.has("crypt_key"), "the Iron Key came along")

	# --- keys: the lair door opens only with the Bone Key ---
	var lair := _door_with_key(m, "lair")
	_check(lair != null and lair.locked and lair.lock_dc == 0, "lair door: key only")
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
	_check(_stairs(m, false) != null and _stairs(m, false).target_map.ends_with("dungeon_3.tscn"), "floor 2 has stairs on down to floor 3")

	# --- back up: floor 1 remembers its doors and dead monsters ---
	var up := _stairs(m, true)
	_check(up != null and up.up, "stairs up on floor 2")
	var old_up := m
	m.take_stairs(up)
	await _until_scene_changes(old_up)
	m = _map()
	_check(m.scene_file_path.ends_with("dungeon_1.tscn"), "back on floor 1")
	m.combat.set_process(false)
	_check(m.party[0].cell == _entry_cell(m, "from_below"), "party at the from_below entry (%s)" % m.party[0].cell)
	var crypt2 := _door_with_key(m, "crypt")
	var first_door: Door = m.door_at(door_cell)
	_check(first_door.is_open and crypt2.is_open, "opened doors stay open")
	var guards := 0
	for mo in m.monsters:
		if DungeonMap.grid_distance(mo.cell, _stairs(m, false).get_cell()) <= 9:
			guards += 1
	_check(guards == 0, "killed stair guards stay dead")
	_check(m.chest_at(chest_cell).opened, "opened chest stays open")
	_check(m.is_explored(nf[1]) and not m.is_seen(nf[1]), "fog: the first room remembered (dimmed) on return")
	_check(m.monsters.size() == total_monsters - killed, "the other monsters are still there (%d)" % m.monsters.size())

	# --- potions: drink from the inventory screen (exploring), the Item action (combat) ---
	var inv2 := m.hud.inventory_screen
	var f2 := m.party[0]
	var potions := m.inventory.count("potion_healing")
	f2.hp = 5
	_check(inv2.equip(f2, "potion_healing") and f2.hp >= 9 and f2.hp <= 15, "clicking a potion: the fighter drinks it (HP %d)" % f2.hp)
	_check(m.inventory.count("potion_healing") == potions - 1, "the potion is gone from the bag")
	var rogue := m.party[1]
	rogue.hp = rogue.stats.max_hp
	_check(not inv2.drink(rogue, "potion_healing") and m.inventory.count("potion_healing") == potions - 1, "an unhurt hero doesn't waste a potion")
	var cm := m.combat
	var cleric := m.party[2]
	var mage := m.party[3]
	f2.hp = f2.stats.max_hp
	cleric.hp = cleric.stats.max_hp
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
	f2.hp = 6
	_check(m.inventory.count("scroll_cure_wounds") == 1, "the Cure Wounds scroll from the storeroom")
	_check(inv2.equip(f2, "scroll_cure_wounds") and f2.hp > 6 and not m.inventory.has("scroll_cure_wounds"), "clicking the scroll: the cleric heals the fighter (HP %d), the scroll is gone" % f2.hp)
	_check(not inv2.equip(f2, "scroll_cure_wounds"), "none left to read")
	m.inventory.add("scroll_fireball")
	_check(not inv2.equip(f2, "scroll_fireball") and m.inventory.has("scroll_fireball"), "Fireball scroll waits for a fight")
	m.inventory.add("scroll_lightning_bolt")
	var fighter_items := cm.menu_items(f2).filter(func(x): return x.item.kind == ItemData.Kind.SCROLL)
	_check(fighter_items.size() >= 2 and not fighter_items[0].ok and fighter_items[0].why.contains("spell list"), "the fighter can't read scrolls (%s)" % (fighter_items[0].why if fighter_items else "?"))
	cm.current = mage
	cm.action_used = false
	cm.attacks_left = mage.stats.attacks_per_action()
	var mage_items := cm.menu_items(mage).filter(func(x): return x.item.id == "scroll_lightning_bolt")
	_check(mage_items.size() == 1 and mage_items[0].ok, "the mage can read Lightning Bolt (beyond level 2: with a check)")
	# Lightning Bolt along a straight run of floor: through two skeletons, stopped by the wall.
	var sk: Array[Actor] = []
	for mo in m.monsters:
		if mo.is_alive() and mo.stats.id == "skeleton" and sk.size() < 2:
			sk.append(mo)
	var origin := Vector2i.ZERO
	var dir := Vector2i.ZERO
	for c: Vector2i in m.floor_layer.get_used_cells():
		if not m.terrain_walkable(c) or m.actor_at(c) != null:
			continue
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var run := 0
			while m.terrain_walkable(c + d * (run + 1)) and m.actor_at(c + d * (run + 1)) == null and m.door_at(c + d * (run + 1)) == null:
				run += 1
			if run >= 5 and run <= 9 and m.blocks_sight(c + d * (run + 1)):
				origin = c
				dir = d
				break
		if dir != Vector2i.ZERO:
			break
	_check(dir != Vector2i.ZERO and sk.size() == 2, "a straight run of floor and two skeletons for the bolt")
	mage.place_at(origin)
	sk[0].place_at(origin + dir * 2)
	sk[1].place_at(origin + dir * 3)
	var lbp := CombatManager.scroll_power(ItemData.get_item("scroll_lightning_bolt"))
	var line := cm.shape_cells(mage, lbp, origin + dir * 12)
	_check(line.size() >= 4 and sk[0].cell in line and sk[1].cell in line, "line covers both skeletons (%d cells)" % line.size())
	_check(line.all(func(c): return m.has_floor(c) and not m.blocks_sight(c)), "the line stops at the wall")
	var hp0: Array[int] = [sk[0].hp, sk[1].hp]
	var slots0: Array = mage.slots_left.duplicate()
	cm.dice_mode = CombatManager.DiceMode.OFF
	cm.order = [mage, sk[0], sk[1]]
	var none: Array[Actor] = []
	await cm._cast(mage, lbp, 0, none, origin + dir * 12)
	_check((sk[0].hp < hp0[0] and sk[1].hp < hp0[1]) or not m.inventory.has("scroll_lightning_bolt"), "both skeletons hit, or the scroll crumbled (%d -> %d, %d -> %d)" % [hp0[0], sk[0].hp, hp0[1], sk[1].hp])
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
		spider.place_at(origin)
		rogue.place_at(origin + dir * 2)
		f2.place_at(origin + dir * 3)
		_check(cm._power_value(spider, web, f2, spider.cell) > 0.0, "the spider would web the fighter")
		_check(cm._power_value(spider, web, rogue, spider.cell) == 0.0, "but not the rogue with the ring")
		_check(cm._shrugs_off(rogue, "restrained") and not cm._shrugs_off(f2, "restrained"), "only the ring-wearer shrugs off restrained")
	rogue.unequip_to(m.inventory, "ring1")
	_check("restrained" not in rogue.stats.condition_immunities and m.inventory.has("ring_free_action"), "ring off: no immunity, back in the bag")
	print("test_dungeon: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILURES", fails])
	quit(1 if fails else 0)
