extends SceneTree
## Module 2 test ("The Frost Spire"): the Frostfell (beacons melt the ward, Hilde hides until the
## dragon dies, her quests, rebinding the Rune of Return), the tower (the mimic, the lever vault,
## Tamsin's cell, the ring of fires, the Star Key door, the riddle), new rules (troll regeneration,
## Death Ward, Evasion, Indomitable, damage powers chosen by the AI) and the ending. PASS/FAIL.
##   HERRA_AUTO_REACT=1 tools/run_godot.sh -t 180 --path . -s res://tools/godot/test_frost.gd

const MAPS := "res://modules/frost_spire/maps/"

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
	m.combat.set_process(false)
	return m


func _all(m: DungeonMap, type: Variant) -> Array:
	return m.entities.get_children().filter(func(n): return is_instance_of(n, type))


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


func _door_with_link(m: DungeonMap, link: String) -> Door:
	for d: Door in _all(m, Door):
		if d.link == link:
			return d
	return null


func _monster(m: DungeonMap, id: String) -> Monster:
	for mo in m.monsters:
		if mo.stats.id == id:
			return mo
	return null


func _run() -> void:
	MapState.reset()
	PartyState.reset()
	Dice.seed_rng(9119)
	var mod := Modules.by_id("frost_spire")
	_check(mod != null and mod.level_min == 5 and mod.level_end == 9 and mod.side_quests.size() == 2, "The Frost Spire: levels 5-6 -> 9, two side quests")

	# --- a new quick-start party arrives in the Frostfell ------------------------------------------
	Intro.begin(mod, {})
	var m := await _open(mod.start_map)
	_check(Modules.current == mod and Quest.given, "the jarl's quest is under way from the start")
	_check(m.party[0].level == 5 and m.party[0].equipment.values().has("longsword_plus1") and m.inventory.gold >= 1500,
			"a new party: level 5, with the module's kit and gold")
	_check(m.map_title == "The Frostfell" and m.floor_layer.tile_set.resource_path.ends_with("snow_tileset.tres"), "the Frostfell, on the snow tiles")

	# --- the beacons and the ward ---------------------------------------------------------------------
	var ward := _door_with_link(m, "ward")
	var beacons := _all(m, Brazier).filter(func(b): return b.link == "beacons")
	_check(ward and ward.style == Door.Style.ICE and not ward.is_open and not ward.by_hand(), "an ice ward blocks the way into the vale")
	_check(m.blocks_sight(ward.get_cell()), "... and the view")
	_check(beacons.size() == 3 and not beacons.any(func(b): return b.lit), "three cold beacons")
	var xp0 := m.party_xp
	for b in beacons:
		m.mech.toggle_brazier(b)
	await create_timer(0.4).timeout
	_check(Quest.has_flag("beacons_lit") and Quest.is_done("beacons"), "all three lit: the quest stage is done")
	_check(ward.is_open and m.terrain_walkable(ward.get_cell()), "the ward melts")
	_check(m.party_xp >= xp0 + 1500 + 3000, "puzzle + quest-stage XP (%d)" % (m.party_xp - xp0))

	# --- the vale: the dragon, Hilde --------------------------------------------------------------------
	var hilde: Npc = _named(m, "Npc_Hilde")
	var dragon := _monster(m, "young_white_dragon")
	_check(hilde != null and dragon != null and not hilde.present, "Hilde hides while the white dragon lives")
	dragon.hp = 0
	m._on_combat_ended()
	m._npc_t = 0.0
	await create_timer(0.6).timeout
	_check(hilde.present and Quest.is_done("dragon"), "the dragon is dead: Hilde comes out")
	var camp_tamsin: Npc = _named(m, "Npc_Tamsin")
	_check(camp_tamsin and not camp_tamsin.present, "Tamsin isn't at the camp yet")
	# Hilde's first talk: quests, a rune for a party that has none
	_place(m, hilde.get_cell() + Vector2i(1, 0))
	m.talk_to(hilde)
	for i in 3:
		m.hud.dialogue.pick(0)
		await _frames(2)
	_check(Quest.has_flag("met_hilde") and Quest.side_given("sunfire") and Quest.side_given("tamsin"), "Hilde: met, two side quests given")
	_check(m.inventory.has("rune_of_return") and RunePortal.bound, "a new party gets a Rune of Return, bound to her camp")
	m.hud.dialogue.close()
	# rebinding: a rune from an earlier adventure
	RunePortal.bound = false
	m.talk_to(hilde)
	var bind_i := m.hud.dialogue.choice_texts().find("1. Bind our rune")
	if bind_i < 0:
		for i in m.hud.dialogue.choice_texts().size():
			if "Bind our rune" in m.hud.dialogue.choice_texts()[i]:
				bind_i = i
	_check(bind_i >= 0, "an unbound rune: Hilde offers to bind it")
	m.hud.dialogue.pick(bind_i)
	_check(RunePortal.bound and RunePortal.home_map() == mod.portal_home_map, "the rune is bound to her camp")
	m.hud.dialogue.close()
	var stairs: Stairs = _named(m, "Stairs_Tower")
	_check(stairs and stairs.tower and stairs.target_map == MAPS + "tower_1.tscn", "the tower's door leads up")
	PartyState.save(m)
	MapState.save(m)

	# --- tower 1: the mimic, the rune ---------------------------------------------------------------------
	m = await _open(MAPS + "tower_1.tscn")
	_check(m.floor_layer.tile_set.resource_path.ends_with("tower_tileset.tres") and Quest.is_done("tower"), "the tower: its own tiles, quest stage done")
	var mimic: Chest = null
	for c: Chest in _all(m, Chest):
		if c.mimic:
			mimic = c
	_check(mimic != null, "a mimic among the chests")
	_check(m.use_rune() == "" and RunePortal.active, "the rune opens a portal in the tower")
	_place(m, mimic.get_cell() + Vector2i(0, 1))
	m.combat.set_process(true)
	m.try_open_chest(mimic, m.party)
	await _frames(20)
	_check(_monster(m, "mimic") != null and (m.combat.in_combat or m.combat._starting), "opening it: a Mimic attacks")
	_check(not mimic.is_shown(), "the chest is gone")
	m.combat.end_combat()
	m.combat.set_process(false)

	# --- tower 2: the orrery levers ------------------------------------------------------------------------
	m = await _open(MAPS + "tower_2.tscn")
	var orrery: Puzzle = _named(m, "Puzzle_N")
	var levers := {}
	for l: Lever in _all(m, Lever):
		if l.link == orrery.link:
			levers[l.symbol_name()] = l
	for s in ["moon", "star", "eye"]:
		m.mech.pull(levers[s], m.party[0])
	await create_timer(0.3).timeout
	_check(orrery.solved and _door_with_link(m, "t2_vault").is_open, "moon, star, eye: the vault opens")
	_check(_all(m, Chest).any(func(c): return "rime_key" in c.items), "the Rime Key is in the archive")

	# --- tower 3: Tamsin --------------------------------------------------------------------------------------
	m = await _open(MAPS + "tower_3.tscn")
	var tamsin: Npc = _named(m, "Npc_Tamsin")
	var pens: Puzzle = _named(m, "Puzzle_K")
	var cell := _door_with_link(m, "tamsin_cell")
	_check(tamsin and tamsin.present and cell and not cell.is_open, "Tamsin, behind bars")
	m.talk_to(tamsin)
	m.hud.dialogue.pick(0)
	_check(Quest.has_flag("met_tamsin") and Quest.side.tamsin.done.has("find"), "talking to her: found")
	m.mech.solve(pens)
	await create_timer(0.3).timeout
	_check(cell.is_open and Quest.has_flag("tamsin_free"), "the pens' puzzle opens her cell")
	m.talk_to(tamsin)
	m.hud.dialogue.pick(0)
	m._npc_t = 0.0
	await create_timer(0.8).timeout
	_check(Quest.has_flag("tamsin_left") and not tamsin.present, "freed, she heads down to the camp")
	var locked := false
	for d: Door in _all(m, Door):
		if d.key_id == "rime":
			locked = d.locked
	_check(locked, "the stair up is locked with the Rime Key")

	# --- tower 4: the ring of frost fires, the lantern, the Star Key ------------------------------------
	m = await _open(MAPS + "tower_4.tscn")
	var ring: Puzzle = _named(m, "Puzzle_L")
	var fires: Array = _all(m, Brazier).filter(func(b): return b.link == ring.link)
	fires.sort_custom(func(a, b): return a.order < b.order)
	# lit [0, 1, 0, 0, 1]: brute-force the presses (each brazier at most once)
	var start := fires.map(func(b): return b.lit)
	var found := []
	for mask in 32:
		var st: Array = start.duplicate()
		for i in 5:
			if mask & (1 << i):
				for j in [i - 1, i, i + 1]:
					st[posmod(j, 5)] = not st[posmod(j, 5)]
		if st.all(func(v): return v):
			for i in 5:
				if mask & (1 << i):
					found.append(i)
			break
	_check(not found.is_empty(), "the ring can be solved (%s)" % str(found))
	for i in found:
		m.mech.toggle_brazier(fires[i])
	await create_timer(0.3).timeout
	_check(ring.solved and _door_with_link(m, "t4_vault").is_open, "all five lit: the reliquary opens")
	_check(_all(m, Chest).any(func(c): return "sunfire_lantern" in c.items), "the Sunfire Lantern is in the reliquary")
	_check(_all(m, Chest).any(func(c): return "star_key" in c.items), "the Star Key is with the guard captain")

	# --- tower 5: the riddle, the Rimecaller ------------------------------------------------------------
	m = await _open(MAPS + "tower_5.tscn")
	var face: StoneFace = _named(m, "StoneFace_K")
	var hoard := _door_with_link(m, "t5_riddle")
	m.mech.talk_to_face(face)
	m.hud.dialogue.pick(face.correct)
	await create_timer(0.3).timeout
	_check(face.solved and hoard.is_open, "\"Ice\": the hoard's secret door opens")
	var star := false
	for d: Door in _all(m, Door):
		if d.key_id == "star":
			star = d.locked
	_check(star, "the observatory is locked with the Star Key")
	var boss := _monster(m, "frost_wizard")
	_check(boss != null and boss.stats.powers.size() == 4, "Morvaine the Rimecaller waits in the observatory")

	# --- the new rules in a fight -----------------------------------------------------------------------
	for h in m.party:
		h.set_level(9)
		h.refresh_stats()
		h.hp = h.stats.max_hp
		h.reset_resources()
	var f := m.party[0]
	var rogue := m.party[1]
	var cleric := m.party[2]
	_check(f.level == 9 and f.uses_left.get("indomitable", 0) == 1 and cleric.uses_left.get("turn_undead", 0) == 2, "level 9: Indomitable, two Channel Divinity")
	# Death Ward
	cleric.add_condition("death_ward", -1)
	m.combat.apply_damage(cleric, cleric.hp + 5, "cold")
	_check(cleric.hp == 1 and not cleric.has_condition("death_ward"), "Death Ward: 1 HP instead of 0, then gone")
	# Indomitable: a guaranteed failure gets a reroll
	var dc := 40
	m.combat.save_vs(f, "WIS", dc)
	_check(f.uses_left.get("indomitable", 0) == 0, "Indomitable rerolls a failed save (once)")
	# Evasion: an area DEX save
	var fb: SpellData = load("res://data/spells/mage_fireball.tres")
	var dmg := DiceRoll.new()
	dmg.total = 20
	var pre := DiceRoll.new()
	pre.total = 99
	rogue.hp = rogue.stats.max_hp
	m.combat.order.assign([rogue])
	m.combat._spell_save(boss, fb, rogue, dmg, pre)
	_check(rogue.hp == rogue.stats.max_hp, "Evasion: a made DEX save against a Fireball does nothing")
	pre.total = 0
	m.combat._spell_save(boss, fb, rogue, dmg, pre)
	_check(rogue.stats.max_hp - rogue.hp == 10, "Evasion: a failed one does half (%d)" % (rogue.stats.max_hp - rogue.hp))
	# troll regeneration, stopped by fire
	m = await _open(MAPS + "tower_4.tscn")
	var troll := _monster(m, "troll")
	troll.hp = 30
	m.combat._start_of_turn(troll)
	_check(troll.hp == 40, "a troll regenerates 10 HP at the start of its turn")
	m.combat.apply_damage(troll, 5, "fire")
	m.combat._start_of_turn(troll)
	_check(troll.hp == 35, "... but not after fire")
	m.combat._start_of_turn(troll)
	_check(troll.hp == 45, "... and again the turn after")
	# the AI breathes on a crowd: a winter wolf with three heroes in its cone
	var wolf := _monster(m, "winter_wolf")
	var cone := Targeting.cone_cells(wolf.cell, wolf.cell + Vector2i(3, 0), 3)
	var spots: Array[Vector2i] = []
	for c in cone:
		if m.terrain_walkable(c) and m.actor_at(c) == null and spots.size() < 3:
			spots.append(c)
	for i in spots.size():
		m.party[i].place_at(spots[i])
	m.party[3].place_at(wolf.cell + Vector2i(-6, -6))
	m.combat.order.assign(m.party + [wolf])
	m.combat.move_left = 0
	var breath: SpellData = wolf.stats.powers[0]
	var v := m.combat._damage_power_value(wolf, breath, m.party[0], wolf.cell)
	_check(v > Dice.average(breath.damage) * 1.5 and spots.size() == 3,
			"the AI values the breath on three heroes well above one target (%.1f)" % v)
	var plan := m.combat.plan_monster_turn(wolf)
	_check(plan.power == breath, "a winter wolf breathes on the crowd rather than biting one")
	# Divine Strike
	var c8 := m.party[2]
	c8.set_level(8)
	c8.refresh_stats()
	_check(c8.stats.divine_strike == "1d8", "Cleric 8: Divine Strike")
	# flesh golem: nonmagical weapons do nothing
	var golem := _monster(m, "flesh_golem")
	_check(golem != null and "immune_nonmagical" in golem.stats.traits and "lightning" in golem.stats.immunities, "flesh golem: immune to lightning and nonmagical weapons")

	# --- the ending -------------------------------------------------------------------------------------
	m = await _open(MAPS + "frostfell.tscn")
	Quest.note_kill("frost_wizard")
	m.quest_check()
	_check(Quest.reward_due(), "the Rimecaller is dead: Hilde owes the reward")
	hilde = _named(m, "Npc_Hilde")
	hilde.present = true
	m.inventory.add("sunfire_lantern")
	m.quest_check()
	_check(Quest.side_reward_due("sunfire"), "the lantern found: Hilde will take it back")
	var gold0 := m.inventory.gold
	HildeTalk._lantern(m, hilde)
	_check(Quest.side_claimed("sunfire") and not m.inventory.has("sunfire_lantern") and m.inventory.gold == gold0 + 1500
			and m.inventory.has("cloak_protection"), "the lantern returned: 1500 gold and a Cloak of Protection")
	HildeTalk._reward(m, hilde)
	_check(Quest.claimed and m.inventory.has("amulet_health"), "the jarl's reward: gold and an Amulet of Health")
	m.hud.dialogue.pick(0)
	await _frames(5)
	_check(m.victory_screen and m.victory_screen.visible, "... then the victory screen")
	get_root().get_tree().paused = false

	print("test_frost: %s (%d failed)" % ["ALL PASS" if fails == 0 else "FAILURES", fails])
	quit(1 if fails else 0)
