class_name ScorchLayer
extends Node2D
## Scorch marks left on the floor (Fireball). Sits just above the floor, below everything else,
## and is lit like the floor. Stores map cells, so it follows view rotation (redraw on turn).

const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
const DARK := [Color8(12, 9, 10), Color8(24, 19, 20), Color8(38, 31, 31)]

## map cell -> strength 0..1 (centre of a blast darker)
var marks := {}


func add_mark(cell: Vector2i, strength: float) -> void:
	marks[cell] = maxf(marks.get(cell, 0.0), strength)
	queue_redraw()


func _draw() -> void:
	for cell: Vector2i in marks:
		var s: float = marks[cell]
		var c := IsoGrid.cell_to_world(cell)
		var seed_v := absi(cell.x * 73856093 ^ cell.y * 19349663)
		for y in range(-8, 8):
			for x in range(-16, 16):
				var e := absf(x + 0.5) / 16.0 + absf(y + 0.5) / 8.0
				if e >= 1.0:
					continue
				# soft dithered blob, ragged edge from a per-cell hash
				var n := float((seed_v + (x * 7 + y * 13) * 2654435761) & 255) / 255.0
				var v := s * (1.45 - e) - 0.12 + n * 0.3
				var th: float = BAYER[posmod(y, 4)][posmod(x, 4)] / 16.0
				if v > th:
					var level := 0 if v > 0.75 else (1 if v > 0.45 else 2)
					draw_rect(Rect2(c.x + x, c.y + y, 1, 1), DARK[level])
