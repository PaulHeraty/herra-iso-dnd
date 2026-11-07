class_name Music
extends Node
## Background music: one looping track at a time (assets/music/<name>.wav, tools/godot/gen_music.gd),
## crossfaded, on the "Music" bus (its volume: the pause menu).
##   Music.play("dungeon")    Music.play("combat", 0.6)    Music.stop(2.0)
## Asking for the track already playing does nothing (so it carries on over the stairs). A track
## faded out remembers where it was and picks up there next time (back from a fight, the dungeon
## tune goes on). A missing track tries FALLBACK, else plays silence. Static and self-creating like Sfx;
## keeps playing while the game is paused and while a help box freezes time.

const DIR := "res://assets/music/"
const BUS := "Music"
const FADE := 1.5
## Track level trims in dB (music sits under the effects).
## Matched by RMS (gen_music.gd prints it): each track lands near -26 dBFS before the Music bus.
const TRIM := {"dungeon": -9.0, "combat": -10.0, "woods": -10.5, "frost": -9.0, "tower": -11.0,
		"boss": -10.0, "title": -10.5}
const FALLBACK := {"tower": "dungeon", "boss": "combat"}
## Monsters whose fight plays "boss".
const BOSSES: Array[String] = ["eye_tyrant", "wraith", "young_white_dragon", "frost_wizard"]

static var _inst: Music

var current := ""                     ## the track asked for ("" = none)
var _player: AudioStreamPlayer        ## the one playing current
var _resume := {}                     ## track -> playback position when it was faded out
var _tweens := {}                     ## player -> its running fade (here, not on the player: no ref cycle)


static func play(track: String, fade := FADE) -> void:
	_instance()._play(track, fade)


static func stop(fade := FADE) -> void:
	_instance()._play("", fade)


static func playing() -> String:
	return _inst.current if is_instance_valid(_inst) else ""


## The track that exists for `track` (itself or its fallback), or "".
static func resolve(track: String) -> String:
	var seen := 0
	while track != "" and seen < 4:
		if ResourceLoader.exists(DIR + track + ".wav"):
			return track
		track = FALLBACK.get(track, "")
		seen += 1
	return ""


static func _instance() -> Music:
	if not is_instance_valid(_inst):
		_inst = Music.new()
		_inst.name = "Music"
		_inst.process_mode = Node.PROCESS_MODE_ALWAYS
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			tree.root.add_child.call_deferred(_inst)    # maps ask from _ready: the root is busy then
	return _inst


func _ready() -> void:
	Settings.load_settings()
	Settings.bus_index(BUS)


func _play(track: String, fade: float) -> void:
	if not is_inside_tree():
		_play.call_deferred(track, fade)       # runs after the deferred add_child, in order
		return
	var res := resolve(track)
	if res == current and (res == "" or (_player and _player.playing)):
		return
	current = res
	var old := _player
	_player = null
	if old:
		_resume[old.get_meta("track")] = old.get_playback_position()
		_fade(old, 0.0, fade, true)
	if res == "":
		return
	var stream := load(DIR + res + ".wav") as AudioStreamWAV
	if stream == null:
		return
	if stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
	var p := AudioStreamPlayer.new()
	p.bus = BUS
	p.stream = stream
	p.set_meta("track", res)
	p.set_meta("level", 0.0)
	add_child(p)
	_player = p
	_set_level(0.0, p)
	var at: float = _resume.get(res, 0.0)
	_resume.erase(res)
	p.play(fmod(at, maxf(stream.get_length(), 0.01)))
	_fade(p, 1.0, fade, false)


func _fade(p: AudioStreamPlayer, to: float, secs: float, free_after: bool) -> void:
	var old: Tween = _tweens.get(p)
	if old and old.is_valid():
		old.kill()
	_tweens.erase(p)
	if secs <= 0.0:
		_set_level(to, p)
		if free_after:
			p.queue_free()
		return
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_method(_set_level.bind(p), float(p.get_meta("level")), to, secs)
	t.tween_callback(func():
		_tweens.erase(p)
		if free_after:
			p.queue_free())
	_tweens[p] = t


func _exit_tree() -> void:
	for t: Tween in _tweens.values():
		if t.is_valid():
			t.kill()
	_tweens.clear()


## Level 0..1 as amplitude, so the crossfade sounds even.
func _set_level(v: float, p: AudioStreamPlayer) -> void:
	if not is_instance_valid(p):
		return
	p.set_meta("level", v)
	p.volume_db = (linear_to_db(v) if v > 0.0001 else -80.0) + TRIM.get(p.get_meta("track"), -9.0)
