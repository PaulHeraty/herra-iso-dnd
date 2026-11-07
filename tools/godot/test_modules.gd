extends SceneTree
## Modules test: the registry (res://modules/*/module.gd), the start screen (menu -> adventure list ->
## the adventure's first map), finishing an adventure into the Roster (module items and keys left
## behind, levels / gear / gold kept), and a roster party starting a new adventure (rested, its
## level, no quest). Writes only user://test_parties and user://test_saves. Prints PASS/FAIL.
##   HERRA_AUTO_REACT=1 tools/run_godot.sh -t 90 --path . -s res://tools/godot/test_modules.gd

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


func _wipe(dir: String) -> void:
	if DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + "/" + f)


func _until_map(timeout := 600) -> DungeonMap:
	for i in timeout:
		await process_frame
		if current_scene is DungeonMap and current_scene.is_node_ready() and not current_scene.party.is_empty():
			break
	await _frames(10)
	return current_scene as DungeonMap


## The card (a flat Button) on the start screen whose first line starts with `text`.
func _card_button(intro: Node, text: String) -> Button:
	for n in intro.find_children("*", "Button", true, false):
		var p := n.get_parent()
		if n.flat and p is Panel:
			for c in p.get_children():
				if c is Label and c.text.begins_with(text):
					return n
	return null


func _button(intro: Node, text: String) -> Button:
	for n in intro.find_children("*", "Button", true, false):
		if n.text == text:
			return n
	return null


func _run() -> void:
	Roster.dir = "user://test_parties"
	SaveGame.dir = "user://test_saves"
	_wipe(Roster.dir)

	# --- the registry -------------------------------------------------------------------------------
	var all := Modules.all()
	var wb := Modules.by_id("wraith_below")
	_check(not all.is_empty() and wb != null, "modules found (%d): %s" % [all.size(), ", ".join(all.map(func(m): return m.id))])
	_check(wb.title == "The Wraith Below" and wb.level_min == 1 and wb.fits_level(1) and not wb.fits_level(5), "The Wraith Below: for a level 1 party")
	_check(ResourceLoader.exists(wb.start_map) and wb.owns(wb.start_map), "its first map is in its folder")
	_check(Modules.for_scene("res://modules/wraith_below/maps/dungeon_3.tscn") == wb, "a map knows its module")
	_check(wb.quest_stages.size() == 11 and wb.intro_pages.size() == 3 and wb.epilogue != "", "quest, story pages and epilogue come from the module")

	# --- the start screen: menu -> new adventure -> the adventure list -> the woods ---------------
	Modules.current = null
	Intro.start_at_menu = true
	change_scene_to_file(Intro.SCENE)
	await _frames(20)
	var intro := current_scene
	_check(intro is Intro and _button(intro, "New adventure") != null, "start screen: the menu")
	_button(intro, "New adventure").pressed.emit()
	await _frames(10)
	_check(_card_button(intro, "The Wraith Below") != null, "no saved parties: straight to the adventure list")
	_card_button(intro, "The Wraith Below").pressed.emit()
	await _frames(5)
	_check(intro._stage == Intro.Stage.STORY, "picking it shows its story")
	intro._start_game()
	var m := await _until_map()
	_check(m != null and m.scene_file_path == wb.start_map, "then its first map")
	_check(Modules.current == wb and m.party[0].level == 1, "a new party: level 1, the module is current")

	# --- finishing: the party goes into the Roster ---------------------------------------------------
	for h in m.party:
		h.set_level(5)
		h.xp = 7000
	m.inventory.add_gold(3000)
	m.inventory.add("rune_of_return")
	m.inventory.add("vault_key")
	m.inventory.add("flame_tongue")
	m.party[0].equip_from(m.inventory, "flame_tongue")
	var entry := Roster.keep(m, wb)
	_check(entry.level == 5 and entry.modules_done == ["wraith_below"], "kept in the Roster: level 5, finished The Wraith Below")
	var bag: Dictionary = entry.party.bag
	var ids: Array = bag.stacks.map(func(s): return s.id)
	_check("rune_of_return" in ids and not "vault_key" in ids, "the keys stay behind; the Rune of Return comes along (rebind it)")
	_check(bag.gold >= 3000 and "potion_healing" in ids, "gold and ordinary items come along")
	_check(entry.party.heroes[Hero.HeroClass.FIGHTER].equipment.values().has("flame_tongue"), "gear comes along")
	var listed := Roster.parties()
	_check(listed.size() == 1 and listed[0].id == entry.id, "the Roster lists it")
	Roster.keep(m, wb)
	_check(Roster.parties().size() == 1, "finishing again updates the same entry")

	# --- the start screen with a saved party ----------------------------------------------------------
	Intro.start_at_menu = true
	change_scene_to_file(Intro.SCENE)
	await _frames(20)
	intro = current_scene
	_button(intro, "New adventure").pressed.emit()
	await _frames(10)
	_check(intro._stage == Intro.Stage.PARTY and _card_button(intro, entry.name) != null, "a saved party: choose a party first")
	_card_button(intro, entry.name).pressed.emit()
	await _frames(10)
	_check(_card_button(intro, "The Wraith Below") == null, "a level 5 party can't start the level 1 adventure")
	_check(_card_button(intro, "The Frost Spire") != null, "... but it can start The Frost Spire (levels 5-6)")
	_button(intro, "Back (Esc)").pressed.emit()
	await _frames(5)
	_card_button(intro, "A new party").pressed.emit()
	await _frames(5)
	_check(_card_button(intro, "The Wraith Below") != null, "... a new party can")

	# --- a roster party starting an adventure ---------------------------------------------------------
	Intro.begin(wb, entry)
	change_scene_to_file(wb.start_map)
	m = await _until_map()
	var f := m.party[0]
	_check(f.level == 5 and f.hp == f.stats.max_hp and f.stats.max_hp > 30, "the roster party arrives at level 5, rested (%d HP)" % f.hp)
	_check(f.equipment.values().has("flame_tongue") and m.inventory.gold >= 3000, "with its gear and gold")
	_check(not Quest.given and not RunePortal.active and not RunePortal.bound and m.inventory.has("rune_of_return"),
			"a fresh story: no quest; the rune came along but isn't bound here")
	_check(PartyState.roster.get("id", "") == entry.id, "it remembers which roster party it is")

	# --- save games know their module -----------------------------------------------------------------
	_wipe(SaveGame.dir)
	_check(SaveGame.save(m, 1, "modtest") == "", "saved")
	_check(SaveGame.info(1).get("module", "") == "wraith_below", "the save's header names the module")
	Modules.current = null
	_check(SaveGame.prepare_load(1) != "" and Modules.current == wb, "loading it makes its module current")

	_wipe(Roster.dir)
	_wipe(SaveGame.dir)
	print("test_modules: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILURES", fails])
	quit(1 if fails else 0)
