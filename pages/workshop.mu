#!/usr/bin/env python3
# The workshop. NomadNet runs this file (it's executable) and serves its stdout as micron.
# Edit the copy in COPY; the frame comes from .lib/station.py. The watch shows the time in
# Ontario when the page is requested.

import math
import os
import sys

COPY = """
## on the bench, in CAD
- a parametric dial blank in Fusion 360, measured against the NH35 spec sheet
- each dial design is built from the blank, so the fit stays right while the face changes
- nothing cut yet

## someday
- original dials
- then casebacks, then cases
"""

SPECS = [
    ("title", "seiko nh35"),
    ("text", "automatic, with date"),
    ("text", "24 jewels · 21,600 bph"),
    ("text", "41 hour power reserve"),
    ("text", "hacking seconds"),
    ("text", "hand-winding"),
    ("", ""),
    ("soft", "a big aftermarket"),
]


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def art(th, now):
    import station as st
    w, h = 44, 48
    cx, cy = 21.5, 23.5
    R, bezel, dial_r = 16.5, 14.8, 13.6
    strap, lug = (58, 40, 32), (150, 152, 160)
    dial = st.lerp(th.zenith, (18, 22, 40), 0.35)
    if st.luma(dial) < 48:   # keep a night dial navy, not black
        dial = st.lerp(dial, (34, 44, 96), 0.6)
    cream, red = (236, 228, 206), (230, 70, 60)

    hh, mm, ss = now.hour % 12, now.minute, now.second
    hands = [   # (angle, length, half width, colour, tail)
        ((hh + mm / 60) / 12, 7.8, 0.95, cream, 0),
        ((mm + ss / 60) / 60, 11.8, 0.7, cream, 0),
        (ss / 60, 12.8, 0.35, red, 3.2),
    ]

    def colour(x, y):
        dx, dy = x - cx, y - cy
        d = math.hypot(dx, dy)
        if d > R:
            if abs(dx) <= 7.5 and (y < cy - R + 3 or y > cy + R - 3):
                stitch = abs(dx) > 6.2 and int(y) % 2 == 0
                return (104, 80, 62) if stitch else strap
            if 6.5 < abs(dx) < 10 and abs(dy) < R + 3.5:
                return lug
            if R <= dx <= R + 2.2 and abs(dy) < 2.2:
                return (170, 172, 180) if int(y) % 2 else (130, 132, 140)
            return None
        if d > bezel:   # polished case, lit from the top left
            k = 0.5 - 0.5 * (dx * -0.6 + dy * -0.8) / d
            return st.lerp((225, 228, 236), (92, 94, 104), k)
        if d > dial_r:
            return (62, 64, 72)
        angle = math.atan2(dy, dx)
        c = st.lerp(dial, (255, 255, 255), 0.08 * abs(math.cos(angle - 2.3)) ** 2)
        c = st.lerp(c, (0, 0, 0), 0.25 * (d / dial_r) ** 3)
        for i in range(12):    # indices, doubled at twelve
            a = i / 12 * 2 * math.pi
            ux, uy = math.sin(a), -math.cos(a)
            offs = (-0.8, 0.8) if i == 0 else (0,)
            for o in offs:
                ox, oy = cx + o * -uy, cy + o * ux
                if i == 3:
                    continue
                if seg_dist(x, y, ox + ux * 10.4, oy + uy * 10.4, ox + ux * 12.8, oy + uy * 12.8) < 0.55:
                    return cream
        if 8.6 < dx < 12.4 and abs(dy) < 1.6:   # date window at three
            return (240, 238, 230) if abs(dy) < 1.0 and 9.4 < dx < 11.8 else (40, 40, 46)
        for a, length, half, col, tail in hands:
            a *= 2 * math.pi
            ux, uy = math.sin(a), -math.cos(a)
            if seg_dist(x, y, cx - ux * tail, cy - uy * tail, cx + ux * length, cy + uy * length) < half:
                return col
        if d < 1.1:
            return (200, 202, 210)
        return c

    px = []
    for y in range(h):
        row = []
        for x in range(w):
            # 3x3 samples per pixel, so the round case and thin hands stay smooth.
            samples = [colour(x + (i + 0.5) / 3, y + (j + 0.5) / 3) for i in range(3) for j in range(3)]
            solid = [s for s in samples if s is not None]
            if len(solid) < 4:
                row.append(None)
            else:
                row.append(tuple(sum(s[k] for s in solid) / len(solid) for k in range(3)))
        px.append(row)

    art_lines = st.render(px)
    styles = {"title": th.accent, "text": th.text, "soft": th.soft}
    side = {}
    for i, (kind, text) in enumerate(SPECS):
        if kind == "title":
            text = st.spaced(text)
        side[5 + i] = "`F%s%s`f" % (styles[kind], text) if kind else ""
    side[5 + len(SPECS) + 2] = "`F%s%s in ontario`f" % (th.dim, now.strftime("%H:%M:%S"))
    return [line + "    " + side.get(i, "") for i, line in enumerate(art_lines)]


if __name__ == "__main__":
    sys.dont_write_bytecode = True
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".lib"))
    try:
        import station
        station.page("workshop", COPY, art, subtitle="watchmaking, from the start")
    except Exception:
        print("#!c=0\n\n`F9bd`_`[← sky`:/page/index.mu]`_`f\n\n`!workshop`!\n")
        print("Seiko NH35 builds.\n" + COPY)
