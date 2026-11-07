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
## A reaction could change the outcome: the HUD asks the player and calls answer_reaction().
## A big moment for the banner ("MAGE CASTS FIREBALL!").
signal announce(text: String)
signal reaction_prompt(text: String)
signal reaction_answered(yes: bool)
## Heroes went up a level after a fight: [{hero, level, gains}].
signal level_ups(ups: Array)

var pending_level_ups: Array[Dictionary] = []
## Conditions put on by the attack being resolved (announced after its damage line).
var _rider_conditions: Array = []

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
## Sneak Attack: once per turn.
var sneak_used := false
## Divine Strike already used this turn.
var divine_used := false
## Free object interaction this turn (opening a door) used.
var interact_used := false
var moving := false
var _reach := {}
var _hover := Vector2i(-99999, -99999)
var _hover_actor: Actor

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
	if not InputMap.has_action("dice_mode"):
		InputMap.add_action("dice_mode")
		var e2 := InputEventKey.new()
		e2.physical_keycode = KEY_F2
		InputMap.action_add_event("dice_mode", e2)
	if not InputMap.has_action("end_turn"):
		InputMap.add_action("end_turn")
		for k: Key in [KEY_ENTER, KEY_KP_ENTER]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event("end_turn", e)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("dice_mode"):
		cycle_dice_mode()
		if map.hud:
			map.hud.flash_hint("Dice scene: %s  (F2 to change)" % DICE_MODE_NAMES[dice_mode])
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
			if targeting:
				_confirm_targets()
			else:
				end_turn()
			return
		var c := IsoGrid.world_to_cell(map.get_local_mouse_position())
		if map.hud and map.hud.mouse_over_ui():
			c = Vector2i(-99999, -99999)
		if map.hud and map.hud.reaction_open():
			c = Vector2i(-99999, -99999)
		if targeting:
			if c != _hover:
				_hover = c
			_show_targeting()       # every frame: the area pulses
			return
		var ha := _mouse_actor()
		if c != _hover or ha != _hover_actor:
			_hover = c
			_hover_actor = ha
			_show_preview()


func _unhandled_input(event: InputEvent) -> void:
	if not in_combat or not current is Hero or moving:
		return
	if targeting:
		_targeting_input(event)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var c := IsoGrid.world_to_cell(map.get_local_mouse_position())
		var foe := _enemy_under_mouse()
		if foe and attacks_left > 0:
			var opt := attack_option(current, foe)
			if not opt.is_empty():
				get_viewport().set_input_as_handled()
				_hero_attack(foe, opt)
			return
		var thing := map.mech.thing_under(map.get_local_mouse_position())
		if thing and not foe and (thing is Trap or thing is Lever):
			get_viewport().set_input_as_handled()
			_use_thing(thing)
			return
		var door := map.closed_door_under(map.get_local_mouse_position())
		if door and not foe:
			get_viewport().set_input_as_handled()
			_use_door(door)
			return
		if _reach.has(c) and _reach[c].stop and c != current.cell and map.is_explored(c):
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
		if attacker == current and chosen_attack and o.attack != chosen_attack:
			continue
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
	if a.rider_damage != "" and (a.rider_vs.is_empty() or target.stats.creature_type in a.rider_vs):
		avg += Dice.average(a.rider_damage) * (0.75 if a.rider_save != "" else 1.0)   # save for half, roughly
	if a.rider_condition != "" and not target.has_condition(a.rider_condition) \
			and not a.rider_condition in target.stats.condition_immunities:
		avg += CONDITION_VALUE.get(a.rider_condition, 3.0) * 0.5
	if "resist_nonmagical" in target.stats.traits and not a.magical and a.magic_bonus == 0 and a.to_hit_override == -99 \
			and a.damage_type in ["bludgeoning", "piercing", "slashing"]:
		avg *= 0.5
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


## Hero animation for a ranged weapon attack: the Rogue draws the bow, the Mage aims the staff
## (crossbow bolt), the Fighter throws (attack swing). "" for monsters.
func _ranged_anim(attacker: Actor) -> String:
	if not attacker is Hero:
		return ""
	match attacker.hero_class:
		Hero.HeroClass.ROGUE:
			return "shoot"
		Hero.HeroClass.MAGE:
			return "cast"
	return "attack"


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
		if attacker is Hero:
			attacker.play_action("attack")
		await attacker.lunge(target.position).finished
	else:
		var anim := _ranged_anim(attacker)
		if anim != "":
			attacker.play_action(anim)
			await get_tree().create_timer(attacker.action_hit_time(anim)).timeout
		var beam := a.damage_type in ["necrotic", "force", "radiant", "fire", "cold", "lightning"]
		Sfx.play("ray_zap" if beam else "bow_shot")
		var col := Color8(230, 90, 200) if beam else Color8(220, 200, 160)
		var p := Projectile.fire(map, attacker.body_position(), target.body_position(),
				Projectile.Style.BEAM if beam else Projectile.Style.ARROW, col)
		await p.done
		if attacker is Hero and attacker.current_action() == "cast":
			attacker.end_action()
	var melee := a.kind == AttackData.Kind.MELEE
	var cond_adv := Condition.attack_advantage(attacker, target, melee, DungeonMap.grid_distance(attacker.cell, target.cell))
	var adv := combine_advantage(opt.adv, cond_adv)
	if "pack_tactics" in st.traits and _ally_next_to(attacker, target):
		adv = combine_advantage(adv, 1)
	var roll := Dice.d20(st.attack_bonus(a), adv)
	var bless_txt := _add_bonus_dice(roll, attacker)
	attacker.remove_condition("hidden")          # attacking gives you away
	var ac := target.stats.armor_class + Condition.ac_bonus(target)
	var crit := roll.natural >= st.crit_range
	var hit := crit or (not roll.is_fumble() and roll.total >= ac)
	if hit and not crit and await _offer_shield(target, attacker, a.name, roll.total, ac):
		ac += 5
		hit = false
	# Paralyzed: any hit from within 5 ft is a critical hit.
	if hit and target.has_condition("paralyzed") and DungeonMap.grid_distance(attacker.cell, target.cell) <= 1:
		crit = true
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
		var sneak_roll: DiceRoll = null
		var dmg := _adjust(maxi(1, dr.total), a.damage_type, target)
		var parts := "%d %s (%s)" % [dmg, a.damage_type, dr.describe()]
		var short := ""
		if _sneak_applies(attacker, target, a, adv):
			var sdice := "%dd6" % st.sneak_dice if st.sneak_dice > 0 else attacker.power("sneak_attack").damage
			var sr := Dice.roll(Dice.crit(sdice) if crit else sdice)
			sneak_roll = sr
			var sd := _adjust(sr.total, a.damage_type, target)
			dmg += sd
			sneak_used = true
			parts += " + %d sneak attack (%s)" % [sd, sr.describe()]
			short += " (+sneak attack)"
			FloatText.spawn(map, target.body_position() + Vector2(0, -22), "SNEAK", COL_MAGIC, 10)
		# Martial Advantage (hobgoblin): +2d6 once a turn when an ally is next to the target.
		if "martial_advantage" in st.traits and not sneak_used and _ally_next_to(attacker, target):
			var mr := Dice.roll("4d6" if crit else "2d6")
			var md := _adjust(mr.total, a.damage_type, target)
			dmg += md
			sneak_used = true
			parts += " + %d martial advantage (%s)" % [md, mr.describe()]
			short += " (+martial advantage)"
		# Divine Strike (Cleric 8): once on each of its turns, a weapon hit deals +1d8 radiant.
		if st.divine_strike != "" and not divine_used and attacker == current:
			var dsr := Dice.roll(Dice.crit(st.divine_strike) if crit else st.divine_strike)
			var dsd := _adjust(dsr.total, "radiant", target)
			dmg += dsd
			divine_used = true
			parts += " + %d radiant (Divine Strike, %s)" % [dsd, dsr.describe()]
			short += " (+radiant)"
			SpellFx.sparkles(map, target.body_position(), Color8(255, 236, 150), false)
		# Flesh golems: immune to bludgeoning, piercing and slashing from nonmagical weapons.
		if "immune_nonmagical" in target.stats.traits and not a.magical and a.magic_bonus == 0 and a.to_hit_override == -99 \
				and a.damage_type in ["bludgeoning", "piercing", "slashing"]:
			dmg = 0
			parts += ", none (needs a magic weapon)"
			short += " (immune: not magic)"
		# Wights, wraiths...: resistant to bludgeoning, piercing and slashing from nonmagical weapons.
		if "resist_nonmagical" in target.stats.traits and not a.magical and a.magic_bonus == 0 and a.to_hit_override == -99 \
				and a.damage_type in ["bludgeoning", "piercing", "slashing"]:
			dmg = dmg / 2
			parts += ", halved (needs a magic weapon)"
			short += " (resisted: not magic)"
		if crit and show_dice(true):
			await _dice_crit(attacker, target, a.name, roll, ac, dr, a.damage_type, sneak_roll)
		if a.rider_condition != "" and target.is_alive():
			var resisted := false
			if a.rider_save != "":
				var cs := save_vs(target, a.rider_save, a.rider_dc)
				resisted = cs.total >= a.rider_dc
				_detail("  %s %s save vs %s: %s - %s" % [target.display_name(), a.rider_save, a.rider_condition,
						cs.describe(), "resisted" if resisted else "FAILED"])
			if not resisted and not _shrugs_off(target, a.rider_condition) \
					and not (a.rider_condition == "prone" and target.stats.fly):
				var c := target.add_condition(a.rider_condition, a.rider_condition_rounds, attacker)
				if a.rider_condition == "paralyzed":
					c.save_ability = a.rider_save
					c.save_dc = a.rider_dc
				_rider_conditions.append([target, a.rider_condition])
		if a.rider_damage != "" and (a.rider_vs.is_empty() or target.stats.creature_type in a.rider_vs):
			var rexpr := Dice.crit(a.rider_damage) if crit else a.rider_damage
			var rr := Dice.roll(rexpr)
			var rd := rr.total
			if a.rider_save != "" and a.rider_condition == "":
				var save := save_vs(target, a.rider_save, a.rider_dc)
				var saved := save.total >= a.rider_dc
				if saved:
					rd = rd / 2
				parts += " + %d %s (%s; %s save %s vs DC %d: %s)" % [_adjust(rd, a.rider_damage_type, target), a.rider_damage_type, rr.describe(),
						a.rider_save, save.describe(), a.rider_dc, "half" if saved else "failed"]
			else:
				parts += " + %d %s (%s)" % [_adjust(rd, a.rider_damage_type, target), a.rider_damage_type, rr.describe()]
			rd = _adjust(rd, a.rider_damage_type, target)
			dmg += rd
			short = " (+%s)" % a.rider_damage_type
		if await _offer_uncanny_dodge(target, attacker, a.name, dmg):
			dmg = dmg / 2
			parts += ", halved (Uncanny Dodge)"
			short += " (halved)"
		apply_damage(target, dmg, a.damage_type, crit)
		_detail("  %s takes %s." % [target.display_name(), parts])
		_say("%s %s %s: %d%s" % [attacker.display_name(), "CRITS" if crit else "hits", target.display_name(), dmg, short])
		for rc in _rider_conditions:
			if rc[0].is_alive() and rc[0].has_condition(rc[1]):
				_say("  %s is %s!" % [rc[0].display_name(), Condition.display(rc[1]).to_lower()])
				FloatText.spawn(map, rc[0].body_position() + Vector2(0, -22), Condition.display(rc[1]).to_upper(), COL_MAGIC, 10)
		_rider_conditions.clear()
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


## A saving throw for `who` (proficiency, Bless, restrained DEX disadvantage). `vs_magic`: against a
## spell or magical effect (Magic Resistance gives advantage).
func roll_save(who: Actor, ability: String, vs_magic := false) -> DiceRoll:
	var adv := Condition.save_advantage(who, ability)
	if vs_magic and "magic_resistance" in who.stats.traits:
		adv = combine_advantage(adv, 1)
	var r := Dice.d20(who.stats.save_bonus(ability), adv)
	_add_bonus_dice(r, who)
	if Condition.auto_fails_save(who, ability):
		r.total = 0              # paralyzed: STR and DEX saves fail
	return r


## Start of a creature's turn: conditions tick down, reaction back, restrained = no movement,
## prone = stand up for half the speed.
func _start_of_turn(a: Actor) -> void:
	a.reaction_used = false
	# Recharge 5-6: a used monster power comes back on a d6 roll of 5 or 6.
	if a is Monster:
		for p: SpellData in a.stats.powers:
			if p.recharge == SpellData.Recharge.DICE and a.uses_left.get(p.id, 1) <= 0:
				var r := Dice.die(6)
				if r >= 5:
					a.uses_left[p.id] = 1
					_say("%s's %s recharges (%d)." % [a.display_name(), p.display_name, r])
	# Regeneration (troll): 10 HP at the start of its turn, unless fire or acid hurt it since its last one.
	if "regeneration" in a.stats.traits and a.is_alive():
		if a.get_meta("regen_blocked", false):
			a.set_meta("regen_blocked", false)
			_say("%s's burns don't knit." % a.display_name())
		elif a.hp < a.stats.max_hp:
			var got := a.heal(10)
			_say("%s regenerates %d HP." % [a.display_name(), got])
			FloatText.spawn(map, a.body_position() + Vector2(0, -14), "+%d" % got, COL_ALLY, 10)
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


## Resistance halves, immunity zeroes, vulnerability doubles.
func _adjust(dmg: int, dtype: String, target: Actor) -> int:
	if dtype in target.stats.immunities:
		return 0
	if dtype in target.stats.resistances:
		return dmg / 2
	if dtype in target.stats.vulnerabilities:
		return dmg * 2
	return dmg


func _hit_sound(dtype: String) -> String:
	match dtype:
		"slashing": return "hit_slash"
		"piercing": return "hit_pierce"
		_: return "hit_blunt"


## The figure under the mouse (by sprite), or null over the UI.
func _mouse_actor() -> Actor:
	if map.hud and map.hud.mouse_over_ui():
		return null
	return map.actor_under(map.get_local_mouse_position())


func _enemy_under_mouse() -> Actor:
	var a := _mouse_actor()
	if a and a.is_alive() and current and not DungeonMap._same_side(a, current):
		return a
	return null


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
		if not h.is_alive() and not h.dead:
			h.revive(1)
			_say("%s comes to (1 HP)." % h.display_name())
	end_combat()
	if not pending_level_ups.is_empty():
		level_ups.emit(pending_level_ups.duplicate())
		pending_level_ups.clear()


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
		var ups := map.award_xp(xp)
		_say("Victory! +%d XP (%d each)" % [xp, xp / maxi(1, map.party.filter(func(h): return not h.dead).size())])
		for u in ups:
			_say("%s reaches level %d!" % [u.hero.display_name(), u.level])
		pending_level_ups.append_array(ups)
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
	if current:
		_end_of_turn_saves(current)
	_next_turn()


## Conditions that end on a save at the end of the bearer's turn (Hold Person, ghoul paralysis).
func _end_of_turn_saves(a: Actor) -> void:
	for c: Condition in a.conditions.duplicate():
		if c.save_ability == "" or not a.is_alive():
			continue
		var s := roll_save(a, c.save_ability)
		_detail("  %s %s save to end %s: %s vs DC %d" % [a.display_name(), c.save_ability, c.id, s.describe(), c.save_dc])
		if s.total >= c.save_dc:
			a.remove_condition(c.id)
			_say("%s shakes off being %s." % [a.display_name(), Condition.display(c.id).to_lower()])
			FloatText.spawn(map, a.body_position() + Vector2(0, -10), "FREE", COL_ALLY, 10)


func _next_turn() -> void:
	_check_join()
	# Skip anyone who has dropped.
	for i in order.size():
		_turn_index += 1
		if _turn_index >= order.size():
			_turn_index = 0
			round_number += 1
			_say("-- Round %d --" % round_number)
		var who := order[_turn_index]
		if who.is_alive() or (who is Hero and _is_dying(who)):
			break
	current = order[_turn_index]
	move_left = current.stats.speed_cells()
	action_used = false
	bonus_used = false
	sneak_used = false
	divine_used = false
	interact_used = false
	attacks_left = current.stats.attacks_per_action()
	chosen_attack = null
	targeting = null
	picked.clear()
	_start_of_turn(current)
	moving = false
	map.camera_controller.target = current
	map.camera_controller.recenter()
	_pulse_t = 0.0
	_clear_move_overlay()
	if current is Hero:
		Sfx.play("turn_chime")
	turn_started.emit(current)
	if current.has_condition("paralyzed") and current.is_alive():
		_paralyzed_turn(current)
	elif current is Monster:
		_emit_status()
		_monster_turn(current)
	elif _is_dying(current):
		_death_save_turn(current)
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
		if map.mech.after_combat_step(who) or not who.is_alive():
			break                         # a hidden trap went off
	map.overlay.clear("destination")
	moving = false
	if in_combat and not game_over and who == current and who is Hero and not who.is_alive():
		end_turn()                        # knocked down by a trap on its own turn
		return
	if in_combat and who == current and who is Hero:
		_show_range()



## Why the current hero can't open `door` right now, or "".
func _door_problem(door: Door) -> String:
	if not door.by_hand():
		return door.hint(map)
	if not current.cell in door.sides():
		return "Move next to the door to open it"
	var key := map.key_for(door)
	if door.locked and key == "" and door.key_id != "" and door.lock_dc <= 0:
		return "Locked: it needs a key"
	if door.locked and key == "":
		if action_used or attacks_left < current.stats.attacks_per_action():
			return "Picking the lock takes your action (already used)"
	elif interact_used:
		return "You have already opened a door this turn"
	return ""


## The current hero opens (or tries to pick/force) a door it stands next to.
func _use_door(door: Door) -> void:
	var why := _door_problem(door)
	if why != "":
		status_changed.emit(why)
		Sfx.play("fail_sting", -12.0)
		return
	if door.locked and map.key_for(door) == "":
		action_used = true                  # picking / forcing it is your action
		attacks_left = 0
	else:
		interact_used = true                # opening (with the key, if locked) is free once a turn
	current.facing = door.get_cell() - current.cell
	var who: Array[Hero] = [current]
	if map.try_open_door(door, who):
		_check_join()
	_show_range()

func _show_range() -> void:
	_reach = map.combat_reach(current.cell, move_left, current)
	var cells: Array[Vector2i] = []
	for c: Vector2i in _reach:
		if _reach[c].stop and c != current.cell and map.is_explored(c):
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
	var thing := map.mech.thing_under(map.get_local_mouse_position())
	if thing and not _enemy_under_mouse():
		var why := _thing_problem(thing)
		map.overlay.set_cells("cursor", [thing.get_cell()], COL_BLOCKED if why != "" else COL_ACTIVE, 0.15, 0.7, why == "")
		if why == "":
			why = "Click: disarm the %s (uses your action, DC %d)" % [thing.trap_name(), thing.disarm_dc] if thing is Trap else "Click: pull the lever (free, once a turn)"
		status_changed.emit(why)
		return
	var door := map.closed_door_under(map.get_local_mouse_position())
	if door and not _enemy_under_mouse():
		var msg := _door_problem(door)
		map.overlay.set_cells("cursor", [door.get_cell()], COL_BLOCKED if msg != "" else COL_ACTIVE, 0.15, 0.7, msg == "")
		if msg == "":
			if not door.locked:
				msg = "Click: open the door (free, once a turn)"
			elif map.key_for(door) != "":
				msg = "Click: unlock it with the %s and open it (free, once a turn)" % ItemData.get_item(map.key_for(door)).display_name
			else:
				msg = "Click: pick the lock (uses your action)"
		status_changed.emit(msg)
		return
	if not map.has_floor(_hover):
		return
	var foe := _enemy_under_mouse()
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
			var extra := " +%dd6 sneak" % maxi(1, current.stats.sneak_dice) if sneak_preview(current, foe, opt) else ""
			var advt := " advantage" if opt.adv > 0 else ""
			status_changed.emit("Attack %s: %s %+d, %s%s  (%d%% to hit%s%s)" % [foe.display_name(), a.name, bonus,
					current.stats.damage_expr(a), extra, roundi(p * 100), advt, ", " + opt.note if opt.note != "" else ""])
		return
	if _reach.has(_hover) and _reach[_hover].stop and _hover != current.cell and map.is_explored(_hover):
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
	if m.has_condition("turned"):
		await _flee_turn(m)
		return
	var plan := plan_monster_turn(m)
	var path: Array[Vector2i] = []
	path.assign(plan.path)
	if not path.is_empty():
		await move_along(m, path)
		if not in_combat or current != m or game_over:
			return
	if plan.target and plan.power:
		var who: Array[Actor] = [plan.target]
		await _cast(m, plan.power, 0, who, plan.target.cell)
		if _check_end():
			return
	elif plan.target:
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
			# Multiattack: the rest of the attacks, at the same target or whoever is still in reach.
			for i in m.stats.extra_attacks:
				if not in_combat or current != m or not m.is_alive() or m.has_condition("paralyzed"):
					break
				var next := _multiattack_option(m, plan.target, opt.attack)
				if next.is_empty():
					break
				await perform_attack(m, next.target, next.opt)
				if _check_end():
					return
	elif plan.path.is_empty():
		_say("%s waits." % m.display_name())
	await get_tree().create_timer(0.25).timeout
	if in_combat and current == m:
		end_turn()


## The next multiattack swing: the same attack at `first` if it is still up, else the best
## option against any hero in reach. {} if nobody can be hit.
func _multiattack_option(m: Monster, first: Actor, a: AttackData) -> Dictionary:
	var best := {}
	var best_ev := -1.0
	for h in map.party:
		if not h.is_alive():
			continue
		for o in attack_options_from(m, h, m.cell):
			var ev := expected_damage(m, h, o) + (5.0 if h == first and o.attack == a else 0.0)
			if ev > best_ev:
				best_ev = ev
				best = {target = h, opt = o}
	return best


## A turned undead: moves as far from the heroes as it can and does nothing else.
func _flee_turn(m: Monster) -> void:
	var reach := map.combat_reach(m.cell, move_left, m)
	var best := m.cell
	var best_d := -1
	for c: Vector2i in reach:
		if not reach[c].stop:
			continue
		var d := 1 << 30
		for h in map.party:
			if h.is_alive():
				d = mini(d, DungeonMap.grid_distance(c, h.cell))
		if d > best_d:
			best_d = d
			best = c
	_say("%s flees in terror of the holy light." % m.display_name())
	if best != m.cell:
		var path: Array[Vector2i] = []
		path.assign(DungeonMap.reach_path(reach, best))
		await move_along(m, path)
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
	var plan := {path = [] as Array[Vector2i], target = null, attack = null, power = null}
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
				var score := ev + randf() * AI_JITTER
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
			# Powers that put a condition on a hero (Web: restrained, Fear Ray: frightened).
			for p: SpellData in m.stats.powers:
				var pv := _power_value(m, p, h, c)
				if pv <= 0.0:
					continue
				var pscore: float = pv + randf() * AI_JITTER - reach[c].cost * AI_STEP_COST - crowd * AI_RANGED_CROWDED
				if pscore > best:
					best = pscore
					plan.target = h
					plan.attack = null
					plan.power = p
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
		# Every way to the heroes is blocked (allies in a corridor, heroes in a doorway): at least
		# get as close as this turn allows, so the queue moves up behind the front.
		var here := _nearest_hero_distance(m.cell, heroes)
		for c: Vector2i in reach:
			var dist := _nearest_hero_distance(c, heroes)
			if dist < here:
				here = dist
				plan.path = DungeonMap.reach_path(reach, c)
		return plan
	var full := DungeonMap.reach_path(far, goal)
	# Walk as far as movement allows, ending on a cell we may stop on.
	var steps := mini(move_left, full.size())
	while steps > 0 and not far[full[steps - 1]].stop:
		steps -= 1
	plan.path = full.slice(0, steps)
	return plan


## Squares (grid distance, walls ignored) from `cell` to the nearest of `heroes`.
static func _nearest_hero_distance(cell: Vector2i, heroes: Array) -> int:
	var best := 1 << 30
	for h: Hero in heroes:
		best = mini(best, DungeonMap.grid_distance(cell, h.cell))
	return best


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


# --- spells & abilities (Phase 3) --------------------------------------------------------------

const COL_ALLY := Color8(120, 220, 140)
const COL_AREA := Color8(255, 110, 40)
const COL_MAGIC := Color8(214, 120, 230)

## Targeting state while the player picks targets for a power.
var targeting: SpellData
var target_slot := 0
var picked: Array[Actor] = []
## Shove: push the target 5 ft away instead of knocking it prone (chosen in the HUD).
var shove_push := false
## Weapon chosen from the Attack menu this turn (null = best automatically).
var chosen_attack: AttackData


## Powers for the hero's Spell/Ability menu: [{power, ok, why, tag}].
func menu_powers(h: Actor) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if h.has_condition("restrained"):
		var busy := action_used or attacks_left < h.stats.attacks_per_action()
		out.append({power = ESCAPE, ok = not busy, why = "action used" if busy else "", tag = "action"})
	for p: SpellData in h.stats.powers:
		if p.kind == SpellData.Kind.MONSTER or p.cast_time == SpellData.CastTime.REACTION:
			continue
		if p.cast_time == SpellData.CastTime.FREE and p.uses == 0:
			continue                     # always-on (Sneak Attack)
		var why := ""
		match p.cast_time:
			SpellData.CastTime.ACTION:
				if action_used or attacks_left < h.stats.attacks_per_action():
					why = "action used"
			SpellData.CastTime.BONUS:
				if bonus_used:
					why = "bonus action used"
			SpellData.CastTime.ATTACK:
				if attacks_left <= 0:
					why = "no attacks left"
		if why == "" and p.id == "action_surge" and not action_used:
			why = "use your action first"
		if why == "" and p.id == "turn_undead" and _undead_in_range(h, p).is_empty():
			why = "no undead in sight"
		if why == "" and p.id == "hide" and _enemy_adjacent(h):
			why = "an enemy is right next to you"
		if why == "" and not h.can_use(p):
			why = "no slots left" if p.uses_slot() else "used up"
		if why == "" and p.target in [SpellData.Target.ENEMY, SpellData.Target.ALLY, SpellData.Target.ANY] \
				and valid_targets(h, p).is_empty():
			why = "no target in range"
		out.append({power = p, ok = why == "", why = why, tag = power_tag(p)})
	return out


## "cantrip", "1st", "3rd", "bonus", "1/rest", "attack"
static func power_tag(p: SpellData) -> String:
	if p.kind == SpellData.Kind.SPELL:
		return power_tag_level(p.level)
	if p.cast_time == SpellData.CastTime.BONUS:
		return "bonus" + (" 1/rest" if p.uses > 0 else "")
	if p.cast_time == SpellData.CastTime.ATTACK:
		return "attack"
	return ""


static func power_tag_level(lvl: int) -> String:
	return ["cantrip", "1st", "2nd", "3rd", "4th", "5th"][clampi(lvl, 0, 5)]


## Pick a weapon for this turn's attacks (from the Attack menu); null = automatic.
func choose_weapon(a: AttackData) -> void:
	chosen_attack = a
	if current is Hero:
		_show_range()


func begin_targeting(p: SpellData) -> void:
	if not current is Hero or moving:
		return
	if p.target == SpellData.Target.SELF:
		var me: Array[Actor] = [current]
		_cast(current, p, current.lowest_slot_for(p), me, current.cell)
		return
	targeting = p
	target_slot = current.lowest_slot_for(p)
	picked.clear()
	_clear_move_overlay()
	_show_targeting()


func cancel_targeting() -> void:
	targeting = null
	picked.clear()
	for layer in ["area", "picked", "targets", "cursor"]:
		map.overlay.clear(layer)
	if in_combat and current is Hero:
		_show_range()


## Creatures `caster` may target with `p` right now (range, line of sight, side).
func valid_targets(caster: Actor, p: SpellData) -> Array[Actor]:
	var out: Array[Actor] = []
	var rng := maxi(1, p.range_cells())
	var pool: Array = order if in_combat else map.party
	for a: Actor in pool:
		if a.dead:
			continue
		var ally := DungeonMap._same_side(a, caster)
		match p.target:
			SpellData.Target.ENEMY:
				if ally or not a.is_alive():
					continue
			SpellData.Target.ALLY:
				if not ally:
					continue
				if not a.is_alive() and p.resolve != SpellData.Resolve.HEAL:
					continue
			SpellData.Target.ANY:
				pass
			_:
				continue
		if not p.creature_types.is_empty() and not a.stats.creature_type in p.creature_types:
			continue
		if DungeonMap.grid_distance(caster.cell, a.cell) > rng:
			continue
		if is_item_power(p) and p.resolve == SpellData.Resolve.HEAL and a.is_alive() and a.hp >= a.stats.max_hp:
			continue                            # don't waste a potion or scroll on someone unhurt
		if p.needs_los and a != caster and not map.has_line_of_sight(caster.cell, a.cell):
			continue
		out.append(a)
	return out


## Cells a shaped power would cover if aimed at `aim` (AREA: centred there; LINE/CONE: toward it),
## cast from the caster's cell or from `origin` (the AI trying out cells it could move to).
func shape_cells(caster: Actor, p: SpellData, aim: Vector2i, origin := Vector2i(-99999, -99999)) -> Array[Vector2i]:
	var from := caster.cell if origin == Vector2i(-99999, -99999) else origin
	match p.target:
		SpellData.Target.AREA:
			return Targeting.area_cells(aim, p.area_size)
		SpellData.Target.LINE:
			# A line stops at the first wall or closed door.
			var line := Targeting.line_cells(from, aim, p.range_cells())
			for i in line.size():
				if map.blocks_sight(line[i]) or not map.has_floor(line[i]):
					return line.slice(0, i)
			return line
		SpellData.Target.CONE:
			return Targeting.cone_cells(from, aim, p.range_cells())
	var none: Array[Vector2i] = []
	return none


func _aim_ok(caster: Actor, p: SpellData, aim: Vector2i) -> bool:
	if not map.has_floor(aim):
		return false
	if p.target == SpellData.Target.AREA:
		return DungeonMap.grid_distance(caster.cell, aim) <= p.range_cells() \
				and (not p.needs_los or map.has_line_of_sight(caster.cell, aim))
	return aim != caster.cell


func _max_picks(p: SpellData) -> int:
	return p.darts_for(target_slot) if p.darts > 0 else p.targets_for(target_slot)


func _is_shaped(p: SpellData) -> bool:
	return p.target in [SpellData.Target.AREA, SpellData.Target.LINE, SpellData.Target.CONE]


func _show_targeting() -> void:
	var p := targeting
	var pulse := 0.5 + 0.5 * sin(_pulse_t * TAU / 0.9)
	map.overlay.clear("cursor")
	if _is_shaped(p):
		map.overlay.clear("targets")
		if _aim_ok(current, p, _hover):
			map.overlay.set_cells("area", shape_cells(current, p, _hover), COL_AREA, 0.32 + 0.16 * pulse, 0.85, true)
		else:
			map.overlay.clear("area")
			if map.has_floor(_hover):
				map.overlay.set_cells("cursor", [_hover], COL_BLOCKED, 0.08, 0.5)
	else:
		var vt := valid_targets(current, p)
		var cells: Array[Vector2i] = []
		for a in vt:
			cells.append(a.cell)
		map.overlay.set_cells("targets", cells, COL_ALLY if p.target == SpellData.Target.ALLY else COL_TARGET, 0.2, 0.7)
		var pc: Array[Vector2i] = []
		for a in picked:
			pc.append(a.cell)
		if pc.is_empty():
			map.overlay.clear("picked")
		else:
			map.overlay.set_cells("picked", pc, COL_ACTIVE, 0.3, 0.9)
		var h := hover_card if hover_card else _mouse_actor()
		if h and h in vt:
			map.overlay.set_cells("cursor", [_hover], COL_ACTIVE, 0.25, 0.9, true)
	status_changed.emit(_targeting_hint())


func _targeting_hint() -> String:
	var p := targeting
	var slot := ""
	if p.uses_slot():
		slot = " (%s slot, +/- to change)" % power_tag_level(target_slot)
	var what := ""
	match p.target:
		SpellData.Target.AREA:
			what = "click where to aim"
		SpellData.Target.LINE, SpellData.Target.CONE:
			what = "click a direction"
		_:
			var n := _max_picks(p)
			what = "click a target" if n == 1 else "pick %d/%d (Enter casts)" % [picked.size(), n]
			if is_potion_power(p):
				what = "click who drinks it (you or an ally next to you)"
	return "%s%s: %s. Right-click cancels." % [p.display_name, slot, what]


func _targeting_input(event: InputEvent) -> void:
	var p := targeting
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			cancel_targeting()
		elif p.uses_slot() and event.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
			_change_slot(1)
		elif p.uses_slot() and event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			_change_slot(-1)
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		if picked.is_empty():
			cancel_targeting()
		else:
			picked.pop_back()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if map.hud and map.hud.mouse_over_ui():
		return
	get_viewport().set_input_as_handled()
	var c := IsoGrid.world_to_cell(map.get_local_mouse_position())
	if _is_shaped(p):
		if _aim_ok(current, p, c):
			var slot := target_slot
			targeting = null
			for layer in ["area", "cursor"]:
				map.overlay.clear(layer)
			var none: Array[Actor] = []
			_cast(current, p, slot, none, c)
		return
	pick_target(_mouse_actor())


## Add a target while targeting (from a click on the map or on a hero's portrait). Returns true if
## it was accepted. Casts once the limit is reached (or every valid creature is picked).
func pick_target(a: Actor) -> bool:
	var p := targeting
	if p == null or a == null or moving or _is_shaped(p) or not a in valid_targets(current, p):
		return false
	if p.darts == 0 and a in picked:
		return false                            # Bless etc.: each creature once
	picked.append(a)
	var limit := _max_picks(p)
	if p.darts == 0:
		limit = mini(limit, valid_targets(current, p).size())
	if picked.size() >= limit:
		_confirm_targets()
	else:
		_show_targeting()
	return true


## While targeting: would `a` be a valid pick right now? (HUD frames portraits with this.)
func is_valid_pick(a: Actor) -> bool:
	return targeting != null and not _is_shaped(targeting) and a in valid_targets(current, targeting) \
			and (targeting.darts > 0 or not a in picked)


## The HUD reports which hero card the mouse is over (null when none), so the map shows that
## hero as the hovered target.
var hover_card: Actor


func _change_slot(d: int) -> void:
	var lvl := target_slot + d
	while lvl >= targeting.level and lvl <= current.slots_left.size():
		if lvl >= 1 and current.slots_left[lvl - 1] > 0:
			target_slot = lvl
			while picked.size() > _max_picks(targeting):
				picked.pop_back()
			return
		lvl += d


func _confirm_targets() -> void:
	if targeting == null or picked.is_empty():
		return
	var p := targeting
	var slot := target_slot
	var t: Array[Actor] = picked.duplicate()
	targeting = null
	picked.clear()
	for layer in ["picked", "targets", "cursor"]:
		map.overlay.clear(layer)
	_cast(current, p, slot, t, t[0].cell)


## Use a power: spend the slot / use / action, then resolve it. Awaitable.
func _cast(caster: Actor, p: SpellData, slot: int, targets: Array[Actor], aim: Vector2i) -> void:
	moving = true
	_clear_move_overlay()
	status_changed.emit("")
	if p.uses_slot():
		caster.spend_slot(slot)
	if p.uses > 0 or p.recharge == SpellData.Recharge.DICE:
		caster.spend_use(p)
	if is_item_power(p):
		map.inventory.remove(p.get_meta("item_id"))
	match p.cast_time:
		SpellData.CastTime.ACTION:
			action_used = true
			attacks_left = 0
		SpellData.CastTime.BONUS:
			bonus_used = true
		SpellData.CastTime.ATTACK:
			attacks_left -= 1
			if attacks_left <= 0:
				action_used = true
	var check := scroll_check_dc(caster, p) if p.is_scroll() else 0
	var fizzled := false
	if check > 0:
		var r := Dice.d20(caster.stats.mod(caster.stats.spell_ability))
		fizzled = r.total < check
		_say("%s reads a %s: a spell beyond their power (%s check %s vs DC %d)" % [caster.display_name(),
				p.get_meta("item_name"), caster.stats.spell_ability, r.describe(), check])
		if fizzled:
			Sfx.play("scroll_read")
			_say("  The words slip away and the scroll crumbles to dust.")
			Sfx.play("fail_sting", -6.0)
			await get_tree().create_timer(0.6).timeout
	if not fizzled:
		await resolve_power(caster, p, slot, targets, aim)
	if caster is Hero and caster.current_action() == "cast":
		caster.end_action()
	moving = false
	if _check_end():
		return
	if in_combat and current is Hero:
		_show_range()


## Apply a power's effect (generic, from its data). Visuals are simple here; Phase 3 steps 3/6
## give individual spells their own effects.
func resolve_power(caster: Actor, p: SpellData, slot: int, targets: Array[Actor], aim: Vector2i) -> void:
	var lvl_txt := " (%s)" % power_tag_level(slot) if p.uses_slot() and slot > p.level else ""
	var verb := "casts" if p.kind == SpellData.Kind.SPELL else "uses"
	if p.is_scroll():
		if scroll_check_dc(caster, p) == 0:      # (else _cast has already said it)
			_say("%s reads a %s" % [caster.display_name(), p.get_meta("item_name")])
	elif is_item_power(p):
		var who: Actor = targets[0] if not targets.is_empty() else caster
		if who == caster:
			_say("%s drinks a %s" % [caster.display_name(), p.display_name])
		else:
			_say("%s gives %s a %s" % [caster.display_name(), who.display_name(), p.display_name])
	else:
		_say("%s %s %s%s" % [caster.display_name(), verb, p.display_name, lvl_txt])
	if p.id == "action_surge":
		action_used = false
		attacks_left = caster.stats.attacks_per_action()
		_say("  %s surges into action: another action this turn!" % caster.display_name())
		Sfx.play("charge", -2.0, 1.2)
		SpellFx.sparkles(map, caster.body_position(), Color8(255, 200, 110))
		FloatText.spawn(map, caster.body_position() + Vector2(0, -14), "ACTION SURGE", COL_ACTIVE, 10)
		await get_tree().create_timer(0.4).timeout
		return
	if p.id == "turn_undead":
		await _turn_undead(caster, p)
		return
	if p.concentration:
		_start_concentration(caster, p)
	if aim != caster.cell:
		caster.facing = _dir_to(caster.cell, aim)
	if caster is Monster:
		caster.play("attack")
	elif caster is Hero:
		if p.kind == SpellData.Kind.SPELL or p.id == "second_wind":
			caster.play_action("cast")      # held until _cast ends it
		elif p.id == "shove":
			caster.play_action("attack")
	if p.is_scroll():
		Sfx.play("scroll_read")
		await get_tree().create_timer(0.4).timeout      # unroll, then the spell goes off
	if p.vfx != "lightning":                            # (lightning cracks when it strikes)
		Sfx.play(p.sfx)
	if is_potion_power(p):
		await get_tree().create_timer(0.45).timeout     # the glugs, then the heal chime
	if p.kind == SpellData.Kind.SPELL and p.vfx != "fireball":
		await SpellFx.charge(map, _cast_from(caster) + Vector2(0, 2), _spell_colour(p))
	var char_level := maxi(1, caster.stats.level)
	var affected: Array[Actor] = targets.duplicate()
	if not _is_shaped(p):
		_preroll(caster, p, slot, char_level, affected)
	if _is_shaped(p):
		affected.clear()
		var cells := shape_cells(caster, p, aim)
		for a in order:
			if a.is_alive() and a.cell in cells and (p.hits_allies or not DungeonMap._same_side(a, caster)):
				affected.append(a)
		if p.vfx == "fireball":
			_preroll(caster, p, slot, char_level, affected)
			await _fireball_show(caster, aim, cells, p, affected)
		elif p.vfx == "burning_hands":
			_preroll(caster, p, slot, char_level, affected)
			await _burning_hands_fx(caster, cells)
		elif p.vfx in ["cone_of_cold", "frost_breath", "ice_storm"]:
			_preroll(caster, p, slot, char_level, affected)
			await _frost_fx(caster, cells, p.vfx == "ice_storm")
		elif p.vfx == "lightning":
			_preroll(caster, p, slot, char_level, affected)
			var end := IsoGrid.cell_to_world(cells[-1]) + Vector2(0, -8) if not cells.is_empty() else IsoGrid.cell_to_world(aim)
			Sfx.play(p.sfx)
			await SpellFx.lightning(map, _cast_from(caster), end)
			_floor_flash(cells, Color8(225, 240, 255), Color8(110, 150, 255))
		else:
			var beam := Projectile.fire(map, caster.body_position(), IsoGrid.cell_to_world(aim), Projectile.Style.BEAM, _spell_colour(p))
			await beam.done
			await _area_flash(cells)
	elif p.target != SpellData.Target.SELF and (p.resolve in [SpellData.Resolve.ATTACK, SpellData.Resolve.SAVE]):
		for a in _unique(affected):
			match p.vfx:
				"fire_bolt":
					await SpellFx.bolt(map, caster.body_position(), a.body_position())
				"sacred_flame":
					await SpellFx.column(map, a.position)
				"scorching_ray":
					pass                # one bolt per ray, with its attack roll
				_:
					var beam := Projectile.fire(map, caster.body_position(), a.body_position(), Projectile.Style.BEAM, _spell_colour(p))
					await beam.done
	if p.resolve == SpellData.Resolve.SAVE and p.vfx != "fireball" and not affected.is_empty() and show_dice(p.big_moment):
		await _dice_save(caster, p, affected, affected[0].body_position())
	match p.resolve:
		SpellData.Resolve.ATTACK:
			for a in affected:
				if p.vfx == "scorching_ray" and a.is_alive():
					await SpellFx.bolt(map, _cast_from(caster), a.body_position())
				await _spell_attack(caster, p, slot, a, char_level)
		SpellData.Resolve.SAVE:
			if _pre_dmg:
				_detail("  %s damage: %s" % [p.display_name, _pre_dmg.describe()])
			for a in affected:
				_spell_save(caster, p, a, _pre_dmg, _pre_saves.get(a))
		SpellData.Resolve.AUTO:
			if p.darts > 0:
				var bend := 16.0
				for a in affected:
					if a.is_alive():
						await SpellFx.dart(map, caster.body_position(), a.body_position(), bend)
						bend = -bend * 1.2
						SpellFx.sparkles(map, a.body_position(), _spell_colour(p), false).duration = 0.3
						var r := Dice.roll(p.damage_for(char_level, slot))
						_deal(caster, a, r.total, p.damage_type, false)
						await get_tree().create_timer(0.06).timeout
			if p.condition != "":
				for a in _unique(affected):
					if p.vfx == "bless":
						SpellFx.sparkles(map, a.body_position(), Color8(255, 220, 110))
					a.add_condition(p.condition, p.condition_rounds, caster, p)
					_say("  %s is %s." % [a.display_name(), Condition.display(p.condition).to_lower()])
					FloatText.spawn(map, a.body_position() + Vector2(0, -10), Condition.display(p.condition).to_upper(), COL_ALLY, 10)
		SpellData.Resolve.HEAL:
			for a in affected:
				var r := Dice.roll(p.heal_for(char_level, slot))
				var amount := r.total
				if p.add_ability_mod:
					amount += caster.stats.mod(caster.stats.spell_ability)
				if p.add_level:
					amount += caster.stats.level
				# Disciple of Life (Life Cleric): healing spells heal 2 + the slot level more.
				if caster.stats.class_id == "cleric" and p.uses_slot() and slot >= 1:
					amount += 2 + slot
				SpellFx.sparkles(map, a.body_position(), Color8(150, 235, 140))
				Sfx.play("heal_chime")
				var was_down := not a.is_alive()
				var got := a.heal(amount)
				# Blessed Healer (Life Cleric 6): healing someone else with a spell heals the cleric too.
				if caster.stats.blessed_healer and p.uses_slot() and slot >= 1 and a != caster and caster.is_alive():
					var bh := caster.heal(2 + slot)
					if bh > 0:
						_detail("  Blessed Healer: %s heals %d" % [caster.display_name(), bh])
				_detail("  heal %s: %s -> %d" % [a.display_name(), r.describe(), amount])
				_say("%s regains %d HP%s" % [a.display_name(), got, " and gets back up!" if was_down else ""])
				FloatText.spawn(map, a.body_position() + Vector2(0, -10), "+%d" % got, COL_ALLY, 10)
		SpellData.Resolve.CONTEST:
			for a in affected:
				await _contest(caster, p, a)
	await get_tree().create_timer(0.4).timeout


func _spell_attack(caster: Actor, p: SpellData, slot: int, target: Actor, char_level: int) -> void:
	if not target.is_alive():
		return
	var dist := DungeonMap.grid_distance(caster.cell, target.cell)
	var adv := Condition.attack_advantage(caster, target, p.range_cells() <= 1, dist)
	if p.range_cells() > 1 and _enemy_adjacent(caster):
		adv = combine_advantage(adv, -1)     # ranged spell attack with an enemy next to you
	var r := Dice.d20(p.attack_bonus_for(caster.stats), adv)
	_add_bonus_dice(r, caster)
	caster.remove_condition("hidden")
	var ac := target.stats.armor_class + Condition.ac_bonus(target)
	var crit := r.is_crit()
	var hit := crit or (not r.is_fumble() and r.total >= ac)
	if hit and not crit and await _offer_shield(target, caster, p.display_name, r.total, ac):
		ac += 5
		hit = false
	_detail("%s: %s vs AC %d - %s" % [p.display_name, r.describe(), ac, "crit" if crit else ("hit" if hit else "miss")])
	if not hit:
		_say("%s misses %s" % [caster.display_name(), target.display_name()])
		Sfx.play("miss_swish")
		if p.vfx == "fire_bolt":
			SpellFx.sparkles(map, target.body_position() + Vector2(10, 0), Color8(110, 104, 112), false).duration = 0.4
		FloatText.spawn(map, target.body_position() + Vector2(0, -10), "MISS", Color8(200, 196, 210), 10)
		return
	if p.damage != "":
		var expr := p.damage_for(char_level, slot)
		if p.vfx in ["fire_bolt", "scorching_ray"]:
			SpellFx.burst(map, target.body_position() + Vector2(0, 10), 0.6, 1.0)
			Sfx.play("fire_impact")
		var d := Dice.roll(Dice.crit(expr) if crit else expr)
		if crit and show_dice(true):
			await _dice_crit(caster, target, p.display_name, r, ac, d, p.damage_type)
		_deal(caster, target, d.total, p.damage_type, crit)
	if p.condition != "" and target.is_alive() and not _shrugs_off(target, p.condition):
		target.add_condition(p.condition, p.condition_rounds, caster, p)
		_say("  %s is %s!" % [target.display_name(), Condition.display(p.condition).to_lower()])
		FloatText.spawn(map, target.body_position() + Vector2(0, -18), Condition.display(p.condition).to_upper(), COL_MAGIC, 10)


func _spell_save(caster: Actor, p: SpellData, target: Actor, dmg_roll: DiceRoll, pre: DiceRoll = null) -> void:
	if not target.is_alive():
		return
	var dc := p.dc_for(caster.stats)
	var s := pre if pre else roll_save(target, p.save_ability, true)
	var saved := s.total >= dc
	if not saved:
		var again := _indomitable(target, p.save_ability, dc, true)
		if again:
			s = again
			saved = s.total >= dc
	_detail("  %s %s save: %s vs DC %d - %s" % [target.display_name(), p.save_ability, s.describe(), dc, "success" if saved else "FAILED"])
	if p.vfx == "sacred_flame" and not saved:
		SpellFx.sparkles(map, target.body_position(), Color8(255, 236, 150))
	if dmg_roll:
		var dmg := dmg_roll.total
		# Evasion (Rogue 7): an area DEX save for half: nothing on a success, half on a failure.
		var evade := target.stats.evasion and p.half_on_save and p.save_ability == "DEX" and _is_shaped(p)
		if saved:
			dmg = 0 if evade else (dmg / 2 if p.half_on_save else 0)
		elif evade:
			dmg = dmg / 2
			_say("  %s twists aside (Evasion): half damage." % target.display_name())
		if dmg > 0:
			_deal(caster, target, dmg, p.damage_type, false, " (half, saved)" if saved else "", p.display_name)
		else:
			_say("%s dodges the %s" % [target.display_name(), p.display_name])
			FloatText.spawn(map, target.body_position() + Vector2(0, -10), "SAVED", Color8(200, 196, 210), 10)
	elif saved:
		_say("%s resists the %s" % [target.display_name(), p.display_name])
		FloatText.spawn(map, target.body_position() + Vector2(0, -10), "RESISTED", Color8(200, 196, 210), 10)
	if not saved and p.condition != "" and target.is_alive() and not _shrugs_off(target, p.condition):
		var c := target.add_condition(p.condition, p.condition_rounds, caster, p)
		if p.save_each_turn:
			c.save_ability = p.save_ability
			c.save_dc = dc
		FloatText.spawn(map, target.body_position() + Vector2(0, -22), Condition.display(p.condition).to_upper(), COL_MAGIC, 10)
		_say("  %s is %s!" % [target.display_name(), Condition.display(p.condition).to_lower()])


## Skill contest: Shove (athletics vs athletics/acrobatics) or Hide (stealth vs passive perception).
func _contest(caster: Actor, p: SpellData, target: Actor) -> void:
	if p.id == "escape":
		_escape(caster)
		return
	var sadv := -1 if p.contest_skill == "stealth" and caster.stats.stealth_disadvantage else 0
	if p.id == "hide" and caster.stats.supreme_sneak:
		sadv = combine_advantage(sadv, 1)            # Supreme Sneak (Rogue 9)
	var mine := Dice.d20(caster.stats.skill_bonus(p.contest_skill), sadv)
	if p.id == "hide":
		var best := 0
		for a in order:
			if a.is_alive() and not DungeonMap._same_side(a, caster):
				best = maxi(best, a.stats.passive_perception())
		_detail("  Stealth %s vs passive Perception %d" % [mine.describe(), best])
		if mine.total > best:
			caster.add_condition("hidden", -1, caster, p)
			_say("%s hides! (next attack has advantage)" % caster.display_name())
			FloatText.spawn(map, caster.body_position() + Vector2(0, -10), "HIDDEN", COL_ALLY, 10)
		else:
			_say("%s fails to hide" % caster.display_name())
		return
	var theirs := -99
	for sk in p.resist_skills:
		theirs = maxi(theirs, target.stats.skill_bonus(sk))
	var their_roll := Dice.d20(theirs)
	_detail("  %s %s vs %s" % [p.contest_skill, mine.describe(), their_roll.describe()])
	caster.lunge(target.position, 5.0)
	if mine.total >= their_roll.total and shove_push:
		shove_push = false
		var dir := (target.cell - caster.cell).clampi(-1, 1)
		var dest := target.cell + dir
		if map.terrain_walkable(dest) and map.occupant(dest, target) == null:
			await target.step_to(dest, 0.16).finished
			Sfx.play("hit_blunt", -4.0, 0.8)
			_say("%s pushes %s back 5 ft!" % [caster.display_name(), target.display_name()])
			FloatText.spawn(map, target.body_position() + Vector2(0, -10), "PUSHED", COL_MAGIC, 10)
		else:
			_say("%s wins the shove, but %s has nowhere to go" % [caster.display_name(), target.display_name()])
		return
	shove_push = false
	if mine.total >= their_roll.total and target.stats.fly:
		_say("%s shoves %s, but it just floats back" % [caster.display_name(), target.display_name()])
	elif mine.total >= their_roll.total:
		target.add_condition(p.condition, p.condition_rounds, caster, p)
		_say("%s shoves %s prone!" % [caster.display_name(), target.display_name()])
		FloatText.spawn(map, target.body_position() + Vector2(0, -10), "PRONE", COL_MAGIC, 10)
	else:
		_say("%s fails to shove %s" % [caster.display_name(), target.display_name()])


## Damage + number + sound + down/slain message.
func _deal(src: Actor, target: Actor, amount: int, dtype: String, crit: bool, note := "", by := "") -> void:
	var dmg := _adjust(maxi(1, amount), dtype, target)
	apply_damage(target, dmg, dtype, crit)
	_say("%s %s %s: %d%s" % [by if by != "" else src.display_name(), "CRITS" if crit else "hits", target.display_name(), dmg, note])
	Sfx.play("crit_hit" if crit else _hit_sound(dtype))
	FloatText.spawn(map, target.body_position() + Vector2(0, -10), ("CRIT %d" if crit else "%d") % dmg,
			Color8(255, 220, 90) if crit else Color8(255, 120, 100), 20 if crit else 10)
	if not target.is_alive():
		_say("%s %s" % [target.display_name(), "is down!" if target is Hero else "is slain!"])


func _spell_colour(p: SpellData) -> Color:
	match p.vfx:
		"web": return Color8(232, 232, 236)
		"fear_ray": return Color8(190, 130, 255)
		"hold": return Color8(150, 200, 255)
	match p.damage_type:
		"fire": return Color8(255, 140, 50)
		"radiant": return Color8(255, 236, 150)
		"force": return Color8(150, 170, 255)
		"necrotic": return Color8(200, 90, 210)
		"lightning": return Color8(160, 200, 255)
		"cold": return Color8(150, 220, 255)
	return Color8(220, 220, 230)


## Quick flash over an area (Fireball gets its full sequence in step 6).
func _area_flash(cells: Array[Vector2i]) -> void:
	for k in 6:
		var a := 0.55 if k % 2 == 0 else 0.25
		map.overlay.set_cells("blast", cells, Color8(255, 200, 90), a, 0.9, true)
		await get_tree().create_timer(0.05).timeout
	map.overlay.clear("blast")


## Concentration: a new concentration spell ends the old one (its conditions on everyone).
func _start_concentration(caster: Actor, p: SpellData) -> void:
	if caster.concentrating:
		end_concentration(caster)
	caster.concentrating = p


func end_concentration(caster: Actor) -> void:
	var p := caster.concentrating
	if p == null:
		return
	caster.concentrating = null
	for a in order:
		for c in a.conditions.duplicate():
			if c.spell == p and c.source == caster:
				a.remove_condition(c.id)
	_say("%s's %s ends." % [caster.display_name(), p.display_name])


static func _unique(arr: Array[Actor]) -> Array[Actor]:
	var out: Array[Actor] = []
	for a in arr:
		if not a in out:
			out.append(a)
	return out


# --- damage, concentration, death saves (Phase 3 step 4) --------------------------------------

## All combat damage goes through here: concentration saves, dropping to 0, death-save failures
## for a hero already down, and massive damage (damage left over >= max HP kills outright).
func apply_damage(target: Actor, dmg: int, dtype := "", crit := false) -> void:
	if not target.is_alive():
		if target is Hero and not target.dead:
			if dmg >= target.stats.max_hp:
				_die(target, "massive damage")
			else:
				target.stable = false
				_death_fail(target, 1, "takes damage while down")
		return
	var before := target.hp
	# Undead Fortitude (zombie): a CON save (DC 5 + the damage) to stay up at 1 HP, unless the
	# damage is radiant or a critical hit.
	if dmg >= target.hp and dmg > 0 and "undead_fortitude" in target.stats.traits and dtype != "radiant" and not crit:
		var fs := roll_save(target, "CON")
		_detail("  %s Undead Fortitude (CON) save: %s vs DC %d" % [target.display_name(), fs.describe(), 5 + dmg])
		if fs.total >= 5 + dmg:
			dmg = target.hp - 1
			_say("%s refuses to fall! (Undead Fortitude)" % target.display_name())
			FloatText.spawn(map, target.body_position() + Vector2(0, -22), "UNDEAD FORTITUDE", COL_MAGIC, 10)
	if dmg > 0 and target.has_condition("turned"):
		target.remove_condition("turned")
	# Death Ward: the first drop to 0 HP is a drop to 1 instead.
	if dmg >= target.hp and dmg > 0 and target.has_condition("death_ward"):
		target.remove_condition("death_ward")
		dmg = target.hp - 1
		_say("%s's Death Ward flares: still standing at 1 HP!" % target.display_name())
		FloatText.spawn(map, target.body_position() + Vector2(0, -22), "DEATH WARD", COL_ALLY, 10)
	# Regeneration (troll): fire or acid stops it on the creature's next turn.
	if dmg > 0 and dtype in ["fire", "acid"] and "regeneration" in target.stats.traits:
		target.set_meta("regen_blocked", true)
	target.take_damage(dmg)
	if not target.is_alive() and target is Monster and "death_burst" in target.stats.traits:
		_death_burst(target)
	if target.concentrating:
		if not target.is_alive():
			end_concentration(target)
		else:
			var dc := maxi(10, dmg / 2)
			var s := roll_save(target, "CON")
			_detail("  %s concentration (CON) save: %s vs DC %d" % [target.display_name(), s.describe(), dc])
			if s.total < dc:
				_say("%s loses concentration!" % target.display_name())
				end_concentration(target)
	if not target.is_alive() and target is Hero:
		target.death_successes = 0
		target.death_failures = 0
		target.stable = false
		if dmg - before >= target.stats.max_hp:
			_die(target, "massive damage")


## A paralyzed creature loses its turn (then saves at its end, end_turn).
func _paralyzed_turn(a: Actor) -> void:
	_say("%s is paralyzed and can't act." % a.display_name())
	status_changed.emit("%s is paralyzed..." % a.display_name())
	await get_tree().create_timer(0.9).timeout
	if in_combat and current == a:
		end_turn()


static func _is_dying(h: Actor) -> bool:
	return h.hp <= 0 and not h.dead and not h.stable


## A downed hero's turn: roll the death save (d20: 10+ success, 1 = two failures, 20 = back up
## with 1 HP). 3 successes = stable, 3 failures = dead.
func _death_save_turn(h: Hero) -> void:
	status_changed.emit("%s is dying: death saving throw..." % h.display_name())
	await get_tree().create_timer(0.7).timeout
	if not in_combat or current != h:
		return
	var r := Dice.d20()
	Sfx.play("clack_small")
	_detail("%s death save: %s" % [h.display_name(), r.describe()])
	if r.natural == 20:
		h.heal(1)
		_say("%s rolls a 20 on the death save and gets back up!" % h.display_name())
		FloatText.spawn(map, h.body_position() + Vector2(0, -10), "20!", COL_ACTIVE, 20)
		await get_tree().create_timer(0.5).timeout
		_show_range()          # back up: the rest of the turn is theirs
		return
	if r.natural >= 10:
		h.death_successes += 1
		_say("%s death save: %d - success (%d/3)" % [h.display_name(), r.natural, h.death_successes])
		FloatText.spawn(map, h.body_position() + Vector2(0, -10), "%d OK" % r.natural, COL_ALLY, 10)
		if h.death_successes >= 3:
			h.stable = true
			_say("%s is stable." % h.display_name())
	else:
		_death_fail(h, 2 if r.natural == 1 else 1, "rolls %d" % r.natural)
	await get_tree().create_timer(0.8).timeout
	if in_combat and current == h:
		end_turn()


func _death_fail(h: Actor, n: int, why: String) -> void:
	h.death_failures = mini(3, h.death_failures + n)
	_say("%s %s - death save failure%s (%d/3)" % [h.display_name(), why, "s" if n > 1 else "", h.death_failures])
	FloatText.spawn(map, h.body_position() + Vector2(0, -10), "FAIL" if n == 1 else "FAIL x2", Color8(240, 110, 100), 10)
	if h.death_failures >= 3:
		_die(h, "")


func _die(h: Actor, why: String) -> void:
	h.dead = true
	h.stable = false
	h.hp = 0
	if h.concentrating:
		end_concentration(h)
	_say("%s has died%s." % [h.display_name(), (" (" + why + ")") if why != "" else ""])
	Sfx.play("fail_sting", -6.0)
	if h.has_method("on_died"):
		h.on_died()


# --- reactions (Shield) ------------------------------------------------------------------------

## -1 = ask the player, 0 = always no, 1 = always yes. Automated test runs set the environment
## variable HERRA_AUTO_REACT=0 or 1 so a prompt can never wait for a human.
var auto_reaction := int(OS.get_environment("HERRA_AUTO_REACT")) if OS.get_environment("HERRA_AUTO_REACT") != "" else -1
var reaction_pending := false


## `target` is about to be hit by `total` vs AC `ac`. If it can cast Shield and +5 AC would turn
## the hit into a miss, ask the player. Returns true if Shield was cast (the attack misses).
func _offer_shield(target: Actor, attacker: Actor, what: String, total: int, ac: int) -> bool:
	if not target is Hero or target.reaction_used or total >= ac + 5:
		return false
	var sh := target.power("shield")
	if sh == null or not target.can_use(sh):
		return false
	var yes := false
	if auto_reaction >= 0:
		yes = auto_reaction == 1
	else:
		reaction_pending = true
		reaction_prompt.emit("%s's %s (%d) would hit %s (AC %d).\nCast Shield? +5 AC until their next turn, uses a 1st-level slot (%d left)." % [
				attacker.display_name(), what, total, target.display_name(), ac, target.slots_left[0]])
		yes = await reaction_answered
		reaction_pending = false
	if not yes:
		return false
	target.reaction_used = true
	target.spend_slot(target.lowest_slot_for(sh))
	target.add_condition("shielded", 1, target, sh)
	_say("%s casts Shield! (AC %d)" % [target.display_name(), ac + 5])
	target.play_action("cast")
	get_tree().create_timer(0.6).timeout.connect(target.end_action)
	Sfx.play("charge", -4.0, 1.4)
	SpellFx.sparkles(map, target.body_position(), Color8(130, 170, 255))
	FloatText.spawn(map, target.body_position() + Vector2(0, -18), "SHIELD", Color8(150, 180, 255), 10)
	return true


## Uncanny Dodge (Rogue 5): reaction when hit by an attack it can see - halve the damage. Asks the
## player when it matters (8+ damage, or the hit would drop them); returns true if used.
func _offer_uncanny_dodge(target: Actor, attacker: Actor, what: String, dmg: int) -> bool:
	if not target is Hero or target.reaction_used or dmg < 2 or target.power("uncanny_dodge") == null:
		return false
	if not target.is_alive() or target.has_condition("paralyzed"):
		return false
	if dmg < 8 and dmg < target.hp:
		return false               # not worth the reaction: don't ask
	var yes := false
	if auto_reaction >= 0:
		yes = auto_reaction == 1
	else:
		reaction_pending = true
		reaction_prompt.emit("%s's %s hits %s for %d.\nUse Uncanny Dodge? Halve the damage (%d), uses your reaction." % [
				attacker.display_name(), what, target.display_name(), dmg, dmg / 2])
		yes = await reaction_answered
		reaction_pending = false
	if not yes:
		return false
	target.reaction_used = true
	_say("%s uses Uncanny Dodge!" % target.display_name())
	Sfx.play("miss_swish", -2.0, 1.2)
	FloatText.spawn(map, target.body_position() + Vector2(0, -26), "DODGE", COL_ALLY, 10)
	return true


## Another creature on `attacker`'s side stands next to `target` (pack tactics, martial advantage).
func _ally_next_to(attacker: Actor, target: Actor) -> bool:
	for x in order:
		if x != attacker and x.is_alive() and DungeonMap._same_side(x, attacker) \
				and not x.has_condition("paralyzed") and DungeonMap.grid_distance(x.cell, target.cell) <= 1:
			return true
	return false


func answer_reaction(yes: bool) -> void:
	if reaction_pending:
		reaction_answered.emit(yes)


# --- class abilities (Phase 3 step 5) ----------------------------------------------------------

## Sneak Attack (Rogue): once per turn, a finesse or ranged weapon attack that has advantage, or
## whose target has another enemy of it (the rogue's ally) within 5 ft - and no disadvantage.
func _sneak_applies(attacker: Actor, target: Actor, a: AttackData, adv: int) -> bool:
	if sneak_used or attacker != current or attacker.power("sneak_attack") == null:
		return false
	if not (a.ability == AttackData.Ability.FINESSE or a.kind == AttackData.Kind.RANGED):
		return false
	if adv < 0:
		return false
	if adv > 0:
		return true
	for x in order:
		if x != attacker and x.is_alive() and DungeonMap._same_side(x, attacker) \
				and DungeonMap.grid_distance(x.cell, target.cell) <= 1:
			return true
	return false


## For the attack hint: would this option get Sneak Attack?
func sneak_preview(attacker: Actor, target: Actor, o: Dictionary) -> bool:
	return _sneak_applies(attacker, target, o.attack, o.adv)


# --- Fireball showcase (Phase 3 step 6) --------------------------------------------------------

func _cast_from(caster: Actor) -> Vector2:
	return caster.cast_point() if caster.has_method("cast_point") else caster.body_position()


## Charge at the staff gem, fly in an arc lighting the room, then the 3x3 blast with flash, shake,
## scorch and smoke. Returns at the moment of the blast (damage is resolved while it plays).
func _fireball_show(caster: Actor, aim: Vector2i, cells: Array[Vector2i], p: SpellData, affected: Array[Actor]) -> void:
	announce.emit("%s CASTS %s!" % [caster.display_name().to_upper(), "FIREBALL"])
	var gem := _cast_from(caster)
	await FireballFx.charge(map, gem)
	var centre := IsoGrid.cell_to_world(aim) + Vector2(0, 2)
	await FireballFx.fly(map, gem, centre + Vector2(0, -8))
	# Time freezes at the moment of impact: the dice scene (big moment).
	if show_dice(true):
		await _dice_save(caster, p, affected, IsoGrid.cell_to_world(aim) + Vector2(0, -8))
	var worlds: Array[Vector2] = []
	for c in cells:
		worlds.append(IsoGrid.cell_to_world(c) + Vector2(0, 2))
	FireballFx.explode(map, centre, worlds)
	map.camera_controller.shake(3.0, 0.4)
	_floor_flash(cells)
	await get_tree().create_timer(0.12).timeout
	_leave_scorch(aim, cells)


## The 3x3 floor flashes white-hot, then fades through orange (as the mock-up's aoe_fire).
func _floor_flash(cells: Array[Vector2i], hot := Color8(255, 200, 90), cool := Color8(255, 110, 40)) -> void:
	for k in 8:
		var fire := 1.0 - k / 7.0
		map.overlay.set_cells("blast", cells, hot.lerp(cool, 1.0 - fire), 0.75 * fire, 0.9 * fire, true)
		await get_tree().create_timer(0.07).timeout
	map.overlay.clear("blast")


func _leave_scorch(aim: Vector2i, cells: Array[Vector2i]) -> void:
	await get_tree().create_timer(0.2).timeout
	for c in cells:
		if map.has_floor(c):
			map.scorch.add_mark(c, 1.0 if c == aim else 0.62)


# --- dice-roll scene (Phase 3 step 7) ----------------------------------------------------------

enum DiceMode { FULL, BIG, QUICK, OFF }
const DICE_MODE_NAMES := ["Full", "Big moments", "Quick", "Off"]
## Full = every spell save + every crit; Big moments = Fireball & area spells, crits; Quick / Off =
## inline rolls only (Quick is a placeholder for a later short pop-up).
var dice_mode := DiceMode.BIG
var _pre_dmg: DiceRoll
var _pre_saves := {}


func show_dice(big: bool) -> bool:
	if map.dice == null:
		return false
	match dice_mode:
		DiceMode.FULL:
			return true
		DiceMode.BIG:
			return big
	return false


func cycle_dice_mode() -> void:
	dice_mode = ((dice_mode + 1) % DiceMode.size()) as DiceMode
	_say("Dice scene: %s" % DICE_MODE_NAMES[dice_mode])


## Roll a save spell's damage and every target's save up front, so the dice scene shows the very
## rolls that are then applied.
func _preroll(caster: Actor, p: SpellData, slot: int, char_level: int, affected: Array[Actor]) -> void:
	_pre_dmg = null
	_pre_saves.clear()
	if p.resolve != SpellData.Resolve.SAVE:
		return
	if p.damage != "":
		_pre_dmg = Dice.roll(p.damage_for(char_level, slot))
	for a in affected:
		if a.is_alive():
			_pre_saves[a] = roll_save(a, p.save_ability, true)


const ABILITY_WORDS := {"STR": "STRENGTH", "DEX": "DEXTERITY", "CON": "CONSTITUTION", "INT": "INTELLIGENCE", "WIS": "WISDOM", "CHA": "CHARISMA"}


func _screen(world: Vector2) -> Vector2:
	return map.get_viewport().get_canvas_transform() * world


## Saves (first three targets in full, then a summary line) and the damage dice.
func _dice_save(caster: Actor, p: SpellData, affected: Array[Actor], spot: Vector2) -> void:
	await map.dice.open(_screen(spot))
	var dc := p.dc_for(caster.stats)
	var shown := 0
	for a in affected:
		if not _pre_saves.has(a):
			continue
		if shown >= 3:
			break
		var s: DiceRoll = _pre_saves[a]
		var saved := s.total >= dc
		var note := ("takes half damage" if p.half_on_save else "takes no damage") if saved else ("takes full damage" if _pre_dmg else "is affected")
		await map.dice.show_d20("%s: %s SAVE" % [a.display_name().to_upper(), ABILITY_WORDS.get(p.save_ability, p.save_ability)],
				"d20 %+d  vs  spell DC %d" % [a.stats.save_bonus(p.save_ability), dc], s,
				"SAVED!" if saved else "FAILED!", saved if not DungeonMap._same_side(a, caster) else not saved, note)
		shown += 1
	if _pre_dmg:
		await map.dice.show_damage("%s DAMAGE: %s" % [p.display_name.to_upper(), p.damage_for(maxi(1, caster.stats.level), 0) if p.upcast_dice == "" else _pre_dmg.expr],
				_pre_dmg, p.damage_type, Color8(255, 170, 90))
	await map.dice.close()


## A critical hit: the natural 20, then the (doubled) damage dice.
func _dice_crit(attacker: Actor, target: Actor, what: String, roll: DiceRoll, ac: int, dmg: DiceRoll, dtype: String, sneak: DiceRoll = null) -> void:
	await map.dice.open(_screen(target.body_position()))
	await map.dice.show_d20("%s: %s" % [attacker.display_name().to_upper(), what.to_upper()],
			"d20 %+d  vs  AC %d" % [roll.modifier, ac], roll, "CRITICAL HIT!", attacker is Hero, "damage dice are doubled")
	await map.dice.show_damage("DAMAGE: %s" % dmg.expr, dmg, dtype, Color8(255, 220, 90))
	if sneak:
		await map.dice.show_damage("SNEAK ATTACK: %s" % sneak.expr, sneak, dtype, Color8(214, 120, 230))
	await map.dice.close()


# --- monster powers + break free (Phase 3 step 8) ----------------------------------------------

## How much a monster wants to use condition power `p` on hero `h` from cell `c` (0 = can't/won't).
## chance the condition lands x how much it's worth (in expected-damage units).
const CONDITION_VALUE := {"restrained": 9.0, "frightened": 12.0, "prone": 4.0, "paralyzed": 16.0}
## A little randomness so monsters don't do exactly the same thing every turn.
const AI_JITTER := 1.5


func _power_value(m: Actor, p: SpellData, h: Actor, c: Vector2i) -> float:
	if p.kind == SpellData.Kind.MONSTER and p.damage != "" and m.can_use(p):
		return _damage_power_value(m, p, h, c)
	if p.kind != SpellData.Kind.MONSTER or p.condition == "" or not m.can_use(p) or h.has_condition(p.condition) \
			or p.condition in h.stats.condition_immunities:
		return 0.0
	var dist := DungeonMap.grid_distance(c, h.cell)
	if dist > maxi(1, p.range_cells()) or (p.needs_los and not map.has_line_of_sight(c, h.cell)):
		return 0.0
	var chance := 0.0
	match p.resolve:
		SpellData.Resolve.ATTACK:
			var adv := -1 if (p.range_cells() > 1 and _enemies_adjacent_at(m, c) > 0) else 0
			chance = hit_chance(p.attack_bonus_for(m.stats), h.stats.armor_class, adv)
		SpellData.Resolve.SAVE:
			chance = clampf((p.dc_for(m.stats) - h.stats.save_bonus(p.save_ability) - 1) / 20.0, 0.05, 0.95)
	return chance * CONDITION_VALUE.get(p.condition, 3.0)


## Is `target` immune to condition `cid` (Ring of Free Action: restrained)? Says so in the log
## with the item that protects it.
func _shrugs_off(target: Actor, cid: String) -> bool:
	if cid not in target.stats.condition_immunities:
		return false
	var why := ""
	var eq = target.get("equipment")
	if eq is Dictionary:
		for slot in eq:
			var it := ItemData.get_item(eq[slot])
			if it and cid in it.condition_immunities:
				why = " (%s)" % it.display_name
				break
	_say("  %s can't be %s%s." % [target.display_name(), Condition.display(cid).to_lower(), why])
	FloatText.spawn(map, target.body_position() + Vector2(0, -18), "IMMUNE", Color8(200, 196, 210), 10)
	return true


## "Break free" from a web (restrained): an action, STR check (Athletics or Acrobatics, whichever is
## better) against the effect's DC. Offered in the Spell/Ability menu while restrained.
static var ESCAPE: SpellData = _make_escape()


static func _make_escape() -> SpellData:
	var s := SpellData.new()
	s.id = "escape"
	s.display_name = "Break free"
	s.kind = SpellData.Kind.ABILITY
	s.cast_time = SpellData.CastTime.ACTION
	s.target = SpellData.Target.SELF
	s.resolve = SpellData.Resolve.CONTEST
	s.needs_los = false
	s.description = "Action: Strength (Athletics) or Dexterity (Acrobatics) check against the web's DC. Success: you are no longer restrained."
	return s


func _escape(who: Actor) -> void:
	var c := who.get_condition("restrained")
	if c == null:
		return
	var dc: int = c.spell.dc_override if c.spell and c.spell.dc_override != -99 else 12
	var bonus := maxi(who.stats.skill_bonus("athletics"), who.stats.skill_bonus("acrobatics"))
	var r := Dice.d20(bonus)
	_detail("  break free: %s vs DC %d" % [r.describe(), dc])
	if r.total >= dc:
		who.remove_condition("restrained")
		_say("%s breaks free! (%d vs DC %d)" % [who.display_name(), r.total, dc])
		FloatText.spawn(map, who.body_position() + Vector2(0, -10), "FREE", COL_ALLY, 10)
	else:
		_say("%s struggles in the web (%d vs DC %d)" % [who.display_name(), r.total, dc])


# --- items (Phase 4 step 4) ---------------------------------------------------------------------
## Potions in a fight: the Item action (SRD: drinking a potion or giving one to another creature
## is an action). The drinker is the hero or an adjacent ally, downed ones included (it gets them
## back up). Each potion kind becomes a small runtime power so it reuses the ally targeting.

static var _item_powers := {}


## The heal "power" behind a potion (cached per item id).
static func item_power(it: ItemData) -> SpellData:
	if _item_powers.has(it.id):
		return _item_powers[it.id]
	var p := SpellData.new()
	p.id = "item_" + it.id
	p.display_name = it.display_name
	p.description = it.description
	p.kind = SpellData.Kind.ABILITY
	p.cast_time = SpellData.CastTime.ACTION
	p.target = SpellData.Target.ALLY
	p.range_ft = 5
	p.needs_los = false
	p.resolve = SpellData.Resolve.HEAL
	p.heal = it.heal
	p.sfx = "potion_drink"
	p.set_meta("item_id", it.id)
	_item_powers[it.id] = p
	return p


## A power that uses up a bag item (potion or scroll).
static func is_item_power(p: SpellData) -> bool:
	return p != null and p.has_meta("item_id")


static func is_potion_power(p: SpellData) -> bool:
	return is_item_power(p) and not p.is_scroll()


# Spell scrolls (SRD Spell Scroll, Phase 4 step 5): if the spell is on your class's spell list you
# can read it, casting it at the scroll's level with the scroll's save DC / attack bonus and no slot
# (the scroll crumbles). A spell above the level you can cast needs a spellcasting ability check
# (DC 10 + its level) or the scroll is wasted. Casting time = the spell's.

static var _scroll_powers := {}


## The spell behind a scroll: a copy of it marked as read from that scroll (cached per item id).
static func scroll_power(it: ItemData) -> SpellData:
	if _scroll_powers.has(it.id):
		return _scroll_powers[it.id]
	var p: SpellData = it.spell.duplicate()
	p.dc_override = SpellData.scroll_dc(p.level)
	p.attack_bonus_override = SpellData.scroll_attack_bonus(p.level)
	p.set_meta("item_id", it.id)
	p.set_meta("scroll", true)
	p.set_meta("item_name", it.display_name)
	_scroll_powers[it.id] = p
	return p


## The power used when this item is picked from the Item menu (null: not usable that way).
static func use_power(it: ItemData) -> SpellData:
	if it.kind == ItemData.Kind.POTION and it.heal != "":
		return item_power(it)
	if it.kind == ItemData.Kind.SCROLL and it.spell != null:
		return scroll_power(it)
	return null


## Why `h` can't read scroll `it` at all ("" = it can).
static func scroll_problem(h: Actor, it: ItemData) -> String:
	if it.spell == null:
		return "the scroll is blank"
	if h.stats.spell_ability == "" or not it.spell.classes.has(h.stats.class_id):
		return "not on %s's spell list" % h.display_name()
	return ""


## Highest spell level `h` can cast with its own slots (0 = cantrips only / none).
static func max_spell_level(h: Actor) -> int:
	var top := 0
	for i in h.stats.spell_slots.size():
		if h.stats.spell_slots[i] > 0:
			top = i + 1
	return top


## A scroll of a spell above what the reader can cast needs this check DC (0 = no check).
static func scroll_check_dc(h: Actor, p: SpellData) -> int:
	return 10 + p.level if p.level > max_spell_level(h) else 0


## Bag items for the hero's Item menu: [{item, count, ok, why}]: potions and scrolls.
func menu_items(h: Actor) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if map.inventory == null:
		return out
	for st: Dictionary in map.inventory.stacks:
		var it := ItemData.get_item(st.id)
		var p := use_power(it) if it else null
		if p == null or p.cast_time in [SpellData.CastTime.REACTION, SpellData.CastTime.FREE]:
			continue
		var why := ""
		if it.kind == ItemData.Kind.SCROLL:
			why = scroll_problem(h, it)
		if why != "":
			pass
		elif p.cast_time == SpellData.CastTime.BONUS:
			if bonus_used:
				why = "bonus action used"
		elif action_used or attacks_left < h.stats.attacks_per_action():
			why = "action used"
		if why == "" and p.target in [SpellData.Target.ENEMY, SpellData.Target.ALLY, SpellData.Target.ANY] \
				and valid_targets(h, p).is_empty():
			why = "no one in reach needs healing" if p.resolve == SpellData.Resolve.HEAL else "no target in range"
		out.append({item = it, count = st.count, ok = why == "", why = why, power = p})
	return out


## Item menu pick: a potion (choose who drinks it: the hero or an adjacent ally) or a scroll
## (target its spell as usual).
func begin_item(item_id: String) -> void:
	var it := ItemData.get_item(item_id)
	if it == null or not map.inventory.has(item_id) or use_power(it) == null:
		return
	if it.kind == ItemData.Kind.SCROLL and scroll_problem(current, it) != "":
		return
	begin_targeting(use_power(it))


## Outside combat (inventory screen): read a healing scroll on `who`. The reader is the first
## conscious hero who can read it. Returns the HP regained, or -1 (with `why` set) if it can't.
func read_now(who: Actor, item_id: String) -> Dictionary:
	var it := ItemData.get_item(item_id)
	if it == null or it.kind != ItemData.Kind.SCROLL or it.spell == null:
		return {got = -1, why = "That isn't a scroll."}
	if it.spell.resolve != SpellData.Resolve.HEAL:
		return {got = -1, why = "Save the %s for a fight (the Item action)." % it.display_name}
	var reader: Actor = null
	for h: Actor in map.party:
		if h.is_alive() and scroll_problem(h, it) == "":
			reader = h
			break
	if reader == null:
		return {got = -1, why = "Nobody awake can read the %s." % it.display_name}
	if who.dead:
		return {got = -1, why = "%s is beyond the help of healing." % who.display_name()}
	if who.is_alive() and who.hp >= who.stats.max_hp:
		return {got = -1, why = "%s is unhurt: no need for the %s." % [who.display_name(), it.display_name]}
	var p := scroll_power(it)
	if scroll_check_dc(reader, p) > 0:
		return {got = -1, why = "%s can't cast spells that powerful yet: read it in a fight." % reader.display_name()}
	if not map.inventory.remove(item_id):
		return {got = -1, why = "None left."}
	var r := Dice.roll(p.heal_for(maxi(1, reader.stats.level), p.level))
	var amount := r.total + (reader.stats.mod(reader.stats.spell_ability) if p.add_ability_mod else 0)
	var was_down := not who.is_alive()
	var got := who.heal(amount)
	Sfx.play("scroll_read")
	get_tree().create_timer(0.4).timeout.connect(func(): Sfx.play("heal_chime"))
	SpellFx.sparkles(map, who.body_position(), Color8(150, 235, 140))
	FloatText.spawn(map, who.body_position() + Vector2(0, -10), "+%d" % got, COL_ALLY, 10)
	_detail("  %s: %s -> %d" % [it.display_name, r.describe(), amount])
	_say("%s reads a %s on %s: +%d HP%s" % [reader.display_name(), it.display_name,
			"themself" if who == reader else who.display_name(), got, " (back up!)" if was_down else ""])
	return {got = got, why = "", reader = reader}


## Outside combat (inventory screen): `who` drinks a potion straight away, no action needed.
## Returns the HP regained, or -1 if it couldn't (not a potion, none left, dead, already full).
func drink_now(who: Actor, item_id: String) -> int:
	var it := ItemData.get_item(item_id)
	if it == null or it.kind != ItemData.Kind.POTION or it.heal == "" or who.dead \
			or (who.is_alive() and who.hp >= who.stats.max_hp) or not map.inventory.remove(item_id):
		return -1
	var r := Dice.roll(it.heal)
	var was_down := not who.is_alive()
	var got := who.heal(r.total)
	Sfx.play("potion_drink")
	get_tree().create_timer(0.45).timeout.connect(func(): Sfx.play("heal_chime"))
	SpellFx.sparkles(map, who.body_position(), Color8(150, 235, 140))
	FloatText.spawn(map, who.body_position() + Vector2(0, -10), "+%d" % got, COL_ALLY, 10)
	_detail("  %s: %s -> %d" % [it.display_name, r.describe(), r.total])
	_say("%s drinks a %s and regains %d HP%s" % [who.display_name(), it.display_name, got, " (back up!)" if was_down else ""])
	return got


# --- class features (Phase 5) ------------------------------------------------------------------

## Undead enemies `caster` can turn: within the power's range and in sight.
func _undead_in_range(caster: Actor, p: SpellData) -> Array[Actor]:
	var out: Array[Actor] = []
	for a in order:
		if a.is_alive() and not DungeonMap._same_side(a, caster) and a.stats.creature_type == "undead" \
				and DungeonMap.grid_distance(caster.cell, a.cell) <= p.range_cells() \
				and map.has_line_of_sight(caster.cell, a.cell):
			out.append(a)
	return out


## Channel Divinity: Turn Undead (SRD) - each undead in 30 ft that sees the cleric makes a WIS
## save or is turned for a minute (ends on damage). Cleric 5: Destroy Undead - a turned undead
## of CR 1/2 or lower is destroyed outright.
func _turn_undead(caster: Actor, p: SpellData) -> void:
	caster.play_action("cast")
	Sfx.play("radiant")
	SpellFx.sparkles(map, caster.body_position(), Color8(255, 236, 150))
	await SpellFx.charge(map, _cast_from(caster) + Vector2(0, 2), Color8(255, 236, 150))
	var dc := p.dc_for(caster.stats)
	for a in _undead_in_range(caster, p):
		var s := roll_save(a, "WIS")
		var saved := s.total >= dc
		_detail("  %s WIS save: %s vs DC %d - %s" % [a.display_name(), s.describe(), dc, "success" if saved else "FAILED"])
		if saved:
			_say("%s resists the holy light" % a.display_name())
			FloatText.spawn(map, a.body_position() + Vector2(0, -10), "RESISTED", Color8(200, 196, 210), 10)
			continue
		SpellFx.column(map, a.position)
		if caster.stats.destroy_undead_cr >= 0.0 and a.stats.challenge <= caster.stats.destroy_undead_cr:
			_say("%s is destroyed by the holy light!" % a.display_name())
			FloatText.spawn(map, a.body_position() + Vector2(0, -10), "DESTROYED", COL_ACTIVE, 10)
			apply_damage(a, a.hp, "radiant")
		else:
			a.add_condition("turned", 10, caster, p)
			_say("%s is turned!" % a.display_name())
			FloatText.spawn(map, a.body_position() + Vector2(0, -10), "TURNED", COL_ACTIVE, 10)
		await get_tree().create_timer(0.15).timeout
	await get_tree().create_timer(0.4).timeout


## Burning Hands: a fan of flame bursts over the cone, nearest cells first.
func _burning_hands_fx(caster: Actor, cells: Array[Vector2i]) -> void:
	var sorted := cells.duplicate()
	sorted.sort_custom(func(x, y): return DungeonMap.grid_distance(caster.cell, x) < DungeonMap.grid_distance(caster.cell, y))
	Sfx.play("fire_impact")
	for c: Vector2i in sorted:
		SpellFx.burst(map, IsoGrid.cell_to_world(c), 0.45, 0.7)
		await get_tree().create_timer(0.03).timeout
	await get_tree().create_timer(0.3).timeout


# --- traps and levers in a fight (Mechanisms) -------------------------------------------------

## Why the current hero can't use `thing` now, or "". Disarming a trap takes the action; pulling a
## lever is the free object interaction; nothing else can be used mid-fight.
func _thing_problem(thing: MapMarker) -> String:
	if not (thing is Trap or thing is Lever):
		return "No time for that in the middle of a fight!"
	if DungeonMap.grid_distance(current.cell, thing.get_cell()) > 1:
		return "Move next to it first"
	if thing is Trap:
		if action_used or attacks_left < current.stats.attacks_per_action():
			return "Disarming a trap takes your action (already used)"
	elif interact_used:
		return "You have already used an object this turn"
	return ""


func _use_thing(thing: MapMarker) -> void:
	var why := _thing_problem(thing)
	if why != "":
		status_changed.emit(why)
		Sfx.play("fail_sting", -12.0)
		return
	current.facing = (thing.get_cell() - current.cell).clampi(-1, 1)
	if thing is Trap:
		action_used = true
		attacks_left = 0
		var who: Array[Hero] = [current]
		map.mech.try_disarm(thing, who)
	else:
		interact_used = true
		map.mech.pull(thing, current)
	map.refresh_navigation()
	if in_combat and not _check_end():
		_check_join()
		_show_range()


# --- levels 6-9 and new monster traits ---------------------------------------------------------

## A save against `dc`, with Indomitable (Fighter 9) rerolling a failure once per long rest.
func save_vs(who: Actor, ability: String, dc: int, vs_magic := false) -> DiceRoll:
	var r := roll_save(who, ability, vs_magic)
	if r.total < dc:
		var again := _indomitable(who, ability, dc, vs_magic)
		if again:
			return again
	return r


## Indomitable: if `who` has it left, reroll the failed save (logged). Returns the new roll or null.
func _indomitable(who: Actor, ability: String, dc: int, vs_magic: bool) -> DiceRoll:
	if not who.stats.indomitable or who.uses_left.get("indomitable", 0) <= 0:
		return null
	who.uses_left["indomitable"] -= 1
	var r := roll_save(who, ability, vs_magic)
	_say("%s refuses to give in (Indomitable): %s save again, %d vs DC %d." % [who.display_name(), ability, r.total, dc])
	FloatText.spawn(map, who.body_position() + Vector2(0, -22), "INDOMITABLE", COL_ACTIVE, 10)
	return r


## Death Burst (ice mephit): it shatters into shards; everyone next to it makes a DEX save (DC 10)
## or takes 1d8 slashing (half on a success).
func _death_burst(m: Actor) -> void:
	_say("%s bursts into a spray of ice shards!" % m.display_name())
	SpellFx.burst(map, m.body_position(), 0.7, 0.8)
	Sfx.play("hit_slash", -4.0, 1.4)
	for a in order.duplicate():
		if a == m or not a.is_alive() or DungeonMap.grid_distance(a.cell, m.cell) > 1:
			continue
		var dmg := Dice.roll("1d8").total
		var s := save_vs(a, "DEX", 10)
		if s.total >= 10:
			dmg /= 2
		if dmg > 0:
			_deal(m, a, dmg, "slashing", false, " (ice shards%s)" % (", half" if s.total >= 10 else ""))


## How much a monster wants to use damaging power `p` aimed at hero `h` from cell `c`: the expected
## damage to every hero it would catch (an area / cone / line can catch several), minus most of what
## it would do to its own side. Breath weapons, a mage's Fireball, the Frost Wizard's spells.
func _damage_power_value(m: Actor, p: SpellData, h: Actor, c: Vector2i) -> float:
	var dist := DungeonMap.grid_distance(c, h.cell)
	if dist > maxi(1, p.range_cells()) or (p.needs_los and not map.has_line_of_sight(c, h.cell)):
		return 0.0
	var avg := Dice.average(p.damage)
	if not _is_shaped(p):
		match p.resolve:
			SpellData.Resolve.ATTACK:
				return hit_chance(p.attack_bonus_for(m.stats), h.stats.armor_class) * avg
			SpellData.Resolve.SAVE:
				return _save_damage_value(m, p, h, avg)
		return avg
	var cells := shape_cells(m, p, h.cell, c)
	var total := 0.0
	for a in order:
		if not a.is_alive() or a == m or not a.cell in cells:
			continue
		var v := _save_damage_value(m, p, a, avg) if p.resolve == SpellData.Resolve.SAVE else avg
		if a is Hero:
			total += v
		elif p.hits_allies:
			total -= v * 0.8
	return total


## Expected damage of a save-for-half (or none) power on one creature.
func _save_damage_value(m: Actor, p: SpellData, who: Actor, avg: float) -> float:
	var fail := clampf((p.dc_for(m.stats) - who.stats.save_bonus(p.save_ability) - 1) / 20.0, 0.05, 0.95)
	return avg * (fail + ((1.0 - fail) * 0.5 if p.half_on_save else 0.0))


## Cone of Cold / a breath of frost: icy bursts sweeping out from the caster; Ice Storm: hail
## falling over the area. Then a blue-white floor flash.
func _frost_fx(caster: Actor, cells: Array[Vector2i], storm: bool) -> void:
	var sorted := cells.duplicate()
	if storm:
		sorted.shuffle()
	else:
		sorted.sort_custom(func(x, y): return DungeonMap.grid_distance(caster.cell, x) < DungeonMap.grid_distance(caster.cell, y))
	for c: Vector2i in sorted:
		var at := IsoGrid.cell_to_world(c)
		if storm:
			SpellFx.dart(map, at + Vector2(randf_range(-10, 10), -60), at, 0.0)
		SpellFx.sparkles(map, at + Vector2(0, -6), Color8(190, 236, 255), false).duration = 0.4
		await get_tree().create_timer(0.025 if not storm else 0.05).timeout
	_floor_flash(cells, Color8(236, 248, 255), Color8(110, 170, 240))
	await get_tree().create_timer(0.35).timeout
