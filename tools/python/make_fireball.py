"""Wizard fireball: game-ready sprite sheets + an in-cave preview with dynamic fire lighting.

Outputs (in ./fireball/):
  fireball_sheet.png    - 6-frame looping fireball, 16x16 per frame
  explosion_sheet.png   - 7-frame impact explosion, 32x32 per frame
  sprites_preview.png   - both sheets enlarged
  fireball_scene.gif    - first-person: wizard casts, fireball lights up the cave, hits the eye monster
  fireball_still.png    - one sharp mid-flight frame
"""
from PIL import Image
import math, os, random

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "fireball")
os.makedirs(OUT, exist_ok=True)

FIRE = [(110, 20, 10), (200, 50, 20), (255, 130, 30), (255, 210, 80), (255, 250, 200)]
SMOKE = [(40, 34, 34), (70, 60, 58), (100, 88, 82)]
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


# ---------------- Fireball sprite (16x16, 6 frames) ----------------
def fireball_frame(f, S=16):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = img.load()
    c = S / 2 - 0.5
    ph = f / 6 * 2 * math.pi
    for y in range(S):
        for x in range(S):
            dx, dy = x - c, y - c
            d, a = math.hypot(dx, dy), math.atan2(dy, dx)
            edge = 5.2 + 0.9 * math.sin(a * 3 + ph) + 0.6 * math.sin(a * 5 - ph * 2) + 0.4 * math.sin(a * 7 + ph * 3)
            if d < edge:
                k = d / edge - (0.08 * math.sin(ph + a * 2))
                i = 4 if k < 0.3 else 3 if k < 0.55 else 2 if k < 0.8 else 1
                px[x, y] = FIRE[i] + (255,)
    rnd = random.Random(f)
    for _ in range(4):  # sparks
        a, r = rnd.uniform(0, 2 * math.pi), rnd.uniform(6, 7.5)
        X, Y = round(c + math.cos(a) * r), round(c + math.sin(a) * r)
        if 0 <= X < S and 0 <= Y < S:
            px[X, Y] = FIRE[rnd.choice((2, 3))] + (255,)
    return img


# ---------------- Explosion sprite (32x32, 7 frames) ----------------
def explosion_frame(k, n=7, S=32):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = img.load()
    t = k / (n - 1)
    rnd = random.Random(42)
    c = S / 2 - 0.5
    R = 4 + 11 * t ** 0.6
    for y in range(S):
        for x in range(S):
            d, a = math.hypot(x - c, y - c), math.atan2(y - c, x - c)
            edge = R * (1 + 0.18 * math.sin(a * 6 + k) + 0.1 * math.sin(a * 11 - k * 2))
            if d < edge:
                rel = d / edge
                heat = (1 - t) * 1.3 - rel * 0.6
                if heat > 0.9: col = FIRE[4]
                elif heat > 0.6: col = FIRE[3]
                elif heat > 0.35: col = FIRE[2]
                elif heat > 0.1: col = FIRE[1]
                else:
                    # smoke: thin out with an ordered dither as it dissipates (thinnest in the middle)
                    density = (1.15 - t) * (0.45 + 0.75 * rel)
                    if BAYER[y % 4][x % 4] / 16 >= density:
                        continue
                    col = SMOKE[2] if heat > -0.2 else SMOKE[1]
                px[x, y] = col + (255,)
    for i in range(18):  # flying embers
        a, sp = rnd.uniform(0, 2 * math.pi), rnd.uniform(0.7, 1.3)
        r = (R + 2) * sp * (0.6 + t)
        X, Y = round(c + math.cos(a) * r), round(c + math.sin(a) * r + 6 * t * t)
        if 0 <= X < S and 0 <= Y < S and rnd.random() > t * 0.8:
            px[X, Y] = FIRE[3 if t < 0.4 else 2] + (255,)
    return img


fb_frames = [fireball_frame(f) for f in range(6)]
ex_frames = [explosion_frame(k) for k in range(7)]


def sheet(frames, S):
    s = Image.new("RGBA", (S * len(frames), S), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.alpha_composite(f, (i * S, 0))
    return s


fs, es = sheet(fb_frames, 16), sheet(ex_frames, 32)
fs.save(os.path.join(OUT, "fireball_sheet.png"))
es.save(os.path.join(OUT, "explosion_sheet.png"))
pv = Image.new("RGBA", (es.width, 16 + 4 + 32), (30, 26, 30, 255))
pv.alpha_composite(fs, (0, 0)); pv.alpha_composite(es, (0, 20))
pv.resize((pv.width * 6, pv.height * 6), Image.NEAREST).save(os.path.join(OUT, "sprites_preview.png"))

# ---------------- Scene: raycaster with dynamic point lights ----------------
CAVE = os.path.join(HERE, "cave")
load = lambda n: Image.open(os.path.join(CAVE, n + ".png")).convert("RGBA")
WT = {"1": load("cave_wall_a").load(), "2": load("cave_wall_b").load(),
      "3": load("cave_wall_web_full").load(), "4": load("cave_wall_web_corner").load()}
FLOOR, CEIL = load("cave_floor").load(), load("cave_wall_a").load()
T = 64
monster_sheet = Image.open(os.path.join(HERE, "eye_tyrant_sheet.png")).convert("RGBA")
mframe = lambda row, col: monster_sheet.crop((col * 32, row * 32, col * 32 + 32, row * 32 + 32))

MAP = ["1111111111", "1........1", "2.11211..2", "1.3...4..1", "1.11.112.1", "1....1...1", "1111111111"]
RW, RH = 320, 200
PX, PY = 1.5, 5.5
DX, DY = 0.0, -1.0
PLX, PLY = -DY * 0.66, DX * 0.66
INV = 1 / (PLX * DY - DX * PLY)
FIRE_COL = (1.0, 0.55, 0.22)


def ambient(d):
    return 0.45 * math.exp(-d * 0.35)


def lit(c, x, y, z, d, lights):
    """Texture colour at world point (x,y,z), seen from distance d."""
    l_r = l_g = l_b = ambient(d)
    for (lx, ly, lz, I, R) in lights:
        dd = math.sqrt((x - lx) ** 2 + (y - ly) ** 2 + (z - lz) ** 2)
        if dd < R:
            w = I * (1 - dd / R) ** 2
            l_r += w * FIRE_COL[0]; l_g += w * FIRE_COL[1]; l_b += w * FIRE_COL[2]
    return (min(255, int(c[0] * l_r)), min(255, int(c[1] * l_g)), min(255, int(c[2] * l_b)))


def render_world(lights):
    img = Image.new("RGB", (RW, RH))
    vp = img.load()
    zbuf = [0.0] * RW
    for sx in range(RW):
        cam = 2 * sx / RW - 1
        rx, ry = DX + PLX * cam, DY + PLY * cam
        mx, my = int(PX), int(PY)
        ddx = abs(1 / rx) if rx else 1e30
        ddy = abs(1 / ry) if ry else 1e30
        stx, sdx = (-1, (PX - mx) * ddx) if rx < 0 else (1, (mx + 1 - PX) * ddx)
        sty, sdy = (-1, (PY - my) * ddy) if ry < 0 else (1, (my + 1 - PY) * ddy)
        while True:
            if sdx < sdy: sdx += ddx; mx += stx; side = 0
            else: sdy += ddy; my += sty; side = 1
            if MAP[my][mx] != ".": break
        dist = (sdx - ddx) if side == 0 else (sdy - ddy)
        zbuf[sx] = dist
        hx, hy = PX + dist * rx, PY + dist * ry
        wx = hy if side == 0 else hx
        tx = int((wx - math.floor(wx)) * T)
        h = RH / dist
        top = RH / 2 - h / 2
        tex = WT[MAP[my][mx]]
        # nudge the hit point off the wall toward the viewer so lights in front illuminate it
        ox, oy = hx - rx * 0.02, hy - ry * 0.02
        for sy in range(max(0, int(top)), min(RH, int(top + h))):
            v = (sy - top) / h
            c = tex[tx, min(T - 1, int(v * T))]
            if side: c = (c[0] * 3 // 4, c[1] * 3 // 4, c[2] * 3 // 4)
            vp[sx, sy] = lit(c, ox, oy, 1 - v, dist, lights)
        for sy in range(min(RH, int(top + h)), RH):
            rd = RH / (2 * sy - RH)
            fx, fy = PX + rd * rx, PY + rd * ry
            u, w = int((fx % 1) * T), int((fy % 1) * T)
            vp[sx, sy] = lit(FLOOR[u, w], fx, fy, 0, rd, lights)
            c = CEIL[u, w]
            vp[sx, RH - 1 - sy] = lit((c[0] * 2 // 3, c[1] * 2 // 3, c[2] * 2 // 3), fx, fy, 1, rd, lights)
    return img, zbuf


def project(wx, wy, wz):
    rx, ry = wx - PX, wy - PY
    tx, ty = INV * (DY * rx - DX * ry), INV * (-PLY * rx + PLX * ry)
    return RW / 2 * (1 + tx / ty), RH / 2 - (wz - 0.5) * RH / ty, ty


def billboard(img, zbuf, spr, wx, wy, wz, size_w, lights, emissive=False):
    sx, sy, depth = project(wx, wy, wz)
    if depth <= 0.05: return
    size = max(1, int(size_w * RH / depth))
    sp, vp = spr.load(), img.load()
    W_, H_ = spr.size
    for i in range(size):
        col = int(sx - size / 2 + i)
        if not (0 <= col < RW) or depth >= zbuf[col]: continue
        for j in range(size):
            row = int(sy - size / 2 + j)
            if not (0 <= row < RH): continue
            c = sp[int(i / size * W_), int(j / size * H_)]
            if not c[3]: continue
            if emissive:
                f = 0.6 + 0.4 * math.exp(-depth * 0.2)
                c3 = (int(c[0] * f), int(c[1] * f), int(c[2] * f))
            else:
                c3 = lit(c, wx, wy, wz, depth, lights)
            if c[3] < 255:
                b = vp[col, row]; a = c[3] / 255
                c3 = tuple(int(b[k] * (1 - a) + c3[k] * a) for k in range(3))
            vp[col, row] = c3


def glow(img, wx, wy, wz, radius_w, strength):
    """Cheap bloom: add warm light around a bright object on screen."""
    sx, sy, depth = project(wx, wy, wz)
    if depth <= 0.05: return
    R = radius_w * RH / depth
    vp = img.load()
    for y in range(max(0, int(sy - R)), min(RH, int(sy + R) + 1)):
        for x in range(max(0, int(sx - R)), min(RW, int(sx + R) + 1)):
            d = math.hypot(x - sx, y - sy) / R
            if d < 1:
                g = strength * (1 - d) ** 2
                c = vp[x, y]
                vp[x, y] = (min(255, int(c[0] + 255 * g)), min(255, int(c[1] + 140 * g)), min(255, int(c[2] + 50 * g)))


def staff(img, gem):
    """First-person wizard staff + gloved hand, bottom right. gem = glow 0..1+."""
    vp = img.load()
    WOOD = [(20, 12, 16), (112, 72, 40), (150, 104, 60)]
    x0, y0, x1, y1 = 268, 200, 244, 128
    for i in range(200):
        t = i / 199
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        for k in range(-4, 5):
            X, Y = int(x + k), int(y)
            if 0 <= X < RW and 0 <= Y < RH:
                c = WOOD[0] if abs(k) == 4 else WOOD[2] if k == -2 else WOOD[1]
                if (Y // 3 + k) % 7 == 0: c = WOOD[0]  # grain
                vp[X, Y] = c
    # claw holding the gem
    for a in (-0.9, 0, 0.9):
        for r in range(0, 11):
            X, Y = int(x1 + math.sin(a) * r * 0.9), int(y1 - math.cos(a) * r * 0.6 - r * 0.3)
            for k in (-1, 0, 1):
                if 0 <= X + k < RW and 0 <= Y < RH: vp[X + k, Y] = WOOD[0] if k else WOOD[1]
    gx, gy = x1, y1 - 9
    for y in range(gy - 7, gy + 8):
        for x in range(gx - 7, gx + 8):
            d = math.hypot(x - gx, y - gy)
            if d < 6:
                i = 4 if d < 2 + gem else 3 if d < 3.5 + gem else 2
                vp[x, y] = FIRE[min(4, i)] if gem > 0.2 else [(120, 40, 30), (170, 60, 40), (220, 110, 70), (250, 170, 120), (255, 220, 190)][i]
    # robe sleeve (purple with gold trim), coming from the bottom-right corner
    LINE = (20, 12, 16)
    ROBE = [(44, 24, 70), (70, 40, 108), (98, 60, 146), (128, 86, 178)]
    GOLD = [(150, 104, 30), (220, 170, 60)]
    for y in range(150, RH):
        for x in range(240, RW):
            e = ((x - 306) / 44) ** 2 + ((y - 214) / 34) ** 2
            if e < 1:
                if e > 0.93: c = LINE
                elif e > 0.78: c = GOLD[1] if e < 0.86 else GOLD[0]
                else:
                    k = (x - 270) / 50 - (y - 180) / 60  # lit from upper left
                    c = ROBE[3 if k < 0.1 else 2 if k < 0.4 else 1 if k < 0.7 else 0]
                vp[x, y] = c
    # leather-gloved fist wrapped around the staff
    GLOVE = [(40, 24, 18), (72, 44, 30), (104, 68, 44), (136, 96, 64)]
    staff_x = lambda y: 268 - (200 - y) / 3

    def blob(cx, cy, rx, ry, light_fn):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                e = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if e < 1 and 0 <= x < RW and 0 <= y < RH:
                    vp[x, y] = LINE if e > 0.72 else GLOVE[light_fn(x - cx, y - cy)]

    # back of the hand, behind the fingers
    blob(staff_x(176) + 10, 176, 12, 17, lambda dx, dy: 1 if dx < 2 else 0)
    # four curled fingers wrapped around the staff, top to bottom
    for i, y in enumerate((160, 169, 178, 187)):
        blob(staff_x(y) - 3 + (i % 2), y, 9, 5.2, lambda dx, dy: 3 if (dy < -1 and dx < 2) else 2 if dy < 1.5 else 1)
    # thumb hooked over the top of the fist
    blob(staff_x(152) + 5, 152, 8, 4.5, lambda dx, dy: 3 if dy < -0.5 else 2)
    if gem > 0:
        R = 14 + gem * 14
        for y in range(max(0, int(gy - R)), min(RH, int(gy + R))):
            for x in range(max(0, int(gx - R)), min(RW, int(gx + R))):
                d = math.hypot(x - gx, y - gy) / R
                if d < 1:
                    g = 0.5 * gem * (1 - d) ** 2
                    c = vp[x, y]
                    vp[x, y] = (min(255, int(c[0] + 255 * g)), min(255, int(c[1] + 140 * g)), min(255, int(c[2] + 50 * g)))


# ---------- Timeline ----------
MON = (1.5, 1.9, 0.6)          # monster position
START = (1.66, 4.95, 0.36)     # leaves the staff tip
frames, durations = [], []


def frame(fb=None, fb_f=0, embers=(), monster=("idle", 0), explosion=None, gem=0.0, cast_light=0.0, dur=80):
    lights = []
    if cast_light: lights.append((1.62, 5.2, 0.4, cast_light, 1.8))
    if fb: lights.append((*fb, 1.9 + 0.3 * math.sin(fb_f * 2.1), 2.6))
    if explosion is not None: lights.append((MON[0], MON[1] + 0.3, MON[2], 4.5 * (1 - explosion / 7) ** 1.5, 3.2))
    img, zb = render_world(lights)
    # sprites, far to near
    if monster:
        row = {"idle": 0, "hurt": 3, "death": 4}[monster[0]]
        billboard(img, zb, mframe(row, monster[1]), *MON, 0.75, lights)
    if explosion is not None and explosion < 7:
        billboard(img, zb, ex_frames[explosion], MON[0], MON[1] + 0.25, MON[2], 1.1, lights, emissive=True)
        glow(img, MON[0], MON[1] + 0.25, MON[2], 1.0, 0.6 * (1 - explosion / 7))
    for k, (ex, ey, ez) in enumerate(embers):
        sx, sy, d = project(ex, ey, ez)
        s = max(1, int(0.05 * RH / d))
        for i in range(s):
            for j in range(s):
                X, Y = int(sx) + i, int(sy) + j
                if 0 <= X < RW and 0 <= Y < RH and d < zb[X]:
                    img.putpixel((X, Y), FIRE[2 - min(2, k // 2)])
    if fb:
        glow(img, *fb, 0.55, 0.45)
        billboard(img, zb, fb_frames[fb_f % 6], *fb, 0.28, lights, emissive=True)
    staff(img, gem)
    frames.append(img); durations.append(dur)


for i in range(4): frame(monster=("idle", i), dur=110)
frame(monster=("idle", 4), gem=0.6, cast_light=0.5)
frame(monster=("idle", 5), gem=1.6, cast_light=1.4)
N = 11
path = []
for i in range(N):
    t = (i + 1) / N
    p = (START[0] + (MON[0] - START[0]) * t, START[1] + (MON[1] + 0.35 - START[1]) * t,
         START[2] + (MON[2] - START[2]) * t + 0.08 * math.sin(math.pi * t))
    path.append(p)
    trail = [(p[0] + random.uniform(-.03, .03), p[1] + 0.12 * (k + 1), p[2] + random.uniform(-.03, .03))
             for k in range(5) if i - k > 0]
    frame(fb=p, fb_f=i, embers=trail, monster=("idle", (6 + i) % 8), gem=max(0, 1.0 - i * 0.35),
          cast_light=max(0, 0.8 - i * 0.4), dur=60)
mon_seq = [("hurt", 0), ("hurt", 1), ("death", 1), ("death", 2), ("death", 3), ("death", 4), ("death", 5),
           ("death", 6), ("death", 7), ("death", 8)]
for k, m in enumerate(mon_seq):
    frame(monster=m, explosion=k if k < 7 else None, dur=90)
frame(monster=None, dur=1200)

big = [f.resize((RW * 2, RH * 2), Image.NEAREST) for f in frames]
big[0].save(os.path.join(OUT, "fireball_scene.gif"), save_all=True, append_images=big[1:], duration=durations, loop=0)
frames[6 + 2].resize((RW * 3, RH * 3), Image.NEAREST).save(os.path.join(OUT, "fireball_still.png"))
frames[6 + N + 1].resize((RW * 3, RH * 3), Image.NEAREST).save(os.path.join(OUT, "explosion_still.png"))
print("frames:", len(frames))
