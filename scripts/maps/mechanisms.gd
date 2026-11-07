class_name Mechanisms
extends Node
## Phase 6 dungeon features on a map: traps (spotting, springing, disarming), Search (F), secret
## doors, levers, pressure plates, puzzles, pushable blocks, the riddle stone face, room notes,
## ambushes (Trigger: hidden monsters appear, a portcullis may seal the room) and lore to read (LoreNote).
## Made by DungeonMap (map.mech). The PartyController / CombatManager ask it what is under the
## mouse and tell it when someone has stepped; it opens doors through `fire(link)`.
##
## Wiring is by `link` strings: a Lever / PressurePlate / Brazier / pushable block with link L is an
## input of the Puzzle whose link is L (the puzzle then opens the doors whose link is its `opens`);
## without a Puzzle, the inputs drive the doors with link L directly (a lever down / a plate held
## = open). A StoneFace and a RoomNote fire their own link.

const SPOT_RANGE := 4        ## passive Perception notices traps and secret doors this close (in sight)
const SEARCH_RANGE := 5      ## Search reaches this far from each hero
const NO_CELL := Vector2i(-99999, -99999)
const COL_FOUND := Color8(255, 220, 120)
const COL_DANGER := Color8(255, 90, 60)
const COL_GOOD := Color8(140, 220, 130)

var map: DungeonMap
var traps: Array[Trap] = []
var plates: Array[PressurePlate] = []
var notes: Array[RoomNote] = []
var triggers: Array[Trigger] = []
## Things the player uses (levers, linked braziers, blocks, plates, stone faces): walls in front of
## them fade while they are in sight (DungeonMap), so nothing important hides behind a wall.
var pieces: Array[MapMarker] = []
var _busy := false           ## a lever sequence is springing back


## Collect the map's mechanisms (after MapState.restore) and settle the plates quietly.
func setup(m: DungeonMap) -> void:
	map = m
	for n in map.entities.get_children():
		if n is Trap:
			traps.append(n)
		elif n is PressurePlate:
			plates.append(n)
		elif n is RoomNote:
			notes.append(n)
		elif n is Trigger:
			triggers.append(n)
		if n is Lever or n is StoneFace or n is PressurePlate or n is LoreNote or (n is Brazier and n.link != "") or (n is Prop and n.pushable):
			pieces.append(n)
	# a sprung ambush whose monsters still live (the party left, or saved mid-fight): the seal is down
	for t in triggers:
		if t.fired and not t.done and t.seal != "":
			for d: Door in _all(Door):
				if d.link == t.seal:
					d.is_open = false
	update_plates(true)


func _combat() -> CombatManager:
	return map.combat


func _say(text: String) -> void:
	if map.combat:
		map.combat._say(text)


func _conscious() -> Array[Hero]:
	var out: Array[Hero] = []
	for h in map.party:
		if h.is_alive():
			out.append(h)
	return out


func _all(type: Variant) -> Array:
	return map.entities.get_children().filter(func(n): return is_instance_of(n, type))


# --- what is where -----------------------------------------------------------------------------

func trap_at(cell: Vector2i) -> Trap:
	for t in traps:
		if t.get_cell() == cell:
			return t
	return null


## A known, armed trap the party's paths go round.
func trap_blocks(cell: Vector2i) -> bool:
	var t := trap_at(cell)
	return t != null and t.blocks_party()


func puzzle_for(link: String) -> Puzzle:
	if link == "":
		return null
	for n in map.entities.get_children():
		if n is Puzzle and n.link == link:
			return n
	return null


func _inputs(link: String, type: Variant) -> Array:
	return map.entities.get_children().filter(func(n): return is_instance_of(n, type) and n.link == link)


## The thing the player can use under a world point (exploring or in a fight): a known armed trap,
## a lever, a linked brazier, a pushable block, a stone face. Only what the party has seen.
func thing_under(pos: Vector2) -> MapMarker:
	var cell := IsoGrid.world_to_cell(pos)
	var best: MapMarker = null
	for n in map.entities.get_children():
		if not n is MapMarker or not n.visible or not map.is_explored(n.get_cell()):
			continue
		var hit := false
		if n is Trap:
			hit = n.blocks_party() and n.get_cell() == cell
		elif n is Lever or n is StoneFace or n is LoreNote:
			hit = n.get_cell() == cell or n.sprite_rect().has_point(pos)
		elif n is Brazier:
			hit = n.link != "" and (n.get_cell() == cell or n.sprite_rect().has_point(pos))
		elif n is Prop:
			hit = n.pushable and (n.get_cell() == cell or n.sprite_rect().has_point(pos))
		if hit and (best == null or n.position.y > best.position.y or best is Trap):
			best = n
	return best


## Cells the leader stands on to use `thing`.
func approach_cells(thing: MapMarker) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if thing is Prop:
		for d: Vector2i in DungeonMap.NEIGHBOURS:
			var side: Vector2i = thing.get_cell() - d
			if push_target(thing, side) != NO_CELL:
				out.append(side)
		return out
	for d: Vector2i in DungeonMap.DIRS8:
		var c: Vector2i = thing.get_cell() + d
		if not trap_blocks(c):
			out.append(c)
	return out


func hint(thing: MapMarker) -> String:
	if thing is Prop:
		return thing.hint() if not map.party.is_empty() else ""
	return thing.hint()


## Use `thing` (the leader is next to it). Exploring; in a fight the CombatManager calls the parts
## it allows (pull, disarm).
func interact(thing: MapMarker) -> void:
	if map.party.is_empty():
		return
	var lead := map.party[0]
	lead.facing = (thing.get_cell() - lead.cell).clampi(-1, 1)
	if thing is Trap:
		try_disarm(thing, map.party)
	elif thing is Lever:
		pull(thing, lead)
	elif thing is Brazier:
		toggle_brazier(thing)
	elif thing is Prop:
		push(thing)
	elif thing is StoneFace:
		talk_to_face(thing)
	elif thing is LoreNote:
		read_lore(thing)


# --- stepping ----------------------------------------------------------------------------------

## After a step of the party (exploring): a hidden trap under a hero goes off, plates update, a
## room note may show. True = stop walking.
func after_party_step() -> bool:
	var stop := false
	for h in _conscious():
		var t := trap_at(h.cell)
		if t and t.armed() and not t.known():
			spring(t, h)
			stop = true
			break
	update_plates()
	if check_triggers():
		return true
	if check_notes():
		stop = true
	return stop


## After a step in a fight: a hero (not a monster: they know their traps) on a hidden trap sets it
## off. True = stop moving.
func after_combat_step(who: Actor) -> bool:
	var stop := false
	if who is Hero and who.is_alive():
		var t := trap_at(who.cell)
		if t and t.armed() and not t.known():
			spring(t, who)
			stop = true
	update_plates()
	if who is Hero and check_triggers():
		stop = true
	return stop


## The party has moved or the fog changed: passive Perception may notice hidden traps and secret
## doors in sight nearby.
func spot_check() -> void:
	var heroes := _conscious()
	if heroes.is_empty():
		return
	for t in traps:
		if t.armed() and not t.known():
			var h := _spotter(heroes, t.get_cell(), t.detect_dc)
			if h:
				_found_trap(t, h, "%s spots a hidden %s!" % [h.display_name(), t.trap_name()])
	for d: Door in _all(Door):
		if d.is_hidden():
			var h := _spotter(heroes, d.get_cell(), d.secret_dc)
			if h:
				_found_secret(d, "%s notices a thin draught through the stonework: a secret door!" % h.display_name())
	for c: Chest in _all(Chest):
		if c.mimic and not c.opened and not c.mimic_spotted:
			var h := _spotter(heroes, c.get_cell(), 15)
			if h:
				c.mimic_spotted = true
				_say("%s watches the chest... and sees its lid rise and fall. It's breathing. A mimic!" % h.display_name())
				Sfx.play("discover")
				FloatText.spawn(map, c.position + Vector2(0, -16), "!", COL_DANGER, 20)


## The hero whose passive Perception notices something at `cell` (in sight, close), or null.
func _spotter(heroes: Array[Hero], cell: Vector2i, dc: int) -> Hero:
	if not map.is_seen(cell):
		return null
	var best: Hero = null
	for h in heroes:
		if DungeonMap.grid_distance(h.cell, cell) > SPOT_RANGE or h.stats.passive_perception() < dc:
			continue
		if h.cell != cell and not map.has_line_of_sight(h.cell, cell):
			continue
		if best == null or h.stats.passive_perception() > best.stats.passive_perception():
			best = h
	return best


func _found_trap(t: Trap, _by: Hero, line: String) -> void:
	HelpBox.tip("trap_spotted")
	t.spotted = true
	map._refresh_fog_look()             # now it is drawn
	_say(line)
	Sfx.play("discover")
	FloatText.spawn(map, IsoGrid.cell_to_world(t.get_cell()) + Vector2(0, -6), "!", COL_DANGER, 20)
	if map.controller:
		map.controller.stop()            # don't walk on into it
	map.refresh_navigation()


func _found_secret(d: Door, line: String) -> void:
	HelpBox.tip("secret_door")
	d.found = true
	if map.map_picture:
		map.map_picture.dirty = true
	_say(line)
	Sfx.play("discover")
	FloatText.spawn(map, d.position + Vector2(0, -30), "!", COL_FOUND, 20)
	SpellFx.sparkles(map, d.position + Vector2(0, -20), COL_FOUND, false)


## Search (F, exploring): every conscious hero looks around (Perception or Investigation, whichever
## is better) and the best roll is checked against every hidden trap and secret door in sight
## within SEARCH_RANGE. Returns "" or why the party can't search now.
func search() -> String:
	if _combat().in_combat:
		return "No time to search in the middle of a fight!"
	var heroes := _conscious()
	if heroes.is_empty():
		return "Nobody is in a state to search."
	var best := -99
	var who: Hero = null
	var skill := ""
	for h in heroes:
		var sk := "perception" if h.stats.skill_bonus("perception") >= h.stats.skill_bonus("investigation") else "investigation"
		var r := Dice.d20(h.stats.skill_bonus(sk))
		map.combat._detail("search: %s %s %s" % [h.display_name(), sk, r.describe()])
		FloatText.spawn(map, h.body_position() + Vector2(0, -16), "?", COL_FOUND, 10)
		if r.total > best:
			best = r.total
			who = h
			skill = sk
	_say("The party searches the area (best: %s, %s %d)." % [who.display_name(), skill.capitalize(), best])
	var found := 0
	for t in traps:
		if t.armed() and not t.known() and _searchable(heroes, t.get_cell()) and best >= t.detect_dc:
			_found_trap(t, who, "%s finds a hidden %s!" % [who.display_name(), t.trap_name()])
			found += 1
	for d: Door in _all(Door):
		if d.is_hidden() and _searchable(heroes, d.get_cell()) and best >= d.secret_dc:
			_found_secret(d, "%s finds a secret door in the wall!" % who.display_name())
			found += 1
	if found == 0:
		_say("Nothing out of the ordinary.")
		Sfx.play("search")
	return ""


func _searchable(heroes: Array[Hero], cell: Vector2i) -> bool:
	if not map.is_seen(cell):
		return false
	for h in heroes:
		if DungeonMap.grid_distance(h.cell, cell) <= SEARCH_RANGE:
			return true
	return false


# --- traps -------------------------------------------------------------------------------------

## The trap goes off on `victim` (who stepped on it, or fumbled disarming it).
func spring(t: Trap, victim: Actor) -> void:
	HelpBox.tip("trap_sprung")
	t.sprung = true
	t.spotted = true
	map._refresh_fog_look()
	if t.armed():
		t.flash_sprung()                 # spikes drop back down, the plate resets
	var cell := t.get_cell()
	var at := IsoGrid.cell_to_world(cell)
	var who := victim.display_name()
	match t.trap_type:
		Trap.TrapType.SPIKES:
			Sfx.play("trap_spikes")
			_say("Click! Spikes shoot up under %s!" % who)
			_trap_hit(t, victim, false)
		Trap.TrapType.DARTS:
			Sfx.play("trap_darts")
			_say("Click! Darts fly out of the walls at %s!" % who)
			for k in 3:
				var from := victim.body_position() + Vector2([-60, 50, -20][k], [-30, -24, -50][k])
				SpellFx.dart(map, from, victim.body_position() + Vector2(k - 1, 0), 0.0)
			_trap_hit(t, victim, false)
		Trap.TrapType.FIRE_JET:
			Sfx.play("fire_impact")
			Sfx.play("trap_fire")
			_say("A jet of flame roars up out of the floor!")
			SpellFx.burst(map, at + Vector2(0, -6), 1.2)
			map.scorch.add_mark(cell, 0.7)
			var hit: Array[Actor] = []
			for n in map.entities.get_children():
				if n is Actor and n.is_alive() and DungeonMap.grid_distance(n.cell, cell) <= 1:
					hit.append(n)
			if not victim in hit:
				hit.append(victim)
			for a in hit:
				_trap_hit(t, a, true)
		Trap.TrapType.PIT:
			Sfx.play("trap_pit")
			_say("The floor gives way under %s!" % who)
			_trap_hit(t, victim, false, "catches the edge of the pit", "falls into the pit")
			if victim.sprite:
				var tw := victim.create_tween()
				tw.tween_property(victim.sprite, "position:y", 6.0, 0.12)
				tw.tween_property(victim.sprite, "position:y", 0.0, 0.5).set_delay(0.5)
		Trap.TrapType.ALARM:
			Sfx.play("trap_alarm")
			_alarm(victim)
	map.refresh_navigation()


## Damage from a trap: an attack roll (darts) or a save (half on a success if `half`, else none).
func _trap_hit(t: Trap, victim: Actor, half: bool, dodge := "leaps clear", hurt_words := "") -> void:
	if t.damage == "":
		return
	var dr := Dice.roll(t.damage)
	var dmg := dr.total
	if t.attack_bonus > 0:
		var r := Dice.d20(t.attack_bonus)
		var hit := r.natural == 20 or (r.natural != 1 and r.total >= victim.stats.armor_class)
		map.combat._detail("  trap attack %s vs AC %d: %s" % [r.describe(), victim.stats.armor_class, "hit" if hit else "miss"])
		if not hit:
			_say("They miss %s." % victim.display_name())
			FloatText.spawn(map, victim.body_position() + Vector2(0, -14), "MISS", Color8(200, 200, 210), 10)
			return
	else:
		var s := map.combat.save_vs(victim, t.save_ability, t.save_dc, true)
		var ok := s.total >= t.save_dc
		# Evasion (Rogue 7): a DEX save for half does nothing on a success, half on a failure.
		if half and t.save_ability == "DEX" and victim.stats.evasion:
			if ok:
				_say("%s twists clear (Evasion)." % victim.display_name())
				return
			dmg /= 2
		map.combat._detail("  %s %s save %s vs DC %d" % [victim.display_name(), t.save_ability, s.describe(), t.save_dc])
		if ok and not half:
			_say("%s %s (%s save %d vs DC %d)." % [victim.display_name(), dodge, t.save_ability, s.total, t.save_dc])
			FloatText.spawn(map, victim.body_position() + Vector2(0, -14), "SAVED", COL_GOOD, 10)
			return
		if ok:
			dmg /= 2
	dmg = map.combat._adjust(dmg, t.damage_type, victim)
	if hurt_words != "":
		_say("%s %s: %d %s damage." % [victim.display_name(), hurt_words, dmg, t.damage_type])
	else:
		_say("%s takes %d %s damage." % [victim.display_name(), dmg, t.damage_type])
	hurt(victim, dmg, t.damage_type)


## Damage outside a weapon or spell (traps, a wrong answer). In a fight it is normal damage; while
## exploring nobody dies of it: a hero who drops is knocked out and comes to with 1 HP a moment
## later (like after a won fight), and massive damage doesn't kill.
func hurt(victim: Actor, dmg: int, dtype: String) -> void:
	if dmg <= 0 or not victim.is_alive():
		return
	var exploring := not _combat().in_combat
	if exploring:
		dmg = mini(dmg, victim.hp + victim.stats.max_hp - 1)
	FloatText.spawn(map, victim.body_position() + Vector2(0, -14), str(dmg), COL_DANGER, 12)
	Sfx.play(map.combat._hit_sound(dtype))
	map.combat.apply_damage(victim, dmg, dtype)
	if not exploring:
		map.combat._check_end()
		return
	if victim is Hero and not victim.is_alive() and not victim.dead:
		victim.stable = true
		_say("%s is knocked out!" % victim.display_name())
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_instance_valid(victim) and not victim.is_alive() and not victim.dead:
				victim.revive(1)
				_say("%s comes to (1 HP)." % victim.display_name()))


## The alarm: the nearest group of monsters comes running (a fight starts with them).
func _alarm(victim: Actor) -> void:
	var best: Monster = null
	for m in map.monsters:
		if m.is_alive() and DungeonMap.grid_distance(m.cell, victim.cell) <= 30 \
				and (best == null or DungeonMap.grid_distance(m.cell, victim.cell) < DungeonMap.grid_distance(best.cell, victim.cell)):
			best = m
	if best == null:
		_say("A bell jangles on the tripwire... but nobody comes.")
		return
	if _combat().in_combat:
		_say("A bell jangles on the tripwire!")
		return
	_say("A bell jangles on the tripwire! %s come running!" % (best.display_name() + "s" if not best.display_name().ends_with("s") else best.display_name()))
	if victim is Hero:
		_combat().start_combat(best, victim)


## Disarm a known trap: the Rogue (thieves' tools) if standing, else whoever is best at it (DEX).
## Fail by 5 or more and it goes off on them. Returns true if it is now disarmed.
func try_disarm(t: Trap, by: Array[Hero]) -> bool:
	var able := by.filter(func(h: Hero): return h.is_alive())
	if able.is_empty() or not t.armed():
		return false
	var who: Hero = able[0]
	for h: Hero in able:
		if h.hero_class == Hero.HeroClass.ROGUE or h.stats.skill_bonus("thieves_tools") > who.stats.skill_bonus("thieves_tools"):
			who = h
			if h.hero_class == Hero.HeroClass.ROGUE:
				break
	var r := Dice.d20(who.stats.skill_bonus("thieves_tools"))
	if r.total >= t.disarm_dc:
		t.disarmed = true
		_say("%s disarms the %s (%s vs DC %d)." % [who.display_name(), t.trap_name(), r.describe(), t.disarm_dc])
		Sfx.play("lock_click")
		SpellFx.sparkles(map, IsoGrid.cell_to_world(t.get_cell()), COL_GOOD, false)
		map.refresh_navigation()
		award(t.xp)
		return true
	if r.total <= t.disarm_dc - 5:
		_say("%s fumbles the %s (%s vs DC %d) and sets it off!" % [who.display_name(), t.trap_name(), r.describe(), t.disarm_dc])
		spring(t, who)
		return false
	_say("%s can't disarm the %s (%s vs DC %d). Try again?" % [who.display_name(), t.trap_name(), r.describe(), t.disarm_dc])
	Sfx.play("door_locked")
	return false


## XP for a disarmed trap or a solved puzzle (shared like a fight's; level-ups shown at once).
func award(xp: int) -> void:
	if xp <= 0:
		return
	var ups := map.award_xp(xp)
	_say("+%d XP" % xp)
	for u in ups:
		_say("%s reaches level %d!" % [u.hero.display_name(), u.level])
	if not ups.is_empty():
		if _combat().in_combat:
			_combat().pending_level_ups.append_array(ups)
		else:
			_combat().level_ups.emit(ups)


# --- doors on links --------------------------------------------------------------------------------

## Open (on) or let drop (off: portcullises only) the doors whose link is `channel`.
func fire(channel: String, on: bool) -> void:
	if channel == "":
		return
	for d: Door in _all(Door):
		if d.link != channel:
			continue
		if on and not d.is_open:
			if not map.is_seen(d.get_cell()):
				_say("Somewhere close, %s." % ("iron chains rattle" if d.style == Door.Style.PORTCULLIS else "stone grinds against stone"))
			d.open()
			SpellFx.sparkles(map, d.position + Vector2(0, -16), Color8(200, 200, 210), false)
		elif not on and d.is_open and d.style == Door.Style.PORTCULLIS:
			if map.occupant(d.get_cell()) == null:
				d.close()


# --- levers, plates, braziers, puzzles -----------------------------------------------------------

## Pull a lever (`who` pulled it: a wrong lever's penalty hits them).
func pull(lever: Lever, who: Actor) -> void:
	if _busy:
		return
	HelpBox.tip("puzzle")
	if lever.role == "reset":
		Sfx.play("lever")
		lever.down = true
		get_tree().create_timer(0.5).timeout.connect(func(): lever.down = false)
		reset_puzzle(lever.link)
		return
	var p := puzzle_for(lever.link)
	if p and p.solved:
		_say("The lever won't move: the mechanism is locked in place.")
		Sfx.play("door_locked")
		return
	if p and p.kind == Puzzle.Kind.SEQUENCE:
		if lever.down:
			_say("The %s lever is stuck down." % lever.symbol_name())
			Sfx.play("door_locked")
			return
		lever.down = true
		Sfx.play("lever")
		p.progress.append(lever.symbol_name())
		var want := p.steps()
		var i := p.progress.size() - 1
		if i >= want.size() or want[i] != p.progress[i]:
			_wrong_sequence(p, who)
		elif p.progress.size() == want.size():
			solve(p)
		else:
			_say("The %s lever locks down with a clack." % lever.symbol_name())
		return
	lever.down = not lever.down
	Sfx.play("lever")
	if p:
		evaluate(p)
	else:
		fire(lever.link, _inputs(lever.link, Lever).any(func(l: Lever): return l.down))


func _wrong_sequence(p: Puzzle, who: Actor) -> void:
	_busy = true
	await get_tree().create_timer(0.5).timeout
	_busy = false
	Sfx.play("puzzle_fail")
	_say("Clunk! Something inside the wall jams, and the levers spring back up.")
	for l: Lever in _inputs(p.link, Lever):
		l.down = false
	p.progress.clear()
	if p.penalty != "" and is_instance_valid(who) and who.is_alive():
		var dmg := Dice.roll(p.penalty).total
		_say("A dart flicks out of the wall at %s!" % who.display_name())
		SpellFx.dart(map, who.body_position() + Vector2(-50, -30), who.body_position(), 0.0)
		hurt(who, map.combat._adjust(dmg, p.penalty_type, who), p.penalty_type)


## Which cells are pressed down: anyone standing (heroes, also downed ones; monsters) and blocks.
func _weights() -> Dictionary:
	var w := {}
	for n in map.entities.get_children():
		if n is Actor and (n.is_alive() or (n is Hero and not n.dead)):
			w[n.cell] = true
		elif n is Prop and n.pushable:
			w[n.get_cell()] = true
	return w


## Bring every plate up to date; links whose plates changed re-evaluate.
func update_plates(quiet := false) -> void:
	if plates.is_empty():
		return
	var w := _weights()
	var changed := {}
	for p in plates:
		var now := w.has(p.get_cell())
		if now != p.pressed:
			p.pressed = now
			changed[p.link] = true
			if not quiet:
				Sfx.play("plate_click", -4.0, 1.0 if now else 0.85)
	if quiet:
		return
	for link: String in changed:
		var pz := puzzle_for(link)
		if pz:
			evaluate(pz)
		else:
			fire(link, _inputs(link, PressurePlate).any(func(pp: PressurePlate): return pp.pressed))


## Light or douse a brazier; in a RING puzzle its two neighbours flip too.
func toggle_brazier(b: Brazier) -> void:
	HelpBox.tip("puzzle")
	var p := puzzle_for(b.link)
	if p and p.solved:
		_say("The flames burn steady and bright. Best leave them be.")
		return
	var flip: Array[Brazier] = [b]
	if p and p.kind == Puzzle.Kind.RING:
		var ring: Array = _inputs(b.link, Brazier)
		ring.sort_custom(func(x: Brazier, y: Brazier): return x.order < y.order)
		var i := ring.find(b)
		var n := ring.size()
		if n >= 3:
			flip = [ring[(i - 1 + n) % n], b, ring[(i + 1) % n]]
	for f in flip:
		f.lit = not f.lit
		SpellFx.sparkles(map, f.position + Vector2(0, -16), Color8(255, 170, 80) if f.lit else Color8(120, 120, 130), false)
	Sfx.play("flame_whoosh")
	if flip.size() > 1:
		_say("The brazier %s, and the fires on either side of it flicker in answer." % ("flares up" if b.lit else "gutters out"))
	if p:
		evaluate(p)


## ALL_ON / RING: solved once every input is on at the same time.
func evaluate(p: Puzzle) -> void:
	if p.solved or p.kind == Puzzle.Kind.SEQUENCE:
		return
	var inputs := 0
	for n in map.entities.get_children():
		if n is Lever and n.link == p.link and n.role == "":
			inputs += 1
			if not n.down:
				return
		elif n is PressurePlate and n.link == p.link:
			inputs += 1
			if not n.pressed:
				return
		elif n is Brazier and n.link == p.link:
			inputs += 1
			if not n.lit:
				return
	if inputs > 0:
		solve(p)


func solve(p: Puzzle) -> void:
	if p.solved:
		return
	p.solved = true
	Sfx.play("puzzle_solved")
	_say(p.solved_text)
	if p.flag != "":
		Quest.set_flag(p.flag)
		map.quest_check()
	if not map.party.is_empty():
		FloatText.spawn(map, map.party[0].body_position() + Vector2(0, -22), "SOLVED!", COL_FOUND, 12)
	fire(p.opens, true)
	award(p.xp)


## A reset lever: the link's blocks slide back where they started (if their cell is free), its
## levers go up, an unsolved puzzle forgets its progress.
func reset_puzzle(link: String) -> void:
	var p := puzzle_for(link)
	if p and p.solved:
		_say("Nothing happens: the puzzle is solved.")
		return
	var moved := 0
	var stuck := 0
	for b: Prop in _inputs(link, Prop):
		if not b.pushable or b.get_cell() == b.start_cell:
			continue
		if map.occupant(b.start_cell) != null:
			stuck += 1
			continue
		var tw := create_tween()
		tw.tween_property(b, "position", b.move_to_cell(b.start_cell), 0.5)
		moved += 1
	for l: Lever in _inputs(link, Lever):
		if l.role == "":
			l.down = false
	if p:
		p.progress.clear()
	Sfx.play("stone_slide")
	if stuck > 0:
		_say("Gears grind, but someone is standing where a block wants to go back to.")
	else:
		_say("With a long grinding, the blocks slide back where they started." if moved > 0 else "Gears grind inside the walls.")
	map.invalidate_static()
	map.refresh_navigation()
	get_tree().create_timer(0.55).timeout.connect(update_plates)


# --- pushable blocks ---------------------------------------------------------------------------

## Where `block` goes if pushed by someone standing at `from` (one cell straight on), or NO_CELL.
func push_target(block: Prop, from: Vector2i) -> Vector2i:
	var d := block.get_cell() - from
	if absi(d.x) + absi(d.y) != 1:
		return NO_CELL
	var dest := block.get_cell() + d
	if not map.terrain_walkable(dest) or not map.is_explored(dest) or map.occupant(dest) != null:
		return NO_CELL
	if map.stairs_at(dest) or map.door_at(dest) or map.portal_at(dest) or trap_blocks(dest):
		return NO_CELL
	return dest


## The leader pushes the block one cell on and steps into its place (the party follows).
func push(block: Prop) -> void:
	HelpBox.tip("puzzle")
	if _combat().in_combat:
		_say("No time for that now!")
		return
	var lead := map.party[0]
	var dest := push_target(block, lead.cell)
	if dest == NO_CELL:
		_say("The block won't budge that way.")
		Sfx.play("door_locked", -6.0)
		return
	var old := block.get_cell()
	var tw := create_tween()
	tw.tween_property(block, "position", block.move_to_cell(dest), 0.3)
	Sfx.play("stone_push")
	map.invalidate_static()
	map.refresh_navigation()
	update_plates()
	if map.controller:
		map.controller.walk_to(old)


# --- the stone face ----------------------------------------------------------------------------

func talk_to_face(f: StoneFace) -> void:
	if map.hud == null:
		return
	HelpBox.tip("riddle")
	map.hud.close_screens()
	map.hud.frame_speaker(f)
	var bye := {text = "Leave", call = map.hud.dialogue.close, bye = true}
	if f.solved:
		map.hud.dialogue.say(f.display_name, f.portrait(), "The stone face is silent now. Its eyes glow a calm green.", [bye])
		return
	var choices := []
	for i in f.answers.size():
		choices.append({text = f.answers[i], call = _answer.bind(f, i)})
	choices.append(bye)
	map.hud.dialogue.say(f.display_name, f.portrait(), f.riddle, choices)


func _answer(f: StoneFace, i: int) -> void:
	map.hud.dialogue.close()
	var lead := map.party[0] if not map.party.is_empty() else null
	if i == f.correct:
		f.solved = true
		Sfx.play("puzzle_solved")
		_say("\"%s.\" The stone face smiles, and its eyes turn green." % f.answers[i])
		fire(f.link, true)
		award(f.xp)
		return
	f.flare()
	Sfx.play("lightning_crack")
	_say("\"%s?\" The stone face's eyes flare red!" % f.answers[i])
	if lead and lead.is_alive():
		SpellFx.lightning(map, f.position + Vector2(-5, -17), lead.body_position())
		hurt(lead, map.combat._adjust(Dice.roll(f.wrong_damage).total, "lightning", lead), "lightning")


# --- room notes --------------------------------------------------------------------------------

## A hero has walked into an unseen note's area: show it. True if it opened the dialogue box.
func check_notes() -> bool:
	if _combat().in_combat or map.hud == null:
		return false
	for n in notes:
		if n.seen:
			continue
		for h in _conscious():
			if n.area().has_point(h.cell):
				n.seen = true
				return _show_note(n)
	return false


func _show_note(n: RoomNote) -> bool:
	if n.link != "":
		fire(n.link, true)
	if n.modal:
		map.hud.close_screens()
		var icon := AtlasTexture.new()
		icon.atlas = load("res://assets/ui/item_icons.png")
		icon.region = Rect2(ItemData.ICON_ORDER.find("scroll") * 16, 0, 16, 16)
		_say("%s: %s" % [n.title, n.text.replace("\n", " ")])
		map.hud.dialogue.say(n.title, icon, n.text, [{text = "Continue", call = map.hud.dialogue.close, bye = true}])
		return true
	map.hud.caption(n.title, n.text)
	return false


# --- ambushes (Trigger) --------------------------------------------------------------------------

## A hero has stepped: spring any ambush whose area they are in. True if one sprang (stop walking).
func check_triggers() -> bool:
	var heroes := _conscious()
	if heroes.is_empty():
		return false
	for t in triggers:
		if t.fired:
			continue
		var r := t.area()
		var inside := heroes.filter(func(h: Hero): return r.has_point(h.cell))
		if inside.is_empty() or (t.whole_party and inside.size() < heroes.size()):
			continue
		spring_ambush(t)
		return true
	return false


## The ambush: the seal drops, the hidden monsters appear and the fight starts (or they join it).
func spring_ambush(t: Trigger) -> void:
	HelpBox.tip("ambush")
	t.fired = true
	if map.controller:
		map.controller.stop()
	var sealed := 0
	if t.seal != "":
		for d: Door in _all(Door):
			if d.link == t.seal and d.is_open and map.occupant(d.get_cell()) == null:
				d.close()
				sealed += 1
		if sealed > 0:
			Sfx.play("trap_pit", -2.0, 0.7)
			map.camera_controller.shake(3.0, 0.25)
	var woke: Array[Monster] = []
	for n in map.entities.get_children():
		if n is MonsterSpawn and n.ambush == t.link and n.lurking():
			var m := map.wake_ambusher(n, t.how)
			if m:
				woke.append(m)
	if t.text != "":
		if map.hud:
			map.hud.caption("Ambush!", t.text)        # (the caption logs it too)
		else:
			_say(t.text)
	if sealed > 0:
		_say("Behind you, %s slams down!" % ("a portcullis" if sealed == 1 else "the portcullises"))
	map.invalidate_static()
	map.refresh_navigation()
	map._refresh_fog_look()
	if woke.is_empty():
		t.done = true
		return
	Sfx.play("trap_alarm", -6.0, 0.8)
	FloatText.spawn(map, woke[0].body_position() + Vector2(0, -18), "AMBUSH!", COL_DANGER, 12)
	if _combat().in_combat:
		_combat()._check_join()
		return
	var near: Hero = null
	for h in _conscious():
		if near == null or DungeonMap.grid_distance(h.cell, woke[0].cell) < DungeonMap.grid_distance(near.cell, woke[0].cell):
			near = h
	if near:
		# a moment to see them appear, then the fight
		get_tree().create_timer(0.7).timeout.connect(func():
			if is_instance_valid(near) and not _combat().in_combat:
				_combat().start_combat(woke[0], near))


## After a fight: an ambush whose monsters are all dead is over; its seal lifts.
func after_combat() -> void:
	for t in triggers:
		if not t.fired or t.done:
			continue
		var alive := false
		for n in map.entities.get_children():
			if n is MonsterSpawn and n.ambush == t.link and not n.cleared and (n.lurking() or (n.monster and n.monster.is_alive())):
				alive = true
		if alive:
			continue
		t.done = true
		if t.seal != "":
			_say("With a clank of chains, the portcullis grinds back up.")
			fire(t.seal, true)
			map.refresh_navigation()


# --- lore (LoreNote) -------------------------------------------------------------------------------

## Read a book / tablet / dead adventurer's letter in the dialogue box; it goes into the journal.
func read_lore(n: LoreNote) -> void:
	if map.hud == null:
		return
	HelpBox.tip("lore")
	map.hud.close_screens()
	var first := not n.read
	n.read = true
	Quest.add_lore(n.lore_id(), n.title, n.text)
	if n.flag != "" and not Quest.has_flag(n.flag):
		Quest.set_flag(n.flag)
		map.quest_check()
	if first:
		_say("Read: %s (kept in the journal, J)." % n.title)
		Sfx.play("scroll_read", -6.0)
	var icon := AtlasTexture.new()
	icon.atlas = load("res://assets/ui/item_icons.png")
	icon.region = Rect2(ItemData.ICON_ORDER.find("scroll") * 16, 0, 16, 16)
	map.hud.dialogue.say(n.title, icon, n.text, [{text = "Close", call = map.hud.dialogue.close, bye = true}])
