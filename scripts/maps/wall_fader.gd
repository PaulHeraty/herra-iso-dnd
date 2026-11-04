class_name WallFader
extends RefCounted
## Fades wall blocks to semi-transparent while they stand in front of a hero or of a highlighted
## floor cell (path, destination, cursor), so nothing important is lost behind a pillar or wall. Each wall tile gets FADE_STEPS alternative tiles with lower alpha
## (made in memory at runtime; the TileSet file is not changed) and cells are switched between them.

const FADE_ALPHA := 0.55      ## opacity of a fully faded wall
const FADE_TIME := 0.15       ## seconds to fade out / back in
const FADE_STEPS := 4
const ALT_BASE := 100         ## alternative ids ALT_BASE+1 .. ALT_BASE+FADE_STEPS
## Minimum overlap (px) between figure and wall block before the wall fades.
const MIN_OVERLAP := 3.0
## Cells in front of a spot that a 40 px wall block could cover it from (the overlap test decides).
const AHEAD := [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 0), Vector2i(0, 2),
	Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 1), Vector2i(1, 3),
	Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4),
]

var _layer: TileMapLayer
var _torches: Array[Torch] = []
var _fade := {}               ## cell -> 0..1 (1 = fully faded)


func _init(walls: TileMapLayer, entities: Node) -> void:
	_layer = walls
	for n in entities.get_children():
		if n is Torch:
			_torches.append(n)
	_make_alternatives()


## Screen-space box of a standing figure (16x24 sprite) whose feet are at `feet`.
static func figure_rect(feet: Vector2) -> Rect2:
	return Rect2(feet + Vector2(-7, -22), Vector2(14, 22))


## Box of the middle of a (map) floor cell's diamond (corners left out), in the current view.
static func floor_rect(cell: Vector2i) -> Rect2:
	return Rect2(IsoGrid.cell_to_world(cell) + Vector2(-12, -5), Vector2(24, 10))


## Fade every wall block in front of any of these world-space boxes; un-fade the rest.
func update(rects: Array[Rect2], delta: float) -> void:
	var want := {}
	for r in rects:
		for c in _walls_hiding(r):
			want[c] = true
	for c in want:
		if not _fade.has(c):
			_fade[c] = 0.0
	var step := delta / FADE_TIME
	for c: Vector2i in _fade.keys():
		var v: float = clampf(_fade[c] + (step if want.has(c) else -step), 0.0, 1.0)
		_fade[c] = v
		_apply(c, v)
		if v == 0.0 and not want.has(c):
			_fade.erase(c)


## View wall cells in front of the box `fig` that cover part of it.
func _walls_hiding(fig: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var cell := IsoGrid.view_world_to_cell(Vector2(fig.get_center().x, fig.end.y - 1.0))
	for off in AHEAD:
		var c: Vector2i = cell + off
		if _layer.get_cell_source_id(c) == -1:
			continue
		var w := IsoGrid.view_cell_to_world(c)
		# Block outline: diamond footprint extruded 40 px up. At horizontal distance dx from its
		# centre it spans from y = w.y - 48 + |dx|/2 (top) to w.y + 8 - |dx|/2 (bottom).
		var dx := 0.0
		if fig.end.x < w.x:
			dx = w.x - fig.end.x
		elif fig.position.x > w.x:
			dx = fig.position.x - w.x
		if dx > 16.0 - MIN_OVERLAP:
			continue
		var top := w.y - 48.0 + dx / 2.0
		var bottom := w.y + 8.0 - dx / 2.0
		if minf(bottom, fig.end.y) - maxf(top, fig.position.y) >= MIN_OVERLAP:
			out.append(c)
	return out


func _apply(c: Vector2i, v: float) -> void:
	var k := roundi(v * FADE_STEPS)
	var alt := 0 if k == 0 else ALT_BASE + k
	if _layer.get_cell_alternative_tile(c) != alt:
		_layer.set_cell(c, _layer.get_cell_source_id(c), _layer.get_cell_atlas_coords(c), alt)
	for t in _torches:
		if IsoGrid.to_view(t.get_cell()) == c:
			t.modulate.a = lerpf(1.0, FADE_ALPHA, float(k) / FADE_STEPS)


## For every tile of the atlas sources used on this layer, add faded copies (same origin,
## sorting and custom data).
func _make_alternatives() -> void:
	var ts := _layer.tile_set
	var sources := {}
	for c in _layer.get_used_cells():
		sources[_layer.get_cell_source_id(c)] = true
	for sid: int in sources:
		var src := ts.get_source(sid) as TileSetAtlasSource
		if src == null:
			continue
		for t in src.get_tiles_count():
			_make_tile_alternatives(ts, src, src.get_tile_id(t))


func _make_tile_alternatives(ts: TileSet, src: TileSetAtlasSource, coords: Vector2i) -> void:
	var base := src.get_tile_data(coords, 0)
	for k in range(1, FADE_STEPS + 1):
		var alt := ALT_BASE + k
		if src.has_alternative_tile(coords, alt):
			continue
		src.create_alternative_tile(coords, alt)
		var d := src.get_tile_data(coords, alt)
		d.texture_origin = base.texture_origin
		d.y_sort_origin = base.y_sort_origin
		d.z_index = base.z_index
		d.flip_h = base.flip_h
		d.flip_v = base.flip_v
		d.transpose = base.transpose
		d.modulate = Color(base.modulate, base.modulate.a * lerpf(1.0, FADE_ALPHA, float(k) / FADE_STEPS))
		for i in ts.get_custom_data_layers_count():
			d.set_custom_data_by_layer_id(i, base.get_custom_data_by_layer_id(i))
