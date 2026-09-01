# Visual Identity

The name, palette, typography, marks and motif vocabulary AnNIXion draws from,
and the rule for every surface it puts in front of you. Read this before adding
an icon, a wallpaper, a theme or any user-facing asset.

This file is the normative reference and is written for whoever is building the
thing. [visual-identity.pdf](visual-identity.pdf) is the same system as an
18-page design board for 0.4.0 "Nebula", written for a design audience: the
mission, the lockup, the specimen, the full mark set and the eight laws, with
the implementation left here. It is regenerated from a built icon theme by
`branding/identity-board.sh`, which refuses to print if any page has outgrown
itself.

---

## Name and mark

Always **AnNIXion** in running text — one word, capital A, capital NIX. Never
*Annixion*, never *ANNIXION*.

In the wordmark, the three letters of NIX carry the signature red and the rest
stays light, so the Nix lineage is legible without saying it. Letterspacing is
wide (0.30em), weight is light: it is a wordmark, not a headline.

The lockup carries **no lowercase**. AN and ION are set as small capitals at
0.62em; NIX stays full size in the signature red. Both parts are capitals, so
they share a baseline and the colour does all the emphasis. In running text the
name is still written AnNIXion — the small-cap treatment belongs to the lockup
alone, which appears once per surface and never inside a sentence.

| Element | Value |
|---|---|
| Wordmark | `AN`·**NIX**·`ION` — small caps either side, NIX in `#FF0033` |
| Descriptor | OFFENSIVE SECURITY DISTRIBUTION, boxed in a hairline red rule |
| Tagline | "The environment for operators who refuse to wing it" — README and release notes only, never the lockup |
| Logo | Nix snowflake under a datamosh glitch, `assets/icons/AnNIXion.png` |
| Launcher mark | The same snowflake drawn to the mark rules, `annixion-logo` |
| Codename | One word in `RELEASE_NAME` beside the number in `VERSION` |

Shipping today is **0.3.1 "Tripwire"**. Next is **0.4.0 "Nebula"**.

> The datamosh logo is **dark-ground only** — light artwork on transparency, it
> vanishes on any light surface. It is a hero image: the Plymouth splash, the
> fastfetch banner, the ISO menus and the README header, all of which draw it
> large.
>
> It is **not** an icon. At the 32px the panel gives it, the glitch bars collapse
> into a smear, so the launcher wears `annixion-logo` instead — the same
> snowflake drawn to the mark rules, one stroke colour, legible at 16px. Because
> it is a stroke rather than baked pixels, it is also the first form of the mark
> that can be recoloured for a light surface.

### Independent of Nix

AnNIXion is built on NixOS and proud of that lineage — the name says so out
loud. It is **not made by, affiliated with, endorsed by, sponsored by or
connected to** the NixOS Foundation, the Nix project, or anyone who works on
them. Nix and NixOS are the work of their own community and owe this project
nothing.

Say this wherever the name might be read as a claim of endorsement: the design
board carries it on its first page. The name is a statement of lineage, never
of affiliation.

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
| Grid | 24 × 24, and the drawing may use all of it |
| Canvas | The grid padded 1.3 units all round — see below |
| Stroke | 2.3275, round cap and join |
| Colour | Whole mark in one class colour |
| Families | One application in several colours shares one body — see below |
| Crossing | A symbol that crosses another is knocked out — see below |
| Fills | Only for dots under 2.5 units |
| On the wallpaper | 1.5 outer stroke in `#0E0F13`; the menu does not need it |
| Export | `scalable/apps/annixion-<tool>.svg` |

### Families

Where one application appears several times under different colours, every
copy shares a single drawing and the colour carries the whole difference. Two
families exist: the four browser profiles and the three terminals. Their
bodies are bound once at the top of `home/icons/marks.nix`, so a redraw cannot
drift between the variants and a fifth variant costs no artwork at all.

This is the rule that decided the browser mark. A globe is the more obvious
browser drawing, but at 22px it is indistinguishable from the Internet
directory's own globe, which sits directly above it. The window and tab is one
stroke less obvious and unmistakably not that.

An earlier revision seated each glyph inside a hexagonal badge. It was dropped:
the container spent 82% of the canvas on itself, leaving the drawing at 18% of
the area and a 1.01px stroke once the menu rendered 22px. Two tools in the same
class became a coloured hexagon with a smudge inside. Filling the canvas gives
4.2× the drawn area and 1.9× the stroke weight from the same drawings.

### Crossing symbols

The lightning through the signal arcs, the blade through the datastore, the
lens laid over the page: a symbol that crosses another is the same colour at
the same weight as the thing it crosses, so at menu size the crossing fuses and
both shapes are lost. Aircrack was three arcs and a lightning bolt, and at 22px
it was a red smudge.

A crossing symbol is therefore drawn **twice** — once in the ground colour
`#14171D` at stroke 4.2, then normally at 2.3275 on top. The wide pass cuts a
gap either side of the crossing symbol. On the menu ground that gap is
invisible and the two shapes simply separate; on the wallpaper it reads as the
dark outline the marks take there anyway.

In `marks.nix` this is the mark's `over` attribute. Order matters: body, then
knockout, then the symbol.

| Rule | Value |
|---|---|
| Knockout stroke | 4.2 in `#14171D` — a gap of about 0.9 either side |
| Applies to | A symbol that **crosses** another shape's stroke |
| Does not apply to | A symbol that sits **inside** one |

That last line is the one that costs you. Knocking out the X inside John's key
head only eats the head, and knocking out Metasploit's spokes eats its core —
both are drawn flat for that reason. Note also that the knockout is nearly
twice the normal stroke, so a crossing symbol needs correspondingly more room
from the edge; `mark-bbox.py` caught WhatWeb's lens handle the moment it was
promoted.

### The canvas is bigger than the grid

A round cap or join reaches **half a stroke width** past the geometry that
draws it. A drip that ends on the bottom of the grid therefore has its tip
sliced flat by the viewBox — and a sliced cap does not read as a short drip, it
reads as a cut. Round tip at the top where the drip leaves the shape, square
end at the bottom: exactly backwards.

So the rendered canvas is the grid plus 1.3 units on every side, and the stroke
is scaled by the same ratio (2.1 → 2.3275) so the weight on screen is
unchanged. The drawing still lives on the 24-unit grid; the pad exists only to
hold the ink the stroke throws beyond it.

Both halves are enforced. `branding/mark-bbox.py` walks every path in the built
theme — Bézier extrema included, not just the control points — and fails if any
mark's geometry leaves the grid or any mark's ink leaves the canvas.
`tests/menu-icons.sh` runs it. It was written after 32 of 81 marks turned out
to be losing ink off the edge, twelve of them drips.

### The hand

Adding a drip to a machine-perfect rectangle does not make it graffiti — it
makes it a rectangle with a drip. The hand has to be in the geometry itself.

Rules 1 and 2 are universal and apply to every mark in the set. Rules 3 and 4
are semantic and are earned.

| # | Device | Rule |
|---|---|---|
| 1 | No straight lines | Every "straight" run bows by about half a unit, and no two are parallel. A hand cannot draw a true horizontal, and the eye reads the difference before it can name it. This does the most work. |
| 2 | No closed circles | Radii vary by up to half a unit around the turn, and the shape never quite meets itself — one gap where the marker lifted. Always on a curve, never on a straight run, never more than one per mark. |
| 3 | The drip | One run of wet paint from the lowest edge that has room, 3–4.5 units, same stroke weight, rounded tip. The signature move. |
| 4 | The X | Struck across anything the tool defeats, overshooting the shape it crosses. If the tool does not break the thing, it does not get the X. |

Corners and crossings overshoot their joins by up to a unit throughout — the
marker keeps moving after the shape has ended.

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

### Session colours

The six classes above say what a tool does to a target. A terminal does
nothing to a target, so the terminal family is coloured by the session you are
standing in instead — and the values are the prompt's own, so the launcher and
the shell it opens agree before you have typed anything.

| Colour | Value | Contrast | Session | Declared |
|---|---|---|---|---|
| Utility | `#7A8494` | 4.8:1 | The operator's own shell | the class table above |
| Elevated | `#FF0033` | 4.5:1 | root | `home/zsh/omp-theme.nix:37` |
| Nix | `#7EBAE4` | 8.6:1 | Inside `nix develop` or `nix-shell` | `home/zsh/omp-theme.nix:38` |

Elevated repeats the signature red rather than introducing a seventh value:
root is the one session that is dangerous to miss, and it should read as the
same red the root Konsole background and the prompt already use. These two
colours are the terminal family's alone — no tool mark may take them.

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
| Grid | 24 × 24, edge to edge | The pad below is what keeps caps off the edge |
| Stroke | 2.3275, round cap and join | Lands at 1.93px when the menu draws 22px |
| Detail budget | Five strokes or fewer | Spend the sixth on silhouette, never on texture |
| Hand | Bowed lines and open curves, always | Devices 1 and 2 are not optional — a true horizontal anywhere breaks the set |
| Drip and X | Earned, not decorative | The drip goes on the lowest edge with room; the X only where the tool breaks something |
| Silhouette | Must differ from its classmates | Inside a class the colour is identical, so shape is the only differentiator |
| | | `gh` shipped as a terminal window with a prompt in it — the same drawing as Konsole, in the same grey. Two unrelated tools may not share a silhouette; it now takes the branch graph in a window. No test catches this, so it is on review. |
| Subject | What the tool does, never its logo | Upstream logos break the set; most of these tools have none |
| Naming | `annixion-<tool>` | Namespaced against upstream hicolor icons |
| Stock alias | Add to `aliases` in `home/icons/default.nix` | Only if the tool ships its own `.desktop` entry — see below |

Test at 22px, next to its classmates — not alone and not at 96px. A mark is
finished when you can pick it out of its own class colour at menu size. If you
cannot, change the shape rather than adding detail.

### Stock icon names

A tool packaged with its own `.desktop` entry asks for the icon name that entry
declares, not for ours, and `home/plasma.nix` pins those entries deliberately —
Plasma matches a window to its launcher by class, and only the stock name
resolves. A mark named `annixion-<tool>` is therefore never consulted for them:
Konsole asks for `utilities-terminal`, Dolphin for `org.kde.dolphin`, and both
fall through to the inherited theme.

The `aliases` set in `home/icons/default.nix` installs those marks under the
stock names as well, as symlinks onto the namespaced file. Three of the names
are generic freedesktop ones rather than app-specific — `utilities-terminal`,
`accessories-calculator` and `preferences-system` — so the mark answers for any
application of that kind, which is the intent here but is worth knowing before
adding a fourth.

`tests/menu-icons.sh` requires every un-namespaced file in the theme to be one
of these symlinks pointing at a mark that exists. Whether a given alias names
the right mark is not tested, and stays on review.

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
| Boot loader | themed | systemd-boot draws a text menu and takes no theme, so the mark's first appearance is the Plymouth splash. `modules/branding.nix` |
| Login (SDDM) | themed | Breeze's greeter rebranded through `theme.conf` alone — no QML of our own |
| Lock screen | themed | `wallpaper_2.png` via `home/plasma.nix:36` |
| Desktop | themed | `wallpaper_1.png`, `preserveAspectFit` on pure black |
| Panel | themed | 32px, `annixion-logo` as launcher icon |
| Application menu | themed | 46 entries across 33 categories, 81 marks |
| Terminal | themed | Konsole, 85% opacity with blur |
| Prompt | themed | oh-my-posh, chrome palette, red accent diamonds |
| fastfetch | themed | AnNIXion mark at width 30, keys and title in red |
| Browser profiles | themed | One mark in four class colours |
| README / GitHub | themed | Glitch banner, wordmark lockup, badge row |
| ISO | themed | Banner on black for both the syslinux and GRUB menus, plus the same Plymouth splash |

### Boot and greeter

The boot splash is a Plymouth `script` theme: the mark on the void ground with
one red progress rule, and a password prompt for an encrypted root. It lives in
`branding/default.nix` and is copied into the initrd, so it must stay small.

`boot.loader.timeout` stays at 3 seconds. A splash that cannot be interrupted
is a machine with no way back to an older generation.

The greeter is Breeze's, rebranded entirely through `theme.conf` — background,
logo and the `#FF0033` accent. Writing QML of our own was rejected: a greeter
that fails to load leaves no way into the machine, and Breeze's is already
tested by everyone running Plasma.

Note that `plasma6.nix` also sets the SDDM theme with `mkDefault`, so
`modules/branding.nix` uses `lib.mkOverride 900` — `mkDefault` there is a
conflict rather than an override, and 900 still yields to `user/`.

### Elevation

The root Konsole profile swaps the whole background to `#301212` rather than
adding a warning icon (`home/konsole.nix:53`). The rule generalises: privilege
changes the surface you are standing on, never a decoration bolted onto it.

---

## Browser profiles

Four profiles, one drawing. The mark is a browser window with a tab, and the
class colour is the only thing that changes between them — the same rule the
recoloured Firefox logos followed before them, held to the mark system instead
of to a raster of somebody else's artwork.

| Profile | Mark | Class | Colour |
|---|---|---|---|
| Unsafe Browser | `annixion-firefox-untrusted` | utility | `#7A8494` |
| Red Team | `annixion-firefox-redteam` | offensive | `#FF0033` |
| OSINT | `annixion-firefox-osint` | probe | `#FFD000` |
| Puppet Master | `annixion-firefox-puppet` | passive | `#33E62B` |

OSINT is amber rather than green deliberately: the profile drives a real browser
at a real target through `annixion-vpn-browser`, fetching their pages and
landing in their logs. That is probe, not passive. Puppet Master takes green
because persona work touches archives and social surfaces, not the target
estate.

A fifth or sixth profile needs no artwork — forensic `#4A90FF` and reverse
`#F213A0` are two lines in `marks.nix`. That is what the six recoloured PNGs
were paying a megabyte for, and two of the six (`firefox-blue.png`,
`firefox-purple.png`) were never referenced at all. All six are gone.

---

## Terminals

The same rule, on the other family. One terminal drawing, three sessions,
coloured by the [session colours](#session-colours) above.

| Entry | Mark | Session |
|---|---|---|
| Konsole | `annixion-konsole` | The operator's own shell |
| Konsole (root) | `annixion-konsole-root` | `sudo -i`, on the `#301212` root profile |
| Konsole (Nix shell) | `annixion-konsole-nix` | `nix develop`, where the checks run |

This is the [elevation rule](#elevation) reaching one surface earlier. The root
Konsole already changes the ground you are standing on once the window is open;
colouring the launcher says it while the pointer is still over the menu.

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

## How it is built

`home/icons/marks.nix` holds one entry per mark — a class and the 24-grid
drawing. The two family bodies are bound in a `let` at the top of that file and
referenced by name, so the four browsers and the three terminals cannot drift
apart. `home/icons/default.nix` renders each into
`scalable/apps/annixion-<name>.svg`, the class supplying the stroke colour, and
emits an `index.theme` inheriting `Slot-Dark-Icons`, `breeze-dark`, `Adwaita`
and `hicolor`. Anything the set does not draw still falls back to a real icon.

`home.nix` joins that theme with `SlotIcons` into the single directory
`xdg.dataFile."icons"` owns, and `home/plasma.nix` selects `AnNIXion`.

Reclassifying a tool is a one-word change to its `class`. Redrawing one is a
change to its `body` — or, for a family member, to the shared body every
variant reads. Neither touches `home/apps-menu.nix`, which names marks
only by `annixion-<tool>` and `annixion-menu-<slug>`.

Adding a menu entry means adding its mark in the same commit —
`tests/menu-icons.sh` fails on any `Icon=` that resolves nowhere, which is the
check that would have caught the four dead names below.

The theme this replaced, `Slot-Nord-Dark-Colorize-Icons`, shipped 195 place
icons and no `apps`, `actions` or `devices` directories, so every application
icon fell through to stock `breeze-dark` — it resolved 4 of the 32 names the
menu used. Four resolved nowhere at all and drew a blank placeholder:

| Entry | Was | Now |
|---|---|---|
| VSCodium | `codium` — resolved nowhere | `annixion-vscodium` |
| Wireshark | `wireshark` — resolved nowhere | `annixion-wireshark` |
| Netcat | `network-transmit-receive` — dropped from Breeze 6 | `annixion-netcat` |
| Binwalk | `media-removable` — dropped from Breeze 6 | `annixion-binwalk` |

See [roadmap.md](roadmap.md) for where this sits in 0.4.0.
