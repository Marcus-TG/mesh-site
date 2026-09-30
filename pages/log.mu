#!c=0
`F7cf`_`[← home`:/page/index.mu]`_`f

>Station Log

Notes from building this node, newest first. Written as I learn, so expect mistakes.

>>2026-09-29  ·  first contact
 - Installed rns + nomadnet on a Mac. First launch: a wall of tracebacks on quit.
   Turns out harmless: LAN discovery threads reading from sockets that were already
   closed.
 - The old public testnet hosts are gone. Found live entry points through the
   community directory instead, and connected to two in Canada.
 - Turned on interface discovery and watched the network describe itself: backbone
   nodes in Belgium and Australia, LoRa gateways in England, and a solar-powered
   microReticulum node in Alabama.
 - Lesson: config keys are case-sensitive. `!Enabled = yes`! quietly disables an
   interface.
 - Stood up a transport node on the homelab: a locked-down container, reachable
   only on my own network, with two uplinks out to the mesh. My laptop now reaches
   everything through it.
 - Built this page.

>>Next
 - LoRa radio (915 MHz) so this station works without the internet
 - A propagation node, so messages wait for me when I'm offline
 - A guestbook
