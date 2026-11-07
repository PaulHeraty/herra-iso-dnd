extends SceneTree
## Save / load test (SaveGame + SaveScreen). Prints PASS/FAIL. Needs a window, like test_dungeon.gd:
##   HERRA_AUTO_REACT=1 Godot_console --path . -s res://tools/godot/test_save.gd
## Writes to user://test_saves (never the real user://saves) and cleans up after itself.

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


func _clean() -> void:
	for i in range(SaveGame.QUICK, SaveGame.SLOTS + 1):
		if FileAccess.file_exists(SaveGame.slot_path(i)):
			DirAccess.remove_absolute(SaveGame.slot_path(i))


func _init() -> void:
	_run()


func _run() -> void:
	SaveGame.dir = "user://test_saves"
	_clean()
	PartyState.reset()
	MapState.reset()
	change_scene_to_file("res://modules/wraith_below/maps/dungeon_1.tscn")
	await _until_scene_changes(null)
	var m := _map()
	_check(m != null and m.party.size() == 4, "dungeon_1 loads with the party")
	_check(SaveGame.info(1).is_empty() and SaveGame.default_name() == "save001", "no saves yet: default name save001")

	# --- change the game: hurt a hero, gold, a dead monster, an open door, moves, a view turn ---
	var fighter := m.party[0]
	fighter.hp = maxi(1, fighter.hp - 3)
	var hp_saved := fighter.hp
	m.party[3].slots_left[0] = 0
	m.inventory.gold += 123
	var gold_saved := m.inventory.gold
	var spawn: MonsterSpawn = null
	for n in m.entities.get_children():
		if n is MonsterSpawn and n.monster:
			spawn = n
			break
	spawn.monster.hp = 0
	spawn.monster.dead = true
	var door: Door = null
	for n in m.entities.get_children():
		if n is Door and not n.is_open and not n.locked:
			door = n
			break
	door.open()
	var moved_to := Vector2i(-999, -999)
	for d in DungeonMap.DIRS8:
		var c: Vector2i = m.party[2].cell + d * 2
		if m.is_walkable(c) and m.actor_at(c) == null:
			moved_to = c
			break
	m.party[2].place_at(moved_to)
	m.party[2].facing = Vector2i(0, -1)
	m.rotate_view(1)
	m.apply_pending_rotation()
	await _frames(5)
	var cells_saved: Array[Vector2i] = []
	for h in m.party:
		cells_saved.append(h.cell)
	var explored := m.fog.explored.size()
	var spawn_name := String(spawn.name)
	var door_name := String(door.name)

	# --- when saving is allowed ---
	m.combat.in_combat = true
	_check(SaveGame.blocked_reason(m) != "", "no saving mid-fight")
	_check(SaveGame.save(m, 1, "x") != "" and SaveGame.info(1).is_empty(), "a refused save writes nothing")
	m.combat.in_combat = false
	_check(SaveGame.blocked_reason(m) == "", "saving allowed while exploring")

	# --- save: blank name = default, typed name kept ---
	_check(SaveGame.save(m, 2, "   ") == "", "save to slot 2")
	_check(SaveGame.info(2).get("name") == "save001", "blank name -> save001 (%s)" % SaveGame.info(2).get("name"))
	_check(SaveGame.info(2).get("map_title") == m.map_title and SaveGame.info(2).get("gold") == gold_saved,
			"slot header: map title + gold")
	_check(SaveGame.save(m, 3, "Before the crypt") == "", "save to slot 3 with a name")
	_check(SaveGame.info(3).get("name") == "Before the crypt", "typed name kept")
	_check(SaveGame.default_name() == "save003", "next default is save003 (%s)" % SaveGame.default_name())
	_check(PartyState.party_xp == 0 and not PartyState.has_state(), "saving doesn't move the R-restart point")

	# --- play on, then load slot 2 ---
	m.inventory.gold += 1000
	fighter.hp = 1
	var err := []
	_check(SaveGame.prepare_load(1, err) == "" and not err.is_empty(), "empty slot can't be loaded")
	_check(m.load_game(2) == "", "load slot 2")
	await _until_scene_changes(m)
	m = _map()
	_check(m != null and m.scene_file_path == "res://modules/wraith_below/maps/dungeon_1.tscn", "back on dungeon_1")
	_check(m.inventory.gold == gold_saved, "gold as saved (%d)" % m.inventory.gold)
	_check(m.party[0].hp == hp_saved, "fighter HP as saved (%d)" % m.party[0].hp)
	_check(m.party[3].slots_left[0] == 0, "mage's spent slot stays spent")
	var same := true
	for i in m.party.size():
		same = same and m.party[i].cell == cells_saved[i]
	_check(same, "everyone on their saved cell")
	_check(m.party[2].facing == Vector2i(0, -1), "facing kept")
	_check(IsoGrid.rotation == 1, "view rotation kept")
	var sp2 := m.entities.get_node(NodePath(spawn_name)) as MonsterSpawn
	_check(sp2.cleared and sp2.monster == null, "the killed monster stays dead")
	var d2 := m.entities.get_node(NodePath(door_name)) as Door
	_check(d2.is_open, "the opened door stays open")
	_check(m.fog.explored.size() == explored, "explored cells kept (%d)" % m.fog.explored.size())

	# --- F5: the quick save (no screen, always the same file) ---
	_check(SaveGame.slot_path(SaveGame.QUICK).ends_with("quick-save.sav"), "the quick save is its own file (quick-save.sav)")
	m.save_screen.quick_save()
	var q1 := SaveGame.info(SaveGame.QUICK)
	_check(not m.save_screen.visible and q1.get("name") == SaveGame.QUICK_NAME, "F5 quick saves without opening a screen")
	_check(SaveGame.default_name() == "save003", "the quick save doesn't use up a default name (%s)" % SaveGame.default_name())
	m.inventory.add_gold(5)
	m.save_screen.quick_save()
	_check(SaveGame.info(SaveGame.QUICK).get("gold") == m.inventory.gold, "F5 again overwrites the quick save")
	var files := DirAccess.get_files_at(SaveGame.dir)
	_check(files.size() == 3 and "quick-save.sav" in files, "on disk: the quick save + the 2 used slots (%s)" % [files])
	m.save_screen.open(false)
	_check(m.save_screen._rows[SaveGame.QUICK].visible and m.save_screen.selected == SaveGame.QUICK, "the load screen lists the quick save (the newest, picked)")
	m.save_screen.close()
	m.inventory.add_gold(-5)

	# --- F6: the save screen, a typed name, Enter saves ---
	m.save_screen.open(true)
	_check(m.save_screen.visible and paused, "F6 screen opens and pauses the game")
	_check(not m.save_screen._rows[SaveGame.QUICK].visible, "the save screen shows only the 3 slots")
	_check(m.save_screen.selected == 1, "save screen picks the first empty slot")
	m.save_screen._name.text = "From the screen"
	m.save_screen.confirm()
	_check(not m.save_screen.visible and not paused, "saved: screen closed, game running")
	_check(SaveGame.info(1).get("name") == "From the screen", "slot 1 saved from the screen")
	m.save_screen.open(false)
	_check(m.save_screen.selected == 1, "load screen picks the newest save")
	m.save_screen.close()
	_check(not paused, "closing unpauses")
	m.combat.game_over = true
	m.save_screen.open(true)
	_check(not m.save_screen.visible, "no save screen after a wipe")
	m.save_screen.open(false)
	_check(m.save_screen.visible, "load screen works after a wipe")
	m.save_screen.select(3)
	m.save_screen.confirm()
	await _until_scene_changes(m)
	m = _map()
	_check(m != null and not m.combat.game_over and not paused, "loaded from the game-over screen")
	_check(m.inventory.gold == gold_saved, "slot 3 state")

	_clean()
	print("\n%s (%d failed)" % ["ALL PASSED" if fails == 0 else "SOME FAILED", fails])
	quit(1 if fails > 0 else 0)
