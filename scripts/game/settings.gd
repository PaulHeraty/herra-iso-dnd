class_name Settings
extends RefCounted
## Player settings kept in user://settings.cfg (the file HelpBox also uses; each keeps its own
## section): [display] fullscreen (default on), [game] dice_mode (CombatManager.DiceMode).
## Test runs (a -s script, HERRA_AUTO_REACT set, or headless) never read or write the file and
## never change the window (tools/run_godot.sh starts them --windowed).

const FILE := "user://settings.cfg"

static var fullscreen := true
static var dice_mode := 1                 ## CombatManager.DiceMode.BIG
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
		return
	var cf := ConfigFile.new()
	if cf.load(FILE) == OK:
		fullscreen = bool(cf.get_value("display", "fullscreen", true))
		dice_mode = int(cf.get_value("game", "dice_mode", dice_mode))


static func save_settings() -> void:
	if not _persist:
		return
	var cf := ConfigFile.new()
	cf.load(FILE)                         # keep the other sections (help)
	cf.set_value("display", "fullscreen", fullscreen)
	cf.set_value("game", "dice_mode", dice_mode)
	cf.save(FILE)


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
