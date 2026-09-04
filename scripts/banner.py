#!/usr/bin/env python3
"""Emit the banner as HTML, for scripts/banner.sh to render.

The lockup is drawn from the rules in docs/visual-identity.md rather than
redrawn by hand, so the banner cannot describe an identity that is not the one
documented: AN and ION as small caps at 0.62em, NIX full size in the signature
red, 0.30em tracking, light weight, and the descriptor boxed in a hairline rule.

Usage: banner.py <mark.png> <out.html> [width] [height]
"""
import base64
import pathlib
import sys

mark_path, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
W = int(sys.argv[3]) if len(sys.argv) > 3 else 1920
H = int(sys.argv[4]) if len(sys.argv) > 4 else 520

mark = base64.b64encode(mark_path.read_bytes()).decode()

# ── The palette, from docs/visual-identity.md ────────────────────────────
RED = "#FF0033"      # the signature accent
TEXT = "#DFE4EA"     # primary text
GROUND = "#000000"   # the void the mark is drawn on
MUTED = "#7A8494"    # utility grey

# Sized off the canvas height so the lockup holds its proportions at any size.
wordmark = round(H * 0.26)
descriptor = round(H * 0.049)
mark_size = round(H * 0.80)

out.write_text(f"""<!doctype html>
<meta charset="utf-8">
<style>
  @page {{ margin: 0; }}
  html, body {{ margin: 0; padding: 0; background: {GROUND}; }}
  body {{
    width: {W}px; height: {H}px;
    display: flex; align-items: center; justify-content: center;
    gap: {round(H * 0.075)}px;
    font-family: "JetBrainsMono Nerd Font", "JetBrains Mono", monospace;
    -webkit-font-smoothing: antialiased;
  }}

  /* The mark is a hero image here, drawn large — never an icon. */
  .mark {{ width: {mark_size}px; height: {mark_size}px; flex: none; }}

  .lockup {{ display: flex; flex-direction: column; align-items: flex-start; }}

  /* No lowercase in the lockup: AN and ION are small capitals either side of
     a full-size NIX, so both parts share a baseline and the colour does all
     the emphasis. In running text the name is still written AnNIXion. */
  .wordmark {{
    font-size: {wordmark}px;
    font-weight: 300;
    letter-spacing: 0.30em;
    line-height: 1;
    color: {TEXT};
    white-space: nowrap;
    /* Tracking adds space after the last glyph; pull it back so the block
       optically aligns with the rule underneath. */
    margin-right: -0.30em;
  }}
  .wordmark .small {{ font-size: 0.62em; }}
  .wordmark .nix {{ color: {RED}; }}

  .descriptor {{
    margin-top: {round(H * 0.055)}px;
    border: 1px solid {RED};
    padding: {round(H * 0.022)}px {round(H * 0.036)}px;
    font-size: {descriptor}px;
    letter-spacing: 0.12em;
    color: {TEXT};
    white-space: nowrap;
  }}
  .descriptor .sep {{ color: {MUTED}; margin: 0 0.7em; }}
</style>
<body>
  <img class="mark" src="data:image/png;base64,{mark}" alt="">
  <div class="lockup">
    <div class="wordmark"><span class="small">AN</span><span class="nix">NIX</span><span class="small">ION</span></div>
    <div class="descriptor">OFFENSIVE<span class="sep">·</span>SECURITY<span class="sep">·</span>DISTRIBUTION</div>
  </div>
</body>
""")
print(f"{out}: {W}x{H}")
