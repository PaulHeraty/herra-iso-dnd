class_name Sfx
extends Node
## Play a sound effect by name (assets/sfx/<name>.wav). Several can overlap.
##   Sfx.play("hit_slash")            Sfx.play("ray_zap", -2.0)  (extra dB)
## Static: the player node creates itself under the scene root on first use (works in the game,
## in the editor's play mode and in headless test scripts, which don't load autoloads).

const DIR := "res://assets/sfx/"
const VOICES := 8
## Per-sound level trim in dB (balances the generated sounds; tune by ear).
const TRIM := {
	"ray_zap": -5.0,
	"hero_hurt": -3.0,
	"bow_shot": -2.0,
	"miss_swish": -3.0,
	"turn_chime": -6.0,
	"ui_select": -6.0,
	"mm_zip": -8.0,
	"fire_impact": 3.0,
	"radiant": -2.0,
	"heal_chime": -3.0,
	"fireball_boom": 3.0,
}

static var _inst: Sfx

var _players: Array[AudioStreamPlayer] = []
var _cache := {}
var _next := 0


static func play(sound: String, db := 0.0, pitch := 1.0) -> void:
	if sound == "":
		return
	if not is_instance_valid(_inst):
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return
		_inst = Sfx.new()
		_inst.name = "Sfx"
		_inst.process_mode = Node.PROCESS_MODE_ALWAYS     # menus that pause the game still click
		tree.root.add_child(_inst)
	_inst._play(sound, db, pitch)


func _init() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func _play(sound: String, db: float, pitch: float) -> void:
	var stream: AudioStream = _cache.get(sound)
	if stream == null:
		var path := DIR + sound + ".wav"
		if not ResourceLoader.exists(path):
			push_warning("Sfx: no sound '%s'" % sound)
			return
		stream = load(path)
		_cache[sound] = stream
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.volume_db = db + TRIM.get(sound, 0.0)
	p.pitch_scale = pitch
	p.play()
