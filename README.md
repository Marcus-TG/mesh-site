# mesh-site

My [NomadNet](https://github.com/markqvist/NomadNet) node on the
[Reticulum](https://reticulum.network/) mesh. It's a small site served over an
encrypted, IP-free network, written in micron (NomadNet's terminal markup).

```
pages/
  index.mu        home: a lake horizon, drawn fresh per visit
  about.mu        who runs this node
  log.mu          visitor stats: who's been by, and when
  lab.mu          the homelab it runs on
  workshop.mu     watchmaking
  art.mu          how the pictures are made
  .lib/station.py shared sky, colours, pixel renderer and page frame
```

Every page is a small Python script (executable, stdlib only) that NomadNet runs and
serves the output of. Each one draws its own piece of pixel art for the current time
in Ontario, and the whole site takes its colours from that hour's sky. Dawn is orange,
day is blue, dusk is coral, night is periwinkle.

To change a page's words, edit the `COPY` block at the top of its file. That block
uses a small markup: `## label` for a section, `### label` for a log entry heading,
`- ` for a bullet, `> ` for a dim note. Blank lines are kept. New pages need
`chmod +x`, and NomadNet shows them within a minute.

Every page counts its own visits by appending a line to `station-visits` in
NomadNet's storage folder, next to its `peersettings`. Each line holds the time, the
page name, and short one-way hashes of the connection and (only if the visitor
identified) their identity. The log page draws these and reads NomadNet's own
totals from `peersettings`. Only real requests count, because only they carry a
`link_id`, so running a page from the terminal doesn't add a visit.

`station.py` sits in a dot-directory because NomadNet serves every other file under
`pages/` as a page. If it's ever missing, each page falls back to plain text.

## Local preview

Point a local NomadNet at this folder in `~/.nomadnetwork/config`, under `[node]`:

```ini
enable_node = yes
node_name = Marcus Dev
pages_path = /Users/marcus/Documents/projects/mesh-site/pages
announce_at_start = no        # keep the dev node unadvertised
page_refresh_interval = 1     # pick up new page files every minute
```

Then open `nomadnet` and browse to your own node. Edits to existing pages show on
`Ctrl+R`, and new files appear within a minute. Every page starts with `#!c=0` (no
caching) while developing. Consider `#!c=3600` before going live, so LoRa visitors
don't re-download pages.

Preview a page's raw output from the terminal, at any hour:

```sh
./pages/workshop.mu                     # now
STATION_TIME=19:10 ./pages/index.mu     # dusk
```

Micron reference: NomadNet → Guide → Outputting Formatted Text.

## Live

Pushing to `main` redeploys the node on my homelab, where it announces itself to the
mesh.
