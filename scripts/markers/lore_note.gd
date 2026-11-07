@tool
class_name LoreNote
extends MapMarker
## Something to read (Phase 6): a book on a lectern, a carved stone tablet, or a dead adventurer's
## last letter. Blocks its cell. Click it: the party walks up and reads it in the dialogue box
## (Mechanisms.read_lore); it goes into the journal (Quest.lore, the quest log's Lore page).
## Unread ones twinkle now and then so the player notices them. Exploring only.
## REMAINS lies flat on the floor: like a Trap it sits SORT_UP above its cell centre (y-sorting).

enum Kind { BOOK, TABLET, REMAINS }

const TEX := {Kind.BOOK: "lore_book", Kind.TABLET: "lore_tablet", Kind.REMAINS: "lore_remains"}
const OFFSET := Vector2(-12, -27)             ## BOOK / TABLET: 24x34, like the lever
const FLAT_OFFSET := Vector2(-17, -9)          ## REMAINS: 34x18, like a trap
const SORT_UP := Vector2(0, -9)
const NAMES := {Kind.BOOK: "A book on a lectern", Kind.TABLET: "A carved stone tablet", Kind.REMAINS: "A dead adventurer's pack"}
## Where the twinkle shows, relative to the cell centre.
const SPARK := {Kind.BOOK: Vector2(-1, -20), Kind.TABLET: Vector2(2, -24), Kind.REMAINS: Vector2(3, -6)}

@export var kind := Kind.BOOK:
	set(v):
		kind = v
		_tex = null
		queue_redraw()
@export var title := ""
@export_multiline var text := ""
## Story flag set the first time it is read (Quest.set_flag: a side quest may wait for it).
@export var flag := ""

var read := false:
	set(v):
		read = v
		if _spark:
			_spark.queue_redraw()
var _tex: Texture2D
var _t := 0.0
var _spark: Node2D               ## the twinkle, unshaded (shows in the dark)


func _init() -> void:
	gizmo_color = Color(0.9, 0.85, 0.6)
	gizmo_label = "LORE"


func _ready() -> void:
	super()
	_t = randf() * 3.0
	if Engine.is_editor_hint():
		set_process(false)
		return
	_spark = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_spark.material = mat
	_spark.draw.connect(_draw_spark)
	add_child(_spark)


func _snap_offset() -> Vector2:
	return SORT_UP if kind == Kind.REMAINS else Vector2.ZERO


## Journal key: the same note on the same map is one entry.
func lore_id() -> String:
	var m := owner.scene_file_path if owner else ""
	return "%s:%s" % [m, name]


func sprite_rect() -> Rect2:
	var c := position - _snap_offset()
	if kind == Kind.REMAINS:
		return Rect2(c + Vector2(-14, -8), Vector2(28, 16))
	return Rect2(c + Vector2(-9, -26), Vector2(18, 30))


func hint() -> String:
	return "%s%s: click to read it." % [NAMES[kind], " (read)" if read else ""]


func save_state() -> Variant:
	return {r = true} if read else null


func load_state(s: Variant) -> void:
	if s is Dictionary:
		read = s.get("r", false)


func _process(delta: float) -> void:
	if read:
		return
	_t += delta
	if _spark:
		_spark.queue_redraw()


func _draw() -> void:
	var c := -_snap_offset()
	if kind != Kind.REMAINS:
		draw_set_transform(c + Vector2(0, 1), 0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.4))
		draw_set_transform(Vector2.ZERO)
	if _tex == null:
		_tex = load("res://assets/sprites/props/%s.png" % TEX[kind])
	if _tex:
		draw_texture(_tex, c + (FLAT_OFFSET if kind == Kind.REMAINS else OFFSET))
	if Engine.is_editor_hint():
		_draw_gizmo()


## Unread: a little gold twinkle every few seconds.
func _draw_spark() -> void:
	if read:
		return
	var k := fmod(_t, 2.6)
	if k >= 0.5:
		return
	var s: Vector2 = SPARK[kind] - _snap_offset()
	var col := Color8(255, 236, 150, 230 if k < 0.35 else 120)
	var r := 1 if k < 0.12 or k > 0.38 else 2
	_spark.draw_rect(Rect2(s, Vector2(1, 1)), Color.WHITE)
	for i in range(1, r + 1):
		for d in [Vector2(i, 0), Vector2(-i, 0), Vector2(0, i), Vector2(0, -i)]:
			_spark.draw_rect(Rect2(s + d, Vector2(1, 1)), col)
