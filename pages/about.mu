#!/usr/bin/env python3
# About. NomadNet runs this file (it's executable) and serves its stdout as micron.
# Edit the copy in COPY below; the frame and art come from .lib/station.py.

import os
import sys

COPY = """
Marcus. Southern Ontario.

## now
- Software Development & Network Engineering at Sheridan College
- running this node, and a homelab to run it on
- building watches, slowly

## before
- tech support at an ISP: fiber, coax, WiFi, VoIP
- a lot of patient explaining

## why a mesh node
Reticulum has no IP addresses. Addressing, routing and trust are rebuilt from keys, which is a good way to learn what they are.

> reach me: Msg Op from your client, or LXMF if you have my address
"""


def art(th, now):
    # A thin strip of the same sky the home page shows, with a still lake under it.
    import random
    import station as st
    rng = random.Random(os.environ.get("link_id") or None)
    w, horizon, h = st.COL, 11, 16
    px, cx, body = st.sky(rng, th.hour, w, horizon, scale=0.8)
    for y in range(horizon, h):
        depth = (y - horizon) / (h - horizon)
        src = px[max(0, horizon - 1 - (y - horizon) * 2)]
        row = [st.lerp(src[x], (8, 20, 40), 0.5 + depth * 0.3) for x in range(w)]
        for x in range(w):
            if abs(x - cx) < 1.5 + depth * 3 and rng.random() < 0.55:
                row[x] = st.lerp(row[x], body, 0.45)
        px.append(row)
    return st.render(px)


if __name__ == "__main__":
    sys.dont_write_bytecode = True
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".lib"))
    try:
        import station
        station.page("about", COPY, art, subtitle="who runs this node")
    except Exception:
        print("#!c=0\n\n`F9bd`_`[← sky`:/page/index.mu]`_`f\n\n`!about`!\n" + COPY)
