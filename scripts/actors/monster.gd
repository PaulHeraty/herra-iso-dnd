class_name Monster
extends Actor
## A monster on the map: stat block from data/monsters/<id>.tres + an animated sprite sheet.
## One scene per monster type in scenes/actors/monsters/<id>.tscn sets the sheet and animations.
##
## anims: name -> [row, first column, frame count, fps, loop]. Expected names: idle, walk, attack,
## hurt, death (+ optional idle variants listed in idle_extras, played now and then, e.g. blink).
## back_row_offset: rows to add for the back 3/4 view (facing up the screen); -1 = no back view.

signal animation_finished(anim: String)

@export var monster_id := ""
@export var anims := {
	"idle": [0, 0, 1, 4.0, true],
}
@export var back_row_offset := -1
@export var idle_extras: PackedStringArray = []
## Seconds between idle variants (random in this range).
@export var idle_extra_every := Vector2(2.5, 6.0)

var group_id := 0
var _anim := ""
var _mt := 0.0
var _back := false
var _extra_timer := 0.0


func _ready() -> void:
	hop_steps = false
	if stats == null and monster_id != "":
		stats = load("res://data/monsters/%s.tres" % monster_id)
	_extra_timer = randf_range(idle_extra_every.x, idle_extra_every.y)
	super()
	play("idle")
	_mt = randf() * 2.0     # don't let every monster of a kind idle in lockstep


## Start an animation from its first frame (no-op if it is already playing and loops).
func play(anim: String) -> void:
	if not anims.has(anim):
		anim = "idle"
	if anim == _anim and anims[anim][4]:
		return
	_anim = anim
	_mt = 0.0
	_show_frame()


func current_animation() -> String:
	return _anim


func _process(delta: float) -> void:
	if _anim == "":
		return
	var a: Array = anims[_anim]
	_mt += delta
	var n := int(_mt * a[3])
	if n >= a[2] and not a[4]:
		var done := _anim
		if done == "death":
			_mt = (a[2] - 0.5) / a[3]     # hold the last frame
			_show_frame()
			if not get_meta("death_signalled", false):
				set_meta("death_signalled", true)
				animation_finished.emit(done)
			return
		animation_finished.emit(done)
		play("idle")
		return
	# Walk while stepping, idle otherwise (unless a one-shot like attack/hurt is playing).
	var looping: bool = a[4]
	if looping:
		if is_moving() and anims.has("walk") and _anim != "walk":
			play("walk")
			return
		if not is_moving() and _anim == "walk":
			play("idle")
			return
		if _anim == "idle" and not idle_extras.is_empty():
			_extra_timer -= delta
			if _extra_timer <= 0.0:
				_extra_timer = randf_range(idle_extra_every.x, idle_extra_every.y)
				play(idle_extras[randi() % idle_extras.size()])
				return
	_show_frame()


func _show_frame() -> void:
	var a: Array = anims[_anim]
	var i := int(_mt * a[3])
	i = posmod(i, a[2]) if a[4] else mini(i, a[2] - 1)
	var row: int = a[0] + (back_row_offset if _back and back_row_offset >= 0 else 0)
	sprite.frame = row * sprite.hframes + a[1] + i


## Front/back view and mirroring from the facing as seen in the current view.
func _update_facing_visual() -> void:
	var v := IsoGrid.rotate_dir(facing)
	var screen := Vector2i(v.x - v.y, v.x + v.y)
	if screen.x != 0:
		sprite.flip_h = screen.x > 0
	if screen.y != 0:
		_back = screen.y < 0
	if _anim != "":
		_show_frame()
