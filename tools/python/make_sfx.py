"""Synthesize retro-style sound effects for the fireball scene (44.1 kHz, 16-bit mono WAV).

Outputs (in ./sfx/): torch_ambience, ui_select, charge, cast_whoosh, fireball_flight,
explosion, monster_hurt, monster_death, turn_chime  (.wav)
"""
import numpy as np, os, wave

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "sfx")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.01, release=None, curve=2.0):
    """Attack then exponential-ish decay over n samples."""
    a = max(1, int(SR * attack))
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    if release is None:
        e[a:] = np.linspace(1, 0, n - a) ** curve
    return e


def filt(x, lo=None, hi=None):
    """Brick-wall-ish band filter via FFT (fine for one-shot sounds)."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    m = np.ones_like(f)
    if lo: m *= 1 / (1 + (lo / np.maximum(f, 1)) ** 4)
    if hi: m *= 1 / (1 + (f / hi) ** 4)
    return np.fft.irfft(X * m, len(x))


def sweep_filter(x, hi_start, hi_end, chunks=40):
    """Lowpass whose cutoff glides over time (processed in overlapping chunks)."""
    out = np.zeros_like(x)
    n = len(x)
    size = n // chunks * 2
    win = np.hanning(size)
    for i in range(chunks * 2):
        s = i * (size // 2)  # 50% overlap
        if s >= n: break
        seg = x[s:s + size]
        w = win[:len(seg)]
        k = s / n
        out[s:s + len(seg)] += filt(seg * w, hi=hi_start + (hi_end - hi_start) * k)
    return out


def square(freq, t, duty=0.5):
    ph = np.cumsum(freq / SR) if np.ndim(freq) else freq * t
    return np.where((ph % 1) < duty, 1.0, -1.0)


def crackle(n, density, seed=0):
    """Random pops like burning wood."""
    r = np.random.default_rng(seed)
    x = np.zeros(n)
    idx = r.integers(0, n - 300, int(density * n / SR))
    for i in idx:
        L = r.integers(40, 300)
        x[i:i + L] += r.uniform(-1, 1) * np.exp(-np.arange(L) / (L / 4)) * r.uniform(0.3, 1)
    return x


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x / m * peak if m else x


def save(name, x, peak=0.9):
    x = norm(x, peak)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    return x


sounds = {}

# --- torch ambience: low rumble + soft crackle (seamless-ish 5 s loop) ---
n = SR * 5
amb = filt(rng.normal(0, 1, n), hi=180) * 0.6 + filt(crackle(n, 14, 1), lo=900, hi=6000) * 0.5
fade = np.ones(n); f = SR // 4
fade[:f] = np.linspace(0, 1, f); fade[-f:] = np.linspace(1, 0, f)
sounds["torch_ambience"] = save("torch_ambience", amb * fade, 0.35)

# --- UI select: two quick square blips ---
t = t_(0.09)
b = np.concatenate([square(880, t_(0.04)) * env(len(t_(0.04)), 0.002),
                    square(1320, t_(0.05)) * env(len(t_(0.05)), 0.002)])
sounds["ui_select"] = save("ui_select", filt(b, hi=6000), 0.4)

# --- charge: rising tone + rising filtered noise + sparkle arpeggio ---
d = 0.42; t = t_(d); n = len(t)
freq = 200 * 2 ** (t / d * 2.5)
tone = np.sin(2 * np.pi * np.cumsum(freq) / SR) * 0.5 + square(freq * 2, t, 0.25) * 0.15
noise = sweep_filter(rng.normal(0, 1, n), 400, 5000) * 0.6
arp = np.zeros(n)
for i, fr in enumerate([1047, 1319, 1568, 2093, 1568, 2093, 2637, 3136]):
    s = int(i * n / 8); L = int(n / 8)
    arp[s:s + L] += square(fr, t_(L / SR), 0.5)[:L] * np.exp(-np.arange(L) / (L / 3)) * 0.18
rise = np.linspace(0.2, 1, n) ** 1.5
sounds["charge"] = save("charge", (tone + noise + arp) * rise * env(n, 0.02, curve=0.15), 0.6)

# --- cast whoosh: fast filtered-noise swell ---
d = 0.35; n = int(SR * d)
w = sweep_filter(rng.normal(0, 1, n), 6000, 600) * np.sin(np.linspace(0, np.pi, n)) ** 1.5
thump = np.sin(2 * np.pi * 110 * t_(d) * np.exp(-t_(d) * 6)) * env(n, 0.003, curve=4) * 0.8
sounds["cast_whoosh"] = save("cast_whoosh", w + thump, 0.7)

# --- fireball flight: roaring fire with crackles and a little doppler rise ---
d = 0.6; n = int(SR * d)
roar = filt(rng.normal(0, 1, n), lo=120, hi=1400) * (0.7 + 0.3 * np.sin(2 * np.pi * 13 * t_(d)))
pops = filt(crackle(n, 70, 3), lo=1500, hi=9000) * 0.8
shape = np.linspace(0.6, 1.0, n) * env(n, 0.03, curve=0.3)
sounds["fireball_flight"] = save("fireball_flight", (roar + pops) * shape, 0.6)

# --- explosion: sub boom + noise burst + long crackling tail ---
d = 1.6; t = t_(d); n = len(t)
boom = np.sin(2 * np.pi * np.cumsum(90 * np.exp(-t * 3) + 30) / SR) * np.exp(-t * 3.5)
burst = filt(rng.normal(0, 1, n), hi=2500) * np.exp(-t * 7)
crunch = filt(rng.normal(0, 1, n), lo=2000, hi=8000) * np.exp(-t * 18) * 0.6
tail = filt(crackle(n, 50, 5), lo=800, hi=7000) * np.exp(-t * 2.2) * 0.5
rumble = filt(rng.normal(0, 1, n), hi=120) * np.exp(-t * 2) * 1.2
x = boom * 1.1 + burst + crunch + tail + rumble
x = np.tanh(x * 1.8)  # a bit of saturation for punch
sounds["explosion"] = save("explosion", x * env(n, 0.002, curve=0.0001), 0.95)

# --- monster hurt: short descending squeal with wobble ---
d = 0.28; t = t_(d); n = len(t)
fr = 900 * np.exp(-t * 4) * (1 + 0.08 * np.sin(2 * np.pi * 35 * t))
sq = square(fr, t, 0.3) * 0.5 + np.sin(2 * np.pi * np.cumsum(fr * 1.5) / SR) * 0.4
sounds["monster_hurt"] = save("monster_hurt", filt(sq, hi=4000) * env(n, 0.005, curve=1.5), 0.55)

# --- monster death: gurgling downward wail, then a wet pop ---
d = 0.9; t = t_(d); n = len(t)
fr = 420 * np.exp(-t * 2.2) * (1 + 0.25 * np.sin(2 * np.pi * 11 * t))
wail = square(fr, t, 0.4) * 0.5 + square(fr * 1.01, t, 0.2) * 0.3
gurgle = filt(rng.normal(0, 1, n), lo=150, hi=900) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 18 * t))) * 0.5
body = filt(wail + gurgle, hi=3000) * env(n, 0.01, curve=1.2)
pop = np.zeros(n); s = int(0.62 * SR); L = int(0.12 * SR)
pop[s:s + L] = np.sin(2 * np.pi * np.cumsum(np.linspace(600, 80, L)) / SR) * np.exp(-np.arange(L) / (L / 4))
sounds["monster_death"] = save("monster_death", body + pop * 0.9, 0.6)

# --- turn chime: two soft bell-ish notes ---
def bell(fr, d):
    t = t_(d)
    return (np.sin(2 * np.pi * fr * t) + 0.4 * np.sin(2 * np.pi * fr * 2.01 * t) +
            0.2 * np.sin(2 * np.pi * fr * 3.02 * t)) * np.exp(-t * 6)
c = np.zeros(int(SR * 0.6))
c[:int(SR * 0.5)] += bell(784, 0.5)
s = int(SR * 0.1); c[s:s + int(SR * 0.5)] += bell(1175, 0.5)
sounds["turn_chime"] = save("turn_chime", c, 0.35)

print("saved:", ", ".join(f"{k} ({len(v)/SR:.2f}s)" for k, v in sounds.items()))
