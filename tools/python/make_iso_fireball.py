"""Animated fireball in the isometric party scene: the Mage casts, the fireball arcs across the room,
explodes over the 3x3 target area and destroys the Eye Tyrant.

Uses make_iso_party.py for the room/party and fireball/*.png for the effect sprites.
Outputs (in ./iso/): iso_fireball.gif, iso_fireball_still.png
"""
from PIL import Image, ImageDraw
import math, os, random
import make_iso_party as S

OUT = S.OUT
FB = Image.open(os.path.join(S.HERE, "fireball", "fireball_sheet.png")).convert("RGBA")
EX = Image.open(os.path.join(S.HERE, "fireball", "explosion_sheet.png")).convert("RGBA")
fb_frame = lambda i: FB.crop(((i % 6) * 16, 0, (i % 6) * 16 + 16, 16))
ex_frame = lambda i, size: EX.crop((i * 32, 0, i * 32 + 32, 32)).resize((size, size), Image.NEAREST)

mage_spr = S.heroes["Mage"]
mcx, mcy = S.center(*S.PARTY["Mage"])
GEM = (mcx - mage_spr.width // 2 + 13, mcy - mage_spr.height + 2 + 3)
tcx, tcy = S.center(*S.MONSTER)
TARGET = (tcx, tcy - 17)
FIRE = [(110, 20, 10), (200, 50, 20), (255, 130, 30), (255, 210, 80), (255, 250, 200)]


def add_glow(img, x, y, R, strength):
    px = img.load()
    for yy in range(int(y - R), int(y + R) + 1):
        for xx in range(int(x - R), int(x + R) + 1):
            if 0 <= xx < S.W and 0 <= yy < S.MAP_H:
                d = math.hypot(xx - x, yy - y) / R
                if d < 1:
                    g = strength * (1 - d) ** 2
                    c = px[xx, yy]
                    px[xx, yy] = (min(255, int(c[0] + 255 * g)), min(255, int(c[1] + 150 * g)),
                                  min(255, int(c[2] + 60 * g)), 255)


def dot(img, x, y, c, s=1):
    for i in range(s):
        for j in range(s):
            X, Y = int(x) + i, int(y) + j
            if 0 <= X < S.W and 0 <= Y < S.MAP_H:
                img.putpixel((X, Y), c + (255,))


def outlined_text(img, x, y, txt, col):
    d = ImageDraw.Draw(img)
    for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1), (1, 1)):
        d.text((x + ox, y + oy), txt, font=S.font, fill=(20, 10, 10))
    d.text((x, y), txt, font=S.font, fill=col)


def path(t):
    """Arc from the staff gem to the monster."""
    x = GEM[0] + (TARGET[0] - GEM[0]) * t
    y = GEM[1] + (TARGET[1] - GEM[1]) * t - 34 * math.sin(math.pi * t)
    return x, y


LOG_BEFORE = [("Rogue hits Eye Tyrant: 9", (170, 166, 180)), ("Eye Tyrant casts Fear!", (200, 120, 220))]
CASTING = [("MAGE CASTS FIREBALL!", (255, 170, 80)), ("", (0, 0, 0))]
timeline = []   # (frame_no, state, duration_ms)
f = 0

# 1) targeting (as in the still mock-up)
for _ in range(6):
    timeline.append((f, {}, 110)); f += 1

# 2) casting: gem charges, sparks spiral in
for k in range(5):
    g = 1 + k * 0.6
    def post(img, k=k, f=f):
        rnd = random.Random(k)
        for i in range(8):
            a = i / 8 * 2 * math.pi + k * 0.7
            r = 16 - k * 3
            dot(img, GEM[0] + math.cos(a) * r, GEM[1] + math.sin(a) * r * 0.7, FIRE[3 if i % 2 else 2])
        add_glow(img, *GEM, 6 + k * 2, 0.15 * k)
    timeline.append((f, {"gem": g, "show_move": False, "top": CASTING, "log": LOG_BEFORE,
                         "post": post}, 80)); f += 1

# 3) flight
NF = 10
trail = []
for k in range(NF):
    t = (k + 1) / NF
    x, y = path(t)
    trail = [(x, y)] + trail[:6]
    def post(img, x=x, y=y, k=k, trail=list(trail)):
        rnd = random.Random(k)
        for i, (tx, ty) in enumerate(trail[1:]):
            for _ in range(2):
                dot(img, tx + rnd.uniform(-3, 3), ty + rnd.uniform(-2, 2) + i * 0.6, FIRE[max(0, 3 - i // 2)],
                    2 if i < 2 else 1)
        add_glow(img, x, y, 16, 0.45)
        img.alpha_composite(fb_frame(k), (int(x - 8), int(y - 8)))
    timeline.append((f, {"gem": max(1, 3.4 - k * 0.8), "show_move": False, "show_active": False,
                         "top": CASTING, "log": LOG_BEFORE, "lights_extra": [(x, y + 12, 1.7, 95)],
                         "post": post}, 55)); f += 1

# 4) explosion over the 3x3 area, monster hurt -> death
mon = [(3, 0), (3, 1), (4, 1), (4, 2), (4, 3), (4, 4), (4, 5), (4, 6), (4, 7), (4, 8)]
shakes = [(3, -2), (-3, 2), (2, 1), (-1, -1), (1, 0)]
LOG_HIT = [("Fireball: 31 fire damage", (255, 190, 90)), ("Eye Tyrant is destroyed!", (255, 120, 90))]
for k in range(len(mon)):
    def post(img, k=k):
        # secondary bursts on the outer 8 tiles, slightly delayed
        for t in S.aoe:
            if t == S.MONSTER: continue
            kk = k - 1
            if 0 <= kk < 7:
                cx, cy = S.center(*t)
                img.alpha_composite(ex_frame(kk, 32), (cx - 16, cy - 22))
        if k < 7:  # main blast
            img.alpha_composite(ex_frame(k, 64), (tcx - 32, tcy - 46))
            add_glow(img, tcx, tcy - 14, 60, 0.55 * (1 - k / 7))
        if k >= 1:  # damage number floats up
            rise = min(k, 6) * 3
            outlined_text(img, tcx - 6, tcy - 52 - rise, "31", (255, 230, 90) if k % 2 else (255, 255, 255))
    fire = max(0.0, 1 - k / 6)
    timeline.append((f, {"monster": mon[k], "show_move": False, "show_active": False, "show_aoe": False,
                         "aoe_fire": fire, "scorch": k >= 3, "shake": shakes[k] if k < len(shakes) else None,
                         "gem": 1, "mage_slots": 1,
                         "lights_extra": [(tcx, tcy - 10, 3.2 * (1 - k / 10) ** 1.5, 170)],
                         "top": CASTING, "log": LOG_HIT, "post": post}, 85)); f += 1

# 5) aftermath: scorched floor, smoke wisps, next turn
for k in range(6):
    def post(img, k=k):
        rnd = random.Random(99)
        for i in range(10):
            x0, y0 = tcx + rnd.uniform(-30, 30), tcy + rnd.uniform(-10, 14)
            y = y0 - k * 2 - rnd.uniform(0, 4)
            if rnd.random() > k / 7:
                dot(img, x0 + math.sin(k + i) * 1.5, y, (90, 84, 82) if i % 2 else (64, 60, 60))
    timeline.append((f, {"monster": None, "show_move": False, "show_active": False, "show_aoe": False,
                         "scorch": True, "mage_slots": 1,
                         "top": [("FIGHTER'S TURN", (255, 220, 120)), ("Room cleared - loot the chest?", (200, 196, 210))],
                         "log": LOG_HIT, "post": post}, 130 if k < 5 else 1500)); f += 1

frames, durs = [], []
for fn, st, dur in timeline:
    frames.append(S.render(fn, st)); durs.append(dur)
big = [fr.resize((S.W * 2, S.H * 2), Image.NEAREST) for fr in frames]
big[0].save(os.path.join(OUT, "iso_fireball.gif"), save_all=True, append_images=big[1:], duration=durs, loop=0)
# sharp stills: mid-flight and the blast
frames[6 + 5 + 6].resize((S.W * 3, S.H * 3), Image.NEAREST).save(os.path.join(OUT, "iso_fireball_still.png"))
frames[6 + 5 + NF + 1].resize((S.W * 3, S.H * 3), Image.NEAREST).save(os.path.join(OUT, "iso_explosion_still.png"))
print("frames:", len(frames))
