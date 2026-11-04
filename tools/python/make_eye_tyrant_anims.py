"""Generate animation frames for the 32x32 Eye Tyrant sprite.

Outputs:
  eye_tyrant_sheet.png      - sprite sheet, one row per animation, 32x32 cells (game-ready)
  anim_<name>.gif           - enlarged preview of each animation
  eye_tyrant_showcase.gif   - all animations played in sequence
"""
from PIL import Image, ImageDraw
import math, os, random

W = H = 32
OUT = os.path.dirname(os.path.abspath(__file__))

CLEAR = (0, 0, 0, 0)
OUTLINE = (34, 16, 40, 255)
SKIN = [(74, 36, 84, 255), (112, 58, 120, 255), (150, 86, 150, 255), (190, 124, 178, 255)]
EYE_W = [(200, 190, 170, 255), (245, 240, 225, 255)]
IRIS = [(170, 30, 30, 255), (235, 80, 40, 255), (255, 190, 60, 255)]
IRIS_HOT = [(235, 80, 40, 255), (255, 190, 60, 255), (255, 250, 200, 255)]
PUPIL = (10, 5, 10, 255)
MOUTH = (40, 10, 25, 255)
TOOTH = (235, 225, 200, 255)

BASE_TIPS = [(4, 8), (9, 4), (16, 2), (23, 4), (28, 8)]


def draw(bob=0, sway=0.0, open_=1.0, look=0, hot=False, mouth_open=0, squash=0, x_eyes=False):
    """Render one frame. bob: vertical offset; sway: stalk wiggle phase;
    open_: central eye openness 0..1; look: pupil x-offset; hot: attack glow;
    mouth_open: extra mouth height; squash: body squash in px; x_eyes: dead eyes."""
    img = Image.new("RGBA", (W, H), CLEAR)
    px = img.load()

    def put(x, y, c):
        x, y = round(x), round(y)
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = c

    cx, cy, r = 16, 20 + bob, 10
    rx, ry = r + squash * 0.6, r - squash

    # Eyestalks
    tips = []
    for i, (tx, ty) in enumerate(BASE_TIPS):
        tx = tx + round(math.sin(sway + i * 1.3) * 1.2)
        ty = ty + bob + squash + round(math.cos(sway + i * 1.3) * 0.6)
        tips.append((tx, ty))
        ang = math.atan2(ty - cy, tx - cx)
        sx, sy = cx + math.cos(ang) * (rx - 1), cy + math.sin(ang) * (ry - 1)
        mx, my = (sx + tx) / 2 + (tx - cx) * 0.15, (sy + ty) / 2 - 1
        for k in range(41):
            t = k / 40
            put((1-t)**2*sx + 2*(1-t)*t*mx + t*t*tx, (1-t)**2*sy + 2*(1-t)*t*my + t*t*ty, SKIN[1])

    # Body
    lx, ly, lz = -0.5, -0.6, 0.62
    for y in range(H):
        for x in range(W):
            dx, dy = (x + .5 - cx) / rx, (y + .5 - cy) / ry
            d2 = dx*dx + dy*dy
            if d2 <= 1:
                light = dx*lx + dy*ly + math.sqrt(1 - d2)*lz
                put(x, y, SKIN[0 if light < .15 else 1 if light < .5 else 2 if light < .85 else 3])

    # Central eye
    ex, ey = 16, 17 + bob + squash // 2
    erx, ery = (5.6, 4.2) if hot else (5.0, 3.6)
    iris = IRIS_HOT if hot else IRIS
    if x_eyes:
        for d in range(-2, 3):
            put(ex + d, ey + d, PUPIL); put(ex + d, ey - d, PUPIL)
    elif open_ < 0.2:
        for x in range(ex - 4, ex + 5):
            put(x, ey, SKIN[0])
    else:
        oy = ery * open_
        for y in range(H):
            for x in range(W):
                dx, dy = (x + .5 - ex) / erx, (y + .5 - ey) / oy
                if dx*dx + dy*dy <= 1:
                    put(x, y, EYE_W[1] if dy < .35 else EYE_W[0])
        for y in range(H):
            for x in range(W):
                d = math.hypot(x + .5 - ex - look, y + .5 - ey)
                if d <= 2.6 and abs(y + .5 - ey) <= oy:
                    put(x, y, iris[2] if d < 1.2 else iris[1] if d < 2 else iris[0])
        ph = max(1, round(2.5 * open_))
        for y in range(ey - ph, ey + ph):
            put(ex + look, y, PUPIL)
            if hot:
                put(ex + look - 1, y, PUPIL)
        if open_ > 0.6:
            put(ex - 2 + look, ey - 2, EYE_W[1])
        for x in range(ex - 4, ex + 5):
            put(x, ey - round(oy) - 1, SKIN[0])

    # Mouth
    base = 24 + bob + squash
    for x in range(10, 23):
        t = (x - 16) / 6.5
        y0 = base + round(1.5 * (1 - t*t))
        top, bot = y0 - 1 - mouth_open, y0 + 1
        for y in range(top, bot + 1):
            put(x, y, MOUTH)
        put(x, top if x % 2 == 0 else bot, TOOTH)

    # Stalk eyes
    for tx, ty in tips:
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            put(tx + dx, ty + dy, EYE_W[1])
        if x_eyes:
            put(tx, ty, PUPIL)
        else:
            put(tx, ty, IRIS_HOT[2] if hot else IRIS[0])

    return outline(img)


def outline(img):
    src = img.copy().load()
    px = img.load()
    for y in range(H):
        for x in range(W):
            if src[x, y][3] == 0:
                for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
                    if 0 <= nx < W and 0 <= ny < H and src[nx, ny][3] and src[nx, ny] != OUTLINE:
                        px[x, y] = OUTLINE
                        break
    return img


def tint(img, color, amount):
    out = img.copy()
    px = out.load()
    for y in range(H):
        for x in range(W):
            r, g, b, a = px[x, y]
            if a and (r, g, b, a) != OUTLINE:
                px[x, y] = (round(r + (color[0]-r)*amount), round(g + (color[1]-g)*amount),
                            round(b + (color[2]-b)*amount), a)
    return out


def shift(img, dx, dy):
    out = Image.new("RGBA", (W, H), CLEAR)
    out.alpha_composite(img, (dx, dy)) if dx >= 0 and dy >= 0 else out.paste(img, (dx, dy), img)
    return out


def explode(img, t, seed=7):
    """Break the sprite into pixel chunks flying outward; t in 0..1."""
    rnd = random.Random(seed)
    src = img.load()
    out = Image.new("RGBA", (W, H), CLEAR)
    px = out.load()
    for y in range(0, H, 2):
        for x in range(0, W, 2):
            c = src[x, y] if src[x, y][3] else src[min(x+1, W-1), y]
            if not c[3]:
                continue
            vx, vy = (x - 16) * 0.5 + rnd.uniform(-3, 3), (y - 18) * 0.5 + rnd.uniform(-4, 1)
            nx = x + vx * t * 2.2
            ny = y + vy * t * 2.2 + 14 * t * t  # gravity
            if rnd.random() < t * 0.9:  # chunks vanish over time
                continue
            alpha = round(255 * (1 - t * 0.6))
            size = 2 if t < 0.5 else 1
            for oy in range(size):
                for ox in range(size):
                    X, Y = round(nx) + ox, round(ny) + oy
                    if 0 <= X < W and 0 <= Y < H:
                        px[X, Y] = c[:3] + (alpha,)
    return out


# ---------- Build animations ----------
anims = {}

# Idle: gentle float + stalk sway, eye glancing around
anims["idle"] = [draw(bob=round(math.sin(i / 8 * 2 * math.pi)), sway=i / 8 * 2 * math.pi,
                      look=[0, 0, 1, 1, 0, 0, -1, -1][i]) for i in range(8)]

# Blink
anims["blink"] = [draw(open_=o) for o in (1, 0.6, 0.1, 0.1, 0.6, 1)]

# Attack: eye widens and glows, mouth opens, lunges toward player
anims["attack"] = [
    draw(),
    draw(open_=0.7, bob=1),                       # wind up (squint)
    draw(hot=True, mouth_open=1, bob=-1),
    draw(hot=True, mouth_open=2, bob=-1),
    draw(hot=True, mouth_open=2),
    draw(mouth_open=1),
]

# Hurt: white flash, red flash, recoil
anims["hurt"] = [
    tint(draw(open_=0.1), (255, 255, 255), 0.85),
    tint(shift(draw(open_=0.1, squash=1), 1, 0), (255, 40, 40), 0.5),
    draw(open_=0.6, squash=1),
    draw(),
]

# Death: flash, squash, eyes go X, then burst
dead = draw(x_eyes=True, squash=2, mouth_open=2)
anims["death"] = [
    tint(draw(open_=0.1), (255, 255, 255), 0.85),
    draw(x_eyes=True, squash=1, mouth_open=1),
    dead,
    tint(dead, (255, 255, 255), 0.6),
] + [explode(dead, t) for t in (0.15, 0.35, 0.55, 0.75, 0.95)]

# ---------- Sprite sheet ----------
cols = max(len(f) for f in anims.values())
sheet = Image.new("RGBA", (cols * W, len(anims) * H), CLEAR)
for row, frames in enumerate(anims.values()):
    for col, f in enumerate(frames):
        sheet.alpha_composite(f, (col * W, row * H))
sheet.save(os.path.join(OUT, "eye_tyrant_sheet.png"))

# ---------- Preview GIFs ----------
S = 8
def bg():
    b = Image.new("RGBA", (W, H), (46, 44, 52, 255))
    for y in range(H):
        for x in range(W):
            if (x // 8 + y // 8) % 2:
                b.putpixel((x, y), (52, 50, 58, 255))
    return b

def frame_img(f, label):
    b = bg(); b.alpha_composite(f)
    big = b.resize((W * S, H * S), Image.NEAREST).convert("RGB")
    canvas = Image.new("RGB", (W * S, H * S + 24), (24, 22, 28))
    canvas.paste(big, (0, 24))
    ImageDraw.Draw(canvas).text((8, 6), label, fill=(230, 220, 240))
    return canvas

speed = {"idle": 140, "blink": 70, "attack": 110, "hurt": 90, "death": 110}
for name, frames in anims.items():
    imgs = [frame_img(f, name) for f in frames]
    imgs[0].save(os.path.join(OUT, f"anim_{name}.gif"), save_all=True, append_images=imgs[1:],
                 duration=speed[name], loop=0)

# Showcase: idle x2, blink, idle, attack, idle, hurt, idle, death, pause
seq = []
def add(name, reps=1):
    for _ in range(reps):
        for f in anims[name]:
            seq.append((frame_img(f, name), speed[name]))
add("idle", 2); add("blink"); add("idle"); add("attack"); add("idle"); add("hurt"); add("idle"); add("death")
seq.append((frame_img(Image.new("RGBA", (W, H), CLEAR), "death"), 900))
seq[0][0].save(os.path.join(OUT, "eye_tyrant_showcase.gif"), save_all=True,
               append_images=[s[0] for s in seq[1:]], duration=[s[1] for s in seq], loop=0)

# Large static sheet preview for inspection
sb = Image.new("RGBA", sheet.size, (46, 44, 52, 255)); sb.alpha_composite(sheet)
sb.resize((sheet.width * 6, sheet.height * 6), Image.NEAREST).save(os.path.join(OUT, "sheet_preview.png"))
print("frames:", {k: len(v) for k, v in anims.items()})
