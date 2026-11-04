@tool
class_name Trap
extends MapMarker
## A trap on a cell. Invisible in game until detected (Rogue, Phase 6).

enum TrapType { SPIKES, DARTS, FIRE_JET, PIT, ALARM }

@export var trap_type := TrapType.SPIKES
@export var hidden := true
@export var detect_dc := 12          ## WIS (Perception) / INT (Investigation) to spot
@export var disarm_dc := 12          ## DEX (thieves' tools) to disarm
@export var save_ability := "DEX"
@export var save_dc := 12
@export var damage := "2d6"          ## dice expression
@export var damage_type := "piercing"
@export var one_shot := true


func _init() -> void:
	gizmo_color = Color(0.75, 0.45, 1.0)
	gizmo_label = "TRAP"
