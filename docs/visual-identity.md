# Visual Identity

The palette, typography, icon system and motif vocabulary AnNIXion draws from.
Read this before adding an icon, a wallpaper or any user-facing asset.

---

## Two colour worlds

AnNIXion runs a sober red-on-Nord chrome (prompt, panel, menus) over a neon
graffiti wall (wallpapers, lock screen). The chrome stays quiet so the wall can
be loud. The badge system below is the join between them: its semantic colours
are lifted from the wallpaper, so the menu speaks the wall's language.

### Chrome

| Colour | Role | Declared |
|---|---|---|
| `#0E0F13` | Deepest ground | `home/zsh/omp-theme.nix:3` |
| `#1A1D24` | Raised surface | `home/zsh/omp-theme.nix:3` |
| `#2E323D` | Segment, divider | `home/zsh/omp-theme.nix:3` |
| `#FF0033` | The signature accent | 18 uses across `home/` |
| `#DFE4EA` | Primary text | `home/zsh/omp-theme.nix:3` |
| `#4C566A` | Nord slate, muted text | `home/firefox/theme.nix:34` |

### Graffiti

Sampled from `assets/wallpaper/`. Pure black ground, one spray colour per mark.

| Colour | Role |
|---|---|
| `#000000` | Wall ground — 62% of wallpaper pixels |
| `#0F5AE6` | Cobalt — the figure |
| `#F213A0` | Magenta — spray tags, smiley, jester |
| `#33E62B` | Acid green — the throw-up tag |

> The mark in `assets/icons/AnNIXion.png` is white and grey glitch on
> transparency. It is dark-ground only and has no light variant.

---

## Typography

`nerd-fonts.jetbrains-mono` and `nerd-fonts.fira-code` already ship in
`home.nix`. JetBrains Mono is the display and interface face; set it at
`-0.03em` tracking at display sizes. Labels are 11px uppercase at `0.12em`.
Category strings and paths keep the mono face — they are things you type.

---

## The badge system

Every AnNIXion application and menu directory gets a flat-top hexagon carrying
a semantic colour, with a near-white glyph inside.

| Property | Value |
|---|---|
| Canvas | 32 × 32, flat-top hexagon |
| Plate fill | Semantic colour at 16% |
| Rim | Semantic colour, width 1.3 |
| Glyph inset | 5.2 per side, scale 0.567 |
| Glyph grid | 24 × 24, stroke 2.6, round cap and join |
| Glyph colour | `#F0F3F6` — never the semantic colour |
| Export | `scalable/apps/annixion-<tool>.svg` |

### Semantic classes

Colour encodes what running the tool does to the target, not which kill-chain
phase it sits in — the menu already tells you the phase.

| Class | Colour | Rule | Examples |
|---|---|---|---|
| Passive | `#33E62B` | Sends nothing to the target | theHarvester, Whois, SecLists |
| Probe | `#FFD000` | Touches the target and shows in their logs, no access attempted | Nmap, dig, WhatWeb, Gobuster, ffuf, Gqrx |
| Offensive | `#FF0033` | Attempts access, execution or credential compromise | Metasploit, sqlmap, Hydra, Hashcat, Aircrack-ng |
| Forensic | `#0F5AE6` | Reads evidence after the fact, never reaches the network | Volatility 3, Autopsy, Wireshark |
| Reverse | `#F213A0` | Pulls a compiled artifact apart | Ghidra, Binwalk |
| Utility | `#7A8494` | Not a tool of the trade | Kate, Ark, KCalc, Dolphin, Konsole |

Red means the tool needs written authorisation behind it. That is the one class
where the badge is a check on muscle memory rather than decoration.

Phases 03 through 07 all land on offensive red, giving the menu an unbroken red
band down its middle — the stretch where you are inside someone else's estate.
If that proves too heavy, move 03 Delivery to probe amber so red means access
achieved.

### Drawing a new glyph

| Rule | Value | Why |
|---|---|---|
| Grid | 24 × 24, glyph inside 21 × 21 | Leaves air so the hexagon never crops a stroke end |
| Stroke | 2.6, round cap and join | Survives the 0.567 downscale and stays solid at 22px |
| Fills | Only for dots under 2.5 units | Filled areas go muddy over the plate wash |
| Detail budget | Four strokes or fewer | Busier reads as texture at menu size |
| Subject | What the tool does, never its logo | Upstream logos break the set; most of these tools have none |
| Naming | `annixion-<tool>` | Namespaced against upstream hicolor icons |

Test at 22px first. If a glyph fails there, delete a stroke — do not thicken it.

---

## Motif vocabulary

The wallpapers carry a fixed cast: dead-eyed smiley, jester, skull, snowflake,
`404`, the throw-up tag. Reuse these rather than inventing new ones.

Motifs live on pure black and nowhere else. They drip downward, never upward.
One spray colour per motif, never two in the same mark.

Allowed: wallpaper, lock screen, ISO boot splash, fastfetch banner, README
header, release art. Not allowed: the menu, the panel, or any badge.

---

## Current state

`home/plasma.nix:27` selects `Slot-Nord-Dark-Colorize-Icons`, which ships 195
place icons and no `apps`, `actions` or `devices` directories — so application
icons fall through to stock `breeze-dark`. Of the 32 distinct icon names in
`home/apps-menu.nix`, that theme resolves 4.

Four names resolve nowhere in the chain and render as a placeholder:

| Entry | Current | Correct |
|---|---|---|
| VSCodium | `codium` | `vscodium` |
| Wireshark | `wireshark` | `org.wireshark.Wireshark` |
| Netcat | `network-transmit-receive` | dropped from Breeze 6, needs replacing |
| Binwalk | `media-removable` | dropped from Breeze 6, needs replacing |

See [roadmap.md](roadmap.md) for where this sits in 0.4.0.
