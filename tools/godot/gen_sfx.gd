extends SceneTree
## Retro synthesized combat sound effects -> assets/sfx/<name>.wav (44.1 kHz, 16-bit, mono).
## Run: Godot_console --headless --path . -s res://tools/godot/gen_sfx.gd   (then --import)
## Same ingredients as tools/python/make_sfx.py (concept session): filtered noise, square waves,
## pitch sweeps, exponential envelopes. Doesn't touch the concept-session WAVs.

const RATE := 44100
const OUT := "res://assets/sfx/"

var _seed := 1


func _init() -> void:
	_save("hit_slash", _hit_slash())
	_save("hit_blunt", _hit_blunt())
	_save("hit_pierce", _hit_pierce())
	_save("miss_swish", _miss_swish())
	_save("bow_shot", _bow_shot())
	_save("hero_hurt", _hero_hurt())
	_save("spider_hiss", _spider_hiss())
	_save("ray_zap", _ray_zap())
	_save("crit_hit", _crit_hit())
	_save("mm_zip", _mm_zip())
	_save("radiant", _radiant())
	_save("heal_chime", _heal_chime())
	_save("fire_impact", _fire_impact())
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

# --- output -----------------------------------------------------------------------------------

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
