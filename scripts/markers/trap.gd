@tool
class_name Trap
extends MapMarker
## A trap on a floor cell (Phase 6). Hidden until a hero spots it: passive Perception (10 + skill)
## vs detect_dc while it is in sight within Mechanisms.SPOT_RANGE cells, or the party Searches (F).
## Stepping on an armed trap nobody has spotted sets it off (Mechanisms.spring). A spotted, armed
## trap is drawn with a red edge: the party's paths go round it, and clicking it sends the party
## over to disarm it (the Rogue with thieves' tools vs disarm_dc; fail by 5 or more and it goes
## off). one_shot traps stay sprung (harmless afterwards); the others re-arm.
## Monsters know their traps and walk over them.

enum TrapType { SPIKES, DARTS, FIRE_JET, PIT, ALARM }

@export var trap_type := TrapType.SPIKES:
	set(v):
		trap_type = v
		queue_redraw()
## false = in plain sight from the start (no need to spot it).
@export var concealed := true
@export var detect_dc := 12          ## Perception to spot it
@export var disarm_dc := 12          ## DEX (thieves' tools) to disarm it
@export var save_ability := "DEX"
@export var save_dc := 12
## > 0: an attack roll (d20 + this) vs AC instead of a saving throw (darts).
@export var attack_bonus := 0
@export var damage := "2d6"          ## dice expression ("" = none: the alarm)
@export var damage_type := "piercing"
@export var one_shot := true
## XP for disarming it (shared like a fight's).
@export var xp := 0

## name, armed texture, sprung texture, armed offset, sprung offset (gen_puzzle_art.gd)
const INFO := {
	TrapType.SPIKES: ["spike trap", "trap_spikes", "trap_spikes_sprung", Vector2(-17, -9), Vector2(-17, -17)],
	TrapType.DARTS: ["dart trap", "trap_darts", "trap_darts_sprung", Vector2(-17, -9), Vector2(-17, -9)],
	TrapType.FIRE_JET: ["fire vent", "trap_fire", "trap_fire_sprung", Vector2(-17, -9), Vector2(-17, -9)],
	TrapType.PIT: ["pit trap", "trap_pit", "trap_pit_open", Vector2(-17, -9), Vector2(-17, -9)],
	TrapType.ALARM: ["tripwire", "trap_wire", "trap_wire_cut", Vector2(-17, -9), Vector2(-17, -9)],
}
## Drawn this far up from its cell's centre: it then y-sorts under anyone standing on its cell or
## the cells beside it (it lies flat on the floor).
const SORT_UP := Vector2(0, -9)
const COL_DANGER := Color8(255, 70, 50)

var spotted := false:
	set(v):
		spotted = v
		queue_redraw()
var disarmed := false:
	set(v):
		disarmed = v
		queue_redraw()
var sprung := false:
	set(v):
		sprung = v
		queue_redraw()
## Seconds the sprung look stays on a trap that re-arms (spikes drop back down).
var _flash_t := 0.0
var _t := 0.0
var _tex := {}
var _warn: Node2D
## 7x7 warning sign: a red triangle with a pale "!" (the outline is drawn round it).
const WARN := ["...#...", "..#!#..", "..#!#..", ".##!##.", ".##.##.", "###!###", "#######"]


func _init() -> void:
	gizmo_color = Color(0.75, 0.45, 1.0)
	gizmo_label = "TRAP"


func _ready() -> void:
	super()
	set_process(not Engine.is_editor_hint())
	if Engine.is_editor_hint():
		return
	# A little red warning sign over a known, armed trap, drawn above the walls (unshaded) so a
	# trap in a corridor behind a wall still shows.
	_warn = Node2D.new()
	_warn.name = "Warn"
	_warn.z_as_relative = false
	_warn.z_index = 5
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_warn.material = mat
	_warn.position = -SORT_UP + Vector2(0, -12)
	_warn.draw.connect(_draw_warn)
	add_child(_warn)


func _snap_offset() -> Vector2:
	return SORT_UP


func trap_name() -> String:
	return INFO[trap_type][0]


## Will it go off?
func armed() -> bool:
	return not disarmed and not (one_shot and sprung)


## Does the party know it is there?
func known() -> bool:
	return spotted or not concealed or sprung or disarmed


## A known, armed trap: the party's paths go round it.
func blocks_party() -> bool:
	return armed() and known()


## DungeonMap draws it only once the party knows about it.
func is_shown() -> bool:
	return known()


## Show the sprung look for a moment (traps that re-arm).
func flash_sprung(seconds := 1.6) -> void:
	_flash_t = seconds
	queue_redraw()


func hint() -> String:
	var nm := trap_name().capitalize()
	if disarmed:
		return "%s (disarmed)." % nm
	if not armed():
		return "%s (sprung)." % nm
	return "%s! Click to disarm it (the Rogue's thieves' tools, DC %d)." % [nm, disarm_dc]


func save_state() -> Variant:
	if not (spotted or disarmed or sprung):
		return null
	return {s = spotted, d = disarmed, x = sprung}


func load_state(s: Variant) -> void:
	if s is Dictionary:
		spotted = s.get("s", false)
		disarmed = s.get("d", false)
		sprung = s.get("x", false)


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			queue_redraw()
	if blocks_party() and visible:
		_t += delta
		queue_redraw()             # the red edge pulses
	if _warn:
		_warn.visible = blocks_party()
		_warn.position.y = -SORT_UP.y - 12 + roundf(sin(_t * TAU / 1.4))


func _texture(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load("res://assets/sprites/props/%s.png" % n)
	return _tex[n]


func _draw() -> void:
	var info: Array = INFO[trap_type]
	var c := -SORT_UP                         # the cell centre, relative to the node
	var show_sprung := (sprung and not armed()) or _flash_t > 0.0
	var tex := _texture(info[2] if show_sprung else info[1])
	var at: Vector2 = c + (info[4] if show_sprung else info[3])
	if blocks_party() and not Engine.is_editor_hint():
		# a pulsing red edge round the cell: danger, the party goes round it
		var d := IsoGrid.diamond(1.5)
		for i in d.size():
			d[i] += c
		var a := 0.35 + 0.25 * sin(_t * TAU / 1.4)
		draw_colored_polygon(d, Color(COL_DANGER, a * 0.3))
		d.append(d[0])
		draw_polyline(d, Color(COL_DANGER, a + 0.2), 1.0)
	draw_texture(tex, at, Color(0.62, 0.62, 0.62, 0.8) if disarmed else Color.WHITE)
	if Engine.is_editor_hint():
		_draw_gizmo()


func _draw_warn() -> void:
	var o := Vector2(-3, -6)
	for y in WARN.size():
		for x in 7:
			if WARN[y][x] == ".":
				continue
			# 1px dark outline: draw the outline pixels first (the 4 neighbours), then the colour
			for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				var nx := x + int(d.x)
				var ny := y + int(d.y)
				if nx < 0 or ny < 0 or nx >= 7 or ny >= WARN.size() or WARN[ny][nx] == ".":
					_warn.draw_rect(Rect2(o + Vector2(nx, ny), Vector2.ONE), Color8(20, 16, 24))
	for y in WARN.size():
		for x in 7:
			var ch: String = WARN[y][x]
			if ch != ".":
				_warn.draw_rect(Rect2(o + Vector2(x, y), Vector2.ONE), Color8(255, 236, 200) if ch == "!" else COL_DANGER)
