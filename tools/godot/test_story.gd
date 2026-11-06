extends SceneTree
## The trader, the quest and the Rune of Return. Prints PASS/FAIL. Needs a window, like
## test_dungeon.gd:  HERRA_AUTO_REACT=1 Godot_console --path . -s res://tools/godot/test_story.gd
## Uses modules/wraith_below/maps/surface.tscn (Brannoc, his stall, the home portal) and dungeon_1.tscn.

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


func _init() -> void:
	_run()


func _run() -> void:
	_quest_rules()
	PartyState.reset()
	MapState.reset()
	var m: DungeonMap = (load("res://modules/wraith_below/maps/surface.tscn") as PackedScene).instantiate()
	root.add_child(m)
	current_scene = m
	await _frames(5)
	var npc: Npc = null
	for n in m.entities.get_children():
		if n is Npc:
			npc = n
	_check(npc != null, "Brannoc stands in the woods")
	_check(not npc.present and not npc.visible, "he hides while the mine goblins live")
	_check(m.terrain_walkable(npc.get_cell()), "a hidden trader doesn't block his cell")
	_check(not Quest.met and not Quest.given, "a new game: no quest yet")

	# --- the goblins at the mine die: he steps out and calls the party over ---
	var guards := 0
	for sp in m.entities.get_children():
		if sp is MonsterSpawn and sp.monster and DungeonMap.grid_distance(sp.monster.cell, npc.get_cell()) <= npc.guard_radius:
			guards += 1
			sp.monster.hp = 0
			sp.monster.dead = true
			m.monsters.erase(sp.monster)
			sp.monster.queue_free()
			sp.monster = null
			sp.cleared = true
	_check(guards >= 3, "the mine goblins guard him (%d)" % guards)
	var near := npc.get_cell() + Vector2i(-3, 2)
	var cells := [near, near + Vector2i(1, 0), near + Vector2i(0, 1), near + Vector2i(1, 1)]
	for i in 4:
		m.party[i].place_at(cells[i])
	m.update_fog()
	m.refresh_navigation()
	for i in 900:
		if m.hud.dialogue.visible:
			break
		await process_frame
	_check(npc.present and npc.visible, "with the goblins dead he comes out")
	_check(not m.terrain_walkable(npc.get_cell()), "and blocks his cell")
	_check(m.hud.dialogue.visible and Quest.met, "he talks to the party by himself")
	var d := m.hud.dialogue
	d.pick(0)
	d.pick(0)
	_check("wraith" in d.current_text() and d.choice_texts().size() == 1, "he offers the quest")
	d.pick(0)
	_check(Quest.given and m.inventory.has("rune_of_return"), "quest accepted: the Rune of Return is in the bag")
	_check("Trade" in d.choice_texts(), "then: Trade / Goodbye")
	d.pick(0)
	_check(m.hud.shop.visible and not d.visible, "Trade opens his stall")

	# --- the shop ---
	var shop := m.hud.shop
	m.inventory.gold = 120
	_check(not shop.buy("potion_greater_healing"), "can't buy what you can't afford")
	_check(shop.buy("potion_healing") and m.inventory.gold == 70, "a Potion of Healing costs 50 gold")
	_check(not shop.buy("ring_protection"), "he doesn't sell the reward ring")
	m.inventory.add("longsword")
	var g := m.inventory.gold
	_check(shop.sell("longsword") and m.inventory.gold == g + 7 and not m.inventory.has("longsword"), "he buys a longsword for half (7 gold)")
	_check(not shop.sell("rune_of_return") and m.inventory.has("rune_of_return"), "he won't buy back the rune")
	shop.close()

	# --- the rune can't be used in the woods ---
	_check(m.use_rune() != "" and not RunePortal.active, "the rune stays dark in the woods")
	var hp: Portal = m.entities.get_node("Portal_Home")
	_check(hp.home and not hp.is_shown(), "the stall's portal is closed")

	# --- down the mine: the first stage is done ---
	var st: Stairs = null
	for n in m.entities.get_children():
		if n is Stairs:
			st = n
	m.take_stairs(st)
	await _until_scene_changes(m)
	m = current_scene
	m.combat.set_process(false)
	await _frames(5)
	_check(m.scene_file_path.ends_with("dungeon_1.tscn") and Quest.is_done("mine"), "floor 1: 'go down into the mine' is ticked off")
	_check(Quest.current() == 1, "next: find the way down")
	_check(m.inventory.has("rune_of_return") and m.inventory.gold == g + 7, "the bag came along")

	# --- use the rune: a portal next to the party ---
	var lead := m.party[0]
	_check(m.hud.inventory_screen.equip(lead, "rune_of_return"), "clicking the rune in the bag uses it")
	_check(RunePortal.active and RunePortal.map_path == m.scene_file_path, "a portal is open on floor 1")
	var pc := RunePortal.cell
	_check(DungeonMap.grid_distance(pc, lead.cell) == 1 and m.terrain_walkable(pc), "next to the leader, on open floor")
	var p := m.portal_at(pc)
	_check(p != null and not p.home and p.visible, "the portal is there")
	_check(m.inventory.has("rune_of_return"), "the rune isn't used up")
	m.take_portal(p)
	await _until_scene_changes(m)
	m = current_scene
	await _frames(5)
	_check(m.scene_file_path == RunePortal.home_map(), "through the portal: back in the woods")
	var hp2: Portal = m.entities.get_node("Portal_Home")
	var arrive := Vector2i(-999, -999)
	for n in m.entities.get_children():
		if n is PartyStart and n.entry_id == RunePortal.HOME_ENTRY:
			arrive = n.get_cell()
	_check(m.party[0].cell == arrive, "the party arrives by the stall")
	_check(hp2.is_shown() and hp2.visible, "the stall's portal stands open")
	var npc2: Npc = m.entities.get_node("Npc_Brannoc")
	_check(npc2.present, "Brannoc is still out (the goblins stay dead)")
	_check(not m.hud.dialogue.visible, "and doesn't repeat his speech")

	# --- back through: the same cell on floor 1, the portal gone ---
	m.take_portal(hp2)
	await _until_scene_changes(m)
	m = current_scene
	m.combat.set_process(false)
	await _frames(5)
	_check(m.scene_file_path.ends_with("dungeon_1.tscn") and m.party[0].cell == pc, "back where the rune was used")
	_check(not RunePortal.active and m.portal_at(pc) == null, "the portal has closed behind them")

	# --- the end of the quest: the Wraith, then the reward ---
	Quest.note_kill("wraith")
	m.quest_check()
	_check(Quest.is_done("wraith") and Quest.is_done("deep") and Quest.reward_due(), "the Wraith destroyed ticks off every stage before it")
	var gold0 := m.inventory.gold
	Quest.claim(m.inventory)
	_check(Quest.claimed and Quest.finished() and m.inventory.gold == gold0 + Quest.reward_gold() and m.inventory.has(Quest.reward_item()),
			"Brannoc pays: %d gold and a %s" % [Quest.reward_gold(), Quest.reward_item()])

	# --- the win screen: his last line's only choice opens it; it pauses the game ---
	var trader: Npc = (load("res://scenes/markers/npc.tscn") as PackedScene).instantiate()
	m.entities.add_child(trader)                   # (we're on floor 1: a stand-in Brannoc)
	await _frames(2)
	TraderTalk._reward(m, trader)
	await _frames(2)
	var ch: Array = m.hud.dialogue._choices
	_check(m.hud.dialogue.visible and ch.size() == 1, "after the reward, one choice: farewell")
	if ch.size() == 1:
		ch[0].call.call()
	await _frames(3)
	_check(m.victory_screen != null and m.victory_screen.visible and paused, "farewell opens the victory screen, game paused")
	_check(not m.hud.visible and not m.hud.dialogue.visible, "the HUD and the talk are hidden behind it")
	var t0 := PartyState.play_seconds
	await _frames(10)
	_check(PartyState.play_seconds == t0, "play time stops while it is up")
	m.victory_screen._keep.pressed.emit()
	await _frames(10)
	_check(not m.victory_screen.visible and not paused and m.hud.visible, "Keep exploring: back to the game")
	_check(PartyState.play_seconds > t0 and PartyState.snapshot(m).get("play_seconds", -1.0) == PartyState.play_seconds,
			"play time counts again and travels with the party")
	print("test_story: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILURES", fails])
	quit(1 if fails else 0)


## Quest bookkeeping without a map.
func _quest_rules() -> void:
	Modules.current = Modules.by_id("wraith_below")       # no map: say which module's quest
	Quest.reset()
	var bag := Inventory.new()
	Quest.note_map("res://modules/wraith_below/maps/dungeon_1.tscn")
	_check(Quest.update(bag).is_empty() and not Quest.is_done("mine"), "nothing is ticked before the quest is given")
	Quest.given = true
	var newly := Quest.update(bag)
	_check(newly.size() == 1 and Quest.is_done("mine"), "given later: what already happened counts")
	bag.add("warren_key")
	newly = Quest.update(bag)
	_check(newly.size() == 5 and Quest.is_done("eye") and Quest.current() == 6, "a later stage done ticks off the ones before it (%d)" % newly.size())
	var saved := Quest.to_dict()
	Quest.reset()
	_check(not Quest.given and Quest.current() == 0, "reset")
	Quest.from_dict(saved)
	_check(Quest.given and Quest.is_done("chief_key"), "to_dict / from_dict")
	Quest.reset()
