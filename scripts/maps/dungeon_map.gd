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
## XP the party has earned (levelling comes in Phase 5).
var party_xp := 0
var overlay: GridOverlay
var controller: PartyController
var camera_controller: CameraController
var wall_fader: WallFader
var scorch: ScorchLayer
var dice: DiceScene
var combat: CombatManager
var hud: CombatHud
## Visible, rotated copies of the Floor / Walls layers.
var floor_view: TileMapLayer
var walls_view: TileMapLayer
var _astar := AStarGrid2D.new()
var fog := FogOfWar.new()
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
	IsoGrid.rotation = 0
	var fr := floor_layer.get_used_rect()
	IsoGrid.pivot = fr.position + fr.size / 2
	for n in entities.get_children():
		if n is MapMarker:
			n.lock_cell()
		if n is Door:
			n.opened.connect(_on_door_opened)
	MapState.restore(self)
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
	refresh_navigation()
	_spawn_party()
	party_xp = PartyState.party_xp
	_compute_fog()
	refresh_navigation()
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
	_apply_view()
	if PartyState.has_state() or map_title != "":
		_arrival_fade(PartyState.has_state())

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("view_rotate_right"):
		rotate_view(1)
	elif Input.is_action_just_pressed("view_rotate_left"):
		rotate_view(-1)
	if _pending_turns != 0 and not _anyone_moving():
		apply_pending_rotation()
	_tick_fog()
	var reveal: Array[Rect2] = []
	for h in party:
		reveal.append(WallFader.figure_rect(h.position))
	for mo in monsters:
		reveal.append(WallFader.figure_rect(mo.position))
	for c in overlay.revealed_cells():
		reveal.append(WallFader.floor_rect(c))
	wall_fader.update(reveal, delta)


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
	for n in entities.get_children():
		if n is Monster and n.cell == cell and n.is_alive():
			return false
		if n is MonsterSpawn and n.monster == null and n.get_cell() == cell:
			return false
	return true


## Floor without a wall, closed door or chest (ignores creatures).
func terrain_walkable(cell: Vector2i) -> bool:
	if floor_layer.get_cell_source_id(cell) == -1:
		return false
	var wall := walls_layer.get_cell_tile_data(cell)
	if wall and wall.get_custom_data("blocks_move"):
		return false
	for n in entities.get_children():
		if n is Door and n.get_cell() == cell and n.blocks_move():
			return false
		if n is Chest and n.get_cell() == cell:
			return false
		if n is Prop and n.blocks and n.get_cell() == cell:
			return false
		if n is Brazier and n.get_cell() == cell:
			return false
	return true


const DIRS8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


## Combat movement: every cell `mover` can reach from `from` within `budget` squares (5e: each
## square costs 1, diagonals too; no cutting wall corners). Allies can be passed through but not
## stopped on; enemies block. Returns cell -> {cost, prev, stop} where stop = can end the move there.
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
				var occ := actor_at(n)
				if occ and occ != mover and occ.is_alive() and not _same_side(occ, mover):
					continue
				reach[n] = {cost = cost, prev = c, stop = occ == null or occ == mover or not occ.is_alive()}
				next.append(n)
		frontier = next
	return reach


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
	return is_walkable(cell) and is_explored(cell)


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
	out.assign(_astar.get_id_path(from, to))
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


## True if a cell blocks sight: a wall, or a closed door.
func blocks_sight(cell: Vector2i) -> bool:
	if walls_layer.get_cell_source_id(cell) != -1:
		return true
	for n in entities.get_children():
		if n is Door and n.get_cell() == cell and n.blocks_move():
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
	if d and not d.is_open:
		return d
	for n in entities.get_children():
		if n is Door and not n.is_open and n.panel_rect().has_point(pos):
			return n
	return null


## Try to open a door: unlocked doors just open; locked ones are picked by the Rogue (thieves'
## tools: DEX + expertise vs lock_dc) or, failing that, forced by the strongest hero (Athletics vs
## lock_dc + 2). Each try is one roll; the player can try again. Logs what happens. Returns true
## if the door is now open.
func try_open_door(door: Door, by: Array[Hero]) -> bool:
	if door.is_open:
		return true
	if not door.locked:
		door.open()
		return true
	var able := by.filter(func(h: Hero): return h.is_alive())
	if able.is_empty():
		return false
	if door.key_id != "" and door.lock_dc <= 0:
		combat._say("The door is locked. It needs a key.")
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
	var dc := door.lock_dc if rogue else door.lock_dc + 2
	var r := Dice.d20(who.stats.skill_bonus(skill))
	if r.total >= dc:
		combat._say("%s %s the lock (%s vs DC %d)" % [who.display_name(),
				"picks" if rogue else "forces", r.describe(), dc])
		Sfx.play("lock_click" if rogue else "hit_blunt")
		door.open()
		return true
	combat._say("%s fails to %s the lock (%s vs DC %d)" % [who.display_name(),
			"pick" if rogue else "force", r.describe(), dc])
	Sfx.play("door_locked")
	return false


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
		if n is Door and n.blocks_move():
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
			n.visible = is_explored(n.get_cell())
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
	if start == null:
		push_warning("%s: no PartyStart marker, party not spawned" % name)
		return
	var cells := _formation_cells(start.get_cell(), PARTY_ORDER.size())
	for i in cells.size():
		var hero: Hero = HERO_SCENE.instantiate()
		hero.hero_class = PARTY_ORDER[i]
		entities.add_child(hero)
		hero.facing = PartyStart.FACING_DIR[start.facing]
		hero.place_at(cells[i])
		PartyState.apply(hero)
		party.append(hero)


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
