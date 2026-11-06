class_name MapBuilder
extends RefCounted
## Builds map scenes (DungeonMap) from short descriptions, for any module: a module's build_maps.gd
## holds the data and calls build_floor / build_surface (see modules/wraith_below/build_maps.gd).
## The scenes are ordinary maps you can keep editing in the editor; re-building OVERWRITES them.
##
##
## DUNGEON FLOORS are laid out on a grid of slots (SLOT cells each). A room sits centred in its
## slot; a link between rooms in slots on the same row or column becomes a straight corridor with
## an arch on the first room's wall and a door on the second's. Room contents are placed by the
## builder from short descriptions:
##   spawn "kkS"     monsters by letter (MONSTERS), placed away from the doorways, one group per room
##   theme           props / decor / braziers / pillars (THEMES)
##   chests          [[gold, [items], lock_dc (0 = open), key_id]]  placed against the back wall
##   stairs / arrive / start  as before (stairs: [up, target map, target entry])
## Phase 6 (dungeon features):
##   name + desc     a RoomNote over the room: its description shows the first time the party walks in
##   clue            instead of desc: a modal note (inscriptions, puzzle rules) in the dialogue box
##   traps           [{t = spikes / darts / fire / pit / alarm, at = cell in the room or "auto",
##                    detect, disarm, save, dmg, type, atk, xp, one_shot}]
##   puzzle          {kind = sequence / blocks / ring / riddle / lever, link, opens, ...} (_puzzle)
##   link options    {secret = true, sdc, link}: a secret door (on the SECOND room's wall: list the
##                   hidden room first); {gate = "name"}: a portcullis opened by the puzzle whose
##                   `opens` (or lever whose link) is "name"; {trap = {...}}: a trap mid-corridor
## THE WOODS are clearings joined by dirt paths; every cell near them is a block of forest (or
## cliff in the cliff zones), so the clearings read as glades in a dense wood.

const F = PartyStart.Facing
const FLOOR_SRC := 0
const WALL_SRC := 1
const FOREST_SRC := 2
enum WallRow { FACE_L, FACE_R, BOTH, CAP }
const SLOT := Vector2i(15, 13)
const TRAP_TYPES := {"spikes": Trap.TrapType.SPIKES, "darts": Trap.TrapType.DARTS, "fire": Trap.TrapType.FIRE_JET,
	"pit": Trap.TrapType.PIT, "alarm": Trap.TrapType.ALARM}
## default damage type, one_shot
const TRAP_DEFAULTS := {"spikes": ["piercing", false], "darts": ["poison", false], "fire": ["fire", false],
	"pit": ["bludgeoning", true], "alarm": ["", true]}
const SYMBOLS := {"sun": Lever.Symbol.SUN, "moon": Lever.Symbol.MOON, "star": Lever.Symbol.STAR,
	"skull": Lever.Symbol.SKULL, "eye": Lever.Symbol.EYE}

const MONSTERS := {
	"r": "giant_rat", "w": "wolf", "g": "goblin", "G": "goblin_boss", "b": "bandit", "z": "zombie",
	"k": "skeleton", "u": "ghoul", "U": "ghast", "h": "hobgoblin", "B": "bugbear", "O": "ogre",
	"W": "wight", "M": "mummy", "p": "specter", "X": "wraith", "S": "giant_spider", "E": "eye_tyrant",
}
const PROPS := {
	"barrel": Prop.Kind.BARREL, "crate": Prop.Kind.CRATE, "sarcophagus": Prop.Kind.SARCOPHAGUS,
	"rubble": Prop.Kind.RUBBLE, "cocoon": Prop.Kind.COCOON, "urn": Prop.Kind.URN,
	"oak": Prop.Kind.TREE_OAK, "pine": Prop.Kind.TREE_PINE, "bush": Prop.Kind.BUSH,
	"boulder": Prop.Kind.BOULDER, "stump": Prop.Kind.STUMP, "log": Prop.Kind.LOG,
	"tent": Prop.Kind.TENT, "grave": Prop.Kind.GRAVE, "stall": Prop.Kind.STALL,
}
## theme -> what furnishes a room: wall props (along the walls), mid props (in the middle, on a
## grid), bones, web, braziers (corners), pillars.
const THEMES := {
	"hall": {"wall": ["urn", "urn", "rubble"], "bones": 1, "braziers": 2},
	"guard": {"wall": ["barrel", "barrel", "crate", "crate"], "bones": 1, "web": true},
	"store": {"wall": ["crate", "crate", "crate", "barrel", "barrel", "barrel", "urn"]},
	"crypt": {"mid": ["sarcophagus", "sarcophagus", "sarcophagus", "sarcophagus"], "wall": ["urn", "urn"], "web": true, "braziers": 1},
	"nest": {"wall": ["cocoon", "cocoon", "cocoon", "cocoon", "rubble"], "bones": 3, "web": true},
	"ossuary": {"wall": ["urn", "urn", "urn", "rubble"], "mid": ["sarcophagus"], "bones": 4, "web": true},
	"lair": {"pillars": true, "braziers": 4, "bones": 2, "web": true, "wall": ["urn"]},
	"warren": {"wall": ["crate", "barrel", "rubble", "rubble", "crate"], "bones": 2, "braziers": 1},
	"barracks": {"wall": ["crate", "crate", "barrel", "barrel", "crate"], "braziers": 2},
	"kennel": {"wall": ["rubble", "barrel"], "bones": 5},
	"throne": {"pillars": true, "braziers": 4, "wall": ["urn", "urn", "crate"], "bones": 1},
	"tomb": {"mid": ["sarcophagus", "sarcophagus"], "wall": ["urn", "urn", "urn"], "braziers": 2, "web": true},
	"flooded": {"wall": ["rubble", "rubble", "urn"], "bones": 2, "web": true},
	"vault": {"pillars": true, "braziers": 4, "wall": ["urn", "urn"], "mid": ["sarcophagus"]},
	"bare": {},
}


var rnd := RandomNumberGenerator.new()


## XP of a map description: its monsters, plus disarmed traps and solved puzzles.
func xp_of(d: Dictionary) -> int:
	var xp := 0
	var areas: Dictionary = d.get("rooms", d.get("clearings", {}))
	for k in areas:
		for ch in areas[k].get("spawn", ""):
			var s: CreatureStats = load("res://data/monsters/%s.tres" % MONSTERS[ch])
			xp += s.xp
		# Phase 6: disarmed traps and solved puzzles / riddles
		for t in areas[k].get("traps", []):
			xp += t.get("xp", 25)
		xp += areas[k].get("puzzle", {}).get("xp", 0)
	for l in d.get("links", []):
		if l.size() > 2 and l[2].has("trap"):
			xp += l[2].trap.get("xp", 25)
	return xp


# --- dungeon floors ---------------------------------------------------------------------------------

func build_floor(d: Dictionary, root_name: String, path: String) -> bool:
	var ok := true
	# rooms: interior rects centred in their slots
	var rects := {}
	for rn in d.rooms:
		var room: Dictionary = d.rooms[rn]
		var size: Vector2i = room.size
		var origin: Vector2i = room.slot * SLOT + Vector2i(2, 2)
		rects[rn] = Rect2i(origin + (SLOT - Vector2i(3, 3) - size) / 2, size)
	var floor_cells := {}
	for rn in rects:
		var r: Rect2i = rects[rn]
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				floor_cells[Vector2i(x, y)] = rn
	var doors := []         # [cell, locked, dc, key, link options]
	var secret_cells := {}  # secret doors: painted as floor, but their neighbours treat them as wall
	var corridor_traps := []    # [cell, spec, name]
	var doorways := {}
	var entries := {}       # room -> its doorway cells (to keep clear)
	for l in d.links:
		var a: Rect2i = rects[l[0]]
		var b: Rect2i = rects[l[1]]
		var opts: Dictionary = l[2] if l.size() > 2 else {}
		var cells: Array[Vector2i] = []
		var door_cell: Vector2i
		var arch_cell: Vector2i
		var sa: Vector2i = d.rooms[l[0]].slot
		var sb: Vector2i = d.rooms[l[1]].slot
		if sa.y == sb.y:
			var lo := maxi(a.position.y, b.position.y)
			var hi := mini(a.end.y, b.end.y) - 1
			var y := (lo + hi) / 2
			var left := a if a.position.x < b.position.x else b
			var right := b if left == a else a
			for x in range(left.end.x, right.position.x):
				cells.append(Vector2i(x, y))
			door_cell = Vector2i(b.position.x - 1, y) if b == right else Vector2i(b.end.x, y)
			arch_cell = Vector2i(a.end.x, y) if a == left else Vector2i(a.position.x - 1, y)
		elif sa.x == sb.x:
			var lo := maxi(a.position.x, b.position.x)
			var hi := mini(a.end.x, b.end.x) - 1
			var x := (lo + hi) / 2
			var top := a if a.position.y < b.position.y else b
			var bot := b if top == a else a
			for y in range(top.end.y, bot.position.y):
				cells.append(Vector2i(x, y))
			door_cell = Vector2i(x, b.position.y - 1) if b == bot else Vector2i(x, b.end.y)
			arch_cell = Vector2i(x, a.end.y) if a == top else Vector2i(x, a.position.y - 1)
		else:
			push_error("%s: link %s-%s: rooms not on one row or column" % [root_name, l[0], l[1]])
			ok = false
			continue
		for c in cells:
			if floor_cells.has(c) and floor_cells[c] != "":
				push_error("%s: corridor %s-%s runs through room %s" % [root_name, l[0], l[1], floor_cells[c]])
				ok = false
			floor_cells[c] = ""
		var is_door: bool = opts.get("door", true)
		if is_door:
			doors.append([door_cell, opts.has("locked"), opts.get("locked", 0), opts.get("key", ""), opts])
		if opts.get("secret", false):
			secret_cells[door_cell] = true
		if opts.has("trap") and cells.size() >= 3:
			corridor_traps.append([cells[cells.size() / 2], opts.trap, "%s%s" % [l[0], l[1]]])
		doorways[door_cell] = true
		doorways[arch_cell] = true
		for rn in [l[0], l[1]]:
			if not entries.has(rn):
				entries[rn] = []
		entries[l[1]].append(door_cell)
		entries[l[0]].append(arch_cell)
	# pillars
	var pillars := {}
	for rn in d.rooms:
		if THEMES[d.rooms[rn].get("theme", "bare")].get("pillars", false):
			var r: Rect2i = rects[rn]
			if r.size.x >= 9 and r.size.y >= 8:
				for p in [Vector2i(2, 2), Vector2i(r.size.x - 3, 2), Vector2i(2, r.size.y - 3), Vector2i(r.size.x - 3, r.size.y - 3)]:
					pillars[r.position + p] = true
	for p in pillars:
		floor_cells.erase(p)
	var walls := {}
	for c: Vector2i in floor_cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if not floor_cells.has(n):
					walls[n] = true

	var root := _make_root(root_name, d.title, "res://assets/tiles/dungeon_tileset.tres", Color(0.34, 0.36, 0.50), d.start_level)
	var floor: TileMapLayer = root.get_node("Floor")
	var wall_layer: TileMapLayer = root.get_node("World/Walls")
	var entities: Node2D = root.get_node("World/Entities")
	var decor: Node2D = root.get_node("World/Decor")
	for c: Vector2i in floor_cells:
		floor.set_cell(c, FLOOR_SRC, Vector2i(rnd.randi_range(0, 7), 1 if doorways.has(c) else 0))
	_paint_walls(wall_layer, walls, WALL_SRC, {}, secret_cells)

	for dd in doors:
		var c: Vector2i = dd[0]
		var door := _inst("door", entities, root, c, "Door_%d_%d" % [c.x, c.y])
		if walls.has(c + Vector2i(1, 0)) and walls.has(c - Vector2i(1, 0)):
			door.wall_run = Door.WallRun.BACK_RIGHT
		elif walls.has(c + Vector2i(0, 1)) and walls.has(c - Vector2i(0, 1)):
			door.wall_run = Door.WallRun.BACK_LEFT
		else:
			push_error("%s: door at %s is not in a wall run" % [root_name, c])
			ok = false
		door.locked = dd[1]
		if dd[1]:
			door.lock_dc = dd[2]
			door.key_id = dd[3]
		var dopts: Dictionary = dd[4]
		if dopts.get("secret", false):
			door.style = Door.Style.SECRET
			door.secret_dc = dopts.get("sdc", 15)
			door.link = dopts.get("link", "")
		elif dopts.has("gate"):
			door.style = Door.Style.PORTCULLIS
			door.link = dopts.gate

	var blocked := {}        # cells with props / chests / braziers / stairs (for the checks)
	var group := 1
	var start_cell := Vector2i.ZERO
	for rn in d.rooms:
		var room: Dictionary = d.rooms[rn]
		var r: Rect2i = rects[rn]
		var theme: Dictionary = THEMES[room.get("theme", "bare")]
		var o := r.position
		_torches(r, walls, doorways, entities, root, rn)
		# cells to keep clear: in front of every doorway, plus the stairs and arrival
		var keep := {}
		for e: Vector2i in entries.get(rn, []):
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					keep[e + Vector2i(dx, dy)] = true
			for k in range(2, 4):
				keep[e + (_inward(e, r) * k)] = true
		var used := {}
		for p in pillars:
			used[p] = true
		# stairs: back corner area; arrival next to them
		if room.has("stairs"):
			var s: Array = room.stairs
			var sc := o + Vector2i(r.size.x - 2, 1)
			if keep.has(sc):
				sc = o + Vector2i(1, r.size.y - 2)
			var st := _inst("stairs", entities, root, sc, "Stairs_" + ("Up" if s[0] else "Down"))
			st.up = s[0]
			st.target_map = s[1]
			st.target_entry = s[2]
			used[sc] = true
			blocked[sc] = true
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					keep[sc + Vector2i(dx, dy)] = true
			if room.has("arrive"):
				var ac := sc + Vector2i(-1, 1)
				var ps := _inst("party_start", entities, root, ac, "PartyStart_" + room.arrive)
				ps.entry_id = room.arrive
				ps.facing = F.SOUTH_WEST
				keep[ac] = true
				if room.get("start", false):
					var main := _inst("party_start", entities, root, ac, "PartyStart")
					main.facing = F.SOUTH_WEST
					start_cell = ac
		# Phase 6: the room's puzzle pieces, traps and description (before the furniture)
		if room.has("puzzle"):
			_puzzle(room.puzzle, r, rn, keep, used, blocked, entities, root, root_name)
		for tspec in room.get("traps", []):
			var tc: Vector2i
			if tspec.get("at", "auto") is String:
				tc = _auto_trap_cell(r, keep, used)
			else:
				tc = o + tspec.at
				if keep.has(tc) or used.has(tc):
					push_error("%s: trap in %s at %s is in the way of something" % [root_name, rn, tspec.at])
					_ok = false
			_trap(tspec, tc, entities, root, "Trap_%s_%d_%d" % [rn, tc.x, tc.y])
			used[tc] = true
		_note(room, r, entities, root, rn)
		# braziers in the corners
		var corners :=[Vector2i(0, 0), Vector2i(r.size.x - 1, r.size.y - 1), Vector2i(r.size.x - 1, 0), Vector2i(0, r.size.y - 1)]
		var nb: int = theme.get("braziers", 0)
		for c in corners:
			if nb <= 0:
				break
			var cc: Vector2i = o + c
			if keep.has(cc) or used.has(cc):
				continue
			_inst("brazier", entities, root, cc, "Brazier_%s_%d_%d" % [rn, cc.x, cc.y])
			used[cc] = true
			blocked[cc] = true
			nb -= 1
		# chests against the back wall
		for ch in room.get("chests", []):
			var cc := _free_near(o + Vector2i(r.size.x / 2, 0), r, keep, used)
			var chest := _inst("chest", entities, root, cc, "Chest_%s_%d_%d" % [rn, cc.x, cc.y])
			chest.gold = ch[0]
			chest.items.assign(ch[1])
			if ch.size() > 2 and ch[2] > 0:
				chest.locked = true
				chest.lock_dc = ch[2]
			used[cc] = true
			blocked[cc] = true
		# props in the middle (sarcophagi) and along the walls
		var mids := [Vector2i(2, 2), Vector2i(r.size.x - 3, 2), Vector2i(2, r.size.y - 3), Vector2i(r.size.x - 3, r.size.y - 3)]
		var mi := 0
		for kind in theme.get("mid", []):
			while mi < mids.size() and (keep.has(o + mids[mi]) or used.has(o + mids[mi])):
				mi += 1
			if mi >= mids.size():
				break
			var mc: Vector2i = o + mids[mi]
			_prop(kind, mc, entities, root, rn)
			used[mc] = true
			blocked[mc] = true
			mi += 1
		var edge := _edge_cells(r)
		_shuffle(edge)
		var ei := 0
		for kind in theme.get("wall", []):
			while ei < edge.size() and (keep.has(edge[ei]) or used.has(edge[ei]) or _crowded(edge[ei], used)):
				ei += 1
			if ei >= edge.size():
				break
			_prop(kind, edge[ei], entities, root, rn)
			used[edge[ei]] = true
			blocked[edge[ei]] = true
			ei += 1
		# decor: web in the back corner, bones about
		if theme.get("web", false):
			_web(decor, root, o, rn)
		var interior := _interior(r)
		_shuffle(interior)
		var nbones: int = theme.get("bones", 0)
		for c in interior:
			if nbones <= 0:
				break
			if not used.has(c):
				_bones(decor, root, c, rn)
				nbones -= 1
		# monsters: far from the doorways, spread out
		var spawn: String = room.get("spawn", "")
		if spawn != "":
			var cells := _monster_cells(r, spawn.length(), entries.get(rn, []), keep, used)
			for i in spawn.length():
				var id: String = MONSTERS[spawn[i]]
				if i >= cells.size():
					push_error("%s: no room for monster %d in %s" % [root_name, i, rn])
					ok = false
					break
				var mc: Vector2i = cells[i]
				var sp := _inst("monster_spawn", entities, root, mc, "%s_%s_%d_%d" % [id.to_pascal_case(), rn, mc.x, mc.y])
				sp.monster_id = id
				sp.group_id = group
				sp.facing = _facing_toward(mc, entries.get(rn, [r.get_center()]))
				_set_preview(sp, id)
				used[mc] = true
			group += 1
	for ct in corridor_traps:
		_trap(ct[1], ct[0], entities, root, "Trap_%s_%d_%d" % [ct[2], ct[0].x, ct[0].y])
	(root.get_node("Camera") as Camera2D).position = IsoGrid.view_cell_to_world(start_cell)
	ok = _check(root_name, floor_cells, blocked, start_cell, rects) and ok and _ok
	_save(root, path)
	return ok


# --- Phase 6: traps, puzzles, notes --------------------------------------------------------------

var _ok := true


func _trap(spec: Dictionary, c: Vector2i, entities: Node2D, root: Node, node_name: String) -> void:
	var t := _inst("trap", entities, root, c, node_name)
	var kind: String = spec.t
	t.trap_type = TRAP_TYPES[kind]
	t.detect_dc = spec.get("detect", 13)
	t.disarm_dc = spec.get("disarm", 13)
	t.save_dc = spec.get("save", 12)
	t.save_ability = spec.get("ability", "DEX")
	t.damage = spec.get("dmg", "" if kind == "alarm" else "2d6")
	t.damage_type = spec.get("type", TRAP_DEFAULTS[kind][0])
	t.attack_bonus = spec.get("atk", 0)
	t.one_shot = spec.get("one_shot", TRAP_DEFAULTS[kind][1])
	t.xp = spec.get("xp", 25)
	t.position = IsoGrid.view_cell_to_world(c) + Trap.SORT_UP


## A free cell near the middle of the room (where the party walks through).
func _auto_trap_cell(r: Rect2i, keep: Dictionary, used: Dictionary) -> Vector2i:
	var mid := r.get_center()
	var best := mid
	var bd := 999.0
	for c: Vector2i in _interior(r):
		if keep.has(c) or used.has(c):
			continue
		var d := Vector2(c - mid).length() + rnd.randf() * 0.5
		if d < bd:
			bd = d
			best = c
	return best


## A room description over the whole room (caption), or a clue (modal).
func _note(room: Dictionary, r: Rect2i, entities: Node2D, root: Node, rn: String) -> void:
	var text: String = room.get("clue", room.get("desc", ""))
	if text == "":
		return
	var n := _inst("room_note", entities, root, r.position, "Note_" + rn)
	n.title = room.get("name", "")
	n.text = text
	n.size = r.size
	n.modal = room.has("clue")


## Place a puzzle's pieces (cells relative to the room) and its Puzzle marker.
func _puzzle(pz: Dictionary, r: Rect2i, rn: String, keep: Dictionary, used: Dictionary, blocked: Dictionary,
		entities: Node2D, root: Node, root_name: String) -> void:
	var o := r.position
	var take := func(rel: Vector2i, what: String, blocks: bool) -> Vector2i:
		var c := o + rel
		if not r.has_point(c) or keep.has(c) or used.has(c):
			push_error("%s: %s in %s at %s is outside the room or in the way" % [root_name, what, rn, rel])
			_ok = false
		used[c] = true
		if blocks:
			blocked[c] = true
		return c
	var kind: String = pz.kind
	var p_kind := -1
	match kind:
		"sequence":
			for lv in pz.levers:                       # [symbol, cell]
				var c: Vector2i = take.call(lv[1], "lever", true)
				var lever := _inst("lever", entities, root, c, "Lever_%s_%s" % [rn, lv[0]])
				lever.link = pz.link
				lever.symbol = SYMBOLS[lv[0]]
			p_kind = Puzzle.Kind.SEQUENCE
		"blocks":
			for i in pz.plates.size():
				var c: Vector2i = take.call(pz.plates[i], "plate", false)
				var plate := _inst("pressure_plate", entities, root, c, "Plate_%s_%d" % [rn, i])
				plate.link = pz.link
				plate.position = IsoGrid.view_cell_to_world(c) + PressurePlate.SORT_UP
			for i in pz.blocks.size():
				var c: Vector2i = take.call(pz.blocks[i], "block", true)
				var b := _inst("prop", entities, root, c, "Block_%s_%d" % [rn, i])
				b.kind = Prop.Kind.BLOCK
				b.pushable = true
				b.link = pz.link
			var rc: Vector2i = take.call(pz.reset, "reset lever", true)
			var rl := _inst("lever", entities, root, rc, "Lever_%s_reset" % rn)
			rl.link = pz.link
			rl.role = "reset"
			p_kind = Puzzle.Kind.ALL_ON
		"ring":
			for i in pz.braziers.size():
				var c: Vector2i = take.call(pz.braziers[i], "brazier", true)
				var b := _inst("brazier", entities, root, c, "Brazier_%s_ring%d" % [rn, i])
				b.link = pz.link
				b.order = i
				b.lit = pz.lit[i] == 1
			p_kind = Puzzle.Kind.RING
		"riddle":
			var c: Vector2i = take.call(pz.at, "stone face", true)
			var f := _inst("stone_face", entities, root, c, "StoneFace_" + rn)
			f.link = pz.link
			f.riddle = pz.riddle
			f.answers.assign(pz.answers)
			f.correct = pz.correct
			f.wrong_damage = pz.get("damage", "2d6")
			f.xp = pz.get("xp", 0)
		"lever":
			var c: Vector2i = take.call(pz.at, "lever", true)
			var lever := _inst("lever", entities, root, c, "Lever_" + rn)
			lever.link = pz.link
	if p_kind >= 0:
		var p := _inst("puzzle", entities, root, o, "Puzzle_" + rn)
		p.link = pz.link
		p.kind = p_kind
		p.opens = pz.opens
		p.solution = pz.get("solution", "")
		p.penalty = pz.get("penalty", "")
		p.xp = pz.get("xp", 0)
		if pz.has("solved_text"):
			p.solved_text = pz.solved_text


## Unit step from a doorway cell into its room.
func _inward(e: Vector2i, r: Rect2i) -> Vector2i:
	if e.y < r.position.y:
		return Vector2i(0, 1)
	if e.y >= r.end.y:
		return Vector2i(0, -1)
	if e.x < r.position.x:
		return Vector2i(1, 0)
	return Vector2i(-1, 0)


func _edge_cells(r: Rect2i) -> Array:
	var out := []
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			if x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1:
				out.append(Vector2i(x, y))
	return out


func _interior(r: Rect2i) -> Array:
	var out := []
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			out.append(Vector2i(x, y))
	return out


## Two wall props side by side would wall off a corner: keep one cell apart (except in a corner run).
func _crowded(c: Vector2i, used: Dictionary) -> bool:
	var n := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if used.has(c + d):
			n += 1
	return n >= 2


func _free_near(c: Vector2i, r: Rect2i, keep: Dictionary, used: Dictionary) -> Vector2i:
	for k in range(0, r.size.x):
		for s in [1, -1]:
			var t := c + Vector2i(k * s, 0)
			if r.has_point(t) and not keep.has(t) and not used.has(t):
				return t
	return c + Vector2i(0, 1)


## Cells for n monsters: the far half of the room from its doorways, two cells apart if possible.
func _monster_cells(r: Rect2i, n: int, entries: Array, keep: Dictionary, used: Dictionary) -> Array[Vector2i]:
	var cand := []
	for c: Vector2i in _interior(r):
		if keep.has(c) or used.has(c):
			continue
		var d := 99
		for e: Vector2i in entries:
			d = mini(d, DungeonMap.grid_distance(c, e))
		cand.append([c, d + rnd.randf() * 1.5])
	cand.sort_custom(func(a, b): return a[1] > b[1])
	var out: Array[Vector2i] = []
	for spacing in [2, 1]:
		for cd in cand:
			if out.size() >= n:
				break
			var c: Vector2i = cd[0]
			if c in out:
				continue
			var ok := true
			for o in out:
				if DungeonMap.grid_distance(c, o) < spacing:
					ok = false
					break
			if ok:
				out.append(c)
	return out


func _facing_toward(c: Vector2i, targets: Array) -> int:
	var best: Vector2i = targets[0]
	for t: Vector2i in targets:
		if DungeonMap.grid_distance(c, t) < DungeonMap.grid_distance(c, best):
			best = t
	var d := best - c
	if absi(d.x) >= absi(d.y):
		return F.SOUTH_EAST if d.x > 0 else F.NORTH_WEST
	return F.SOUTH_WEST if d.y > 0 else F.NORTH_EAST


## Torches on the room's walls: on the back walls every few cells, and one back-face torch in the
## middle of each front wall so the room is lit evenly.
func _torches(r: Rect2i, walls: Dictionary, doorways: Dictionary, entities: Node2D, root: Node, rn: String) -> void:
	var spots := []
	var step := 4
	for x in range(r.position.x + 1, r.end.x - 1, step):
		spots.append([Vector2i(x, r.position.y - 1), Torch.Face.LEFT])
	for y in range(r.position.y + 1, r.end.y - 1, step):
		spots.append([Vector2i(r.position.x - 1, y), Torch.Face.RIGHT])
	spots.append([Vector2i(r.position.x + r.size.x / 2, r.end.y), Torch.Face.BACK_RIGHT])
	spots.append([Vector2i(r.end.x, r.position.y + r.size.y / 2), Torch.Face.BACK_LEFT])
	var used := {}
	for s in spots:
		var c: Vector2i = s[0]
		for shift in [0, 1, -1, 2, -2]:
			var along := Vector2i(1, 0) if s[1] in [Torch.Face.LEFT, Torch.Face.BACK_RIGHT] else Vector2i(0, 1)
			var t: Vector2i = c + along * shift
			if walls.has(t) and not doorways.has(t) and not doorways.has(t + along) and not doorways.has(t - along) and not used.has(t):
				c = t
				break
		if not walls.has(c) or used.has(c) or doorways.has(c):
			continue
		used[c] = true
		var torch := (load("res://scenes/markers/torch.tscn") as PackedScene).instantiate()
		torch.name = "Torch_%s_%d_%d" % [rn, c.x, c.y]
		torch.face = s[1]
		torch.position = IsoGrid.view_cell_to_world(c) + torch._snap_offset()
		_add(entities, torch, root)


# --- the woods ------------------------------------------------------------------------------------------

func build_surface(d: Dictionary, root_name: String, path: String) -> bool:
	var ok := true
	var floor_cells := {}       # cell -> "grass" / "path" / "forest"
	var rects := {}
	for cn in d.clearings:
		var r: Rect2i = d.clearings[cn].rect
		rects[cn] = r
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var c := Vector2i(x, y)
				# ragged edges: drop a few corner cells
				var corner := (x == r.position.x or x == r.end.x - 1) and (y == r.position.y or y == r.end.y - 1)
				if corner and rnd.randf() < 0.7:
					continue
				var edge := x == r.position.x or x == r.end.x - 1 or y == r.position.y or y == r.end.y - 1
				floor_cells[c] = "forest" if edge and rnd.randf() < 0.6 else "grass"
	var path_cells := {}
	for p in d.paths:
		var a: Vector2i = p[0]
		var b: Vector2i = p[1]
		var c := a
		var wiggle := 0
		while c != b:
			for k in 2:
				var w := c + (Vector2i(0, k) if c.x != b.x else Vector2i(k, 0))
				path_cells[w] = true
			if c.x != b.x:
				c.x += signi(b.x - c.x)
				if rnd.randf() < 0.15 and c.x != b.x:
					wiggle = clampi(wiggle + rnd.randi_range(-1, 1), -1, 1)
			else:
				c.y += signi(b.y - c.y)
		path_cells[b] = true
	for c in path_cells:
		floor_cells[c] = "path"
	# every other cell of the area (and a 2-cell rim) is forest: no holes of void inside the woods
	var walls := {}
	var bounds := Rect2i(floor_cells.keys()[0], Vector2i.ONE)
	for c: Vector2i in floor_cells:
		bounds = bounds.expand(c)
	bounds = bounds.grow(2)
	bounds.size += Vector2i.ONE
	for x in range(bounds.position.x, bounds.end.x):
		for y in range(bounds.position.y, bounds.end.y):
			if not floor_cells.has(Vector2i(x, y)):
				walls[Vector2i(x, y)] = true
	var cliff_cells := {}
	for c in walls:
		for cr: Rect2i in d.cliffs:
			if cr.has_point(c):
				cliff_cells[c] = true

	var root := _make_root(root_name, d.title, "res://assets/tiles/outdoor_tileset.tres", Color(0.56, 0.56, 0.7), d.start_level)
	var floor: TileMapLayer = root.get_node("Floor")
	var wall_layer: TileMapLayer = root.get_node("World/Walls")
	var entities: Node2D = root.get_node("World/Entities")
	var decor: Node2D = root.get_node("World/Decor")
	for c: Vector2i in floor_cells:
		var row: int = {"grass": 0, "path": 1, "forest": 2}[floor_cells[c]]
		floor.set_cell(c, FLOOR_SRC, Vector2i(rnd.randi_range(0, 7), row))
	_paint_walls(wall_layer, walls, FOREST_SRC, cliff_cells)

	var blocked := {}
	var group := 1
	var start_cell := Vector2i.ZERO
	for cn in d.clearings:
		var cl: Dictionary = d.clearings[cn]
		var r: Rect2i = cl.rect
		var o := r.position
		var used := {}
		for c in path_cells:
			used[c] = true                # paths stay clear
		for p in cl.get("props", []):
			_prop(p[0], o + p[1], entities, root, cn)
			used[o + p[1]] = true
			blocked[o + p[1]] = true
		for f in cl.get("campfire", []):
			var b := _inst("brazier", entities, root, o + f, "Campfire_%s" % cn)
			b.campfire = true
			used[o + f] = true
			blocked[o + f] = true
		for ch in cl.get("chests", []):
			var cc: Vector2i = o + ch[2]
			var chest := _inst("chest", entities, root, cc, "Chest_%s" % cn)
			chest.gold = ch[0]
			chest.items.assign(ch[1])
			used[cc] = true
			blocked[cc] = true
		for b: Vector2i in cl.get("bones", []):
			_bones(decor, root, o + b, cn)
		for tspec in cl.get("traps", []):
			var tc: Vector2i = o + tspec.at
			if not floor_cells.has(tc) or blocked.has(tc):
				push_error("%s: trap in %s at %s is not on open ground" % [root_name, cn, tspec.at])
				_ok = false
			_trap(tspec, tc, entities, root, "Trap_%s_%d_%d" % [cn, tc.x, tc.y])
			used[tc] = true
		_note(cl, r, entities, root, cn)
		if cl.has("trader"):
			var tr: Dictionary = cl.trader
			_prop("stall", o + tr.stall, entities, root, cn)
			var npc := _inst("npc", entities, root, o + tr.npc, "Npc_Brannoc")
			npc.npc_id = "brannoc"
			npc.display_name = "Brannoc"
			npc.guard_radius = 12
			var pt := _inst("portal", entities, root, o + tr.portal, "Portal_Home")
			pt.home = true
			var ps := _inst("party_start", entities, root, o + tr.arrive, "PartyStart_portal")
			ps.entry_id = RunePortal.HOME_ENTRY
			ps.facing = F.NORTH_EAST
			for c: Vector2i in [tr.stall, tr.npc, tr.portal, tr.arrive]:
				used[o + c] = true
			blocked[o + tr.stall] = true
			blocked[o + tr.npc] = true
		var entry_cells: Array = []
		if cl.has("start"):
			var ps := _inst("party_start", entities, root, o + cl.start[0], "PartyStart")
			ps.facing = cl.start[1]
			start_cell = o + cl.start[0]
		if cl.has("stairs"):
			var s: Array = cl.stairs
			var st := _inst("stairs", entities, root, o + s[0], "Stairs_Mine")
			st.cave = true
			st.target_map = s[1]
			st.target_entry = s[2]
			used[o + s[0]] = true
			blocked[o + s[0]] = true
			var a: Array = cl.arrive
			var ap := _inst("party_start", entities, root, o + a[0], "PartyStart_" + a[1])
			ap.entry_id = a[1]
			ap.facing = a[2]
			for dx in range(-1, 2):
				for dy in range(-1, 3):
					used[o + s[0] + Vector2i(dx, dy)] = true
		# a few trees and bushes round the edge of the glade (not on the paths)
		for c: Vector2i in _edge_cells(r):
			if floor_cells.has(c) and not used.has(c) and not _crowded(c, used) and rnd.randf() < 0.22:
				var kind: String = ["pine", "oak", "bush", "pine"][rnd.randi_range(0, 3)]
				_prop(kind, c, entities, root, cn)
				used[c] = true
				blocked[c] = true
		# entrances: where paths touch the clearing (monsters face them)
		for c in path_cells:
			if r.grow(1).has_point(c) and not r.has_point(c):
				entry_cells.append(c)
		if entry_cells.is_empty():
			entry_cells.append(r.get_center())
		var spawn: String = cl.get("spawn", "")
		if spawn != "":
			var keep := {}
			for e: Vector2i in entry_cells:
				for dx in range(-2, 3):
					for dy in range(-2, 3):
						keep[e + Vector2i(dx, dy)] = true
			var free := {}
			for c in used:
				if not path_cells.has(c):
					free[c] = true
			var cells := _monster_cells(r, spawn.length(), entry_cells, keep, free)
			for i in spawn.length():
				if i >= cells.size():
					push_error("%s: no room for monster %d in %s" % [root_name, i, cn])
					ok = false
					break
				var id: String = MONSTERS[spawn[i]]
				var mc: Vector2i = cells[i]
				var sp := _inst("monster_spawn", entities, root, mc, "%s_%s_%d_%d" % [id.to_pascal_case(), cn, mc.x, mc.y])
				sp.monster_id = id
				sp.group_id = group
				sp.facing = _facing_toward(mc, entry_cells)
				_set_preview(sp, id)
			group += 1
	# lone trees along the paths outside the clearings make the paths read as forest tracks
	(root.get_node("Camera") as Camera2D).position = IsoGrid.view_cell_to_world(start_cell)
	ok = _check(root_name, floor_cells, blocked, start_cell, rects) and ok and _ok
	_save(root, path)
	return ok


# --- shared ------------------------------------------------------------------------------------------

## Wall blocks: the row (faces shown) follows from the neighbours, like the rotated views. Cells in
## `alt` use the cliff source instead of `src`. Cells in `virtual` (secret doors) aren't painted but
## count as wall for their neighbours (no face shows toward them).
func _paint_walls(layer: TileMapLayer, walls: Dictionary, src: int, alt: Dictionary, virtual := {}) -> void:
	for c: Vector2i in walls:
		var left := not walls.has(c + Vector2i(0, 1)) and not virtual.has(c + Vector2i(0, 1))
		var right := not walls.has(c + Vector2i(1, 0)) and not virtual.has(c + Vector2i(1, 0))
		var row := WallRow.CAP
		if left and right:
			row = WallRow.BOTH
		elif left:
			row = WallRow.FACE_L
		elif right:
			row = WallRow.FACE_R
		layer.set_cell(c, WALL_SRC if alt.has(c) else src, Vector2i(rnd.randi_range(0, 3), row))


func _prop(kind: String, c: Vector2i, entities: Node2D, root: Node, area: String) -> void:
	var prop := _inst("prop", entities, root, c, "%s_%s_%d_%d" % [kind.capitalize(), area, c.x, c.y])
	prop.kind = PROPS[kind]


func _web(decor: Node2D, root: Node, o: Vector2i, rn: String) -> void:
	var web := Sprite2D.new()
	web.name = "Web_" + rn
	web.texture = load("res://assets/sprites/props/web.png")
	web.centered = false
	web.offset = Vector2(-27, -34)
	web.position = IsoGrid.view_cell_to_world(o) + Vector2(0, -7)
	web.add_to_group("wall_decor", true)
	_add(decor, web, root)


func _bones(decor: Node2D, root: Node, c: Vector2i, rn: String) -> void:
	var bones := Sprite2D.new()
	bones.name = "Bones_%s_%d_%d" % [rn, c.x, c.y]
	bones.texture = load("res://assets/sprites/props/bones.png")
	bones.centered = false
	bones.offset = Vector2(-7, -6)
	bones.position = IsoGrid.view_cell_to_world(c)
	_add(decor, bones, root)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rnd.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## Every room / clearing must be reachable from the start on foot (props, chests and braziers
## block; doors don't), and every chest must have a free cell next to it.
func _check(root_name: String, floor_cells: Dictionary, blocked: Dictionary, start: Vector2i, rects: Dictionary) -> bool:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = c + n
			if floor_cells.has(nc) and not blocked.has(nc) and not seen.has(nc):
				seen[nc] = true
				queue.append(nc)
	var ok := true
	for rn in rects:
		var r: Rect2i = rects[rn]
		var any := false
		for c in _interior(r):
			if seen.has(c):
				any = true
				break
		if not any:
			push_error("%s: %s can't be reached" % [root_name, rn])
			ok = false
	for b: Vector2i in blocked:
		var reach := false
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			if seen.has(b + n):
				reach = true
		if not reach:
			push_error("%s: %s is walled in by props" % [root_name, b])
			ok = false
	var floors := 0
	for c in floor_cells:
		floors += 1
	print("map_builder: %s %d floor cells, %d reachable, %d areas %s" % [root_name, floors, seen.size(), rects.size(), "ok" if ok else "PROBLEMS"])
	return ok


func _set_preview(sp: Node, id: String) -> void:
	match id:
		"eye_tyrant":
			sp.preview = load("res://assets/sprites/monsters/eye_tyrant_32.png")
			sp.preview_offset = Vector2(-16, -33)
		"giant_spider":
			sp.preview = load("res://assets/sprites/monsters/giant_spider_preview.png")
			sp.preview_offset = Vector2(-20, -27)
		_:
			var tex: Texture2D = load("res://assets/sprites/monsters/%s_sheet.png" % id)
			var cell := Vector2(tex.get_width() / 17.0, tex.get_height() / 2.0)
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(Vector2.ZERO, cell)
			sp.preview = at
			sp.preview_offset = Vector2(-cell.x / 2.0, -(cell.y - 2.0))


func _inst(scene: String, parent: Node, root: Node, cell: Vector2i, node_name: String) -> Node2D:
	var n: Node2D = (load("res://scenes/markers/%s.tscn" % scene) as PackedScene).instantiate()
	n.name = node_name
	n.position = IsoGrid.view_cell_to_world(cell)
	_add(parent, n, root)
	return n


func _add(parent: Node, n: Node, root: Node) -> void:
	parent.add_child(n)
	n.owner = root


func _make_root(root_name: String, title: String, tileset: String, ambient: Color, start_level: int) -> Node2D:
	var root := Node2D.new()
	root.name = root_name
	root.set_script(load("res://scripts/maps/dungeon_map.gd"))
	root.map_title = title
	root.start_level = start_level
	var ts: TileSet = load(tileset)
	var amb := CanvasModulate.new()
	amb.name = "Ambient"
	amb.color = ambient
	_add(root, amb, root)
	var floor := TileMapLayer.new()
	floor.name = "Floor"
	floor.tile_set = ts
	_add(root, floor, root)
	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	_add(root, world, root)
	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = ts
	walls.y_sort_enabled = true
	_add(world, walls, root)
	for nm in ["Entities", "Decor"]:
		var n := Node2D.new()
		n.name = nm
		n.y_sort_enabled = true
		_add(world, n, root)
	var cam := Camera2D.new()
	cam.name = "Camera"
	_add(root, cam, root)
	return root


func _save(root: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps, path)
	print("map_builder: ", path, " ", "ok" if err == OK else "ERROR %d" % err)
	root.free()
