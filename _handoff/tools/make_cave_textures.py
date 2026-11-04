"""Generate seamless 64x64 pixel-art cave textures (with spider webs) and an in-game style preview.

Outputs (in ./cave/):
  cave_wall_a.png, cave_wall_b.png        - plain rock walls (tile seamlessly)
  cave_wall_web_corner.png                - wall with a web in the top-left corner
  cave_wall_web_full.png                  - wall with a big web and dangling strands
  web_decal.png                           - transparent web to overlay on any surface
  cave_floor.png                          - bonus: floor texture for the preview
  tiling_preview.png                      - 3x3 tiling check
  corridor_preview.png                    - first-person view of a cave corridor
"""
from PIL import Image
import math, os, random

T = 64
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "cave")
os.makedirs(OUT, exist_ok=True)

ROCK = [(18, 14, 17), (34, 28, 30), (52, 43, 42), (72, 60, 54), (94, 79, 68), (120, 102, 85), (148, 128, 104)]
DAMP = [(22, 26, 24), (34, 44, 38), (48, 62, 50)]
WEB = (225, 225, 230)


def wrap(d):
    return d - T * round(d / T)


def tile_noise(seed, octaves=(4, 8, 16)):
    """Seamless fractal value noise in 0..1."""
    rnd = random.Random(seed)
    out = [[0.0] * T for _ in range(T)]
    total = 0
    for per in octaves:
        amp = 1 / per ** 0.5
        total += amp
        grid = [[rnd.random() for _ in range(per)] for _ in range(per)]
        cell = T / per
        for y in range(T):
            for x in range(T):
                gx, gy = x / cell, y / cell
                x0, y0 = int(gx), int(gy)
                fx, fy = gx - x0, gy - y0
                fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
                a = grid[y0 % per][x0 % per]; b = grid[y0 % per][(x0 + 1) % per]
                c = grid[(y0 + 1) % per][x0 % per]; d = grid[(y0 + 1) % per][(x0 + 1) % per]
                out[y][x] += amp * ((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy)
    return [[v / total for v in row] for row in out]


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def quant(v, x, y, pal):
    """Map 0..1 to a palette with light ordered dithering (classic pixel-art look)."""
    v = v * (len(pal) - 1) + (BAYER[y % 4][x % 4] / 16 - 0.5) * 0.55
    return pal[max(0, min(len(pal) - 1, round(v)))]


def rock(seed, cells=13, damp=0.0, scale=1.0):
    rnd = random.Random(seed)
    pts = [(rnd.uniform(0, T), rnd.uniform(0, T) * scale, rnd.uniform(-0.12, 0.12)) for _ in range(cells)]
    noise = tile_noise(seed + 1)
    fine = tile_noise(seed + 2, (16, 32))
    height = [[0.0] * T for _ in range(T)]
    edge = [[0.0] * T for _ in range(T)]
    tone = [[0.0] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            ds = sorted((math.hypot(wrap(x - px), wrap(y - py) * 1.15), t) for px, py, t in pts)
            e = ds[1][0] - ds[0][0]
            edge[y][x] = e
            tone[y][x] = ds[0][1]
            height[y][x] = min(e / 6, 1) ** 0.7 + noise[y][x] * 0.5
    img = Image.new("RGBA", (T, T))
    px = img.load()
    dn = tile_noise(seed + 3, (2, 4, 8))
    for y in range(T):
        for x in range(T):
            light = height[(y - 1) % T][(x - 1) % T] - height[(y + 1) % T][(x + 1) % T]
            v = 0.42 + tone[y][x] + light * 0.9 + (fine[y][x] - 0.5) * 0.25 + (noise[y][x] - .5) * .3
            if edge[y][x] < 1.3:
                v = 0.02  # crack
            elif edge[y][x] < 2.3:
                v -= 0.18
            c = quant(max(0, min(1, v)), x, y, ROCK)
            # damp streaks (vertical, darker, a little green)
            if damp and dn[y][x] > 1 - damp and v > 0.05:
                c = quant(max(0, min(1, v * 0.8)), x, y, DAMP)
            px[x, y] = c + (255,)
    return img


# ---------- Spider webs ----------
def line(img, x0, y0, x1, y1, color, alpha, sag=0.0, cx=None, cy=None):
    px = img.load()
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 1.5) + 1
    for i in range(n + 1):
        t = i / n
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        if sag and cx is not None:  # pull the middle of the thread toward the web centre
            s = sag * math.sin(math.pi * t)
            x += (cx - x) * s; y += (cy - y) * s
        X, Y = round(x), round(y)
        if 0 <= X < img.width and 0 <= Y < img.height:
            r, g, b, a = px[X, Y]
            na = alpha / 255
            px[X, Y] = (round(r * (1 - na) + color[0] * na), round(g * (1 - na) + color[1] * na),
                        round(b * (1 - na) + color[2] * na), max(a, alpha))


def web(img, cx, cy, a0, a1, radius, rings, seed, broken=0.15, dangling=()):
    rnd = random.Random(seed)
    n = max(5, int((a1 - a0) / 26))
    angs = [a0 + (a1 - a0) * i / (n - 1) + rnd.uniform(-5, 5) for i in range(n)]
    ends = []
    for a in angs:
        r = radius * rnd.uniform(0.85, 1.05)
        ends.append((math.radians(a), r))
        line(img, cx, cy, cx + math.cos(math.radians(a)) * r, cy + math.sin(math.radians(a)) * r, WEB, 150)
    for k in range(1, rings + 1):
        f = k / (rings + 0.5)
        for i in range(len(ends) - 1):
            if rnd.random() < broken:
                continue
            (a, r), (b, s) = ends[i], ends[i + 1]
            ra, rb = r * f * rnd.uniform(.95, 1.05), s * f * rnd.uniform(.95, 1.05)
            line(img, cx + math.cos(a) * ra, cy + math.sin(a) * ra, cx + math.cos(b) * rb, cy + math.sin(b) * rb,
                 WEB, 120 + round(40 * (1 - f)), sag=0.12, cx=cx, cy=cy)
    for x, y0, length in dangling:  # loose strands hanging down
        line(img, x, y0, x + rnd.uniform(-1, 1), y0 + length, WEB, 110)
        img.load()[round(x), round(y0 + length)] = (240, 240, 245, 200)  # dew/blob at end
    # dense hub
    for dx, dy in ((0, 0), (1, 0), (0, 1), (-1, 0), (0, -1)):
        X, Y = round(cx + dx), round(cy + dy)
        if 0 <= X < img.width and 0 <= Y < img.height:
            img.load()[X, Y] = (235, 235, 240, 220)


def shadow_under_web(img, web_layer):
    """Darken the rock 1px down-right of each web thread so the web reads against the wall."""
    px, w = img.load(), web_layer.load()
    for y in range(T - 1):
        for x in range(T - 1):
            if w[x, y][3] > 60 and w[x + 1, y + 1][3] < 60:
                r, g, b, a = px[x + 1, y + 1]
                px[x + 1, y + 1] = (r * 2 // 3, g * 2 // 3, b * 2 // 3, a)


def with_web(base, **kw):
    layer = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    web(layer, **kw)
    out = base.copy()
    shadow_under_web(out, layer)
    out.alpha_composite(layer)
    return out, layer


# ---------- Build textures ----------
wall_a = rock(11)
wall_b = rock(29, cells=11, damp=0.22)
floor = rock(53, cells=22)
floor = Image.eval(floor, lambda v: v)  # same style, smaller stones
wall_web_corner, _ = with_web(wall_a, cx=0, cy=0, a0=2, a1=88, radius=58, rings=6, seed=3)
wall_web_full, _ = with_web(wall_b, cx=32, cy=24, a0=-180, a1=180, radius=30, rings=7, seed=8, broken=0.2,
                            dangling=[(20, 44, 9), (41, 46, 14), (30, 52, 7)])
decal = Image.new("RGBA", (T, T), (0, 0, 0, 0))
web(decal, cx=32, cy=30, a0=-180, a1=180, radius=31, rings=7, seed=5, broken=0.12)

tex = {"cave_wall_a": wall_a, "cave_wall_b": wall_b, "cave_wall_web_corner": wall_web_corner,
       "cave_wall_web_full": wall_web_full, "web_decal": decal, "cave_floor": floor}
for name, im in tex.items():
    im.save(os.path.join(OUT, name + ".png"))

# ---------- Tiling check: 3x3 of wall_a ----------
tp = Image.new("RGBA", (T * 6 + 8, T * 3), (40, 40, 48, 255))
for j in range(3):
    for i in range(3):
        tp.paste(wall_a, (i * T, j * T))
        tp.paste(wall_b, (T * 3 + 8 + i * T, j * T))
tp.resize((tp.width * 3, tp.height * 3), Image.NEAREST).save(os.path.join(OUT, "tiling_preview.png"))

# ---------- First-person corridor preview (simple raycaster) ----------
MAP = [
    "1111111111",
    "1........1",
    "2.11211..2",
    "1.3...4..1",
    "1.11.112.1",
    "1....1...1",
    "1111111111",
]
WALLS = {"1": wall_a, "2": wall_b, "3": wall_web_full, "4": wall_web_corner}
RW, RH = 320, 200
pos_x, pos_y = 1.5, 5.5
dir_a = math.radians(-90)  # looking "north" up the corridor
dx, dy = math.cos(dir_a), math.sin(dir_a)
plx, ply = -dy * 0.66, dx * 0.66
view = Image.new("RGB", (RW, RH))
vp = view.load()
zbuf = [0.0] * RW
texpx = {k: v.load() for k, v in WALLS.items()}
fpx, cpx = floor.load(), wall_a.load()


def fog(c, d):
    f = math.exp(-d * 0.32)
    return tuple(round(v * f) for v in c[:3])


for sx in range(RW):
    cam = 2 * sx / RW - 1
    rx, ry = dx + plx * cam, dy + ply * cam
    mx, my = int(pos_x), int(pos_y)
    ddx = abs(1 / rx) if rx else 1e30
    ddy = abs(1 / ry) if ry else 1e30
    stx, sdx = (-1, (pos_x - mx) * ddx) if rx < 0 else (1, (mx + 1 - pos_x) * ddx)
    sty, sdy = (-1, (pos_y - my) * ddy) if ry < 0 else (1, (my + 1 - pos_y) * ddy)
    while True:
        if sdx < sdy:
            sdx += ddx; mx += stx; side = 0
        else:
            sdy += ddy; my += sty; side = 1
        if MAP[my][mx] != ".":
            break
    dist = (sdx - ddx) if side == 0 else (sdy - ddy)
    zbuf[sx] = dist
    wx = (pos_y + dist * ry) if side == 0 else (pos_x + dist * rx)
    tx = int((wx - math.floor(wx)) * T)
    h = int(RH / dist)
    top = RH // 2 - h // 2
    tp_ = texpx[MAP[my][mx]]
    for sy in range(max(0, top), min(RH, top + h)):
        c = tp_[tx, min(T - 1, int((sy - top) / h * T))]
        if side:
            c = tuple(v * 3 // 4 for v in c[:3])
        vp[sx, sy] = fog(c, dist)
    # floor + ceiling
    for sy in range(min(RH, top + h), RH):
        rd = RH / (2 * sy - RH)
        fx, fy = pos_x + rd * rx, pos_y + rd * ry
        u, v = int((fx % 1) * T), int((fy % 1) * T)
        vp[sx, sy] = fog(fpx[u, v], rd)
        vp[sx, RH - 1 - sy] = fog(tuple(c * 2 // 3 for c in cpx[u, v][:3]), rd)

# Billboard sprite: the eye monster floating up ahead, if it exists
sprite_path = os.path.join(HERE, "eye_tyrant_32.png")
if os.path.exists(sprite_path):
    spr = Image.open(sprite_path).convert("RGBA")
    sp = spr.load()
    sxw, syw = 1.5, 1.9
    rel_x, rel_y = sxw - pos_x, syw - pos_y
    inv = 1 / (plx * dy - dx * ply)
    tx_, ty_ = inv * (dy * rel_x - dx * rel_y), inv * (-ply * rel_x + plx * rel_y)
    scr_x = int(RW / 2 * (1 + tx_ / ty_))
    size = int(RH / ty_ * 0.7)
    for i in range(size):
        col = scr_x - size // 2 + i
        if 0 <= col < RW and ty_ < zbuf[col]:
            for j in range(size):
                row = RH // 2 - size // 2 - size // 6 + j
                c = sp[int(i / size * 32), int(j / size * 32)]
                if c[3] and 0 <= row < RH:
                    vp[col, row] = fog(c, ty_)

view.resize((RW * 3, RH * 3), Image.NEAREST).save(os.path.join(OUT, "corridor_preview.png"))
print("done:", ", ".join(tex))
