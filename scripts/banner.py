#!/usr/bin/env python3
"""Emit the banner as HTML, for scripts/banner.sh to render.

The lockup is built from the rules in docs/visual-identity.md rather than drawn
by hand, so the banner cannot show an identity that is not the documented one:
AN and ION as small capitals at 0.62em, NIX full size in the signature red,
0.30em tracking at light weight, and the descriptor boxed in a hairline rule.

Usage: banner.py <mark.png> <out.html> [width] [height]
"""
import base64
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import pngtool  # noqa: E402

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
mark_box = round(H * 0.80)

# ── Centre the mark on its ink, not on its canvas ────────────────────────
# The artwork does not fill its own PNG, so centring the image leaves the
# drawing sitting visibly high or low against the wordmark beside it. Measure
# where the ink actually is, scale the image so that ink fills the slot, and
# shift by the gap between the ink's centre and the canvas's.
mw, mh, stride, px = pngtool.decode(mark_path)
box = pngtool.ink_bbox(mw, mh, stride, px)
if box is None:
    sys.exit("banner: the mark has no ink")
ix0, iy0, ix1, iy1 = box
ink_w, ink_h = ix1 - ix0 + 1, iy1 - iy0 + 1

scale = mark_box / max(ink_w, ink_h)
img_w, img_h = mw * scale, mh * scale
dx = (mw / 2 - (ix0 + ix1 + 1) / 2) * scale
dy = (mh / 2 - (iy0 + iy1 + 1) / 2) * scale

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

  /* The mark is a hero image here, drawn large — never an icon. The slot is
     the size the ink should come out; the image inside it is larger than the
     slot and offset, because the ink is not centred in its own canvas. */
  .slot {{
    width: {mark_box}px; height: {mark_box}px; flex: none;
    position: relative;
  }}
  .slot img {{
    position: absolute; left: 50%; top: 50%;
    width: {img_w:.2f}px; height: {img_h:.2f}px;
    transform: translate(calc(-50% + {dx:.2f}px), calc(-50% + {dy:.2f}px));
  }}

  /* The rule spans the wordmark's measure: the two are one lockup, so the box
     is as wide as what it sits under, not as wide as its own text. */
  .lockup {{
    display: flex; flex-direction: column; align-items: stretch;
    font-size: {wordmark}px;
  }}

  /* No lowercase in the lockup: AN and ION are small capitals either side of a
     full-size NIX, so both parts share a baseline and the colour does all the
     emphasis. In running text the name is still written AnNIXion. */
  .wordmark {{
    font-size: 1em;
    font-weight: 300;
    letter-spacing: 0.30em;
    line-height: 1;
    color: {TEXT};
    white-space: nowrap;
    /* Tracking is applied after every glyph including the last, so the box is
       0.30em wider than the ink. Taken back here, where 1em is the wordmark's
       own size — on a 0.62em span it would only claw back two thirds of it.
       The box then measures what the eye measures, which is what the rule
       stretching under it and the centring around it both match against. */
    margin-right: -0.30em;
  }}
  .wordmark .small {{ font-size: 0.62em; }}
  .wordmark .nix {{ color: {RED}; }}


  .descriptor {{
    margin-top: {round(H * 0.055)}px;
    border: 1px solid {RED};
    padding: {round(H * 0.022)}px 0;
    font-size: {descriptor}px;
    letter-spacing: 0.12em;
    color: {TEXT};
    white-space: nowrap;
    display: flex; justify-content: center; gap: 1.5em;
  }}
  .descriptor .sep {{ color: {MUTED}; }}
</style>
<body>
  <div class="slot"><img src="data:image/png;base64,{mark}" alt=""></div>
  <div class="lockup">
    <div class="wordmark"><span class="small">AN</span><span class="nix">NIX</span><span class="small">ION</span></div>
    <div class="descriptor">
      <span>OFFENSIVE</span><span class="sep">·</span><span>SECURITY</span><span class="sep">·</span><span>DISTRIBUTION</span>
    </div>
  </div>
</body>
""")
print(f"{out}: {W}x{H}, mark ink {ink_w}x{ink_h} in {mw}x{mh}, nudged {dx:+.1f},{dy:+.1f}")
