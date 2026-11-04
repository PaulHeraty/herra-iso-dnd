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
signal log_line(text: String)

const DETECT_INTERVAL := 0.2
const MONSTER_TURN_PAUSE := 0.8     ## step 3 placeholder: monsters "wait" this long
const COL_ACTIVE := Color8(255, 220, 90)

var map: DungeonMap
var in_combat := false
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
	if current is Hero and Input.is_action_just_pressed("end_turn"):
		end_turn()


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
		_say("%s initiative: %s" % [a.display_name(), r.describe()])
	all.sort_custom(func(x: Actor, y: Actor) -> bool:
		if initiative[x] != initiative[y]:
			return initiative[x] > initiative[y]
		if x.stats.dex_score != y.stats.dex_score:
			return x.stats.dex_score > y.stats.dex_score
		return tiebreak[x] > tiebreak[y])
	order = all
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
	# Skip anyone who has dropped since (death comes in step 5).
	for i in order.size():
		_turn_index += 1
		if _turn_index >= order.size():
			_turn_index = 0
			round_number += 1
			_say("-- Round %d --" % round_number)
		if order[_turn_index].is_alive():
			break
	current = order[_turn_index]
	map.camera_controller.target = current
	map.camera_controller.recenter()
	_pulse_t = 0.0
	turn_started.emit(current)
	if current is Monster:
		_monster_turn(current)


func _monster_turn(m: Monster) -> void:
	await get_tree().create_timer(MONSTER_TURN_PAUSE).timeout
	if not in_combat or current != m:
		return
	_say("%s waits." % m.display_name())
	end_turn()


## Leave combat (step 8 decides when; available for tests/debugging now).
func end_combat() -> void:
	if not in_combat:
		return
	in_combat = false
	current = null
	order.clear()
	map.overlay.clear("active")
	map.camera_controller.target = map.party[0]
	map.controller.enabled = true
	combat_ended.emit()


# --- helpers ---------------------------------------------------------------------------------

func _say(text: String) -> void:
	print("[combat] ", text)
	log_line.emit(text)


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
