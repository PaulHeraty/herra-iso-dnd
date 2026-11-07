extends SceneTree
## Chiptune music -> assets/music/<name>.wav (32 kHz, 16-bit, mono, seamless loops).
## Run: Godot_console --headless --path . -s res://tools/godot/gen_music.gd [-- dungeon combat]   (then --import)
## A tiny tracker: each song = tempo + bars + channels. A channel is an instrument and a line of
## tokens, one per step: a note ("A4", "C#5", "Bb3"), "-" = hold the note, "." = rest. Drum lines use
## one letter per step: K kick, S snare, h hat, t low tom, "." rest. Chord-built parts (bass, arpeggio)
## come from the song's chord list. Note tails and echoes run past the end wrap round to the start,
## so the loop has no seam. Music.gd sets the loop when it plays the file.

const RATE := 32000
const OUT := "res://assets/music/"

## Instruments: wave (pulse / tri / noise), duty, ADSR in seconds (s = sustain level), vibrato.
const INST := {
	"lead": {"wave": "pulse", "duty": 0.25, "a": 0.008, "d": 0.25, "s": 0.55, "r": 0.12, "vib": 0.010, "vib_hz": 5.2, "vib_delay": 0.18},
	"lead_soft": {"wave": "pulse", "duty": 0.5, "a": 0.03, "d": 0.4, "s": 0.45, "r": 0.25, "vib": 0.008, "vib_hz": 4.6, "vib_delay": 0.25},
	"arp": {"wave": "pulse", "duty": 0.125, "a": 0.004, "d": 0.18, "s": 0.0, "r": 0.05},
	"bass_tri": {"wave": "tri", "a": 0.01, "d": 0.6, "s": 0.7, "r": 0.15},
	"bass_pulse": {"wave": "pulse", "duty": 0.5, "a": 0.004, "d": 0.12, "s": 0.5, "r": 0.03},
	"flute": {"wave": "tri", "a": 0.035, "d": 0.3, "s": 0.75, "r": 0.14, "vib": 0.012, "vib_hz": 5.0, "vib_delay": 0.15},
	"pluck": {"wave": "pulse", "duty": 0.25, "a": 0.002, "d": 0.22, "s": 0.0, "r": 0.05},
	"bell": {"wave": "tri", "a": 0.002, "d": 0.9, "s": 0.12, "r": 0.6},
	"pad": {"wave": "pulse", "duty": 0.5, "a": 0.35, "d": 0.5, "s": 0.6, "r": 0.6, "vib": 0.004, "vib_hz": 3.5, "vib_delay": 0.0},
}

const NOTE_INDEX := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
## Chord name -> semitones above the root (root letter + optional # / b, then "m" = minor).
const MAJOR := [0, 4, 7]
const MINOR := [0, 3, 7]


func _init() -> void:
	var all := {"dungeon": _song_dungeon, "combat": _song_combat, "woods": _song_woods,
			"frost": _song_frost, "tower": _song_tower, "boss": _song_boss, "title": _song_title}
	var only := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for nm: String in all:
		if only.is_empty() or nm in only:
			var song: Dictionary = (all[nm] as Callable).call()
			if not _check(nm, song):
				continue
			_save(nm, _render(song), song.get("peak", 0.8))
	quit()


## Every channel's line must be exactly `steps` tokens long (a bar with a token too many or too few
## would shift everything after it).
func _check(nm: String, song: Dictionary) -> bool:
	var ok := true
	for i in song.channels.size():
		var ch: Dictionary = song.channels[i]
		var n: int = (ch.drums if ch.has("drums") else ch.notes).split(" ", false).size()
		if n != song.steps:
			push_error("%s: channel %d has %d steps, not %d" % [nm, i, n, song.steps])
			ok = false
	return ok


# --- songs -----------------------------------------------------------------------------------------

## Exploring the dungeon: slow D minor, a triangle bass, a quiet 12.5% arpeggio that shimmers like
## dripping water, and a sparse lead with an echo down the halls. 76 BPM, 8th-note steps, 16 bars (~50 s).
func _song_dungeon() -> Dictionary:
	var chords := ["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A", "A",
			"Dm", "Dm", "F", "F", "C", "C", "A", "A"]
	var lead := [
		". . . . . . . .",
		". . . . A4 - D5 -",
		"F5 - - - E5 - D5 -",
		"D5 - - - - - . .",
		". . G4 - Bb4 - D5 -",
		"C5 - Bb4 - A4 - G4 -",
		"A4 - - - - - - -",
		"E5 - C#5 - A4 - - .",
		"D5 - - - - - . .",
		". . F5 - E5 - D5 -",
		"C5 - - - A4 - - -",
		"F4 - A4 - C5 - F5 -",
		"E5 - - - D5 - C5 -",
		"G4 - - - - - . .",
		"A4 - C#5 - E5 - G5 -",
		"F5 - - - E5 - - .",
	]
	# arpeggio: root, 5th, octave, 3rd above, octave, 5th... (8 steps a bar), octave 4
	var arp := []
	for c in chords:
		var r := _chord_root(c, 4)
		var iv := _chord_iv(c)
		for k in [0, iv[2], 12, iv[1] + 12, 12, iv[2], iv[1], iv[2]]:
			arp.append(_name(r + k))
	# bass: the root held for the bar, octave 2; the 5th on beat 3 in every second bar
	var bass := []
	for i in chords.size():
		var r := _chord_root(chords[i], 2)
		if i % 2 == 1:
			bass.append_array([_name(r), "-", "-", "-", _name(r + 7), "-", "-", "-"])
		else:
			bass.append_array([_name(r), "-", "-", "-", "-", "-", "-", "-"])
	# a low tom heartbeat every second bar, far away
	var drums := ""
	for i in chords.size():
		drums += "t . . t . . . . " if i % 2 == 0 else ". . . . . . . . "
	return {
		"bpm": 76.0, "steps_per_beat": 2, "steps": chords.size() * 8,
		"channels": [
			{"inst": "lead_soft", "notes": " ".join(lead), "vol": 0.30, "echo": [3, 0.38, 0.45]},
			{"inst": "arp", "notes": " ".join(arp), "vol": 0.10, "echo": [3, 0.3, 0.35]},
			{"inst": "bass_tri", "notes": " ".join(bass), "vol": 0.42},
			{"drums": drums, "vol": 0.22},
		],
		"peak": 0.75,
	}


## Combat: driving A minor at 144 BPM, 16th-note steps, 16 bars (~27 s). Pulse bass in 8ths with
## octave jumps, kick + snare + hats, a fast arpeggio and a 25% lead.
func _song_combat() -> Dictionary:
	var chords := ["Am", "Am", "F", "G", "Am", "Am", "F", "E",
			"Dm", "Dm", "Am", "Am", "F", "G", "E", "E"]
	var lead8 := [
		"A4 - C5 - E5 - A5 -",
		"G5 - E5 - C5 D5 E5 -",
		"F5 - - - E5 - D5 -",
		"D5 - B4 - G4 - B4 D5",
		"E5 - - A5 - - G5 -",
		"E5 - C5 - A4 - C5 E5",
		"F5 - E5 - D5 - C5 -",
		"B4 - G#4 - E4 - - -",
		"D5 - F5 - A5 - - -",
		"G5 F5 E5 - D5 - - -",
		"C5 - E5 - A5 - - -",
		"B5 A5 G5 - E5 - - -",
		"F5 - - - A5 - - -",
		"G5 - - - B5 - - -",
		"G#5 - - - E5 - - -",
		"B4 - - - G#4 - B4 -",
	]
	# 8th-note tokens -> 16th steps (each token is held for 2 steps)
	var lead := []
	for bar in lead8:
		for tok in bar.split(" "):
			lead.append(tok)
			lead.append("-" if tok != "." else ".")
	var arp := []
	var bass := []
	for c in chords:
		var r4 := _chord_root(c, 4)
		var iv := _chord_iv(c)
		for s in 16:
			arp.append(_name(r4 + [0, iv[1], iv[2], 12][s % 4]))
		var r2 := _chord_root(c, 2)
		for k in [0, 0, 12, 0, 0, 12, 7, 12]:
			bass.append_array([_name(r2 + k), "."])
	var drums := ""
	for i in chords.size():
		if i % 4 == 3:
			drums += "K . h . S . h K K . h . S S S S "    # a fill every 4th bar
		else:
			drums += "K . h . S . h . K . K h S . h h "
	return {
		"bpm": 144.0, "steps_per_beat": 4, "steps": chords.size() * 16,
		"channels": [
			{"inst": "lead", "notes": " ".join(lead), "vol": 0.26, "echo": [3, 0.22, 0.25]},
			{"inst": "arp", "notes": " ".join(arp), "vol": 0.07},
			{"inst": "bass_pulse", "notes": " ".join(bass), "vol": 0.22},
			{"drums": drums, "vol": 0.40},
		],
		"peak": 0.8,
	}


## The Harrow Woods: a folk tune in G, 96 BPM, 8th-note steps, 16 bars (~40 s). A triangle "flute"
## lead, a plucked 25% arpeggio, a bouncing root-5th triangle bass, soft hats on the off-beats.
func _song_woods() -> Dictionary:
	var chords := ["G", "G", "Em", "Em", "C", "D", "G", "G",
			"Em", "Em", "C", "C", "Am", "D", "G", "D"]
	var lead := [
		"D5 - B4 - D5 - G5 -",
		"F#5 - E5 - D5 - - -",
		"B4 - E5 - G5 - F#5 E5",
		"D5 - - - B4 - - -",
		"C5 - E5 - G5 - E5 -",
		"F#5 - E5 - D5 - A4 -",
		"B4 - - - G4 - A4 B4",
		"G4 - - - - - . .",
		". . E5 - F#5 - G5 -",
		"B5 - A5 - G5 - E5 -",
		"G5 - - - E5 - C5 -",
		"E5 - D5 - C5 - - -",
		"A4 - C5 - E5 - A5 -",
		"F#5 - - - E5 - D5 -",
		"D5 - B4 - G4 - B4 -",
		"A4 - - - D5 - - .",
	]
	var arp := []
	var bass := []
	for c in chords:
		var r := _chord_root(c, 4)
		var iv := _chord_iv(c)
		for k in [0, iv[2], 12, iv[1] + 12, iv[2] + 12, iv[1] + 12, 12, iv[2]]:
			arp.append(_name(r + k))
		var r2 := _chord_root(c, 2)
		bass.append_array([_name(r2), "-", _name(r2 + 7), "-", _name(r2 + 12), "-", _name(r2 + 7), "-"])
	var drums := ""
	for i in chords.size():
		drums += "t . h . . . h . " if i % 2 == 0 else ". . h . . . h h "
	return {
		"bpm": 96.0, "steps_per_beat": 2, "steps": chords.size() * 8,
		"channels": [
			{"inst": "flute", "notes": " ".join(lead), "vol": 0.46, "echo": [3, 0.25, 0.3]},
			{"inst": "pluck", "notes": " ".join(arp), "vol": 0.09, "echo": [3, 0.2, 0.25]},
			{"inst": "bass_tri", "notes": " ".join(bass), "vol": 0.40},
			{"drums": drums, "vol": 0.20},
		],
		"peak": 0.75,
	}


## The Frostfell: cold and wide open, B minor at 66 BPM, 8th-note steps, 16 bars (~58 s). Slow
## pulse pads (two voices), long triangle bass notes, a high bell melody with a long echo, and
## gusts of wind (filtered noise) every four bars.
func _song_frost() -> Dictionary:
	var chords := ["Bm", "Bm", "G", "G", "Em", "Em", "F#", "F#",
			"Bm", "Bm", "D", "D", "G", "Em", "F#", "F#"]
	var lead := [
		". . . . F#5 - - -",
		"B5 - - - A5 - F#5 -",
		"G5 - - - - - . .",
		". . D5 - E5 - F#5 -",
		"G5 - - - F#5 - E5 -",
		"B4 - - - - - . .",
		". . C#5 - E5 - F#5 -",
		"A#4 - - - C#5 - - -",
		"B4 - - - D5 - F#5 -",
		"B5 - - - - - A5 -",
		"F#5 - - - A5 - D6 -",
		"C#6 - - - A5 - - -",
		"B5 - - - G5 - D5 -",
		"E5 - - - G5 - B5 -",
		"A#5 - - - F#5 - C#5 -",
		"F#5 - - - - - . .",
	]
	var drums := ""
	for i in chords.size():
		drums += "w . . . . . . . " if i % 4 == 0 else ". . . . . . . . "
	return {
		"bpm": 66.0, "steps_per_beat": 2, "steps": chords.size() * 8,
		"channels": [
			{"inst": "bell", "notes": " ".join(lead), "vol": 0.40, "echo": [3, 0.45, 0.5]},
			{"inst": "pad", "notes": _held(chords, 4, 1, 8), "vol": 0.07},
			{"inst": "pad", "notes": _held(chords, 4, 2, 8), "vol": 0.06},
			{"inst": "bass_tri", "notes": _held(chords, 2, 0, 8), "vol": 0.40},
			{"drums": drums, "vol": 0.30},
		],
		"peak": 0.72,
	}


## The Rimecaller's tower: arcane clockwork, C minor at 88 BPM, 16th-note steps, 16 bars (~44 s).
## A ticking 16th arpeggio (the orrery), a soft lead in 8ths, a triangle bass and a clock of hats.
func _song_tower() -> Dictionary:
	var chords := ["Cm", "Cm", "Ab", "Ab", "Fm", "Fm", "G", "G",
			"Cm", "Cm", "Ab", "Bb", "Fm", "Db", "G", "G"]
	var lead8 := [
		"G4 - C5 - D5 - Eb5 -",
		"D5 - C5 - G4 - - -",
		"Ab4 - C5 - Eb5 - G5 -",
		"F5 - Eb5 - C5 - - -",
		"F4 - Ab4 - C5 - F5 -",
		"Eb5 - D5 - C5 - Ab4 -",
		"B4 - - - D5 - F5 -",
		"Eb5 - D5 - B4 - - -",
		"C5 - Eb5 - G5 - C6 -",
		"B5 - G5 - Eb5 - D5 -",
		"C5 - - - Eb5 - Ab5 -",
		"G5 - F5 - D5 - Bb4 -",
		"Ab5 - G5 - F5 - C5 -",
		"Db5 - F5 - Ab5 - F5 -",
		"G5 - F5 - D5 - B4 -",
		"D5 - - - B4 - - -",
	]
	var arp := []
	var bass := []
	for c in chords:
		var r := _chord_root(c, 4)
		var iv := _chord_iv(c)
		for rep in 2:
			for k in [0, iv[1], iv[2], 12, iv[1] + 12, 12, iv[2], iv[1]]:
				arp.append(_name(r + k))
		var r2 := _chord_root(c, 2)
		bass.append_array([_name(r2), "-", "-", "-", _name(r2 + 7), "-", "-", "-",
				_name(r2 + 12), "-", _name(r2 + 7), "-", _name(r2), "-", "-", "-"])
	var drums := ""
	for i in chords.size():
		drums += ("t" if i % 2 == 0 else "h") + " . . . h . . . h . . . h . . . "
	return {
		"bpm": 88.0, "steps_per_beat": 4, "steps": chords.size() * 16,
		"channels": [
			{"inst": "lead_soft", "notes": " ".join(_double(lead8)), "vol": 0.28, "echo": [6, 0.35, 0.4]},
			{"inst": "arp", "notes": " ".join(arp), "vol": 0.08, "echo": [3, 0.3, 0.3]},
			{"inst": "bass_tri", "notes": " ".join(bass), "vol": 0.40},
			{"drums": drums, "vol": 0.20},
		],
		"peak": 0.75,
	}


## Boss fights: D minor at 160 BPM, 16th-note steps, 16 bars (24 s). A 16th pedal bass, the lead
## doubled an octave down, a fast arpeggio, heavy drums with fills. Ends on A (the dominant) so the
## loop drives back into the top.
func _song_boss() -> Dictionary:
	var chords := ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Gm", "A",
			"Bb", "Bb", "Gm", "Gm", "Eb", "Eb", "A", "A"]
	var lead8 := [
		"D5 - - - A4 - D5 -",
		"F5 - E5 - D5 - A4 -",
		"Bb4 - D5 - F5 - - -",
		"E5 - - - C5 - E5 -",
		"A5 - - - F5 - D5 -",
		"A5 - Bb5 - A5 - F5 -",
		"G5 - - - D5 - Bb4 -",
		"C#5 - E5 - A5 - - -",
		"D6 - - - Bb5 - F5 -",
		"D6 C6 Bb5 - A5 - F5 -",
		"G5 - - - Bb5 - D6 -",
		"C6 Bb5 A5 - G5 - - -",
		"G5 - - - Eb5 - Bb4 -",
		"Eb5 - F5 - G5 - Bb5 -",
		"A5 - - - C#6 - - -",
		"E5 - G5 - C#5 - A4 -",
	]
	var lead := _double(lead8)
	var low := []
	for t: String in lead:
		low.append(t if t in ["-", "."] else _name(_midi(t) - 12))
	var arp := []
	var bass := []
	for c in chords:
		var r4 := _chord_root(c, 4)
		var iv := _chord_iv(c)
		for s in 16:
			arp.append(_name(r4 + [0, iv[1], iv[2], 12, iv[2], iv[1]][s % 6]))
		var r2 := _chord_root(c, 2)
		for k in [0, 0, 12, 0, 0, 0, 12, 0, 0, 0, 12, 0, 7, 0, 12, 10]:
			bass.append(_name(r2 + k))
	var drums := ""
	for i in chords.size():
		if i % 4 == 3:
			drums += "K . S . K S . S K S S S S S S S "
		else:
			drums += "K . h K S . h . K K h . S . h h "
	return {
		"bpm": 160.0, "steps_per_beat": 4, "steps": chords.size() * 16,
		"channels": [
			{"inst": "lead", "notes": " ".join(lead), "vol": 0.24, "echo": [3, 0.2, 0.22]},
			{"inst": "lead_soft", "notes": " ".join(low), "vol": 0.12},
			{"inst": "arp", "notes": " ".join(arp), "vol": 0.06},
			{"inst": "bass_pulse", "notes": " ".join(bass), "vol": 0.22},
			{"drums": drums, "vol": 0.42},
		],
		"peak": 0.82,
	}


## The start screen: a heroic march in C, 100 BPM, 8th-note steps, 16 bars (~38 s). A 25% lead with
## an echo, pads, a triangle bass on the beats, a soft march of kick, snare and hats.
func _song_title() -> Dictionary:
	var chords := ["C", "C", "Am", "Am", "F", "G", "C", "C",
			"F", "F", "Dm", "G", "Am", "F", "G", "G"]
	var lead := [
		"C5 - - - G4 - C5 -",
		"E5 - - - D5 C5 D5 -",
		"E5 - - - A4 - C5 -",
		"E5 - - - - - . .",
		"F5 - - - E5 - D5 -",
		"D5 - - - B4 - G4 -",
		"C5 - E5 - G5 - - -",
		"G5 - - - - - . .",
		"A5 - - - G5 - F5 -",
		"C5 - - - F5 - A5 -",
		"A5 - - - F5 - D5 -",
		"G5 - F5 - E5 - D5 -",
		"E5 - - - C5 - A4 -",
		"F5 - - - A5 - C6 -",
		"B5 - - - G5 - D5 -",
		"D5 - - - B4 - - -",
	]
	var bass := []
	for c in chords:
		var r2 := _chord_root(c, 2)
		bass.append_array([_name(r2), "-", _name(r2 + 12), "-", _name(r2 + 7), "-", _name(r2 + 12), "-"])
	var drums := ""
	for i in chords.size():
		drums += "K . h . S . h . " if i % 4 != 3 else "K . h . S . S S "
	return {
		"bpm": 100.0, "steps_per_beat": 2, "steps": chords.size() * 8,
		"channels": [
			{"inst": "lead", "notes": " ".join(lead), "vol": 0.26, "echo": [3, 0.3, 0.32]},
			{"inst": "pad", "notes": _held(chords, 4, 1, 8), "vol": 0.06},
			{"inst": "pad", "notes": _held(chords, 4, 2, 8), "vol": 0.05},
			{"inst": "bass_tri", "notes": " ".join(bass), "vol": 0.40},
			{"drums": drums, "vol": 0.22},
		],
		"peak": 0.75,
	}


## 8th-note bars -> 16th steps (each token held for 2 steps).
func _double(bars: Array) -> Array:
	var out := []
	for bar: String in bars:
		for tok in bar.split(" ", false):
			out.append(tok)
			out.append("-" if tok != "." else ".")
	return out


## One chord tone (0 root, 1 third, 2 fifth) held through each bar, tied over repeated chords.
func _held(chords: Array, octave: int, tone: int, per_bar: int) -> String:
	var out := []
	for i in chords.size():
		var tie: bool = i > 0 and chords[i] == chords[i - 1]
		out.append("-" if tie else _name(_chord_root(chords[i], octave) + _chord_iv(chords[i])[tone]))
		for s in per_bar - 1:
			out.append("-")
	return " ".join(out)


# --- notes -----------------------------------------------------------------------------------------

## MIDI number of a note name ("C#5" -> 73).
func _midi(nm: String) -> int:
	var i: int = NOTE_INDEX[nm[0]]
	var rest := nm.substr(1)
	if rest.begins_with("#"):
		i += 1
		rest = rest.substr(1)
	elif rest.begins_with("b"):
		i -= 1
		rest = rest.substr(1)
	return i + (int(rest) + 1) * 12


func _name(midi: int) -> String:
	const N := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	return "%s%d" % [N[midi % 12], midi / 12 - 1]


func _freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


func _chord_root(chord: String, octave: int) -> int:
	var nm := chord.trim_suffix("m")
	return _midi(nm + str(octave))


func _chord_iv(chord: String) -> Array:
	return MINOR if chord.ends_with("m") else MAJOR


# --- rendering -------------------------------------------------------------------------------------

func _render(song: Dictionary) -> PackedFloat32Array:
	var step_s: float = 60.0 / float(song.bpm) / float(song.steps_per_beat)
	var total := int(round(float(song.steps) * step_s * RATE))
	var out := PackedFloat32Array()
	out.resize(total)
	for ch: Dictionary in song.channels:
		var buf := PackedFloat32Array()
		buf.resize(total)
		if ch.has("drums"):
			var toks: PackedStringArray = ch.drums.split(" ", false)
			for s in toks.size():
				if toks[s] != ".":
					_drum(buf, toks[s], int(round(s * step_s * RATE)))
		else:
			var inst: Dictionary = INST[ch.inst]
			for nt in _parse(ch.notes):
				_note(buf, inst, _freq(nt[0]), int(round(nt[1] * step_s * RATE)), nt[2] * step_s)
		if ch.has("echo"):
			buf = _echo(buf, int(round(ch.echo[0] * step_s * RATE)), ch.echo[1], ch.echo[2])
		for i in total:
			out[i] += buf[i] * ch.vol
	# no DC (pulse waves carry some), gentle low-pass to soften the edges
	var mean := 0.0
	for v in out:
		mean += v
	mean /= total
	var s := 0.0
	var k := 1.0 - exp(-TAU * 9000.0 / RATE)
	for rnd in 2:                       # 2 passes: the filter state wraps round the loop too
		for i in total:
			s += k * (out[i] - mean - s)
			if rnd == 1:
				out[i] = s
	return out


## Tokens -> [midi, start step, length in steps].
func _parse(line: String) -> Array:
	var notes := []
	var toks := line.split(" ", false)
	for s in toks.size():
		var t := toks[s]
		if t == "-":
			if not notes.is_empty() and notes[-1][1] + notes[-1][2] == s:
				notes[-1][2] += 1
		elif t != ".":
			notes.append([_midi(t), s, 1])
	return notes


## One note added into buf at `at` (wrapping), held `held` seconds, then released.
func _note(buf: PackedFloat32Array, inst: Dictionary, f: float, at: int, held: float) -> void:
	var a: float = inst.a
	var d: float = inst.d
	var sus: float = inst.s
	var r: float = inst.r
	var n := int((held + r) * RATE)
	var total := buf.size()
	var phase := 0.0
	var vib: float = inst.get("vib", 0.0)
	var vib_hz: float = inst.get("vib_hz", 5.0)
	var vib_delay: float = inst.get("vib_delay", 0.2)
	var duty: float = inst.get("duty", 0.5)
	var rel_from := 0.0
	for i in n:
		var t := float(i) / RATE
		# ADSR
		var e: float
		if t < held:
			if t < a:
				e = t / a
			else:
				e = lerpf(1.0, sus, minf(1.0, (t - a) / d)) if d > 0.0 else sus
			rel_from = e
		else:
			e = rel_from * (1.0 - (t - held) / r)
		var ff := f
		if vib > 0.0 and t > vib_delay:
			ff *= 1.0 + vib * sin(TAU * vib_hz * (t - vib_delay)) * minf(1.0, (t - vib_delay) / 0.3)
		var dt := ff / RATE
		phase = fmod(phase + dt, 1.0)
		var v := 0.0
		match inst.wave:
			"pulse":
				v = (1.0 if phase < duty else -1.0) + _blep(phase, dt) - _blep(fmod(phase + 1.0 - duty, 1.0), dt)
			"tri":
				v = 4.0 * absf(phase - 0.5) - 1.0
		buf[(at + i) % total] += v * e


## PolyBLEP: smooths the pulse's jumps so high notes don't alias.
func _blep(t: float, dt: float) -> float:
	if t < dt:
		t /= dt
		return t + t - t * t - 1.0
	if t > 1.0 - dt:
		t = (t - 1.0) / dt
		return t * t + t + t + 1.0
	return 0.0


var _rng := RandomNumberGenerator.new()


func _drum(buf: PackedFloat32Array, kind: String, at: int) -> void:
	var total := buf.size()
	match kind:
		"K":                                    # kick: a sine diving 160 -> 45 Hz
			var n := int(0.18 * RATE)
			var ph := 0.0
			for i in n:
				var t := float(i) / n
				ph += lerpf(160.0, 45.0, sqrt(t)) / RATE
				buf[(at + i) % total] += sin(TAU * ph) * pow(1.0 - t, 2.2) * 1.1
		"t":                                    # soft low tom (the dungeon's heartbeat)
			var n := int(0.28 * RATE)
			var ph := 0.0
			for i in n:
				var t := float(i) / n
				ph += lerpf(95.0, 60.0, t) / RATE
				buf[(at + i) % total] += sin(TAU * ph) * pow(1.0 - t, 2.5) * minf(1.0, i / 200.0)
		"S":                                    # snare: noise burst + a 190 Hz knock
			var n := int(0.14 * RATE)
			var lp := 0.0
			for i in n:
				var t := float(i) / n
				var w := _rng.randf_range(-1.0, 1.0)
				lp += 0.35 * (w - lp)
				var tone := sin(TAU * 190.0 * i / RATE) * pow(1.0 - t, 6.0) * 0.5
				buf[(at + i) % total] += ((w - lp) * 0.9 + tone) * pow(1.0 - t, 3.0)
		"w":                                    # a gust of wind: noise through a sweeping resonant band-pass
			var n := int(4.0 * RATE)
			var low := 0.0
			var band := 0.0
			for i in n:
				var t := float(i) / n
				var fc := 450.0 + 900.0 * sin(PI * t) + 250.0 * sin(TAU * 3.0 * t)
				var f := 2.0 * sin(PI * fc / RATE)
				var w := _rng.randf_range(-1.0, 1.0)
				low += f * band
				var high := w - low - 0.35 * band
				band += f * high
				buf[(at + i) % total] += band * 0.25 * pow(sin(PI * t), 2.0)
		"h":                                    # closed hat: bright noise, very short
			var n := int(0.035 * RATE)
			var prev := 0.0
			for i in n:
				var t := float(i) / n
				var w := _rng.randf_range(-1.0, 1.0)
				buf[(at + i) % total] += (w - prev) * 0.3 * pow(1.0 - t, 2.0)
				prev = w


## Feedback echo round the loop: delay in samples, feedback, wet level. Several passes, so the
## echoes that spill past the end come back in at the start.
func _echo(x: PackedFloat32Array, delay: int, fb: float, wet: float) -> PackedFloat32Array:
	var total := x.size()
	var line := PackedFloat32Array()
	line.resize(total)
	for rnd in 3:
		for i in total:
			line[i] = x[i] + fb * line[(i - delay + total) % total]
	var y := PackedFloat32Array()
	y.resize(total)
	for i in total:
		y[i] = x[i] + wet * (line[(i - delay + total) % total])
	return y


# --- output ----------------------------------------------------------------------------------------

func _save(name: String, x: PackedFloat32Array, peak: float) -> void:
	var m := 0.0001
	var sq := 0.0
	for v in x:
		m = maxf(m, absf(v))
	for v in x:
		sq += (v / m * peak) * (v / m * peak)
	var data := PackedByteArray()
	data.resize(x.size() * 2)
	for i in x.size():
		data.encode_s16(i * 2, clampi(int(x[i] / m * peak * 32767.0), -32768, 32767))
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT + name + ".wav"), FileAccess.WRITE)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)            # PCM
	f.store_16(1)            # mono
	f.store_32(RATE)
	f.store_32(RATE * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()
	var rms := sqrt(sq / x.size())
	print("wrote %s%s.wav  %.1fs  peak %.2f  rms %.1f dBFS" % [OUT, name, x.size() / float(RATE), peak, linear_to_db(rms)])
