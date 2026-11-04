class_name Actor
extends Node2D
## Anything that stands on the grid and moves around: heroes now, monsters in Phase 2.
## The node's position is the actor's feet (a cell centre). It draws a soft elliptical shadow
## under itself; the "Sprite" child draws the figure on top.
##
## Walk sheets (see tools/godot/gen_hero_sheets.gd): 5 columns (idle, 4 walk frames) x 2 rows
## (0 = front 3/4 facing screen down-left, 1 = back 3/4 facing screen up-left); right-facing
## directions are the same rows mirrored. A single-frame sprite falls back to mirror + hop.

## Shadow ellipse radius (x) in px; it's squashed vertically like the iso floor.
@export var shadow_radius := 7.0
@export var shadow_alpha := 0.7
## Stat block (heroes: data/heroes/, monsters: data/monsters/). Current HP lives in `hp`.
@export var stats: CreatureStats
## Height of the figure's middle above its feet (aim point for numbers, arrows and rays).
@export var body_height := 14.0

const WALK_FRAME_TIME := 0.09     ## s per walk frame: 2 frames per orthogonal step
const IDLE_DELAY := 0.06          ## stay in the walk cycle across the gap between steps

## The cell the actor stands on, or is walking into (map cells).
var cell := Vector2i.ZERO
## Direction the actor faces, in map cells (one of the 8 neighbours).
var facing := Vector2i(0, 1):
	set(v):
		facing = v
		if is_node_ready():
			_update_facing_visual()

## True for hero-style walk sheets (5 x 2: idle + 4 walk frames, front/back rows). Set by Hero.
var walk_sheet := false
## Without a walk sheet: bob 1px per step so walking reads (monsters animate themselves instead).
var hop_steps := true
var _tween: Tween
var _anim_t := 0.0
var _still_t := 0.0
var _row := 0
## Current hit points (set to stats.max_hp on spawn).
var hp := 0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	if stats:
		hp = stats.max_hp
	_update_facing_visual()


## Put the actor straight onto a cell (no animation). Also used after the view turns.
func place_at(c: Vector2i) -> void:
	cell = c
	position = IsoGrid.cell_to_world(c)
	_update_facing_visual()


func is_moving() -> bool:
	return _tween != null and _tween.is_running()


func has_walk_sheet() -> bool:
	return walk_sheet


## Walk to a neighbouring cell over `duration` seconds. `cell` changes at once (so pathing and
## occupancy see where the actor is going). Returns the tween; await its `finished`.
func step_to(c: Vector2i, duration: float) -> Tween:
	var d := c - cell
	if d != Vector2i.ZERO:
		facing = d.clampi(-1, 1)
	cell = c
	var target := IsoGrid.cell_to_world(c)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", target, duration)
	if hop_steps and not has_walk_sheet():
		# Little 1px hop per step so walking reads as walking without a walk cycle.
		_tween.parallel().tween_property(sprite, "position:y", -1.0, duration * 0.5)
		_tween.parallel().tween_property(sprite, "position:y", 0.0, duration * 0.5).set_delay(duration * 0.5)
	return _tween


func _process(delta: float) -> void:
	if not has_walk_sheet():
		return
	if is_moving():
		_still_t = 0.0
		_anim_t += delta
		sprite.frame = _row * sprite.hframes + 1 + int(_anim_t / WALK_FRAME_TIME) % 4
	else:
		_still_t += delta
		if _still_t >= IDLE_DELAY:
			_anim_t = 0.0
			sprite.frame = _row * sprite.hframes


## Pick sheet row (front/back) and mirroring from the facing as seen in the current view.
## Facings that point straight across or straight up/down the screen keep the previous choice
## for the part that is ambiguous.
func _update_facing_visual() -> void:
	var v := IsoGrid.rotate_dir(facing)
	var screen := Vector2i(v.x - v.y, v.x + v.y)    # iso: +x cell = right+down, +y cell = left+down
	if screen.x != 0:
		sprite.flip_h = screen.x > 0                # drawings face left; mirror to face right
	if screen.y != 0:
		_row = 0 if screen.y > 0 else 1
	if has_walk_sheet():
		sprite.frame = _row * sprite.hframes + (sprite.frame % sprite.hframes)


func _draw() -> void:
	# Soft shadow: a darker core inside a fainter rim, both squashed 0.45 vertically.
	draw_set_transform(Vector2(0, 1), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, shadow_radius + 1.5, Color(0, 0, 0, shadow_alpha * 0.5))
	draw_circle(Vector2.ZERO, shadow_radius, Color(0, 0, 0, shadow_alpha))
	draw_set_transform(Vector2.ZERO)


func display_name() -> String:
	return stats.display_name if stats else String(name)


func is_alive() -> bool:
	return hp > 0


## World position of the figure's middle (where hits land).
func body_position() -> Vector2:
	return position + Vector2(0, -body_height)


## Lose hit points. Returns the damage actually taken. Plays hurt or down/death visuals.
func take_damage(amount: int) -> int:
	if hp <= 0:
		return 0
	var taken := mini(amount, hp)
	hp -= taken
	if hp <= 0:
		_on_down()
	else:
		_on_hurt()
	return taken


func _flash(col := Color(1.0, 0.35, 0.35)) -> void:
	var tw := create_tween()
	sprite.modulate = col
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)


## Brief lunge toward a point (melee attack), then back.
func lunge(toward: Vector2, px := 4.0) -> Tween:
	var d := (toward - position).normalized() * px
	var tw := create_tween()
	tw.tween_property(sprite, "position", d, 0.08)
	tw.tween_property(sprite, "position", Vector2.ZERO, 0.12)
	return tw


func _on_hurt() -> void:
	_flash()


func _on_down() -> void:
	_flash()
