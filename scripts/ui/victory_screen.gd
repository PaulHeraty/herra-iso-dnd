class_name VictoryScreen
extends CanvasLayer
## The win screen: shown when Brannoc has paid the reward for the Wraith (TraderTalk._reward ->
## DungeonMap.show_victory). The map darkens, "VICTORY" + a few lines of epilogue, the four heroes
## in their arms-raised cast pose (fallen heroes greyed), time played, monsters slain, gold and
## party XP, a fanfare, gold sparks drifting up. Keep exploring = back to the game (Brannoc still
## trades); Quit = close the game. The game is paused while it is up. F9 still loads (the save
## screen sits above it, layer 60).

const SCREEN := CombatHud.SCREEN
const EPILOGUE := "The Wraith is destroyed. The dead lie still beneath the Harrow Woods, the old silver mine falls quiet, and the miners can go home. Songs will be sung about you in every tavern from here to the coast."
## Hero figure scale and the gap between their 32x32 cells (screen px).
const HERO_SCALE := 3
const HERO_GAP := 104
## Cast "raise" column on the action sheet (Hero.ACTION_ANIMS.cast starts there).
const POSE_COL := 7
const SPARKS := 40

var map: DungeonMap
var _root: Control
var _dim: ColorRect
var _sparks: Control
var _spark_pos: Array[Vector2] = []
var _spark_speed: Array[float] = []
var _was_paused := false
var _keep: Button
var _hud_was_visible := true


func _ready() -> void:
	layer = 58                      # above the HUD, fades and arrival title; below the save screen (60)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.size = SCREEN
	_root.theme = CombatHud.make_theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	_dim.size = SCREEN
	_dim.color = Color(0.02, 0.01, 0.04, 0.93)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP           # the map can't be clicked under it
	_root.add_child(_dim)
	_sparks = Control.new()
	_sparks.size = SCREEN
	_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks.draw.connect(_draw_sparks)
	_root.add_child(_sparks)
	for i in SPARKS:
		_spark_pos.append(Vector2(randf() * SCREEN.x, randf() * SCREEN.y))
		_spark_speed.append(randf_range(6.0, 18.0))


func open() -> void:
	if visible:
		return
	if map and map.hud:
		map.hud.close_screens()
		map.hud.dialogue.close()
		_hud_was_visible = map.hud.visible
		map.hud.visible = false
	for c in _root.get_children():
		if c != _dim and c != _sparks:
			c.queue_free()
	_build()
	visible = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.8)
	Sfx.play("victory_fanfare")


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused
	if map and map.hud:
		map.hud.visible = _hud_was_visible


func _process(delta: float) -> void:
	if not visible:
		return
	for i in _spark_pos.size():
		var p := _spark_pos[i]
		p.y -= _spark_speed[i] * delta
		p.x += sin(p.y * 0.05 + i) * 4.0 * delta
		if p.y < -2.0:
			p = Vector2(randf() * SCREEN.x, SCREEN.y + 2.0)
		_spark_pos[i] = p
	_sparks.queue_redraw()


func _draw_sparks() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in _spark_pos.size():
		var p := _spark_pos[i].floor()
		var a := 0.35 + 0.35 * sin(t * 3.0 + i * 1.7)
		var col := Color8(255, 210, 80) if i % 3 else Color8(255, 250, 200)
		col.a = a
		_sparks.draw_rect(Rect2(p, Vector2.ONE), col)
		if i % 5 == 0:                       # a few bigger ones: a tiny plus
			col.a = a * 0.5
			_sparks.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), col)
			_sparks.draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), col)


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		close()
		get_viewport().set_input_as_handled()


# --- building -------------------------------------------------------------------------------

func _build() -> void:
	var title := _label(Vector2.ZERO, CombatHud.COL_BANNER)
	_centre(title, "VICTORY!", 18, 4)
	var ep := _label(Vector2(110, 62), CombatHud.COL_TEXT)
	ep.text = EPILOGUE
	ep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ep.size = Vector2(SCREEN.x - 220, 0)
	ep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_heroes(104)
	_build_stats(232)
	var thanks := _label(Vector2.ZERO, CombatHud.COL_GOLD)
	_centre(thanks, "Thanks for playing HerraDnD!", 284, 1)
	var by := _label(Vector2.ZERO, CombatHud.COL_DIM)
	_centre(by, "A Herrasoft game", 296, 1)
	_keep = _button("Keep exploring", Vector2(SCREEN.x / 2.0 - 104, 314), 98)
	_keep.pressed.connect(close)
	var quit := _button("Quit game", Vector2(SCREEN.x / 2.0 + 6, 314), 98)
	quit.pressed.connect(func(): get_tree().quit())
	var hint := _label(Vector2.ZERO, CombatHud.COL_DIM)
	_centre(hint, "Brannoc will still trade with you, and the woods are yours to wander.", 340, 1)


## The four heroes, arms raised, name + level under each. y = top of their cells.
func _build_heroes(y: float) -> void:
	var heroes: Array[Hero] = []
	if map:
		heroes = map.party
	var cell := 32 * HERO_SCALE
	var x0 := (SCREEN.x - (heroes.size() - 1) * HERO_GAP - cell) / 2.0
	for i in heroes.size():
		var h := heroes[i]
		var x := roundf(x0 + i * HERO_GAP)
		var pic := TextureRect.new()
		var at := AtlasTexture.new()
		if h.action_texture():
			at.atlas = h.action_texture()
			at.region = Rect2(POSE_COL * 32, 0, 32, 32)
		else:
			at.atlas = h.walk_texture()
			at.region = Rect2(-8, -8, 32, 32)
		pic.texture = at
		pic.position = Vector2(x, y)
		pic.size = Vector2(cell, cell)
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fallen := h.dead
		if fallen:
			pic.modulate = Color(0.4, 0.4, 0.45)
		_root.add_child(pic)
		var name_l := _label(Vector2.ZERO, CombatHud.COL_DIM if fallen else CombatHud.COL_TEXT)
		_centre(name_l, h.display_name(), y + cell + 2, 1, x + cell / 2.0)
		var lv := _label(Vector2.ZERO, CombatHud.COL_DIM if fallen else CombatHud.COL_XP.lightened(0.3))
		_centre(lv, "Fallen (Lv %d)" % h.level if fallen else "Level %d" % h.level, y + cell + 13, 1, x + cell / 2.0)


## Time played, monsters slain, gold, party XP: a 2x2 block centred at y.
func _build_stats(y: float) -> void:
	var kills := 0
	for n in Quest.kills.values():
		kills += int(n)
	var rows := [
		["Time played", time_text(PartyState.play_seconds)],
		["Monsters slain", str(kills)],
		["Gold", str(map.inventory.gold if map and map.inventory else 0)],
		["Party XP", str(map.party_xp if map else 0)],
	]
	for i in rows.size():
		var col := i % 2
		var row := i / 2
		var x := SCREEN.x / 2.0 - 150 + col * 160
		var k := _label(Vector2(x, y + row * 13), CombatHud.COL_DIM)
		k.text = rows[i][0]
		var v := _label(Vector2(x + 82, y + row * 13), CombatHud.COL_GOLD if rows[i][0] == "Gold" else CombatHud.COL_TEXT)
		v.text = rows[i][1]


## "2h 05m" / "14m 09s".
static func time_text(seconds: float) -> String:
	var s := int(seconds)
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s / 60) % 60]
	return "%dm %02ds" % [s / 60, s % 60]


func _label(pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


## Centre a label on x = cx (default: the screen) at height y, drawn at `k`x.
func _centre(l: Label, text: String, y: float, k: float, cx := SCREEN.x / 2.0) -> void:
	l.text = text
	l.scale = Vector2(k, k)
	var w := CombatHud.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x * k
	l.position = Vector2(roundf(cx - w / 2.0), y)


func _button(text: String, pos: Vector2, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.size = Vector2(w, 14)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(b)
	return b
