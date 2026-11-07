class_name Settings
extends RefCounted
## Player settings kept in user://settings.cfg (the file HelpBox also uses; each keeps its own
## section): [display] fullscreen (default on), [game] dice_mode (CombatManager.DiceMode),
## [audio] one volume step (0-10) per bus.
## Test runs (a -s script, HERRA_AUTO_REACT set, or headless) never read or write the file and
## never change the window (tools/run_godot.sh starts them --windowed).

const FILE := "user://settings.cfg"

## Audio buses (default_bus_layout.tres: SFX, Music and Ambience all send to Master).
## Sfx plays on "SFX"; music and looping ambience will use their own buses.
const BUSES: Array[String] = ["Master", "SFX", "Music", "Ambience"]
const VOL_STEPS := 10
const VOL_DEFAULT := {"Master": 10, "SFX": 10, "Music": 8, "Ambience": 10}

static var fullscreen := true
static var dice_mode := 1                 ## CombatManager.DiceMode.BIG
static var volumes := VOL_DEFAULT.duplicate()    ## bus name -> step 0..VOL_STEPS (0 = muted)
static var _loaded := false
static var _persist := true


static func scripted() -> bool:
	var args := OS.get_cmdline_args()
	return "-s" in args or "--script" in args or OS.get_environment("HERRA_AUTO_REACT") != "" \
			or DisplayServer.get_name() == "headless"


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	if scripted():
		_persist = false
		apply_volumes()
		return
	var cf := ConfigFile.new()
	if cf.load(FILE) == OK:
		fullscreen = bool(cf.get_value("display", "fullscreen", true))
		dice_mode = int(cf.get_value("game", "dice_mode", dice_mode))
		for bus in BUSES:
			volumes[bus] = clampi(int(cf.get_value("audio", bus.to_lower(), volumes[bus])), 0, VOL_STEPS)
	apply_volumes()


static func save_settings() -> void:
	if not _persist:
		return
	var cf := ConfigFile.new()
	cf.load(FILE)                         # keep the other sections (help)
	cf.set_value("display", "fullscreen", fullscreen)
	cf.set_value("game", "dice_mode", dice_mode)
	for bus in BUSES:
		cf.set_value("audio", bus.to_lower(), volumes[bus])
	cf.save(FILE)


# --- audio ---------------------------------------------------------------------------------------

## The bus's index, adding it (sending to Master) if the layout file didn't have it.
static func bus_index(bus: String) -> int:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus)
		AudioServer.set_bus_send(i, "Master")
	return i


## Step -> dB on a squared curve (sounds more even than linear): 10 = 0 dB, 5 = -12 dB, 1 = -40 dB.
static func step_db(step: int) -> float:
	var f := clampf(float(step) / VOL_STEPS, 0.0, 1.0)
	return linear_to_db(f * f) if f > 0.0 else -80.0


static func apply_volumes() -> void:
	for bus in BUSES:
		var i := bus_index(bus)
		var step: int = volumes[bus]
		AudioServer.set_bus_volume_db(i, step_db(step))
		AudioServer.set_bus_mute(i, step <= 0)


static func get_volume(bus: String) -> int:
	load_settings()
	return volumes.get(bus, VOL_STEPS)


static func set_volume(bus: String, step: int) -> void:
	load_settings()
	volumes[bus] = clampi(step, 0, VOL_STEPS)
	apply_volumes()
	save_settings()


## Put the window in the saved mode (start screen + every map call it; cheap when nothing changes).
static func apply() -> void:
	load_settings()
	if not _persist:
		return
	_apply_window()


static func _apply_window() -> void:
	var fs := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if fs == fullscreen:
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var sz := Vector2i(1280, 720)
		DisplayServer.window_set_size(sz)
		var scr := DisplayServer.window_get_current_screen()
		var area := DisplayServer.screen_get_usable_rect(scr)
		DisplayServer.window_set_position(area.position + (area.size - sz) / 2)


static func set_fullscreen(on: bool) -> void:
	load_settings()
	fullscreen = on
	save_settings()
	if _persist:
		_apply_window()


static func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)


static func set_dice_mode(mode: int) -> void:
	load_settings()
	dice_mode = mode
	save_settings()


## F11 or Alt+Enter: switch fullscreen / window (start screen + maps).
static func is_fullscreen_key(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	return event.keycode == KEY_F11 or (event.keycode in [KEY_ENTER, KEY_KP_ENTER] and event.alt_pressed)
