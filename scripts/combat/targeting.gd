class_name Targeting
## Grid shapes for spells and abilities (map cells).

## size x size square centred on `center` (odd sizes; Fireball 3x3).
static func area_cells(center: Vector2i, size: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := size / 2
	for y in range(-r, size - r):
		for x in range(-r, size - r):
			out.append(center + Vector2i(x, y))
	return out


## Cells along a line from `from` toward `toward`, `length` cells long (excluding `from`).
static func line_cells(from: Vector2i, toward: Vector2i, length: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var d := Vector2(toward - from)
	if d == Vector2.ZERO:
		return out
	d = d.normalized()
	var p := Vector2(from) + Vector2(0.5, 0.5)
	var seen := {}
	var steps := length * 4
	for i in range(1, steps + 1):
		var q := p + d * (float(i) / 4.0)
		var c := Vector2i(floori(q.x), floori(q.y))
		if c != from and not seen.has(c):
			seen[c] = true
			out.append(c)
		if DungeonMap.grid_distance(from, c) >= length:
			break
	return out


## 5e cone: a 90-degree wedge from `from` toward `toward`, `length` cells long.
static func cone_cells(from: Vector2i, toward: Vector2i, length: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var d := Vector2(toward - from)
	if d == Vector2.ZERO:
		return out
	d = d.normalized()
	for y in range(-length, length + 1):
		for x in range(-length, length + 1):
			var off := Vector2(x, y)
			if off == Vector2.ZERO or maxi(absi(x), absi(y)) > length:
				continue
			if off.normalized().dot(d) >= cos(deg_to_rad(45.0)) - 0.001:
				out.append(from + Vector2i(x, y))
	return out
