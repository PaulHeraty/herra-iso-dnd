"""Generate a 32x32 pixel-art floating eye monster sprite (plus a scaled preview)."""
from PIL import Image
import math, os

W = H = 32
OUT = os.path.dirname(os.path.abspath(__file__))

# Palette
CLEAR = (0, 0, 0, 0)
OUTLINE = (34, 16, 40, 255)
SKIN = [(74, 36, 84, 255), (112, 58, 120, 255), (150, 86, 150, 255), (190, 124, 178, 255)]  # dark -> light
EYE_W = [(200, 190, 170, 255), (245, 240, 225, 255)]
IRIS = [(170, 30, 30, 255), (235, 80, 40, 255), (255, 190, 60, 255)]
PUPIL = (10, 5, 10, 255)
MOUTH = (40, 10, 25, 255)
TOOTH = (235, 225, 200, 255)

img = Image.new("RGBA", (W, H), CLEAR)
px = img.load()

def put(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = c

# --- Eyestalks (drawn first, behind body) ---
cx, cy, r = 16, 19, 10
stalk_tips = [(4, 7), (9, 3), (16, 1), (23, 3), (28, 7)]
for tx, ty in stalk_tips:
    # start on body surface, gentle curve toward tip
    ang = math.atan2(ty - cy, tx - cx)
    sx, sy = cx + math.cos(ang) * (r - 1), cy + math.sin(ang) * (r - 1)
    mx, my = (sx + tx) / 2 + (tx - cx) * 0.15, (sy + ty) / 2 - 1
    for i in range(41):
        t = i / 40
        x = (1 - t) ** 2 * sx + 2 * (1 - t) * t * mx + t ** 2 * tx
        y = (1 - t) ** 2 * sy + 2 * (1 - t) * t * my + t ** 2 * ty
        put(round(x), round(y), SKIN[1])

# --- Body sphere with top-left lighting ---
lx, ly, lz = -0.5, -0.6, 0.62
for y in range(H):
    for x in range(W):
        dx, dy = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
        d2 = dx * dx + dy * dy
        if d2 <= 1:
            dz = math.sqrt(1 - d2)
            light = dx * lx + dy * ly + dz * lz
            idx = 0 if light < 0.15 else 1 if light < 0.5 else 2 if light < 0.85 else 3
            put(x, y, SKIN[idx])

# --- Central eye ---
ex, ey, erx, ery = 16, 16, 5.0, 3.6
for y in range(H):
    for x in range(W):
        dx, dy = (x + 0.5 - ex) / erx, (y + 0.5 - ey) / ery
        if dx * dx + dy * dy <= 1:
            put(x, y, EYE_W[1] if dy < 0.35 else EYE_W[0])
for y in range(H):
    for x in range(W):
        d = math.hypot(x + 0.5 - ex, y + 0.5 - ey)
        if d <= 2.6:
            put(x, y, IRIS[2] if d < 1.2 else IRIS[1] if d < 2.0 else IRIS[0])
for y in range(14, 19):  # slit pupil
    put(16, y, PUPIL)
put(14, 14, EYE_W[1])  # glint
# eyelid line
for x in range(12, 21):
    put(x, 12, SKIN[0])

# --- Mouth with teeth ---
for x in range(10, 23):
    t = (x - 16) / 6.5
    y0 = 23 + round(1.5 * (1 - t * t))
    for y in range(y0 - 1, y0 + 2):
        put(x, y, MOUTH)
    if x % 2 == 0:
        put(x, y0 - 1, TOOTH)  # upper teeth
    else:
        put(x, y0 + 1, TOOTH)  # lower teeth

# --- Small stalk eyes ---
for tx, ty in stalk_tips:
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if abs(dx) + abs(dy) < 2:
                put(tx + dx, ty + dy, EYE_W[1])
    put(tx, ty, IRIS[0])

# --- 1px dark outline around everything ---
src = img.copy().load()
for y in range(H):
    for x in range(W):
        if src[x, y][3] == 0:
            for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
                if 0 <= nx < W and 0 <= ny < H and src[nx, ny][3] and src[nx, ny] != OUTLINE:
                    px[x, y] = OUTLINE
                    break

img.save(os.path.join(OUT, "eye_tyrant_32.png"))

# Scaled preview on a dark-stone background, nearest-neighbour so pixels stay crisp
S = 12
bg = Image.new("RGBA", (W, H), (46, 44, 52, 255))
for y in range(H):
    for x in range(W):
        if (x // 8 + y // 8) % 2:
            bg.putpixel((x, y), (52, 50, 58, 255))
bg.alpha_composite(img)
bg.resize((W * S, H * S), Image.NEAREST).save(os.path.join(OUT, "eye_tyrant_preview.png"))
print("done")
