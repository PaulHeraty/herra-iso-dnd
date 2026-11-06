@tool
class_name Puzzle
extends MapMarker
## The rules of a puzzle (invisible in game). Its inputs are the levers / plates / braziers /
## blocks whose `link` equals this puzzle's `link`; when it is solved it opens the doors whose
## link is `opens` (Mechanisms.fire) and stays solved. Kinds:
##   SEQUENCE  pull the levers in the order of `solution` (symbol names: "sun,moon,star"). A wrong
##             lever: they all spring back up (and `penalty` dice hit whoever pulled it).
##   ALL_ON    every input on at once: all plates pressed (blocks pushed onto them), all levers
##             down, all braziers lit.
##   RING      braziers in a ring (their `order`): lighting or dousing one flips it and its two
##             neighbours. All lit = solved.

enum Kind { SEQUENCE, ALL_ON, RING }

@export var link := ""
@export var kind := Kind.SEQUENCE
@export var opens := ""
@export var solution := ""
## SEQUENCE: dice that hit the hero who pulls a wrong lever ("" = none), and their damage type.
@export var penalty := ""
@export var penalty_type := "piercing"
## XP when solved (shared like a fight's).
@export var xp := 0
## Logged when it is solved.
@export_multiline var solved_text := "Somewhere close, stone grinds against stone."

var solved := false
## SEQUENCE: the symbols pulled so far.
var progress: Array[String] = []


func _init() -> void:
	gizmo_color = Color(1.0, 0.5, 0.9)
	gizmo_label = "PUZZLE"


func steps() -> PackedStringArray:
	return solution.split(",", false)


## Never drawn in game.
func is_shown() -> bool:
	return false


func save_state() -> Variant:
	if not solved and progress.is_empty():
		return null
	return {s = solved, p = Array(progress)}


func load_state(s: Variant) -> void:
	if s is Dictionary:
		solved = s.get("s", false)
		progress.assign(s.get("p", []))
