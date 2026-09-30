#!/usr/bin/env python3
# The lab. NomadNet runs this file (it's executable) and serves its stdout as micron.
# Edit the copy in COPY and the machines in RACK; the frame comes from .lib/station.py.

import os
import sys

# (name, detail lines...), top of the rack first. Drawn next to their units: three
# detail lines fit beside the 2U units, two beside the 1U ones.
RACK = [
    ("service host", "Ryzen 9, RTX 3060, 32 GB", "Docker"),
    ("inference", "Ryzen 7, RTX 3090, 64 GB", "local models"),
    ("storage", "Dell PowerEdge R710, 64 GB", "TrueNAS SCALE", "the boring, important one"),
    ("network", "UniFi", "VLANs, dual WAN"),
]

COPY = """
## why
I never went to school for this. Building a homelab was my education, and I built a career out of it.

- running my own services instead of renting them
- local models on my own GPUs instead of cloud APIs
- this node: take addressing, routing and trust away, then rebuild them from keys. The most interesting way I've found to learn what they actually are.
"""


def art(th, now):
    # A small rack, one unit per machine. The lights are drawn fresh each visit.
    import random
    import station as st
    rng = random.Random(os.environ.get("link_id") or None)
    w, h = 30, 32
    px = st.blank(w, h)
    post, hole = (46, 48, 58), (24, 24, 30)
    for y in range(h):
        for x in (0, 1, w - 2, w - 1):
            px[y][x] = post
        if y % 3 == 1:
            px[y][0] = px[y][w - 1] = hole

    def box(y0, y1, face, edge):
        for y in range(y0, y1):
            for x in range(3, w - 3):
                px[y][x] = edge if y in (y0, y1 - 1) or x in (3, w - 4) else face

    green, amber, blue, off = (80, 230, 120), (250, 180, 60), (90, 170, 255), (40, 44, 50)

    # service host, 1U: vent slots and two lights.
    box(1, 6, (72, 74, 84), (96, 98, 110))
    for x in range(6, 19, 2):
        for y in (2, 3, 4):
            px[y][x] = (52, 54, 62)
    px[3][w - 6] = green
    px[3][w - 8] = amber if rng.random() < 0.6 else off

    # inference, 2U: two fans.
    box(7, 15, (38, 38, 44), (62, 62, 72))
    for fx in (9, 19):
        for y in range(8, 14):
            for x in range(fx - 4, fx + 5):
                d = ((x - fx) ** 2 + ((y - 10.5) * 1.1) ** 2) ** 0.5
                if d < 1.2:
                    px[y][x] = (90, 90, 100)
                elif d < 3.2:
                    px[y][x] = (24, 24, 28) if (x + y) % 2 else (54, 54, 62)
    px[9][w - 6] = (255, 255, 255) if rng.random() < 0.7 else off

    # storage, 2U: the R710's front. Control panel with its little LCD on the left,
    # then six 3.5" bays in two rows of three, each with an activity light.
    box(16, 24, (70, 72, 80), (96, 98, 110))
    for y in range(17, 23):
        for x in range(5, 8):
            px[y][x] = (40, 42, 50)
    for x in range(5, 8):
        px[18][x] = (90, 150, 230)
    px[21][6] = green
    for r, y0 in enumerate((17, 20)):
        for i in range(3):
            x0 = 9 + i * 6
            for y in range(y0, y0 + 3):
                for x in range(x0, x0 + 5):
                    px[y][x] = (110, 112, 124) if y == y0 else (48, 50, 58)
            px[y0 + 1][x0 + 4] = green if rng.random() < 0.8 else off
            px[y0 + 2][x0 + 4] = blue if rng.random() < 0.5 else off

    # network, 1U: a row of ports, each with a link light.
    box(25, 30, (64, 66, 76), (90, 92, 104))
    for i in range(11):
        x = 5 + i * 2
        px[27][x] = (20, 20, 24)
        px[28][x] = (20, 20, 24)
        px[26][x] = rng.choice([green, green, green, amber, off])

    art_lines = st.render(px)
    labels = {}
    for (name, *details), row in zip(RACK, (0, 4, 8, 13)):
        labels[row] = "`F%s%s`f" % (th.accent, st.spaced(name))
        for i, line in enumerate(details):
            last = i == len(details) - 1
            labels[row + 1 + i] = "`F%s%s`f" % (th.soft if last else th.text, line)
    return [line + "    " + labels.get(i, "") for i, line in enumerate(art_lines)]


if __name__ == "__main__":
    sys.dont_write_bytecode = True
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".lib"))
    try:
        import station
        station.page("lab", COPY, art, subtitle="the homelab, and why it exists")
    except Exception:
        print("#!c=0\n\n`F9bd`_`[← sky`:/page/index.mu]`_`f\n\n`!lab`!\n")
        print("\n".join("%s: %s" % (m[0], ", ".join(m[1:])) for m in RACK) + "\n" + COPY)
