extends SceneTree
## Monster behaviour test (playtest batch): doors, traps, smart vs dim targeting, the hidden Rogue,
## monsters that spawned inside walls / boxed in by props. Prints PASS/FAIL.
##   HERRA_AUTO_REACT=1 tools/run_godot.sh -t 120 --path . -s res://tools/godot/test_monster_ai.gd
## Uses the Goblin Warrens (goblins: smart, open doors; wolves: dim, can't) and every map for the
## spawn check. Things are found by what they are, not by cell, so map rebuilds don't break it.

const MAPS := "res://modules/wraith_below/maps/"
var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	_run()


func _open(path: String) -> DungeonMap:
	if current_scene:
		var old := current_scene
		root.remove_child(old)
		old.free()
	MapState.reset()
	PartyState.reset()
	var m: DungeonMap = (load(path) as PackedScene).instantiate()
	root.add_child(m)
	current_scene = m
	await _frames(5)
	m.combat.set_process(false)
	return m


func _monster(m: DungeonMap, id: String) -> Monster:
	for x in m.monsters:
		if x.monster_id == id and x.is_alive():
			return x
	return null


## Free walkable cells around `at` (nobody on them), nearest first.
func _free_near(m: DungeonMap, at: Vector2i, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var c := at + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == r and m.terrain_walkable(c) and m.occupant(c) == null and not c in out \
						and m.mech.trap_at(c) == null:
					out.append(c)
					if out.size() >= n:
						return out
	return out


## Move every hero far away (to the party start area), so only the ones a check places matter.
func _park_party(m: DungeonMap) -> void:
	var start: Vector2i = Vector2i.ZERO
	for p in m.entities.get_children():
		if p is PartyStart:
			start = p.get_cell()
	var spots := _free_near(m, start, 6)
	for i in m.party.size():
		m.party[i].place_at(spots[i])
		m.party[i].remove_condition("hidden")


func _run() -> void:
	var m := await _open(MAPS + "dungeon_3.tscn")
	var goblin := _monster(m, "goblin")
	var wolf := _monster(m, "wolf")
	_check(goblin != null and wolf != null, "the Warrens have goblins and wolves")
	_check(goblin.smart() and goblin.opens_doors(), "a goblin (INT 10) fights smart and opens doors")
	_check(not wolf.smart() and not wolf.opens_doors(), "a wolf (INT 3) is dim and can't open doors")

	# --- doors -------------------------------------------------------------------------------------
	var door: Door = null
	for d in m.entities.get_children():
		if d is Door and d.style == Door.Style.WOOD and not d.is_open and not d.locked:
			var s: Array[Vector2i] = d.sides()
			if m.terrain_walkable(s[0]) and m.terrain_walkable(s[1]) and m.occupant(s[0]) == null and m.occupant(s[1]) == null:
				door = d
				break
	_check(door != null, "found a closed, unlocked wooden door")
	var a: Vector2i = door.sides()[0]
	var b: Vector2i = door.sides()[1]
	var g_home := goblin.cell
	goblin.place_at(a)
	var reach := m.combat_reach(a, 2, goblin)
	_check(reach.has(b), "a goblin's path goes through the closed door")
	door.locked = true
	reach = m.combat_reach(a, 2, goblin)
	_check(not reach.has(b), "... but not through a locked one")
	door.locked = false
	var w_home := wolf.cell
	goblin.place_at(g_home)
	wolf.place_at(a)
	reach = m.combat_reach(a, 2, wolf)
	_check(not reach.has(b), "a wolf can't get through a closed door")
	wolf.place_at(w_home)
	goblin.place_at(a)
	_park_party(m)
	m.combat.in_combat = true
	m.combat.current = goblin
	m.combat.move_left = 6
	var path: Array[Vector2i] = [door.get_cell(), b]
	await m.combat.move_along(goblin, path)
	_check(door.is_open and goblin.cell == b, "moving, the goblin throws the door open and walks through")
	m.combat.in_combat = false
	m.combat.order.clear()

	# --- traps -------------------------------------------------------------------------------------
	var trap: Trap = null
	for t in m.mech.traps:
		if t.armed() and t.trap_type != Trap.TrapType.ALARM and m.occupant(t.get_cell()) == null \
				and not _free_near(m, t.get_cell(), 1).is_empty():
			trap = t
			break
	_check(trap != null, "found an armed trap")
	var next_to: Vector2i = _free_near(m, trap.get_cell(), 1)[0]
	goblin.place_at(next_to)
	_check(not m.combat_reach(next_to, 1, goblin).has(trap.get_cell()), "a smart goblin steps round its trap")
	goblin.place_at(g_home)
	wolf.place_at(next_to)
	_check(m.combat_reach(next_to, 1, wolf).has(trap.get_cell()), "a dim wolf would walk onto it")
	var hp0 := wolf.hp
	m.combat.in_combat = true
	m.combat.current = wolf
	m.combat.move_left = 6
	var onto: Array[Vector2i] = [trap.get_cell()]
	await m.combat.move_along(wolf, onto)
	_check(trap.sprung, "the wolf sets the trap off (%s, HP %d -> %d)" % [trap.trap_name(), hp0, wolf.hp])
	m.combat.in_combat = false
	m.combat.order.clear()
	wolf.hp = wolf.stats.max_hp

	# --- dim vs smart targeting ----------------------------------------------------------------------
	_park_party(m)
	var fighter: Hero = m.party[0]
	var mage: Hero = m.party[3]
	var around := _free_near(m, wolf.cell, 12)
	fighter.place_at(around[0])                         # right next to it
	var far_spot := around[0]
	for c in around:
		if DungeonMap.grid_distance(c, wolf.cell) == 3:
			far_spot = c
	mage.place_at(far_spot)                             # three squares off, nearly dead
	mage.hp = 1
	m.update_fog()
	m.combat.order.assign([wolf] + m.party)
	m.combat.move_left = wolf.stats.speed_cells()
	var plan := m.combat.plan_monster_turn(wolf)
	_check(plan.target == fighter, "a dim wolf bites the hero next to it, not the dying Mage (%s)" % (plan.target.display_name() if plan.target else "nobody"))
	wolf.last_hurt_by = mage
	wolf.remove_meta("ai_target")
	plan = m.combat.plan_monster_turn(wolf)
	_check(plan.target == mage, "... unless the Mage just hurt it: then it turns on her")
	wolf.last_hurt_by = null
	wolf.remove_meta("ai_target")
	# the same two heroes round a goblin: it goes for the kill
	_park_party(m)
	around = _free_near(m, goblin.cell, 12)
	fighter.place_at(around[0])
	far_spot = around[0]
	for c in around:
		if DungeonMap.grid_distance(c, goblin.cell) == 2:
			far_spot = c
	mage.place_at(far_spot)
	m.update_fog()
	m.combat.order.assign([goblin] + m.party)
	m.combat.move_left = goblin.stats.speed_cells()
	var hits_mage := 0
	for i in 10:
		if m.combat.plan_monster_turn(goblin).target == mage:
			hits_mage += 1
	_check(hits_mage >= 8, "a smart goblin finishes off the dying Mage (%d / 10)" % hits_mage)
	mage.hp = mage.stats.max_hp

	# --- the hidden Rogue ---------------------------------------------------------------------------
	_park_party(m)
	var rogue: Hero = m.party[1]
	rogue.place_at(_free_near(m, goblin.cell, 1)[0])
	rogue.add_condition("hidden", -1, rogue, null)
	rogue.set_meta("stealth_total", 30)
	m.update_fog()
	m.combat.order.assign([goblin] + m.party)
	m.combat.move_left = goblin.stats.speed_cells()
	plan = m.combat.plan_monster_turn(goblin)
	_check(plan.target != rogue, "a goblin can't pick the hidden Rogue next to it (%s)" % (plan.target.display_name() if plan.target else "nobody"))
	_check(Condition.attack_advantage(goblin, rogue, true, 1) == -1, "attacks against a hidden hero have disadvantage")
	m.combat.move_left = 0
	plan = m.combat.plan_monster_turn(goblin)
	_check(plan.target == null and plan.search, "with nobody else in reach, the goblin searches")
	await m.combat._monster_search(goblin)
	_check(rogue.has_condition("hidden"), "... and can't beat Stealth 30")
	rogue.set_meta("stealth_total", 1)
	await m.combat._monster_search(goblin)
	_check(not rogue.has_condition("hidden"), "... but finds a Rogue who rolled 1")

	# --- monsters stuck in walls / behind props ------------------------------------------------------
	for path_ in ["res://modules/wraith_below/maps/surface.tscn", MAPS + "dungeon_5.tscn",
			"res://modules/frost_spire/maps/frostfell.tscn"]:
		m = await _open(path_)
		var stuck := 0
		for x in m.monsters:
			if not m.terrain_walkable(x.cell) or not m._has_way_out(x.cell):
				stuck += 1
		_check(stuck == 0, "%s: every monster can move (%d stuck)" % [path_.get_file(), stuck])

	print("test_monster_ai: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILURES", fails])
	quit()
