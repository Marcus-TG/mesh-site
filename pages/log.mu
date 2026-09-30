#!/usr/bin/env python3
# Station log. NomadNet runs this file (it's executable) and serves its stdout as micron.
# Add entries at the top of COPY as you go, same format. The art comes from .lib/station.py
# and the waterfall below.

import os
import sys

COPY = """
### 2026-09-29 · first contact
- installed rns + nomadnet on a Mac
- the old public testnet hosts are gone; found live entry points in the community directory and joined two in Canada
- turned on interface discovery: backbone nodes in Belgium and Australia, LoRa gateways in England, a solar-powered node in Alabama
- 256 nodes heard by morning
- transport node on the homelab, in a locked-down container
- this page

> lesson: config keys are case-sensitive. "Enabled = yes" quietly disables an interface.

## next
- a LoRa radio (915 MHz), so this works without the internet
- a propagation node, so messages wait for me when I'm offline
- a guestbook
"""

HEAT = [(0.0, (6, 8, 20)), (0.22, (16, 26, 62)), (0.45, (24, 90, 150)),
        (0.7, (120, 210, 200)), (0.88, (240, 230, 150)), (1.0, (255, 252, 230))]


def heat(v):
    import station as st
    v = max(0.0, min(1.0, v))
    for (a, ca), (b, cb) in zip(HEAT, HEAT[1:]):
        if v <= b:
            return st.lerp(ca, cb, (v - a) / (b - a))
    return HEAT[-1][1]


def art(th, now):
    # A radio waterfall: time runs down, frequency across. Noise, and a couple of LoRa
    # packets: a preamble of identical up-chirps, then data chirps at shifted starts.
    import random
    import station as st
    rng = random.Random(os.environ.get("link_id") or None)
    w, h = st.COL, 24
    v = [[abs(rng.gauss(0.08, 0.06)) for _ in range(w)] for _ in range(h)]

    def packet(center, bw, start, chirp, count, strength):
        lo = center - bw / 2
        for n in range(count):
            shift = 0 if n < 4 else rng.random()      # preamble, then data symbols
            for sub in range(chirp * 6):
                t = sub / (chirp * 6)
                y = start + n * chirp + t * chirp
                x = lo + ((t + shift) % 1.0) * bw
                yi, xi = int(y), int(x)
                if 0 <= yi < h and 0 <= xi < w:
                    v[yi][xi] = max(v[yi][xi], strength)
                    if xi + 1 < w:
                        v[yi][xi + 1] = max(v[yi][xi + 1], strength * 0.4)

    packet(rng.randint(24, 48), rng.randint(9, 12), rng.randint(-3, 1), 6, 5, 0.95)
    packet(rng.choice([rng.randint(6, 12), rng.randint(60, 66)]), 7, rng.randint(6, 12), 5, 3, 0.5)
    return st.render([[heat(c) for c in row] for row in v])


if __name__ == "__main__":
    sys.dont_write_bytecode = True
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".lib"))
    try:
        import station
        station.page("log", COPY, art, subtitle="notes from building the mesh, newest first")
    except Exception:
        print("#!c=0\n\n`F9bd`_`[← sky`:/page/index.mu]`_`f\n\n`!log`!\n" + COPY)
