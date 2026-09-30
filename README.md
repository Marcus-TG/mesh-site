# mesh-site

My [NomadNet](https://github.com/markqvist/NomadNet) node on the
[Reticulum](https://reticulum.network/) mesh. It's a small site served over an
encrypted, IP-free network, written in micron (NomadNet's terminal markup).

```
pages/
  index.mu      home
  about.mu      who runs this node
  log.mu        station log: notes from building the mesh setup
  lab.mu        the homelab it runs on
  workshop.mu   watchmaking
```

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

Micron reference: NomadNet → Guide → Outputting Formatted Text.

## Live

Pushing to `main` redeploys the node on my homelab, where it announces itself to the
mesh.
