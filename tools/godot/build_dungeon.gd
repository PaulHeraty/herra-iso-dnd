extends SceneTree
## Builds the first dungeon: two floors, ten rooms, as ordinary map scenes you can keep editing.
##   scenes/maps/dungeon_1.tscn  "The Upper Halls"   - 6 rooms, stairs down
##   scenes/maps/dungeon_2.tscn  "The Webbed Deep"   - 4 rooms, stairs up, the Eye Tyrant's lair
## Run: Godot_console --headless --path . -s res://tools/godot/build_dungeon.gd
## Re-running OVERWRITES both scenes: once they have been edited in the editor, don't.
##
## Each floor is a list of rooms (interior floor rectangles) and corridors (floor rectangles).
## Walls are made automatically on every empty cell touching floor; the wall row (which faces
## show) follows from the neighbours, like the rotated views. Doors go on corridor cells in a
## room's wall line. Torches are spread along each room's walls (back faces on the front walls),
## webs go in back corners, monsters in a room share a group (they fight together).
## Room-local coordinates: (0, 0) = the room's first interior cell.

const TILESET := "res://assets/tiles/dungeon_tileset.tres"
const AMBIENT := Color(0.34, 0.36, 0.50)
const FLOOR_SRC := 0
const WALL_SRC := 1
enum WallRow { FACE_L, FACE_R, BOTH, CAP }

const MONSTERS := {
	"k": "skeleton", "S": "giant_spider", "E": "eye_tyrant",
}
const PROPS := {
	"barrel": Prop.Kind.BARREL, "crate": Prop.Kind.CRATE, "sarcophagus": Prop.Kind.SARCOPHAGUS,
	"rubble": Prop.Kind.RUBBLE, "cocoon": Prop.Kind.COCOON, "urn": Prop.Kind.URN,
}

# --- the two floors -------------------------------------------------------------------------------
# rooms: name -> {rect, monsters [[kind, cell, facing]], props [[kind, cell, (along_y)]],
#                 chests [[cell, gold, (items), (lock_dc: 0 = unlocked)]], braziers [cells], bones [cells], web (bool), torches (step)}
# corridors: [Rect2i] ; doors: [[cell, locked, dc (0 = key only), (key_id)]] ; arches: doorway cells without a door

const F = PartyStart.Facing

var FLOOR_1 := {
	"title": "The Upper Halls",
	"rooms": {
		# A: entrance hall - the party starts here
		"A": {"rect": Rect2i(2, 18, 8, 7), "braziers": [Vector2i(2, 1), Vector2i(5, 5)],
			"start": [Vector2i(3, 3), F.NORTH_EAST], "bones": [Vector2i(6, 1)],
			"props": [["rubble", Vector2i(0, 6)], ["urn", Vector2i(7, 0)]]},
		# B: guard room - three skeletons behind a door
		"B": {"rect": Rect2i(2, 2, 10, 7), "web": true,
			"monsters": [["k", Vector2i(2, 2), F.SOUTH_WEST], ["k", Vector2i(6, 1), F.SOUTH_WEST],
				["k", Vector2i(4, 4), F.SOUTH_EAST]],
			"props": [["barrel", Vector2i(9, 0)], ["barrel", Vector2i(9, 1)], ["crate", Vector2i(0, 6)]],
			"bones": [Vector2i(7, 5)],
			"chests": [[Vector2i(4, 0), 30, ["mace_plus1", "potion_healing"]]]},
		# C: storeroom - supplies and a chest
		"C": {"rect": Rect2i(14, 3, 7, 5),
			"props": [["crate", Vector2i(0, 0)], ["crate", Vector2i(1, 0)], ["barrel", Vector2i(6, 0)],
				["barrel", Vector2i(6, 4)], ["crate", Vector2i(0, 4)], ["urn", Vector2i(3, 0)]],
			"chests": [[Vector2i(5, 0), 40, ["potion_healing", "potion_healing", "crypt_key", "scroll_cure_wounds"], 12]]},
		# D: the crypt - locked (the Iron Key is in the storeroom chest; or pick it); sarcophagi, skeletons and the floor's treasure
		"D": {"rect": Rect2i(14, 14, 9, 9), "web": true,
			"props": [["sarcophagus", Vector2i(2, 2)], ["sarcophagus", Vector2i(6, 2)],
				["sarcophagus", Vector2i(2, 6)], ["sarcophagus", Vector2i(6, 6)], ["urn", Vector2i(0, 0)],
				["urn", Vector2i(8, 0)]],
			"monsters": [["k", Vector2i(4, 1), F.SOUTH_WEST], ["k", Vector2i(4, 4), F.NORTH_WEST],
				["k", Vector2i(4, 7), F.NORTH_WEST]],
			"chests": [[Vector2i(4, 0), 120, ["longsword_plus1", "studded_leather_plus1", "scroll_magic_missile"]]], "braziers": [Vector2i(0, 8)]},
		# E: webbed hall - giant spiders among the cocooned dead
		"E": {"rect": Rect2i(25, 2, 10, 10), "web": true,
			"monsters": [["S", Vector2i(6, 2), F.SOUTH_WEST], ["S", Vector2i(3, 6), F.SOUTH_WEST]],
			"props": [["cocoon", Vector2i(1, 1)], ["cocoon", Vector2i(8, 1)], ["cocoon", Vector2i(8, 7)],
				["cocoon", Vector2i(2, 8)], ["rubble", Vector2i(5, 4)]],
			"bones": [Vector2i(7, 4), Vector2i(1, 5)],
			# a dead adventurer's pack among the cocoons
			"chests": [[Vector2i(3, 0), 45, ["ring_free_action", "shortbow_plus1"]]]},
		# F: stair room - two skeletons guard the way down
		"F": {"rect": Rect2i(26, 16, 8, 7),
			"monsters": [["k", Vector2i(2, 3), F.NORTH_EAST], ["k", Vector2i(5, 3), F.NORTH_EAST]],
			"stairs": [Vector2i(6, 5), false, "res://scenes/maps/dungeon_2.tscn", "from_above"],
			"arrive": [Vector2i(5, 5), "from_below", F.NORTH_WEST],
			"braziers": [Vector2i(1, 1)], "bones": [Vector2i(3, 5)]},
	},
	"corridors": [
		Rect2i(5, 9, 1, 9),       # A - B
		Rect2i(12, 5, 2, 1),      # B - C
		Rect2i(10, 21, 4, 1),     # A - D (locked crypt)
		Rect2i(21, 5, 4, 1),      # C - E
		Rect2i(29, 12, 1, 4),     # E - F
	],
	"doors": [[Vector2i(5, 9), false, 0], [Vector2i(13, 5), false, 0], [Vector2i(13, 21), true, 13, "crypt"],
		[Vector2i(24, 5), false, 0], [Vector2i(29, 15), false, 0]],
	"arches": [Vector2i(5, 17), Vector2i(12, 5), Vector2i(10, 21), Vector2i(21, 5), Vector2i(29, 12)],
}

var FLOOR_2 := {
	"title": "The Webbed Deep",
	"rooms": {
		# G: landing at the foot of the stairs
		"G": {"rect": Rect2i(2, 2, 6, 6),
			"stairs": [Vector2i(1, 0), true, "res://scenes/maps/dungeon_1.tscn", "from_below"],
			"arrive": [Vector2i(2, 2), "from_above", F.SOUTH_EAST],
			"braziers": [Vector2i(5, 5)], "props": [["rubble", Vector2i(5, 0)]], "bones": [Vector2i(0, 4)],
			"chests": [[Vector2i(3, 0), 20, ["dagger_plus1", "potion_healing"]]]},
		# H: ossuary - four skeletons among the bones of the dead
		"H": {"rect": Rect2i(11, 2, 10, 8), "web": true,
			"monsters": [["k", Vector2i(3, 1), F.SOUTH_WEST], ["k", Vector2i(7, 1), F.SOUTH_WEST],
				["k", Vector2i(5, 4), F.SOUTH_WEST], ["k", Vector2i(8, 6), F.NORTH_WEST]],
			"props": [["sarcophagus", Vector2i(1, 6)], ["urn", Vector2i(0, 0)], ["urn", Vector2i(9, 0)],
				["urn", Vector2i(9, 3)], ["rubble", Vector2i(3, 6)]],
			"bones": [Vector2i(2, 3), Vector2i(6, 2), Vector2i(4, 5), Vector2i(7, 7)],
			"chests": [[Vector2i(5, 0), 60, ["potion_greater_healing", "lair_key", "scroll_lightning_bolt", "shield_plus1"]]]},
		# I: the nest - spiders and cocoons
		"I": {"rect": Rect2i(2, 12, 11, 9), "web": true,
			"monsters": [["S", Vector2i(4, 3), F.NORTH_EAST], ["S", Vector2i(8, 5), F.NORTH_WEST],
				["S", Vector2i(3, 7), F.NORTH_EAST]],
			"props": [["cocoon", Vector2i(0, 1)], ["cocoon", Vector2i(10, 0)], ["cocoon", Vector2i(10, 8)],
				["cocoon", Vector2i(6, 8)], ["cocoon", Vector2i(0, 7)], ["rubble", Vector2i(6, 1)]],
			"bones": [Vector2i(2, 2), Vector2i(7, 3), Vector2i(5, 6)],
			"chests": [[Vector2i(8, 0), 80, ["ring_resistance", "rapier_plus1", "potion_healing"]]]},
		# J: the Eye Tyrant's lair - pillars, braziers, and the dungeon's treasure
		"J": {"rect": Rect2i(16, 13, 12, 10), "web": true,
			"pillars": [Vector2i(3, 2), Vector2i(8, 2), Vector2i(3, 7), Vector2i(8, 7)],
			"monsters": [["E", Vector2i(6, 5), F.NORTH_WEST], ["k", Vector2i(2, 4), F.NORTH_WEST],
				["k", Vector2i(9, 4), F.NORTH_WEST]],
			"braziers": [Vector2i(0, 0), Vector2i(11, 0), Vector2i(0, 9), Vector2i(11, 9)],
			"chests": [[Vector2i(10, 8), 300, ["ring_protection", "chain_mail_plus1", "potion_greater_healing", "scroll_fireball"]]], "props": [["urn", Vector2i(11, 4)]],
			"bones": [Vector2i(5, 8), Vector2i(7, 1)]},
	},
	"corridors": [
		Rect2i(8, 4, 3, 1),       # G - H
		Rect2i(4, 8, 1, 4),       # G - I
		Rect2i(18, 10, 1, 3),     # H - J
		Rect2i(13, 17, 3, 1),     # I - J
	],
	"doors": [[Vector2i(10, 4), false, 0], [Vector2i(4, 11), false, 0], [Vector2i(18, 12), false, 0],
		[Vector2i(15, 17), true, 0, "lair"]],
	"arches": [Vector2i(8, 4), Vector2i(4, 8), Vector2i(18, 10), Vector2i(13, 17)],
}

var rnd := RandomNumberGenerator.new()


func _init() -> void:
	rnd.seed = 7
	var ok := _build(FLOOR_1, "Dungeon1", "res://scenes/maps/dungeon_1.tscn")
	ok = _build(FLOOR_2, "Dungeon2", "res://scenes/maps/dungeon_2.tscn") and ok
	quit(0 if ok else 1)


func _build(d: Dictionary, root_name: String, path: String) -> bool:
	var floor_cells := {}
	var pillars := {}
	for rn in d.rooms:
		var r: Rect2i = d.rooms[rn].rect
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				floor_cells[Vector2i(x, y)] = rn
		for p in d.rooms[rn].get("pillars", []):
			pillars[r.position + p] = true
	for c: Rect2i in d.corridors:
		for x in range(c.position.x, c.end.x):
			for y in range(c.position.y, c.end.y):
				if not floor_cells.has(Vector2i(x, y)):
					floor_cells[Vector2i(x, y)] = ""
	for p in pillars:
		floor_cells.erase(p)
	var walls := {}
	for c: Vector2i in floor_cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if not floor_cells.has(n):
					walls[n] = true
	var doorways := {}
	for dd in d.doors:
		doorways[dd[0]] = true
	for a in d.arches:
		doorways[a] = true

	var root := _make_root(root_name, d.title)
	var floor: TileMapLayer = root.get_node("Floor")
	var wall_layer: TileMapLayer = root.get_node("World/Walls")
	var entities: Node2D = root.get_node("World/Entities")
	var decor: Node2D = root.get_node("World/Decor")

	for c: Vector2i in floor_cells:
		var dark := doorways.has(c)
		floor.set_cell(c, FLOOR_SRC, Vector2i(rnd.randi_range(0, 7), 1 if dark else 0))
	for c: Vector2i in walls:
		var left := not walls.has(c + Vector2i(0, 1))
		var right := not walls.has(c + Vector2i(1, 0))
		var row := WallRow.CAP
		if left and right:
			row = WallRow.BOTH
		elif left:
			row = WallRow.FACE_L
		elif right:
			row = WallRow.FACE_R
		wall_layer.set_cell(c, WALL_SRC, Vector2i(rnd.randi_range(0, 3), row))

	var ok := true
	# Doors: the run they sit in is whichever axis has walls on both sides.
	for dd in d.doors:
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
		if dd.size() > 3:
			door.key_id = dd[3]

	var group := 1
	var start_cell := Vector2i.ZERO
	for rn in d.rooms:
		var room: Dictionary = d.rooms[rn]
		var r: Rect2i = room.rect
		var o := r.position
		_torches(room, r, walls, doorways, entities, root, rn)
		if room.get("web", false):
			var web := Sprite2D.new()
			web.name = "Web_" + rn
			web.texture = load("res://assets/sprites/props/web.png")
			web.centered = false
			web.offset = Vector2(-27, -34)
			web.position = IsoGrid.view_cell_to_world(o) + Vector2(0, -7)
			web.add_to_group("wall_decor", true)
			_add(decor, web, root)
		for b: Vector2i in room.get("bones", []):
			var bones := Sprite2D.new()
			bones.name = "Bones_%s_%d_%d" % [rn, b.x, b.y]
			bones.texture = load("res://assets/sprites/props/bones.png")
			bones.centered = false
			bones.offset = Vector2(-7, -6)
			bones.position = IsoGrid.view_cell_to_world(o + b)
			_add(decor, bones, root)
		for p in room.get("props", []):
			var prop := _inst("prop", entities, root, o + p[1], "%s_%s_%d_%d" % [p[0].capitalize(), rn, p[1].x, p[1].y])
			prop.kind = PROPS[p[0]]
			if p.size() > 2:
				prop.along_y = p[2]
		for b: Vector2i in room.get("braziers", []):
			_inst("brazier", entities, root, o + b, "Brazier_%s_%d_%d" % [rn, b.x, b.y])
		for ch in room.get("chests", []):
			var chest := _inst("chest", entities, root, o + ch[0], "Chest_" + rn)
			chest.gold = ch[1]
			if ch.size() > 2:
				chest.items.assign(ch[2])
			if ch.size() > 3 and ch[3] > 0:
				chest.locked = true
				chest.lock_dc = ch[3]
		var any_monster := false
		for m in room.get("monsters", []):
			var id: String = MONSTERS[m[0]]
			var sp := _inst("monster_spawn", entities, root, o + m[1], "%s_%s_%d_%d" % [id.to_pascal_case(), rn, m[1].x, m[1].y])
			sp.monster_id = id
			sp.group_id = group
			sp.facing = m[2]
			_set_preview(sp, id)
			any_monster = true
		if any_monster:
			group += 1
		if room.has("start"):
			var ps := _inst("party_start", entities, root, o + room.start[0], "PartyStart")
			ps.facing = room.start[1]
			start_cell = o + room.start[0]
		if room.has("arrive"):
			var ps := _inst("party_start", entities, root, o + room.arrive[0], "PartyStart_" + room.arrive[1])
			ps.entry_id = room.arrive[1]
			ps.facing = room.arrive[2]
			if start_cell == Vector2i.ZERO:
				start_cell = o + room.arrive[0]
		if room.has("stairs"):
			var s: Array = room.stairs
			var st := _inst("stairs", entities, root, o + s[0], "Stairs_" + ("Up" if s[1] else "Down"))
			st.up = s[1]
			st.target_map = s[2]
			st.target_entry = s[3]

	(root.get_node("Camera") as Camera2D).position = IsoGrid.view_cell_to_world(start_cell)
	ok = _check(root_name, d, floor_cells, walls, start_cell) and ok
	_save(root, path)
	return ok


## Torches on the room's walls: on the back walls (north = LEFT face, west = RIGHT face) every
## few cells, and one back-face torch in the middle of each front wall so the room is lit evenly.
func _torches(room: Dictionary, r: Rect2i, walls: Dictionary, doorways: Dictionary, entities: Node2D, root: Node, rn: String) -> void:
	var spots := []           # [wall cell, face]
	var step: int = room.get("torch_step", 4)
	for x in range(r.position.x + 1, r.end.x - 1, step):
		spots.append([Vector2i(x, r.position.y - 1), Torch.Face.LEFT])
	for y in range(r.position.y + 1, r.end.y - 1, step):
		spots.append([Vector2i(r.position.x - 1, y), Torch.Face.RIGHT])
	spots.append([Vector2i(r.position.x + r.size.x / 2, r.end.y), Torch.Face.BACK_RIGHT])
	spots.append([Vector2i(r.end.x, r.position.y + r.size.y / 2), Torch.Face.BACK_LEFT])
	var used := {}
	for s in spots:
		var c: Vector2i = s[0]
		# slide along the wall off doorways
		for shift in [0, 1, -1, 2, -2]:
			var along := Vector2i(1, 0) if s[1] in [Torch.Face.LEFT, Torch.Face.BACK_RIGHT] else Vector2i(0, 1)
			var t: Vector2i = c + along * shift
			if walls.has(t) and not doorways.has(t + along) and not doorways.has(t - along) and not used.has(t):
				c = t
				break
		if not walls.has(c) or used.has(c):
			continue
		used[c] = true
		var torch := (load("res://scenes/markers/torch.tscn") as PackedScene).instantiate()
		torch.name = "Torch_%s_%d_%d" % [rn, c.x, c.y]
		torch.face = s[1]
		torch.position = IsoGrid.view_cell_to_world(c) + torch._snap_offset()
		_add(entities, torch, root)


## Every room must be reachable from the start through doors, and nothing may stand on a wall.
func _check(root_name: String, d: Dictionary, floor_cells: Dictionary, walls: Dictionary, start: Vector2i) -> bool:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = c + n
			if floor_cells.has(nc) and not seen.has(nc):
				seen[nc] = true
				queue.append(nc)
	var ok := true
	for rn in d.rooms:
		if not seen.has(d.rooms[rn].rect.position + Vector2i(1, 1)):
			push_error("%s: room %s can't be reached" % [root_name, rn])
			ok = false
	print("build_dungeon: %s %d floor cells, %d walls, %d rooms %s" % [root_name, floor_cells.size(),
			walls.size(), d.rooms.size(), "ok" if ok else "PROBLEMS"])
	return ok


func _set_preview(sp: Node, id: String) -> void:
	match id:
		"eye_tyrant":
			sp.preview = load("res://assets/sprites/monsters/eye_tyrant_32.png")
			sp.preview_offset = Vector2(-16, -33)
		"giant_spider":
			sp.preview = load("res://assets/sprites/monsters/giant_spider_preview.png")
			sp.preview_offset = Vector2(-20, -27)
		"skeleton":
			var at := AtlasTexture.new()
			at.atlas = load("res://assets/sprites/monsters/skeleton_sheet.png")
			at.region = Rect2(0, 0, 16, 24)
			sp.preview = at
			sp.preview_offset = Vector2(-8, -22)


func _inst(scene: String, parent: Node, root: Node, cell: Vector2i, node_name: String) -> Node2D:
	var n: Node2D = (load("res://scenes/markers/%s.tscn" % scene) as PackedScene).instantiate()
	n.name = node_name
	n.position = IsoGrid.view_cell_to_world(cell)
	_add(parent, n, root)
	return n


func _add(parent: Node, n: Node, root: Node) -> void:
	parent.add_child(n)
	n.owner = root


func _make_root(root_name: String, title: String) -> Node2D:
	var root := Node2D.new()
	root.name = root_name
	root.set_script(load("res://scripts/maps/dungeon_map.gd"))
	root.map_title = title
	var ts: TileSet = load(TILESET)
	var amb := CanvasModulate.new()
	amb.name = "Ambient"
	amb.color = AMBIENT
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
	print("build_dungeon: ", path, " ", "ok" if err == OK else "ERROR %d" % err)
	root.free()
