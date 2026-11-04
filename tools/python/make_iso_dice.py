"""Dice-roll overlay for the isometric fireball scene.

Time freezes just before the fireball hits. The Eye Tyrant rolls a d20 Dexterity save (and fails),
then the 8d6 fire damage tumbles in and totals 31; then the blast resumes.

Outputs (in ./iso/): iso_dice.mp4 (with sound), iso_dice.gif, dice_d20_still.png, dice_8d6_still.png
"""
import math, os, random, subprocess, tempfile, wave
import numpy as np
from PIL import Image, ImageDraw
import make_iso_fireball as A      # renders the base animation frames (A.frames, A.durs)
import make_sfx as X               # sound helpers (also (re)writes the base sfx files)

S = A.S
W, H, MAP_H = S.W, S.H, S.MAP_H
font = S.font
OUT = S.OUT

# ---------------------------------------------------------------- roll values (consistent with the scene)
D20, DEX_MOD, DC = 9, 2, 15
D6S = [4, 6, 2, 5, 3, 1, 6, 4]          # sums to 31
assert sum(D6S) == 31

PURPLE = {"edge": (30, 14, 40), "dark": (70, 40, 110), "mid": (112, 70, 172), "light": (160, 120, 220),
          "num": (255, 240, 190)}
FIREC = {"edge": (40, 10, 8), "side": (130, 30, 16), "face": (214, 70, 32), "hi": (250, 130, 60),
         "pip": (255, 236, 170)}


# ---------------------------------------------------------------- drawing helpers
def text_img(txt, col, scale=1, outline=(14, 8, 12)):
    w = int(font.getlength(txt)) + 4
    im = Image.new("RGBA", (w, 15), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1), (1, 1)):
        d.text((2 + ox, 2 + oy), txt, font=font, fill=outline)
    d.text((2, 2), txt, font=font, fill=col)
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST) if scale > 1 else im


def put_text(img, cx, y, txt, col, scale=1):
    t = text_img(txt, col, scale)
    img.alpha_composite(t, (int(cx - t.width / 2), int(y)))


def draw_d20(img, cx, cy, R, ang, number, shade_seed=0, flash=0.0):
    d = ImageDraw.Draw(img)
    hexv = [(cx + R * math.sin(ang + k * math.pi / 3), cy - R * math.cos(ang + k * math.pi / 3)) for k in range(6)]
    inner = [(cx + R * 0.52 * math.sin(ang + k * 2 * math.pi / 3), cy - R * 0.52 * math.cos(ang + k * 2 * math.pi / 3))
             for k in range(3)]
    # tumbling: which outer faces catch the light changes from frame to frame
    rnd = random.Random(shade_seed)
    d.polygon(hexv, fill=PURPLE["dark"])
    for i in range(3):
        tri = [inner[i], hexv[(2 * i + 1) % 6], inner[(i + 1) % 3]]
        d.polygon(tri, fill=PURPLE["mid"] if rnd.random() < 0.7 else PURPLE["light"])
    d.polygon(inner, fill=PURPLE["light"])
    for i in range(3):  # facet edges
        d.line([inner[i], hexv[(2 * i) % 6]], fill=PURPLE["edge"])
        d.line([inner[i], hexv[(2 * i + 1) % 6]], fill=PURPLE["edge"])
        d.line([inner[i], hexv[(2 * i - 1) % 6]], fill=PURPLE["edge"])
    d.polygon(inner, outline=PURPLE["edge"])
    d.polygon(hexv, outline=PURPLE["edge"])
    d.line(hexv + [hexv[0]], fill=PURPLE["edge"], width=2)
    # highlight sliver on the top-left edge
    d.line([hexv[5], hexv[0]], fill=(200, 170, 240))
    t = text_img(str(number), PURPLE["num"])
    img.alpha_composite(t, (int(cx - t.width / 2 + 1), int(cy - 6)))
    if flash:
        ring = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(ring).polygon([(x + (x - cx) * 0.25, y + (y - cy) * 0.25) for x, y in hexv],
                                     outline=(255, 255, 255, int(255 * flash)))
        img.alpha_composite(ring)


PIPS = {1: [(0, 0)], 2: [(-1, -1), (1, 1)], 3: [(-1, -1), (0, 0), (1, 1)], 4: [(-1, -1), (1, -1), (-1, 1), (1, 1)],
        5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)], 6: [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)]}


def draw_d6(img, cx, cy, s, ang, value):
    d = ImageDraw.Draw(img)
    def sq(ox, oy, k):
        pts = []
        for a in (45, 135, 225, 315):
            for da in (-14, 14):      # cut corners -> rounded look
                r = s * 0.5 * math.sqrt(2) * (0.86 if da else 1) * k
                aa = math.radians(a + da) + ang
                pts.append((cx + ox + math.cos(aa) * r * (1 / math.cos(math.radians(14)) * 0.86),
                            cy + oy + math.sin(aa) * r * (1 / math.cos(math.radians(14)) * 0.86)))
        return pts
    d.polygon(sq(1, 3, 1), fill=FIREC["edge"])            # thickness/shadow
    d.polygon(sq(0, 1.5, 1), fill=FIREC["side"])
    d.polygon(sq(0, 0, 1), fill=FIREC["face"], outline=FIREC["edge"])
    d.line(sq(0, 0, 1)[1:4], fill=FIREC["hi"])            # lit top edge
    for px, py in PIPS[value]:
        u, v = px * s * 0.26, py * s * 0.26
        x = cx + u * math.cos(ang) - v * math.sin(ang)
        y = cy + u * math.sin(ang) + v * math.cos(ang)
        d.rectangle((round(x) - 1, round(y) - 1, round(x), round(y)), fill=FIREC["pip"])


SPOT = (A.tcx - 6, A.tcy - 22)   # keep the Eye Tyrant + incoming fireball lit


def dim(img, k=0.42, spot=True):
    px = img.load()
    for y in range(MAP_H):
        for x in range(W):
            kk = k
            if spot:
                d = math.hypot(x - SPOT[0], (y - SPOT[1]) * 1.2) / 52
                kk = k + (1 - k) * max(0.0, min(1.0, 1.6 - d * 1.6))
            r, g, b = px[x, y][:3]
            px[x, y] = (int(r * kk), int(g * kk), min(255, int(b * kk * (1.1 if kk < 1 else 1))), 255)


PX = 104                          # panel centre x
def panel(img, title, col):
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle((12, 40, 196, 226), fill=(18, 14, 24, 215), outline=(120, 96, 70, 255))
    d.rectangle((14, 42, 194, 224), outline=(50, 40, 34, 255))
    put_text(img, PX, 46, title, col)


def bounce(t, x0, x1, y_floor, h0):
    """Ball-like motion: travels x0->x1 while bouncing with decaying height. t in 0..1"""
    x = x0 + (x1 - x0) * (1 - (1 - t) ** 2)
    segs = [0.0, 0.42, 0.72, 0.9, 1.0]
    for i in range(4):
        if t <= segs[i + 1]:
            u = (t - segs[i]) / (segs[i + 1] - segs[i])
            hgt = h0 * (0.35 ** i)
            return x, y_floor - hgt * 4 * u * (1 - u) * (1 if i else 1)
    return x, y_floor


# ---------------------------------------------------------------- build the frozen-impact frames
I_FREEZE = 6 + 5 + A.NF - 1          # last flight frame: fireball right at the Eye Tyrant
base = A.frames[I_FREEZE].convert("RGBA")
dimmed = base.copy(); dim(dimmed)

seq = []          # (image, duration_ms)
sfx_events = []   # (time_ms relative to freeze start, sound_name, volume)
clock = 0


def add(img, dur):
    global clock
    seq.append((img.convert("RGB"), dur)); clock += dur


# brief "hit-stop" flash before dimming
add(base, 120)

# ---- d20 saving throw
title = "EYE TYRANT: DEXTERITY SAVE"
NR = 16
rnd = random.Random(3)
prev_y = None
for i in range(NR):
    t = i / (NR - 1)
    x, y = bounce(t, PX - 62, PX, 112, 15)
    img = dimmed.copy(); panel(img, title, (210, 170, 255))
    put_text(img, PX, 60, f"d20 + {DEX_MOD}  vs  spell DC {DC}", (180, 176, 190))
    num = D20 if t > 0.9 else rnd.randint(1, 20)
    ang = (1 - t) ** 1.5 * 9.0
    draw_d20(img, x, y, 22, ang, num, shade_seed=i, flash=0)
    add(img, 45)
    # clack when the die hits the floor (local minimum of the bounce)
    if prev_y is not None and y >= 111 and prev_y < 111:
        sfx_events.append((clock - 45, "clack_big", 0.9 if i < 8 else 0.6))
    prev_y = y
sfx_events.append((clock - 45, "clack_big", 0.5))
# settle, flash, reveal result
for k in range(4):
    img = dimmed.copy(); panel(img, title, (210, 170, 255))
    put_text(img, PX, 60, f"d20 + {DEX_MOD}  vs  spell DC {DC}", (180, 176, 190))
    draw_d20(img, PX, 112, 22, 0, D20, shade_seed=99, flash=1 - k / 4)
    add(img, 60)
sfx_events.append((clock, "fail_sting", 0.8))
result_frames = []
for k in range(14):
    img = dimmed.copy(); panel(img, title, (210, 170, 255))
    put_text(img, PX, 60, f"d20 + {DEX_MOD}  vs  spell DC {DC}", (180, 176, 190))
    draw_d20(img, PX, 112, 22, 0, D20, shade_seed=99)
    put_text(img, PX, 140, f"{D20} + {DEX_MOD} = {D20 + DEX_MOD}", (235, 230, 240))
    if k >= 2:
        sc = 3 if k == 2 else 2
        put_text(img, PX, 158 - (sc - 2) * 6, "FAILED!", (255, 90, 80) if k % 4 < 3 else (255, 200, 180), sc)
    if k >= 5:
        put_text(img, PX, 200, "takes full damage", (200, 150, 150))
    add(img, 70)
d20_still = seq[-1][0]

# ---- 8d6 damage
title = "FIREBALL DAMAGE: 8d6"
slots_x = [PX + (i % 4 - 1.5) * 32 for i in range(8)]
slots_y = [96 if i < 4 else 126 for i in range(8)]
STAG, FALL = 2, 9
NB = STAG * 7 + FALL + 1
rnd = random.Random(8)
landed_at = {}
for i in range(NB):
    img = dimmed.copy(); panel(img, title, (255, 170, 90))
    put_text(img, PX, 60, "roll 8 six-sided dice", (180, 176, 190))
    running = 0
    for j, val in enumerate(D6S):
        k = i - j * STAG
        if k < 0: continue
        t = min(1, k / FALL)
        x0 = slots_x[j] - 18
        x, y = bounce(t, x0, slots_x[j], slots_y[j], 14)
        y -= (1 - t) ** 2 * 8
        settled = t >= 1
        face = val if t > 0.8 else rnd.randint(1, 6)
        draw_d6(img, x, y, 16, (1 - t) ** 1.3 * 7 + j, face) if not settled else draw_d6(img, x, y, 16, 0, val)
        if settled:
            running += val
            if j not in landed_at:
                landed_at[j] = clock
                sfx_events.append((clock, "clack_small", 0.7))
        elif k == int(FALL * 0.42):
            sfx_events.append((clock, "clack_small", 0.45))
    if running:
        put_text(img, PX, 150, f"= {running}", (255, 200, 110), 2)
    add(img, 50)

# total reveal
for k in range(16):
    img = dimmed.copy(); panel(img, title, (255, 170, 90))
    put_text(img, PX, 60, "roll 8 six-sided dice", (180, 176, 190))
    for j, val in enumerate(D6S):
        draw_d6(img, slots_x[j], slots_y[j], 16, 0, val)
    put_text(img, PX, 144, "+".join(map(str, D6S)), (200, 190, 180))
    if k == 0:
        sfx_events.append((clock, "total_sting", 0.9))
    sc = 4 if k < 2 else 3
    put_text(img, PX, 158 - (sc - 3) * 6, "31", (255, 230, 120) if k % 3 else (255, 255, 255), sc)
    if k >= 3:
        put_text(img, PX, 204, "FIRE DAMAGE", (255, 150, 80))
    add(img, 70)
d6_still = seq[-1][0]

# quick fade back
for k in (0.7, 0.85):
    img = base.copy(); dim(img, k); add(img, 50)
FREEZE_MS = clock

# ---------------------------------------------------------------- full sequence
frames, durs = [], []
for i in range(I_FREEZE + 1):
    frames.append(A.frames[i]); durs.append(A.durs[i])
t_freeze = sum(durs)
for im, d in seq:
    frames.append(im); durs.append(d)
for i in range(I_FREEZE + 1, len(A.frames)):
    frames.append(A.frames[i]); durs.append(A.durs[i])

big = [f.resize((W * 2, H * 2), Image.NEAREST) for f in frames]
big[0].save(os.path.join(OUT, "iso_dice.gif"), save_all=True, append_images=big[1:], duration=durs, loop=0)
d20_still.resize((W * 3, H * 3), Image.NEAREST).save(os.path.join(OUT, "dice_d20_still.png"))
d6_still.resize((W * 3, H * 3), Image.NEAREST).save(os.path.join(OUT, "dice_8d6_still.png"))

# ---------------------------------------------------------------- sounds
SR = X.SR
rng = np.random.default_rng(11)


def clack(pitch, dur=0.06, body=1.0):
    t = X.t_(dur); n = len(t)
    click = X.filt(rng.normal(0, 1, n), lo=1800, hi=9000) * np.exp(-t * 160)
    ring = (np.sin(2 * np.pi * pitch * t) + 0.5 * np.sin(2 * np.pi * pitch * 1.63 * t)) * np.exp(-t * 70) * 0.6
    thud = np.sin(2 * np.pi * 180 * t) * np.exp(-t * 60) * 0.5 * body
    return click + ring + thud


big_clack = np.concatenate([clack(2600, body=1.4), np.zeros(200), clack(3100, 0.04, 0.3) * 0.4])
X.save("clack_big", big_clack, 0.8)
X.save("clack_small", clack(3400, 0.05, 0.5), 0.6)
t = X.t_(0.5)
fail = np.concatenate([X.square(440, X.t_(0.14), 0.5) * X.env(len(X.t_(0.14)), 0.005, curve=0.6),
                       X.square(330, X.t_(0.14), 0.5) * X.env(len(X.t_(0.14)), 0.005, curve=0.6),
                       X.square(220, X.t_(0.3), 0.5) * X.env(len(X.t_(0.3)), 0.005, curve=1.5)])
X.save("fail_sting", X.filt(fail, hi=3500), 0.45)
t = X.t_(0.7)
hit = np.sin(2 * np.pi * np.cumsum(140 * np.exp(-t * 6) + 50) / SR) * np.exp(-t * 6)
shimmer = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * 5) for f in (523, 659, 784, 1047)) * 0.18
X.save("total_sting", hit + shimmer + X.filt(rng.normal(0, 1, len(t)), hi=3000) * np.exp(-t * 25) * 0.5, 0.75)


def load(name):
    with wave.open(os.path.join(X.OUT, name + ".wav")) as w:
        return np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32767


starts = np.concatenate([[0], np.cumsum(A.durs)]) / 1000
i_cast, i_flight, i_boom = 6, 11, 11 + A.NF
i_after = i_boom + 10
shift = FREEZE_MS / 1000
events = [(starts[1], "ui_select", 0.8), (starts[i_cast], "charge", 0.9),
          (starts[i_flight] - 0.03, "cast_whoosh", 0.9), (starts[i_flight], "fireball_flight", 0.8),
          (starts[i_boom] + shift, "explosion", 1.0), (starts[i_boom] + shift + 0.02, "monster_hurt", 0.7),
          (starts[i_boom + 2] + shift, "monster_death", 0.8), (starts[i_after] + shift + 0.35, "turn_chime", 0.8)]
events += [(t_freeze / 1000 + ms / 1000, n, v) for ms, n, v in sfx_events]

total = sum(durs) / 1000 + 0.3
mix = np.zeros(int(SR * total) + SR)
amb = load("torch_ambience")
mix += np.tile(amb, int(np.ceil(len(mix) / len(amb))))[:len(mix)] * 0.6
# fade the fireball roar out quickly at the freeze (time stops)
for tm, name, vol in events:
    s = load(name) * vol
    i = int(tm * SR)
    if name == "fireball_flight":
        cut = int(t_freeze / 1000 * SR) - i
        if 0 < cut < len(s):
            fade = np.ones(len(s)); f = int(0.06 * SR)
            fade[cut:cut + f] = np.linspace(1, 0, len(fade[cut:cut + f])); fade[cut + f:] = 0
            s = s * fade
    mix[i:i + len(s)] += s[:len(mix) - i]
mix = np.tanh(mix[:int(SR * total)] * 1.1) * 0.95
mixp = os.path.join(X.OUT, "dice_scene_mix.wav")
with wave.open(mixp, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((mix * 32767).astype(np.int16).tobytes())

with tempfile.TemporaryDirectory() as tmp:
    lines = []
    for k, (fr, d) in enumerate(zip(frames, durs)):
        p = os.path.join(tmp, f"f{k:03d}.png")
        fr.resize((W * 3, H * 3), Image.NEAREST).save(p)
        lines += [f"file '{p}'", f"duration {d / 1000:.3f}"]
    lines += [f"file '{p}'", "duration 0.300", f"file '{p}'"]
    lst = os.path.join(tmp, "list.txt"); open(lst, "w").write("\n".join(lines) + "\n")
    out = os.path.join(OUT, "iso_dice.mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-i", mixp,
                    "-vf", "fps=30,format=yuv420p", "-c:v", "libx264", "-crf", "16", "-tune", "animation",
                    "-c:a", "aac", "-b:a", "160k", "-shortest", "-movflags", "+faststart", out], check=True)
print(f"frames {len(frames)}, length {sum(durs)/1000:.1f}s, freeze {FREEZE_MS/1000:.1f}s, dice sfx {len(sfx_events)}")
