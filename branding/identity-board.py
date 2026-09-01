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

CHROME = [("#0E0F13","Deepest ground","home/zsh/omp-theme.nix:3"),
          ("#1A1D24","Raised surface","home/zsh/omp-theme.nix:3"),
          ("#2E323D","Segment, divider","home/zsh/omp-theme.nix:3"),
          ("#FF0033","The signature accent","18 uses across home/"),
          ("#DFE4EA","Primary text","home/zsh/omp-theme.nix:3"),
          ("#301212","Root ground","home/konsole.nix:55")]
GRAFFITI = [("#000000","Wall ground — 62% of wallpaper pixels"),
            ("#0F5AE6","Cobalt — the figure"),
            ("#F213A0","Magenta — spray tags, smiley, jester"),
            ("#33E62B","Acid green — the throw-up tag")]
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
 ("Boot loader","themed","systemd-boot draws a text menu and takes no theme, so the mark's first appearance is the Plymouth splash"),
 ("Login (SDDM)","themed","Breeze's greeter rebranded through theme.conf alone — no QML of our own"),
 ("Lock screen","themed","wallpaper_2.png via home/plasma.nix:36"),
 ("Desktop","themed","wallpaper_1.png, preserveAspectFit on pure black"),
 ("Panel","themed","32px, annixion-logo as launcher icon"),
 ("Application menu","themed","42 entries, 34 directories, 81 marks"),
 ("Terminal","themed","Konsole, 85% opacity with blur"),
 ("Prompt","themed","oh-my-posh, chrome palette, red accent diamonds"),
 ("fastfetch","themed","AnNIXion mark at width 30, keys and title in red"),
 ("Browser profiles","themed","One mark in four class colours"),
 ("README / GitHub","themed","Glitch banner, wordmark lockup, badge row"),
 ("ISO","themed","Banner on black for both the syslinux and GRUB menus"),
]
REJECTED = [
 ("The hexagonal badge","Every glyph seated in a coloured hexagon.",
  "The container spent 82% of the canvas on itself, leaving the drawing at 18% of the area and a 1.01px stroke once the menu rendered 22px. Two tools in the same class became a coloured hexagon with a smudge inside.",
  "Filling the canvas gives 4.2× the drawn area and 1.9× the stroke weight from the same drawings."),
 ("Rotating marks off-axis","A few degrees of tilt on every mark, for looseness.",
  "It reads as hand-drawn at 96px and as a rendering bug at 22px, and a menu column all leaning the same way looks broken rather than deliberate.",
  "The hand lives in the strokes, not the transform."),
 ("A globe for the browser profiles","The obvious drawing for a web browser.",
  "At 22px it is indistinguishable from the Internet directory's own globe, which sits directly above it in the same menu, and both are grey.",
  "The window and tab is one stroke less obvious and unmistakably not that."),
 ("A drip bolted onto machine geometry","Perfect rectangles, with paint added afterwards.",
  "Adding a drip to a machine-perfect rectangle does not make it graffiti — it makes it a rectangle with a drip.",
  "The hand has to be in the geometry itself, which is what devices 1 and 2 are for."),
 ("Our own SDDM greeter in QML","Full control over the login surface.",
  "A greeter that fails to load leaves no way into the machine.",
  "Breeze's greeter, rebranded through theme.conf — it is already tested by everyone running Plasma."),
 ("Shadowing upstream icon names","Drawing annixion marks under names like wireshark or ghidra, so pinned stock launchers wear them too.",
  "A mark filed under an upstream name silently wins the icon lookup for every application that asks for it, including ones we never drew for.",
  "Marks stay namespaced annixion-*, and tests/menu-icons.sh fails on any un-namespaced file in the theme. The six stock launchers pinned to the panel keep their upstream icons."),
]
DO = ["State what happened and what to do about it.",
      "Name things the way an operator does — <em>targets</em>, <em>hosts</em>, <em>captures</em>.",
      "Say the consequence before the mechanism, in commit messages and errors alike.",
      "Keep the dry register: the wall is loud so the words do not have to be."]
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
                f'<div class="pt"><h2>{title}</h2><p class="kick">{kicker}</p></div>'
                f'<div class="rule"></div></header>')
    return f'<section class="page {cls}">{head}<div class="pb">{body}</div>'\
           f'<footer class="pf"><span>AnNIXion — Visual Identity</span>'\
           f'<span>0.3.1 “Tripwire”</span>'\
           f'<span class="pg">{PAGENO[0]:02d} / {{TOTAL}}</span></footer></section>'

P = []

# ── cover ────────────────────────────────────────────────────────────────
P.append(page(None,"","",f'''
<div class="cover">
  <div class="cov-l">
    <div class="eyebrow"><span class="rr"></span><span class="lab">Design board · v0.3.1 “Tripwire”</span></div>
    <h1>Everything gets<br>crossed <span class="sig">out</span></h1>
    <p class="lede">The X is already the loudest thing AnNIXion owns. It is the hero letterform in the
    wordmark, it is the dead eyes on the wall, and it is what an operator leaves behind. This board is the
    whole system: one palette lifted off the wallpaper, one set of hand-drawn marks, one face, and a rule
    for every surface the distribution puts in front of you.</p>
    <div class="wordmark">
      <div class="wm">an<span class="nix">NIX</span>ion</div>
      <div class="wmd"><span class="ln"></span><span class="bx">OFFENSIVE SECURITY DISTRIBUTION</span><span class="ln"></span></div>
    </div>
    <p class="tagline">“The environment for operators who refuse to wing it”</p>
  </div>
  <div class="cov-r">{mark("logo", 168)}</div>
</div>''',"cover-page"))

# ── 01 name and mark ─────────────────────────────────────────────────────
P.append(page("01","Name and mark","Always AnNIXion in running text — one word, capital A, capital NIX. Never Annixion, never ANNIXION.",f'''
<div class="two">
  <div class="col">
    <table class="kv">
      <tr><th>Wordmark</th><td><code>anNIXion</code>, NIX in <code>#FF0033</code></td></tr>
      <tr><th>Descriptor</th><td>OFFENSIVE SECURITY DISTRIBUTION, boxed in a hairline red rule</td></tr>
      <tr><th>Tagline</th><td>README and release notes only, never the lockup</td></tr>
      <tr><th>Logo</th><td>Nix snowflake under a datamosh glitch — a hero image, never an icon</td></tr>
      <tr><th>Launcher mark</th><td><code>annixion-logo</code> — the same snowflake drawn to the mark rules</td></tr>
      <tr><th>Codename</th><td>One word in <code>RELEASE_NAME</code> beside the number in <code>VERSION</code></td></tr>
    </table>
    <div class="note"><b>In the wordmark</b>, the three letters of NIX carry the signature red and the rest
    stays light, so the Nix lineage is legible without saying it. Letterspacing is wide (0.30em), weight is
    light: it is a wordmark, not a headline.</div>
  </div>
  <div class="col">
    <div class="panel">
      <span class="lab">The X — the recurring device</span>
      <div class="xrow">
        <figure>{mark("logo",56)}<figcaption>in the mark</figcaption></figure>
        <figure><svg class="mk loose" style="width:56px;height:56px" viewBox="0 0 24 24" fill="none" stroke="#FF0033" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">{MOTIFS[0][1]}</svg><figcaption>as the eyes on the wall</figcaption></figure>
        <figure>{mark("menu-root",56)}<figcaption>over a finished target</figcaption></figure>
      </div>
      <p class="sm">Three places that were never talking to each other. The X is the crossed-out letter in
      the wordmark, the eyes on the graffiti smiley, and the shape an operator draws over a target that is
      done. Making it the system cost nothing — it was already there.</p>
    </div>
    <div class="panel warn">
      <span class="lab">Dark ground only</span>
      <p class="sm">The datamosh logo is light artwork on transparency: it vanishes on any light surface, and
      at the 32px the panel gives it the glitch bars collapse into a smear. The panel wears
      <code>annixion-logo</code> instead. Because that is a stroke rather than baked pixels, it is also the
      first form of the mark that can be recoloured for a light surface.</p>
    </div>
  </div>
</div>'''))

# ── 02 palette ───────────────────────────────────────────────────────────
sw = "".join(f'<div class="sw"><div class="chip" style="background:{h}"></div>'
             f'<div class="meta"><span class="hex">{h}</span><span class="use">{r}</span>'
             f'<span class="src">{d}</span></div></div>' for h,r,d in CHROME)
gr = "".join(f'<div class="sw"><div class="chip" style="background:{h}"></div>'
             f'<div class="meta"><span class="hex">{h}</span><span class="use">{r}</span></div></div>' for h,r in GRAFFITI)
P.append(page("02","Palette","A sober red-on-Nord chrome runs the interface; a neon graffiti wall runs behind it.",f'''
<span class="lab">Chrome — the interface</span>
<div class="sws">{sw}</div>
<span class="lab" style="margin-top:8mm;display:block">Graffiti — sampled from assets/wallpaper/</span>
<div class="sws">{gr}</div>
<div class="note" style="margin-top:7mm">The mark colours are lifted off the wall, so the menu speaks the
wallpaper's language the moment it opens. Motifs live on pure black and nowhere else, one spray colour per
motif, never two in the same mark.</div>'''))

# ── 03 semantic classes ──────────────────────────────────────────────────
cards = "".join(
 f'<div class="cls"><div class="cls-top">{mark(ic,34)}<span class="cls-name">{n}</span>'
 f'<span class="cls-hex" style="color:{c}">{c}</span></div>'
 f'<div class="cls-body"><p class="cls-rule">{r}</p>'
 f'<p class="cls-eg">{" · ".join(eg)}</p>'
 f'<p class="cls-cr">contrast <b>{cr}</b> on the #14171D menu ground</p></div></div>'
 for n,c,cr,r,ic,eg in CLASSES)
P.append(page("03","Semantic classes","Colour encodes what running the tool does to the target, not which kill-chain phase it sits in — the menu already tells you the phase.",f'''
<div class="clsgrid">{cards}</div>
<div class="note" style="margin-top:6mm"><b>Red means the tool needs written authorisation behind it.</b>
That is the one class where the mark is a check on muscle memory rather than decoration. Phases 03 through
07 all land on offensive red, giving the menu an unbroken red band down its middle — the stretch where you
are inside someone else's estate.</div>'''))

# ── 04 session colours ───────────────────────────────────────────────────
terms = "".join(f'<figure class="tf">{mark(m,54)}<figcaption><b>{lbl}</b><span>{d}</span></figcaption></figure>'
  for m,lbl,d in [("konsole","Operator","#7A8494 · the operator's own shell"),
                  ("konsole-root","Root","#FF0033 · sudo -i, on the #301212 root profile"),
                  ("konsole-nix","Nix shell","#7EBAE4 · nix develop, where the checks run")])
P.append(page("04","Session colours","The six classes say what a tool does to a target. A terminal does nothing to a target, so the terminal family is coloured by the session you are standing in instead.",f'''
<div class="two">
 <div class="col">
  <div class="terms">{terms}</div>
  <div class="note">The values are the prompt's own — the session segment flips to accent red as root and to
  Nix blue inside a Nix shell (<code>home/zsh/omp-theme.nix:37</code>). The launcher and the shell it opens
  agree before you have typed anything.</div>
 </div>
 <div class="col">
  <table class="grid-t">
   <thead><tr><th>Colour</th><th>Value</th><th>Contrast</th><th>Session</th></tr></thead>
   <tbody>
    <tr><td>Utility</td><td><code>#7A8494</code></td><td>4.8:1</td><td>The operator's own shell</td></tr>
    <tr><td>Elevated</td><td><code>#FF0033</code></td><td>4.5:1</td><td>root</td></tr>
    <tr><td>Nix</td><td><code>#7EBAE4</code></td><td>8.6:1</td><td>Inside <code>nix develop</code></td></tr>
   </tbody></table>
  <div class="note"><b>Elevated repeats the signature red</b> rather than introducing a seventh value: root
  is the one session that is dangerous to miss, and it should read as the same red the root Konsole
  background and the prompt already use. These two colours are the terminal family's alone — no tool mark
  may take them.</div>
  <div class="note"><b>This is the elevation rule reaching one surface earlier.</b> The root Konsole already
  changes the ground you are standing on once the window is open; colouring the launcher says it while the
  pointer is still over the menu.</div>
 </div>
</div>'''))

# ── 05 typography ────────────────────────────────────────────────────────
P.append(page("05","Typography","JetBrains Mono is the display and interface face. Things you type should look typed.",f'''
<div class="two">
 <div class="col">
  <div class="spec-blk">
   <div class="sp-lab">Display · 46px · -0.03em</div>
   <div class="sp sp-d">Everything gets crossed out</div>
   <div class="sp-lab">Section · 26px · -0.02em</div>
   <div class="sp sp-s">The mark system</div>
   <div class="sp-lab">Label · 11px · uppercase · 0.12em</div>
   <div class="sp sp-l">SEMANTIC CLASSES</div>
   <div class="sp-lab">Body · 16px · 1.6</div>
   <div class="sp sp-b">Say the consequence before the mechanism.</div>
   <div class="sp-lab">Wordmark · light · 0.30em — the one place tracking goes wide</div>
   <div class="sp sp-w">an<span class="sig">NIX</span>ion</div>
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
  <table class="kv">
   <tr><th>Face</th><td><code>nerd-fonts.jetbrains-mono</code>, shipped in <code>home.nix</code></td></tr>
   <tr><th>Fallback</th><td><code>nerd-fonts.fira-code</code></td></tr>
   <tr><th>Display tracking</th><td><code>-0.03em</code> at display sizes</td></tr>
   <tr><th>Labels</th><td>11px uppercase at <code>0.12em</code></td></tr>
   <tr><th>Wordmark</th><td>light weight, <code>0.30em</code></td></tr>
  </table>
  <div class="note">Category strings and paths keep the mono face — they are things you type, and should
  look typed. This board is set in the same face the system is.</div>
 </div>
</div>'''))

# ── 06 the mark system ───────────────────────────────────────────────────
P.append(page("06","The mark system","Every AnNIXion application and menu directory gets a single-colour line drawing filling its whole canvas. No container, no plate — the colour classifies, the silhouette identifies.",f'''
<div class="two">
 <div class="col">
  <div class="gridart"><div class="ga-frame">{mark("nmap",150)}</div>
   <div class="ga-cap">Nmap at 150px on the 24-unit grid. The drawing fills 21 × 21, leaving 1.5 units of
   air each side so round caps never clip.</div></div>
 </div>
 <div class="col">
  <table class="grid-t">
   <thead><tr><th>Rule</th><th>Value</th><th>Why</th></tr></thead>
   <tbody>
    <tr><td>Grid</td><td>24 × 24, drawing fills 21 × 21</td><td>1.5 units of air each side</td></tr>
    <tr><td>Stroke</td><td>2.1, round cap and join</td><td>Lands at 1.93px when the menu draws 22px</td></tr>
    <tr><td>Colour</td><td>Whole mark in one class colour</td><td>Colour classifies, silhouette identifies</td></tr>
    <tr><td>Fills</td><td>Only for dots under 2.5 units</td><td>Anything larger becomes a blob at 16px</td></tr>
    <tr><td>Detail budget</td><td>Five strokes or fewer</td><td>Spend the sixth on silhouette, never texture</td></tr>
    <tr><td>Silhouette</td><td>Must differ from its classmates</td><td>Inside a class the colour is identical</td></tr>
    <tr><td>Subject</td><td>What the tool does, never its logo</td><td>Upstream logos break the set</td></tr>
    <tr><td>Naming</td><td><code>annixion-&lt;tool&gt;</code></td><td>Namespaced against upstream hicolor icons</td></tr>
    <tr><td>Export</td><td><code>scalable/apps/annixion-&lt;tool&gt;.svg</code></td><td>One file per mark</td></tr>
   </tbody></table>
  <div class="note"><b>Test at 22px, next to its classmates</b> — not alone and not at 96px. A mark is
  finished when you can pick it out of its own class colour at menu size. If you cannot, change the shape
  rather than adding detail.</div>
 </div>
</div>'''))

# ── 07 the hand ──────────────────────────────────────────────────────────
demos = "".join(f'<figure class="dm">'
  f'<div class="dm-art"><svg class="mk gy" viewBox="0 0 24 24">{g}</svg>'
  f'<span class="arw">&rarr;</span>'
  f'<svg class="mk sg" viewBox="0 0 24 24">{h}</svg></div>'
  f'<figcaption>{cap}</figcaption></figure>' for g,h,cap in GEO)
rules = "".join(f'<div class="hr"><span class="hn">{n}</span><div><b>{t}</b>'
  f'<span class="tagx {k}">{k}</span><p>{d}</p></div></div>' for n,t,d,k in HAND)
P.append(page("07","The hand","Adding a drip to a machine-perfect rectangle does not make it graffiti — it makes it a rectangle with a drip. The hand has to be in the geometry itself.",f'''
<div class="demos">{demos}</div>
<div class="hrules">{rules}</div>
<div class="note">Rules 1 and 2 are universal and apply to every mark in the set. Rules 3 and 4 are semantic
and are earned. Corners and crossings overshoot their joins by up to a unit throughout — the marker keeps
moving after the shape has ended.</div>'''))

# ── 08 families ──────────────────────────────────────────────────────────
ffam = "".join(f'<figure class="ff">{mark(m,60)}<figcaption><b>{lbl}</b><span>{c}</span></figcaption></figure>'
  for m,lbl,c in [("firefox-untrusted","Unsafe Browser","utility · #7A8494"),
                  ("firefox-redteam","Red Team","offensive · #FF0033"),
                  ("firefox-osint","OSINT","probe · #FFD000"),
                  ("firefox-puppet","Puppet Master","passive · #33E62B")])
res = "".join(f'<figure class="ff dim">{mark("firefox-untrusted",44,c)}<figcaption><span>{lbl}</span></figcaption></figure>'
  for c,lbl in [("#4A90FF","forensic — reserved"),("#F213A0","reverse — reserved")])
P.append(page("08","Families","Where one application appears several times under different colours, every copy shares a single drawing and the colour carries the whole difference.",f'''
<span class="lab">The browser profiles — one drawing, four classes</span>
<div class="fams">{ffam}</div>
<div class="two" style="margin-top:6mm">
 <div class="col">
  <div class="note"><b>Bound once</b> at the top of <code>home/icons/marks.nix</code> and referenced by
  name, so a redraw cannot drift between the variants and a fifth variant costs no artwork at all — the two
  reserve classes below are two lines each.</div>
  <div class="fams">{res}</div>
 </div>
 <div class="col">
  <div class="note reject"><b>Why not a globe.</b> A globe is the more obvious browser drawing. At 22px it
  is indistinguishable from the Internet directory's own globe, which sits directly above it in the same
  menu — and both are grey. The window and tab is one stroke less obvious and unmistakably not that.</div>
  <div class="clash">
   <div class="cl-row">{mark("menu-internet",22)}<span>Internet — directory</span></div>
   <div class="cl-row">{mark("firefox-untrusted",22)}<span>Firefox — Unsafe Browser</span></div>
   <div class="cl-row">{mark("firefox-redteam",22)}<span>Firefox — Red Team</span></div>
   <div class="cl-row">{mark("firefox-osint",22)}<span>Firefox — OSINT</span></div>
   <div class="cl-row">{mark("firefox-puppet",22)}<span>Firefox — Puppet Master</span></div>
  </div>
  <div class="note">OSINT is amber rather than green deliberately: the profile drives a real browser at a
  real target, fetching their pages and landing in their logs. That is probe, not passive.</div>
 </div>
</div>'''))

# ── 09/10 the full set ───────────────────────────────────────────────────
names = sorted(n[len("annixion-"):-4] for n in os.listdir(ICONS) if n.startswith("annixion-"))
tools = [n for n in names if not n.startswith("menu-")]
dirs  = [n for n in names if n.startswith("menu-")]
def cell(n): return f'<figure class="tl">{mark(n,52)}<figcaption>{n}</figcaption></figure>'
P.append(page("09","The set — applications",f"{len(tools)} application marks. Colour is the class; every silhouette differs from its classmates.",
  f'<div class="setgrid">{"".join(cell(n) for n in tools)}</div>'))
P.append(page("10","The set — menu directories",f"{len(dirs)} directory marks, one per node of the kill-chain tree. A directory takes the colour of what it contains.",
  f'<div class="setgrid">{"".join(cell(n) for n in dirs)}</div>'))

# ── 11 motifs ────────────────────────────────────────────────────────────
mot = "".join(f'<figure class="mo"><svg class="mk loose" viewBox="0 0 24 24">{d}</svg>'
  f'<figcaption>{n}</figcaption></figure>' for n,d in MOTIFS)
P.append(page("11","Motif vocabulary","The wallpapers carry a fixed cast. Reuse these rather than inventing new ones.",f'''
<div class="motifs">{mot}</div>
<div class="two" style="margin-top:7mm">
 <div class="col"><div class="note"><b>Where they are allowed.</b> Wallpaper, lock screen, ISO boot splash,
 fastfetch banner, README header, release art. Motifs live on pure black and nowhere else. They drip
 downward, never upward. One spray colour per motif, never two in the same mark.</div></div>
 <div class="col"><div class="note reject"><b>Not the panel and not the menu</b> — with one exception. The
 X-eyed smiley is the Post-Exploitation mark, because there it states something true rather than
 decorating. Motifs are drawn looser than tool marks: stroke 1.7, hand-weighted curves, allowed to
 overshoot much further.</div></div>
</div>'''))

# ── 12 surfaces ──────────────────────────────────────────────────────────
rows = "".join(f'<tr><td>{s}</td><td><span class="pill">{st}</span></td><td>{d}</td></tr>' for s,st,d in SURFACES)
P.append(page("12","Surfaces","A rule for every surface the distribution puts in front of you, from power-on to the desktop.",f'''
<table class="grid-t wide"><thead><tr><th>Surface</th><th>State</th><th>Notes</th></tr></thead><tbody>{rows}</tbody></table>
<div class="two" style="margin-top:6mm">
 <div class="col"><div class="note"><b>Boot.</b> <code>boot.loader.timeout</code> stays at 3 seconds. A
 splash that cannot be interrupted is a machine with no way back to an older generation. The splash is a
 Plymouth <code>script</code> theme copied into the initrd, so it must stay small.</div></div>
 <div class="col"><div class="note"><b>Elevation.</b> The root Konsole profile swaps the whole background
 to <code>#301212</code> rather than adding a warning icon. The rule generalises: privilege changes the
 surface you are standing on, never a decoration bolted onto it.</div></div>
</div>'''))

# ── 13 rejected ──────────────────────────────────────────────────────────
rej = "".join(f'<div class="rj"><b>{t}</b><p class="rj-w">{w}</p>'
  f'<p class="rj-x"><span>Why not</span>{y}</p><p class="rj-i"><span>Instead</span>{i}</p></div>'
  for t,w,y,i in REJECTED)
P.append(page("13","Rejected directions","What was tried, what it cost, and what replaced it. Kept because the next person to have the same idea deserves the measurement, not the argument.",
  f'<div class="rejects">{rej}</div>'))

# ── 14 voice ─────────────────────────────────────────────────────────────
P.append(page("14","Voice","The wall is loud so the words do not have to be.",f'''
<div class="two">
 <div class="col"><div class="panel yes"><span class="lab">Do</span><ul>{"".join(f"<li>{x}</li>" for x in DO)}</ul></div></div>
 <div class="col"><div class="panel no"><span class="lab">Don't</span><ul>{"".join(f"<li>{x}</li>" for x in DONT)}</ul></div></div>
</div>
<div class="term">
 <div class="term-bar">konsole — the register, in practice</div>
 <div class="term-body"><span class="tg">$&gt;</span> annixion-vpn-browser OSINT<br>
 <span class="tm">the tunnel is down; the browser did not start</span><br>
 <span class="tm">bring it up with: sudo systemctl start wg-quick-osint</span><br><br>
 <span class="tg">$&gt;</span> <span class="tc">// not: “Oops! Something went wrong :( Please try again.”</span></div>
</div>'''))

# ── 15 colophon ──────────────────────────────────────────────────────────
P.append(page("15","How it is built","Reclassifying a tool is a one-word change. Redrawing one is a change to its body. Neither touches the menu.",f'''
<div class="two">
 <div class="col">
  <table class="kv">
   <tr><th><code>home/icons/marks.nix</code></th><td>One entry per mark — a class and the 24-grid drawing. The two family bodies are bound in a <code>let</code> at the top and referenced by name.</td></tr>
   <tr><th><code>home/icons/default.nix</code></th><td>Renders each into <code>scalable/apps/annixion-&lt;name&gt;.svg</code>, the class supplying the stroke colour, and emits an <code>index.theme</code>.</td></tr>
   <tr><th><code>home.nix</code></th><td>Joins that theme with <code>SlotIcons</code> into the one directory <code>xdg.dataFile."icons"</code> owns.</td></tr>
   <tr><th><code>home/apps-menu.nix</code></th><td>Names marks only by <code>annixion-&lt;tool&gt;</code> and <code>annixion-menu-&lt;slug&gt;</code>.</td></tr>
   <tr><th><code>tests/menu-icons.sh</code></th><td>Fails on any <code>Icon=</code> that resolves nowhere, and on any un-namespaced file in the theme.</td></tr>
  </table>
 </div>
 <div class="col">
  <div class="note"><b>Adding a menu entry means adding its mark in the same commit.</b> The test is the
  check that would have caught the four dead names the previous theme was carrying — <code>codium</code>,
  <code>wireshark</code>, <code>network-transmit-receive</code> and <code>media-removable</code>, all of
  which drew a blank placeholder.</div>
  <div class="note"><b>Inheritance.</b> The theme inherits <code>Slot-Dark-Icons</code>,
  <code>breeze-dark</code>, <code>Adwaita</code> and <code>hicolor</code>, so anything the set does not draw
  still falls back to a real icon rather than a blank.</div>
  <div class="note reject"><b>One boundary.</b> Six launchers pinned to the panel are stock desktop entries
  — Konsole, Dolphin, Burp Suite, Wireshark, Ghidra, Obsidian — because Plasma matches a window to a
  launcher by class and only the stock name resolves. They wear their upstream icons. Shadowing those names
  in our theme would capture the lookup for every application that asks for them, so the test forbids it.</div>
  <div class="colo">Set in JetBrains Mono, the system's own face. Every mark on this board is read out of a
  built icon theme, not redrawn — regenerate with <code>branding/identity-board.sh</code>. The normative
  reference is <code>docs/visual-identity.md</code>.</div>
 </div>
</div>'''))

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
.page{width:297mm;height:210mm;padding:14mm 15mm 11mm;background:var(--void);
 position:relative;overflow:hidden;display:flex;flex-direction:column;
 page-break-after:always;break-after:page;}
.page:last-child{page-break-after:auto;break-after:auto;}
.pb{flex:1;min-height:0;}
h1,h2{margin:0;font-weight:700;letter-spacing:-.03em;line-height:1.06;}
h1{font-size:38pt;} h2{font-size:19pt;letter-spacing:-.02em;}
p{margin:0;}
code{font-family:var(--mono);font-size:.9em;color:var(--fg);
 background:rgba(255,255,255,.05);padding:.5px 3px;border-radius:2px;}
.sig{color:var(--sig);}
.lab{font-size:7.4pt;text-transform:uppercase;letter-spacing:.13em;color:var(--muted);}
.sm{font-size:8.4pt;color:var(--muted);line-height:1.55;}

/* header / footer */
.ph{display:grid;grid-template-columns:auto 1fr;gap:0 6mm;align-items:start;
 padding-bottom:5mm;margin-bottom:6mm;border-bottom:1px solid var(--edge);}
.pn{font-size:30pt;font-weight:700;color:var(--sig);line-height:.85;letter-spacing:-.05em;}
.pt h2{margin-bottom:2.2mm;}
.kick{font-size:9pt;color:var(--muted);max-width:175mm;}
.rule{display:none;}
.pf{display:flex;gap:6mm;align-items:center;padding-top:3.5mm;margin-top:5mm;
 border-top:1px solid var(--edge);font-size:7pt;color:#5A6474;letter-spacing:.06em;}
.pf .pg{margin-left:auto;}

/* cover */
.cover-page{padding:0;}
.cover{flex:1;display:grid;grid-template-columns:1fr 74mm;align-items:stretch;
 gap:14mm;padding:20mm 15mm;}
.eyebrow{display:flex;gap:5mm;align-items:center;margin-bottom:7mm;}
.rr{width:16mm;height:1.1mm;background:var(--sig);}
.cover .lede{font-size:10pt;color:var(--muted);max-width:150mm;margin:6mm 0 10mm;}
.wordmark{background:#000;border:1px solid var(--edge);padding:9mm 7mm;
 display:flex;flex-direction:column;align-items:center;gap:5mm;}
.wm{font-size:27pt;font-weight:300;letter-spacing:.30em;color:#F2F4F7;
 text-indent:.30em;line-height:1;}
.wm .nix{color:var(--sig);font-weight:400;}
.wmd{display:flex;align-items:center;gap:4mm;width:100%;}
.wmd .ln{flex:1;height:.3mm;background:var(--sig);}
.wmd .bx{border:.3mm solid var(--sig);padding:1.4mm 3.5mm;font-size:7pt;letter-spacing:.19em;}
.tagline{margin-top:7mm;font-size:9pt;color:var(--muted);font-style:italic;}
.cov-r{background:#000;border:1px solid var(--edge);padding:12mm;display:grid;place-items:center;}
.cov-l{display:flex;flex-direction:column;justify-content:center;}

/* layout */
.two{display:grid;grid-template-columns:1fr 1fr;gap:8mm;height:100%;}
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

/* tables */
table{border-collapse:collapse;width:100%;font-size:8.6pt;}
.kv th{text-align:left;vertical-align:top;padding:2.4mm 4mm 2.4mm 0;color:var(--muted);
 font-weight:400;white-space:nowrap;border-bottom:1px solid var(--edge);width:1%;}
.kv td{vertical-align:top;padding:2.4mm 0;border-bottom:1px solid var(--edge);}
.grid-t th{text-align:left;font-size:7.2pt;text-transform:uppercase;letter-spacing:.1em;
 color:var(--muted);font-weight:400;background:var(--surface);padding:2.4mm 3mm;
 border-bottom:1px solid var(--edge);}
.grid-t td{padding:2.4mm 3mm;border-bottom:1px solid var(--edge);vertical-align:top;}
.grid-t td:first-child{color:var(--fg);white-space:nowrap;}
.grid-t.wide td:last-child{color:var(--muted);}
.pill{font-size:7pt;text-transform:uppercase;letter-spacing:.08em;color:#33E62B;
 border:.3mm solid rgba(51,230,43,.42);padding:.6mm 2mm;}

/* swatches */
.sws{display:grid;grid-template-columns:repeat(6,1fr);gap:3mm;margin-top:3mm;}
.sw{border:1px solid var(--edge);background:var(--surface);}
.sw .chip{height:26mm;border-bottom:1px solid var(--edge);}
.sw .meta{padding:3mm;display:flex;flex-direction:column;gap:1mm;}
.sw .hex{font-size:9pt;font-weight:700;}
.sw .use{font-size:7.6pt;color:var(--muted);line-height:1.4;}
.sw .src{font-size:6.6pt;color:#5A6474;}

/* marks */
.mk{display:block;fill:none;}
svg.mk[viewBox]{width:100%;height:100%;}
.mk.loose{width:62px;height:62px;stroke:#F213A0;stroke-width:1.7;
 stroke-linecap:round;stroke-linejoin:round;color:#F213A0;}
.mk.gy{width:52px;height:52px;stroke:#5A6474;stroke-width:2.1;stroke-linecap:round;stroke-linejoin:round;}
.mk.sg{width:52px;height:52px;stroke:var(--sig);stroke-width:2.1;stroke-linecap:round;stroke-linejoin:round;}

.xrow{display:flex;gap:7mm;justify-content:center;}
.xrow figure{margin:0;display:flex;flex-direction:column;align-items:center;gap:2.5mm;}
.xrow figcaption{font-size:7pt;color:var(--muted);text-align:center;}

/* classes */
.clsgrid{display:grid;grid-template-columns:repeat(3,1fr);gap:4mm;}
.cls{border:1px solid var(--edge);background:var(--surface);display:flex;flex-direction:column;}
.cls-top{display:flex;align-items:center;gap:3.5mm;padding:3.5mm 4mm;
 background:#0E0F13;border-bottom:1px solid var(--edge);}
.cls-top .mk{width:34px;height:34px;flex:none;}
.cls-name{font-size:10pt;font-weight:700;}
.cls-hex{margin-left:auto;font-size:8pt;font-weight:700;}
.cls-body{padding:4mm;display:flex;flex-direction:column;gap:2.6mm;}
.cls-rule{font-size:8.8pt;}
.cls-eg{font-size:7.6pt;color:var(--muted);}
.cls-cr{font-size:7pt;color:#5A6474;}
.cls-cr b{color:var(--muted);}

/* terminals / families */
.terms{display:flex;flex-direction:column;gap:3mm;}
.tf{margin:0;display:flex;align-items:center;gap:5mm;background:var(--surface);
 border:1px solid var(--edge);padding:4mm;}
.tf .mk{width:54px;height:54px;flex:none;}
.tf figcaption{display:flex;flex-direction:column;gap:1mm;}
.tf b{font-size:10pt;} .tf span{font-size:8pt;color:var(--muted);}
.fams{display:flex;gap:4mm;}
.ff{margin:0;flex:1;background:var(--surface);border:1px solid var(--edge);
 padding:4mm;display:flex;flex-direction:column;align-items:center;gap:3mm;}
.ff .mk{width:60px;height:60px;}
.ff figcaption{display:flex;flex-direction:column;gap:.8mm;text-align:center;}
.ff b{font-size:8.8pt;} .ff span{font-size:7.2pt;color:var(--muted);}
.ff.dim{opacity:.72;} .ff.dim .mk{width:44px;height:44px;}
.clash{background:var(--surface);border:1px solid var(--edge);padding:2mm 0;}
.cl-row{display:flex;align-items:center;gap:4mm;padding:1.8mm 4mm;font-size:8.6pt;}
.cl-row .mk{width:22px;height:22px;flex:none;}

/* grid art */
.gridart{background:var(--surface);border:1px solid var(--edge);padding:5mm;
 display:flex;flex-direction:column;gap:4mm;height:100%;}
.ga-frame{flex:1;display:grid;place-items:center;background:
 linear-gradient(#232936 .3mm,transparent .3mm) 0 0/100% 12.5%,
 linear-gradient(90deg,#232936 .3mm,transparent .3mm) 0 0/12.5% 100%,#0E0F13;}
.ga-frame .mk{width:150px;height:150px;}
.ga-cap{font-size:8pt;color:var(--muted);}

/* hand */
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

/* the set */
.setgrid{display:grid;grid-template-columns:repeat(9,1fr);gap:6mm 3mm;}
.tl{margin:0;display:flex;flex-direction:column;align-items:center;gap:2mm;}
.tl .mk{width:52px;height:52px;}
.tl figcaption{font-size:6.6pt;color:var(--muted);text-align:center;line-height:1.25;
 word-break:break-word;}

/* motifs */
.motifs{display:flex;gap:5mm;justify-content:space-between;background:#000;
 border:1px solid var(--edge);padding:8mm 6mm;}
.mo{margin:0;display:flex;flex-direction:column;align-items:center;gap:3.5mm;}
.mo figcaption{font-size:7.2pt;text-transform:uppercase;letter-spacing:.09em;color:var(--muted);}

/* rejected */
.rejects{display:grid;grid-template-columns:repeat(3,1fr);gap:4mm;}
.rj{background:var(--surface);border:1px solid var(--edge);border-top:.8mm solid var(--sig-dim);
 padding:4mm;display:flex;flex-direction:column;gap:2.4mm;}
.rj b{font-size:9.4pt;}
.rj p{font-size:7.9pt;line-height:1.5;}
.rj-w{color:var(--muted);font-style:italic;}
.rj-x span,.rj-i span{display:block;font-size:6.6pt;text-transform:uppercase;
 letter-spacing:.11em;margin-bottom:.8mm;}
.rj-x span{color:var(--sig);} .rj-i span{color:#33E62B;}
.rj-x{color:var(--muted);} .rj-i{color:var(--fg);}

/* typography page */
.spec-blk{background:var(--surface);border:1px solid var(--edge);padding:5mm;
 display:flex;flex-direction:column;gap:1.5mm;height:100%;}
.sp-lab{font-size:6.6pt;text-transform:uppercase;letter-spacing:.11em;color:#5A6474;
 margin-top:3mm;}
.sp{color:var(--fg);}
.sp-d{font-size:23pt;font-weight:700;letter-spacing:-.03em;line-height:1.08;}
.sp-s{font-size:14pt;font-weight:700;letter-spacing:-.02em;}
.sp-l{font-size:8.4pt;text-transform:uppercase;letter-spacing:.12em;color:var(--muted);}
.sp-b{font-size:9.4pt;line-height:1.6;}
.sp-w{font-size:17pt;font-weight:300;letter-spacing:.30em;text-indent:.30em;}
.charset{background:var(--surface);border:1px solid var(--edge);padding:5mm;
 display:flex;flex-direction:column;gap:1.4mm;}
.cs-row{font-size:12.5pt;letter-spacing:.02em;color:#AEB6C2;}

/* terminal */
.term{border:1px solid var(--edge);margin-top:6mm;}
.term-bar{background:#0E0F13;border-bottom:1px solid var(--edge);padding:2.4mm 4mm;
 font-size:7pt;text-transform:uppercase;letter-spacing:.1em;color:var(--muted);}
.term-body{background:var(--surface);padding:4mm;font-size:8.8pt;line-height:1.75;}
.tg{color:var(--sig);} .tm{color:var(--fg);} .tc{color:#5A6474;}
.colo{font-size:7.6pt;color:#5A6474;line-height:1.55;margin-top:auto;}
"""

doc = ('<!doctype html><html><head><meta charset="utf-8">'
       '<title>AnNIXion — Visual Identity</title>'
       f'<style>{CSS}</style></head><body>' + "".join(P) + '</body></html>')
doc = doc.replace("{TOTAL}", f"{len(P):02d}")
with open(OUT, "w") as fh:
    fh.write(doc)
print(f"{OUT}: {len(P)} pages")
