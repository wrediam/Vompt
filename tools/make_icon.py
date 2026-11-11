"""Draws the Vompt app icon: three prompter lines, the current word lit in cue
amber, and the cue mark pointing at it. Full-bleed square; iOS applies the mask.

    tools/.venv/bin/python tools/make_icon.py icon.png
"""
import sys
from PIL import Image, ImageDraw, ImageFilter

S = 4096                      # supersample, downscaled to 1024 at the end
k = S / 1024
INK_CENTER = (27, 34, 58)     # lifted navy at the center
INK_EDGE = (7, 9, 17)
PAPER = (248, 245, 238)
CUE = (255, 192, 56)
TALLY = (242, 73, 59)

img = Image.new("RGB", (S, S), INK_EDGE)

# Soft radial lift, like light falling on a studio monitor.
glow = Image.new("L", (S, S), 0)
ImageDraw.Draw(glow).ellipse([S * 0.08, S * 0.02, S * 0.92, S * 0.86], fill=255)
glow = glow.filter(ImageFilter.GaussianBlur(S * 0.16))
img = Image.composite(Image.new("RGB", (S, S), INK_CENTER), img, glow)

d = ImageDraw.Draw(img, "RGBA")
def bar(x0, x1, yc, color, h=66):
    d.rounded_rectangle([x0 * k, (yc - h / 2) * k, x1 * k, (yc + h / 2) * k], radius=h / 2 * k, fill=color)

left = 322
# Read line: dimmed, like words already spoken.
bar(left, 804, 368, PAPER + (112,))
# Current line: the word being read glows amber.
halo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(halo).rounded_rectangle([(left - 14) * k, 462 * k, 556 * k, 546 * k], radius=42 * k, fill=CUE + (120,))
halo = halo.filter(ImageFilter.GaussianBlur(28 * k))
img.paste(halo, (0, 0), halo)
d = ImageDraw.Draw(img, "RGBA")
bar(left, 542, 504, CUE + (255,))
bar(578, 822, 504, PAPER + (255,))
# Upcoming line.
bar(left, 716, 640, PAPER + (255,))

# Cue mark: a rounded triangle pointing at the current line.
tri = Image.new("RGBA", (S, S), (0, 0, 0, 0))
td = ImageDraw.Draw(tri)
td.polygon([(214 * k, 460 * k), (214 * k, 548 * k), (276 * k, 504 * k)], fill=CUE + (255,))
img.paste(tri, (0, 0), tri)

if "--tally" in sys.argv:
    d = ImageDraw.Draw(img, "RGBA")
    d.ellipse([772 * k, 236 * k, 820 * k, 284 * k], fill=TALLY + (255,))

out = img.resize((1024, 1024), Image.LANCZOS)
out.save(sys.argv[1], "PNG")
