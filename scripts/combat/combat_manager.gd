class_name CombatManager
extends Node
## Switches between exploration and turn-based combat (Phase 2).
##
## Exploration: every DETECT_INTERVAL, each monster that is not yet fighting checks whether it can
## see a hero (grid distance <= its sight range and a clear line of sight). If so, combat starts:
## the party stops, that monster's whole group_id joins, everyone rolls initiative (d20 + DEX;
## ties: higher DEX score, then random) and turns run in that order, round after round.
##
## Step 3: a hero's turn ends with Enter ("end_turn"); monsters just wait. Movement (step 4),
## attacks (5), monster AI (6), the real UI (7) and the end of combat (8) build on this.

signal combat_started
signal turn_started(actor: Actor)
signal combat_ended
## All foes dead (xp = total XP of the monsters beaten) / all heroes down.
signal victory(xp: int)
signal defeat
signal log_line(text: String)
## Short status for the HUD hint line (movement left, controls).
signal status_changed(text: String)

const DETECT_INTERVAL := 0.2
const MONSTER_TURN_PAUSE := 0.8     ## step 3 placeholder: monsters "wait" this long
const STEP_TIME := 0.18             ## s per square while moving in combat (diagonal x1.41)
const COL_ACTIVE := Color8(255, 220, 90)
const COL_RANGE := Color8(90, 150, 255)
const COL_BLOCKED := Color8(255, 80, 60)
const COL_TARGET := Color8(255, 110, 40)

## This turn: squares of movement left, whether the action is used (step 5), moving right now.
var move_left := 0
var action_used := false
var attacks_left := 0
var bonus_used := false
var moving := false
var _reach := {}
var _hover := Vector2i(-99999, -99999)

var map: DungeonMap
var in_combat := false
## The whole party is down: input stops; R restarts the map.
var game_over := false
var round_number := 0
## Initiative order and each combatant's roll.
var order: Array[Actor] = []
var initiative := {}
var current: Actor

var _turn_index := -1
var _detect_t := 0.0
var _pulse_t := 0.0
var _starting := false


func _ready() -> void:
	if not InputMap.has_action("end_turn"):
		InputMap.add_action("end_turn")
		for k: Key in [KEY_ENTER, KEY_KP_ENTER]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event("end_turn", e)


func _process(delta: float) -> void:
	if game_over:
		if Input.is_key_pressed(KEY_R):
			game_over = false
			get_tree().reload_current_scene()
		return
	if not in_combat:
		if _starting:
			return
		_detect_t -= delta
		if _detect_t <= 0.0:
			_detect_t = DETECT_INTERVAL
			_check_detection()
		return
	# Pulse the active combatant's tile (yellow, like the mock-up).
	_pulse_t += delta
	if current:
		var pulse := 0.5 + 0.5 * sin(_pulse_t * TAU / 1.2)
		map.overlay.set_cells("active", [current.cell], COL_ACTIVE, 0.15, 0.55 + 0.4 * pulse)
	if current is Hero and not moving:
		if Input.is_action_just_pressed("end_turn"):
			end_turn()
			return
		var c := IsoGrid.world_to_cell(map.get_local_mouse_position())
		if map.hud and map.hud.mouse_over_ui():
			c = Vector2i(-99999, -99999)
		if c != _hover:
			_hover = c
			_show_preview()


func _unhandled_input(event: InputEvent) -> void:
	if not in_combat or not current is Hero or moving:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var c := IsoGrid.world_to_cell(map.get_local_mouse_position())
		var foe := _enemy_at(c)
		if foe and attacks_left > 0:
			var opt := attack_option(current, foe)
			if not opt.is_empty():
				get_viewport().set_input_as_handled()
				_hero_attack(foe, opt)
			return
		if _reach.has(c) and _reach[c].stop and c != current.cell:
			get_viewport().set_input_as_handled()
			move_along(current, DungeonMap.reach_path(_reach, c))


# --- attacks ---------------------------------------------------------------------------------

## How `attacker` would attack `target` right now: {attack, adv, note} or {} if it can't.
## Melee if in reach; otherwise ranged with line of sight (disadvantage at long range or with an
## enemy adjacent to the shooter).
func attack_option(attacker: Actor, target: Actor) -> Dictionary:
	var best := {}
	var best_ev := -1.0
	for o in attack_options_from(attacker, target, attacker.cell):
		var ev := expected_damage(attacker, target, o)
		if ev > best_ev:
			best_ev = ev
			best = o
	return best


## Expected damage of an attack option (hit chance x average damage, riders included).
func expected_damage(attacker: Actor, target: Actor, o: Dictionary) -> float:
	var a: AttackData = o.attack
	var p := hit_chance(attacker.stats.attack_bonus(a), target.stats.armor_class, o.adv)
	var avg := maxf(1.0, Dice.average(attacker.stats.damage_expr(a)))
	if a.rider_damage != "":
		avg += Dice.average(a.rider_damage) * 0.75       # save for half, roughly
	return p * avg


## Every attack `attacker` could make on `target` if it stood on `from`: [{attack, adv, note}].
func attack_options_from(attacker: Actor, target: Actor, from: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not target.is_alive() or attacker.stats == null:
		return out
	var dist := DungeonMap.grid_distance(from, target.cell)
	var los := -1        # computed lazily
	for a: AttackData in attacker.stats.attacks:
		if a.damage == "0" or a.damage == "":
			continue                       # e.g. the spider's Web: a condition attack (Phase 3)
		if a.kind == AttackData.Kind.MELEE:
			if dist <= a.reach_cells():
				out.append({attack = a, adv = 0, note = ""})
			continue
		var far := a.long_range_cells() if a.long_range_cells() > 0 else a.range_cells()
		if dist > far:
			continue
		if los == -1:
			los = 1 if map.has_line_of_sight(from, target.cell) else 0
		if los == 0:
			continue
		var adv := 0
		var note := ""
		if dist > a.range_cells():
			adv = -1
			note = "long range"
		if _enemy_adjacent_at(attacker, from):
			adv = -1
			note = "enemy adjacent" if note == "" else note + ", enemy adjacent"
		out.append({attack = a, adv = adv, note = note})
	for o in out:
		var ca := Condition.attack_advantage(attacker, target, o.attack.kind == AttackData.Kind.MELEE, dist)
		o.adv = combine_advantage(o.adv, ca)
	return out


## Roll an attack and apply it. Awaitable.
func perform_attack(attacker: Actor, target: Actor, opt: Dictionary) -> void:
	if opt.is_empty() or not attacker.is_alive() or not target.is_alive():
		return
	var a: AttackData = opt.attack
	var st := attacker.stats
	attacker.facing = _dir_to(attacker.cell, target.cell)
	if attacker is Monster:
		attacker.play("attack")
	if a.kind == AttackData.Kind.MELEE:
		await attacker.lunge(target.position).finished
	else:
		var beam := a.damage_type in ["necrotic", "force", "radiant", "fire", "cold", "lightning"]
		Sfx.play("ray_zap" if beam else "bow_shot")
		var col := Color8(230, 90, 200) if beam else Color8(220, 200, 160)
		var p := Projectile.fire(map, attacker.body_position(), target.body_position(),
				Projectile.Style.BEAM if beam else Projectile.Style.ARROW, col)
		await p.done
	var melee := a.kind == AttackData.Kind.MELEE
	var cond_adv := Condition.attack_advantage(attacker, target, melee, DungeonMap.grid_distance(attacker.cell, target.cell))
	var adv := combine_advantage(opt.adv, cond_adv)
	var roll := Dice.d20(st.attack_bonus(a), adv)
	var bless_txt := _add_bonus_dice(roll, attacker)
	attacker.remove_condition("hidden")          # attacking gives you away
	var ac := target.stats.armor_class + Condition.ac_bonus(target)
	var crit := roll.is_crit()
	var hit := crit or (not roll.is_fumble() and roll.total >= ac)
	var adv_txt := "" if adv == 0 else (" (disadvantage%s)" % (": " + opt.note if opt.note != "" else "") if adv < 0 else " (advantage)")
	adv_txt += bless_txt
	_detail("%s attacks %s with %s: %s vs AC %d%s - %s" % [attacker.display_name(), target.display_name(),
			a.name, roll.describe(), ac, adv_txt, "CRITICAL HIT!" if crit else ("hit" if hit else "miss")])
	if not hit:
		_say("%s misses %s" % [attacker.display_name(), target.display_name()])
	if hit:
		var expr := st.damage_expr(a)
		if crit:
			expr = Dice.crit(expr)
		var dr := Dice.roll(expr)
		# House rule: a hit always deals at least 1 damage (before resistance/immunity).
		var dmg := _adjust(maxi(1, dr.total), a.damage_type, target)
		var parts := "%d %s (%s)" % [dmg, a.damage_type, dr.describe()]
		var short := ""
		if a.rider_damage != "":
			var rexpr := Dice.crit(a.rider_damage) if crit else a.rider_damage
			var rr := Dice.roll(rexpr)
			var save := roll_save(target, a.rider_save)
			var rd := rr.total
			var saved := save.total >= a.rider_dc
			if saved:
				rd = rd / 2
			rd = _adjust(rd, a.rider_damage_type, target)
			dmg += rd
			parts += " + %d %s (%s; %s save %s vs DC %d: %s)" % [rd, a.rider_damage_type, rr.describe(),
					a.rider_save, save.describe(), a.rider_dc, "half" if saved else "failed"]
			short = " (+%s)" % a.rider_damage_type
		target.take_damage(dmg)
		_detail("  %s takes %s." % [target.display_name(), parts])
		_say("%s %s %s: %d%s" % [attacker.display_name(), "CRITS" if crit else "hits", target.display_name(), dmg, short])
		Sfx.play("crit_hit" if crit else _hit_sound(a.damage_type))
		FloatText.spawn(map, target.body_position() + Vector2(0, -10),
				("CRIT %d" if crit else "%d") % dmg, Color8(255, 220, 90) if crit else Color8(255, 120, 100), 20 if crit else 10)
		if not target.is_alive():
			_say("%s %s" % [target.display_name(), "is down!" if target is Hero else "is slain!"])
	else:
		Sfx.play("miss_swish")
		FloatText.spawn(map, target.body_position() + Vector2(0, -10), "MISS", Color8(200, 196, 210), 10)
	await get_tree().create_timer(0.45).timeout


func _hero_attack(foe: Actor, opt: Dictionary) -> void:
	moving = true          # busy: no other input
	_clear_move_overlay()
	await perform_attack(current, foe, opt)
	attacks_left -= 1
	if attacks_left <= 0:
		action_used = true
	moving = false
	if _check_end():
		return
	if in_combat and current is Hero:
		_show_range()


## Combine advantage sources: any advantage + any disadvantage cancel (5e).
static func combine_advantage(a: int, b: int) -> int:
	var adv := a > 0 or b > 0
	var dis := a < 0 or b < 0
	if adv and dis:
		return 0
	return 1 if adv else (-1 if dis else 0)


## Add condition dice (Bless: +1d4) to an attack roll or save. Returns log text ("" if none).
func _add_bonus_dice(r: DiceRoll, who: Actor) -> String:
	var extra := Condition.roll_bonus_dice(who)
	if extra == "":
		return ""
	var b := Dice.roll(extra)
	r.total += b.total
	r.modifier += b.total
	return " (bless +%d)" % b.total


## A saving throw for `who` (proficiency, Bless, restrained DEX disadvantage).
func roll_save(who: Actor, ability: String) -> DiceRoll:
	var r := Dice.d20(who.stats.save_bonus(ability), Condition.save_advantage(who, ability))
	_add_bonus_dice(r, who)
	return r


## Start of a creature's turn: conditions tick down, reaction back, restrained = no movement,
## prone = stand up for half the speed.
func _start_of_turn(a: Actor) -> void:
	a.reaction_used = false
	for cid in a.tick_conditions():
		_say("%s is no longer %s." % [a.display_name(), Condition.display(cid).to_lower()])
		if cid == "blessed":
			pass
	if Condition.speed_zero(a):
		move_left = 0
	elif a.has_condition("prone"):
		a.remove_condition("prone")
		move_left -= a.stats.speed_cells() / 2
		_say("%s stands up." % a.display_name())


## Resistance halves, immunity zeroes.
func _adjust(dmg: int, dtype: String, target: Actor) -> int:
	if dtype in target.stats.immunities:
		return 0
	if dtype in target.stats.resistances:
		return dmg / 2
	return dmg


func _hit_sound(dtype: String) -> String:
	match dtype:
		"slashing": return "hit_slash"
		"piercing": return "hit_pierce"
		_: return "hit_blunt"


func _enemy_at(c: Vector2i) -> Actor:
	var a := map.actor_at(c)
	if a and a.is_alive() and not DungeonMap._same_side(a, current):
		return a
	return null


func _enemy_adjacent(who: Actor) -> bool:
	return _enemy_adjacent_at(who, who.cell)


func _enemy_adjacent_at(who: Actor, cell: Vector2i) -> bool:
	return _enemies_adjacent_at(who, cell) > 0


func _enemies_adjacent_at(who: Actor, cell: Vector2i) -> int:
	var n := 0
	for a in order:
		if a != who and a.is_alive() and not DungeonMap._same_side(a, who) and DungeonMap.grid_distance(a.cell, cell) <= 1:
			n += 1
	return n


func _victory_pause() -> void:
	await get_tree().create_timer(2.2).timeout
	# Simplified until death saves + healing (Phase 3): the fallen come to with 1 HP.
	for h in map.party:
		if not h.is_alive():
			h.revive(1)
			_say("%s comes to (1 HP)." % h.display_name())
	end_combat()


## Hit chance for the hint line (nat 1 misses, nat 20 hits).
static func hit_chance(bonus: int, ac: int, adv := 0) -> float:
	var p := clampf((21.0 - (ac - bonus)) / 20.0, 0.05, 0.95)
	if adv > 0:
		return 1.0 - pow(1.0 - p, 2)
	if adv < 0:
		return p * p
	return p


## Victory or defeat? (Placeholder handling; step 8 does it properly.) Returns true if over.
func _check_end() -> bool:
	if not in_combat:
		return true
	var foes := order.filter(func(x): return x is Monster and x.is_alive())
	var heroes := order.filter(func(x): return x is Hero and x.is_alive())
	if foes.is_empty():
		var xp := 0
		for x in order:
			if x is Monster:
				xp += x.stats.xp
		map.party_xp += xp
		_say("Victory! +%d XP" % xp)
		current = null
		_clear_move_overlay()
		status_changed.emit("")
		Sfx.play("total_sting")
		victory.emit(xp)
		_victory_pause()
		return true
	if heroes.is_empty():
		_say("The party has fallen...")
		current = null
		game_over = true
		_clear_move_overlay()
		map.overlay.clear("active")
		status_changed.emit("")
		Sfx.play("fail_sting")
		defeat.emit()
		return true
	return false


# --- starting --------------------------------------------------------------------------------

func _check_detection() -> void:
	for m in map.monsters:
		if not m.is_alive():
			continue
		for h in map.party:
			if not h.is_alive():
				continue
			if DungeonMap.grid_distance(m.cell, h.cell) <= m.stats.sight_cells() \
					and map.has_line_of_sight(m.cell, h.cell):
				start_combat(m, h)
				return


## Combat begins because `spotter` saw `target`.
func start_combat(spotter: Monster, target: Hero) -> void:
	if in_combat or _starting:
		return
	_starting = true
	map.controller.enabled = false
	# Let anyone mid-step finish their step first.
	while _anyone_moving():
		await get_tree().process_frame
	var foes: Array[Monster] = []
	for m in map.monsters:
		if m.is_alive() and m.group_id == spotter.group_id:
			foes.append(m)
	_say("%s spots the party!" % spotter.display_name())
	# Face each other.
	for m in foes:
		m.facing = _dir_to(m.cell, _nearest(m.cell, map.party).cell)
	for h in map.party:
		h.facing = _dir_to(h.cell, _nearest(h.cell, foes).cell)
	# Initiative.
	var all: Array[Actor] = []
	all.append_array(map.party.filter(func(h): return h.is_alive()))
	all.append_array(foes)
	initiative.clear()
	var tiebreak := {}
	for a in all:
		var r := Dice.d20(a.stats.initiative_bonus())
		initiative[a] = r.total
		tiebreak[a] = randf()
		_detail("%s initiative: %s" % [a.display_name(), r.describe()])
	all.sort_custom(func(x: Actor, y: Actor) -> bool:
		if initiative[x] != initiative[y]:
			return initiative[x] > initiative[y]
		if x.stats.dex_score != y.stats.dex_score:
			return x.stats.dex_score > y.stats.dex_score
		return tiebreak[x] > tiebreak[y])
	order = all
	for a in order:
		if a is Monster:
			a.show_hp_bar = true
	_say("Initiative: " + ", ".join(order.map(func(x: Actor): return "%s %d" % [x.display_name(), initiative[x]])))
	in_combat = true
	_starting = false
	round_number = 1
	_turn_index = -1
	combat_started.emit()
	_say("-- Round 1 --")
	_next_turn()


# --- turns -----------------------------------------------------------------------------------

func end_turn() -> void:
	if not in_combat:
		return
	_next_turn()


func _next_turn() -> void:
	_check_join()
	# Skip anyone who has dropped.
	for i in order.size():
		_turn_index += 1
		if _turn_index >= order.size():
			_turn_index = 0
			round_number += 1
			_say("-- Round %d --" % round_number)
		if order[_turn_index].is_alive():
			break
	current = order[_turn_index]
	move_left = current.stats.speed_cells()
	action_used = false
	bonus_used = false
	attacks_left = current.stats.attacks_per_action()
	_start_of_turn(current)
	moving = false
	map.camera_controller.target = current
	map.camera_controller.recenter()
	_pulse_t = 0.0
	_clear_move_overlay()
	if current is Hero:
		Sfx.play("turn_chime")
	turn_started.emit(current)
	if current is Monster:
		_emit_status()
		_monster_turn(current)
	else:
		_show_range()


# --- movement --------------------------------------------------------------------------------

## Walk `who` along `path` (cells, excluding its own), one square at a time, spending movement.
func move_along(who: Actor, path: Array[Vector2i]) -> void:
	if path.is_empty() or moving:
		return
	moving = true
	_clear_move_overlay()
	map.overlay.set_cells("destination", [path[-1]], COL_ACTIVE, 0.2, 0.6, true)
	for c in path:
		if move_left <= 0 or not in_combat:
			break
		var d := c - who.cell
		var tw := who.step_to(c, STEP_TIME * (1.4142 if d.x != 0 and d.y != 0 else 1.0))
		move_left -= 1
		_emit_status()
		await tw.finished
		map.apply_pending_rotation()
	map.overlay.clear("destination")
	moving = false
	if in_combat and who == current and who is Hero:
		_show_range()


func _show_range() -> void:
	_reach = map.combat_reach(current.cell, move_left, current)
	var cells: Array[Vector2i] = []
	for c: Vector2i in _reach:
		if _reach[c].stop and c != current.cell:
			cells.append(c)
	if cells.is_empty():
		map.overlay.clear("range")
	else:
		map.overlay.set_cells("range", cells, COL_RANGE, 0.18, 0.45)
	# Enemies the hero can attack right now.
	var targets: Array[Vector2i] = []
	if attacks_left > 0:
		for a in order:
			if a is Monster and not attack_option(current, a).is_empty():
				targets.append(a.cell)
	if targets.is_empty():
		map.overlay.clear("targets")
	else:
		map.overlay.set_cells("targets", targets, COL_TARGET, 0.22, 0.7)
	_hover = Vector2i(-99999, -99999)
	_emit_status()


func _show_preview() -> void:
	map.overlay.clear("path")
	map.overlay.clear("cursor")
	_emit_status()
	if not map.has_floor(_hover):
		return
	var foe := _enemy_at(_hover)
	if foe:
		var opt := attack_option(current, foe) if attacks_left > 0 else {}
		if opt.is_empty():
			map.overlay.set_cells("cursor", [_hover], COL_BLOCKED, 0.08, 0.5)
			if attacks_left <= 0:
				status_changed.emit("No attacks left this turn   Enter = end turn")
			else:
				status_changed.emit("%s: out of reach" % foe.display_name())
		else:
			var a: AttackData = opt.attack
			var bonus := current.stats.attack_bonus(a)
			var p := hit_chance(bonus, foe.stats.armor_class, opt.adv)
			map.overlay.set_cells("cursor", [_hover], COL_TARGET, 0.3, 0.9, true)
			status_changed.emit("Attack %s: %s %+d, %s  (%d%% to hit%s)" % [foe.display_name(), a.name, bonus,
					current.stats.damage_expr(a), roundi(p * 100), ", " + opt.note if opt.note != "" else ""])
		return
	if _reach.has(_hover) and _reach[_hover].stop and _hover != current.cell:
		var p := DungeonMap.reach_path(_reach, _hover)
		if p.size() > 1:
			map.overlay.set_cells("path", p.slice(0, -1), COL_RANGE, 0.25, 0.6, true)
		map.overlay.set_cells("cursor", [_hover], COL_ACTIVE, 0.2, 0.75, true)
	elif _hover != current.cell:
		map.overlay.set_cells("cursor", [_hover], COL_BLOCKED, 0.08, 0.5)


func _clear_move_overlay() -> void:
	for layer in ["range", "path", "cursor", "destination", "targets"]:
		map.overlay.clear(layer)


func _emit_status() -> void:
	if current is Hero:
		var atk := "Attack used" if attacks_left <= 0 else ("Attacks %d" % attacks_left if current.stats.attacks_per_action() > 1 else "Attack ready")
		status_changed.emit("Move %d/%d   %s   Enter = end turn" % [move_left, current.stats.speed_cells(), atk])
	else:
		status_changed.emit("")


func _monster_turn(m: Monster) -> void:
	await get_tree().create_timer(MONSTER_TURN_PAUSE * 0.5).timeout
	if not in_combat or current != m or game_over:
		return
	var plan := plan_monster_turn(m)
	var path: Array[Vector2i] = []
	path.assign(plan.path)
	if not path.is_empty():
		await move_along(m, path)
		if not in_combat or current != m or game_over:
			return
	if plan.target:
		var opts := attack_options_from(m, plan.target, m.cell)
		var opt := {}
		for o in opts:
			if o.attack == plan.attack:
				opt = o
		if opt.is_empty() and not opts.is_empty():
			opt = opts[0]
		if not opt.is_empty():
			await perform_attack(m, plan.target, opt)
			if _check_end():
				return
	elif plan.path.is_empty():
		_say("%s waits." % m.display_name())
	await get_tree().create_timer(0.25).timeout
	if in_combat and current == m:
		end_turn()


# --- monster AI ------------------------------------------------------------------------------

## AI tuning (expected-damage units).
const AI_STEP_COST := 0.08          ## per square walked: prefer not to wander
const AI_RANGED_CROWDED := 2.5      ## per adjacent hero when the chosen attack is ranged
const AI_FINISH_BONUS := 4.0        ## the attack would likely drop the target

## What a monster does this turn: {path: cells to walk, target: Actor or null, attack: AttackData}.
## Scores every reachable stopping cell x every standing hero x every usable attack by expected
## damage; if nothing can be attacked this turn, walks toward the nearest hero by real path.
func plan_monster_turn(m: Monster) -> Dictionary:
	var heroes := map.party.filter(func(h): return h.is_alive())
	var plan := {path = [] as Array[Vector2i], target = null, attack = null}
	if heroes.is_empty():
		return plan
	var reach := map.combat_reach(m.cell, move_left, m)
	var best := -INF
	for c: Vector2i in reach:
		if not reach[c].stop:
			continue
		var crowd := _enemies_adjacent_at(m, c)
		for h: Hero in heroes:
			for o in attack_options_from(m, h, c):
				var a: AttackData = o.attack
				var ev := expected_damage(m, h, o)
				var score := ev
				if ev >= h.hp * 0.8:
					score += AI_FINISH_BONUS
				score -= reach[c].cost * AI_STEP_COST
				if a.kind == AttackData.Kind.RANGED:
					score -= crowd * AI_RANGED_CROWDED
				if score > best:
					best = score
					plan.target = h
					plan.attack = a
					plan.path = DungeonMap.reach_path(reach, c)
	if plan.target:
		return plan
	# Nothing in reach: close in on the nearest hero (by real path, around walls).
	var far := map.combat_reach(m.cell, 200, m)
	var goal := Vector2i.ZERO
	var goal_cost := 1 << 30
	for h: Hero in heroes:
		for d: Vector2i in DungeonMap.DIRS8:
			var n: Vector2i = h.cell + d
			if far.has(n) and far[n].stop and far[n].cost < goal_cost:
				goal_cost = far[n].cost
				goal = n
	if goal_cost == 1 << 30:
		return plan
	var full := DungeonMap.reach_path(far, goal)
	# Walk as far as movement allows, ending on a cell we may stop on.
	var steps := mini(move_left, full.size())
	while steps > 0 and not far[full[steps - 1]].stop:
		steps -= 1
	plan.path = full.slice(0, steps)
	return plan


## Monsters outside the fight that now see a hero join it (with their whole group).
func _check_join() -> void:
	var joined: Array[Actor] = []
	for m in map.monsters:
		if not m.is_alive() or m in order or m in joined:
			continue
		for h in map.party:
			if h.is_alive() and DungeonMap.grid_distance(m.cell, h.cell) <= m.stats.sight_cells() \
					and map.has_line_of_sight(m.cell, h.cell):
				for g in map.monsters:
					if g.is_alive() and g.group_id == m.group_id and not g in order and not g in joined:
						joined.append(g)
				_say("%s joins the fight!" % m.display_name())
				break
	if joined.is_empty():
		return
	for a in joined:
		(a as Monster).show_hp_bar = true
		var r := Dice.d20(a.stats.initiative_bonus())
		initiative[a] = r.total
		_detail("%s initiative: %s" % [a.display_name(), r.describe()])
		a.facing = _dir_to(a.cell, _nearest(a.cell, map.party).cell)
	var cur := order[_turn_index] if _turn_index >= 0 and _turn_index < order.size() else null
	order.append_array(joined)
	order.sort_custom(func(x: Actor, y: Actor) -> bool:
		if initiative[x] != initiative[y]:
			return initiative[x] > initiative[y]
		return x.stats.dex_score > y.stats.dex_score)
	if cur:
		_turn_index = order.find(cur)


## Leave combat (step 8 decides when; available for tests/debugging now).
func end_combat() -> void:
	if not in_combat:
		return
	in_combat = false
	current = null
	for a in order:
		if a is Monster:
			a.show_hp_bar = false
	order.clear()
	map.overlay.clear("active")
	_clear_move_overlay()
	map.refresh_navigation()      # monsters may have moved
	map.camera_controller.target = map.party[0]
	map.controller.enabled = true
	combat_ended.emit()


# --- helpers ---------------------------------------------------------------------------------

func _say(text: String) -> void:
	print("[combat] ", text)
	log_line.emit(text)


## Full roll detail: debug console only (the log shows the short version).
func _detail(text: String) -> void:
	print("[combat]   ", text)


func _anyone_moving() -> bool:
	for h in map.party:
		if h.is_moving():
			return true
	for m in map.monsters:
		if m.is_moving():
			return true
	return false


func _nearest(from: Vector2i, actors: Array) -> Actor:
	var best: Actor = null
	var best_d := 1 << 30
	for a: Actor in actors:
		var d := DungeonMap.grid_distance(from, a.cell)
		if d < best_d:
			best_d = d
			best = a
	return best


static func _dir_to(from: Vector2i, to: Vector2i) -> Vector2i:
	var d := (to - from).clampi(-1, 1)
	return d if d != Vector2i.ZERO else Vector2i(0, 1)
