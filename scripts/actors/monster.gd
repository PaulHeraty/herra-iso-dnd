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
## After the death animation the monster disappears: it waits death_fade_delay seconds on its
## last frame, then fades out (shadow too). The Eye Tyrant's animation already dissolves it, so
## its delay is 0. Set false to leave a corpse.
@export var vanish_on_death := true
@export var death_fade_delay := 1.0
## Combat HP bar: height above the feet (top of the sprite) and width.
@export var hp_bar_y := -30.0
@export var hp_bar_w := 16

var group_id := 0
## Shown while this monster is in a fight (CombatManager sets it).
var show_hp_bar := false:
	set(v):
		show_hp_bar = v
		if _bar:
			_bar.queue_redraw()
var _bar: Node2D
var _anim := ""
var _mt := 0.0
var _back := false
var _extra_timer := 0.0


func _ready() -> void:
	hop_steps = false
	if stats == null and monster_id != "":
		stats = load("res://data/monsters/%s.tres" % monster_id)
	_extra_timer = randf_range(idle_extra_every.x, idle_extra_every.y)
	_bar = Node2D.new()
	_bar.name = "HpBar"
	_bar.z_index = 45
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_bar.material = mat
	_bar.draw.connect(_draw_hp_bar)
	add_child(_bar)
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
	if show_hp_bar and _bar:
		_bar.queue_redraw()
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
				if vanish_on_death:
					_fade_out()
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


func _on_hurt() -> void:
	_flash()
	play("hurt")
	Sfx.play("monster_hurt")


func _on_down() -> void:
	_flash()
	play("death")
	Sfx.play("monster_death")


func _fade_out() -> void:
	var tw := create_tween()
	if death_fade_delay > 0.0:
		tw.tween_interval(death_fade_delay)
		tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): visible = false)


func take_damage(amount: int) -> int:
	var t := super(amount)
	if _bar:
		_bar.queue_redraw()
	return t


## Small bar above the monster: dark frame, red fill for the HP left.
func _draw_hp_bar() -> void:
	if not show_hp_bar or not is_alive() or stats == null:
		return
	var w := hp_bar_w
	var x := -w / 2
	var y := int(hp_bar_y)
	_bar.draw_rect(Rect2(x - 1, y - 1, w + 2, 4), Color8(20, 16, 24))
	_bar.draw_rect(Rect2(x, y, w, 2), Color8(58, 22, 28))
	var fill := roundi(w * clampf(float(hp) / stats.max_hp, 0.0, 1.0))
	if fill > 0:
		_bar.draw_rect(Rect2(x, y, fill, 2), Color8(214, 60, 52))
	# Condition icons above the bar (prone, restrained...).
	var ids := Condition.shown_ids(self)
	var ix := -(ids.size() * 10 - 1) / 2
	for i in ids.size():
		_bar.draw_texture_rect_region(Condition.ICONS, Rect2(ix + i * 10, y - 11, 9, 9), Condition.icon_rect(ids[i]))
