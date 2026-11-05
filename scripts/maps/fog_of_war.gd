class_name FogOfWar
extends RefCounted
## What the party has explored and what it can see right now (map cells).
##   explored: every cell the party has ever seen (kept per map by MapState).
##   visible:  cells some conscious hero sees now: symmetric-ish recursive shadowcasting, radius
##             SIGHT cells (darkvision 60 ft), walls and closed doors block, props don't.
## DungeonMap draws unexplored cells as nothing (black), explored-but-not-visible ones dimmed,
## and hides monsters outside `visible` (outside combat).

const SIGHT := 12

var explored := {}
var visible := {}

var _opaque := {}
var _radius2 := 0.0
var _out := {}

## Octant transforms (xx, xy, yx, yy).
const OCTANTS := [[1, 0, 0, 1], [0, 1, 1, 0], [0, -1, 1, 0], [-1, 0, 0, 1],
		[-1, 0, 0, -1], [0, -1, -1, 0], [0, 1, -1, 0], [1, 0, 0, -1]]


## Recompute `visible` from the eyes (hero cells); returns the cells seen for the first time.
func update(eyes: Array[Vector2i], opaque: Dictionary) -> Array[Vector2i]:
	_opaque = opaque
	_radius2 = (SIGHT + 0.5) * (SIGHT + 0.5)
	_out = {}
	for e in eyes:
		_out[e] = true
		for o in OCTANTS:
			_cast(e, 1, 1.0, 0.0, o[0], o[1], o[2], o[3])
	visible = _out
	var fresh: Array[Vector2i] = []
	for c: Vector2i in visible:
		if not explored.has(c):
			explored[c] = true
			fresh.append(c)
	return fresh


## Recursive shadowcasting (RogueBasin, Björn Bergström) for one octant.
func _cast(o: Vector2i, row: int, start: float, end: float, xx: int, xy: int, yx: int, yy: int) -> void:
	if start < end:
		return
	var new_start := 0.0
	for j in range(row, SIGHT + 1):
		var dx := -j - 1
		var dy := -j
		var blocked := false
		while dx <= 0:
			dx += 1
			var c := Vector2i(o.x + dx * xx + dy * xy, o.y + dx * yx + dy * yy)
			var l_slope := (dx - 0.5) / (dy + 0.5)
			var r_slope := (dx + 0.5) / (dy - 0.5)
			if start < r_slope:
				continue
			if end > l_slope:
				break
			if dx * dx + dy * dy < _radius2:
				_out[c] = true
			if blocked:
				if _opaque.has(c):
					new_start = r_slope
					continue
				blocked = false
				start = new_start
			elif _opaque.has(c) and j < SIGHT:
				blocked = true
				_cast(o, j + 1, start, l_slope, xx, xy, yx, yy)
				new_start = r_slope
		if blocked:
			break
