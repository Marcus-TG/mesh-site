# Shared pieces for the station's pages: the Ontario sky, colours taken from it,
# a half-block pixel renderer, a small pixel font, and the page frame.
#
# Pages import this. It lives in a dot-directory because NomadNet serves every other
# file under pages/ as a page. Stdlib only: pages run with an almost empty environment.

import hashlib
import math
import os
import re
import struct
import time
from datetime import datetime, timedelta, timezone

COL = 72   # width of the text column every inner page is laid out in

# Sky palettes keyed by hour of day: (zenith, horizon) RGB. Interpolated between keys.
KEYS = [
    (0.0,  (6, 8, 22),     (22, 26, 62)),
    (5.0,  (10, 10, 34),   (48, 34, 80)),
    (6.5,  (40, 44, 110),  (240, 120, 90)),
    (8.0,  (70, 120, 210), (250, 200, 150)),
    (11.0, (60, 130, 230), (170, 210, 245)),
    (16.0, (70, 130, 220), (190, 210, 235)),
    (18.2, (70, 60, 150),  (255, 140, 70)),
    (19.3, (40, 30, 90),   (220, 80, 90)),
    (20.5, (14, 14, 44),   (60, 36, 84)),
    (24.0, (6, 8, 22),     (22, 26, 62)),
]

PAGES = [
    ("about", "about.mu", "who runs this node"),
    ("log", "log.mu", "who's been by, and when"),
    ("lab", "lab.mu", "the homelab it runs on"),
    ("workshop", "workshop.mu", "watchmaking"),
    ("art", "art.mu", "how the pictures are made"),
]


# ── time and sky ─────────────────────────────────────────────────────────────

def ontario_now():
    try:
        from zoneinfo import ZoneInfo
        now = datetime.now(ZoneInfo("America/Toronto"))
    except Exception:
        now = datetime.now(timezone(timedelta(hours=-4)))
    fake = os.environ.get("STATION_TIME")   # "HH:MM", for previewing other hours locally
    if fake:
        h, m = fake.split(":")
        now = now.replace(hour=int(h), minute=int(m))
    return now


def hour_of(now):
    return now.hour + now.minute / 60 + now.second / 3600


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def sky_at(hour):
    for (h0, z0, r0), (h1, z1, r1) in zip(KEYS, KEYS[1:]):
        if h0 <= hour <= h1:
            t = (hour - h0) / (h1 - h0)
            return lerp(z0, z1, t), lerp(r0, r1, t)
    return KEYS[0][1], KEYS[0][2]


def phase_name(hour):
    if 5.0 <= hour < 7.5:   return "dawn"
    if 7.5 <= hour < 17.8:  return "day"
    if 17.8 <= hour < 20.5: return "dusk"
    return "night"


def is_dark(hour):
    return phase_name(hour) == "night" or hour < 6.0 or hour > 20.0


def celestial(hour):
    """Sun or moon for this hour: (t along its arc 0..1, body colour, glow colour, is_sun)."""
    if 6.3 <= hour <= 19.7:
        return (hour - 6.3) / (19.7 - 6.3), (255, 236, 170), (255, 170, 90), True
    t = ((hour - 19.7) % 24) / (24 - 19.7 + 6.3)
    return t, (225, 228, 240), (120, 130, 170), False


def sky(rng, hour, w, horizon, scale=1.0):
    """Sky rows 0..horizon-1: gradient, grain, stars when dark, sun or moon with glow.
    Returns (px, cx) where cx is the body's column, for light paths on water."""
    zenith, low = sky_at(hour)
    px = []
    for y in range(horizon):
        t = (y / max(1, horizon - 1)) ** 1.6
        base = lerp(zenith, low, t)
        row = []
        for x in range(w):
            n = rng.uniform(-3, 3)
            row.append((base[0] + n, base[1] + n, base[2] + n))
        px.append(row)

    if is_dark(hour):
        for _ in range(int(w * horizon / 43)):
            x, y = rng.randrange(w), rng.randrange(max(1, horizon - round(4 * scale)))
            b = rng.choice([150, 190, 230, 255])
            px[y][x] = (b, b, min(255, b + 20))

    t, body, glow, is_sun = celestial(hour)
    radius = (2.2 if is_sun else 1.7) * scale
    margin = 6 * scale
    cx = margin + t * (w - 2 * margin)
    cy = horizon - 2 * scale - math.sin(t * math.pi) * (horizon - 6 * scale)
    for y in range(horizon):
        for x in range(w):
            d = math.hypot((x - cx) * 0.5, y - cy)
            if d <= radius:
                px[y][x] = body
            elif d <= radius * 3.2:
                k = (1 - (d - radius) / (radius * 2.2)) * 0.35
                px[y][x] = lerp(px[y][x], glow, k)
    return px, cx, body


# ── colour ───────────────────────────────────────────────────────────────────

def clamp(c):
    return tuple(max(0, min(255, int(v))) for v in c)


def hexc(c):
    r, g, b = clamp(c)
    return "%x%x%x" % (round(r / 17), round(g / 17), round(b / 17))


def luma(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def lift(c, floor):
    """Brighten c until it is at least `floor` bright: scale up first, which keeps the
    hue, then mix toward white only for what scaling can't reach."""
    if luma(c) >= floor:
        return c
    c = tuple(v * 255 / max(1, max(c)) for v in c)
    k = 0.0
    while luma(lerp(c, (255, 255, 255), k)) < floor and k < 1:
        k += 0.05
    return lerp(c, (255, 255, 255), k)


def saturate(c, k):
    m = sum(c) / 3
    return clamp(tuple(m + (v - m) * k for v in c))


class Theme:
    """Page colours, taken from the sky at this hour so the whole site shifts with it."""

    def __init__(self, hour):
        zenith, low = sky_at(hour)
        self.hour = hour
        self.zenith, self.low = zenith, low
        self.accent = hexc(lift(saturate(low, 1.8), 175))         # labels, titles
        self.shadow = hexc(lerp(lift(saturate(low, 1.8), 175), (28, 28, 36), 0.72))
        self.link = hexc(lift(saturate(lerp(zenith, (110, 150, 255), 0.35), 1.4), 160))
        self.text = "ccc"
        self.soft = "99a"
        self.dim = "667"
        self.rule = "445"


# ── pixels ───────────────────────────────────────────────────────────────────

def render(px):
    """Pixel rows -> micron lines, two pixel rows per text row via half blocks.
    A pixel of None is transparent (page background)."""
    lines = []
    for row in range(0, len(px) - 1, 2):
        out, fg, bg = [], None, None
        for top, bot in zip(px[row], px[row + 1]):
            t = hexc(top) if top is not None else None
            b = hexc(bot) if bot is not None else None
            if t is None and b is None:
                glyph, want_fg, want_bg = " ", fg, None
            elif b is None:
                glyph, want_fg, want_bg = "▀", t, None
            elif t is None:
                glyph, want_fg, want_bg = "▄", b, None
            else:
                glyph, want_fg, want_bg = "▀", t, b
            if want_fg != fg:
                out.append("`F" + want_fg)
                fg = want_fg
            if want_bg != bg:
                out.append("`B" + want_bg if want_bg else "`b")
                bg = want_bg
            out.append(glyph)
        out.append("`f`b")   # reset colours only; a full `` reset would also drop centering
        lines.append("".join(out))
    return lines


def blank(w, h):
    return [[None] * w for _ in range(h)]


FONT = {
    "a": ".#.|#.#|###|#.#|#.#", "b": "##.|#.#|##.|#.#|##.", "c": ".##|#..|#..|#..|.##",
    "d": "##.|#.#|#.#|#.#|##.", "e": "###|#..|##.|#..|###", "f": "###|#..|##.|#..|#..",
    "g": ".##|#..|#.#|#.#|.##", "h": "#.#|#.#|###|#.#|#.#", "i": "###|.#.|.#.|.#.|###",
    "j": "..#|..#|..#|#.#|.#.", "k": "#.#|#.#|##.|#.#|#.#", "l": "#..|#..|#..|#..|###",
    "m": "#...#|##.##|#.#.#|#...#|#...#", "n": "#..#|##.#|#.##|#..#|#..#",
    "o": ".##.|#..#|#..#|#..#|.##.", "p": "##.|#.#|##.|#..|#..", "q": ".#.|#.#|#.#|##.|.##",
    "r": "##.|#.#|##.|#.#|#.#", "s": ".##|#..|.#.|..#|##.", "t": "###|.#.|.#.|.#.|.#.",
    "u": "#.#|#.#|#.#|#.#|###", "v": "#.#|#.#|#.#|#.#|.#.", "w": "#...#|#...#|#.#.#|##.##|#...#",
    "x": "#.#|#.#|.#.|#.#|#.#", "y": "#.#|#.#|.#.|.#.|.#.", "z": "###|..#|.#.|#..|###",
    " ": "..|..|..|..|..",
}


def pixel_text(text, color, shadow=None, spacing=1):
    """Text in the 5px font, with an optional drop shadow one pixel down-right.
    Returns 6 pixel rows (3 text rows)."""
    glyphs = [FONT.get(ch, FONT[" "]).split("|") for ch in text.lower()]
    w = sum(len(g[0]) + spacing for g in glyphs) + 1
    px = blank(w, 6)
    x0 = 0
    for g in glyphs:
        for y, row in enumerate(g):
            for x, on in enumerate(row):
                if on == "#":
                    if shadow is not None and px[y + 1][x0 + x + 1] is None:
                        px[y + 1][x0 + x + 1] = shadow
                    px[y][x0 + x] = color
        x0 += len(g[0]) + spacing
    return px


def pad(px, w):
    """Widen pixel rows to w with transparent pixels on the right."""
    return [row + [None] * (w - len(row)) for row in px]


def rgb(hex3):
    return tuple(int(ch, 16) * 17 for ch in hex3)


# ── text ─────────────────────────────────────────────────────────────────────

_CODES = re.compile(r"`\[([^`\]]*)`[^\]]*\]|`[FB]T[0-9a-fA-F]{6}|`[FB][0-9a-fA-F]{3}|`[!*_fbaclr`]")


def vis_len(s):
    return len(_CODES.sub(lambda m: m.group(1) or "", s))


def fill(s, w=COL):
    """Pad a micron line with spaces to w visible columns, so a centred block stays
    left-aligned inside itself."""
    return s + " " * max(0, w - vis_len(s))


def spaced(word):
    return " ".join(word.upper())


def wrap(text, width, first, rest):
    words, lines, cur = text.split(), [], first
    for word in words:
        if vis_len(cur) + len(word) > width and cur.strip():
            lines.append(cur.rstrip())
            cur = rest
        cur += word + " "
    lines.append(cur.rstrip())
    return lines


def body(src, th):
    """A small markup for page copy, laid out in the column:
         ## label     section label with a rule, letter-spaced
         ### label    the same, as written (dates, log entries)
         - item       bullet (wraps with a hanging indent)
         > note       dim note
         blank line   blank line
         anything else is a paragraph. Lines holding micron codes are passed through."""
    out = []
    for raw in src.strip("\n").split("\n"):
        line = raw.rstrip()
        if line.startswith("#") and not line.startswith(("## ", "### ")):
            continue
        if not line:
            out.append("")
        elif line.startswith("## ") or line.startswith("### "):
            label = spaced(line[3:]) if line.startswith("## ") else line[4:]
            out.append("`F%s%s`f  `F%s%s`f" % (th.accent, label, th.rule, "─" * (COL - len(label) - 2)))
        elif line.startswith("- "):
            item = line[2:]
            if "`" in item:
                out.append(" `F%s∙`f  `F%s%s`f" % (th.dim, th.text, item))
            else:
                for i, l in enumerate(wrap(item, COL - 4, "", "    ")):
                    out.append((" `F%s∙`f  " % th.dim if i == 0 else "") + "`F%s%s`f" % (th.text, l))
        elif line.startswith("> "):
            for l in wrap(line[2:], COL, "", ""):
                out.append("`F%s`*%s`*`f" % (th.soft, l))
        elif "`" in line:
            out.append(line)
        else:
            for l in wrap(line, COL, "", ""):
                out.append("`F%s%s`f" % (th.text, l))
    return out


# ── visitors ─────────────────────────────────────────────────────────────────
# Pages count themselves: one line per request, appended to a file beside NomadNet's
# own storage. A line holds the time, the page, and short one-way hashes of the link
# and (if the visitor chose to identify) their identity. Nothing that names anyone.

VISITS = "station-visits"


def storage_dir():
    """NomadNet's storage folder, found the way NomadNet finds its config: the parent
    of the pages folder (the default layout), then /etc, ~/.config, ~/."""
    pages = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    candidates = [os.environ.get("STATION_STORAGE"), os.path.dirname(pages)]
    try:
        import pwd
        home = pwd.getpwuid(os.getuid()).pw_dir
        candidates += ["/etc/nomadnetwork/storage", home + "/.config/nomadnetwork/storage",
                       home + "/.nomadnetwork/storage"]
    except Exception:
        pass
    for d in candidates:
        if d and os.path.isfile(os.path.join(d, "peersettings")):
            return d
    return None


def _h(value):
    return hashlib.sha256(value.encode()).hexdigest()[:10] if value else "-"


def record(page_name):
    """Count this request. Only real requests carry a link_id, so local runs don't count."""
    link = os.environ.get("link_id")
    d = storage_dir()
    if not link or not d:
        return
    path = os.path.join(d, VISITS)
    try:
        with open(path, "a") as f:
            f.write("%d %s %s %s\n" % (time.time(), page_name, _h(link), _h(os.environ.get("remote_identity"))))
        if os.path.getsize(path) > 2 * 1024 * 1024:   # ~25k visits; then drop the oldest half
            with open(path) as f:
                lines = f.readlines()
            with open(path, "w") as f:
                f.writelines(lines[len(lines) // 2:])
    except OSError:
        pass


def visits():
    """[(unix time, page, link hash, identity hash or '-')], oldest first."""
    d = storage_dir()
    out = []
    try:
        with open(os.path.join(d, VISITS)) as f:
            for line in f:
                parts = line.split()
                if len(parts) == 4:
                    out.append((int(parts[0]), parts[1], parts[2], parts[3]))
    except (OSError, TypeError, ValueError):
        pass
    return out


def _unpack(b, i=0):
    """Just enough msgpack to read NomadNet's peersettings (stdlib only, so no library)."""
    t = b[i]
    if t <= 0x7f: return t, i + 1
    if t >= 0xe0: return t - 0x100, i + 1
    if 0x80 <= t <= 0x8f: return _map(b, i + 1, t & 0x0f)
    if 0x90 <= t <= 0x9f: return _arr(b, i + 1, t & 0x0f)
    if 0xa0 <= t <= 0xbf: n = t & 0x1f; return b[i + 1:i + 1 + n].decode("utf-8", "replace"), i + 1 + n
    if t == 0xc0: return None, i + 1
    if t == 0xc2: return False, i + 1
    if t == 0xc3: return True, i + 1
    fixed = {0xca: ">f", 0xcb: ">d", 0xcc: ">B", 0xcd: ">H", 0xce: ">I", 0xcf: ">Q",
             0xd0: ">b", 0xd1: ">h", 0xd2: ">i", 0xd3: ">q"}
    if t in fixed:
        n = struct.calcsize(fixed[t])
        return struct.unpack(fixed[t], b[i + 1:i + 1 + n])[0], i + 1 + n
    sized = {0xc4: (">B", False), 0xc5: (">H", False), 0xc6: (">I", False),
             0xd9: (">B", True), 0xda: (">H", True), 0xdb: (">I", True)}
    if t in sized:
        fmt, text = sized[t]
        k = struct.calcsize(fmt)
        n = struct.unpack(fmt, b[i + 1:i + 1 + k])[0]
        raw = b[i + 1 + k:i + 1 + k + n]
        return (raw.decode("utf-8", "replace") if text else raw), i + 1 + k + n
    if t in (0xdc, 0xdd, 0xde, 0xdf):
        fmt = ">H" if t in (0xdc, 0xde) else ">I"
        k = struct.calcsize(fmt)
        n = struct.unpack(fmt, b[i + 1:i + 1 + k])[0]
        return (_arr if t in (0xdc, 0xdd) else _map)(b, i + 1 + k, n)
    raise ValueError("msgpack type %x" % t)


def _map(b, i, n):
    out = {}
    for _ in range(n):
        k, i = _unpack(b, i)
        v, i = _unpack(b, i)
        out[k] = v
    return out, i


def _arr(b, i, n):
    out = []
    for _ in range(n):
        v, i = _unpack(b, i)
        out.append(v)
    return out, i


def node_stats():
    """NomadNet's own running totals (links, pages served, last announce), or {}."""
    try:
        with open(os.path.join(storage_dir(), "peersettings"), "rb") as f:
            data, _ = _unpack(f.read())
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def ago(seconds):
    seconds = max(0, int(seconds))
    for size, unit in ((86400, "day"), (3600, "hour"), (60, "min")):
        if seconds >= size:
            n = seconds // size
            return "%d %s%s ago" % (n, unit, "s" if n > 1 and unit != "min" else "")
    return "just now"


# ── page frame ───────────────────────────────────────────────────────────────

def nav(th, current=None):
    parts = []
    for name, target, _ in PAGES:
        if name == current:
            parts.append("`F%s`!%s`!`f" % (th.accent, name))
        else:
            parts.append("`F%s`_`[%s`:/page/%s]`_`f" % (th.link, name, target))
    return ("  `F%s·`f  " % th.rule).join(parts)


def page(name, copy, art=None, subtitle=None):
    """Print an inner page: header line, art, pixel title, copy, footer nav.
    `art` is a function (theme, now) -> list of micron lines, each COL wide or less.
    `copy` is body markup, or a function (theme, now) returning it."""
    record(name)
    now = ontario_now()
    th = Theme(hour_of(now))

    lines = ["#!c=0", "", "`c"]
    back = "`F%s`_`[← sky`:/page/index.mu]`_`f" % th.link
    clock = "`F%s%s  ·  %s in ontario`f" % (th.dim, phase_name(th.hour), now.strftime("%H:%M"))
    lines.append(fill(back + " " * (COL - vis_len(back) - vis_len(clock)) + clock))
    lines.append("")

    if art:
        try:
            drawn = art(th, now)
            lines += [fill(l) for l in drawn]
            lines.append("")
        except Exception:
            pass

    title = pixel_text(name, rgb(th.accent), rgb(th.shadow), spacing=2)
    lines += [fill(l) for l in render(pad(title, COL))]
    if subtitle:
        lines.append(fill("`F%s%s`f" % (th.soft, subtitle)))
    lines.append("")

    if callable(copy):   # copy built per request, after this visit is counted
        copy = copy(th, now)
    lines += [fill(l) for l in body(copy, th)]

    lines.append("")
    lines.append(fill("`F%s%s`f" % (th.rule, "─" * COL)))
    lines.append(nav(th, name))
    lines.append("`a")
    print("\n".join(lines))

