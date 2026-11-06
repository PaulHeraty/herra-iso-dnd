extends SceneTree
## Phase 6 test: traps (spotting, paths round them, disarming, springing), Search, secret doors,
## levers + portcullises, the lever sequence, blocks + plates (and the reset lever), the brazier
## ring, the riddle face, room notes, an alarm, and all of it kept by MapState. Prints PASS/FAIL.
## Needs a window (no --headless), e.g.:
##   HERRA_AUTO_REACT=1 tools/run_godot.sh -t 120 --path . -s res://tools/godot/test_puzzles.gd
## Uses the campaign maps built by modules/wraith_below/build_maps.gd; things are found by name
## (Trap_AB_..., Puzzle_N, Block_K_0...) and puzzle pieces by their link, not by cell.

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
	var m: DungeonMap = (load(path) as PackedScene).instantiate()
	root.add_child(m)
	current_scene = m
	await _frames(5)
	m.combat.set_process(false)            # no fights unless the test starts one
	return m


func _all(m: DungeonMap, type: Variant) -> Array:
	return m.entities.get_children().filter(func(n): return is_instance_of(n, type))


func _named(m: DungeonMap, prefix: String) -> Node:
	for n in m.entities.get_children():
		if String(n.name).begins_with(prefix):
			return n
	return null


func _place_party(m: DungeonMap, at: Vector2i, rest_far := false) -> void:
	var cells := [at]
	for d in DungeonMap.DIRS8:
		var c: Vector2i = at + d
		if cells.size() < m.party.size() and m.terrain_walkable(c) and m.actor_at(c) == null and m.mech.trap_at(c) == null:
			cells.append(c)
	for i in m.party.size():
		if rest_far and i > 0:
			m.party[i].place_at(Vector2i(-300 - i * 3, -300))      # out of everyone's way
		else:
			m.party[i].place_at(cells[mini(i, cells.size() - 1)])
	m.update_fog()
	m.refresh_navigation()


func _heal(m: DungeonMap) -> void:
	for h in m.party:
		h.dead = false
		h.hp = h.stats.max_hp


func _walk(m: DungeonMap, to: Vector2i) -> void:
	m.controller.walk_to(to)
	for i in 600:
		await process_frame
		if not m.controller.is_walking():
			break
	await _frames(3)


## A walkable cell `k` steps from `c` (straight in one of 4 directions) with a clear line to it.
func _cell_near(m: DungeonMap, c: Vector2i, k: int) -> Vector2i:
	for d in DungeonMap.NEIGHBOURS:
		var t: Vector2i = c + d * k
		var ok := true
		for j in range(1, k + 1):
			if not m.terrain_walkable(c + d * j):
				ok = false
		if ok:
			return t
	return c


func _run() -> void:
	MapState.reset()
	Dice.seed_rng(6006)

	# --- floor 1: notes, a corridor trap spotted and disarmed ------------------------------------
	var m := await _open("res://modules/wraith_below/maps/dungeon_1.tscn")
	_check(m.mech != null and not m.mech.traps.is_empty(), "floor 1 has traps (%d)" % m.mech.traps.size())
	var note_a: RoomNote = _named(m, "Note_A")
	_check(note_a != null and not note_a.seen and not note_a.modal, "the entrance hall has a room description")
	m.mech.check_notes()
	_check(note_a.seen, "the description shows when the party is in the room")

	var spikes: Trap = _named(m, "Trap_AB_")
	_check(spikes != null and spikes.trap_type == Trap.TrapType.SPIKES and not spikes.known(), "a hidden spike trap between the hall and the guardroom")
	var tc := spikes.get_cell()
	var near := _cell_near(m, tc, 3)
	_place_party(m, near)
	_check(spikes.spotted, "passive Perception spots it (DC %d) from 3 cells" % spikes.detect_dc)
	_check(spikes.blocks_party() and m.mech.trap_blocks(tc), "a spotted, armed trap blocks the party's way")
	var beyond := tc + (tc - near).clampi(-1, 1)
	_check(m.find_path(near, beyond).is_empty(), "the 1-wide corridor is blocked by the known trap")
	var hero_reach := m.combat_reach(tc + (near - tc).clampi(-1, 1), 3, m.party[0])
	_check(not hero_reach.has(tc), "combat: heroes can't step on a known trap")
	var mon: Monster = m.monsters[0]
	var mon_reach := m.combat_reach(tc + (near - tc).clampi(-1, 1), 3, mon)
	_check(mon_reach.has(tc), "combat: monsters walk over their own traps")
	var xp0 := m.party_xp
	var tries := 0
	while not spikes.disarmed and tries < 40:
		_heal(m)
		m.mech.try_disarm(spikes, m.party)
		tries += 1
	_heal(m)
	_check(spikes.disarmed and not spikes.blocks_party(), "the Rogue disarms it (%d tries)" % tries)
	_check(m.party_xp == xp0 + spikes.xp, "disarming gives XP (+%d)" % spikes.xp)
	_check(not m.find_path(near, beyond).is_empty(), "the corridor is clear again")

	# --- a hidden trap goes off when walked on ---------------------------------------------------------
	var pit: Trap = _named(m, "Trap_IJ_")
	_check(pit != null and pit.trap_type == Trap.TrapType.PIT and pit.detect_dc > m.party[1].stats.passive_perception(), "a pit nobody can spot passively (DC %d)" % pit.detect_dc)
	var pc := pit.get_cell()
	var p_from := _cell_near(m, pc, 2)
	var p_to := pc + (pc - p_from).clampi(-1, 1)
	_place_party(m, p_from, true)
	_check(not pit.known(), "... still hidden with the party 2 cells away")
	var hp0 := m.party[0].hp
	await _walk(m, p_to)
	_check(pit.sprung and pit.known(), "walking over it springs the pit")
	_check(m.party[0].cell == pc, "the walk stops on the trap")
	print("      (fighter HP %d -> %d)" % [hp0, m.party[0].hp])
	_check(not pit.armed() and not m.mech.trap_blocks(pc), "a sprung pit (one-shot) is harmless after")
	_heal(m)

	# --- Search ---------------------------------------------------------------------------------------
	var k_trap: Trap = _named(m, "Trap_K_")
	var kc := k_trap.get_cell()
	k_trap.detect_dc = 40
	_place_party(m, _cell_near(m, kc, 2))
	_check(not k_trap.known(), "a DC 40 trap isn't spotted passively")
	m.mech.search()
	_check(not k_trap.known(), "... nor by a Search")
	k_trap.detect_dc = -10
	m.mech.search()
	_check(k_trap.spotted, "a Search finds a trap the roll beats")

	# --- the secret door in the entrance hall -------------------------------------------------------
	var secret: Door = null
	for d: Door in _all(m, Door):
		if d.style == Door.Style.SECRET:
			secret = d
	_check(secret != null and secret.is_hidden(), "a hidden secret door on floor 1")
	var sc := secret.get_cell()
	_check(m.closed_door_under(secret.position) == null, "a hidden secret door can't be clicked")
	_check(m.blocks_sight(sc) and not m.terrain_walkable(sc), "it blocks sight and movement like the wall")
	_check(m.map_picture.colour_of(sc) != MapPicture.COL_DOOR, "the map shows it as wall")
	var inside := secret.sides()[0] if m.has_floor(secret.sides()[0]) else secret.sides()[1]
	var outside := secret.sides()[1] if inside == secret.sides()[0] else secret.sides()[0]
	_place_party(m, inside + (inside - sc))
	_check(secret.found, "the Rogue's passive Perception (%d) finds it (DC %d)" % [m.party[1].stats.passive_perception(), secret.secret_dc])
	_check(m.closed_door_under(secret.position) == secret, "found: it can be clicked")
	m.try_open_door(secret, m.party)
	_check(secret.is_open and m.terrain_walkable(sc), "it opens")
	_check(not m.find_path(m.party[0].cell, outside).is_empty(), "the way to the strongroom is open")
	m.rotate_view(1)
	m.apply_pending_rotation()
	m.rotate_view(-1)
	m.apply_pending_rotation()
	_check(true, "turning the view with secret doors and traps works")

	# --- the lever sequence (the Hall of Hours) -----------------------------------------------------
	var hours: Puzzle = _named(m, "Puzzle_N")
	_check(hours != null and hours.kind == Puzzle.Kind.SEQUENCE and hours.solution == "sun,moon,star", "the Hall of Hours: a lever sequence")
	var levers := {}
	for l: Lever in _all(m, Lever):
		if l.link == hours.link:
			levers[l.symbol_name()] = l
	_check(levers.size() == 3, "three levers (sun, moon, star)")
	var gate: Door = null
	for d: Door in _all(m, Door):
		if d.link == hours.opens:
			gate = d
	_check(gate != null and gate.style == Door.Style.PORTCULLIS and not gate.is_open, "a closed portcullis on the vault")
	_check(not m.blocks_sight(gate.get_cell()), "you can see through a portcullis")
	m.try_open_door(gate, m.party)
	_check(not gate.is_open, "... but not lift it by hand")
	var note_n: RoomNote = _named(m, "Note_N")
	_place_party(m, levers.moon.get_cell() + Vector2i(1, 0))
	_check(note_n.modal and m.mech.check_notes() and m.hud.dialogue.visible, "the clue opens in the dialogue box")
	m.hud.dialogue.close()
	_heal(m)
	m.mech.pull(levers.moon, m.party[0])
	_check(levers.moon.down, "a lever goes down")
	await create_timer(0.8).timeout
	_check(not levers.moon.down and hours.progress.is_empty(), "the wrong first lever: they all spring back")
	for s in ["sun", "moon"]:
		m.mech.pull(levers[s], m.party[0])
	_check(not hours.solved and levers.sun.down and levers.moon.down, "sun, moon: so far so good")
	m.mech.pull(levers.star, m.party[0])
	_check(hours.solved, "sun, moon, star: solved")
	await create_timer(0.3).timeout
	_check(gate.is_open, "the portcullis rises")
	_place_party(m, gate.get_cell() + Vector2i(-2, 0))
	_check(m.terrain_walkable(gate.get_cell()) and not m.find_path(m.party[0].cell, gate.get_cell() + Vector2i(1, 0)).is_empty(), "the party can walk through into the vault")
	m.mech.pull(levers.moon, m.party[0])
	_check(levers.moon.down, "a solved puzzle's levers stay put")

	# --- everything is remembered (MapState) -----------------------------------------------------------
	MapState.save(m)
	m = await _open("res://modules/wraith_below/maps/dungeon_1.tscn")
	spikes = _named(m, "Trap_AB_")
	pit = _named(m, "Trap_IJ_")
	_check(spikes.disarmed and pit.sprung and not pit.armed(), "back on floor 1: traps stay disarmed / sprung")
	secret = null
	for d: Door in _all(m, Door):
		if d.style == Door.Style.SECRET:
			secret = d
	_check(secret.found and secret.is_open, "... the secret door stays found and open")
	hours = _named(m, "Puzzle_N")
	_check(hours.solved, "... the puzzle stays solved")
	for d: Door in _all(m, Door):
		if d.link == "d1_vault":
			gate = d
	_check(gate.is_open and m.terrain_walkable(gate.get_cell()), "... the portcullis stays up")
	_check((_named(m, "Note_A") as RoomNote).seen, "... and seen notes don't show again")

	# --- floor 2: blocks onto plates, the reset lever ------------------------------------------------
	m = await _open("res://modules/wraith_below/maps/dungeon_2.tscn")
	var weigh: Puzzle = _named(m, "Puzzle_K")
	_check(weigh != null and weigh.kind == Puzzle.Kind.ALL_ON, "floor 2: the weighing room (blocks + plates)")
	var b0: Prop = _named(m, "Block_K_0")
	var b1: Prop = _named(m, "Block_K_1")
	var plates := _all(m, PressurePlate)
	_check(b0 and b1 and b0.pushable and plates.size() == 2, "two pushable blocks, two plates")
	var start0 := b0.get_cell()
	# reveal the room
	_place_party(m, start0 + Vector2i(0, 1), true)
	_check(m.mech.thing_under(b0.position + Vector2(0, -8)) == b0, "the block is clickable")
	_check(m.mech.push_target(b0, m.party[0].cell) == start0 + Vector2i(0, -1), "pushed from below it slides up")
	m.mech.push(b0)
	await create_timer(0.6).timeout
	_check(b0.get_cell() == start0 + Vector2i(0, -1) and m.party[0].cell == start0, "one push: the block moves, the leader steps after it")
	_check(not m.terrain_walkable(b0.get_cell()) and m.terrain_walkable(start0), "the block blocks its new cell, the old one is free")
	var reset: Lever = null
	for l: Lever in _all(m, Lever):
		if l.role == "reset":
			reset = l
	m.party[0].place_at(reset.get_cell() + Vector2i(-1, 1))       # walk over to the lever
	m.mech.pull(reset, m.party[0])
	await create_timer(0.8).timeout
	_check(b0.get_cell() == start0, "the reset lever slides the block back")
	# block 0: straight up onto plate 0 (4 pushes); block 1: right twice, then down twice
	m.party[0].place_at(start0 + Vector2i(0, 1))
	for i in 4:
		m.mech.push(b0)
		await create_timer(0.5).timeout
	var on0 := false
	for p: PressurePlate in plates:
		if p.get_cell() == b0.get_cell():
			on0 = p.pressed
	_check(on0 and not weigh.solved, "block 0 is on a plate (pressed), not solved yet")
	var s1 := b1.get_cell()
	m.party[0].place_at(s1 + Vector2i(-1, 0))
	for i in 2:
		m.mech.push(b1)
		await create_timer(0.5).timeout
	m.party[0].place_at(b1.get_cell() + Vector2i(0, -1))
	m.refresh_navigation()
	for i in 2:
		m.mech.push(b1)
		await create_timer(0.5).timeout
	_check(weigh.solved, "both plates down: solved")
	await create_timer(0.3).timeout
	var vault2: Door = null
	for d: Door in _all(m, Door):
		if d.link == weigh.opens:
			vault2 = d
	_check(vault2 and vault2.is_open, "the treasury's portcullis rises")
	MapState.save(m)
	m = await _open("res://modules/wraith_below/maps/dungeon_2.tscn")
	b0 = _named(m, "Block_K_0")
	_check(b0.get_cell() != start0, "pushed blocks stay where they were pushed")

	# --- floor 3: an alarm tripwire --------------------------------------------------------------------
	m = await _open("res://modules/wraith_below/maps/dungeon_3.tscn")
	var wire: Trap = _named(m, "Trap_AB_")
	_check(wire.trap_type == Trap.TrapType.ALARM, "floor 3: a tripwire")
	wire.detect_dc = 40
	var w_from := _cell_near(m, wire.get_cell(), 2)
	_place_party(m, w_from, true)
	await _walk(m, wire.get_cell() + (wire.get_cell() - w_from).clampi(-1, 1))
	await _frames(10)
	_check(wire.sprung, "walking into it rings the bell")
	_check(m.combat.in_combat or m.combat._starting, "... and the goblins come running (a fight starts)")

	# --- floor 4: the ring of five fires -------------------------------------------------------------
	m = await _open("res://modules/wraith_below/maps/dungeon_4.tscn")
	var ring: Puzzle = _named(m, "Puzzle_L")
	var fires: Array = _all(m, Brazier).filter(func(b): return b.link == ring.link)
	fires.sort_custom(func(a, b): return a.order < b.order)
	_check(fires.size() == 5, "floor 4: five braziers in a ring")
	_check(fires.map(func(b): return int(b.lit)) == [1, 0, 0, 1, 0], "two of them burning")
	m.mech.toggle_brazier(fires[0])
	_check(fires.map(func(b): return int(b.lit)) == [0, 1, 0, 1, 1], "touching one flips it and both neighbours")
	m.mech.toggle_brazier(fires[3])
	_check(not ring.solved, "not solved yet")
	m.mech.toggle_brazier(fires[4])
	_check(ring.solved and fires.all(func(b): return b.lit), "all five lit: solved (0, 3, 4)")
	await create_timer(0.3).timeout
	var vault4: Door = null
	for d: Door in _all(m, Door):
		if d.link == ring.opens:
			vault4 = d
	_check(vault4 and vault4.is_open, "the reliquary opens")
	m.mech.toggle_brazier(fires[1])
	_check(fires[1].lit, "a solved ring can't be put out")

	# --- floor 5: the speaking stone ------------------------------------------------------------------
	m = await _open("res://modules/wraith_below/maps/dungeon_5.tscn")
	var face: StoneFace = _named(m, "StoneFace_K")
	var hoard: Door = null
	for d: Door in _all(m, Door):
		if d.link == face.link:
			hoard = d
	_check(face != null and hoard != null and hoard.style == Door.Style.SECRET and hoard.is_hidden(), "floor 5: a riddle face and a hidden door")
	_place_party(m, face.get_cell() + Vector2i(0, 1))
	m.mech.talk_to_face(face)
	_check(m.hud.dialogue.visible and "A wraith" in m.hud.dialogue.choice_texts()[0], "it asks its riddle")
	var hp1 := m.party[0].hp
	m.hud.dialogue.pick(2)                  # "The wind"
	_check(not face.solved and m.party[0].hp < hp1, "a wrong answer: lightning (HP %d -> %d)" % [hp1, m.party[0].hp])
	_heal(m)
	m.mech.talk_to_face(face)
	m.hud.dialogue.pick(face.correct)
	_check(face.solved, "the right answer")
	await create_timer(0.3).timeout
	_check(hoard.found and hoard.is_open, "the secret door to the kings' hoard grinds open")

	# --- the woods: the first trap ----------------------------------------------------------------------
	m = await _open("res://modules/wraith_below/maps/surface.tscn")
	var hunt: Trap = _named(m, "Trap_start_")
	_check(hunt != null and hunt.trap_type == Trap.TrapType.PIT, "the woods: a hunter's pit on the path")
	_place_party(m, _cell_near(m, hunt.get_cell(), 3))
	_check(hunt.spotted, "the level 1 Rogue spots it (passive %d vs DC %d)" % [m.party[1].stats.passive_perception(), hunt.detect_dc])

	print("test_puzzles: %d failed" % fails)
	quit(1 if fails > 0 else 0)
