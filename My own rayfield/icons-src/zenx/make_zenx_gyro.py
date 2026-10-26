# ZenX loading-splash animation for the SeneX icon pack (the gyro loader).
#   py make_zenx_gyro.py      (then: cd .. && node build_icons.mjs)
#
# zenx-gyro-src.gif is the 400x400 ZX logo with orbit rings spinning round it, drawn on
# black (60 frames, 30 ms each). Roblox can't play a GIF, so SeneX plays it as a flipbook:
# the frames go onto 1024x1024 sheets (4 x 4 frames of 256 px) and the splash steps
# ImageRectOffset through them. Writes into ../extras:
#   zenx-gyro-1.png .. zenx-gyro-N.png  the sheets, frames left to right, top to bottom
# and zenx/gyro.json - the layout, which build_icons.mjs puts into pack.json as `gyro`.
# Like zenx-logo.png the glow is keyed out of the black (alpha = brightness) over a dark
# disc, so it sits on any game background.
import json
import math
import os
from PIL import Image, ImageSequence

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "extras")
FRAME = 256          # px per frame on the sheets
COLS = 4             # 4 x 4 frames = 1024 x 1024 px per sheet
PER_SHEET = COLS * COLS
CX, CY = 200, 200    # centre of the logo in the source (measured)
CROP = 190           # half-size of the crop around it (the orbits reach ~175)
DISC_R = 168         # dark disc radius in the source px - just inside the orbit sphere
DISC = 0.94          # opacity of the dark disc
DISC_RGB = (8, 6, 20)
BLACK = 3            # GIF dither noise below this counts as black


def smooth(edge0, edge1, x):
    t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


gif = Image.open(os.path.join(HERE, "zenx-gyro-src.gif"))
frames, durations = [], []
for frame in ImageSequence.Iterator(gif):
    durations.append(frame.info.get("duration", 30))
    # the source is lit on black, i.e. already premultiplied: resize it as it is and
    # only then key the alpha out, so the scaled glow gets no dark fringes
    rgb = frame.convert("RGB").crop((CX - CROP, CY - CROP, CX + CROP, CY + CROP))
    frames.append(rgb.resize((FRAME, FRAME), Image.LANCZOS))

scale = FRAME / (2 * CROP)
disc_r = DISC_R * scale
centre = FRAME / 2
disc = [[DISC * (1 - smooth(disc_r - 6, disc_r, math.hypot(x + 0.5 - centre, y + 0.5 - centre)))
         for x in range(FRAME)] for y in range(FRAME)]


def key(rgb):
    out = Image.new("RGBA", (FRAME, FRAME))
    spx, opx = rgb.load(), out.load()
    for y in range(FRAME):
        row = disc[y]
        for x in range(FRAME):
            r, g, b = spx[x, y]
            glow = max(0.0, (max(r, g, b) - BLACK) / (255 - BLACK))
            under = row[x] * (1 - glow)  # the disc shows through where the glow is faint
            a = glow + under
            if a <= 0:
                opx[x, y] = (0, 0, 0, 0)
                continue
            # premultiplied: glow colour (the pixel itself) over the disc colour
            pr = r / 255 + DISC_RGB[0] / 255 * under
            pg = g / 255 + DISC_RGB[1] / 255 * under
            pb = b / 255 + DISC_RGB[2] / 255 * under
            opx[x, y] = (min(255, round(pr / a * 255)), min(255, round(pg / a * 255)),
                         min(255, round(pb / a * 255)), round(min(a, 1) * 255))
    return out


sheets = []
for start in range(0, len(frames), PER_SHEET):
    chunk = frames[start:start + PER_SHEET]
    rows = math.ceil(len(chunk) / COLS)
    sheet = Image.new("RGBA", (COLS * FRAME, rows * FRAME), (0, 0, 0, 0))
    for i, rgb in enumerate(chunk):
        sheet.paste(key(rgb), ((i % COLS) * FRAME, (i // COLS) * FRAME))
    name = "zenx-gyro-%d" % (len(sheets) + 1)
    # 256-colour palette + alpha table (like notif-shadow.png): ~190 KB a sheet instead of
    # ~1.3 MB, and the same to the eye at splash size (the source is a 256-colour GIF)
    sheet = sheet.quantize(256, method=Image.Quantize.FASTOCTREE)
    sheet.save(os.path.join(OUT, name + ".png"), optimize=True)
    sheets.append(name)
    print(name, sheet.size, os.path.getsize(os.path.join(OUT, name + ".png")), "bytes")

layout = {
    "sheets": sheets,             # extras keys, in frame order
    "size": FRAME,                # frame px (ImageRectSize)
    "cols": COLS,
    "perSheet": PER_SHEET,
    "frames": len(frames),
    "ms": round(sum(durations) / len(durations)),  # per frame
    "disc": round(2 * disc_r / FRAME, 4),          # dark disc diameter / frame size
}
with open(os.path.join(HERE, "gyro.json"), "w") as f:
    json.dump(layout, f)
print(layout)
