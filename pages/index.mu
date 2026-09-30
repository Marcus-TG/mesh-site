#!/usr/bin/env python3
# Generative home page. NomadNet runs this file (it's executable) and serves its stdout
# as micron. Every visit draws a new lake horizon for the current time in Ontario.
#
# Runs with an almost empty environment (PATH, link_id, remote_identity only), and
# stderr is discarded, so: stdlib only, and any failure falls back to a plain page.
# Preview the raw output with ./index.mu, or browse the dev node.

import math
import os
import random
from datetime import datetime, timedelta, timezone

W = 64   # columns
H = 32   # pixel rows (two per text row, via half blocks)
HORIZON = 19

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


def ontario_now():
    try:
        from zoneinfo import ZoneInfo
        return datetime.now(ZoneInfo("America/Toronto"))
    except Exception:
        return datetime.now(timezone(timedelta(hours=-4)))


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


def clamp(c):
    return tuple(max(0, min(255, int(v))) for v in c)


def hexc(c):
    r, g, b = clamp(c)
    return "%x%x%x" % (round(r / 17), round(g / 17), round(b / 17))


def draw(rng, hour):
    zenith, horizon = sky_at(hour)
    phase = phase_name(hour)
    dark = phase == "night" or hour < 6.0 or hour > 20.0
    px = [[(0, 0, 0)] * W for _ in range(H)]

    # Sky gradient, eased toward the horizon, with a little grain.
    for y in range(HORIZON):
        t = (y / (HORIZON - 1)) ** 1.6
        base = lerp(zenith, horizon, t)
        for x in range(W):
            n = rng.uniform(-3, 3)
            px[y][x] = (base[0] + n, base[1] + n, base[2] + n)

    # Stars.
    if dark:
        for _ in range(rng.randint(28, 46)):
            x, y = rng.randrange(W), rng.randrange(HORIZON - 4)
            b = rng.choice([150, 190, 230, 255])
            px[y][x] = (b, b, min(255, b + 20))

    # Sun or moon on an arc across the sky.
    if 6.3 <= hour <= 19.7:
        t = (hour - 6.3) / (19.7 - 6.3)
        body, glow, radius = (255, 236, 170), (255, 170, 90), 2.2
    else:
        t = ((hour - 19.7) % 24) / (24 - 19.7 + 6.3)
        body, glow, radius = (225, 228, 240), (120, 130, 170), 1.7
    cx = 6 + t * (W - 12)
    cy = HORIZON - 2 - math.sin(t * math.pi) * (HORIZON - 6)
    for y in range(HORIZON):
        for x in range(W):
            d = math.hypot((x - cx) * 0.5, y - cy)
            if d <= radius:
                px[y][x] = body
            elif d <= radius * 3.2:
                k = (1 - (d - radius) / (radius * 2.2)) * 0.35
                px[y][x] = lerp(px[y][x], glow, k)

    # Distant skyline across the water, with one tall needle tower.
    if dark:
        silhouette = lerp(zenith, (10, 10, 18), 0.75)
    else:
        silhouette = lerp(horizon, (40, 40, 60), 0.55)
    heights = [0] * W
    x = rng.randint(4, 10)
    while x < W - 6:
        w, h = rng.randint(2, 5), rng.randint(1, 5)
        for i in range(w):
            if x + i < W:
                heights[x + i] = max(heights[x + i], h)
        x += w + rng.randint(0, 3)
    tower = rng.randint(W // 3, 2 * W // 3)
    for x in range(W):
        for y in range(HORIZON - heights[x], HORIZON):
            px[y][x] = silhouette
            if dark and heights[x] > 1 and rng.random() < 0.12:
                px[y][x] = rng.choice([(255, 210, 120), (255, 190, 90), (200, 220, 255)])
    for y in range(HORIZON - 12, HORIZON):
        px[y][tower] = silhouette
    for y in range(HORIZON - 7, HORIZON - 5):
        for x in (tower - 1, tower + 1):
            px[y][x] = silhouette
    px[HORIZON - 13][tower] = (255, 40, 40)   # aircraft warning light

    # Water: mirrored, darkened sky with ripples.
    for y in range(HORIZON, H):
        depth = (y - HORIZON) / (H - HORIZON)
        src = max(0, HORIZON - 1 - (y - HORIZON) * 2)
        row = []
        for x in range(W):
            sx = min(W - 1, max(0, x + rng.randint(-1, 1)))
            c = lerp(px[src][sx], (8, 20, 40), 0.45 + depth * 0.3)
            if rng.random() < 0.04:
                c = lerp(c, (255, 255, 255), 0.12)
            row.append(c)
        px[y] = row

        # Light path under the sun/moon: short horizontal glints that widen with depth.
        half = 2 + depth * 7
        x = int(cx - half)
        while x < cx + half:
            if rng.random() < 0.6 - depth * 0.25:
                for i in range(rng.randint(2, 4)):
                    if 0 <= x + i < W and abs(x + i - cx) < half:
                        px[y][x + i] = lerp(px[y][x + i], body, 0.6 - depth * 0.25)
                x += 4
            else:
                x += 1
    return px, phase


def render(px):
    # Each text row carries two pixel rows: top = foreground of ▀, bottom = background.
    lines = []
    for row in range(0, H, 2):
        out, fg, bg = [], None, None
        for x in range(W):
            top, bottom = hexc(px[row][x]), hexc(px[row + 1][x])
            if top != fg:
                out.append("`F" + top)
                fg = top
            if bottom != bg:
                out.append("`B" + bottom)
                bg = bottom
            out.append("▀")
        out.append("`f`b")   # reset colors only; a full `` reset would also drop centering
        lines.append("".join(out))
    return lines


def gradient_text(text, a, b):
    n = max(1, len(text) - 1)
    return "".join("`F%s%s" % (hexc(lerp(a, b, i / n)), ch) for i, ch in enumerate(text)) + "`f"


def main():
    seed = os.environ.get("link_id") or "%032x" % random.getrandbits(128)
    rng = random.Random(seed)
    now = ontario_now()
    hour = now.hour + now.minute / 60
    zenith, horizon = sky_at(hour)
    px, phase = draw(rng, hour)

    link = "`F9bd`_`[{0}`:/page/{1}]`_`f"
    print("#!c=0")
    print("")
    print("`c")
    for line in render(px):
        print(line)
    print("")
    title_from = lerp(horizon, (255, 255, 255), 0.45)
    print("`!" + gradient_text("S T R A U S S", title_from, (235, 235, 255)) + "`!")
    print("`Faaa%s  ·  %s in ontario  ·  sky no. %s`f" % (phase, now.strftime("%H:%M"), seed[:6]))
    print("")
    print("  ".join([link.format("about", "about.mu"), link.format("log", "log.mu"),
                     link.format("lab", "lab.mu"), link.format("workshop", "workshop.mu")]))
    print("")
    print("`F667`*every visitor gets their own sky`*`f")
    print("`a")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("#!c=0\n\n`c`!STRAUSS`!\n\nthe sky failed to render. try again.\n\n"
              "`F9bd`_`[about`:/page/about.mu]`_`f\n`a")
