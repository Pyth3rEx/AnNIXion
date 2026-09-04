#!/usr/bin/env python3
"""Render docs/visual-identity.md into a print-ready design board.

Marks are read out of a built AnNIXion icon theme rather than redrawn here, so
the board can only ever show what actually ships. Driver: identity-board.sh.
"""
import sys, os, re, html

ICONS = sys.argv[1]
OUT = sys.argv[2]

def mark(name, size=None, colour=None):
    """Inline one built mark, optionally recoloured."""
    with open(os.path.join(ICONS, f"annixion-{name}.svg")) as fh:
        s = fh.read()
    s = s.replace('width="24" height="24"', "")
    s = s.replace("<svg ", f'<svg class="mk" ', 1)
    if colour:
        s = re.sub(r'(stroke|fill)="#[0-9A-Fa-f]{6}"', lambda m: f'{m.group(1)}="{colour}"', s)
    if size:
        s = s.replace('<svg class="mk" ', f'<svg class="mk" style="width:{size}px;height:{size}px" ', 1)
    return s

RELEASE = "0.4.0 “Nebula”"

def wm(size_cls=""):
    return (f'<div class="wm {size_cls}"><span class="sc">AN</span>'
            f'<span class="nix">NIX</span><span class="sc">ION</span></div>')

AUDIENCE = [
 ("firefox-redteam","Red teamers","Assessing someone else's estate, under written authorisation, with a proxy in front of everything."),
 ("firefox-osint","Intelligence analysts","Working sources and archives at scale, where the collection must never be attributable to the collector."),
 ("firefox-puppet","Persona operators","Running identities that have to stay separate, stay consistent, and stay alive for months."),
]
PILLARS = [
 ("menu-root","Annexion","Take the territory.",
  "The name is <em>annexion</em> — to take full control of a territory, absorb it completely, make it "
  "yours. A machine is not a tool you rent for the engagement. It is ground you take and hold, and "
  "everything on it is declared, owned and accounted for — down to the wallpaper."),
 ("seclists","Refuse to wing it","Discipline over improvisation.",
  "Nothing set up by hand. Nothing that drifts. Nothing that exists only in a shell history. If a thing "
  "matters enough to configure, it matters enough to declare — and once declared it survives the "
  "reinstall, the rollback and the handover."),
 ("menu-tools","Opinionated","Built for people who already know why.",
  "Not a first distribution, and not pretending to be. It makes the choices so you do not spend your "
  "morning making them again, and assumes you can tell when a default is wrong for you. Every one can be "
  "overridden in a line — but you have to mean it."),
 ("menu-install","Reproducible","Or it did not happen.",
  "The whole machine is one declared artifact: packages, egress policy, browser isolation, desktop, "
  "shell. Deploy and redeploy are the same command, and a bad change is undone by booting the previous "
  "generation. You can say what the machine was doing when it mattered, and put it back."),
 ("menu-install-tunneling","Privacy first","Adapt or die.",
  "Confinement is not a preference the user can lose. Where a profile is meant to leave only through a "
  "tunnel, it leaves only through a tunnel — and if the tunnel is gone, it does not leave at all. If we "
  "cannot deliver the service to standard, we do not deliver a lesser one."),
]
LAWS = [
 ("Colour classifies. Silhouette identifies.",
  "A mark never says two things with one device. The colour tells you what running the tool does to a "
  "target; the drawing tells you which tool it is. Read the colour first and you already know whether you "
  "need authorisation before you have read the name."),
 ("The container is the enemy.",
  "Every plate, badge and rounded tile is canvas spent on itself instead of on the drawing. The set draws "
  "edge to edge and lets the shape make the silhouette. Where a container was tried, it took four fifths of "
  "the area and gave nothing back."),
 ("Privilege changes the ground you stand on.",
  "Elevation is never a badge bolted onto a corner. The root terminal changes its entire background; the "
  "root launcher changes its entire colour. A warning you can learn to ignore is not a warning."),
 ("When symbols cross, cut a gap.",
  "Two shapes of the same colour at the same weight do not read as two shapes where they meet — they "
  "read as one blob, and the smaller the icon the sooner it happens. A crossing symbol is drawn twice: "
  "once wide in the ground colour to cut a gap, then normally on top. A symbol that merely sits inside "
  "another shape is not crossing it, and knocking that one out only eats the shape."),
 ("A cap is ink, and ink needs room.",
  "A round cap reaches half a stroke past the point that draws it. A line ending on the edge of the "
  "canvas therefore loses its tip to the crop, and a sliced tip does not read as short — it reads as "
  "cut. The canvas is bigger than the grid for exactly this reason, and the build measures every mark "
  "rather than trusting the drawing."),
 ("The hand lives in the geometry.",
  "Looseness is not a filter applied at the end. It is in how the line was drawn: nothing truly straight, "
  "nothing truly parallel, nothing that quite closes. A perfect rectangle with a drip on it is a perfect "
  "rectangle with a drip on it."),
 ("One application, one drawing.",
  "However many colours a thing wears, it is drawn once. Four browser profiles and three terminals share "
  "two drawings between them. A variant that needs new artwork is a variant that will drift."),
 ("Draw what it does, never its logo.",
  "Borrowed logos break a set faster than bad drawing does — they arrive with someone else's grid, weight "
  "and intent. Most of these tools have no logo anyway. Draw the job."),
 ("Test at the size it will be seen.",
  "A mark that only works at poster size is not a mark. Everything here is judged at menu size, in its own "
  "colour, beside the things it will actually sit next to. If it cannot be told apart there, the shape is "
  "wrong — adding detail will not save it."),
 ("Red is a check on muscle memory.",
  "The signature colour is not decoration and is not spent freely. It means the thing behind it needs "
  "written authorisation, or root, or both. Used anywhere else it stops meaning anything, and the one "
  "place it must work is the place you are moving too fast to read."),
]
def menu_model():
    """The real kill-chain tree: every directory, and the tools filed under it.

    Read from the built catalog rather than scraped out of the Nix source, for
    the same reason the marks are taken from a built theme — the board must not
    be able to describe a menu that is not the one shipping.
    """
    import json
    import subprocess

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = subprocess.run(
        ["nix", "build", "--no-link", "--print-out-paths", ".#catalog-json"],
        cwd=root, capture_output=True, text=True,
    )
    if out.returncode != 0:
        raise SystemExit(f"identity-board: could not build .#catalog-json\n{out.stderr}")
    cat = json.loads(open(out.stdout.strip()).read())

    tools = cat["tools"]
    nodes = []
    for n in sorted(cat["nodes"], key=lambda n: (n["path"].count("/"), n["order"])):
        nodes.append({
            "path": n["path"],
            "depth": n["path"].count("/"),
            "label": n["label"],
            "icon": f"annixion-{n['mark']}",
            "tools": [(tools[t]["name"], tools[t]["icon"]) for t in sorted(n["tools"])],
        })
    # A tool earning a place under a second phase appears under both, the way
    # the menu shows it.
    by_path = {n["path"]: n for n in nodes}
    for key, t in tools.items():
        for extra in t.get("alsoIn", []):
            if extra in by_path:
                by_path[extra]["tools"].append((t["name"], t["icon"]))

    # The browser profiles ship their entries from home/firefox, not the catalog.
    ff = open(f"{root}/home/firefox/default.nix").read()
    extra = []
    for blk in re.findall(r"\[Desktop Entry\](.*?)\n    \'\'", ff, re.S):
        if "NoDisplay=true" in blk:
            continue
        cats = re.findall(r"(X-AnNIXion-[\w-]+)", blk)
        extra.append((re.search(r"Name=(.+)", blk).group(1).strip(),
                      re.search(r"Icon=(.+)", blk).group(1).strip(), cats))
    by_cat = {n.get("category") or "": n for n in cat["nodes"]}
    for name, icon, cats in extra:
        for c in cats:
            n = by_cat.get(c)
            if n and n["path"] in by_path:
                by_path[n["path"]]["tools"].append((name, icon))

    nodes.sort(key=lambda n: (n["path"].split("/")[0], n["path"]))
    order = {n["path"].split("/")[0]: i for i, n in enumerate(
        sorted([x for x in cat["nodes"] if "/" not in x["path"]], key=lambda x: x["order"]))}
    nodes.sort(key=lambda n: (order.get(n["path"].split("/")[0], 99), n["path"]))

    if not nodes:
        raise SystemExit("identity-board: parsed no menu directories")

    for n in nodes:
        for nm, ic in [(n["label"], n["icon"])] + list(n["tools"]):
            if not os.path.exists(os.path.join(ICONS, f"{ic}.svg")):
                raise SystemExit(f"identity-board: {nm} names {ic}, which the theme does not have")
    return nodes


def flat(name, size=None):
    """The mark as it would look without its knockout pass."""
    s = mark(name, size)
    groups = re.findall(r'<g\b.*?</g>', s, re.S)
    if len(groups) == 3:                       # body, knockout, symbol
        s = s.replace(groups[1], "", 1)
    return s


CHROME = [("#0E0F13","Deepest ground"),("#1A1D24","Raised surface"),("#2E323D","Segment, divider"),
          ("#FF0033","The signature accent"),("#DFE4EA","Primary text"),("#301212","Root ground")]
GRAFFITI = [("#000000","Wall ground — 62% of the wallpaper"),("#0F5AE6","Cobalt — the figure"),
            ("#F213A0","Magenta — spray tags, smiley, jester"),("#33E62B","Acid green — the throw-up tag")]
CLASSES = [
 ("Passive","#33E62B","10.7:1","Sends nothing to the target","theharvester",["theHarvester","Whois","SecLists"]),
 ("Probe","#FFD000","12.2:1","Touches the target and shows in their logs, no access attempted","nmap",["Nmap","dig","WhatWeb","Gobuster","ffuf","Gqrx"]),
 ("Offensive","#FF0033","4.5:1","Attempts access, execution or credential compromise","metasploit",["Metasploit","sqlmap","Hydra","Hashcat","Aircrack-ng"]),
 ("Forensic","#4A90FF","5.8:1","Reads evidence after the fact, never reaches the network","volatility",["Volatility 3","Autopsy","Wireshark"]),
 ("Reverse","#F213A0","4.6:1","Pulls a compiled artifact apart","ghidra",["Ghidra","Binwalk"]),
 ("Utility","#7A8494","4.8:1","Not a tool of the trade","kate",["Kate","Ark","KCalc","Dolphin","Konsole"]),
]
HAND = [
 ("1","No straight lines","Every straight run bows by about half a unit, and no two are parallel. A hand cannot draw a true horizontal, and the eye reads the difference before it can name it. This does the most work.","universal"),
 ("2","No closed circles","Radii vary by up to half a unit around the turn, and the shape never quite meets itself — one gap where the marker lifted. Always on a curve, never on a straight run, never more than one per mark.","universal"),
 ("3","The drip","One run of wet paint from the lowest edge that has room, 3–4.5 units, same stroke weight, rounded tip. The signature move.","earned"),
 ("4","The X","Struck across anything the tool defeats, overshooting the shape it crosses. If the tool does not break the thing, it does not get the X.","earned"),
]
GEO = [
 ('<rect x="4.5" y="7" width="15" height="10" rx="1.6"/>',
  '<path d="M4.2 7.4 19.9 6.8c.6 3.4.7 6.8.3 10.2l-15.6.5c-.6-3.4-.7-6.8-.3-10.1z"/><path d="M6.6 17.4v4.4"/>',
  "A window, and a window with a drip"),
 ('<circle cx="12" cy="12" r="8.4"/>',
  '<path d="M20.9 14.4c-1.2 3.9-4.8 6.7-8.9 6.7-5.2 0-9.4-4.3-9.3-9.4C2.8 6.7 6.9 2.7 12 2.7c4.7 0 8.7 3.5 9.3 8.1"/>',
  "A circle, and a circle that never closes"),
 ('<path d="M4 8h16M4 12h16M4 16h11"/>',
  '<path d="M3.4 7.8q8.4-.7 17 .2M3.6 12.1q8.2-.6 16.6.1M3.5 16.3q5.6-.5 11.2 0"/>',
  "Three rules, and three rules no two of which are parallel"),
 ('<rect x="5" y="6" width="14" height="10" rx="1.6"/>',
  '<path d="M4.7 6.4 19.4 5.9c.5 3.3.6 6.6.2 9.9l-14.6.5c-.5-3.3-.6-6.6-.1-9.8z"/><path d="M7 8.2 17.2 14.1M17.4 8 7.2 14.3"/>',
  "A box, and a box that has been crossed out"),
]
MOTIFS = [
 ("X-eyed smiley",'<path d="M21.9 15.3c-1.4 4.3-5.5 7.4-10 7.3C6.3 22.5 1.6 17.8 1.8 12.1 2 6.5 6.5 2.1 12 2.1c5.2 0 9.6 3.9 10.2 9"/><path d="M5.9 7.2 10.6 12.1M10.9 6.9 5.7 12.6"/><path d="M13.2 6.9 18.1 11.8M18.4 7.2 13 12.7"/><path d="M5.6 14.5c1.6 3.4 3.8 5.1 6.5 5.1s4.9-1.8 6.4-5.3"/><path d="M8.8 17.2v3.3M12.1 18.7v3.5M15.4 17v3.2"/><path d="M3.6 18.6v4.9"/>'),
 ("Skull",'<path d="M12 1.4C6.8 1.3 2.7 5.3 2.8 10.2c0 2.8 1.4 4.8 3 6v3.6c0 1.3 1 2.3 2.3 2.3q3.9.2 7.8 0c1.3 0 2.3-1 2.3-2.3v-3.6c1.6-1.3 3-3.3 3-6.1C21.3 5.2 17.2 1.3 12 1.4z"/><circle cx="8.4" cy="10.3" r="2.1" fill="currentColor" stroke="none"/><circle cx="15.6" cy="10.1" r="2.1" fill="currentColor" stroke="none"/><path d="M10 22.1q.2-1.7 0-3.4M14 22.1q.2-1.7 0-3.4"/>'),
 ("404",'<path d="M1.2 15.5q3.2-.3 6.4 0M5.9 2.3 1.2 12.6q4.1.2 8.2 0M5.9 12.6q.3 3.5.1 7"/><path d="M15.8 11c0 2.2-1.7 3.9-3.9 3.9s-3.7-1.8-3.7-4c0-2.1 1.7-3.7 3.8-3.7s3.8 1.7 3.8 3.8"/><path d="M14.4 15.5q3.2-.3 6.4 0M19.1 2.3l-4.7 10.3q4.1.2 8.2 0M19.1 12.6q.3 3.5.1 7"/><path d="M12 15.1v3.8"/>'),
 ("Throw-up tag",'<path d="M1.2 19.4C3.5 11.6 6.2 6.8 8 6.8s1.4 9.6 3.7 9.6 2.7-10.2 5-10.2 2.7 8.3 6.4 8.3"/><path d="M4.8 22.4v-2.6M11.2 22.6v-3.6M18 22.3v-2.8"/>'),
 ("The X",'<path d="M2.4 2.2 21.8 21.6M21.6 2.4 2.2 21.8"/><path d="M4.6 21.9v2"/>'),
]
SURFACES = [
 ("Boot loader","The first thing the mark says, before anything else has loaded"),
 ("Login","The greeter, rebranded to the palette — signature red on the void ground"),
 ("Lock screen","The wall, uninterrupted"),
 ("Desktop","The wall, on pure black, aspect preserved"),
 ("Panel","32px, the launcher mark at the left edge"),
 ("Application menu","Forty-six entries across thirty-three categories, every one carrying its own mark"),
 ("Terminal","85% opacity with blur, so the wall reads through the work"),
 ("Prompt","The chrome palette, red accent diamonds, and the session colour on the left"),
 ("System banner","The mark at width thirty, keys and title in red"),
 ("Browser profiles","One mark in four class colours"),
 ("Repository","Glitch banner, wordmark lockup, badge row"),
 ("Install image","The banner on black, and the same splash the installed system uses"),
]
DO = ["State what happened and what to do about it.",
      "Name things the way an operator does — <em>targets</em>, <em>hosts</em>, <em>captures</em>.",
      "Say the consequence before the mechanism.",
      "Keep the register dry: the wall is loud so the words do not have to be."]
DONT = ["Reach for hacker-movie voice — no “pwned”, no leetspeak, no skull emoji in output.",
        "Apologise in errors or hedge with “something went wrong”.",
        "Use the graffiti vocabulary in UI copy; it belongs on the wall, not in a dialog.",
        "Explain what a tool is in a menu label — the menu is for finding, not teaching."]

PAGENO = [0]

def page(n, title, kicker, body, cls=""):
    PAGENO[0] += 1
    head = ""
    if n:
        head = (f'<header class="ph"><div class="pn">{n}</div>'
                f'<div class="pt"><h2>{title}</h2><p class="kick">{kicker}</p></div></header>')
    return (f'<section class="page {cls}">{head}<div class="pb">{body}</div>'
            f'<footer class="pf"><span>{{WM}}</span><span>Design board</span>'
            f'<span>{RELEASE}</span>'
            f'<span class="pg">{PAGENO[0]:02d} / {{TOTAL}}</span></footer></section>')

P = []

# ══ WELCOME ══════════════════════════════════════════════════════════════
aud = "".join(f'<div class="aud">{mark(m,30)}<div><b>{t}</b><span>{d}</span></div></div>'
              for m,t,d in AUDIENCE)
P.append(page(None,"","",f'''
<div class="welcome">
  <div class="w-l">
    <div class="eyebrow"><span class="rr"></span><span class="lab">Design board · {RELEASE}</span></div>
    <h1>Take the ground.<br>Then make it <span class="sig">yours</span>.</h1>
    <p class="lede">An opinionated, reproducible offensive security distribution for people who do this
    for a living. Not a toolkit you assemble over a weekend and patch by hand for a year — a territory you
    annex. Every tool, every browser profile, every egress rule and every pixel of the desktop is declared
    in code and deployed in one command.</p>
    <p class="lede2">The discipline of an engineer, the temperament of a privateer: rigorous underneath,
    unapologetic on the surface. The name comes from <em>annexion</em> — to take full control of a
    territory, absorb it completely, make it yours.</p>
    <div class="auds">{aud}</div>
  </div>
  <div class="w-r">
    <div class="w-mark">{mark("logo",108)}</div>
    <div class="wordmark">{wm()}
      <div class="wmd"><span class="ln"></span><span class="bx">OFFENSIVE SECURITY DISTRIBUTION</span><span class="ln"></span></div>
    </div>
    <p class="tagline">“The environment for operators who refuse to wing it”</p>
  </div>
</div>
<div class="indep">
  <span class="lab">Independent of Nix</span>
  <p>AnNIXion is built on NixOS and proud of that lineage — the name says so out loud. It is <b>not made
  by, affiliated with, endorsed by, sponsored by or connected to</b> the NixOS Foundation, the Nix project,
  or anyone who works on them. Nix and NixOS are the work of their own community and owe this project
  nothing. AnNIXion is an independent downstream distribution and speaks only for itself; every opinion
  here is ours, and none of it should be read as theirs.</p>
</div>''',"welcome-page"))

# ══ 01 MISSION ═══════════════════════════════════════════════════════════
P.append(page("01","Mission","Why this exists, and what it refuses to do.",f'''
<div class="mission">
  <p class="m-big">AnNIXion exists to give the operator a machine that is <span class="sig">entirely
  theirs</span> and <span class="sig">entirely known</span>.</p>
  <div class="two">
   <div class="col">
    <p class="m-body">The trade runs on trust in your own environment. You cannot assess somebody else's
    estate from a box you are not sure of — one whose proxy might be leaking, whose profile might be
    bleeding cookies into the next engagement, whose last three fixes exist only in a shell history nobody
    kept. Every hour spent wondering about your own machine is an hour not spent on the target, and every
    unrecorded fix is a finding you will not be able to defend.</p>
    <p class="m-body">So the whole machine is declared, not just the tools: the egress policy, the browser
    isolation, the menu, the prompt, the wall behind it. One artifact, one command, one known state.</p>
   </div>
   <div class="col">
    <p class="m-body">What that buys is not convenience. It is the ability to say exactly what your machine
    was doing at the moment it mattered, and to put it back byte for byte — on a new disk, on somebody
    else's hardware, a year later.</p>
    <p class="m-body">And it buys the right to be strict. A system that can be rebuilt in one command can
    afford to refuse. It never has to degrade quietly to keep working, because nothing about it is
    precious and nothing about it is improvised.</p>
   </div>
  </div>
</div>'''))

# ══ 02 PILLARS ═══════════════════════════════════════════════════════════
pil = "".join(f'<div class="pil">{mark(m,36,"#FF0033")}<div class="pil-b"><b>{t}</b>'
              f'<span class="pil-s">{sub}</span><p>{d}</p></div></div>' for m,t,sub,d in PILLARS)
P.append(page("02","The five pillars","Everything below the fold in this document is downstream of these.",
  f'<div class="pillars">{pil}</div>'))

# ══ 03 ADAPT OR DIE ══════════════════════════════════════════════════════
P.append(page("03","Adapt or die","The one place the project is genuinely inflexible, and the reason it can afford to be.",f'''
<div class="creed">
  <p class="cr-big">If we cannot deliver the service to standard,<br>we do not deliver a <span class="sig">lesser one</span>.</p>
</div>
<div class="two">
 <div class="col">
  <p class="m-body">Most software, told it cannot do the safe thing, does the unsafe thing and mentions it.
  The tunnel drops and the browser keeps loading. The proxy is not listening and the request goes direct.
  There is a dialog, and the dialog has a “continue anyway”, and at three in the morning everybody presses
  it.</p>
  <p class="m-body">Here the confinement is not a setting inside the application that the application can
  lose. A profile that is meant to leave only through the tunnel is held to that below the application
  entirely — so it is not a promise the browser makes, and not one it can break. Tunnel down, nothing
  leaves. No dialog. No fallback. No continue anyway.</p>
 </div>
 <div class="col">
  <div class="creed-x">{mark("menu-root",90)}</div>
  <p class="m-body">That is what <b>privacy first</b> costs, and it is the whole reason the standard is
  worth having. A killswitch with an override is a preference. A killswitch without one is a property of
  the machine.</p>
  <p class="m-body"><b>Adapt or die</b> points at us before it points at anyone else. When the standard and
  the convenience collide, the convenience goes. If a feature cannot be built to the standard, it does not
  ship until it can.</p>
 </div>
</div>'''))

# ══ 04 NAME AND MARK ═════════════════════════════════════════════════════
P.append(page("04","Name and mark","One word, capital A, capital NIX. Never <em>Annixion</em>, never <em>ANNIXION</em>.",f'''
<div class="two">
  <div class="col">
    <div class="lockup">{wm("big")}
      <div class="wmd"><span class="ln"></span><span class="bx">OFFENSIVE SECURITY DISTRIBUTION</span><span class="ln"></span></div>
    </div>
    <div class="note"><b>The lockup sets AN and ION as small capitals</b> at roughly six tenths the height
    of NIX, which stays full size in the signature red. No lowercase anywhere: the three letters of the
    lineage carry the colour, the rest carries the word, and the eye reads NIX without anyone having to
    point at it. Letterspacing is wide at 0.30em and the weight is light — it is a wordmark, not a
    headline. In running text the name is simply written AnNIXion.</div>
  </div>
  <div class="col">
    <div class="panel">
      <span class="lab">The X — the recurring device</span>
      <div class="xrow">
        <figure>{mark("logo",54)}<figcaption>in the mark</figcaption></figure>
        <figure><svg class="mk loose" style="width:54px;height:54px" viewBox="-1.3 -1.3 26.6 26.6" fill="none" stroke="#FF0033" stroke-width="1.88" stroke-linecap="round" stroke-linejoin="round">{MOTIFS[0][1]}</svg><figcaption>as the eyes on the wall</figcaption></figure>
        <figure>{mark("menu-root",54)}<figcaption>over a finished target</figcaption></figure>
      </div>
      <p class="sm">Three places that were never talking to each other. The X is the crossed-out letter in
      the wordmark, the eyes on the graffiti smiley, and the shape an operator draws over a target that is
      done. Making it the system cost nothing — it was already there.</p>
    </div>
    <div class="panel warn">
      <span class="lab">Two forms, two jobs</span>
      <p class="sm">The <b>datamosh logo</b> is a hero image: light artwork on transparency, drawn large on
      the boot splash, the banner and the repository header. It is not an icon — at launcher size the
      glitch collapses into a smear. The <b>launcher mark</b> is the same snowflake reduced to its six
      arms, four of which are the X, drawn to the mark rules and legible down to sixteen pixels.</p>
    </div>
  </div>
</div>'''))

# ══ 05 PALETTE ═══════════════════════════════════════════════════════════
sw = "".join(f'<div class="sw"><div class="chip" style="background:{h}"></div>'
             f'<div class="meta"><span class="hex">{h}</span><span class="use">{r}</span></div></div>'
             for h,r in CHROME)
gr = "".join(f'<div class="sw"><div class="chip" style="background:{h}"></div>'
             f'<div class="meta"><span class="hex">{h}</span><span class="use">{r}</span></div></div>'
             for h,r in GRAFFITI)
P.append(page("05","Palette","A sober red-on-Nord chrome runs the interface; a neon graffiti wall runs behind it.",f'''
<span class="lab">Chrome — the interface</span>
<div class="sws">{sw}</div>
<span class="lab" style="margin-top:8mm;display:block">Graffiti — sampled off the wall itself</span>
<div class="sws">{gr}</div>
<div class="note" style="margin-top:7mm">The mark colours are lifted off the wallpaper, so the menu speaks
the wall's language the moment it opens. Motifs live on pure black and nowhere else. They drip downward,
never upward, and carry one spray colour each — never two in the same mark.</div>'''))

# ══ 06 SEMANTIC CLASSES ══════════════════════════════════════════════════
cards = "".join(
 f'<div class="cls"><div class="cls-top">{mark(ic,34)}<span class="cls-name">{n}</span>'
 f'<span class="cls-hex" style="color:{c}">{c}</span></div>'
 f'<div class="cls-body"><p class="cls-rule">{r}</p><p class="cls-eg">{" · ".join(eg)}</p>'
 f'<p class="cls-cr">contrast <b>{cr}</b> against the menu ground</p></div></div>'
 for n,c,cr,r,ic,eg in CLASSES)
P.append(page("06","Semantic classes","Colour encodes what running the tool does to the target — not which phase of the job it sits in. The menu already tells you the phase.",f'''
<div class="clsgrid">{cards}</div>
<div class="note" style="margin-top:6mm"><b>Red means the tool needs written authorisation behind it.</b>
That is the one class where the mark is a check on muscle memory rather than decoration. The middle of the
kill chain lands on red end to end, giving the menu an unbroken red band down its centre — the stretch
where you are inside somebody else's estate.</div>'''))

# ══ 07 SESSION COLOURS ═══════════════════════════════════════════════════
terms = "".join(f'<figure class="tf">{mark(m,52)}<figcaption><b>{lbl}</b><span>{d}</span></figcaption></figure>'
  for m,lbl,d in [("konsole","Operator","#7A8494 · your own shell"),
                  ("konsole-root","Root","#FF0033 · elevated, on the red ground"),
                  ("konsole-nix","Build shell","#7EBAE4 · the throwaway environment")])
P.append(page("07","Session colours","The six classes say what a tool does to a target. A terminal does nothing to a target, so it is coloured by the session you are standing in instead.",f'''
<div class="two">
 <div class="col">
  <div class="terms">{terms}</div>
  <div class="note">These are not new values invented for the icons. The prompt already flips its session
  segment to accent red as root and to the cool blue inside a throwaway build shell — the launcher simply
  says the same thing one surface earlier, before you have typed anything.</div>
 </div>
 <div class="col">
  <div class="note"><b>Elevated repeats the signature red</b> rather than introducing a seventh value. Root
  is the one session that is dangerous to miss, and it should read as the same red the root terminal
  background and the prompt already use. These two colours belong to the terminal family alone — no tool
  mark may take them.</div>
  <div class="note"><b>This is the elevation law reaching one surface earlier.</b> The root terminal
  already changes the ground you are standing on once the window is open. Colouring the launcher says it
  while the pointer is still over the menu, which is the moment it is useful.</div>
  <div class="pgrid">
   <div class="pg-c" style="background:#7A8494"></div>
   <div class="pg-c" style="background:#FF0033"></div>
   <div class="pg-c" style="background:#7EBAE4"></div>
  </div>
 </div>
</div>'''))

# ══ 08 TYPOGRAPHY ════════════════════════════════════════════════════════
P.append(page("08","Typography","One face does everything. Things you type should look typed.",f'''
<div class="two">
 <div class="col">
  <div class="spec-blk">
   <div class="sp-lab">Display · -0.03em</div>
   <div class="sp sp-d">Take the ground</div>
   <div class="sp-lab">Section · -0.02em</div>
   <div class="sp sp-s">The mark system</div>
   <div class="sp-lab">Label · uppercase · 0.12em</div>
   <div class="sp sp-l">SEMANTIC CLASSES</div>
   <div class="sp-lab">Body · 1.6 leading</div>
   <div class="sp sp-b">Say the consequence before the mechanism.</div>
   <div class="sp-lab">Wordmark · light · 0.30em — the one place tracking goes wide</div>
   <div class="sp">{wm("spec")}</div>
  </div>
 </div>
 <div class="col">
  <div class="charset">
   <div class="cs-row">ABCDEFGHIJKLM</div>
   <div class="cs-row">NOPQRSTUVWXYZ</div>
   <div class="cs-row">abcdefghijklm</div>
   <div class="cs-row">nopqrstuvwxyz</div>
   <div class="cs-row">0123456789</div>
   <div class="cs-row">! ? @ # $ % &amp; * / \\ &lt; &gt; {{ }} [ ]</div>
  </div>
  <div class="note"><b>JetBrains Mono</b> is the display and interface face, with Fira Code behind it. A
  monospace was not chosen for flavour: category strings, hostnames and paths are the substance of this
  interface, and they should look like the things you type rather than like prose about them.</div>
  <div class="note">The wordmark is the single exception to everything above — light weight, wide tracking,
  small capitals. It is allowed to behave differently because it appears once per surface and never inside
  a sentence. This board is set in the same face the system is.</div>
 </div>
</div>'''))

# ══ 09 THE MARK SYSTEM ═══════════════════════════════════════════════════
P.append(page("09","The mark system","Every application and every menu directory gets a single-colour line drawing filling its whole canvas. No container, no plate.",f'''
<div class="two">
 <div class="col">
  <div class="gridart"><div class="ga-frame">{mark("nmap",122)}</div>
   <div class="ga-cap">One mark at poster size on its own grid. A round cap reaches half a stroke past the
   line that draws it, so the canvas is the grid plus a margin for the ink the stroke throws beyond it —
   otherwise a drip ending on the bottom edge is sliced flat and reads as a cut, not a tip.</div></div>
  <div class="knock">
   <span class="lab">Where one symbol crosses another</span>
   <div class="kn-row">
    <figure>{flat("aircrack",44)}{flat("aircrack",22)}<figcaption>flat — the bolt<br>fuses with the arcs</figcaption></figure>
    <figure>{mark("aircrack",44)}{mark("aircrack",22)}<figcaption>knocked out — a gap<br>in the ground colour</figcaption></figure>
    <figure>{flat("sqlmap",44)}{flat("sqlmap",22)}<figcaption>flat</figcaption></figure>
    <figure>{mark("sqlmap",44)}{mark("sqlmap",22)}<figcaption>knocked out</figcaption></figure>
   </div>
  </div>
 </div>
 <div class="col">
  <table class="grid-t">
   <thead><tr><th>Rule</th><th>Value</th><th>Why</th></tr></thead>
   <tbody>
    <tr><td>Grid</td><td>24 units, edge to edge</td><td>The drawing may use all of it</td></tr>
    <tr><td>Canvas</td><td>The grid, padded 1.3 all round</td><td>Where the round cap goes, so nothing is sliced</td></tr>
    <tr><td>Stroke</td><td>2.33, round cap and join</td><td>Lands just under 2px at menu size</td></tr>
    <tr><td>Colour</td><td>One class colour, whole mark</td><td>Colour classifies, silhouette identifies</td></tr>
    <tr><td>Fills</td><td>Dots under 2.5 units only</td><td>Anything larger becomes a blob when small</td></tr>
    <tr><td>Detail</td><td>Five strokes or fewer</td><td>Spend the sixth on silhouette, never texture</td></tr>
    <tr><td>Silhouette</td><td>Differs from its classmates</td><td>Inside a class the colour is identical</td></tr>
    <tr><td>Subject</td><td>What it does, never its logo</td><td>Borrowed logos break the set</td></tr>
   </tbody></table>
  <div class="note"><b>A mark is finished when you can pick it out of its own class colour at menu size,
  beside its classmates.</b> Not alone, and not at poster size. If you cannot, change the shape — adding
  detail will make it worse.</div>
 </div>
</div>'''))

# ══ 10 THE HAND ══════════════════════════════════════════════════════════
demos = "".join(f'<figure class="dm"><div class="dm-art"><svg class="mk gy" viewBox="0 0 24 24">{g}</svg>'
  f'<span class="arw">&rarr;</span><svg class="mk sg" viewBox="0 0 24 24">{h}</svg></div>'
  f'<figcaption>{cap}</figcaption></figure>' for g,h,cap in GEO)
rules = "".join(f'<div class="hr"><span class="hn">{n}</span><div><b>{t}</b>'
  f'<span class="tagx {k}">{k}</span><p>{d}</p></div></div>' for n,t,d,k in HAND)
P.append(page("10","The hand","Adding a drip to a machine-perfect rectangle does not make it graffiti — it makes it a rectangle with a drip. The hand has to be in the geometry itself.",f'''
<div class="demos">{demos}</div>
<div class="hrules">{rules}</div>
<div class="note">Devices one and two are universal and apply to every mark in the set. Three and four are
semantic and have to be earned. Corners and crossings overshoot their joins by up to a unit throughout —
the marker keeps moving after the shape has ended.</div>'''))

# ══ 11 FAMILIES ══════════════════════════════════════════════════════════
ffam = "".join(f'<figure class="ff">{mark(m,58)}<figcaption><b>{lbl}</b><span>{c}</span></figcaption></figure>'
  for m,lbl,c in [("firefox-untrusted","Unsafe","utility · #7A8494"),
                  ("firefox-redteam","Red Team","offensive · #FF0033"),
                  ("firefox-osint","OSINT","probe · #FFD000"),
                  ("firefox-puppet","Puppet Master","passive · #33E62B")])
res = "".join(f'<figure class="ff dim">{mark("firefox-untrusted",42,c)}<figcaption><span>{lbl}</span></figcaption></figure>'
  for c,lbl in [("#4A90FF","forensic — held"),("#F213A0","reverse — held")])
P.append(page("11","Families","Where one application appears several times in different colours, every copy shares a single drawing and the colour carries the whole difference.",f'''
<span class="lab">The browser profiles — one drawing, four classes</span>
<div class="fams">{ffam}</div>
<div class="two" style="margin-top:6mm">
 <div class="col">
  <div class="note"><b>Drawn once, referenced by name.</b> A redraw cannot drift between the variants,
  reclassifying a profile is a change of one word, and a fifth profile costs no artwork at all — the two
  colours below are already waiting for one.</div>
  <div class="fams">{res}</div>
 </div>
 <div class="col">
  <div class="note reject"><b>A globe was the obvious drawing, and it lost.</b> At menu size it is
  indistinguishable from the Internet directory's own globe, which sits directly above it in the same list
  — and both are grey. The window and tab is one degree less obvious and unmistakably not that.</div>
  <div class="clash">
   <div class="cl-row">{mark("menu-internet",22)}<span>Internet — directory</span></div>
   <div class="cl-row">{mark("firefox-untrusted",22)}<span>Unsafe Browser</span></div>
   <div class="cl-row">{mark("firefox-redteam",22)}<span>Red Team</span></div>
   <div class="cl-row">{mark("firefox-osint",22)}<span>OSINT</span></div>
   <div class="cl-row">{mark("firefox-puppet",22)}<span>Puppet Master</span></div>
  </div>
  <div class="note">OSINT is amber rather than green deliberately. The profile drives a real browser at a
  real target, fetching their pages and landing in their logs. That is a probe, not passive collection.</div>
 </div>
</div>'''))

# ══ 12-14 THE SET, BY CATEGORY ═══════════════════════════════════════════
NODES = menu_model()


def bare(icon):
    return mark(icon[len("annixion-"):], None)


def tool_cell(name, icon):
    return (f'<figure class="tcell"><span class="ic30">{bare(icon)}</span>'
            f'<figcaption>{html.escape(name)}</figcaption></figure>')


def block(i):
    """One top-level phase: its own mark, then each directory beneath it."""
    top = NODES[i]
    rows = ""
    if top["tools"]:
        rows += f'<div class="tools">{"".join(tool_cell(*t) for t in top["tools"])}</div>'
    j = i + 1
    while j < len(NODES) and NODES[j]["depth"] > top["depth"]:
        sb = NODES[j]
        rows += (f'<div class="subrow"><div class="sub-h"><span class="ic22">{bare(sb["icon"])}</span>'
                 f'{html.escape(sb["label"])}</div>'
                 f'<div class="tools">{"".join(tool_cell(*t) for t in sb["tools"])}</div></div>')
        j += 1
    return (f'<div class="cat"><div class="cat-h"><span class="ic28">{bare(top["icon"])}</span>'
            f'<b>{html.escape(top["label"])}</b></div>{rows}</div>')


TOPS = [i for i, n in enumerate(NODES) if n["depth"] == 0]
if len(TOPS) < 10:
    raise SystemExit(f"identity-board: found only {len(TOPS)} top-level categories")
groups = [TOPS[0:4], TOPS[4:10], TOPS[10:]]
titles = ["The set — reconnaissance to exploitation",
          "The set — installation to the wire",
          "The set — off the kill chain"]
kickers = ["Every mark in the place it is actually used. A directory takes the colour of what it holds; "
           "a tool takes the colour of what running it does to the target.",
           "The middle of the chain runs red end to end. That is deliberate: it is the stretch where you "
           "are inside somebody else's estate, and it should not look like the rest. Once the work is "
           "over the set cools to forensic blue and reverse magenta — neither of which touches the network.",
           "The parts of the menu that are not the kill chain: the browsers, the editors, the terminals, "
           "and the two marks that belong to no category at all."]

for k, (grp, title, kick) in enumerate(zip(groups, titles, kickers)):
    body = f'<div class="cats">{"".join(block(i) for i in grp)}</div>'
    if k == 2:
        body += ('<div class="cat outside"><div class="cat-h">'
                 f'<span class="ic28">{mark("logo")}</span><b>Outside the tree</b></div>'
                 '<div class="tools">'
                 f'{tool_cell("The launcher mark", "annixion-logo")}'
                 f'{tool_cell("The menu root", "annixion-menu-root")}'
                 '</div></div>')
    P.append(page(f"{12 + k}", title, kick, body))

# ══ 14 MOTIFS ════════════════════════════════════════════════════════════
mot = "".join(f'<figure class="mo"><svg class="mk loose" viewBox="-1.3 -1.3 26.6 26.6">{d}</svg>'
  f'<figcaption>{n}</figcaption></figure>' for n,d in MOTIFS)
P.append(page("15","Motif vocabulary","The wall carries a fixed cast. Reuse it rather than inventing new ones.",f'''
<div class="motifs">{mot}</div>
<div class="two" style="margin-top:7mm">
 <div class="col"><div class="note"><b>Where they are allowed.</b> The wallpaper, the lock screen, the boot
 splash, the system banner, the repository header and release art. Motifs live on pure black and nowhere
 else. They drip downward, never upward, and take one spray colour each.</div></div>
 <div class="col"><div class="note reject"><b>Not the panel, and not the menu</b> — with one exception. The
 X-eyed smiley is the post-exploitation mark, because there it states something true rather than
 decorating. Motifs are drawn looser than tool marks: lighter stroke, hand-weighted curves, and allowed to
 overshoot much further.</div></div>
</div>'''))

# ══ 15 SURFACES ══════════════════════════════════════════════════════════
rows = "".join(f'<tr><td>{s}</td><td>{d}</td></tr>' for s,d in SURFACES)
P.append(page("16","Surfaces","A rule for every surface the system puts in front of you, from power-on to the desktop.",f'''
<table class="grid-t wide"><thead><tr><th>Surface</th><th>How the identity lands</th></tr></thead><tbody>{rows}</tbody></table>
<div class="two" style="margin-top:6mm">
 <div class="col"><div class="note"><b>The splash can always be interrupted.</b> A boot screen you cannot
 escape is a machine with no way back to a working state. Three seconds, every time, however good the
 animation is.</div></div>
 <div class="col"><div class="note"><b>Elevation changes the ground.</b> The root terminal swaps its entire
 background rather than adding a warning icon in a corner. Privilege is a floor you are standing on, never
 a decoration bolted onto the furniture.</div></div>
</div>'''))

# ══ 16 DESIGN LAWS ═══════════════════════════════════════════════════════
laws = "".join(f'<div class="law"><span class="ln-n">{i:02d}</span><div><b>{t}</b><p>{d}</p></div></div>'
                for i,(t,d) in enumerate(LAWS, 1))
P.append(page("17","Design laws","Ten rules the whole system runs on. They are not style preferences — each one was paid for, and breaking one shows up on screen within a day.",
  f'<div class="laws">{laws}</div>'))

# ══ 17 VOICE ═════════════════════════════════════════════════════════════
P.append(page("18","Voice","Two registers, on purpose. The pitch is loud. The interface is quiet.",f'''
<div class="note" style="margin-bottom:6mm"><b>The first three pages of this document swagger, and nothing
the system says at runtime is allowed to.</b> That split is the point. Attitude belongs where somebody has
chosen to read — a cover, a banner, a wall. It does not belong in an error at three in the morning, where
the only thing anyone wants is what happened and what to do about it. A distribution that talks like its
own marketing is a distribution you stop reading.</div>
<div class="two">
 <div class="col"><div class="panel yes"><span class="lab">Do</span><ul>{"".join(f"<li>{x}</li>" for x in DO)}</ul></div></div>
 <div class="col"><div class="panel no"><span class="lab">Don't</span><ul>{"".join(f"<li>{x}</li>" for x in DONT)}</ul></div></div>
</div>
<div class="term">
 <div class="term-bar">the register, in practice</div>
 <div class="term-body"><span class="tg">$&gt;</span> osint-browser<br>
 <span class="tm">the tunnel is down; the browser did not start</span><br>
 <span class="tm">bring it up, then run this again</span><br><br>
 <span class="tg">$&gt;</span> <span class="tc">// not: “Oops! Something went wrong :( Please try again.”</span><br>
 <span class="tg">$&gt;</span> <span class="tc">// and not: “tunnel pwned — u r leaking bro”</span></div>
</div>
<p class="closing">The wall is loud so the words do not have to be.</p>'''))

CSS = """
@page { size: A4 landscape; margin: 0; }
:root{
 --void:#0E0F13; --surface:#14171D; --raised:#1A1D24; --edge:#2A2F3A;
 --fg:#DFE4EA; --muted:#838D9E; --sig:#FF0033; --sig-dim:#7A0C22; --cool:#7EBAE4;
 --mono:"JetBrainsMono Nerd Font","JetBrains Mono","FiraCode Nerd Font",monospace;
}
*{box-sizing:border-box; -webkit-print-color-adjust:exact; print-color-adjust:exact;}
html,body{margin:0;padding:0;background:var(--void);color:var(--fg);
 font-family:var(--mono); font-size:9.4pt; line-height:1.58;}
/* Justified throughout. Monospace justifies badly without hyphenation,
   so every prose class opts into both together. */
.kick,.lede,.lede2,.sm,.note,.m-body,.indep p,.pil-b p,.law p,.cls-rule,
.ga-cap,.grid-t.wide td:last-child,.aud span,.panel li{
 text-align:justify;text-justify:inter-word;hyphens:auto;-webkit-hyphens:auto;}
.page{width:297mm;height:210mm;padding:14mm 15mm 10mm;background:var(--void);
 position:relative;overflow:hidden;display:flex;flex-direction:column;
 page-break-after:always;break-after:page;}
.page:last-child{page-break-after:auto;break-after:auto;}
.pb{flex:1;min-height:0;}
h1,h2{margin:0;font-weight:700;letter-spacing:-.03em;line-height:1.06;}
h1{font-size:27pt;} h2{font-size:19pt;letter-spacing:-.02em;}
p{margin:0;} em{font-style:italic;color:var(--fg);}
code{font-family:var(--mono);font-size:.9em;background:rgba(255,255,255,.05);padding:.5px 3px;}
.sig{color:var(--sig);}
.lab{font-size:7.4pt;text-transform:uppercase;letter-spacing:.13em;color:var(--muted);}
.sm{font-size:8.4pt;color:var(--muted);line-height:1.55;}

.ph{display:grid;grid-template-columns:auto 1fr;gap:0 6mm;align-items:start;
 padding-bottom:5mm;margin-bottom:6mm;border-bottom:1px solid var(--edge);}
.pn{font-size:30pt;font-weight:700;color:var(--sig);line-height:.85;letter-spacing:-.05em;}
.pt h2{margin-bottom:2.2mm;}
.kick{font-size:9pt;color:var(--muted);max-width:180mm;}
.pf{display:flex;gap:6mm;align-items:center;padding-top:3.5mm;margin-top:5mm;
 border-top:1px solid var(--edge);font-size:7pt;color:#5A6474;letter-spacing:.06em;}
.pf .pg{margin-left:auto;}

/* wordmark — small capitals, no lowercase */
.wm{font-weight:300;letter-spacing:.30em;color:#F2F4F7;text-indent:.30em;
 line-height:1;white-space:nowrap;font-size:20pt;}
.wm .sc{font-size:.62em;}
.wm .nix{color:var(--sig);font-weight:400;}
.wm.big{font-size:30pt;} .wm.spec{font-size:17pt;}
.wmd{display:flex;align-items:center;gap:4mm;width:100%;}
.wmd .ln{flex:1;min-width:5mm;height:.3mm;background:var(--sig);}
.wmd .bx{border:.3mm solid var(--sig);padding:1.4mm 3.5mm;font-size:6.6pt;letter-spacing:.19em;
 white-space:nowrap;}
.wordmark .bx{font-size:5.8pt;letter-spacing:.15em;}
.wordmark{background:#000;border:1px solid var(--edge);padding:5.5mm 5mm;
 display:flex;flex-direction:column;align-items:center;gap:4.5mm;}
.lockup{background:#000;border:1px solid var(--edge);padding:14mm 8mm;
 display:flex;flex-direction:column;align-items:center;gap:7mm;}

/* welcome */
.welcome-page{padding:12mm 15mm 10mm;}
.welcome{display:grid;grid-template-columns:1fr 80mm;gap:10mm;align-items:start;}
.w-l{display:flex;flex-direction:column;}
.w-r{display:flex;flex-direction:column;gap:5mm;}
.w-mark{background:#000;border:1px solid var(--edge);padding:7mm;display:grid;place-items:center;}
.eyebrow{display:flex;gap:5mm;align-items:center;margin-bottom:6mm;}
.rr{width:16mm;height:1.1mm;background:var(--sig);}
.lede{font-size:9.6pt;color:#B6BECB;max-width:150mm;margin-top:5mm;}
.lede2{font-size:8.8pt;color:var(--muted);max-width:150mm;margin-top:3.5mm;}
.tagline{font-size:8.6pt;color:var(--muted);font-style:italic;text-align:center;}
.auds{display:flex;flex-direction:column;gap:2mm;margin-top:5mm;}
.aud{display:flex;gap:3.5mm;align-items:flex-start;background:var(--surface);
 border:1px solid var(--edge);padding:2.4mm 3.5mm;}
.aud .mk{width:26px;height:26px;flex:none;}
.aud b{font-size:8.4pt;display:block;}
.aud span{font-size:7.4pt;color:var(--muted);line-height:1.4;}
.indep{margin-top:3.5mm;border:1px solid var(--sig-dim);border-left:1.4mm solid var(--sig);
 background:rgba(255,0,51,.05);padding:3.5mm 4.5mm;display:flex;flex-direction:column;gap:1.5mm;}
.indep p{font-size:7.6pt;color:#B6BECB;line-height:1.5;max-width:none;}
.indep b{color:var(--fg);}

/* mission */
.mission{display:flex;flex-direction:column;gap:7mm;height:100%;}
.m-big{font-size:20pt;font-weight:700;letter-spacing:-.025em;line-height:1.24;max-width:210mm;}
.m-body{font-size:10pt;color:#B6BECB;line-height:1.62;}
.m-body + .m-body{margin-top:4mm;}

/* pillars */
.pillars{display:flex;flex-direction:column;gap:2mm;}
.pil{display:flex;gap:4.5mm;align-items:flex-start;background:var(--surface);
 border:1px solid var(--edge);border-left:.9mm solid var(--sig-dim);padding:2.9mm 4.5mm;}
.pil .mk{width:36px;height:36px;flex:none;margin-top:.5mm;}
.pil-b{display:flex;flex-direction:column;gap:1mm;}
.pil-b b{font-size:10pt;letter-spacing:-.01em;}
.pil-s{font-size:7.6pt;color:var(--sig);text-transform:uppercase;letter-spacing:.1em;}
.pil-b p{font-size:8pt;color:var(--muted);line-height:1.46;margin-top:.7mm;max-width:none;}

/* creed */
.creed{border:1px solid var(--edge);background:#000;padding:11mm 8mm;margin-bottom:7mm;text-align:center;}
.cr-big{font-size:19pt;font-weight:700;line-height:1.32;letter-spacing:-.02em;max-width:none;}
.creed-x{display:grid;place-items:center;padding:2mm 0 4mm;}

/* generic */
.two{display:grid;grid-template-columns:1fr 1fr;gap:8mm;}
.col{display:flex;flex-direction:column;gap:5mm;min-width:0;}
.panel{background:var(--surface);border:1px solid var(--edge);padding:5mm;
 display:flex;flex-direction:column;gap:3.5mm;}
.panel.warn{border-left:1mm solid var(--sig-dim);}
.panel ul{margin:0;padding-left:5mm;display:flex;flex-direction:column;gap:2.4mm;font-size:9pt;}
.panel.yes li::marker{color:#33E62B;} .panel.no li::marker{color:var(--sig);}
.note{font-size:8.6pt;color:var(--muted);border-left:.6mm solid var(--sig-dim);
 padding-left:4mm;line-height:1.55;}
.note b{color:var(--fg);font-weight:700;}
.note.reject{border-left-color:#3A4150;}
.closing{margin-top:4mm;font-size:11pt;color:var(--muted);font-style:italic;text-align:center;}

table{border-collapse:collapse;width:100%;font-size:8.6pt;}
.grid-t th{text-align:left;font-size:7.2pt;text-transform:uppercase;letter-spacing:.1em;
 color:var(--muted);font-weight:400;background:var(--surface);padding:2.4mm 3mm;
 border-bottom:1px solid var(--edge);}
.grid-t td{padding:1.7mm 3mm;border-bottom:1px solid var(--edge);vertical-align:top;}
.grid-t td:first-child{color:var(--fg);white-space:nowrap;}
.grid-t.wide td:last-child{color:var(--muted);}

.sws{display:grid;grid-template-columns:repeat(6,1fr);gap:3mm;margin-top:3mm;}
.sw{border:1px solid var(--edge);background:var(--surface);}
.sw .chip{height:30mm;border-bottom:1px solid var(--edge);}
.sw .meta{padding:3mm;display:flex;flex-direction:column;gap:1mm;}
.sw .hex{font-size:9pt;font-weight:700;}
.sw .use{font-size:7.6pt;color:var(--muted);line-height:1.4;}

.mk{display:block;fill:none;}
svg.mk[viewBox]{width:100%;height:100%;}
.mk.loose{width:62px;height:62px;stroke:#F213A0;stroke-width:1.88;
 stroke-linecap:round;stroke-linejoin:round;color:#F213A0;}
.mk.gy{width:52px;height:52px;stroke:#5A6474;stroke-width:2.1;stroke-linecap:round;stroke-linejoin:round;}
.mk.sg{width:52px;height:52px;stroke:var(--sig);stroke-width:2.1;stroke-linecap:round;stroke-linejoin:round;}

.xrow{display:flex;gap:7mm;justify-content:center;}
.xrow figure{margin:0;display:flex;flex-direction:column;align-items:center;gap:2.5mm;}
.xrow figcaption{font-size:7pt;color:var(--muted);text-align:center;}

.clsgrid{display:grid;grid-template-columns:repeat(3,1fr);gap:4mm;}
.cls{border:1px solid var(--edge);background:var(--surface);display:flex;flex-direction:column;}
.cls-top{display:flex;align-items:center;gap:3.5mm;padding:3.5mm 4mm;
 background:#0E0F13;border-bottom:1px solid var(--edge);}
.cls-top .mk{width:34px;height:34px;flex:none;}
.cls-name{font-size:10pt;font-weight:700;}
.cls-hex{margin-left:auto;font-size:8pt;font-weight:700;}
.cls-body{padding:4mm;display:flex;flex-direction:column;gap:2.6mm;}
.cls-rule{font-size:8.8pt;} .cls-eg{font-size:7.6pt;color:var(--muted);}
.cls-cr{font-size:7pt;color:#5A6474;} .cls-cr b{color:var(--muted);}

.terms{display:flex;flex-direction:column;gap:3mm;}
.tf{margin:0;display:flex;align-items:center;gap:5mm;background:var(--surface);
 border:1px solid var(--edge);padding:4mm;}
.tf .mk{width:52px;height:52px;flex:none;}
.tf figcaption{display:flex;flex-direction:column;gap:1mm;}
.tf b{font-size:10pt;} .tf span{font-size:8pt;color:var(--muted);}
.pgrid{display:flex;gap:3mm;margin-top:auto;}
.pg-c{flex:1;height:14mm;border:1px solid var(--edge);}
.fams{display:flex;gap:4mm;}
.ff{margin:0;flex:1;background:var(--surface);border:1px solid var(--edge);
 padding:4mm;display:flex;flex-direction:column;align-items:center;gap:3mm;}
.ff .mk{width:58px;height:58px;}
.ff figcaption{display:flex;flex-direction:column;gap:.8mm;text-align:center;}
.ff b{font-size:8.8pt;} .ff span{font-size:7.2pt;color:var(--muted);}
.ff.dim{opacity:.72;} .ff.dim .mk{width:42px;height:42px;}
.clash{background:var(--surface);border:1px solid var(--edge);padding:2mm 0;}
.cl-row{display:flex;align-items:center;gap:4mm;padding:1.8mm 4mm;font-size:8.6pt;}
.cl-row .mk{width:22px;height:22px;flex:none;}

.gridart{background:var(--surface);border:1px solid var(--edge);padding:5mm;
 display:flex;flex-direction:column;gap:4mm;}
.knock{background:var(--surface);border:1px solid var(--edge);padding:4mm 5mm;
 display:flex;flex-direction:column;gap:3mm;margin-top:4mm;}
.kn-row{display:flex;gap:5mm;justify-content:space-between;}
.kn-row figure{margin:0;display:flex;flex-direction:column;align-items:center;gap:1.6mm;}
.kn-row .mk{display:inline-block;}
.kn-row figcaption{font-size:6.6pt;color:var(--muted);text-align:center;line-height:1.35;}
.ga-frame{flex:1;display:grid;place-items:center;background:
 linear-gradient(#232936 .3mm,transparent .3mm) 0 0/100% 12.5%,
 linear-gradient(90deg,#232936 .3mm,transparent .3mm) 0 0/12.5% 100%,#0E0F13;}
.ga-frame .mk{width:150px;height:150px;}
.ga-cap{font-size:8pt;color:var(--muted);}

.demos{display:grid;grid-template-columns:repeat(4,1fr);gap:4mm;margin-bottom:6mm;}
.dm{margin:0;background:var(--surface);border:1px solid var(--edge);padding:4mm;
 display:flex;flex-direction:column;align-items:center;gap:3mm;}
.dm-art{display:flex;align-items:center;gap:4mm;}
.arw{color:#4C566A;font-size:12pt;}
.dm figcaption{font-size:7.4pt;color:var(--muted);text-align:center;line-height:1.45;}
.hrules{display:grid;grid-template-columns:repeat(2,1fr);gap:3mm 7mm;margin-bottom:5mm;}
.hr{display:flex;gap:4mm;align-items:baseline;}
.hn{font-size:15pt;font-weight:700;color:var(--sig-dim);line-height:1;}
.hr b{font-size:9.6pt;} .hr p{font-size:8.2pt;color:var(--muted);margin-top:1mm;}
.tagx{font-size:6.4pt;text-transform:uppercase;letter-spacing:.09em;margin-left:3mm;
 padding:.4mm 1.8mm;border:.3mm solid var(--edge);color:var(--muted);}
.tagx.earned{color:var(--sig);border-color:var(--sig-dim);}

.cats{column-count:2;column-gap:8mm;}
.cat{break-inside:avoid;background:var(--surface);border:1px solid var(--edge);
 border-left:.8mm solid var(--sig-dim);padding:2.8mm 3.4mm;margin-bottom:2.8mm;
 display:flex;flex-direction:column;gap:2mm;}
.cat.outside{border-left-color:#3A4150;}
.cat-h{display:flex;align-items:center;gap:3mm;}
.cat-h b{font-size:9pt;letter-spacing:-.01em;}
.subrow{display:flex;flex-direction:column;gap:1.4mm;}
.sub-h{display:flex;align-items:center;gap:2.2mm;font-size:7.6pt;color:var(--muted);}
.tools{display:flex;flex-wrap:wrap;gap:2mm 2.6mm;}
.tcell{margin:0;display:flex;flex-direction:column;align-items:center;gap:1mm;width:13mm;}
.tcell figcaption{font-size:5.6pt;color:var(--muted);text-align:center;line-height:1.2;}
.ic30,.ic28,.ic22{display:inline-flex;flex:none;}
.ic30 svg,.ic28 svg,.ic22 svg{width:100%;height:100%;}
.ic30{width:26px;height:26px;} .ic28{width:25px;height:25px;} .ic22{width:20px;height:20px;}

.motifs{display:flex;gap:5mm;justify-content:space-between;background:#000;
 border:1px solid var(--edge);padding:8mm 6mm;}
.mo{margin:0;display:flex;flex-direction:column;align-items:center;gap:3.5mm;}
.mo figcaption{font-size:7.2pt;text-transform:uppercase;letter-spacing:.09em;color:var(--muted);}

/* laws */
.laws{display:grid;grid-template-columns:1fr 1fr;gap:3.5mm 8mm;}
.law{display:flex;gap:4mm;align-items:flex-start;}
.ln-n{font-size:13pt;font-weight:700;color:var(--sig-dim);line-height:1.1;}
.law b{font-size:9.8pt;letter-spacing:-.01em;}
.law p{font-size:8.2pt;color:var(--muted);line-height:1.5;margin-top:1.2mm;}

.spec-blk{background:var(--surface);border:1px solid var(--edge);padding:5mm;
 display:flex;flex-direction:column;gap:1.5mm;height:100%;}
.sp-lab{font-size:6.6pt;text-transform:uppercase;letter-spacing:.11em;color:#5A6474;margin-top:3mm;}
.sp{color:var(--fg);}
.sp-d{font-size:23pt;font-weight:700;letter-spacing:-.03em;line-height:1.08;}
.sp-s{font-size:14pt;font-weight:700;letter-spacing:-.02em;}
.sp-l{font-size:8.4pt;text-transform:uppercase;letter-spacing:.12em;color:var(--muted);}
.sp-b{font-size:9.4pt;line-height:1.6;}
.charset{background:var(--surface);border:1px solid var(--edge);padding:5mm;
 display:flex;flex-direction:column;gap:1.4mm;}
.cs-row{font-size:12.5pt;letter-spacing:.02em;color:#AEB6C2;}

.term{border:1px solid var(--edge);margin-top:5mm;}
.term-bar{background:#0E0F13;border-bottom:1px solid var(--edge);padding:2.4mm 4mm;
 font-size:7pt;text-transform:uppercase;letter-spacing:.1em;color:var(--muted);}
.term-body{background:var(--surface);padding:4mm;font-size:8.8pt;line-height:1.75;}
.tg{color:var(--sig);} .tm{color:var(--fg);} .tc{color:#5A6474;}
"""

FOOTWM = ('<span class="wm" style="font-size:7pt;letter-spacing:.2em;text-indent:.2em">'
          '<span class="sc">AN</span><span class="nix">NIX</span><span class="sc">ION</span></span>')
doc = ('<!doctype html><html lang="en"><head><meta charset="utf-8">'
       '<title>AnNIXion — Visual Identity</title>'
       f'<style>{CSS}</style></head><body>' + "".join(P) + '</body></html>')
doc = doc.replace("{TOTAL}", f"{len(P):02d}").replace("{WM}", FOOTWM)
with open(OUT, "w") as fh:
    fh.write(doc)
print(f"{OUT}: {len(P)} pages")
