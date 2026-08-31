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

## The mark system

Every AnNIXion application and menu directory gets a single-colour line drawing
filling its whole canvas. No container, no plate — the colour classifies, the
silhouette identifies.

| Property | Value |
|---|---|
| Canvas | 24 × 24, drawing fills 21 × 21 |
| Stroke | 2.1, round cap and join |
| Colour | Whole mark in one class colour |
| Fills | Only for dots under 2.5 units |
| On the wallpaper | 1.5 outer stroke in `#0E0F13`; the menu does not need it |
| Export | `scalable/apps/annixion-<tool>.svg` |

An earlier revision seated each glyph inside a hexagonal badge. It was dropped:
the container spent 82% of the canvas on itself, leaving the drawing at 18% of
the area and a 1.01px stroke once the menu rendered 22px. Two tools in the same
class became a coloured hexagon with a smudge inside. Filling the canvas gives
4.2× the drawn area and 1.9× the stroke weight from the same drawings.

The hexagon had been buying a family resemblance and a hard edge against a busy
wallpaper. The colour system carries the family resemblance on its own, and the
menu draws on a solid `#14171D` panel rather than on the wallpaper — so only
desktop shortcuts need the edge, which the outer stroke supplies for free.

### Semantic classes

Colour encodes what running the tool does to the target, not which kill-chain
phase it sits in — the menu already tells you the phase. Contrast ratios are
measured as a stroke against the `#14171D` menu ground.

| Class | Colour | Contrast | Rule | Examples |
|---|---|---|---|---|
| Passive | `#33E62B` | 10.7:1 | Sends nothing to the target | theHarvester, Whois, SecLists |
| Probe | `#FFD000` | 12.2:1 | Touches the target and shows in their logs, no access attempted | Nmap, dig, WhatWeb, Gobuster, ffuf, Gqrx |
| Offensive | `#FF0033` | 4.5:1 | Attempts access, execution or credential compromise | Metasploit, sqlmap, Hydra, Hashcat, Aircrack-ng |
| Forensic | `#4A90FF` | 5.8:1 | Reads evidence after the fact, never reaches the network | Volatility 3, Autopsy, Wireshark |
| Reverse | `#F213A0` | 4.6:1 | Pulls a compiled artifact apart | Ghidra, Binwalk |
| Utility | `#7A8494` | 4.8:1 | Not a tool of the trade | Kate, Ark, KCalc, Dolphin, Konsole |

Forensic is the wallpaper's cobalt `#0F5AE6` lifted to `#4A90FF`. The wallpaper
value works as a large filled figure on pure black but reaches only 3.1:1 as a
2px stroke — the one colour in the set that fails. Keep `#0F5AE6` for fills and
`#4A90FF` for marks.

Red means the tool needs written authorisation behind it. That is the one class
where the badge is a check on muscle memory rather than decoration.

Phases 03 through 07 all land on offensive red, giving the menu an unbroken red
band down its middle — the stretch where you are inside someone else's estate.
If that proves too heavy, move 03 Delivery to probe amber so red means access
achieved.

### Drawing a new mark

| Rule | Value | Why |
|---|---|---|
| Grid | 24 × 24, drawing fills 21 × 21 | 1.5 units of air each side so round caps never clip |
| Stroke | 2.1, round cap and join | Lands at 1.93px when the menu draws 22px |
| Detail budget | Five strokes or fewer | Busier reads as texture at menu size |
| Silhouette | Must differ from its classmates | Inside a class the colour is identical, so shape is the only differentiator |
| Subject | What the tool does, never its logo | Upstream logos break the set; most of these tools have none |
| Naming | `annixion-<tool>` | Namespaced against upstream hicolor icons |

Test at 22px, next to its classmates — not alone and not at 96px. A mark is
finished when you can pick it out of its own class colour at menu size. If you
cannot, change the shape rather than adding detail.

---

## Motif vocabulary

The wallpapers carry a fixed cast: dead-eyed smiley, jester, skull, snowflake,
`404`, the throw-up tag. Reuse these rather than inventing new ones.

Motifs live on pure black and nowhere else. They drip downward, never upward.
One spray colour per motif, never two in the same mark. Motifs are drawn looser
than tool marks: stroke 1.7, hand-weighted curves, allowed to overshoot. Tool
marks borrow the wall's palette, never its hand.

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
