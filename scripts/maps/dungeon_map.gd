class_name DungeonMap
extends Node2D
## Root script for every map scene. Expected children (see scenes/maps/map_template.tscn):
##   Ambient   CanvasModulate   - dim cool ambient light
##   Floor     TileMapLayer     - floor tiles (dungeon_tileset, source 0)
##   World     Node2D (y-sort)  - everything that depth-sorts:
##     Walls     TileMapLayer (y-sort) - wall blocks (source 1)
##     Entities  Node2D (y-sort)       - markers (party start, monsters, chests, torches, doors, traps)
##                                       and actors (the party is spawned here at runtime)
##     Decor     Node2D (y-sort)       - pure decoration sprites (bones, webs...). Put sprites that
##                                       hang on a back wall/corner (webs) in group "wall_decor":
##                                       they are hidden when the view is rotated.
##   Camera    Camera2D
##
## View rotation (Q/E): the Floor and Walls layers you paint are the *map* (hidden at runtime);
## FloorView/WallsView show it turned by quarter turns. All game logic uses map cells.

## Monsters without a scene in scenes/actors/monsters/ get a static preview sprite instead.
@export var preview_missing_monsters := true
## Which PartyStart to use (matches PartyStart.entry_id).
@export var entry_id := "start"
## Shown when the party arrives (e.g. "The Upper Halls").
@export var map_title := ""
## Fog of war: only explored cells are drawn; explored ones out of sight are dimmed and their
## monsters hidden (see FogOfWar).
@export var fog_of_war := true
## The party's level when this map is the first one played (a fresh party, no PartyState):
## lets each floor be played on its own at the level it is meant for.
@export_range(1, 5) var start_level := 1

const HERO_SCENE := preload("res://scenes/actors/hero.tscn")
const PARTY_ORDER := [Hero.HeroClass.FIGHTER, Hero.HeroClass.ROGUE, Hero.HeroClass.CLERIC, Hero.HeroClass.MAGE]
## Preferred formation around the leader's cell; falls back to the nearest free cells.
const FORMATION := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
const NEIGHBOURS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Wall atlas rows (see CLAUDE.md): which faces of a block are drawn.
const WALL_ROW_LEFT := 0      ## lower-left face only
const WALL_ROW_RIGHT := 1     ## lower-right face only
const WALL_ROW_BOTH := 2
const WALL_ROW_CAP := 3
## TileMapLayer rendering quadrant size (cells) for the visible layers (see _make_view_layers).
const LIGHT_CHUNK := 4

## The heroes, leader first.
var party: Array[Hero] = []
## Monsters spawned from MonsterSpawn markers.
var monsters: Array[Monster] = []
## XP the party has earned in total (each hero keeps its own share: Hero.xp).
var party_xp := 0
## The party's shared bag: gold + items (carried between floors by PartyState).
var inventory: Inventory
var overlay: GridOverlay
var controller: PartyController
var camera_controller: CameraController
var wall_fader: WallFader
var scorch: ScorchLayer
var dice: DiceScene
var combat: CombatManager
## Traps, levers, plates, puzzles, secret doors, blocks, room notes (Phase 6).
var mech: Mechanisms
var hud: CombatHud
## Save / load slots (F5 / F9).
var save_screen: SaveScreen
## The victory screen (after Brannoc pays for the Wraith), made when first shown.
var victory_screen: VictoryScreen
## Set by the intro: the next map to load fades in from black (a new game starts from it).
static var fade_from_black := false
## Visible, rotated copies of the Floor / Walls layers.
var floor_view: TileMapLayer
var walls_view: TileMapLayer
var _astar := AStarGrid2D.new()
var fog := FogOfWar.new()
## The map as a picture for the minimap / full map (follows the fog).
var map_picture: MapPicture
var _fog_key := ""
var _wall_set := {}
## View cell -> map cell (floor) / [source, atlas, map cell] (walls) for the current rotation.
var _view_floor := {}
var _view_walls := {}
const FOG_DIM := Color(0.5, 0.5, 0.6)
var _pending_turns := 0
## Sprites placed by map cell (decor, monster previews): node -> [map cell, offset from its centre]
var _placed := {}

@onready var floor_layer: TileMapLayer = $Floor
@onready var walls_layer: TileMapLayer = $World/Walls
@onready var entities: Node2D = $World/Entities
@onready var decor: Node2D = $World/Decor
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	Modules.ensure_for(scene_file_path)      # a map run on its own: its module
	# The quest and the rune's portal travel with the party (a new game starts them afresh).
	if PartyState.has_state():
		Quest.from_dict(PartyState.story.get("quest", {}))
		RunePortal.from_dict(PartyState.story.get("portal", {}))
	else:
		Quest.reset()
		RunePortal.reset()
	IsoGrid.rotation = 0
	var fr := floor_layer.get_used_rect()
	IsoGrid.pivot = fr.position + fr.size / 2
	for n in entities.get_children():
		if n is MapMarker:
			n.lock_cell()
		if n is Door:
			n.opened.connect(_on_door_opened)
	MapState.restore(self)
	mech = Mechanisms.new()
	mech.name = "Mechanisms"
	add_child(mech)
	mech.setup(self)
	for s in decor.get_children():
		if s is Node2D:
			_place_by_cell(s, s.position)
	_make_view_layers()
	scorch = ScorchLayer.new()
	scorch.name = "Scorch"
	add_child(scorch)
	move_child(scorch, floor_view.get_index() + 1)       # floor marks, lit like the floor
	overlay = GridOverlay.new()
	overlay.name = "Overlay"
	add_child(overlay)
	move_child(overlay, scorch.get_index() + 1)          # above the floor, below World
	_spawn_monsters()
	for n in entities.get_children():
		if n is Npc:
			n.present = _npc_area_clear(n)
	invalidate_static()
	refresh_navigation()
	_spawn_party()
	mech.update_plates(true)          # heroes may arrive standing on a plate
	party_xp = PartyState.party_xp
	inventory = Inventory.from_dict(PartyState.bag) if not PartyState.bag.is_empty() else Inventory.starting()
	_compute_fog()
	refresh_navigation()
	map_picture = MapPicture.new(self)
	camera_controller = CameraController.new()
	camera_controller.name = "CameraController"
	camera_controller.camera = camera
	camera_controller.target = party[0] if not party.is_empty() else null
	camera_controller.bounds = get_world_bounds()
	add_child(camera_controller)
	controller = PartyController.new()
	controller.name = "PartyController"
	controller.map = self
	controller.overlay = overlay
	controller.camera = camera_controller
	controller.party = party
	add_child(controller)
	combat = CombatManager.new()
	combat.name = "CombatManager"
	combat.map = self
	add_child(combat)
	dice = DiceScene.new()
	dice.name = "DiceScene"
	add_child(dice)
	hud = CombatHud.new()
	hud.name = "CombatHud"
	hud.combat = combat
	add_child(hud)
	save_screen = SaveScreen.new()
	save_screen.name = "SaveScreen"
	save_screen.map = self
	add_child(save_screen)
	Quest.note_map(scene_file_path)
	_place_portals(false)
	inventory.changed.connect(quest_check)
	combat.combat_ended.connect(_on_combat_ended)
	if MapState.next_entry == MapState.AT_SAVE:
		IsoGrid.rotation = posmod(MapState.arrive_rotation, 4)     # the view as it was saved
	_apply_view()
	if IsoGrid.rotation != 0:
		camera_controller.bounds = get_world_bounds()
		if not party.is_empty():
			camera_controller.jump_to(party[0].position)
	quest_check.call_deferred()
	if PartyState.has_state() or map_title != "":
		_arrival_fade(PartyState.has_state() or fade_from_black)
	fade_from_black = false
	# the room the party arrives in describes itself once the title has gone
	get_tree().create_timer(2.8).timeout.connect(_arrival_notes)


func _process(delta: float) -> void:
	PartyState.play_seconds += delta
	if Input.is_action_just_pressed("view_rotate_right"):
		rotate_view(1)
	elif Input.is_action_just_pressed("view_rotate_left"):
		rotate_view(-1)
	if _pending_turns != 0 and not _anyone_moving():
		apply_pending_rotation()
	_tick_fog()
	_tick_npcs(delta)
	var reveal: Array[Rect2] = []
	for h in party:
		reveal.append(WallFader.figure_rect(h.position))
	for mo in monsters:
		reveal.append(WallFader.figure_rect(mo.position))
	for c in overlay.revealed_cells():
		reveal.append(WallFader.floor_rect(c))
	# known traps in sight: the walls in front of them fade, so the danger shows (corridors)
	if mech:
		for t in mech.traps:
			if t.blocks_party() and is_seen(t.get_cell()):
				reveal.append(WallFader.floor_rect(t.get_cell()))
		for p in mech.pieces:
			if is_seen(p.get_cell()):
				reveal.append(WallFader.floor_rect(p.get_cell()) if p is PressurePlate else WallFader.figure_rect(IsoGrid.cell_to_world(p.get_cell())))
	wall_fader.update(reveal, delta)
	_fade_tall_props(delta)


## Turn the view by quarter turns (+1 = clockwise). Applied as soon as nobody is mid-step.
func rotate_view(turns: int) -> void:
	_pending_turns += turns


## Apply a requested rotation now (PartyController calls this between steps).
func apply_pending_rotation() -> void:
	if _pending_turns == 0:
		return
	# Keep the map cell at the centre of the screen at the centre after turning.
	var focus := IsoGrid.world_to_cell(camera.position)
	IsoGrid.rotation = posmod(IsoGrid.rotation + _pending_turns, 4)
	_pending_turns = 0
	_apply_view()
	camera_controller.bounds = get_world_bounds()
	camera_controller.jump_to(IsoGrid.cell_to_world(focus))


## True if a cell has floor, no wall, no closed door, no chest and no monster (heroes are ignored).
func is_walkable(cell: Vector2i) -> bool:
	if not terrain_walkable(cell):
		return false
	for m in monsters:
		if m.cell == cell and m.is_alive():
			return false
	return not _static_cells().spawns.has(cell)


## Floor without a wall, closed door, chest, prop or brazier (ignores creatures).
func terrain_walkable(cell: Vector2i) -> bool:
	if floor_layer.get_cell_source_id(cell) == -1:
		return false
	var wall := walls_layer.get_cell_tile_data(cell)
	if wall and wall.get_custom_data("blocks_move"):
		return false
	var st := _static_cells()
	if st.move.has(cell):
		return false
	for d: Door in st.doors:
		if d.get_cell() == cell and d.blocks_move():
			return false
	return true


## Cells blocked by things that never move (chests, props, braziers; trees also block sight),
## spawns still waiting for their monster, and the doors - worked out once (big outdoor maps
## have hundreds of trees, and these are asked for every cell).
var _static := {}


func _static_cells() -> Dictionary:
	if _static.is_empty():
		var move := {}
		var sight := {}
		var spawns := {}
		var doors: Array[Door] = []
		for n in entities.get_children():
			if n is Door:
				doors.append(n)
			elif n is Npc:
				if n.present:
					move[n.get_cell()] = true
			elif n is Chest or n is Brazier or n is Lever or n is StoneFace:
				move[n.get_cell()] = true
			elif n is Prop:
				if n.blocks:
					move[n.get_cell()] = true
				if n.blocks_sight():
					sight[n.get_cell()] = true
			elif n is MonsterSpawn and n.monster == null and not n.cleared:
				spawns[n.get_cell()] = true
		_static = {move = move, sight = sight, spawns = spawns, doors = doors}
	return _static


## Forget the cached blockers (after spawning monsters, adding or removing props).
func invalidate_static() -> void:
	_static = {}


const DIRS8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


## Combat movement: every cell `mover` can reach from `from` within `budget` squares (5e: each
## square costs 1, diagonals too; no cutting wall corners). One creature per square: nobody can
## move through or onto a square someone else stands on (allies included; a downed hero still
## takes up a square, the dead don't). Returns cell -> {cost, prev, stop} (stop is always true now:
## every reachable cell is free to end on).
func combat_reach(from: Vector2i, budget: int, mover: Actor) -> Dictionary:
	var reach := {from: {cost = 0, prev = from, stop = true}}
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		var next: Array[Vector2i] = []
		for c in frontier:
			var cost: int = reach[c].cost + 1
			if cost > budget:
				continue
			for d: Vector2i in DIRS8:
				var n := c + d
				if reach.has(n) or not terrain_walkable(n):
					continue
				if d.x != 0 and d.y != 0 and not (terrain_walkable(c + Vector2i(d.x, 0)) and terrain_walkable(c + Vector2i(0, d.y))):
					continue
				if occupant(n, mover) != null:
					continue
				if mover is Hero and mech and mech.trap_blocks(n):
					continue          # a known trap: heroes go round it
				reach[n] = {cost = cost, prev = c, stop = true}
				next.append(n)
		frontier = next
	return reach


## The creature taking up `cell` (not `except`): anyone standing, and downed heroes (still
## alive, making death saves). Dead creatures and remains don't take up a square.
func occupant(cell: Vector2i, except: Actor = null) -> Actor:
	for n in entities.get_children():
		if n is Actor and n != except and n.cell == cell and (n.is_alive() or (n is Hero and not n.dead)):
			return n
	return null


## Path (excluding the start) to `to` through a combat_reach result, or [] if unreachable.
static func reach_path(reach: Dictionary, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not reach.has(to):
		return out
	var c := to
	while reach[c].prev != c:
		out.push_front(c)
		c = reach[c].prev
	return out


static func _same_side(a: Actor, b: Actor) -> bool:
	return (a is Hero) == (b is Hero)


## True if the map has a floor tile at `cell` that the party knows about (explored).
func has_floor(cell: Vector2i) -> bool:
	return floor_layer.get_cell_source_id(cell) != -1 and is_explored(cell)


## Fog of war: has the party seen this cell? (Always true with fog_of_war off.)
func is_explored(cell: Vector2i) -> bool:
	return not fog_of_war or fog.explored.has(cell)


## Fog of war: can the party see this cell right now?
func is_seen(cell: Vector2i) -> bool:
	return not fog_of_war or fog.visible.has(cell)


func _party_can_walk(cell: Vector2i) -> bool:
	return is_walkable(cell) and is_explored(cell) and not (mech and mech.trap_blocks(cell))


## Rebuild the walk grid from the tiles and doors. Call after opening/closing doors or editing tiles.
func refresh_navigation() -> void:
	_astar.region = floor_layer.get_used_rect().grow(1)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	var r := _astar.region
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			_astar.set_point_solid(Vector2i(x, y), not _party_can_walk(Vector2i(x, y)))


## Cells from `from` to `to` inclusive (diagonals allowed when not cutting a wall corner),
## or [] if `to` can't be reached.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _astar.is_in_boundsv(from) or not _astar.is_in_boundsv(to) or _astar.is_point_solid(to):
		return out
	# The cell the walker stands on may count as blocked (a trap it just set off): path from it anyway.
	var from_solid := _astar.is_point_solid(from)
	if from_solid:
		_astar.set_point_solid(from, false)
	out.assign(_astar.get_id_path(from, to))
	if from_solid:
		_astar.set_point_solid(from, true)
	return out


## World-space box around all floor and wall tiles in the current view (walls reach 40 px up).
func get_world_bounds() -> Rect2:
	var r := Rect2()
	var first := true
	for layer: TileMapLayer in [floor_layer, walls_layer]:
		var up := 40.0 if layer == walls_layer else 0.0
		for c in layer.get_used_cells():
			var p := IsoGrid.cell_to_world(c)
			var cell_r := Rect2(p.x - 16, p.y - 8 - up, 32, 16 + up)
			r = cell_r if first else r.merge(cell_r)
			first = false
	return r


## 5e grid distance in cells (diagonals count as one square, like moving).
static func grid_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## True if a cell blocks sight: a wall, or a closed door (not a portcullis: bars).
func blocks_sight(cell: Vector2i) -> bool:
	if walls_layer.get_cell_source_id(cell) != -1:
		return true
	var st := _static_cells()
	if st.sight.has(cell):
		return true
	for d: Door in st.doors:
		if d.get_cell() == cell and d.blocks_sight():
			return true
	return false


## Clear line between two cell centres (endpoints excluded): sampled every 1/8 cell, so a line
## that only grazes a wall corner still counts as clear.
func has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	var pa := Vector2(a) + Vector2(0.5, 0.5)
	var pb := Vector2(b) + Vector2(0.5, 0.5)
	var n := int(ceil(pa.distance_to(pb) * 8.0))
	for i in range(1, n):
		var p := pa.lerp(pb, float(i) / n)
		var c := Vector2i(floori(p.x), floori(p.y))
		if c == a or c == b:
			continue
		# skip samples within a hair of a cell edge (corner grazing)
		var fx := p.x - c.x
		var fy := p.y - c.y
		if minf(fx, 1.0 - fx) < 0.02 or minf(fy, 1.0 - fy) < 0.02:
			continue
		if blocks_sight(c):
			return false
	return true


## The figure drawn under a world (map-local) point: whose sprite contains it, front-most first
## (figures stand taller than their tile, so clicking a body should pick that body). Falls back
## to whoever stands on the cell under the point.
func actor_under(pos: Vector2, include_down := true) -> Actor:
	var best: Actor = null
	for n in entities.get_children():
		if not n is Actor or not n.visible:
			continue
		var a: Actor = n
		if a.dead or (not include_down and not a.is_alive()):
			continue
		if not a.is_alive() and a is Monster:
			continue
		var r := a.sprite.get_rect()
		r.position += a.position + a.sprite.position
		r = r.grow(-1)
		if r.has_point(pos) and (best == null or a.position.y > best.position.y):
			best = a
	if best:
		return best
	return actor_at(IsoGrid.world_to_cell(pos))


## The door on a (map) cell, or null.
func door_at(cell: Vector2i) -> Door:
	for n in entities.get_children():
		if n is Door and n.get_cell() == cell:
			return n
	return null


## A closed door under a world point: on the cell under it, or whose panel the point is on.
func closed_door_under(pos: Vector2) -> Door:
	var d := door_at(IsoGrid.world_to_cell(pos))
	if d and not d.is_open and not d.is_hidden():
		return d
	for n in entities.get_children():
		if n is Door and not n.is_open and not n.is_hidden() and n.panel_rect().has_point(pos):
			return n
	return null


## Try to open a door: unlocked doors just open; locked ones need a key or a roll (_try_lock).
## Returns true if the door is now open.
func try_open_door(door: Door, by: Array[Hero]) -> bool:
	if door.is_open:
		return true
	if not door.by_hand():
		combat._say(door.hint(self))
		Sfx.play("door_locked")
		return false
	if door.locked and not _try_lock(door, "door", by):
		return false
	door.open()
	return true


## A locked door or chest (`thing` has locked, lock_dc, key_id): the matching key from the bag
## opens it; else the Rogue picks it (thieves' tools: DEX + expertise vs lock_dc) or, failing that,
## the strongest hero forces it (Athletics vs lock_dc + 2). Each try is one roll; the player can
## try again. key_id with lock_dc 0 = only the key. Logs what happens. True = unlocked.
## The bag's key for a door or chest's lock ("" = none, or it has no key).
func key_for(thing: Node) -> String:
	return inventory.key_for(thing.key_id) if inventory else ""


## Hover text for a locked door or chest: what clicking it will do.
func lock_hint(thing: Node, what: String) -> String:
	var key := key_for(thing)
	if key != "":
		return "%s (locked): click to unlock it with the %s." % [what, ItemData.get_item(key).display_name]
	if thing.key_id != "" and thing.lock_dc <= 0:
		return "%s (locked): it needs a key." % what
	return "%s (locked): click to try the lock." % what


func _try_lock(thing: Node, what: String, by: Array[Hero]) -> bool:
	var able := by.filter(func(h: Hero): return h.is_alive())
	if able.is_empty():
		return false
	var key := key_for(thing)
	if key != "":
		combat._say("%s unlocks the %s with the %s." % [able[0].display_name(), what,
				ItemData.get_item(key).display_name])
		Sfx.play("lock_click")
		thing.locked = false
		return true
	if thing.key_id != "" and thing.lock_dc <= 0:
		combat._say("The %s is locked. It needs a key." % what)
		Sfx.play("door_locked")
		return false
	var rogue: Hero = null
	var strong: Hero = able[0]
	for h: Hero in able:
		if h.hero_class == Hero.HeroClass.ROGUE:
			rogue = h
		if h.stats.skill_bonus("athletics") > strong.stats.skill_bonus("athletics"):
			strong = h
	var who := rogue if rogue else strong
	var skill := "thieves_tools" if rogue else "athletics"
	var dc: int = thing.lock_dc if rogue else thing.lock_dc + 2
	var r := Dice.d20(who.stats.skill_bonus(skill))
	if r.total >= dc:
		combat._say("%s %s the lock (%s vs DC %d)" % [who.display_name(),
				"picks" if rogue else "forces", r.describe(), dc])
		Sfx.play("lock_click" if rogue else "hit_blunt")
		thing.locked = false
		return true
	combat._say("%s fails to %s the lock (%s vs DC %d)" % [who.display_name(),
			"pick" if rogue else "force", r.describe(), dc])
	Sfx.play("door_locked")
	return false


## The chest on a (map) cell, or null.
func chest_at(cell: Vector2i) -> Chest:
	for n in entities.get_children():
		if n is Chest and n.get_cell() == cell:
			return n
	return null


## An unopened, explored chest under a world point (its cell or its sprite), or null.
func closed_chest_under(pos: Vector2) -> Chest:
	var c := chest_at(IsoGrid.world_to_cell(pos))
	if c and not c.opened and is_explored(c.get_cell()):
		return c
	for n in entities.get_children():
		if n is Chest and not n.opened and is_explored(n.get_cell()) and n.sprite_rect().has_point(pos):
			return n
	return null


## Open a chest (locks as for doors) and put what's inside into the party bag. Exploration only.
## Returns true if it is now open.
func try_open_chest(chest: Chest, by: Array[Hero]) -> bool:
	if chest.opened:
		return true
	if combat.in_combat:
		combat._say("No time for that now!")
		return false
	if chest.locked and not _try_lock(chest, "chest", by):
		return false
	chest.open()
	_loot(chest)
	return true


func _loot(chest: Chest) -> void:
	var found: Array[Dictionary] = []          # [{id, count}] for the HUD
	var counts := {}
	for iid in chest.items:
		if ItemData.get_item(iid) == null:
			continue
		if not counts.has(iid):
			found.append({id = iid, count = 0})
		counts[iid] = counts.get(iid, 0) + 1
	for f in found:
		f.count = counts[f.id]
		inventory.add(f.id, f.count)
	if chest.gold > 0:
		inventory.add_gold(chest.gold)
	var parts: Array[String] = []
	if chest.gold > 0:
		parts.append("%d gold" % chest.gold)
	for f in found:
		var nm := ItemData.get_item(f.id).display_name
		parts.append(nm if f.count == 1 else "%d x %s" % [f.count, nm])
	if parts.is_empty():
		combat._say("The chest is empty.")
		return
	combat._say("Found " + ", ".join(parts) + ".")
	var top := chest.position + Vector2(0, -14)
	if chest.gold > 0:
		get_tree().create_timer(0.2).timeout.connect(func(): Sfx.play("coins"))
		FloatText.spawn(self, top, "+%d gold" % chest.gold, Color8(255, 215, 90))
	SpellFx.sparkles(self, top + Vector2(0, 6), Color8(255, 220, 120), false)
	if hud:
		hud.show_loot(chest.gold, found)


func _on_door_opened() -> void:
	update_fog()
	refresh_navigation()


## The stairs on a (map) cell, or null.
func stairs_at(cell: Vector2i) -> Stairs:
	for n in entities.get_children():
		if n is Stairs and n.get_cell() == cell:
			return n
	return null


## Stairs under a world point: on the cell under it, or (stairs up) whose steps the point is on.
func stairs_under(pos: Vector2) -> Stairs:
	var s := stairs_at(IsoGrid.world_to_cell(pos))
	if s:
		return s
	for n in entities.get_children():
		if n is Stairs and n.up and Rect2(n.position + Vector2(-16, -30), Vector2(32, 38)).has_point(pos):
			return n
	return null


var _leaving := false


## Go to the map the stairs lead to (outside combat): fade out, remember this map and the party,
## change scene. The new map places the party at the PartyStart named by target_entry.
func take_stairs(st: Stairs) -> void:
	if _leaving or combat.in_combat or combat.game_over:
		return
	if st.target_map == "" or not ResourceLoader.exists(st.target_map):
		combat._say("These stairs lead nowhere (yet).")
		return
	_leaving = true
	controller.enabled = false
	Sfx.play("stairs", 0.0, 1.15 if st.up else 1.0)
	var fade := _fade_rect()
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.6)
	await tw.finished
	MapState.save(self)
	PartyState.save(self)
	MapState.next_entry = st.target_entry
	get_tree().change_scene_to_file(st.target_map)


## True while the party is on its way to another map (or a loaded game).
func is_leaving() -> bool:
	return _leaving


## Load the game saved in `slot` (any time, even mid-fight or after a wipe): fade out, set up
## the saved state, load its map. Returns "" or why it can't be loaded.
func load_game(slot: int) -> String:
	if _leaving:
		return "Already on the way."
	var err := []
	var target := SaveGame.prepare_load(slot, err)
	if target == "":
		return err[0] if not err.is_empty() else "That save can't be loaded."
	_leaving = true
	controller.enabled = false
	_fade_to(target)
	return ""


func _fade_to(target: String) -> void:
	var fade := _fade_rect()
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.4)
	await tw.finished
	get_tree().change_scene_to_file(target)


## A full-screen black rect above everything (for fades).
func _fade_rect() -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var r := ColorRect.new()
	r.size = Vector2(640, 360)
	r.color = Color(0, 0, 0, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	return r


## Arriving: fade in from black (after stairs) and show the map's title for a moment.
func _arrival_fade(from_black: bool) -> void:
	var r := _fade_rect()
	r.color.a = 1.0 if from_black else 0.0
	var title := Label.new()
	title.add_theme_font_override("font", load("res://assets/fonts/herra_pixel.fnt"))
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color8(255, 220, 120))
	title.text = map_title.to_upper()
	title.scale = Vector2(2, 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(320, 12)
	title.position = Vector2(0, 110)
	title.modulate.a = 0.0
	r.get_parent().add_child(title)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.8)
	tw.parallel().tween_property(title, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.6)
	tw.tween_property(title, "modulate:a", 0.0, 0.6)
	await tw.finished
	r.get_parent().queue_free()


## The actor standing on a cell, or null.
func actor_at(cell: Vector2i) -> Actor:
	for n in entities.get_children():
		if n is Actor and n.cell == cell:
			return n
	return null


# --- view (rotation) ---------------------------------------------------------------------------

func _make_view_layers() -> void:
	floor_view = TileMapLayer.new()
	floor_view.name = "FloorView"
	floor_view.tile_set = floor_layer.tile_set
	# Small rendering chunks: a 2D canvas item takes only a limited number of lights, and a big
	# map has dozens of torches, so a big floor chunk would drop most of them.
	floor_view.rendering_quadrant_size = LIGHT_CHUNK
	add_child(floor_view)
	move_child(floor_view, floor_layer.get_index() + 1)
	walls_view = TileMapLayer.new()
	walls_view.name = "WallsView"
	walls_view.tile_set = walls_layer.tile_set
	walls_view.rendering_quadrant_size = LIGHT_CHUNK
	walls_view.y_sort_enabled = true
	walls_layer.get_parent().add_child(walls_view)
	walls_layer.get_parent().move_child(walls_view, walls_layer.get_index() + 1)
	floor_layer.visible = false
	walls_layer.visible = false


## Rebuild everything visible for the current IsoGrid.rotation.
func _apply_view() -> void:
	wall_fader = WallFader.new(walls_view, entities)     # also makes the dimmed tile variants
	floor_view.clear()
	_view_floor.clear()
	for c in floor_layer.get_used_cells():
		_view_floor[IsoGrid.to_view(c)] = c
	for v: Vector2i in _view_floor:
		_draw_floor_cell(v)
	walls_view.clear()
	_view_walls.clear()
	var view_walls := {}
	for c in walls_layer.get_used_cells():
		view_walls[IsoGrid.to_view(c)] = c
	for v: Vector2i in view_walls:
		var c: Vector2i = view_walls[v]
		var sid := walls_layer.get_cell_source_id(c)
		var atlas := walls_layer.get_cell_atlas_coords(c)
		if IsoGrid.rotation == 0:
			_view_walls[v] = [sid, atlas, c]
		else:
			# Pick the block variant by which faces are now exposed to the viewer.
			var left := not view_walls.has(v + Vector2i(0, 1))
			var right := not view_walls.has(v + Vector2i(1, 0))
			var row := WALL_ROW_CAP
			if left and right:
				row = WALL_ROW_BOTH
			elif left:
				row = WALL_ROW_LEFT
			elif right:
				row = WALL_ROW_RIGHT
			_view_walls[v] = [sid, Vector2i(atlas.x, row), c]
	for v: Vector2i in _view_walls:
		if is_explored(_view_walls[v][2]):
			walls_view.set_cell(v, _view_walls[v][0], _view_walls[v][1])
	# Secret doors draw the wall block their place would show in this view.
	for n in entities.get_children():
		if n is Door and n.style == Door.Style.SECRET:
			var sv := IsoGrid.to_view(n.get_cell())
			var sl := not view_walls.has(sv + Vector2i(0, 1))
			var sr := not view_walls.has(sv + Vector2i(1, 0))
			var srow := WALL_ROW_BOTH if sl and sr else (WALL_ROW_LEFT if sl else (WALL_ROW_RIGHT if sr else WALL_ROW_CAP))
			n.wall_tile = Vector2i(absi(n.get_cell().x * 7 + n.get_cell().y * 3) % 4, srow)
	for n in entities.get_children():
		if n is MapMarker:
			n.apply_view()
		elif n is Actor:
			n.place_at(n.cell)
	for s: Node2D in _placed:
		s.position = IsoGrid.cell_to_world(_placed[s][0]) + _placed[s][1]
		if s.is_in_group("wall_decor"):
			s.visible = IsoGrid.rotation == 0
	overlay.queue_redraw()
	if scorch:
		scorch.queue_redraw()
	_refresh_fog_look()


# --- fog of war ---------------------------------------------------------------------------------

## Recompute what the party sees (after moves, doors, rotation) and redraw what changed.
func update_fog() -> void:
	if not fog_of_war or floor_view == null:
		return
	var fresh := _compute_fog()
	for c in fresh:
		if _astar.is_in_boundsv(c):
			_astar.set_point_solid(c, not _party_can_walk(c))
	_refresh_fog_look()
	if mech:
		mech.spot_check()


## Update the fog when a hero has changed cell or a door has opened; keep monster visibility
## current every frame (monsters move on their own).
func _tick_fog() -> void:
	if not fog_of_war:
		return
	var key := ""
	for h in party:
		key += "%d,%d,%d;" % [h.cell.x, h.cell.y, int(h.is_alive())]
	for n in entities.get_children():
		if n is Door and n.is_open:
			key += "d"
	if key != _fog_key:
		_fog_key = key
		update_fog()
	_refresh_monster_fog()


func _compute_fog() -> Array[Vector2i]:
	if not fog_of_war:
		return []
	if _wall_set.is_empty():
		for c in walls_layer.get_used_cells():
			_wall_set[c] = true
	var opaque := _wall_set.duplicate()
	for n in entities.get_children():
		if n is Door and n.blocks_sight():
			opaque[n.get_cell()] = true
	var eyes: Array[Vector2i] = []
	for h in party:
		if h.is_alive():
			eyes.append(h.cell)
	if eyes.is_empty():
		for h in party:
			if not h.dead:
				eyes.append(h.cell)
	return fog.update(eyes, opaque)


## Floor tile for a view cell: hidden if unexplored, dimmed if out of sight.
func _draw_floor_cell(v: Vector2i) -> void:
	var c: Vector2i = _view_floor[v]
	if not is_explored(c):
		floor_view.erase_cell(v)
		return
	var alt := floor_layer.get_cell_alternative_tile(c) if is_seen(c) else WallFader.DIM_BASE
	if floor_view.get_cell_source_id(v) == -1 or floor_view.get_cell_alternative_tile(v) != alt:
		floor_view.set_cell(v, floor_layer.get_cell_source_id(c), floor_layer.get_cell_atlas_coords(c), alt)


## Redraw tiles, markers and decor for the current fog.
func _refresh_fog_look() -> void:
	if map_picture:
		map_picture.dirty = true
	if wall_fader == null:
		return
	for v: Vector2i in _view_floor:
		_draw_floor_cell(v)
	var dim := {}
	for v: Vector2i in _view_walls:
		var w: Array = _view_walls[v]
		if not is_explored(w[2]):
			continue
		if walls_view.get_cell_source_id(v) == -1:
			walls_view.set_cell(v, w[0], w[1])
		if not is_seen(w[2]):
			dim[v] = true
	wall_fader.set_dim(dim)
	for n in entities.get_children():
		if n is Torch:                      # torches and braziers: hidden until seen, never dimmed
			n.visible = is_explored(n.get_cell())
		elif n is MapMarker:
			n.visible = is_explored(n.get_cell()) and (not n.has_method("is_shown") or n.is_shown())
			n.modulate = Color.WHITE if is_seen(n.get_cell()) else FOG_DIM
	for s: Node2D in _placed:
		var c: Vector2i = _placed[s][0]
		s.visible = is_explored(c) and (IsoGrid.rotation == 0 or not s.is_in_group("wall_decor"))
		s.modulate = Color.WHITE if is_seen(c) else FOG_DIM
	_refresh_monster_fog()


## Monsters show only while the party sees them (or while they're in the fight); remains stay
## where they fell once explored.
func _refresh_monster_fog() -> void:
	for m in monsters:
		if not m.is_alive() and m.vanish_on_death:
			continue
		var show := is_seen(m.cell) or (not m.is_alive() and is_explored(m.cell))
		if combat and combat.in_combat and m in combat.order:
			show = true
		if m.visible != show:
			m.visible = show


## Remember a sprite's map cell (and offset within it) so it can follow view rotation.
func _place_by_cell(s: Node2D, pos: Vector2) -> void:
	var c := IsoGrid.world_to_cell(pos)
	_placed[s] = [c, pos - IsoGrid.cell_to_world(c)]


func _anyone_moving() -> bool:
	for h in party:
		if h.is_moving():
			return true
	return false


# --- spawning ----------------------------------------------------------------------------------

func _find_party_start() -> PartyStart:
	var want := MapState.next_entry if MapState.next_entry != "" else entry_id
	var first: PartyStart = null
	for n in entities.get_children():
		if n is PartyStart:
			if n.entry_id == want:
				return n
			if first == null:
				first = n
	return first


func _spawn_party() -> void:
	var start := _find_party_start()
	# Back through the rune's portal: arrive where the rune was used (no marker there).
	var via_portal := MapState.next_entry == RunePortal.ARRIVE
	# A loaded game: everyone back on the cells they stood on when it was saved.
	var from_save := MapState.next_entry == MapState.AT_SAVE and not MapState.arrive_cells.is_empty()
	if start == null and not via_portal and not from_save:
		push_warning("%s: no PartyStart marker, party not spawned" % name)
		return
	var origin := MapState.arrive_cell if via_portal else (MapState.arrive_cells[0] if from_save else start.get_cell())
	var cells := _formation_cells(origin, PARTY_ORDER.size())
	if from_save:
		cells = _saved_cells(cells)
	for i in cells.size():
		var hero: Hero = HERO_SCENE.instantiate()
		hero.hero_class = PARTY_ORDER[i]
		entities.add_child(hero)
		hero.facing = PartyStart.FACING_DIR[start.facing] if start else Vector2i(1, 0)
		if from_save and i < MapState.arrive_facings.size():
			hero.facing = MapState.arrive_facings[i]
		hero.place_at(cells[i])
		if PartyState.has_state():
			PartyState.apply(hero)
		elif start_level > 1:
			hero.set_level(start_level)
		party.append(hero)


## The cells saved with the game (MapState.arrive_cells), each one kept if it is still free and
## walkable; any that aren't fall back to the free formation cells around the leader.
func _saved_cells(fallback: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in PARTY_ORDER.size():
		var c: Vector2i = MapState.arrive_cells[i] if i < MapState.arrive_cells.size() else NO_CELL
		if not is_walkable(c) or c in out:
			c = NO_CELL
			for f in fallback:
				if f not in out and f not in MapState.arrive_cells:
					c = f
					break
		if c != NO_CELL:
			out.append(c)
	return out


## n free walkable cells for the party: the FORMATION offsets where possible, else the nearest
## free cells reachable from the start (breadth-first), so walls never swallow a hero.
func _formation_cells(origin: Vector2i, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for off in FORMATION:
		if out.size() < n and is_walkable(origin + off):
			out.append(origin + off)
	var queue: Array[Vector2i] = [origin]
	var seen := {origin: true}
	while out.size() < n and not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if is_walkable(c) and c not in out:
			out.append(c)
		for d in NEIGHBOURS:
			var nc: Vector2i = c + d
			if not seen.has(nc) and is_walkable(nc):
				seen[nc] = true
				queue.append(nc)
	if out.size() < n:
		push_warning("%s: only %d free cells near PartyStart" % [name, out.size()])
	return out


## A Monster actor at every MonsterSpawn whose scenes/actors/monsters/<monster_id>.tscn exists.
func _spawn_monsters() -> void:
	for n in entities.get_children():
		if not n is MonsterSpawn or n.cleared:
			continue
		var path := "res://scenes/actors/monsters/%s.tscn" % n.monster_id
		if not ResourceLoader.exists(path):
			push_warning("%s: no scene for monster '%s'" % [name, n.monster_id])
			if preview_missing_monsters and n.preview:
				_spawn_preview_sprite(n)
			continue
		var m: Monster = (load(path) as PackedScene).instantiate()
		m.group_id = n.group_id
		entities.add_child(m)
		m.facing = PartyStart.FACING_DIR[n.facing]
		m.place_at(n.get_cell())
		n.monster = m
		monsters.append(m)


func _spawn_preview_sprite(n: MonsterSpawn) -> void:
	var s := Sprite2D.new()
	s.texture = n.preview
	s.centered = false
	s.offset = n.preview_offset
	entities.add_child(s)
	_placed[s] = [n.get_cell(), Vector2.ZERO]
	s.position = IsoGrid.cell_to_world(n.get_cell())


## Share `xp` between the heroes who aren't dead (5e: split evenly). Returns the level-ups:
## [{hero, level, gains}] (also written to the combat log by the caller).
func award_xp(xp: int) -> Array[Dictionary]:
	party_xp += xp
	var ups: Array[Dictionary] = []
	var share_with := party.filter(func(h): return not h.dead)
	if share_with.is_empty() or xp <= 0:
		return ups
	var share := xp / share_with.size()
	for h: Hero in share_with:
		for u in h.add_xp(share):
			u.hero = h
			ups.append(u)
	return ups


## Trees and tents in front of a hero or a monster fade (like the walls, WallFader), so nobody
## gets lost behind the woods.
var _tall_props: Array[Prop] = []
## Secret doors (closed) draw a wall block of their own: they fade like the walls (WallFader).
var _secret_doors: Array[Door] = []
var _tall_scanned := false


func _fade_tall_props(delta: float) -> void:
	if not _tall_scanned:
		_tall_scanned = true
		for n in entities.get_children():
			if n is Prop and n.is_tall():
				_tall_props.append(n)
			elif n is Door and n.style == Door.Style.SECRET:
				_secret_doors.append(n)
	if _tall_props.is_empty() and _secret_doors.is_empty():
		return
	var figures: Array[Node2D] = []
	figures.append_array(party)
	for m in monsters:
		if m.visible and m.is_alive():
			figures.append(m)
	for d in _secret_doors:
		var dr := d.panel_rect()
		var behind := false
		for f in figures:
			if f.position.y < d.position.y and dr.intersects(WallFader.figure_rect(f.position)):
				behind = true
				break
		d.modulate.a = move_toward(d.modulate.a, 0.55 if behind and not d.is_open else 1.0, delta * 3.0)
	for p in _tall_props:
		var r := p.sprite_rect()
		var hide := false
		for f in figures:
			if f.position.y < p.position.y and r.intersects(WallFader.figure_rect(f.position)):
				hide = true
				break
		var target := 0.45 if hide else 1.0
		p.modulate.a = move_toward(p.modulate.a, target, delta * 3.0)


# --- the trader, the quest and the Rune of Return -------------------------------------------------

## The win screen (VictoryScreen): Brannoc has paid for the Wraith.
func show_victory() -> void:
	if victory_screen == null:
		victory_screen = VictoryScreen.new()
		victory_screen.name = "VictoryScreen"
		victory_screen.map = self
		add_child(victory_screen)
	victory_screen.open()


## Tick off quest stages that have happened (map reached, key found, monster killed) and tell the
## player about each one.
func quest_check() -> void:
	var newly := Quest.update(inventory)
	if newly.is_empty():
		return
	for s in newly:
		combat._say("Quest: %s (done)" % s.text)
	if hud:
		hud.quest_toast(newly)


## After a fight: count the dead for the quest (each monster once), then let the trader step out.
func _on_combat_ended() -> void:
	for m in monsters:
		if not m.is_alive() and not m.has_meta("quest_counted"):
			m.set_meta("quest_counted", true)
			if m.stats:
				Quest.note_kill(m.stats.id)
	quest_check()
	_npc_t = 0.6


## No living monster within the NPC's guard_radius (he only comes out once they're dead).
func _npc_area_clear(n: Npc) -> bool:
	if n.guard_radius <= 0:
		return true
	for m in monsters:
		if m.is_alive() and grid_distance(m.cell, n.get_cell()) <= n.guard_radius:
			return false
	return true


var _npc_t := 0.0


## NPCs come out of hiding once their area is clear, and call the party over the first time the
## party sees them (Brannoc's intro, where he gives the quest and the rune).
func _tick_npcs(delta: float) -> void:
	_npc_t -= delta
	if _npc_t > 0.0 or combat == null or combat.in_combat or combat.game_over or _leaving:
		return
	_npc_t = 0.25
	for n in entities.get_children():
		if not n is Npc:
			continue
		if not n.present:
			if _npc_area_clear(n):
				n.appear()
				invalidate_static()
				refresh_navigation()
				_refresh_fog_look()
				_npc_t = 1.2                  # a moment before he speaks up
			continue
		if not Quest.met and is_seen(n.get_cell()) and hud and not hud.ui_busy() \
				and not controller.is_walking() and controller.enabled:
			talk_to(n)
			return


## Talk to an NPC (he turns to the party and raises a hand; the dialogue box opens).
func talk_to(n: Npc) -> void:
	if combat.in_combat or not n.present:
		return
	controller.stop()
	n.greet(party[0].position if not party.is_empty() else n.position)
	if Modules.current:
		Modules.current.npc_talk(self, n)       # the module's dialogue for this NPC


## A present NPC under a world point: on the cell under it, or whose sprite the point is on.
func npc_under(pos: Vector2) -> Npc:
	var c := IsoGrid.world_to_cell(pos)
	for n in entities.get_children():
		if n is Npc and n.present and n.visible and (n.get_cell() == c or n.sprite_rect().has_point(pos)):
			return n
	return null


## The (shown) portal on a cell, or null.
func portal_at(cell: Vector2i) -> Portal:
	for n in entities.get_children():
		if n is Portal and n.is_shown() and n.get_cell() == cell:
			return n
	return null


## A shown portal under a world point (its cell or its oval of light).
func portal_under(pos: Vector2) -> Portal:
	var p := portal_at(IsoGrid.world_to_cell(pos))
	if p:
		return p
	for n in entities.get_children():
		if n is Portal and n.is_shown() and n.visible \
				and Rect2(n.position + Portal.OFFSET, Portal.FRAME_SIZE).has_point(pos):
			return n
	return null


const PORTAL_SCENE := preload("res://scenes/markers/portal.tscn")


## Put the rune's portal ends on this map: the runtime one where the rune was used (if it was used
## here), and tell the home one (outside the stall) where it leads. `fresh` = just opened (grows).
func _place_portals(fresh: bool) -> void:
	for n in entities.get_children():
		if n is Portal and not n.home:
			n.queue_free()
			entities.remove_child(n)
	for n in entities.get_children():
		if n is Portal and n.home:
			n.where = "back down to %s" % map_title_of(RunePortal.map_path)
	if RunePortal.active and RunePortal.map_path == scene_file_path:
		var p: Portal = PORTAL_SCENE.instantiate()
		p.name = "RunePortal"
		p.position = IsoGrid.view_cell_to_world(RunePortal.cell)
		p.where = "back to Brannoc's stall"
		entities.add_child(p)
		p.lock_cell()
		p.apply_view()
		if fresh:
			p.open_fx()
	_refresh_fog_look()


## A map scene's map_title (read from the file without loading the map), or "".
static func map_title_of(path: String) -> String:
	if path == "" or not ResourceLoader.exists(path):
		return "the dungeon"
	var st := (load(path) as PackedScene).get_state()
	for i in st.get_node_property_count(0):
		if st.get_node_property_name(0, i) == "map_title":
			return str(st.get_node_property_value(0, i))
	return "the dungeon"


## Use the Rune of Return: a portal opens next to the party (anywhere but the woods; not in a
## fight). Returns "" if it opened, else why not. Any portal open elsewhere moves here.
func use_rune() -> String:
	if combat.in_combat:
		return "No time for that in the middle of a fight!"
	if scene_file_path == RunePortal.home_map():
		return "The rune stays dark: Brannoc's stall is here in the woods."
	var c := _portal_cell()
	if c == NO_CELL:
		return "There's no room here for a portal."
	RunePortal.open_at(scene_file_path, c)
	_place_portals(true)
	Sfx.play("portal_open")
	SpellFx.sparkles(self, IsoGrid.cell_to_world(c) + Vector2(0, -16), Color8(150, 186, 255))
	combat._say("The rune flares blue and a portal opens. Brannoc's stall waits on the other side.")
	return ""


const NO_CELL := Vector2i(-99999, -99999)


## A free, explored floor cell next to the leader for the portal (in front of them if it can be).
func _portal_cell() -> Vector2i:
	if party.is_empty():
		return NO_CELL
	var lead := party[0]
	var dirs: Array = DIRS8.duplicate()
	dirs.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).normalized().dot(Vector2(lead.facing)) > Vector2(b).normalized().dot(Vector2(lead.facing)))
	for d: Vector2i in dirs:
		var c: Vector2i = lead.cell + d
		if terrain_walkable(c) and is_explored(c) and actor_at(c) == null and stairs_at(c) == null \
				and door_at(c) == null and npc_under(IsoGrid.cell_to_world(c)) == null:
			return c
	return NO_CELL


## Step through a portal (outside combat): from below to Brannoc's stall, or from the stall back to
## where the rune was used, which closes the portal.
func take_portal(p: Portal) -> void:
	if _leaving or combat.in_combat or combat.game_over or not p.is_shown():
		return
	var target := RunePortal.map_path if p.home else RunePortal.home_map()
	if target == "" or not ResourceLoader.exists(target):
		combat._say("The portal flickers. It leads nowhere.")
		return
	_leaving = true
	controller.enabled = false
	Sfx.play("portal_travel")
	for h in party:
		var tw := h.create_tween()
		tw.tween_property(h, "modulate", Color(0.6, 0.75, 1.6, 0.0), 0.5)
	var fade := _fade_rect()
	var tw2 := create_tween()
	tw2.tween_interval(0.25)
	tw2.tween_property(fade, "color:a", 1.0, 0.5)
	await tw2.finished
	MapState.save(self)
	if p.home:
		MapState.next_entry = RunePortal.ARRIVE
		MapState.arrive_cell = RunePortal.cell
		RunePortal.close()                  # the way back is used: the portal is gone
	else:
		MapState.next_entry = RunePortal.HOME_ENTRY
	PartyState.save(self)
	get_tree().change_scene_to_file(target)


## A moment after arriving: the description of the room the party stands in (Mechanisms).
func _arrival_notes() -> void:
	if mech and combat and not combat.in_combat and not _leaving:
		mech.check_notes()
