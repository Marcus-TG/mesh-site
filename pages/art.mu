#!/usr/bin/env python3
# How the art is made. NomadNet runs this file (it's executable) and serves its stdout
# as micron. Edit the copy in COPY; the frame comes from .lib/station.py.

import math
import os
import sys

COPY = """
## the sky
- nine colour keys across the day, a zenith and a horizon for each, blended in between
- the sun rides an arc from 6:18 to 19:42, then the moon takes over, with stars after dark
- the skyline, the ripples and the light on the water are random, seeded by your connection, so every visit gets its own sky. "sky no." is the start of that seed.

## the pages
- about: the same sky, as a thin strip
- log: visits by hour, drawn like a radio waterfall
- lab: a rack drawn pixel by pixel, its lights different every visit
- workshop: the hands are worked out from the time, and every pixel is sampled nine times so the round case and thin hands stay smooth
- titles: a five-pixel font with a drop shadow

## colour
Titles, labels and links take their colour from the horizon at this hour, brightened until they're readable. Dawn comes out orange, day blue, dusk coral, night periwinkle.

## how it runs
Every page is a small Python script. NomadNet runs it for each request and sends back whatever it prints, so the picture you get is made the moment you ask for it.
"""


def art(th, now):
    # A whole day of this sky in one strip: midnight to midnight across, zenith to
    # horizon down, with the sun's and moon's arcs traced over it.
    import station as st
    w, h = st.COL, 20
    px = []
    for y in range(h):
        row = []
        for x in range(w):
            zenith, low = st.sky_at(x / w * 24)
            row.append(st.lerp(zenith, low, (y / (h - 1)) ** 1.6))
        px.append(row)
    for x in range(w):
        t, body, glow, _ = st.celestial(x / w * 24)
        y = round(h - 3 - math.sin(t * math.pi) * (h - 7))
        px[y][x] = st.lerp(px[y][x], body, 0.85)

    lines = st.render(px)
    x_now = min(w - 1, int(st.hour_of(now) / 24 * w))
    lines.append("`F%s%s▲`f" % (th.accent, " " * x_now))
    lines.append("`F%s%s`f" % (th.rule, "".join("%-18s" % ("%02d" % hr) for hr in (0, 6, 12, 18))))
    return lines


if __name__ == "__main__":
    sys.dont_write_bytecode = True
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".lib"))
    try:
        import station
        station.page("art", COPY, art, subtitle="how the pictures on this site are made")
    except Exception:
        print("#!c=0\n\n`F9bd`_`[← sky`:/page/index.mu]`_`f\n\n`!art`!\n" + COPY)
