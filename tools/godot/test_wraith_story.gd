extends SceneTree
## Module 1 story test (Phase 7, "The Wraith Below"): Hanna at the mine camp and "Word of Tobin"
## (the miner's letter sets a flag when read), Brannoc's side quest "The Taken" and his Ask menu,
## old Pell in the goblins' holding pen (freed, he turns up at the camp), Sir Aldric's ghost in the
## Sunken Crypts and "The King's Crown", and the epilogue that follows the story. PASS/FAIL.
##   HERRA_AUTO_REACT=1 tools/run_godot.sh -t 150 --path . -s res://tools/godot/test_wraith_story.gd

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
		PartyState.save(current_scene)
		MapState.save(current_scene)
		var old := current_scene
		root.remove_child(old)
		old.free()
	var m: DungeonMap = (load(path) as PackedScene).instantiate()
	root.add_child(m)
	current_scene = m
	await _frames(5)
	m.combat.set_process(false)
	return m


func _named(m: DungeonMap, prefix: String) -> Node:
	for n in m.entities.get_children():
		if String(n.name).begins_with(prefix):
			return n
	return null


func _place(m: DungeonMap, at: Vector2i) -> void:
	var cells: Array[Vector2i] = [at]
	for d in DungeonMap.DIRS8:
		if cells.size() < 4 and m.terrain_walkable(at + d) and m.actor_at(at + d) == null:
			cells.append(at + d)
	for i in m.party.size():
		m.party[i].place_at(cells[mini(i, cells.size() - 1)])
	m.update_fog()
	m.refresh_navigation()


## Kill every monster within `radius` cells of a cell (as if a fight there was won).
func _clear_near(m: DungeonMap, c: Vector2i, radius: int) -> int:
	var n := 0
	for sp in m.entities.get_children():
		if sp is MonsterSpawn and sp.monster and DungeonMap.grid_distance(sp.monster.cell, c) <= radius:
			n += 1
			sp.monster.hp = 0
			sp.monster.dead = true
			m.monsters.erase(sp.monster)
			sp.monster.queue_free()
			sp.monster = null
			sp.cleared = true
	m.refresh_navigation()
	m._npc_t = 0.0
	return n


func _choice(m: DungeonMap, text: String) -> int:
	var ch: Array = m.hud.dialogue.choice_texts()
	for i in ch.size():
		if text in ch[i]:
			return i
	return -1


func _run() -> void:
	MapState.reset()
	PartyState.reset()
	Dice.seed_rng(4242)
	var mod := Modules.by_id("wraith_below")
	_check(mod != null and mod.side_quests.size() == 3, "The Wraith Below: three side quests")
	Intro.begin(mod, {})

	# --- the mine camp: Brannoc, Hanna -----------------------------------------------------------------
	var m := await _open(mod.start_map)
	var brannoc: Npc = _named(m, "Npc_Brannoc")
	var hanna: Npc = _named(m, "Npc_Hanna")
	var camp_pell: Npc = _named(m, "Npc_Pell")
	_check(hanna and not hanna.present, "Hanna hides with Brannoc while the mine goblins live")
	_check(camp_pell and not camp_pell.present, "Pell isn't at the camp yet")
	_clear_near(m, brannoc.get_cell(), brannoc.guard_radius)
	_place(m, brannoc.get_cell() + Vector2i(-3, 2))
	for i in 900:
		if m.hud.dialogue.visible:
			break
		await process_frame
	_check(brannoc.present and hanna.present and not camp_pell.present, "the goblins dead: Brannoc and Hanna come out, not Pell")
	_check(m.hud.dialogue.visible and Quest.met, "Brannoc calls the party over")
	for i in 5:
		m.hud.dialogue.pick(0)
	_check(Quest.given and Quest.side_given("taken") and "Hanna" in m.hud.dialogue.current_text(), "his speech: the quest, the rune, Pell, then Hanna")
	m.hud.dialogue.pick(_choice(m, "Goodbye"))
	# Hanna
	_place(m, hanna.get_cell() + Vector2i(1, 0))
	m.talk_to(hanna)
	_check(m.hud.dialogue.visible and "Tobin" in m.hud.dialogue.current_text(), "Hanna asks after her husband Tobin")
	m.hud.dialogue.pick(0)
	_check(Quest.side_given("tobin") and Quest.has_met("hanna"), "side quest 'Word of Tobin'")
	m.hud.dialogue.pick(0)
	_check(not m.hud.dialogue.visible, "and she lets the party go")
	# Brannoc's Ask menu
	m.talk_to(brannoc)
	m.hud.dialogue.pick(_choice(m, "Ask about"))
	_check(_choice(m, "The mine") >= 0 and _choice(m, "The goblins") >= 0 and _choice(m, "What next") >= 0, "Ask about: what next, the mine, the goblins")
	m.hud.dialogue.pick(_choice(m, "The goblins"))
	_check("prisoner" in m.hud.dialogue.current_text(), "the goblins take prisoners, he wonders why")
	m.hud.dialogue.close()

	# --- the Upper Halls: Tobin's letter ---------------------------------------------------------------
	m = await _open(MAPS + "dungeon_1.tscn")
	var letter: LoreNote = null
	for n in m.entities.get_children():
		if n is LoreNote and n.flag == "tobin_letter":
			letter = n
	_check(letter != null and "Your Tobin" in letter.text, "Tobin's letter lies in the entrance hall")
	var xp0 := m.party_xp
	m.mech.read_lore(letter)
	_check(Quest.has_flag("tobin_letter") and Quest.side.tobin.done.has("find"), "reading it: the stage is done")
	_check(m.party_xp >= xp0 + 100, "with its XP (%d)" % (m.party_xp - xp0))
	m.hud.dialogue.close()

	# --- the Warrens: Pell in the holding pen ------------------------------------------------------------
	m = await _open(MAPS + "dungeon_3.tscn")
	var pell: Npc = _named(m, "Npc_Pell")
	_check(pell and pell.present, "Pell sits in the goblins' holding pen")
	var pen_locked := false
	for d in m.entities.get_children():
		if d is Door and d.key_id == "warren" and d.locked and DungeonMap.grid_distance(d.get_cell(), pell.get_cell()) <= 9:
			pen_locked = true
	_check(pen_locked, "behind a locked door (the Chief's Key)")
	var war: LoreNote = null
	for n in m.entities.get_children():
		if n is LoreNote and n.flag == "war_orders":
			war = n
	m.mech.read_lore(war)
	m.hud.dialogue.close()
	_check(Quest.has_flag("war_orders"), "the goblin war orders set their flag")
	_place(m, pell.get_cell() + Vector2i(1, 0))
	m.talk_to(pell)
	_check(Quest.has_flag("met_pell") and Quest.side.taken.done.has("find"), "talking to him: found")
	m.hud.dialogue.pick(0)
	_check("Cold King" in m.hud.dialogue.current_text(), "he tells of the Cold King")
	m.hud.dialogue.pick(0)
	_check("secret cubby" in m.hud.dialogue.current_text(), "and of the chief's secret stash")
	m.hud.dialogue.pick(0)
	m._npc_t = 0.0
	await create_timer(0.8).timeout
	_check(Quest.has_flag("pell_left") and not pell.present, "he makes for the surface")

	# --- back at the camp: Pell, Hanna's news, Brannoc's reward ----------------------------------------
	m = await _open(mod.start_map)
	brannoc = _named(m, "Npc_Brannoc")
	hanna = _named(m, "Npc_Hanna")
	camp_pell = _named(m, "Npc_Pell")
	_check(camp_pell.present and brannoc.present and hanna.present, "Pell is at the camp now")
	_place(m, hanna.get_cell() + Vector2i(1, 0))
	var gold := m.inventory.gold
	m.talk_to(hanna)
	m.hud.dialogue.pick(0)
	_check(_choice(m, "Keep it") >= 0, "the news: she offers her savings")
	m.hud.dialogue.pick(_choice(m, "Keep it"))
	_check(Quest.side_claimed("tobin") and Quest.has_flag("hanna_kept") and m.inventory.gold == gold, "left with her: no gold taken, quest done")
	m.hud.dialogue.close()
	m.talk_to(brannoc)
	var pi := _choice(m, "Pell is safe")
	_check(pi >= 0, "Brannoc: 'Pell is safe'")
	m.hud.dialogue.pick(pi)
	_check(Quest.side_claimed("taken") and m.inventory.gold == gold + 250 and m.inventory.has("potion_superior_healing"), "the reward: 250 gold + a Potion of Superior Healing")
	m.hud.dialogue.pick(_choice(m, "Ask about"))
	m.hud.dialogue.pick(_choice(m, "The goblins"))
	_check("Cold King" in m.hud.dialogue.current_text(), "with the war orders read, he knows the Cold King is the wraith")
	m.hud.dialogue.close()
	m.talk_to(camp_pell)
	_check(m.hud.dialogue.visible, "Pell talks at the camp")
	m.hud.dialogue.close()

	# --- the Sunken Crypts: Sir Aldric -----------------------------------------------------------------
	m = await _open(MAPS + "dungeon_4.tscn")
	var aldric: Npc = _named(m, "Npc_Aldric")
	_check(aldric and not aldric.present and aldric.ghostly, "Sir Aldric's ghost hides while his tomb's dead walk")
	var guards := _clear_near(m, aldric.get_cell(), aldric.guard_radius)
	await create_timer(0.8).timeout
	_check(guards >= 2 and aldric.present, "the dead destroyed: he shows himself (%d)" % guards)
	_check(aldric.material is CanvasItemMaterial and aldric.material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "a ghost: drawn unshaded")
	_place(m, aldric.get_cell() + Vector2i(1, 0))
	m.talk_to(aldric)
	for i in 3:
		m.hud.dialogue.pick(0)
	_check("Sun Key" in m.hud.dialogue.current_text() or Quest.side_given("crown"), "he tells of the Sun Key")
	m.hud.dialogue.pick(0)
	_check(Quest.side_given("crown") and Quest.has_met("aldric"), "side quest 'The King's Crown'")
	m.hud.dialogue.close()
	# the Wraith destroyed, the crown taken from its vault
	_check(_has_crown_in_vault(), "the crown lies in the Wraith's vault chest")
	Quest.note_kill("wraith")
	m.inventory.add("crown_ostric")
	m.quest_check()
	_check(Quest.side_reward_due("crown"), "Wraith dead + crown in the bag: time to lay it in the tomb")
	xp0 = m.party_xp
	m.talk_to(aldric)
	var li := _choice(m, "Lay the crown")
	_check(li >= 0, "Aldric: 'Lay the crown in the tomb'")
	m.hud.dialogue.pick(li)
	_check(Quest.side_claimed("crown") and not m.inventory.has("crown_ostric") and m.inventory.has("cloak_protection"), "the crown laid: his Cloak of Protection")
	_check(m.party_xp >= xp0 + 1000, "with its XP (%d)" % (m.party_xp - xp0))
	m.hud.dialogue.pick(0)
	m._npc_t = 0.0
	await create_timer(0.8).timeout
	_check(Quest.has_flag("aldric_rests") and not aldric.present, "and he fades away, at rest")

	# --- the epilogue -------------------------------------------------------------------------------------
	var ep := mod.epilogue_text()
	_check("Aldric" in ep and "Pell" in ep and "Hanna" in ep, "the epilogue tells of Aldric, Pell and Hanna")
	Quest.reset()
	_check(not ("Aldric" in mod.epilogue_text()), "... and not when they weren't helped")
	_check("crown_ostric" in mod.module_items, "the crown stays behind when the party moves on")

	print("test_wraith_story: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILURES", fails])
	quit(0 if fails == 0 else 1)


func _has_crown_in_vault() -> bool:
	var m: DungeonMap = (load(MAPS + "dungeon_5.tscn") as PackedScene).instantiate()
	var ok := false
	for n in m.get_node("World/Entities").get_children():
		if n is Chest and "crown_ostric" in n.items:
			ok = true
	m.free()
	return ok
