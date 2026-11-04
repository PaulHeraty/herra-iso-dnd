class_name GridOverlay
extends Node2D
## Tinted floor diamonds drawn just above the Floor layer and under everything that y-sorts:
## hover cursor, path preview, and (Phase 2+) move ranges, spell areas, the active hero.
## Like the mock-ups, overlays are not darkened by the ambient light.

## name -> {cells: Array[Vector2i], color: Color, fill: float, border: float, reveal: bool}
var _layers := {}
var _order: Array[String] = []


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


## Show (or replace) a named set of tinted cells. Layers draw in the order first set.
## `reveal`: walls standing in front of these cells fade out so the marks can be seen.
func set_cells(layer: String, cells: Array, color: Color, fill := 0.18, border := 0.45, reveal := false) -> void:
	if layer not in _order:
		_order.append(layer)
	_layers[layer] = {cells = cells, color = color, fill = fill, border = border, reveal = reveal}
	queue_redraw()


## All cells of layers shown with reveal = true.
func revealed_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for l: Dictionary in _layers.values():
		if l.reveal:
			out.append_array(l.cells)
	return out


func clear(layer: String) -> void:
	if _layers.erase(layer):
		queue_redraw()


func _draw() -> void:
	var fill_poly := IsoGrid.diamond(1)
	var edge := IsoGrid.diamond(1)
	edge.append(edge[0])
	for layer in _order:
		if not _layers.has(layer):
			continue
		var l: Dictionary = _layers[layer]
		for c: Vector2i in l.cells:
			draw_set_transform(IsoGrid.cell_to_world(c))
			if l.fill > 0.0:
				draw_colored_polygon(fill_poly, Color(l.color, l.fill))
			if l.border > 0.0:
				draw_polyline(edge, Color(l.color, l.border), 1.0)
	draw_set_transform(Vector2.ZERO)
