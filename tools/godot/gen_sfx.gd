extends SceneTree
## Retro synthesized combat sound effects -> assets/sfx/<name>.wav (44.1 kHz, 16-bit, mono).
## Run: Godot_console --headless --path . -s res://tools/godot/gen_sfx.gd   (then --import)
## Same ingredients as tools/python/make_sfx.py (concept session): filtered noise, square waves,
## pitch sweeps, exponential envelopes. Doesn't touch the concept-session WAVs.

const RATE := 44100
const OUT := "res://assets/sfx/"

var _seed := 1


func _init() -> void:
	# Pass sound names after -- to make only those (e.g. -- level_up): the rest stay as they are.
	var all := {
		"hit_slash": _hit_slash,
		"hit_blunt": _hit_blunt,
		"hit_pierce": _hit_pierce,
		"miss_swish": _miss_swish,
		"bow_shot": _bow_shot,
		"hero_hurt": _hero_hurt,
		"spider_hiss": _spider_hiss,
		"ray_zap": _ray_zap,
		"crit_hit": _crit_hit,
		"mm_zip": _mm_zip,
		"radiant": _radiant,
		"heal_chime": _heal_chime,
		"fire_impact": _fire_impact,
		"fireball_boom": _fireball_boom,
		"door_open": _door_open,
		"door_locked": _door_locked,
		"lock_click": _lock_click,
		"stairs": _stairs,
		"bone_rattle": _bone_rattle,
		"bone_collapse": _bone_collapse,
		"chest_open": _chest_open,
		"coins": _coins,
		"potion_drink": _potion_drink,
		"scroll_read": _scroll_read,
		"lightning_crack": _lightning_crack,
		"level_up": _level_up,
		"portal_open": _portal_open,
		"portal_travel": _portal_travel,
		"quest_update": _quest_update,
		"logo_chime": _logo_chime,
		"victory_fanfare": _victory_fanfare,
		# Phase 6: traps, mechanisms, puzzles
		"trap_spikes": _trap_spikes,
		"trap_darts": _trap_darts,
		"trap_fire": _trap_fire,
		"trap_pit": _trap_pit,
		"trap_alarm": _trap_alarm,
		"lever": _lever,
		"plate_click": _plate_click,
		"gate_rise": _gate_rise,
		"stone_slide": _stone_slide,
		"stone_push": _stone_push,
		"puzzle_solved": _puzzle_solved,
		"puzzle_fail": _puzzle_fail,
		"discover": _discover,
		"search": _search,
		"flame_whoosh": _flame_whoosh,
	}
	var only := OS.get_cmdline_user_args()
	for nm: String in all:
		if only.is_empty() or nm in only:
			_save(nm, (all[nm] as Callable).call())
	quit()


# --- building blocks --------------------------------------------------------------------------

func _n(dur: float) -> int:
	return int(dur * RATE)


func _noise(n: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	_seed += 1
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		x[i] = rng.randf_range(-1.0, 1.0)
	return x


## Exponential-ish decay envelope with a short attack.
func _env(n: int, attack := 0.005, curve := 3.0) -> PackedFloat32Array:
	var e := PackedFloat32Array()
	e.resize(n)
	var a := maxi(1, _n(attack))
	for i in n:
		var t := float(i) / n
		e[i] = (minf(1.0, float(i) / a)) * pow(1.0 - t, curve)
	return e


## One-pole low-pass (cutoff Hz, may sweep from c0 to c1).
func _lowpass(x: PackedFloat32Array, c0: float, c1 := -1.0) -> PackedFloat32Array:
	if c1 < 0.0:
		c1 = c0
	var y := PackedFloat32Array()
	y.resize(x.size())
	var s := 0.0
	for i in x.size():
		var c := lerpf(c0, c1, float(i) / x.size())
		var k := 1.0 - exp(-TAU * c / RATE)
		s += k * (x[i] - s)
		y[i] = s
	return y


func _highpass(x: PackedFloat32Array, c: float) -> PackedFloat32Array:
	var lp := _lowpass(x, c)
	var y := PackedFloat32Array()
	y.resize(x.size())
	for i in x.size():
		y[i] = x[i] - lp[i]
	return y


## Square wave sweeping f0 -> f1 (exponential), optional vibrato.
func _square(n: int, f0: float, f1: float, duty := 0.5, vib_hz := 0.0, vib_amt := 0.0) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var f := f0 * pow(f1 / f0, t)
		if vib_hz > 0.0:
			f *= 1.0 + vib_amt * sin(TAU * vib_hz * i / RATE)
		ph = fmod(ph + f / RATE, 1.0)
		y[i] = 1.0 if ph < duty else -1.0
	return y


func _sine(n: int, f0: float, f1: float) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(n)
	var ph := 0.0
	for i in n:
		var f := f0 * pow(f1 / f0, float(i) / n)
		ph += TAU * f / RATE
		y[i] = sin(ph)
	return y


func _mul(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(mini(a.size(), b.size()))
	for i in y.size():
		y[i] = a[i] * b[i]
	return y


## Mix b into a (at sample offset), scaled.
func _mix(a: PackedFloat32Array, b: PackedFloat32Array, gain := 1.0, offset := 0) -> PackedFloat32Array:
	var y := a.duplicate()
	if y.size() < offset + b.size():
		y.resize(offset + b.size())
	for i in b.size():
		y[offset + i] += b[i] * gain
	return y


# --- sounds -----------------------------------------------------------------------------------

func _hit_slash() -> PackedFloat32Array:
	var n := _n(0.28)
	var swish := _mul(_highpass(_noise(n), 1800.0), _env(n, 0.002, 4.0))
	var ring := _mul(_square(_n(0.22), 1250.0, 900.0, 0.3), _env(_n(0.22), 0.001, 5.0))
	var thud := _mul(_lowpass(_noise(_n(0.12)), 600.0), _env(_n(0.12), 0.001, 3.0))
	return _mix(_mix(swish, ring, 0.25, _n(0.01)), thud, 0.8, _n(0.012))


func _hit_blunt() -> PackedFloat32Array:
	var n := _n(0.25)
	var boom := _mul(_sine(n, 160.0, 55.0), _env(n, 0.002, 3.0))
	var crack := _mul(_lowpass(_noise(_n(0.08)), 1400.0), _env(_n(0.08), 0.001, 4.0))
	return _mix(boom, crack, 0.9)


func _hit_pierce() -> PackedFloat32Array:
	var n := _n(0.16)
	var thock := _mul(_lowpass(_noise(n), 2400.0, 500.0), _env(n, 0.001, 5.0))
	var tick := _mul(_square(_n(0.05), 900.0, 600.0, 0.25), _env(_n(0.05), 0.001, 4.0))
	return _mix(thock, tick, 0.3)


func _miss_swish() -> PackedFloat32Array:
	var n := _n(0.22)
	var e := PackedFloat32Array()
	e.resize(n)
	for i in n:
		var t := float(i) / n
		e[i] = sin(PI * t) * sin(PI * t)          # swell in and out
	return _mul(_lowpass(_highpass(_noise(n), 500.0), 1200.0, 4000.0), e)


func _bow_shot() -> PackedFloat32Array:
	var tw := _n(0.18)
	var twang := _mul(_square(tw, 260.0, 190.0, 0.4), _env(tw, 0.001, 4.0))
	twang = _lowpass(twang, 2000.0)
	var wn := _n(0.25)
	var e := PackedFloat32Array()
	e.resize(wn)
	for i in wn:
		var t := float(i) / wn
		e[i] = pow(sin(PI * t), 2) * 0.6
	var whoosh := _mul(_lowpass(_highpass(_noise(wn), 800.0), 3000.0, 1500.0), e)
	return _mix(twang, whoosh, 0.7, _n(0.03))


func _hero_hurt() -> PackedFloat32Array:
	var n := _n(0.26)
	var grunt := _mul(_lowpass(_square(n, 320.0, 140.0, 0.35, 28.0, 0.04), 1600.0), _env(n, 0.004, 2.5))
	var hit := _mul(_lowpass(_noise(_n(0.07)), 900.0), _env(_n(0.07), 0.001, 3.0))
	return _mix(grunt, hit, 0.7)


func _spider_hiss() -> PackedFloat32Array:
	var n := _n(0.45)
	var e := PackedFloat32Array()
	e.resize(n)
	for i in n:
		var t := float(i) / n
		e[i] = minf(1.0, t * 12.0) * pow(1.0 - t, 1.5)
	var hiss := _mul(_highpass(_lowpass(_noise(n), 7000.0), 2500.0), e)
	var click := _mul(_square(_n(0.04), 700.0, 500.0, 0.2), _env(_n(0.04), 0.001, 3.0))
	return _mix(_mix(hiss, click, 0.25), click, 0.2, _n(0.06))


func _ray_zap() -> PackedFloat32Array:
	var n := _n(0.42)
	var zap := _mul(_square(n, 1600.0, 260.0, 0.5, 45.0, 0.08), _env(n, 0.003, 1.6))
	var buzz := _mul(_lowpass(_noise(n), 3000.0), _env(n, 0.003, 2.0))
	return _mix(_lowpass(zap, 5000.0), buzz, 0.25)


func _crit_hit() -> PackedFloat32Array:
	var base := _hit_slash()
	var n := _n(0.35)
	var shine := _mul(_square(n, 1046.5, 1568.0, 0.25), _env(n, 0.002, 2.5))
	return _mix(base, _lowpass(shine, 6000.0), 0.22, _n(0.03))




# --- spell sounds (Phase 3 step 3) ------------------------------------------------------------

## Magic Missile dart: quick rising zip with a glassy ring.
func _mm_zip() -> PackedFloat32Array:
	var n := _n(0.22)
	var zip := _mul(_square(n, 520.0, 1900.0, 0.25), _env(n, 0.003, 2.2))
	var ring := _mul(_sine(_n(0.2), 2400.0, 2300.0), _env(_n(0.2), 0.002, 3.0))
	return _mix(_lowpass(zip, 6000.0), ring, 0.35, _n(0.05))


## Sacred Flame: shimmering major chord with tremolo, swelling then fading.
func _radiant() -> PackedFloat32Array:
	var n := _n(0.9)
	var x := PackedFloat32Array()
	x.resize(n)
	for f in [523.25, 659.25, 783.99, 1046.5]:
		var s := _sine(n, f, f * 1.01)
		for i in n:
			x[i] += s[i] * 0.25
	var e := PackedFloat32Array()
	e.resize(n)
	for i in n:
		var t := float(i) / n
		e[i] = minf(1.0, t * 6.0) * pow(1.0 - t, 1.6) * (0.75 + 0.25 * sin(TAU * 11.0 * i / RATE))
	var shimmer := _mul(_highpass(_noise(n), 6000.0), _env(n, 0.05, 2.0))
	return _mix(_mul(x, e), shimmer, 0.08)


## Cure Wounds: soft rising arpeggio of bell-like notes.
func _heal_chime() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(0.85))
	var notes := [659.25, 783.99, 987.77, 1318.5]
	for k in notes.size():
		var n := _n(0.45)
		var b := _mul(_sine(n, notes[k], notes[k]), _env(n, 0.004, 3.0))
		var over := _mul(_sine(n, notes[k] * 2.0, notes[k] * 2.0), _env(n, 0.002, 5.0))
		out = _mix(out, _mix(b, over, 0.3), 0.6, _n(0.09 * k))
	return out


## Fire Bolt impact: small whoompf + crackle.
func _fire_impact() -> PackedFloat32Array:
	var n := _n(0.35)
	var boom := _mul(_lowpass(_noise(n), 1800.0, 300.0), _env(n, 0.002, 2.5))
	var crack := PackedFloat32Array()
	crack.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in n:
		if rng.randf() < 0.004:
			crack[i] = rng.randf_range(-1.0, 1.0)
	crack = _mul(_highpass(crack, 2000.0), _env(n, 0.001, 1.5))
	return _mix(boom, crack, 1.5)



## Fireball: a big explosion - sub-bass thump, sharp crack, roaring blast sweeping down,
## long rumbling tail with crackles, a little saturation for weight.
func _fireball_boom() -> PackedFloat32Array:
	var n := _n(2.6)
	# sub-bass thump: 75 Hz falling to 28 Hz
	var sub := _mul(_sine(_n(1.2), 75.0, 28.0), _env(_n(1.2), 0.004, 2.2))
	# the crack at the front
	var crack := _mul(_highpass(_noise(_n(0.09)), 1500.0), _env(_n(0.09), 0.0005, 3.0))
	# roaring blast: noise with a cutoff sweeping 4 kHz -> 250 Hz
	var roar := _mul(_lowpass(_noise(_n(1.1)), 4000.0, 250.0), _env(_n(1.1), 0.003, 1.8))
	# rumble tail: dark noise, slow swell and long fade
	var rumble_n := _n(2.6)
	var rumble := _lowpass(_lowpass(_noise(rumble_n), 180.0), 140.0)
	var re := PackedFloat32Array()
	re.resize(rumble_n)
	for i in rumble_n:
		var t := float(i) / rumble_n
		re[i] = minf(1.0, t * 8.0) * pow(1.0 - t, 1.3) * (0.8 + 0.2 * sin(TAU * 3.0 * t))
	rumble = _mul(rumble, re)
	# crackles in the tail
	var crk := PackedFloat32Array()
	crk.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in n:
		var t := float(i) / n
		if t > 0.08 and rng.randf() < 0.0025 * (1.0 - t):
			crk[i] = rng.randf_range(-1.0, 1.0)
	crk = _highpass(crk, 1800.0)
	var x := PackedFloat32Array()
	x.resize(n)
	x = _mix(x, sub, 1.0)
	x = _mix(x, roar, 0.9)
	x = _mix(x, rumble, 2.4)
	x = _mix(x, crack, 0.7)
	x = _mix(x, crk, 0.6)
	# saturation for weight
	var peak := 0.0001
	for v in x:
		peak = maxf(peak, absf(v))
	for i in x.size():
		x[i] = tanh(x[i] / peak * 1.8)
	return x


# --- dungeon sounds (doors, locks, stairs, skeletons) ---------------------------------------

## Heavy wooden door: a creaky hinge (wobbling square, low-passed) then a soft thud.
func _door_open() -> PackedFloat32Array:
	var n := _n(0.55)
	var creak := PackedFloat32Array()
	creak.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var f := 180.0 + 120.0 * t + 40.0 * sin(t * 37.0) + 25.0 * sin(t * 91.0)
		ph += f / RATE
		creak[i] = (1.0 if fmod(ph, 1.0) < 0.18 else -0.2) * sin(PI * t) * (0.6 + 0.4 * sin(t * 53.0))
	creak = _lowpass(creak, 2200.0, 1400.0)
	var tn := _n(0.2)
	var thud := _mix(_mul(_sine(tn, 110.0, 50.0), _env(tn, 0.002, 3.0)),
			_mul(_lowpass(_noise(tn), 500.0), _env(tn, 0.001, 4.0)), 0.6)
	return _mix(creak, thud, 1.4, _n(0.42))


## Locked: the handle rattles twice against the bolt.
func _door_locked() -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(_n(0.32))
	for k in 2:
		var m := _n(0.07)
		var clunk := _mix(_mul(_square(m, 520.0 - k * 60.0, 300.0, 0.3), _env(m, 0.001, 4.0)),
				_mul(_lowpass(_noise(m), 1800.0), _env(m, 0.001, 5.0)), 0.8)
		x = _mix(x, clunk, 1.0, _n(0.02 + k * 0.13))
	return x


## Lock picked: two light ticks, then the bolt clicks back.
func _lock_click() -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(_n(0.36))
	for k in 2:
		var m := _n(0.025)
		x = _mix(x, _mul(_highpass(_noise(m), 3000.0), _env(m, 0.001, 3.0)), 0.5, _n(0.01 + k * 0.08))
	var c := _n(0.09)
	var click := _mix(_mul(_square(c, 1400.0, 900.0, 0.25), _env(c, 0.001, 5.0)),
			_mul(_lowpass(_noise(c), 2500.0), _env(c, 0.001, 4.0)), 0.9)
	return _mix(x, click, 1.0, _n(0.24))


## Footsteps on stone stairs, falling in pitch (going down; played faster/higher for up).
func _stairs() -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(_n(1.0))
	for k in 5:
		var m := _n(0.1)
		var step := _mix(_mul(_sine(m, 150.0 - k * 12.0, 60.0), _env(m, 0.002, 3.0)),
				_mul(_lowpass(_noise(m), 900.0 - k * 80.0), _env(m, 0.001, 5.0)), 0.7)
		x = _mix(x, step, 1.0 - k * 0.12, _n(k * 0.17))
	return x


## Skeleton hit: a burst of dry bone clicks.
func _bone_rattle() -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(_n(0.3))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 9:
		var m := _n(0.03)
		var f := rng.randf_range(900.0, 1700.0)
		var click := _mix(_mul(_square(m, f, f * 0.7, 0.2), _env(m, 0.001, 6.0)),
				_mul(_highpass(_noise(m), 2000.0), _env(m, 0.001, 6.0)), 0.6)
		x = _mix(x, click, rng.randf_range(0.4, 1.0) * (1.0 - k * 0.07), _n(k * 0.026 + rng.randf_range(0.0, 0.01)))
	return x


## Skeleton collapses: clicks spreading out, then a final clatter on the floor.
func _bone_collapse() -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(_n(0.8))
	var rng := RandomNumberGenerator.new()
	rng.seed = 78
	for k in 22:
		var m := _n(0.035)
		var f := rng.randf_range(600.0, 1500.0)
		var click := _mix(_mul(_square(m, f, f * 0.6, 0.2), _env(m, 0.001, 6.0)),
				_mul(_highpass(_noise(m), 1500.0), _env(m, 0.001, 6.0)), 0.6)
		var t := pow(rng.randf(), 0.7) * 0.62
		x = _mix(x, click, rng.randf_range(0.3, 0.9), _n(t))
	var tn := _n(0.15)
	x = _mix(x, _mul(_lowpass(_noise(tn), 700.0), _env(tn, 0.001, 3.0)), 0.8, _n(0.6))
	return x


# --- output -----------------------------------------------------------------------------------

## Chest lid: a short low hinge creak, then the lid knocks back against the chest.
func _chest_open() -> PackedFloat32Array:
	var n := _n(0.3)
	var creak := PackedFloat32Array()
	creak.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var f := 140.0 + 160.0 * t + 30.0 * sin(t * 41.0)
		ph += f / RATE
		creak[i] = (1.0 if fmod(ph, 1.0) < 0.2 else -0.25) * sin(PI * t)
	creak = _lowpass(creak, 1800.0, 1200.0)
	var tn := _n(0.18)
	var knock := _mix(_mul(_sine(tn, 150.0, 70.0), _env(tn, 0.002, 4.0)),
			_mul(_lowpass(_noise(tn), 700.0), _env(tn, 0.001, 5.0)), 0.7)
	return _mix(creak, knock, 1.3, _n(0.26))


## Coins: a handful of small metallic pings (inharmonic partials), tumbling and fading.
func _coins() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(0.7))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var t := 0.0
	for k in 9:
		var m := _n(0.16)
		var f := rng.randf_range(2300.0, 3600.0)
		var ping := _mix(_sine(m, f, f), _sine(m, f * 2.76, f * 2.76), 0.45)
		ping = _mix(ping, _sine(m, f * 5.4, f * 5.4), 0.2)
		ping = _mul(ping, _env(m, 0.001, 6.0))
		out = _mix(out, ping, 0.75 - k * 0.06, _n(t))
		t += rng.randf_range(0.025, 0.07)
	return out


func _save(name: String, x: PackedFloat32Array, peak := 0.85) -> void:
	var m := 0.0001
	for v in x:
		m = maxf(m, absf(v))
	var data := PackedByteArray()
	data.resize(x.size() * 2)
	for i in x.size():
		var s := clampi(int(x[i] / m * peak * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, s)
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
	print("wrote %s%s.wav  %.2fs" % [OUT, name, x.size() / float(RATE)])


## Drinking a potion: a cork pop, then three glugs (falling sine bubbles over a soft gurgle).
func _potion_drink() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(0.62))
	var pn := _n(0.05)
	var pop := _mul(_sine(pn, 900.0, 380.0), _env(pn, 0.001, 6.0))
	pop = _mix(pop, _mul(_highpass(_noise(pn), 2500.0), _env(pn, 0.0005, 9.0)), 0.35)
	out = _mix(out, pop, 0.8)
	var pitches := [330.0, 290.0, 345.0]
	for k in pitches.size():
		var gn := _n(0.11)
		var f: float = pitches[k]
		var glug := _mul(_sine(gn, f, f * 0.55), _env(gn, 0.006, 2.5))
		var gurgle := _mul(_lowpass(_noise(gn), 500.0), _env(gn, 0.01, 2.0))
		out = _mix(out, _mix(glug, gurgle, 0.5), 0.9, _n(0.14 + 0.14 * k))
	return out


## Reading a spell scroll: a dry paper unroll (crackly band-passed noise), then a rising
## two-note shimmer as the words burn away.
func _scroll_read() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(0.75))
	var rn := _n(0.32)
	var rustle := _lowpass(_highpass(_noise(rn), 1200.0), 5200.0)
	var crackle := _noise(rn)
	var e := PackedFloat32Array()
	e.resize(rn)
	for i in rn:
		var t := float(i) / rn
		# uneven paper ticks over a swell that fades
		e[i] = sin(PI * t) * (0.45 + 0.55 * absf(crackle[i]) * (1.0 if fmod(t * 23.0, 1.0) < 0.35 else 0.3))
	out = _mix(out, _mul(rustle, e), 0.7)
	for k in 2:
		var sn := _n(0.4)
		var f: float = [880.0, 1318.5][k]
		var tone := _mix(_sine(sn, f, f * 1.02), _sine(sn, f * 2.0, f * 2.03), 0.3)
		out = _mix(out, _mul(tone, _env(sn, 0.03, 2.2)), 0.32, _n(0.22 + 0.11 * k))
	return out


## Lightning Bolt: a sharp white-noise crack with a buzzing zap, then a low rolling rumble.
func _lightning_crack() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(1.4))
	var cn := _n(0.16)
	var crack := _mul(_highpass(_noise(cn), 900.0), _env(cn, 0.0008, 5.0))
	out = _mix(out, crack, 1.0)
	var zn := _n(0.3)
	var zap := _mul(_square(zn, 2200.0, 180.0, 0.35, 70.0, 0.2), _env(zn, 0.001, 2.0))
	out = _mix(out, _lowpass(zap, 4500.0), 0.35)
	var rn := _n(1.3)
	var rumble := _lowpass(_noise(rn), 160.0, 70.0)
	var re := PackedFloat32Array()
	re.resize(rn)
	for i in rn:
		var t := float(i) / rn
		re[i] = minf(1.0, t * 12.0) * pow(1.0 - t, 1.8) * (0.7 + 0.3 * sin(TAU * 3.5 * t))
	out = _mix(out, _mul(rumble, re), 5.0, _n(0.06))
	return out


## Level up: a quick rising square-wave arpeggio (C E G C) then a held bright chord with a little
## vibrato and a sparkle on top. Chiptune fanfare, ~1.3 s.
func _level_up() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(1.35))
	var arp := [523.25, 659.25, 783.99, 1046.5]
	for k in arp.size():
		var n := _n(0.11)
		var t := _mul(_square(n, arp[k], arp[k], 0.25), _env(n, 0.003, 1.5))
		out = _mix(out, t, 0.32, _n(0.075 * k))
	var start := _n(0.3)
	for f in [523.25, 659.25, 783.99, 1046.5]:
		var n := _n(1.0)
		var t := _mul(_square(n, f, f, 0.5, 5.5, 0.006), _env(n, 0.01, 2.2))
		out = _mix(out, t, 0.12, start)
	var sp := _n(0.6)
	var spark := _mul(_sine(sp, 2093.0, 2637.0), _env(sp, 0.002, 4.0))
	out = _mix(out, spark, 0.18, start + _n(0.05))
	return out


## Portal opening: a rising shimmer (detuned sines sweeping up with a fast wobble) over a soft
## airy swell of filtered noise, settling into a hum. ~1.4 s.
func _portal_open() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(1.4))
	var n := _n(1.3)
	var e := PackedFloat32Array()
	e.resize(n)
	for i in n:
		var t := float(i) / n
		e[i] = minf(1.0, t * 4.0) * pow(1.0 - t, 1.4) * (0.75 + 0.25 * sin(TAU * 9.0 * t * (1.0 + t)))
	for f in [220.0, 331.0, 442.0]:
		out = _mix(out, _mul(_sine(n, f, f * 2.6), e), 0.22)
	var air := _lowpass(_highpass(_noise(n), 600.0), 1200.0, 5000.0)
	out = _mix(out, _mul(air, e), 0.5)
	var sp := _n(0.5)
	out = _mix(out, _mul(_sine(sp, 1760.0, 2637.0), _env(sp, 0.002, 4.0)), 0.12, _n(0.45))
	return out


## Stepping through: a falling whoosh (noise sweeping down) with a low thrum. ~0.9 s.
func _portal_travel() -> PackedFloat32Array:
	var n := _n(0.9)
	var e := PackedFloat32Array()
	e.resize(n)
	for i in n:
		var t := float(i) / n
		e[i] = minf(1.0, t * 8.0) * pow(1.0 - t, 2.0)
	var whoosh := _mul(_lowpass(_noise(n), 6000.0, 300.0), e)
	var thrum := _mul(_sine(n, 180.0, 70.0), e)
	return _mix(_mix(PackedFloat32Array(), whoosh, 0.9), thrum, 0.5)


## Quest updated: two bright square-wave notes (G then C up a fourth) with a soft echo. ~0.7 s.
func _quest_update() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(0.75))
	var notes := [783.99, 1046.5]
	for k in notes.size():
		var n := _n(0.3 if k == 0 else 0.45)
		var t := _mul(_square(n, notes[k], notes[k], 0.25), _env(n, 0.004, 2.0))
		out = _mix(out, t, 0.28, _n(0.12 * k))
		out = _mix(out, t, 0.08, _n(0.12 * k + 0.2))     # echo
	return out


## Herrasoft splash: a soft bell chord rolled upward (E A C# E, sine + a quieter octave partial),
## long ring with a gentle shimmer. ~2.2 s.
func _logo_chime() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(2.3))
	var notes := [659.25, 880.0, 1108.73, 1318.51]
	for k in notes.size():
		var n := _n(2.3 - 0.12 * k)
		var e := _env(n, 0.004, 3.2)
		var bell := _mix(_sine(n, notes[k], notes[k]), _sine(n, notes[k] * 2.0, notes[k] * 2.0), 0.3)
		bell = _mix(bell, _sine(n, notes[k] * 3.01, notes[k] * 3.01), 0.08)
		out = _mix(out, _mul(bell, e), 0.22, _n(0.12 * k))
	var sp := _n(0.9)
	out = _mix(out, _mul(_sine(sp, 2637.0, 2637.0), _env(sp, 0.01, 3.0)), 0.06, _n(0.5))
	return out


## Victory: a chiptune fanfare. Pickup triplet (G G G), then C - G - C' - E' rising, a held bright
## C major chord with vibrato, a little bass under it and a sparkle on top. ~3.2 s.
func _victory_fanfare() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(3.3))
	# [start s, length s, Hz]
	var lead := [
		[0.00, 0.10, 392.0], [0.13, 0.10, 392.0], [0.26, 0.10, 392.0],
		[0.40, 0.28, 523.25], [0.70, 0.18, 392.0], [0.90, 0.18, 523.25], [1.10, 0.20, 659.25],
		[1.32, 1.9, 783.99],
	]
	for nt in lead:
		var n := _n(nt[1])
		var vib := 5.5 if nt[1] > 1.0 else 0.0
		var t := _mul(_square(n, nt[2], nt[2], 0.25, vib, 0.007), _env(n, 0.004, 1.6 if nt[1] > 1.0 else 1.2))
		out = _mix(out, t, 0.26, _n(nt[0]))
	# harmony under the held note: C E G (half-duty squares, quieter)
	for f in [523.25, 659.25, 392.0]:
		var n := _n(1.9)
		out = _mix(out, _mul(_square(n, f, f, 0.5, 5.0, 0.005), _env(n, 0.02, 1.8)), 0.08, _n(1.32))
	# bass: triangle-ish (sine) C2 - G2 - C3 pulses
	var bass := [[0.40, 0.28, 130.81], [0.70, 0.18, 98.0], [0.90, 0.18, 130.81], [1.10, 0.20, 164.81], [1.32, 1.6, 130.81]]
	for b in bass:
		var n := _n(b[1])
		out = _mix(out, _mul(_sine(n, b[2], b[2]), _env(n, 0.005, 1.5)), 0.30, _n(b[0]))
	var sp := _n(0.8)
	out = _mix(out, _mul(_sine(sp, 2093.0, 3136.0), _env(sp, 0.002, 4.0)), 0.12, _n(1.36))
	return out


# --- Phase 6: traps, mechanisms, puzzles ----------------------------------------------------------

## A click under the plate, then steel spikes ringing up out of the floor.
func _trap_spikes() -> PackedFloat32Array:
	var c := _n(0.04)
	var x := _mul(_highpass(_noise(c), 2500.0), _env(c, 0.001, 4.0))
	var n := _n(0.45)
	var shing := _mul(_highpass(_noise(n), 3500.0), _env(n, 0.002, 5.0))
	for f in [2150.0, 3370.0, 4410.0]:
		shing = _mix(shing, _mul(_sine(n, f, f * 0.98), _env(n, 0.002, 4.0)), 0.25)
	return _mix(x, shing, 1.0, _n(0.07))


## Three darts: short airy thwips, a tick as each leaves its hole.
func _trap_darts() -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(_n(0.5))
	for k in 3:
		var m := _n(0.11)
		var e := PackedFloat32Array()
		e.resize(m)
		for i in m:
			var t := float(i) / m
			e[i] = sin(PI * t) * (1.0 - t)
		var thwip := _mul(_lowpass(_highpass(_noise(m), 1500.0), 5000.0, 2500.0), e)
		var tick := _mul(_square(_n(0.015), 1800.0, 1400.0, 0.3), _env(_n(0.015), 0.001, 4.0))
		x = _mix(x, _mix(tick, thwip, 0.9), 1.0 - k * 0.15, _n(0.02 + k * 0.11))
	return x


## A roaring gout of flame: low noise swelling and dying away.
func _trap_fire() -> PackedFloat32Array:
	var n := _n(0.9)
	var e := PackedFloat32Array()
	e.resize(n)
	for i in n:
		var t := float(i) / n
		e[i] = minf(1.0, t * 8.0) * pow(1.0 - t, 1.6)
	var roar := _mul(_lowpass(_noise(n), 900.0, 400.0), e)
	var hiss := _mul(_highpass(_noise(n), 3000.0), e)
	return _mix(roar, hiss, 0.25)


## The floor gives: a crack, crumbling stone, a thud far below.
func _trap_pit() -> PackedFloat32Array:
	var c := _n(0.08)
	var x := _mul(_lowpass(_noise(c), 3000.0), _env(c, 0.001, 3.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	for k in 10:
		var m := _n(0.05)
		var bit := _mul(_lowpass(_noise(m), rng.randf_range(600.0, 1600.0)), _env(m, 0.001, 4.0))
		x = _mix(x, bit, rng.randf_range(0.3, 0.7), _n(0.05 + k * 0.04 + rng.randf_range(0.0, 0.02)))
	var tn := _n(0.3)
	var thud := _mix(_mul(_sine(tn, 90.0, 40.0), _env(tn, 0.002, 3.0)), _mul(_lowpass(_noise(tn), 300.0), _env(tn, 0.001, 3.0)), 0.7)
	return _mix(x, thud, 1.2, _n(0.55))


## A hand bell jangled hard: inharmonic clangs, quickly repeated.
func _trap_alarm() -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(_n(1.3))
	for k in 6:
		var m := _n(0.5)
		var f := 1480.0 if k % 2 == 0 else 1395.0
		var bell := _mix(_sine(m, f, f), _sine(m, f * 2.43, f * 2.43), 0.5)
		bell = _mix(bell, _sine(m, f * 3.9, f * 3.9), 0.25)
		bell = _mul(bell, _env(m, 0.001, 4.0))
		var clap := _mul(_highpass(_noise(_n(0.01)), 3000.0), _env(_n(0.01), 0.001, 3.0))
		x = _mix(x, _mix(bell, clap, 0.6), 0.8 - k * 0.08, _n(k * 0.13))
	return x


## A heavy lever: a ratchet of clicks, then a deep clunk.
func _lever() -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(_n(0.45))
	for k in 4:
		var m := _n(0.02)
		x = _mix(x, _mul(_square(m, 900.0 - k * 60.0, 700.0, 0.3), _env(m, 0.001, 5.0)), 0.35, _n(k * 0.045))
	var tn := _n(0.25)
	var clunk := _mix(_mul(_sine(tn, 140.0, 60.0), _env(tn, 0.002, 3.0)),
			_mul(_lowpass(_noise(tn), 900.0), _env(tn, 0.001, 5.0)), 0.9)
	return _mix(x, clunk, 1.0, _n(0.19))


## A stone plate settling: a dull tock.
func _plate_click() -> PackedFloat32Array:
	var n := _n(0.14)
	return _mix(_mul(_sine(n, 260.0, 150.0), _env(n, 0.001, 5.0)),
			_mul(_lowpass(_noise(n), 1400.0), _env(n, 0.001, 6.0)), 0.8)


## A portcullis winding up: chain links clattering over a grinding drone, ending in a clank.
func _gate_rise() -> PackedFloat32Array:
	var n := _n(0.95)
	var e := PackedFloat32Array()
	e.resize(n)
	for i in n:
		var t := float(i) / n
		e[i] = minf(1.0, t * 10.0) * (1.0 - t * 0.6)
	var drone := _mul(_lowpass(_square(n, 70.0, 85.0, 0.4), 400.0), e)
	var x := _mix(drone, _mul(_lowpass(_noise(n), 600.0), e), 0.6)
	for k in 14:
		var m := _n(0.025)
		x = _mix(x, _mul(_square(m, 1300.0 + (k % 3) * 170.0, 1000.0, 0.25), _env(m, 0.001, 5.0)), 0.18, _n(0.03 + k * 0.058))
	var tn := _n(0.2)
	var clank := _mix(_mul(_sine(tn, 220.0, 120.0), _env(tn, 0.001, 4.0)), _mul(_square(tn, 600.0, 500.0, 0.3), _env(tn, 0.001, 6.0)), 0.3)
	return _mix(x, clank, 0.9, _n(0.86))


## Stone grinding on stone: low rough noise, wavering, fading.
func _stone_slide() -> PackedFloat32Array:
	var n := _n(1.1)
	var e := PackedFloat32Array()
	e.resize(n)
	for i in n:
		var t := float(i) / n
		e[i] = minf(1.0, t * 6.0) * pow(1.0 - t, 1.2) * (0.75 + 0.25 * sin(t * 47.0))
	var grind := _mul(_lowpass(_noise(n), 500.0, 250.0), e)
	return _mix(grind, _mul(_lowpass(_square(n, 55.0, 48.0, 0.3), 300.0), e), 0.35)


## A block shoved one square: a short scrape and a bump.
func _stone_push() -> PackedFloat32Array:
	var n := _n(0.35)
	var e := PackedFloat32Array()
	e.resize(n)
	for i in n:
		var t := float(i) / n
		e[i] = sin(PI * minf(1.0, t * 1.2)) * (0.8 + 0.2 * sin(t * 90.0))
	var scrape := _mul(_lowpass(_noise(n), 1100.0, 600.0), e)
	var tn := _n(0.14)
	return _mix(scrape, _mul(_sine(tn, 120.0, 60.0), _env(tn, 0.002, 3.0)), 0.8, _n(0.26))


## Solved: a bright rising arpeggio (C E G C) with a soft echo.
func _puzzle_solved() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(1.2))
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for k in notes.size():
		var n := _n(0.6)
		var t := _mix(_square(n, notes[k], notes[k], 0.25), _sine(n, notes[k] * 2.0, notes[k] * 2.0), 0.3)
		t = _mul(t, _env(n, 0.004, 2.5))
		out = _mix(out, t, 0.22, _n(0.09 * k))
		out = _mix(out, t, 0.07, _n(0.09 * k + 0.22))
	return out


## Wrong: a low falling buzz and a clunk.
func _puzzle_fail() -> PackedFloat32Array:
	var n := _n(0.4)
	var buzz := _mul(_lowpass(_square(n, 180.0, 90.0, 0.4), 1200.0), _env(n, 0.003, 2.0))
	var tn := _n(0.2)
	return _mix(buzz, _mul(_sine(tn, 110.0, 55.0), _env(tn, 0.001, 3.0)), 0.9, _n(0.05))


## Something noticed: two quick high notes (a "ping!").
func _discover() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(0.4))
	var notes := [1318.51, 1975.53]
	for k in 2:
		var n := _n(0.22)
		var f: float = notes[k]
		out = _mix(out, _mul(_mix(_sine(n, f, f), _square(n, f, f, 0.25), 0.15), _env(n, 0.002, 3.0)), 0.5, _n(k * 0.08))
	return out


## Searching and finding nothing: a soft shuffle of hands over stone.
func _search() -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(_n(0.5))
	for k in 3:
		var m := _n(0.12)
		var e := PackedFloat32Array()
		e.resize(m)
		for i in m:
			e[i] = sin(PI * float(i) / m)
		x = _mix(x, _mul(_lowpass(_highpass(_noise(m), 800.0), 3000.0), e), 0.4, _n(k * 0.14))
	return x


## A brazier catching (or snuffed): a breathy whoosh of flame.
func _flame_whoosh() -> PackedFloat32Array:
	var n := _n(0.5)
	var e := PackedFloat32Array()
	e.resize(n)
	for i in n:
		var t := float(i) / n
		e[i] = minf(1.0, t * 12.0) * pow(1.0 - t, 2.0)
	return _mix(_mul(_lowpass(_noise(n), 1600.0, 500.0), e), _mul(_highpass(_noise(n), 2500.0), e), 0.3)
