#!c=0
`F7cf`_`[← home`:/page/index.mu]`_`f

>The Lab

The hardware this node lives on. Specs, not addresses.

`t
| Role | Box | Notes |
| ---- | --- | ----- |
| service host | Ryzen 9 · 32 GB | Docker, every stack defined in git |
| inference | Ryzen 7 · RTX 3090 | local LLMs instead of cloud APIs |
| storage | TrueNAS SCALE | the boring, important one |
| network | UniFi | VLANs, dual-WAN |
`t

>>This node
The Reticulum daemon runs in its own container: read-only filesystem, no
capabilities, its own network, one mounted folder. It connects outward to a couple of
public entry points and relays for my own devices. Nothing on my router is open for it.

>>Rule of the lab
If it isn't in the repo, it doesn't exist.
