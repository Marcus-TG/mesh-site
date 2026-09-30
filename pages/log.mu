#!/usr/bin/env python3
# Station log: who's been by, and when. NomadNet runs this file (it's executable) and
# serves its stdout as micron. Every page counts its own visits (see .lib/station.py);
# this one draws them as a waterfall and adds NomadNet's own running totals.

import os
import sys
from datetime import datetime, timedelta

DAYS = 12   # rows in the waterfall, today at the top

HEAT = [(0.0, (6, 8, 20)), (0.22, (16, 26, 62)), (0.45, (24, 90, 150)),
        (0.7, (120, 210, 200)), (0.88, (240, 230, 150)), (1.0, (255, 252, 230))]


def heat(st, v):
    v = max(0.0, min(1.0, v))
    for (a, ca), (b, cb) in zip(HEAT, HEAT[1:]):
        if v <= b:
            return st.lerp(ca, cb, (v - a) / (b - a))
    return HEAT[-1][1]


def local(t, now):
    return datetime.fromtimestamp(t, tz=now.tzinfo)


def art(th, now):
    # Visits by hour, one row per day, newest at the top: 2x2 pixels per hour. Empty
    # hours are a faint noise floor, hours still to come today are left blank.
    import random
    import station as st
    rng = random.Random(os.environ.get("link_id") or None)
    today = now.date()
    counts = {}
    for t, *_ in st.visits():
        d = local(t, now)
        key = ((today - d.date()).days, d.hour)
        counts[key] = counts.get(key, 0) + 1
    peak = max(counts.values(), default=1)

    px = []
    for day in range(DAYS):
        for _ in range(2):
            row = []
            for x in range(48):
                hour = x // 2
                if day == 0 and hour > now.hour:
                    row.append(None)
                    continue
                n = counts.get((day, hour), 0)
                v = 0.32 + 0.68 * (n / peak) ** 0.6 if n else rng.uniform(0.02, 0.16)
                row.append(heat(st, v))
            px.append(row)
    lines = st.render(px)

    for day, line in enumerate(lines):
        date = today - timedelta(days=day)
        label = "today" if day == 0 else date.strftime("%a %d").lower()
        total = sum(counts.get((day, h), 0) for h in range(24))
        lines[day] = line + "  `F%s%-7s`f `F%s%s`f" % (th.soft, label, th.accent if total else th.rule,
                                                      total if total else "·")
    axis = "".join("%-12s" % ("%02d" % h) for h in (0, 6, 12, 18))
    lines.append("`F%s%s`f" % (th.rule, axis))
    return lines


def copy(th, now):
    import station as st
    rows = st.visits()
    node = st.node_stats()
    t_now = now.timestamp()
    out = []

    if rows:
        out.append("you're visit no. %s." % format(len(rows), ","))
        out.append("")
        today = [r for r in rows if local(r[0], now).date() == now.date()]
        week = [r for r in rows if t_now - r[0] < 7 * 86400]
        people = {r[3] for r in rows if r[3] != "-"}
        since = local(rows[0][0], now).strftime("%Y-%m-%d")
        out.append("## visits")
        out.append("- %d today · %d this week · %s since %s" % (len(today), len(week),
                                                             format(len(rows), ","), since))
        out.append("- %d connections this week" % len({r[2] for r in week}))
        if people:
            out.append("- %d visitor%s identified themselves" % (
                len(people), "" if len(people) == 1 else "s have"))
        if len(rows) > 1:
            t, page = rows[-2][0], rows[-2][1]
            out.append("- before you: %s, reading %s" % (st.ago(t_now - t), "home" if page == "index" else page))

        out.append("")
        out.append("## most read")
        per = {}
        for r in rows:
            per[r[1]] = per.get(r[1], 0) + 1
        names = ["index"] + [p[0] for p in st.PAGES]
        width = 30
        for name in sorted(names, key=lambda p: -per.get(p, 0)):
            share = per.get(name, 0) / len(rows)
            filled = round(share * width)
            out.append("- `F%s%-9s`f `F%s%s`F%s%s`f  `F%s%3d%%`f" % (
                th.text, "home" if name == "index" else name, th.accent, "█" * filled,
                th.rule, "░" * (width - filled), th.soft, round(share * 100)))
    else:
        out.append("no visits counted yet.")

    if node:
        out.append("")
        out.append("## the node")
        if node.get("node_connects"):
            out.append("- %s links opened" % format(node["node_connects"], ","))
        if node.get("served_page_requests"):
            out.append("- %s pages and %s files served" % (format(node.get("served_page_requests", 0), ","),
                                                         format(node.get("served_file_requests", 0), ",")))
        if node.get("node_last_announce"):
            out.append("- last announced %s" % st.ago(t_now - node["node_last_announce"]))

    return "\n".join(out)


if __name__ == "__main__":
    sys.dont_write_bytecode = True
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".lib"))
    try:
        import station
        station.page("log", copy, art, subtitle="who's been by, and when")
    except Exception:
        print("#!c=0\n\n`F9bd`_`[← sky`:/page/index.mu]`_`f\n\n`!log`!\n\nno stats right now.")
