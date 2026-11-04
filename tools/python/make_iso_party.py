"""Isometric, grid-based dungeon mock-up: a 4-member party (fighter, rogue, cleric, mage) facing an Eye Tyrant.

Outputs (in ./iso/):
  party_sprites.png   - the four hero sprites, enlarged
  iso_scene.png       - still of the scene (3x)
  iso_scene.gif       - animated: flickering torches, idle bobbing, pulsing target area
"""
from PIL import Image, ImageDraw, ImageFont
import math, os, random

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "iso")
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- palette
P = {
    "K": (20, 16, 24), "w": (240, 240, 250),
    "m": (200, 205, 215), "M": (140, 145, 160), "n": (90, 92, 110),
    "r": (180, 40, 40), "R": (120, 24, 30),
    "s": (232, 180, 140), "S": (190, 130, 100),
    "b": (120, 78, 44), "B": (70, 44, 26), "y": (230, 190, 70),
    "g": (60, 92, 62), "G": (36, 56, 40), "h": (92, 128, 82),
    "l": (122, 84, 52), "L": (80, 54, 34),
    "o": (232, 226, 210), "O": (168, 162, 160), "u": (64, 96, 176), "U": (38, 56, 112), "c": (104, 62, 30),
    "p": (112, 70, 172), "P": (66, 40, 110), "q": (154, 114, 214),
    "e": (226, 226, 232), "E": (168, 168, 180), "f": (255, 170, 60), "F": (255, 242, 190),
}

FIGHTER = [
    "..............",
    "....mmmm......",
    "...mmmmmM...w.",
    "...mMMMMn...w.",
    "...nKKKKn...w.",
    "...nssSSn...w.",
    "....nnnn....w.",
    "..nMmmmmMn..w.",
    "MMMMMrrrrMn.w.",
    "MbbbMrrRrMn.w.",
    "MbyybMrRrMn.w.",
    "MbyybMrRrMn.w.",
    "MbbbMrrRrMnyyy",
    ".MbbMyyyyMnns.",
    "..MM.rrrrRn.b.",
    "....rrrRR.....",
    "....MMnMn.....",
    "....mMnmM.....",
    "....mMnmM.....",
    "....MMnMM.....",
    "...BBB.BBB....",
    "...BBB.BBB....",
]
ROGUE = [
    "..............",
    ".....hhh......",
    "....hgggG.....",
    "...hggggGG....",
    "...gGSSSSG....",
    "...gGwSwSG....",
    "...GgGGGGgG...",
    "..gGgllllgGg..",
    ".gGgLllllLgGg.",
    ".gGLlLLLLlLGg.",
    ".gGLllyllLLGg.",
    ".gGsLlllLLsGg.",
    ".gmsLLLLLLsmg.",
    ".gw.LLLLLL.wg.",
    ".Gw.lllLLL.wG.",
    ".GG.llLLL..GG.",
    "....LLLLL.....",
    "....LL.LL.....",
    "....LL.LL.....",
    "....LL.LL.....",
    "...BBB.BBB....",
    "...BBB.BBB....",
]
CLERIC = [
    "..............",
    "....cccc......",
    "...cccccc.....",
    "...csssSc.....",
    "...sKsKSS..M..",
    "...ssssSS.MmM.",
    "....sSSS..MMM.",
    "..uoooooOu.b..",
    ".uoooyoooOub..",
    ".uooyyyooOUb..",
    ".uOooyooOOUb..",
    ".sOoooooOOUs..",
    "..uoooooOOU...",
    "..uooooOOOU...",
    "..uuuyyyuuU...",
    "..ooooooOOO...",
    "..oooooOOOO...",
    "..ooooOOOOO...",
    "..ooooOOOOO...",
    ".ooooOOOOOOO..",
    "...BB...BB....",
    "..............",
]
MAGE = [
    ".....p........",
    ".....pp.....F.",
    "....qpP....fFf",
    "....qppP....f.",
    "...qpypPP...b.",
    ".PPPPPPPPPP.b.",
    "...sKsKSS...b.",
    "...eeeeEE...b.",
    "..peeeeeEp..b.",
    ".ppPeeeEPpp.b.",
    ".pqpPeEPppPsb.",
    ".pqppPPpppPsb.",
    ".pqpppyppPP.b.",
    ".sqpppypPPs.b.",
    "..qpppypPP..b.",
    "..qppppPPP..b.",
    "..qppppPPPP.b.",
    "..qpppPPPPP.b.",
    ".qqppPPPPPPPb.",
    ".qppPPPPPPPPb.",
    "...BB...BB..B.",
    "..............",
]
CHEST = [
    "..BBBBBBBBBB..",
    ".BbbbbbbbbbbB.",
    "BbbbbbbbbbbbbB",
    "yyyyyyyyyyyyyy",
    "BbbbbbyybbbbbB",
    "BbbbbbyKbbbbbB",
    "BbbbbbyybbbbbB",
    "BbbbbbbbbbbbbB",
    "yyyyyyyyyyyyyy",
    ".BBBBBBBBBBBB.",
]
BONES = [
    "..eee.......",
    ".eKeKe......",
    ".eeeee.e..e.",
    "..eEe...ee..",
    "...........",
    "..e...e.ee..",
    "...eee..e...",
]


def grid_sprite(rows, outline=True):
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w + 2, len(rows) + 2), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                px[x + 1, y + 1] = P[ch] + (255,)
    if outline:
        src = img.copy().load()
        for y in range(img.height):
            for x in range(img.width):
                if src[x, y][3] == 0 and any(
                        0 <= x + dx < img.width and 0 <= y + dy < img.height and src[x + dx, y + dy][3]
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    px[x, y] = P["K"] + (255,)
    return img


heroes = {"Fighter": grid_sprite(FIGHTER), "Rogue": grid_sprite(ROGUE),
          "Cleric": grid_sprite(CLERIC), "Mage": grid_sprite(MAGE)}
chest, bones = grid_sprite(CHEST), grid_sprite(BONES)
monster_sheet = Image.open(os.path.join(HERE, "eye_tyrant_sheet.png")).convert("RGBA")

# hero line-up preview
lu = Image.new("RGBA", (4 * 24, 30), (40, 38, 46, 255))
for i, im in enumerate(heroes.values()):
    lu.alpha_composite(im, (i * 24 + 4, 3))
lu.resize((lu.width * 8, lu.height * 8), Image.NEAREST).save(os.path.join(OUT, "party_sprites.png"))

# ---------------------------------------------------------------- scene setup
W, H = 400, 300
MAP_H = 240
N = 9
OX, OY = 200, 68
WALL = 40
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
FLOOR_PAL = [(22, 20, 26), (38, 36, 44), (54, 52, 60), (72, 69, 76), (92, 88, 94), (114, 108, 112)]
BRICK_PAL = [(26, 24, 30), (46, 43, 50), (64, 60, 66), (84, 78, 82), (106, 98, 98), (128, 118, 114)]


def q(v, x, y, pal):
    v = v * (len(pal) - 1) + (BAYER[y % 4][x % 4] / 16 - 0.5) * 0.6
    return pal[max(0, min(len(pal) - 1, round(v)))]


def corner(gx, gy):
    """Screen position of a tile's top corner."""
    return OX + (gx - gy) * 16, OY + (gx + gy) * 8


def center(gx, gy):
    x, y = corner(gx, gy)
    return x, y + 8


def tile_pixels(gx, gy):
    x0, y0 = corner(gx, gy)
    for py in range(16):
        yy = py + 0.5 - 8
        hw = 16 * (1 - abs(yy) / 8)
        for px in range(int(16 - hw + 0.5), int(16 + hw + 0.5)):
            dx, dy = px + 0.5 - 16, yy
            yield x0 - 16 + px, y0 + py, dx, dy


def draw_floor(img, gx, gy, dark=False):
    px = img.load()
    rnd = random.Random(gx * 131 + gy * 17)
    base = rnd.uniform(0.38, 0.6) * (0.5 if dark else 1)
    crack = rnd.random() < 0.25
    for X, Y, dx, dy in tile_pixels(gx, gy):
        e = abs(dx) / 16 + abs(dy) / 8
        v = base + rnd.uniform(-0.06, 0.06)
        if e > 0.88: v = 0.02
        elif e > 0.74: v += 0.14 if dy < 0 else -0.16
        if crack and abs(dx - dy * 1.6 - 3) < 0.6 and e < 0.6: v = 0.1
        if 0 <= X < W and 0 <= Y < H:
            px[X, Y] = q(max(0, min(1, v)), X, Y, FLOOR_PAL) + (255,)


def draw_wall(img, gx, gy, faces):
    """Wall block on tile (gx,gy). faces: 'L' = face toward +gy (lower-left), 'R' = toward +gx (lower-right)."""
    px = img.load()
    x, y = corner(gx, gy)
    rnd = random.Random(gx * 77 + gy * 991)
    tone = [[rnd.uniform(-0.12, 0.12) for _ in range(4)] for _ in range(8)]
    for face in faces:
        for u in range(16):
            for v in range(WALL):
                if face == "L":
                    X = x - 16 + u
                    Y = y + 8 + int(u * 0.5) - WALL + v
                    light = 0.62
                else:
                    X = x + u
                    Y = y + 16 - int(u * 0.5) - WALL + v
                    light = 0.44
                row = v // 8
                bu = (u + (4 if row % 2 else 0))
                val = light + tone[row % 8][(bu // 8) % 4]
                if v % 8 == 0 or bu % 8 == 0: val = 0.08          # mortar
                elif v % 8 == 1: val += 0.08                       # top bevel of brick
                if 0 <= X < W and 0 <= Y < H:
                    px[X, Y] = q(max(0, min(1, val)), X, Y, BRICK_PAL) + (255,)
    # top cap
    for X, Y, dx, dy in tile_pixels(gx, gy):
        Y -= WALL
        e = abs(dx) / 16 + abs(dy) / 8
        if 0 <= X < W and 0 <= Y < H:
            px[X, Y] = q(0.25 if e < 0.8 else 0.12, X, Y, BRICK_PAL) + (255,)


def overlay_tile(img, gx, gy, color, alpha, border_alpha):
    px = img.load()
    for X, Y, dx, dy in tile_pixels(gx, gy):
        e = abs(dx) / 16 + abs(dy) / 8
        a = border_alpha if e > 0.8 else alpha
        if 0 <= X < W and 0 <= Y < H and e < 0.97:
            c = px[X, Y]
            px[X, Y] = tuple(int(c[k] * (1 - a) + color[k] * a) for k in range(3)) + (255,)


def web(img, cx, cy, seed):
    rnd = random.Random(seed)
    px = img.load()
    def put(x, y, a):
        X, Y = round(x), round(y)
        if 0 <= X < W and 0 <= Y < H:
            c = px[X, Y]
            px[X, Y] = tuple(int(c[k] * (1 - a) + 220 * a) for k in range(3)) + (255,)
    angs = [math.radians(a) for a in (100, 125, 150, 175, 30, 55, 80)]
    lens = [rnd.uniform(18, 26) for _ in angs]
    for a, L in zip(angs, lens):
        for i in range(int(L * 1.5)):
            t = i / (L * 1.5)
            put(cx + math.cos(a) * L * t, cy + math.sin(a) * L * t * 0.8, 0.5)
    order = sorted(range(len(angs)), key=lambda i: angs[i])
    for k in range(1, 5):
        f = k / 5
        for i, j in zip(order, order[1:]):
            a, b = angs[i], angs[j]
            for s in range(12):
                t = s / 11
                ang = a + (b - a) * t
                L = (lens[i] + (lens[j] - lens[i]) * t) * f * (1 - 0.08 * math.sin(math.pi * t))
                put(cx + math.cos(ang) * L, cy + math.sin(ang) * L * 0.8, 0.4)


def blit(img, spr, x, y, light=1.0, tint=(1, 1, 1)):
    """Paste sprite with its own lighting multiplier."""
    s = spr.copy()
    sp = s.load()
    for j in range(s.height):
        for i in range(s.width):
            r, g, b, a = sp[i, j]
            if a:
                sp[i, j] = (min(255, int(r * light * tint[0])), min(255, int(g * light * tint[1])),
                            min(255, int(b * light * tint[2])), a)
    img.alpha_composite(s, (int(x), int(y)))


def shadow(img, x, y, rx, ry):
    px = img.load()
    for Y in range(int(y - ry), int(y + ry) + 1):
        for X in range(int(x - rx), int(x + rx) + 1):
            if ((X - x) / rx) ** 2 + ((Y - y) / ry) ** 2 < 1 and 0 <= X < W and 0 <= Y < H:
                c = px[X, Y]
                px[X, Y] = (c[0] // 2, c[1] // 2, c[2] // 2, 255)


def flame(img, x, y, f):
    rnd = random.Random(f * 7 + x)
    px = img.load()
    hgt = 7 + rnd.randint(0, 2)
    for j in range(hgt):
        t = j / hgt
        half = (1 - t) * 2.4 + rnd.uniform(-0.4, 0.4)
        sway = math.sin(f * 1.7 + j * 0.6) * t * 1.2
        for i in range(-3, 4):
            if abs(i - sway) <= half:
                c = (255, 245, 190) if abs(i - sway) < half * 0.4 and t < 0.6 else (255, 180, 60) if t < 0.75 else (220, 70, 30)
                X, Y = int(x + i), int(y - j)
                if 0 <= X < W and 0 <= Y < H: px[X, Y] = c + (255,)


def bracket(img, x, y):
    d = ImageDraw.Draw(img)
    d.rectangle((x - 1, y, x + 1, y + 5), fill=(40, 30, 26))
    d.rectangle((x - 2, y - 1, x + 2, y), fill=(70, 50, 36))


# ---------------------------------------------------------------- level content
WALL_R = [(gx, -1) for gx in range(N)]          # back-right wall
WALL_L = [(-1, gy) for gy in range(N)]          # back-left wall
DOOR = (5, -1)                                   # doorway in back-right wall
PARTY = {"Fighter": (4, 5), "Rogue": (7, 5), "Cleric": (3, 7), "Mage": (5, 7)}
MONSTER = (5, 2)
CHEST_AT = (8, 0)
BONES_AT = (0, 1)
ACTIVE = "Mage"
occupied = set(PARTY.values()) | {MONSTER, CHEST_AT}
move_range = [(x, y) for x in range(N) for y in range(N)
              if 0 < abs(x - PARTY[ACTIVE][0]) + abs(y - PARTY[ACTIVE][1]) <= 2 and (x, y) not in occupied]
aoe = [(MONSTER[0] + i, MONSTER[1] + j) for i in (-1, 0, 1) for j in (-1, 0, 1)]


def face_center(gx, gy, face):
    x, y = corner(gx, gy)
    return (x - 8, y + 12 - WALL // 2 - 4) if face == "L" else (x + 8, y + 12 - WALL // 2 - 4)


TORCHES = [face_center(2, -1, "L"), face_center(8, -1, "L"), face_center(-1, 2, "R"), face_center(-1, 6, "R")]
STATS = {"Fighter": (34, 42, None), "Rogue": (19, 27, None), "Cleric": (24, 30, (3, 4)), "Mage": (14, 18, (2, 4))}

font = ImageFont.load_default_imagefont()


def light_at(x, y, lights):
    amb = (0.34, 0.36, 0.5)
    r, g, b = amb
    for lx, ly, I, R in lights:
        d = math.hypot(x - lx, (y - ly) * 1.6)
        if d < R:
            w = I * (1 - d / R) ** 1.6
            r += w; g += w * 0.68; b += w * 0.36
    return r, g, b


def render(f, st=None):
    st = st or {}
    rnd = random.Random(f)
    img = Image.new("RGBA", (W, H), (8, 6, 10, 255))
    # floor + doorway
    for gy in range(N):
        for gx in range(N):
            draw_floor(img, gx, gy)
    draw_floor(img, *DOOR, dark=True)
    draw_floor(img, DOOR[0], DOOR[1] - 1, dark=True)
    # walls (back to front)
    draw_wall(img, -1, -1, "")
    for gx, gy in WALL_R:
        if (gx, gy) != DOOR:
            draw_wall(img, gx, gy, "L")
    for gx, gy in WALL_L:
        draw_wall(img, gx, gy, "R")
    for t in TORCHES:
        bracket(img, t[0], t[1] + 2)
    web(img, corner(0, 0)[0], corner(0, 0)[1] - WALL + 8, 4)
    if st.get('scorch'):
        spx = img.load()
        for t in aoe:
            tc = center(*t); mc = center(*MONSTER)
            for X, Y, dx, dy in tile_pixels(*t):
                dd = math.hypot(X - mc[0], (Y - mc[1]) * 2) / 40
                if BAYER[Y % 4][X % 4] / 16 < 1.1 - dd:
                    c = spx[X, Y]; spx[X, Y] = (c[0] // 3, c[1] // 3, c[2] // 3, 255)

    # lighting pass on the environment
    flick = [1.25 + 0.18 * math.sin(f * 2.3 + i * 1.7) + rnd.uniform(-0.05, 0.05) for i in range(len(TORCHES))]
    mx_, my_ = center(*PARTY["Mage"])
    lights = [(tx, ty, flick[i], 120) for i, (tx, ty) in enumerate(TORCHES)] + [(mx_ + 6, my_ - 24, 0.55 * st.get('gem', 1), 50 + 20 * (st.get('gem', 1) - 1))] + st.get('lights_extra', [])
    px = img.load()
    for y in range(MAP_H):
        for x in range(W):
            c = px[x, y]
            lr, lg, lb = light_at(x, y, lights)
            px[x, y] = (min(255, int(c[0] * lr)), min(255, int(c[1] * lg)), min(255, int(c[2] * lb)), 255)

    # tactical overlays
    pulse = 0.5 + 0.5 * math.sin(f / 8 * 2 * math.pi)
    for t in (move_range if st.get('show_move', True) else []):
        overlay_tile(img, *t, (90, 150, 255), 0.18, 0.45)
    for t in (aoe if st.get('show_aoe', True) else []):
        if 0 <= t[0] < N and 0 <= t[1] < N:
            overlay_tile(img, *t, (255, 110, 40), 0.22 + 0.12 * pulse, 0.6)
    if st.get('aoe_fire'):
        for t in aoe:
            overlay_tile(img, *t, (255, 200, 90), 0.75 * st['aoe_fire'], 0.9 * st['aoe_fire'])
    if st.get('show_active', True):
        overlay_tile(img, *PARTY[ACTIVE], (255, 220, 90), 0.15, 0.55 + 0.4 * pulse)

    # objects sorted by depth
    objs = [(sum(BONES_AT), "bones", BONES_AT), (sum(CHEST_AT), "chest", CHEST_AT),
            (sum(MONSTER) + 0.1, "monster", MONSTER)] * (st.get('monster', 0) is not None) + [(sum(p) + 0.2, n, p) for n, p in PARTY.items()]
    for _, kind, (gx, gy) in sorted(objs):
        cx, cy = center(gx, gy)
        lr, lg, lb = light_at(cx, cy - 10, lights)
        L = (lr + lg + lb) / 3
        tint = (lr / L, lg / L, lb / L)
        if kind == "bones":
            blit(img, bones, cx - 7, cy - 6, L, tint)
        elif kind == "chest":
            shadow(img, cx, cy + 2, 9, 4)
            blit(img, chest, cx - 8, cy - 10, L, tint)
        elif kind == "monster":
            row, col = st.get('monster') or (0, f % 8)
            if row != 4 or col < 5: shadow(img, cx, cy + 1, 10, 4)
            bob = round(math.sin(f / 8 * 2 * math.pi) * 1.5) if row == 0 else 0
            spr = monster_sheet.crop((col * 32, row * 32, col * 32 + 32, row * 32 + 32))
            blit(img, spr, cx - 16, cy - 33 + bob, L * 1.1, tint)
        else:
            spr = heroes[kind]
            shadow(img, cx, cy + 1, 7, 3)
            bob = 1 if (f + {"Fighter": 0, "Rogue": 1, "Cleric": 2, "Mage": 3}[kind]) % 4 < 2 else 0
            blit(img, spr, cx - spr.width // 2, cy - spr.height + 2 - bob, L * 1.05, tint)
            if kind == "Mage":  # glowing gem on the staff
                gx_, gy_ = cx - spr.width // 2 + 13, cy - spr.height + 2 - bob + 3
                for yy in range(gy_ - 6, gy_ + 7):
                    for xx in range(gx_ - 6, gx_ + 7):
                        d = math.hypot(xx - gx_, yy - gy_) / 6
                        if d < 1 and 0 <= xx < W and 0 <= yy < H:
                            c = img.getpixel((xx, yy)); g = 0.5 * (1 - d) ** 2 * (0.8 + 0.2 * pulse) * st.get('gem', 1)
                            img.putpixel((xx, yy), (min(255, int(c[0] + 255 * g)), min(255, int(c[1] + 150 * g)),
                                                    min(255, int(c[2] + 60 * g)), 255))

    # torch flames (emissive) + soft glow
    for i, (tx, ty) in enumerate(TORCHES):
        for yy in range(ty - 12, ty + 8):
            for xx in range(tx - 10, tx + 11):
                d = math.hypot(xx - tx, (yy - ty + 3) * 1.2) / 11
                if d < 1:
                    c = img.getpixel((xx, yy)); g = 0.35 * (1 - d) ** 2 * flick[i]
                    img.putpixel((xx, yy), (min(255, int(c[0] + 255 * g)), min(255, int(c[1] + 160 * g)),
                                            min(255, int(c[2] + 60 * g)), 255))
        flame(img, tx, ty + 1, f + i * 3)

    if 'post' in st:
        st['post'](img)
    if st.get('shake'):
        sx_, sy_ = st['shake']
        region = img.crop((0, 0, W, MAP_H))
        img.paste((8, 6, 10, 255), (0, 0, W, MAP_H))
        img.paste(region, (sx_, sy_))

    # ---------------- UI ----------------
    d = ImageDraw.Draw(img)
    top = st.get('top', [("MAGE'S TURN", (255, 220, 120)), ("Cast Fireball: 3x3 area, 8d6 fire", (200, 196, 210))])
    log = st.get('log', [("Rogue hits Eye Tyrant: 9", (170, 166, 180)), ("Eye Tyrant casts Fear!", (200, 120, 220))])
    for k, (txt, col) in enumerate(top):
        d.text((8, 6 + k * 12), txt, font=font, fill=col)
    for k, (txt, col) in enumerate(log):
        d.text((W - 150, 6 + k * 12), txt, font=font, fill=col)
    d.rectangle((0, MAP_H, W, H), fill=(28, 24, 32))
    d.line((0, MAP_H, W, MAP_H), fill=(90, 80, 70))
    d.line((0, MAP_H + 1, W, MAP_H + 1), fill=(10, 8, 12))
    for i, (name, spr) in enumerate(heroes.items()):
        bx, by = 6 + i * 79, MAP_H + 6
        active = name == ACTIVE
        d.rectangle((bx, by, bx + 76, by + 48), fill=(40, 36, 46), outline=(255, 210, 90) if active else (70, 64, 76))
        port = spr.crop((0, 0, spr.width, 12)).resize((spr.width * 2, 24), Image.NEAREST)
        d.rectangle((bx + 3, by + 3, bx + 34, by + 28), fill=(22, 20, 26))
        img.alpha_composite(port, (bx + 3, by + 4))
        d.text((bx + 36, by + 3), name, font=font, fill=(235, 230, 240) if active else (190, 186, 196))
        hp, mhp, slots = STATS[name]
        if name == 'Mage' and 'mage_slots' in st: slots = (st['mage_slots'], slots[1])
        d.rectangle((bx + 3, by + 32, bx + 73, by + 36), fill=(60, 20, 24))
        d.rectangle((bx + 3, by + 32, bx + 3 + int(70 * hp / mhp), by + 36), fill=(200, 50, 50))
        d.text((bx + 36, by + 16), f"{hp}/{mhp}", font=font, fill=(220, 120, 120))
        if slots:
            for k in range(slots[1]):
                c = (110, 150, 255) if k < slots[0] else (50, 54, 80)
                d.rectangle((bx + 3 + k * 9, by + 40, bx + 9 + k * 9, by + 44), fill=c)
    ax = 6 + 4 * 79
    for j, label in enumerate(("Attack", "Spell", "Item", "Wait")):
        y0 = MAP_H + 6 + j * 12
        sel = label == "Spell"
        d.rectangle((ax, y0, W - 6, y0 + 10), fill=(70, 50, 30) if sel else (40, 36, 46),
                    outline=(255, 210, 90) if sel else (70, 64, 76))
        d.text((ax + 4, y0), ("> " if sel else "  ") + label, font=font, fill=(255, 230, 160) if sel else (180, 176, 190))
    return img.convert("RGB")


if __name__ == "__main__":
    frames = [render(f) for f in range(8)]
    frames[0].resize((W * 3, H * 3), Image.NEAREST).save(os.path.join(OUT, "iso_scene.png"))
    big = [fr.resize((W * 2, H * 2), Image.NEAREST) for fr in frames]
    big[0].save(os.path.join(OUT, "iso_scene.gif"), save_all=True, append_images=big[1:], duration=130, loop=0)
    print("ok")
