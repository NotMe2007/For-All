# ZenX loading-splash images for the SeneX icon pack.
#   py make_zenx_logo.py      (then: cd .. && node build_icons.mjs)
#
# zenx-logo-src.png is the 400x400 ZX logo drawn on black. Writes into ../extras:
#   zenx-logo.png  the badge: dark disc inside the ring, glow outside keyed out of
#                  the black (alpha = brightness) so it sits on any game background
#   zenx-glow.png  white mask of the bright strokes (ZX, ring, streak) - the shine sweep
#   zenx-ring.png  white glow ring at the same spot as the logo's ring - the ripple
# Both masks are white so SeneX can tint them with ImageColor3.
import math
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "extras")
SIZE = 256           # output px
CX, CY, R = 200, 200, 150  # ring centre / radius in the source (measured)
CROP = 184           # half-size of the crop around the centre (keeps the outer glow)
DISC = 0.92          # opacity of the dark disc inside the ring


def smooth(edge0, edge1, x):
    t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


src = Image.open(os.path.join(HERE, "zenx-logo-src.png")).convert("RGB")
src = src.crop((CX - CROP, CY - CROP, CX + CROP, CY + CROP))
n = src.size[0]
spx = src.load()

logo = Image.new("RGBA", (n, n))
glow = Image.new("LA", (n, n))
lpx, gpx = logo.load(), glow.load()
for y in range(n):
    for x in range(n):
        r, g, b = spx[x, y]
        lum = max(r, g, b) / 255
        dist = math.hypot(x + 0.5 - CROP, y + 0.5 - CROP)
        a = max(lum, DISC * (1 - smooth(R - 6, R - 1, dist)))
        if a > 0:
            lpx[x, y] = (min(255, round(r / a)), min(255, round(g / a)), min(255, round(b / a)), round(a * 255))
        else:
            lpx[x, y] = (0, 0, 0, 0)
        gpx[x, y] = (255, round(255 * smooth(0.25, 0.85, lum)))

ring = Image.new("LA", (n, n))
rpx = ring.load()
for y in range(n):
    for x in range(n):
        d = math.hypot(x + 0.5 - CROP, y + 0.5 - CROP) - R
        a = math.exp(-(d / 2.5) ** 2) + 0.35 * math.exp(-(d / 11) ** 2)
        rpx[x, y] = (255, round(255 * min(a, 1.0)))

for name, im in (("zenx-logo", logo), ("zenx-glow", glow), ("zenx-ring", ring)):
    im.resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(OUT, name + ".png"), optimize=True)
    print(name, os.path.getsize(os.path.join(OUT, name + ".png")), "bytes")
