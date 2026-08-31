# Visual Identity

The name, palette, typography, marks and motif vocabulary AnNIXion draws from,
and the rule for every surface it puts in front of you. Read this before adding
an icon, a wallpaper, a theme or any user-facing asset.

---

## Name and mark

Always **AnNIXion** in running text — one word, capital A, capital NIX. Never
*Annixion*, never *ANNIXION*.

In the wordmark, the three letters of NIX carry the signature red and the rest
stays light, so the Nix lineage is legible without saying it. Letterspacing is
wide (0.30em), weight is light: it is a wordmark, not a headline.

| Element | Value |
|---|---|
| Wordmark | `anNIXion`, NIX in `#FF0033` |
| Descriptor | OFFENSIVE SECURITY DISTRIBUTION, boxed in a hairline red rule |
| Tagline | "The environment for operators who refuse to wing it" — README and release notes only, never the lockup |
| Logo | Nix snowflake under a datamosh glitch, `assets/icons/AnNIXion.png` |
| Codename | One word in `RELEASE_NAME` beside the number in `VERSION` |

Shipping today is **0.3.1 "Tripwire"**. Next is **0.4.0 "Nebula"**.

> The logo is **dark-ground only** — light artwork on transparency, it vanishes
> on any light surface. Used as the panel launcher (`home/plasma.nix:191`) and
> the fastfetch logo. No light variant exists; one must be drawn before any
> light surface can.

### The X

The X is the crossed-out letter in the wordmark, the eyes on the graffiti
smiley, and the shape an operator draws over a finished target. It is the
system's recurring device — already present in three places that were never
talking to each other.

---

## Palette

A sober red-on-Nord chrome runs the interface; a neon graffiti wall runs behind
it. The mark colours are lifted off the wall, so the menu speaks the wallpaper's
language the moment it opens.

### Chrome

| Colour | Role | Declared |
|---|---|---|
| `#0E0F13` | Deepest ground | `home/zsh/omp-theme.nix:3` |
| `#1A1D24` | Raised surface | `home/zsh/omp-theme.nix:3` |
| `#2E323D` | Segment, divider | `home/zsh/omp-theme.nix:3` |
| `#FF0033` | The signature accent | 18 uses across `home/` |
| `#DFE4EA` | Primary text | `home/zsh/omp-theme.nix:3` |
| `#301212` | Root ground | `home/konsole.nix:55` |

### Graffiti

Sampled from `assets/wallpaper/`. Pure black ground, one spray colour per mark.

| Colour | Role |
|---|---|
| `#000000` | Wall ground — 62% of wallpaper pixels |
| `#0F5AE6` | Cobalt — the figure |
| `#F213A0` | Magenta — spray tags, smiley, jester |
| `#33E62B` | Acid green — the throw-up tag |

---

## Typography

`nerd-fonts.jetbrains-mono` and `nerd-fonts.fira-code` already ship in
`home.nix`. JetBrains Mono is the display and interface face; set it at
`-0.03em` tracking at display sizes. Labels are 11px uppercase at `0.12em`.
Category strings and paths keep the mono face — they are things you type, and
should look typed. The wordmark is the one place letterspacing goes wide.

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

### The hand

Marks are drawn fast, by someone who does not care to close a shape neatly.
These are the only four devices. Apply one or two per mark, never all four, and
never at the cost of reading it at 22px.

| Device | Rule |
|---|---|
| Overshoot | Strokes run past their joins by about one unit. The strongest signal a drawing was not made with a mouse. |
| Broken stroke | One deliberate gap where the marker lifted. Always on a curve, never on a straight run, never more than one per mark. |
| The drip | One run of wet paint from the lowest edge, 3–4.5 units, same stroke weight, rounded tip. The signature move. |
| The X | Struck across anything the tool defeats. Semantic, not decorative — if the tool does not break the thing, it does not get the X. |

Rotating marks off-axis was tried and rejected: it reads as hand-drawn at 96px
and as a rendering bug at 22px, and a menu column all leaning the same way looks
broken rather than deliberate. The hand lives in the strokes, not the transform.

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

Red means the tool needs written authorisation behind it. That is the one class
where the mark is a check on muscle memory rather than decoration.

Forensic is the wallpaper's cobalt `#0F5AE6` lifted to `#4A90FF`. The wallpaper
value works as a large filled figure on pure black but reaches only 3.1:1 as a
2px stroke. Keep `#0F5AE6` for fills, `#4A90FF` for marks.

Phases 03 through 07 all land on offensive red, giving the menu an unbroken red
band down its middle — the stretch where you are inside someone else's estate.
If that proves too heavy, move 03 Delivery to probe amber so red means access
achieved.

### Drawing a new mark

| Rule | Value | Why |
|---|---|---|
| Grid | 24 × 24, drawing fills 21 × 21 | 1.5 units of air each side so round caps never clip |
| Stroke | 2.1, round cap and join | Lands at 1.93px when the menu draws 22px |
| Detail budget | Five strokes or fewer | Spend the sixth on silhouette, never on texture |
| Hand | One or two devices | All four at once reads as noise, not as a tag |
| Silhouette | Must differ from its classmates | Inside a class the colour is identical, so shape is the only differentiator |
| Subject | What the tool does, never its logo | Upstream logos break the set; most of these tools have none |
| Naming | `annixion-<tool>` | Namespaced against upstream hicolor icons |

Test at 22px, next to its classmates — not alone and not at 96px. A mark is
finished when you can pick it out of its own class colour at menu size. If you
cannot, change the shape rather than adding detail.

---

## Motif vocabulary

The wallpapers carry a fixed cast: dead-eyed smiley, jester, skull, snowflake,
`404`, the throw-up tag, the X. Reuse these rather than inventing new ones.

Motifs live on pure black and nowhere else. They drip downward, never upward.
One spray colour per motif, never two in the same mark. Drawn looser than tool
marks: stroke 1.7, hand-weighted curves, allowed to overshoot much further.

Allowed: wallpaper, lock screen, ISO boot splash, fastfetch banner, README
header, release art. Not the panel and not the menu — with one exception, the
X-eyed smiley is the Post-Exploitation mark, because there it states something
true rather than decorating.

---

## Surfaces

| Surface | State | Notes |
|---|---|---|
| Boot loader | **stock** | No Plymouth theme. First thing seen at power-on and entirely un-branded — the largest gap |
| Login (SDDM) | **stock** | `modules/desktop.nix:15` enables it but themes nothing |
| Lock screen | themed | `wallpaper_2.png` via `home/plasma.nix:33` |
| Desktop | themed | `wallpaper_1.png`, `preserveAspectFit` on pure black |
| Panel | themed | 32px, AnNIXion mark as launcher icon |
| Application menu | in progress | 41 entries, 34 directories |
| Terminal | themed | Konsole, 85% opacity with blur |
| Prompt | themed | oh-my-posh, chrome palette, red accent diamonds |
| fastfetch | themed | AnNIXion mark at width 30, keys and title in red |
| Browser profiles | themed | Four colour-coded Firefox profiles |
| README / GitHub | themed | Glitch banner, wordmark lockup, badge row |
| ISO | **stock** | Inherits the boot loader gap |

### Elevation

The root Konsole profile swaps the whole background to `#301212` rather than
adding a warning icon (`home/konsole.nix:53`). The rule generalises: privilege
changes the surface you are standing on, never a decoration bolted onto it.

---

## Browser profiles

The four Firefox profiles were colour-coded before the semantic classes existed
and map cleanly onto them.

| Profile | Asset | Class |
|---|---|---|
| Unsafe Browser | `firefox-grey.png` | utility |
| Red Team | `firefox-red.png` | offensive |
| OSINT | `firefox-yellow.png` | probe |
| Puppet Master | `firefox-green.png` | passive |
| — unused — | `firefox-blue.png` | reserve for forensic |
| — unused — | `firefox-purple.png` | recolour to `#F213A0` for reverse |

OSINT is amber rather than green deliberately: the profile drives a real browser
at a real target through `annixion-vpn-browser`, fetching their pages and
landing in their logs. That is probe, not passive. Puppet Master takes green
because persona work touches archives and social surfaces, not the target
estate.

`firefox-blue.png` and `firefox-purple.png` exist in `assets/icons/` and are
referenced nowhere.

---

## Voice

**Do** state what happened and what to do about it. Name things the way an
operator does — *targets*, *hosts*, *captures*. Say the consequence before the
mechanism, in commit messages and errors alike. Keep the dry register: the wall
is loud so the words do not have to be.

**Don't** reach for hacker-movie voice — no "pwned", no leetspeak, no skull
emoji in output. Don't apologise in errors or hedge with "something went wrong".
Don't use the graffiti vocabulary in UI copy; it belongs on the wall, not in a
dialog. Don't explain what a tool is in a menu label — the menu is for finding,
not teaching.

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
