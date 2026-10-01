#!/usr/bin/env python3
# Generative home page. NomadNet runs this file (it's executable) and serves its stdout
# as micron. Every visit draws a new lake horizon for the current time in Ontario.
#
# Runs with an almost empty environment (PATH, link_id, remote_identity only), and
# stderr is discarded, so: stdlib only, and any failure falls back to a plain page.
# The sky, colours and pixel renderer are shared with the other pages in .lib/station.py.
# Preview the raw output with ./index.mu, or browse the dev node.

import os
import random
import sys

S = 1.5                  # scale of the painting; shapes are sized for S = 1 (64 columns)
W = round(64 * S)        # columns
H = round(32 * S) // 2 * 2   # pixel rows (two per text row, via half blocks), kept even
HORIZON = round(19 * S)


def s(n):
    return max(1, round(n * S))


def draw(st, rng, hour):
    px, cx, body = st.sky(rng, hour, W, HORIZON, S)
    zenith, horizon = st.sky_at(hour)
    dark = st.is_dark(hour)
    px += [[(0, 0, 0)] * W for _ in range(H - HORIZON)]

    # Distant skyline across the water, with one tall needle tower.
    if dark:
        silhouette = st.lerp(zenith, (10, 10, 18), 0.75)
    else:
        silhouette = st.lerp(horizon, (40, 40, 60), 0.55)
    heights = [0] * W
    x = rng.randint(s(4), s(10))
    while x < W - s(6):
        w, h = rng.randint(s(2), s(5)), rng.randint(s(1), s(5))
        for i in range(w):
            if x + i < W:
                heights[x + i] = max(heights[x + i], h)
        x += w + rng.randint(0, s(3))
    tower = rng.randint(W // 3, 2 * W // 3)
    for x in range(W):
        for y in range(HORIZON - heights[x], HORIZON):
            px[y][x] = silhouette
            if dark and heights[x] > 1 and rng.random() < 0.12:
                px[y][x] = rng.choice([(255, 210, 120), (255, 190, 90), (220, 150, 70)])
    for y in range(HORIZON - s(12), HORIZON):
        px[y][tower] = silhouette
    for y in range(HORIZON - s(7), HORIZON - s(5)):
        for x in (tower - 1, tower + 1):
            px[y][x] = silhouette
    px[HORIZON - s(12) - 1][tower] = (255, 40, 40)   # aircraft warning light

    # Water: mirrored, darkened sky with ripples.
    for y in range(HORIZON, H):
        depth = (y - HORIZON) / (H - HORIZON)
        src = max(0, HORIZON - 1 - (y - HORIZON) * 2)
        row = []
        for x in range(W):
            sx = min(W - 1, max(0, x + rng.randint(-1, 1)))
            c = st.lerp(px[src][sx], (8, 20, 40), 0.45 + depth * 0.3)
            if rng.random() < 0.04:
                c = st.lerp(c, (255, 255, 255), 0.12)
            row.append(c)
        px[y] = row

        # Light path under the sun/moon: short horizontal glints that widen with depth.
        half = (2 + depth * 7) * S
        x = int(cx - half)
        while x < cx + half:
            if rng.random() < 0.6 - depth * 0.25:
                for i in range(rng.randint(s(2), s(4))):
                    if 0 <= x + i < W and abs(x + i - cx) < half:
                        px[y][x + i] = st.lerp(px[y][x + i], body, 0.6 - depth * 0.25)
                x += s(4)
            else:
                x += 1
    return px


def main():
    import station as st
    st.record("index")
    seed = os.environ.get("link_id") or "%032x" % random.getrandbits(128)
    rng = random.Random(seed)
    now = st.ontario_now()
    th = st.Theme(st.hour_of(now))

    print("#!c=0")
    print("")
    print("`c")
    for line in st.render(draw(st, rng, th.hour)):
        print(line)
    print("")

    title = st.pixel_text("strauss", (238, 238, 246), st.rgb(th.shadow), spacing=2)
    for line in st.render(title):
        print(line)
    print("`F%s%s  ·  %s in ontario  ·  sky no. %s`f" % (
        th.dim, st.phase_name(th.hour), now.strftime("%H:%M"), seed[:6]))
    print("")
    print("`F%sthe sky is drawn fresh for every visit, at the time of day in ontario.`f" % th.soft)
    print("`F%severy page does the same, in that hour's colours.`f" % th.soft)
    print("")
    print("")

    # A small directory of the pages, centred as one block.
    width = 40
    for name, target, blurb in st.PAGES:
        link = "`F%s`_`[%s`:/page/%s]`_`f" % (th.link, name, target)
        dots = "`F%s%s`f" % (th.rule, "·" * (width - len(name) - len(blurb) - 2))
        print(st.fill("%s %s `F%s%s`f" % (link, dots, th.soft, blurb), width))
    print("`a")


if __name__ == "__main__":
    sys.dont_write_bytecode = True
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".lib"))
    try:
        main()
    except Exception:
        print("#!c=0\n\n`c`!STRAUSS`!\n\nthe sky failed to render. try again.\n\n"
              "`F9bd`_`[about`:/page/about.mu]`_`f\n`a")
