#!/usr/bin/env python3
"""Builds App Store marketing art from the raw screenshots.

    python3 -m venv tools/.venv && tools/.venv/bin/pip install pillow
    tools/.venv/bin/python tools/marketing.py

Inputs: store/screenshots/* (from tools/screenshots.py) and
docs/images/studio-live.png (Vompt Studio's Live tab).
Outputs in store/marketing/:
  header-3840x1646.png        product page header (21:9)
  search-3840x2560.png        search results asset (3:2)
  universal-5244x2950.png     16:9 PNG accepted for both header and search
  <device>/<n>-<scene>.png    captioned screenshots per device slot

Copy leads with what sets Vompt apart: voice tracking, the browser remote,
and on-device AI. Keep it free of em dashes.
"""
import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHOTS = ROOT / "store/screenshots"
OUT = ROOT / "store/marketing"
FONTS = ROOT / "vompt/assets/fonts"
STUDIO = ROOT / "docs/images/studio-live.png"

INK = (13, 17, 28)
INK_LIFT = (28, 36, 58)
RAISED = (22, 27, 41)
LINE = (42, 49, 67)
PAPER = (242, 239, 232)
MUTED = (143, 151, 170)
CUE = (255, 194, 74)

# (scene, headline, subline). Order follows the pitch.
SCENES = [
    ("voice", "Scrolls as you speak.",
     "Read at your own pace. The word you're on lights up and stays on the mark."),
    ("remote", "Run it from your browser.",
     "Vompt Studio is served by your iPhone over Wi-Fi. Write, send, start and watch the take live."),
    ("ai", "Rewrite with on-device AI.",
     "Make it sound spoken, cut it to a minute, or draft from notes. Nothing leaves your iPhone."),
    ("fillers", "Counts every um and uh.",
     "Pace, fillers, skipped lines and coaching notes after every take."),
    ("progress", "Watch the ums drop.",
     "Every take is saved, so you can see yourself get better."),
    ("versions", "Every draft, kept.",
     "Compare any version with your script now, and bring it back in a tap."),
]

DEVICES = {
    # slot: (canvas size, screenshot folder)
    "iphone-6.3": ((2622, 1206), "iphone-6.3"),
    "iphone-6.9": ((2868, 1320), "iphone-6.9"),
    "ipad-13": ((2064, 2752), "ipad-13"),
}


def font(weight, size):
    return ImageFont.truetype(str(FONTS / f"AtkinsonHyperlegibleNext-{weight}.ttf"), int(size))


def background(w, h):
    """Eigengrau with a soft lift, like light on a studio monitor."""
    img = Image.new("RGB", (w, h), INK)
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse([w * -0.1, h * -0.4, w * 1.1, h * 1.0], fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(min(w, h) * 0.25))
    return Image.composite(Image.new("RGB", (w, h), INK_LIFT), img, glow)


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius=radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def phone(shot, width):
    """A screenshot in a black bezel, scaled to `width` overall. iPad-shaped
    screenshots (aspect under 1.5) get an iPad's tighter corners."""
    short = min(shot.size)
    tablet = max(shot.size) / short < 1.5
    bezel = int(short * (0.025 if tablet else 0.035))
    outer, inner = (0.05, 0.035) if tablet else (0.16, 0.13)
    framed = Image.new("RGBA", (shot.width + 2 * bezel, shot.height + 2 * bezel), (0, 0, 0, 0))
    body = rounded(Image.new("RGB", framed.size, (6, 6, 8)), int(short * outer))
    framed.alpha_composite(body)
    framed.alpha_composite(rounded(shot.convert("RGB"), int(short * inner)), (bezel, bezel))
    ImageDraw.Draw(framed).rounded_rectangle(
        [1, 1, framed.width - 2, framed.height - 2], radius=int(short * outer), outline=(58, 60, 70), width=max(2, bezel // 6)
    )
    scale = width / framed.width
    return framed.resize((int(framed.width * scale), int(framed.height * scale)), Image.LANCZOS)


def browser(shot, width):
    """A screenshot in a minimal browser window, scaled to `width`."""
    bar = int(shot.width * 0.034)
    win = Image.new("RGB", (shot.width, shot.height + bar), RAISED)
    win.paste(shot.convert("RGB"), (0, bar))
    d = ImageDraw.Draw(win)
    r = bar * 0.18
    for i, c in enumerate([(242, 95, 87), (247, 190, 76), (93, 196, 99)]):
        cx, cy = bar * 0.75 + i * bar * 0.6, bar / 2
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c)
    framed = rounded(win, int(shot.width * 0.012))
    ImageDraw.Draw(framed).rounded_rectangle(
        [0, 0, framed.width - 1, framed.height - 1], radius=int(shot.width * 0.012), outline=LINE, width=3
    )
    scale = width / framed.width
    return framed.resize((int(framed.width * scale), int(framed.height * scale)), Image.LANCZOS)


def place(canvas, item, x, y):
    """Composite an RGBA item with a soft shadow at (x, y)."""
    pad = int(max(item.size) * 0.06)
    shadow = Image.new("RGBA", (item.width + 2 * pad, item.height + 2 * pad), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 170), (pad, pad + pad // 3), item.split()[3])
    shadow = shadow.filter(ImageFilter.GaussianBlur(pad / 2.2))
    canvas.alpha_composite(shadow, (int(x - pad), int(y - pad)))
    canvas.alpha_composite(item, (int(x), int(y)))


def wrap(text, f, max_w):
    words, lines, line = text.split(), [], ""
    for w in words:
        trial = f"{line} {w}".strip()
        if f.getlength(trial) <= max_w or not line:
            line = trial
        else:
            lines.append(line)
            line = w
    lines.append(line)
    return lines


def caption(canvas, x, y, max_w, headline, sub, size, center=False):
    """Cue mark, headline and subline. Returns the bottom y."""
    d = ImageDraw.Draw(canvas)
    hf, sf = font("ExtraBold", size), font("Medium", size * 0.42)
    lines = wrap(headline, hf, max_w)
    lh = size * 1.12
    for i, line in enumerate(lines):
        lw = hf.getlength(line)
        lx = x + (max_w - lw) / 2 if center else x
        if i == 0:
            # The prompter's reading-line cue, pointing at the headline.
            t = size * 0.30
            cy = y + size * 0.55
            d.polygon([(lx - t * 1.9, cy - t), (lx - t * 1.9, cy + t), (lx - t * 0.4, cy)], fill=CUE)
        d.text((lx, y + i * lh), line, font=hf, fill=PAPER)
    y += len(lines) * lh + size * 0.32
    sub_lines = [l for part in sub.split("\n") for l in wrap(part, sf, max_w)]
    for i, line in enumerate(sub_lines):
        lw = sf.getlength(line)
        lx = x + (max_w - lw) / 2 if center else x
        d.text((lx, y), line, font=sf, fill=MUTED)
        y += sf.size * 1.4
    return y


def load(folder, name):
    return Image.open(SHOTS / folder / name)


def studio():
    """Vompt Studio's Live view, without the empty lower half of the editor."""
    img = Image.open(STUDIO)
    return img.crop((0, 0, img.width, int(img.height * 0.64)))


def art(scene, folder, box):
    """Draws the scene's imagery inside box = (x, y, w, h) and returns a layer."""
    x, y, w, h = box
    layer = Image.new("RGBA", (int(x + w + 400), int(y + h + 400)), (0, 0, 0, 0))
    portrait_device = folder.startswith("ipad")

    def fit_phone(shot, max_w, max_h):
        ph = phone(shot, max_w)
        if ph.height > max_h:
            ph = phone(shot, max_w * max_h / ph.height)
        return ph

    if scene == "voice":
        ph = fit_phone(load(folder, "1-prompter.png"), w, h)
        place(layer, ph, x + (w - ph.width) / 2, y + (h - ph.height) / 2)
    elif scene == "fillers":
        ph = fit_phone(load(folder, "2-summary.png"), w, h)
        place(layer, ph, x + (w - ph.width) / 2, y + (h - ph.height) / 2)
    elif scene == "remote":
        # Studio fills the frame; the phone it drives overlaps the corner.
        br = browser(studio(), w * (1.0 if portrait_device else 0.94))
        if br.height > h * 0.82:
            br = browser(studio(), br.width * h * 0.82 / br.height)
        ph = fit_phone(load(folder, "1-prompter.png"), w * (0.40 if portrait_device else 0.44), h * 0.55)
        # One overlapping group, centered: the device covers the window's
        # corner (bottom right on iPad, bottom left on iPhone).
        group_h = br.height + ph.height * (0.80 if portrait_device else 0.55)
        top = y + (h - group_h) / 2
        place(layer, br, x + w - br.width, top)
        px = x + w - ph.width - w * 0.03 if portrait_device else x
        place(layer, ph, px, top + br.height - ph.height * (0.20 if portrait_device else 0.45))
    else:
        names = {
            "ai": ["6-editor.png", "4-assist.png"],
            "progress": ["3-library.png", "5-history.png"],
            "versions": ["7-versions.png", "8-version-diff.png"],
        }[scene]
        shots = [load(folder, n) for n in names]
        gap = w * 0.04
        if portrait_device:
            ph = fit_phone(shots[1], w * 0.8, h)
            place(layer, ph, x + (w - ph.width) / 2, y + (h - ph.height) / 2)
        else:
            phones = [fit_phone(s, (w - gap) / 2, h) for s in shots]
            total = sum(p.width for p in phones) + gap
            px = x + (w - total) / 2
            for p in phones:
                place(layer, p, px, y + (h - p.height) / 2)
                px += p.width + gap
    return layer


def screenshot(device, scene, headline, sub, index):
    (cw, ch), folder = DEVICES[device]
    canvas = background(cw, ch).convert("RGBA")
    if cw > ch:
        # Landscape: caption on the left third, imagery on the right.
        m = cw * 0.05
        text_w = cw * 0.30
        size = ch * 0.085
        block_h = size * 2.4 + size * 0.42 * 1.4 * 3
        caption(canvas, m + size * 0.7, (ch - block_h) / 2, text_w - size * 0.7, headline, sub, size)
        box = (m + text_w + m * 0.6, ch * 0.08, cw - (m + text_w + m * 0.6) - m, ch * 0.84)
    else:
        # Portrait (iPad): caption on top, imagery below.
        m = cw * 0.07
        size = cw * 0.062
        bottom = caption(canvas, m + size * 0.7, ch * 0.07, cw - 2 * m - size * 0.7, headline, sub, size)
        box = (m, bottom + ch * 0.04, cw - 2 * m, ch - bottom - ch * 0.04 - m)
    layer = art(scene, folder, box)
    canvas.alpha_composite(layer.crop((0, 0, cw, ch)))
    path = OUT / device / f"{index}-{scene}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(path, optimize=True)
    return path


def hero(canvas, left, top, width, phone_width, center=None, phone_shift=0.18):
    """Studio window fully in frame, with the phone it drives overlapping the
    window's lower-left corner. With `center`, the group is centered on that y."""
    br = browser(studio(), width)
    ph = phone(load("iphone-6.9", "1-prompter.png"), phone_width)
    if center is not None:
        top = center - (br.height + ph.height * 0.60) / 2
    place(canvas, br, left, top)
    place(canvas, ph, left - phone_width * phone_shift, top + br.height - ph.height * 0.40)


def header():
    """21:9 product page header: the pitch on the left, Studio driving the phone on the right."""
    w, h = 3840, 1646
    canvas = background(w, h).convert("RGBA")
    size = 150
    caption(canvas, w * 0.06 + size * 0.7, h * 0.30, w * 0.33, "Your voice runs the prompter.",
            "Voice tracking, a browser remote\nand on-device AI. Private and free.", size)
    hero(canvas, w * 0.45, h * 0.09, w * 0.51, w * 0.25)
    path = OUT / "header-3840x1646.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(path, optimize=True)
    return path


def search():
    """3:2 search results asset: one bold line, then the remote and prompter together."""
    w, h = 3840, 2560
    canvas = background(w, h).convert("RGBA")
    size = 190
    bottom = caption(canvas, w * 0.08, h * 0.08, w * 0.84, "Your voice runs the prompter.",
                     "Voice tracking, a browser remote and on-device AI. Private and free.", size, center=True)
    layer = art("remote", "iphone-6.9", (w * 0.08, bottom + h * 0.04, w * 0.84, h - bottom - h * 0.10))
    canvas.alpha_composite(layer.crop((0, 0, w, h)))
    path = OUT / "search-3840x2560.png"
    canvas.convert("RGB").save(path, optimize=True)
    return path


def universal():
    """16:9 PNG that App Store Connect accepts for both header and search results."""
    w, h = 5244, 2950
    canvas = background(w, h).convert("RGBA")
    size = 230
    caption(canvas, w * 0.06 + size * 0.7, h * 0.355, w * 0.34, "Your voice runs the prompter.",
            "Voice tracking, a browser remote\nand on-device AI. Private and free.", size)
    hero(canvas, w * 0.47, 0, w * 0.50, w * 0.29, center=h * 0.5, phone_shift=0.10)
    path = OUT / "universal-5244x2950.png"
    canvas.convert("RGB").save(path, optimize=True)
    return path


if __name__ == "__main__":
    print(universal().relative_to(ROOT))
    print(header().relative_to(ROOT))
    print(search().relative_to(ROOT))
    for device in DEVICES:
        for i, (scene, headline, sub) in enumerate(SCENES, start=1):
            print(screenshot(device, scene, headline, sub, i).relative_to(ROOT))
