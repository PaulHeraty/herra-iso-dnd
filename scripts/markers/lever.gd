@tool
class_name Lever
extends MapMarker
## A lever on a stone pedestal, standing on a floor cell (blocks it). Click it: the party walks up
## and pulls it (Mechanisms.pull). Without a Puzzle on its `link`, the lever drives the doors
## (portcullis / secret) whose link matches: down = open, up = closed. With a Puzzle (e.g. a
## SEQUENCE of symbols), the puzzle decides. `role = "reset"` puts a puzzle's blocks back home.
## In combat pulling a lever is the free object interaction (once a turn).

enum Symbol { NONE, SUN, MOON, STAR, SKULL, EYE }
## 5x5 glyphs drawn on the pedestal's plaque (gold).
const GLYPHS := {
	Symbol.SUN: ["#.#.#", ".###.", "##.##", ".###.", "#.#.#"],
	Symbol.MOON: [".###.", "##...", "#....", "##...", ".###."],
	Symbol.STAR: ["..#..", "#####", ".###.", ".#.#.", "#...#"],
	Symbol.SKULL: [".###.", "#####", "#.#.#", ".###.", ".#.#."],
	Symbol.EYE: [".....", ".###.", "##.##", ".###.", "....."],
}
const SYMBOL_NAMES := {Symbol.NONE: "", Symbol.SUN: "sun", Symbol.MOON: "moon", Symbol.STAR: "star",
		Symbol.SKULL: "skull", Symbol.EYE: "eye"}
const OFFSET := Vector2(-12, -27)
const PLAQUE := Vector2(-6, -7)             ## glyph top-left, relative to the cell centre (5x5, sheared with the face)
const GLYPH_COL := Color8(236, 196, 92)

@export var link := ""
@export var symbol := Symbol.NONE:
	set(v):
		symbol = v
		queue_redraw()
## "" = a normal lever; "reset" = puts the link's puzzle (blocks, levers) back as it started.
@export var role := ""
@export var down := false:
	set(v):
		down = v
		queue_redraw()

var _tex_up: Texture2D
var _tex_down: Texture2D


func _init() -> void:
	gizmo_color = Color(0.95, 0.75, 0.3)
	gizmo_label = "LEVER"


func symbol_name() -> String:
	return SYMBOL_NAMES[symbol]


func sides() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DungeonMap.DIRS8:
		out.append(get_cell() + d)
	return out


func sprite_rect() -> Rect2:
	return Rect2(position + Vector2(-9, -24), Vector2(18, 28))


func hint() -> String:
	if role == "reset":
		return "A lever marked with a circular arrow: click to pull it (puts the blocks back)."
	var what := "Lever" if symbol == Symbol.NONE else "Lever with a %s on it" % symbol_name()
	return "%s (%s): click to pull it." % [what, "down" if down else "up"]


func save_state() -> Variant:
	return {d = down} if down else null


func load_state(s: Variant) -> void:
	if s is Dictionary:
		down = s.get("d", false)


func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO)
	if _tex_up == null:
		_tex_up = load("res://assets/sprites/props/lever_up.png")
		_tex_down = load("res://assets/sprites/props/lever_down.png")
	draw_texture(_tex_down if down else _tex_up, OFFSET)
	var g: Array = GLYPHS.get(symbol, [])
	if role == "reset":
		g = [".###.", "#...#", "#.#..", "#..#.", ".###."]
	for y in g.size():
		for x in 5:
			if g[y][x] == "#":
				draw_rect(Rect2(PLAQUE + Vector2(x, y + x * 0.5).floor(), Vector2(1, 1)), GLYPH_COL)
	if Engine.is_editor_hint():
		_draw_gizmo()
